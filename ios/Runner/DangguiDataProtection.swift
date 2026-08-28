import Foundation

enum DangguiDataProtectionError: String, Error {
  case createDirectory = "create-directory"
  case setProtection = "set-protection"
  case setBackupExclusion = "set-backup-exclusion"
  case verifyBackupExclusion = "verify-backup-exclusion"
  case enumerate = "enumerate"
  case unknown = "unknown"
}

struct DangguiDataProtectionStatus: Equatable {
  enum Availability: String {
    case available
    case unavailable
  }

  let availability: Availability
  let errorCode: String?

  var flutterPayload: [String: String] {
    var payload = ["status": availability.rawValue]
    if let errorCode {
      payload["errorCode"] = errorCode
    }
    return payload
  }
}

/// Persists only a stable availability flag and error code. Paths and
/// underlying filesystem errors never cross this boundary or enter logs.
final class DangguiDataProtectionCoordinator {
  private static let statusKey = "danggui.data-protection.status"
  private static let errorCodeKey = "danggui.data-protection.error-code"

  private let defaults: UserDefaults
  private let applyPolicy: () throws -> Void

  init(
    defaults: UserDefaults = .standard,
    applyPolicy: @escaping () throws -> Void
  ) {
    self.defaults = defaults
    self.applyPolicy = applyPolicy
  }

  func currentStatus() -> DangguiDataProtectionStatus {
    guard
      defaults.string(forKey: Self.statusKey)
        == DangguiDataProtectionStatus.Availability.available.rawValue
    else {
      return DangguiDataProtectionStatus(
        availability: .unavailable,
        errorCode: defaults.string(forKey: Self.errorCodeKey) ?? "not-checked"
      )
    }
    return DangguiDataProtectionStatus(
      availability: .available,
      errorCode: nil
    )
  }

  @discardableResult
  func retry() -> DangguiDataProtectionStatus {
    // Fail closed if the process exits during the filesystem policy pass.
    recordUnavailable(errorCode: "policy-pending")
    do {
      try applyPolicy()
      defaults.set(
        DangguiDataProtectionStatus.Availability.available.rawValue,
        forKey: Self.statusKey
      )
      defaults.removeObject(forKey: Self.errorCodeKey)
    } catch let error as DangguiDataProtectionError {
      recordUnavailable(errorCode: error.rawValue)
    } catch {
      recordUnavailable(errorCode: DangguiDataProtectionError.unknown.rawValue)
    }
    return currentStatus()
  }

  private func recordUnavailable(errorCode: String) {
    defaults.set(
      DangguiDataProtectionStatus.Availability.unavailable.rawValue,
      forKey: Self.statusKey
    )
    defaults.set(errorCode, forKey: Self.errorCodeKey)
  }
}

/// Applies Danggui's local-data policy to the database, restore journals and
/// automatic backups. The selected class remains available to background
/// work after the first device unlock, while keeping bytes encrypted at rest
/// across a reboot. The directory policy is inherited by newly created files;
/// the recursive pass upgrades files created by older releases.
enum DangguiDataProtection {
  static let protectionType = FileProtectionType.completeUntilFirstUserAuthentication

  static var protectedAttributes: [FileAttributeKey: Any] {
    [.protectionKey: protectionType]
  }

  static func apply(
    to rootURL: URL,
    fileManager: FileManager = .default,
    setBackupExclusion: (URL) throws -> Void = { url in
      var rootValues = URLResourceValues()
      rootValues.isExcludedFromBackup = true
      var mutableRootURL = url
      try mutableRootURL.setResourceValues(rootValues)
    },
    readBackupExclusion: (URL) throws -> Bool? = { url in
      try url.resourceValues(
        forKeys: [.isExcludedFromBackupKey]
      ).isExcludedFromBackup
    }
  ) throws {
    do {
      try fileManager.createDirectory(
        at: rootURL,
        withIntermediateDirectories: true,
        attributes: protectedAttributes
      )
    } catch {
      throw DangguiDataProtectionError.createDirectory
    }
    do {
      try fileManager.setAttributes(
        protectedAttributes,
        ofItemAtPath: rootURL.path
      )
    } catch {
      throw DangguiDataProtectionError.setProtection
    }
    do {
      try setBackupExclusion(rootURL)
    } catch let error as DangguiDataProtectionError {
      throw error
    } catch {
      throw DangguiDataProtectionError.setBackupExclusion
    }
    do {
      guard try readBackupExclusion(rootURL) == true else {
        throw DangguiDataProtectionError.verifyBackupExclusion
      }
    } catch let error as DangguiDataProtectionError {
      throw error
    } catch {
      throw DangguiDataProtectionError.verifyBackupExclusion
    }

    var enumerationError: Error?
    guard let enumerator = fileManager.enumerator(
      at: rootURL,
      includingPropertiesForKeys: [.isSymbolicLinkKey],
      options: [],
      errorHandler: { _, error in
        enumerationError = error
        return false
      }
    ) else {
      throw DangguiDataProtectionError.enumerate
    }
    while let childURL = enumerator.nextObject() as? URL {
      let values: URLResourceValues
      do {
        values = try childURL.resourceValues(forKeys: [.isSymbolicLinkKey])
      } catch {
        throw DangguiDataProtectionError.enumerate
      }
      if values.isSymbolicLink == true {
        enumerator.skipDescendants()
        continue
      }
      do {
        try fileManager.setAttributes(
          protectedAttributes,
          ofItemAtPath: childURL.path
        )
      } catch {
        throw DangguiDataProtectionError.setProtection
      }
    }
    if let enumerationError {
      // Do not silently claim the migration completed if an existing child
      // could not be enumerated and therefore may retain weaker protection.
      _ = enumerationError
      throw DangguiDataProtectionError.enumerate
    }
  }
}
