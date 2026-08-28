import Foundation
import XCTest
@testable import Runner

final class DangguiDataProtectionTests: XCTestCase {
  func testLocalDataPolicyUsesAfterFirstUnlockProtection() {
    XCTAssertEqual(
      DangguiDataProtection.protectedAttributes[.protectionKey] as? FileProtectionType,
      .completeUntilFirstUserAuthentication
    )
  }

  func testPolicyExcludesRootFromBackupAndProtectsExistingChildren() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let nested = root.appendingPathComponent("backups", isDirectory: true)
    let file = nested.appendingPathComponent("fixture.sqlite")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(
      at: nested,
      withIntermediateDirectories: true
    )
    try Data("fixture".utf8).write(to: file)

    var protectedPaths: [String: FileProtectionType] = [:]
    try DangguiDataProtection.apply(
      to: root,
      setProtection: { url, attributes in
        protectedPaths[url.standardizedFileURL.path] = try XCTUnwrap(
          attributes[.protectionKey] as? FileProtectionType
        )
      }
    )

    let rootValues = try root.resourceValues(forKeys: [.isExcludedFromBackupKey])
    XCTAssertEqual(rootValues.isExcludedFromBackup, true)
    let expectedProtectedPaths = Set(
      [root, nested, file].map { $0.standardizedFileURL.path }
    )
    XCTAssertEqual(Set(protectedPaths.keys), expectedProtectedPaths)
    for path in expectedProtectedPaths {
      XCTAssertEqual(
        protectedPaths[path],
        .completeUntilFirstUserAuthentication
      )
    }
  }

  func testPolicyFailsClosedWhenBackupExclusionCannotBeVerified() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    XCTAssertThrowsError(
      try DangguiDataProtection.apply(
        to: root,
        setBackupExclusion: { _ in },
        readBackupExclusion: { _ in false }
      )
    ) { error in
      XCTAssertEqual(
        error as? DangguiDataProtectionError,
        .verifyBackupExclusion
      )
    }
  }

  func testCoordinatorPersistsStableFailureAndCanRetry() throws {
    let suiteName = "DangguiDataProtectionTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    var attempts = 0
    let coordinator = DangguiDataProtectionCoordinator(defaults: defaults) {
      attempts += 1
      if attempts == 1 {
        throw DangguiDataProtectionError.setBackupExclusion
      }
    }

    XCTAssertEqual(coordinator.currentStatus().availability, .unavailable)
    XCTAssertEqual(coordinator.currentStatus().errorCode, "not-checked")

    let failed = coordinator.retry()
    XCTAssertEqual(failed.availability, .unavailable)
    XCTAssertEqual(failed.errorCode, "set-backup-exclusion")
    XCTAssertFalse(failed.flutterPayload.values.contains(suiteName))

    let recovered = coordinator.retry()
    XCTAssertEqual(recovered.availability, .available)
    XCTAssertNil(recovered.errorCode)
    XCTAssertEqual(
      coordinator.currentStatus(),
      DangguiDataProtectionStatus(availability: .available, errorCode: nil)
    )
  }
}
