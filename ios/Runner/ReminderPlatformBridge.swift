import Flutter
import Foundation
import UIKit
import UserNotifications

#if canImport(AlarmKit)
import AlarmKit
import AppIntents
import SwiftUI
#endif

/// Flutter bridge for reliable reminders on Apple platforms.
///
/// AlarmKit is compiled only when the selected SDK provides it and is gated at
/// runtime to iOS 26. Earlier systems keep using the existing Dart-managed
/// `UNUserNotificationCenter` fallback.
final class ReminderPlatformBridge {
  static let channelName = "com.danggui.memo/reminder_platform"

  private let channel: FlutterMethodChannel
  private var alarmObserverTask: Task<Void, Never>?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(
          FlutterError(
            code: "bridge_unavailable",
            message: "The reminder platform bridge is unavailable.",
            details: nil
          )
        )
        return
      }
      self.handle(call, result: result)
    }
    startObservingAlarmKit()
    recoverPersistedAlarmTransactions()
  }

  deinit {
    alarmObserverTask?.cancel()
    channel.setMethodCallHandler(nil)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getCapabilities":
      getCapabilities(result: result)
    case "getLocalTimeZoneIdentifier":
      result(TimeZone.autoupdatingCurrent.identifier)
    case "requestNotificationPermission":
      requestNotificationPermission(result: result)
    case "requestAlarmAuthorization":
      requestAlarmAuthorization(result: result)
    case "requestExactAlarmPermission", "requestFullScreenPermission":
      // These are Android-only permission concepts. Returning false lets the
      // shared Dart flow skip them without a MissingPluginException.
      result(false)
    case "openNotificationSettings", "openAlarmSoundSettings":
      openNotificationSettings(result: result)
    case "openOemAutostartSettings":
      result(false)
    case "scheduleAlarm":
      scheduleAlarm(arguments: call.arguments, result: result)
    case "activateDeviceGeneration":
      activateDeviceGeneration(arguments: call.arguments, result: result)
    case "cancelAlarm":
      cancelAlarm(arguments: call.arguments, result: result)
    case "retireNativeAlarmRoute":
      retireNativeAlarmRoute(arguments: call.arguments, result: result)
    case "stopAlarm":
      stopAlarm(arguments: call.arguments, result: result)
    case "snoozeAlarm":
      snoozeAlarm(arguments: call.arguments, result: result)
    case "listScheduledAlarms":
      listScheduledAlarms(result: result)
    case "listAlarmSnapshots":
      listAlarmSnapshots(result: result)
    case "drainAlarmEvents":
      drainAlarmEvents(result: result)
    case "ackAlarmEvents":
      acknowledgeAlarmEvents(arguments: call.arguments, result: result)
    case "scheduleTestAlarm":
      scheduleTestAlarm(arguments: call.arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Capabilities and permissions

  private func getCapabilities(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let notificationsEnabled: Bool
      switch settings.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
        notificationsEnabled = true
      default:
        notificationsEnabled = false
      }

      let timeSensitiveEnabled: Bool
      if #available(iOS 15.0, *) {
        timeSensitiveEnabled = settings.timeSensitiveSetting == .enabled
      } else {
        timeSensitiveEnabled = false
      }

      DispatchQueue.main.async {
        // AlarmManager authorization is UI/platform state. Read it on the
        // main queue even though UNUserNotificationCenter answers on an
        // arbitrary queue, then complete FlutterResult exactly once here.
        let alarmAuthorization = self.alarmAuthorizationState()
        let alarmKitSupported = self.isAlarmKitSupported
        let alarmGrade = alarmKitSupported && alarmAuthorization == "authorized"
        let deliveryCapability: String
        if alarmGrade {
          deliveryCapability = "alarm-grade"
        } else if notificationsEnabled && timeSensitiveEnabled {
          deliveryCapability = "time-sensitive-best-effort"
        } else if notificationsEnabled {
          deliveryCapability = "ordinary"
        } else {
          deliveryCapability = "unavailable"
        }
        result([
          "supported": alarmKitSupported,
          "platform": "ios",
          "notificationsEnabled": notificationsEnabled,
          "notificationAuthorized": notificationsEnabled,
          "notificationsGranted": notificationsEnabled,
          "notificationAuthorization": self.notificationAuthorizationName(
            settings.authorizationStatus
          ),
          "alarmKitSupported": alarmKitSupported,
          "alarmAuthorization": alarmAuthorization,
          "authorizationState": alarmAuthorization,
          "deliveryCapability": deliveryCapability,
          "alarmGrade": alarmGrade,
          "ordinaryNotificationsSupported": true,
          "ordinaryNotificationsEnabled": notificationsEnabled,
          "timeSensitiveSupported": true,
          "timeSensitiveEnabled": timeSensitiveEnabled,
          "timeSensitiveAuthorized": timeSensitiveEnabled,
          // AlarmKit owns alert haptics. Danggui intentionally does not claim
          // that the per-reminder vibration preference controls system haptics.
          "perReminderVibrationControllable": false,
          "vibrationControl": "system",
          "alarms": [
            "supported": alarmKitSupported,
            "authorization": alarmAuthorization,
          ],
        ])
      }
    }
  }

  private func requestNotificationPermission(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { granted, error in
      DispatchQueue.main.async {
        if let error {
          result(
            FlutterError(
              code: "notification_permission_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        } else {
          result(granted)
        }
      }
    }
  }

  private func requestAlarmAuthorization(result: @escaping FlutterResult) {
#if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      Task { @MainActor in
        do {
          let state = try await AlarmManager.shared.requestAuthorization()
          result(state == .authorized)
        } catch {
          result(
            FlutterError(
              code: "alarm_authorization_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
      return
    }
#endif
    result(false)
  }

  private var isAlarmKitSupported: Bool {
#if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      return true
    }
#endif
    return false
  }

  private func alarmAuthorizationState() -> String {
#if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      switch AlarmManager.shared.authorizationState {
      case .authorized:
        return "authorized"
      case .denied:
        return "denied"
      case .notDetermined:
        return "notDetermined"
      @unknown default:
        return "unavailable"
      }
    }
#endif
    return "unavailable"
  }

  private func notificationAuthorizationName(
    _ status: UNAuthorizationStatus
  ) -> String {
    switch status {
    case .notDetermined:
      return "notDetermined"
    case .denied:
      return "denied"
    case .authorized:
      return "authorized"
    case .provisional:
      return "provisional"
    case .ephemeral:
      return "ephemeral"
    @unknown default:
      return "unknown"
    }
  }

  private func openNotificationSettings(result: @escaping FlutterResult) {
    let settingsURLString: String
    if #available(iOS 16.0, *) {
      settingsURLString = UIApplication.openNotificationSettingsURLString
    } else if #available(iOS 15.4, *) {
      settingsURLString = UIApplicationOpenNotificationSettingsURLString
    } else {
      settingsURLString = UIApplication.openSettingsURLString
    }

    guard let url = URL(string: settingsURLString) else {
      result(settingsUnavailableError())
      return
    }
    DispatchQueue.main.async {
      UIApplication.shared.open(url, options: [:]) { opened in
        if opened {
          result(nil)
        } else {
          result(self.settingsUnavailableError())
        }
      }
    }
  }

  private func settingsUnavailableError() -> FlutterError {
    FlutterError(
      code: "settings_unavailable",
      message: "The operating system did not open notification settings.",
      details: nil
    )
  }

  // MARK: Alarm operations

  /// Establishes the database generation whose reminders may interact with
  /// native delivery state. A missing/null generation is the v1.1.4 legacy
  /// generation; a non-null value must be a canonicalizable UUID.
  private func activateDeviceGeneration(
    arguments: Any?,
    result: @escaping FlutterResult
  ) {
    let values = arguments as? [String: Any]
    let generation: String?
    do {
      generation = try Self.optionalDeviceGeneration(values)
    } catch {
      result(alarmError("invalid_device_generation", error))
      return
    }
#if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      Task { @MainActor in
        do {
          try await DangguiAlarmOperationActor.shared.activateDeviceGeneration(
            generation
          )
          result(nil)
        } catch {
          result(self.alarmError("alarm_generation_activation_failed", error))
        }
      }
      return
    }
#endif
    do {
      try DangguiAlarmStore.activateDeviceGeneration(generation)
      result(nil)
    } catch {
      result(alarmError("alarm_generation_activation_failed", error))
    }
  }

  private func scheduleAlarm(arguments: Any?, result: @escaping FlutterResult) {
    do {
      let record = try DangguiAlarmRecord(arguments: arguments)
#if canImport(AlarmKit)
      if #available(iOS 26.0, *) {
        Task { @MainActor in
          do {
            try await DangguiAlarmOperationActor.shared.schedule(record)
            result(nil)
          } catch {
            result(self.alarmError("alarm_schedule_failed", error))
          }
        }
        return
      }
#endif
      result(alarmKitUnavailableError())
    } catch {
      result(alarmError("invalid_alarm_request", error))
    }
  }

  private func cancelAlarm(arguments: Any?, result: @escaping FlutterResult) {
    guard let reminderID = reminderID(from: arguments) else {
      result(missingReminderIDError())
      return
    }
    let expectedDeviceGeneration: String?
    do {
      expectedDeviceGeneration = try Self.optionalDeviceGeneration(
        arguments as? [String: Any]
      )
    } catch {
      result(alarmError("invalid_alarm_identity", error))
      return
    }
#if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      Task { @MainActor in
        do {
          try await DangguiAlarmOperationActor.shared.cancel(
            reminderID: reminderID,
            expectedDeviceGeneration: expectedDeviceGeneration
          )
          result(nil)
        } catch {
          result(self.alarmError("alarm_cancel_failed", error))
        }
      }
      return
    }
#endif
    do {
      guard try DangguiAlarmStore.activeGenerationMatches(
        expectedDeviceGeneration
      ) else {
        result(nil)
        return
      }
      _ = try DangguiAlarmStore.remove(
        reminderID: reminderID,
        deviceGeneration: expectedDeviceGeneration
      )
      try DangguiAlarmStore.removeTransactions(
        reminderID: reminderID,
        deviceGeneration: expectedDeviceGeneration
      )
    } catch {
      result(alarmError("alarm_cancel_failed", error))
      return
    }
    result(nil)
  }

  /// Removes only the AlarmKit representation for one immutable reminder
  /// revision. Unlike `cancelAlarm`, this is a delivery-route transition, not a
  /// business cancellation: once cleanup is complete the same revision may be
  /// installed again if AlarmKit authorization later returns.
  private func retireNativeAlarmRoute(
    arguments: Any?,
    result: @escaping FlutterResult
  ) {
    guard let reminderID = reminderID(from: arguments) else {
      result(missingReminderIDError())
      return
    }
    let values = arguments as? [String: Any]
    let expectedRevision = Self.integer(values, keys: ["scheduleRevision", "revision"])
    let expectedSession = Self.string(
      values,
      keys: ["session", "sessionId", "platformId", "platformAlarmId"]
    )
    let expectedDeviceGeneration: String?
    do {
      expectedDeviceGeneration = try Self.optionalDeviceGeneration(values)
    } catch {
      result(alarmError("invalid_alarm_identity", error))
      return
    }
    guard let expectedRevision, expectedRevision > 0,
          let expectedSession, !expectedSession.isEmpty else {
      result(invalidAlarmIdentityError())
      return
    }
#if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      Task { @MainActor in
        do {
          try await DangguiAlarmOperationActor.shared.retireNativeRoute(
            reminderID: reminderID,
            expectedRevision: expectedRevision,
            expectedSession: expectedSession,
            expectedDeviceGeneration: expectedDeviceGeneration
          )
          result(nil)
        } catch {
          result(self.alarmError("alarm_route_retire_failed", error))
        }
      }
      return
    }
#endif
    // Earlier systems have no AlarmKit daemon registration. This must be a
    // no-op rather than an unscoped mirror deletion: a delayed fallback call
    // must never erase a newer revision restored from durable state.
    result(nil)
  }

  private func stopAlarm(arguments: Any?, result: @escaping FlutterResult) {
    guard let reminderID = reminderID(from: arguments) else {
      result(missingReminderIDError())
      return
    }
    let values = arguments as? [String: Any]
    let expectedRevision = Self.integer(values, keys: ["scheduleRevision", "revision"])
    let expectedSession = Self.string(
      values,
      keys: ["session", "sessionId", "platformId", "platformAlarmId"]
    )
    guard let expectedRevision, expectedRevision > 0,
          let expectedSession, !expectedSession.isEmpty else {
      result(invalidAlarmIdentityError())
      return
    }
#if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      Task { @MainActor in
        do {
          try await DangguiAlarmOperationActor.shared.stop(
            reminderID: reminderID,
            expectedRevision: expectedRevision,
            expectedSession: expectedSession
          )
          result(nil)
        } catch {
          result(self.alarmError("alarm_stop_failed", error))
        }
      }
      return
    }
#endif
    result(alarmKitUnavailableError())
  }

  private func snoozeAlarm(arguments: Any?, result: @escaping FlutterResult) {
    guard let reminderID = reminderID(from: arguments) else {
      result(missingReminderIDError())
      return
    }
    let values = arguments as? [String: Any]
    let requestedMinutes = Self.integer(
      values,
      keys: ["minutes", "snoozeMinutes", "defaultSnoozeMinutes"]
    )
    let expectedRevision = Self.integer(values, keys: ["scheduleRevision", "revision"])
    let expectedSession = Self.string(
      values,
      keys: ["session", "sessionId", "platformId", "platformAlarmId"]
    )
    guard let expectedRevision, expectedRevision > 0,
          let expectedSession, !expectedSession.isEmpty else {
      result(invalidAlarmIdentityError())
      return
    }
#if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      Task { @MainActor in
        do {
          try await DangguiAlarmOperationActor.shared.snooze(
            reminderID: reminderID,
            minutes: requestedMinutes,
            expectedRevision: expectedRevision,
            expectedSession: expectedSession
          )
          result(nil)
        } catch {
          result(self.alarmError("alarm_snooze_failed", error))
        }
      }
      return
    }
#endif
    result(alarmKitUnavailableError())
  }

  private func listScheduledAlarms(result: @escaping FlutterResult) {
#if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      Task { @MainActor in
        do {
          let records = try await DangguiAlarmOperationActor.shared.reconcileAndList()
          result(records.map(\.legacyFlutterMap))
        } catch {
          result(self.alarmError("alarm_list_failed", error))
        }
      }
      return
    }
#endif
    result([Any]())
  }

  private func listAlarmSnapshots(result: @escaping FlutterResult) {
#if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      Task { @MainActor in
        do {
          let records = try await DangguiAlarmOperationActor.shared.reconcileAndList()
          result(records.map(\.snapshotMap))
        } catch {
          result(self.alarmError("alarm_snapshot_failed", error))
        }
      }
      return
    }
#endif
    result([Any]())
  }

  private func drainAlarmEvents(result: @escaping FlutterResult) {
#if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      // Reconcile first so alarms that fired while the app wasn't running are
      // represented in the durable event journal before it is returned.
      Task { @MainActor in
        _ = try? await DangguiAlarmOperationActor.shared.reconcileAndList()
        do {
          result(try DangguiAlarmStore.activeEventsDurably().map(\.flutterMap))
        } catch {
          result(self.alarmError("alarm_event_drain_failed", error))
        }
      }
      return
    }
#endif
    do {
      result(try DangguiAlarmStore.activeEventsDurably().map(\.flutterMap))
    } catch {
      result(alarmError("alarm_event_drain_failed", error))
    }
  }

  private func acknowledgeAlarmEvents(
    arguments: Any?,
    result: @escaping FlutterResult
  ) {
    let values = arguments as? [String: Any]
    let eventIDs = Set((values?["eventIds"] as? [String]) ?? [])
    do {
      try DangguiAlarmStore.acknowledgeActiveEventsDurably(eventIDs)
      result(nil)
    } catch {
      result(alarmError("alarm_event_ack_failed", error))
    }
  }

  private func scheduleTestAlarm(arguments: Any?, result: @escaping FlutterResult) {
    let values = arguments as? [String: Any]
    let now = Date().timeIntervalSince1970
    let delaySeconds = min(
      3_600,
      max(15, Self.integer(values, keys: ["delaySeconds"]) ?? 15)
    )
    var request: [String: Any] = [
      "reminderId": "danggui-test-\(UUID().uuidString)",
      "taskId": "danggui-test",
      "scheduleRevision": 1,
      "triggerAtEpochMs": Int64((now + Double(delaySeconds)) * 1_000),
      "title": Self.string(values, keys: ["title"]) ?? "当归测试闹钟",
      "body": Self.string(values, keys: ["body"]) ?? "用于检查提醒是否可靠送达",
      "vibrationEnabled": Self.boolean(values, keys: ["vibrationEnabled"]) ?? true,
      "defaultSnoozeMinutes": 10,
    ]
    do {
      if let generation = try DangguiAlarmStore.activeDeviceGeneration() {
        request["deviceGeneration"] = generation
      }
    } catch {
      result(alarmError("alarm_generation_read_failed", error))
      return
    }
    scheduleAlarm(arguments: request, result: result)
  }

  private func reminderID(from arguments: Any?) -> String? {
    let values = arguments as? [String: Any]
    return Self.string(values, keys: ["reminderId", "alarmId", "id"])
  }

  private func missingReminderIDError() -> FlutterError {
    FlutterError(
      code: "invalid_alarm_request",
      message: "A non-empty reminderId is required.",
      details: nil
    )
  }

  private func invalidAlarmIdentityError() -> FlutterError {
    FlutterError(
      code: "invalid_alarm_identity",
      message: "A positive revision and non-empty alarm session are required.",
      details: nil
    )
  }

  private func alarmKitUnavailableError() -> FlutterError {
    FlutterError(
      code: "alarmkit_unavailable",
      message: "AlarmKit requires iOS 26 or later. Use the notification fallback on this device.",
      details: nil
    )
  }

  private func alarmError(_ fallbackCode: String, _ error: Error) -> FlutterError {
    let mapping = DangguiAlarmFailureMapper.flutterError(for: error, fallbackCode: fallbackCode)
    return FlutterError(code: mapping.code, message: mapping.message, details: mapping.details)
  }

  // MARK: Alarm observation

  private func startObservingAlarmKit() {
#if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      alarmObserverTask = Task { @MainActor in
        for await alarms in AlarmManager.shared.alarmUpdates {
          if Task.isCancelled { break }
          await DangguiAlarmOperationActor.shared.reconcile(alarms)
        }
      }
    }
#endif
  }

  private func recoverPersistedAlarmTransactions() {
#if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      Task { @MainActor in
        await DangguiAlarmOperationActor.shared.recoverPersistedTransactions()
      }
    }
#endif
  }

  // MARK: Method-channel value parsing

  fileprivate static func string(
    _ values: [String: Any]?,
    keys: [String]
  ) -> String? {
    guard let values else { return nil }
    for key in keys {
      if let value = values[key] as? String, !value.isEmpty {
        return value
      }
      if let value = values[key], !(value is NSNull) {
        let text = String(describing: value)
        if !text.isEmpty { return text }
      }
    }
    return nil
  }

  /// Missing/null represents the legacy database generation. Any supplied
  /// value is deliberately strict: coercing numbers or empty strings into a
  /// generation would let a delayed route mutation escape its database epoch.
  static func optionalDeviceGeneration(
    _ values: [String: Any]?
  ) throws -> String? {
    guard let values else { return nil }
    let suppliedValues: [Any] = ["deviceGeneration", "generation"]
      .compactMap { values[$0] }
    guard !suppliedValues.isEmpty else { return nil }
    let normalizedValues = try suppliedValues.map { supplied -> String? in
      if supplied is NSNull { return nil }
      guard let rawGeneration = supplied as? String,
            let normalized = DangguiAlarmGeneration.normalized(rawGeneration)
      else {
        throw DangguiAlarmBridgeError.invalidDeviceGeneration
      }
      return normalized
    }
    let first = normalizedValues[0]
    guard normalizedValues.dropFirst().allSatisfy({
      DangguiAlarmGeneration.matches(first, $0)
    }) else {
      throw DangguiAlarmBridgeError.invalidDeviceGeneration
    }
    return first
  }

  fileprivate static func integer(
    _ values: [String: Any]?,
    keys: [String]
  ) -> Int? {
    guard let values else { return nil }
    for key in keys {
      if let value = values[key] as? NSNumber { return value.intValue }
      if let value = values[key] as? String, let parsed = Int(value) {
        return parsed
      }
    }
    return nil
  }

  fileprivate static func int64(
    _ values: [String: Any]?,
    keys: [String]
  ) -> Int64? {
    guard let values else { return nil }
    for key in keys {
      if let value = values[key] as? NSNumber { return value.int64Value }
      if let value = values[key] as? String, let parsed = Int64(value) {
        return parsed
      }
    }
    return nil
  }

  fileprivate static func boolean(
    _ values: [String: Any]?,
    keys: [String]
  ) -> Bool? {
    guard let values else { return nil }
    for key in keys {
      if let value = values[key] as? Bool { return value }
      if let value = values[key] as? NSNumber { return value.boolValue }
      if let value = values[key] as? String {
        switch value.lowercased() {
        case "true", "1": return true
        case "false", "0": return false
        default: continue
        }
      }
    }
    return nil
  }
}

// MARK: Durable native mirror and event journal

enum DangguiAlarmIdentifier {
  /// Produces a stable UUID-shaped identifier for one immutable alarm revision.
  /// A revision-specific ID lets an edit be installed and verified before its
  /// predecessor is retired, removing the previous cancel-first loss window.
  static func platformID(
    for reminderID: String,
    revision: Int,
    deviceGeneration: String? = nil
  ) -> String {
    var identity = "\(reminderID)\u{1f}\(revision)"
    if let deviceGeneration {
      identity += "\u{1f}\(deviceGeneration.lowercased())"
    }
    let bytes = Array(identity.utf8)
    let first = fnv1a(bytes, seed: 0xcbf29ce484222325)
    let second = fnv1a(bytes.reversed(), seed: 0x84222325cbf29ce4)
    var characters = Array(String(format: "%016llx%016llx", first, second))
    // Mark the value as a name-derived UUID and use the RFC 4122 variant.
    characters[12] = "5"
    characters[16] = "a"
    return [
      String(characters[0..<8]),
      String(characters[8..<12]),
      String(characters[12..<16]),
      String(characters[16..<20]),
      String(characters[20..<32]),
    ].joined(separator: "-")
  }

  /// Compatibility helper for v1 mirror data and older native tests.
  static func platformID(for reminderID: String) -> String {
    platformID(for: reminderID, revision: 0)
  }

  private static func fnv1a<S: Sequence>(
    _ bytes: S,
    seed: UInt64
  ) -> UInt64 where S.Element == UInt8 {
    var hash = seed
    for byte in bytes {
      hash ^= UInt64(byte)
      hash = hash &* 0x100000001b3
    }
    return hash
  }
}

struct DangguiAlarmRecord: Codable, Hashable, Sendable {
  var reminderID: String
  var platformAlarmID: String
  /// A database-replacement generation. Missing means the v1.1.4 legacy
  /// generation and preserves its deterministic platform identifier.
  var deviceGeneration: String?
  var taskID: String
  var scheduleRevision: Int
  var triggerAtEpochMs: Int64
  var title: String
  var body: String
  var vibrationEnabled: Bool
  var defaultSnoozeMinutes: Int
  var localeTag: String
  var lastState: String
  var firedEventRecorded: Bool

  init(arguments: Any?) throws {
    guard let values = arguments as? [String: Any] else {
      throw DangguiAlarmBridgeError.invalidArguments
    }
    guard let reminderID = ReminderPlatformBridge.string(
      values,
      keys: ["reminderId", "alarmId", "id"]
    ) else {
      throw DangguiAlarmBridgeError.missingReminderID
    }
    guard let triggerAtEpochMs = ReminderPlatformBridge.int64(
      values,
      keys: [
        "triggerAtEpochMs",
        "scheduledAtEpochMs",
        "triggerAtMillis",
        "scheduledAtMillis",
      ]
    ) else {
      throw DangguiAlarmBridgeError.missingTriggerDate
    }
    guard triggerAtEpochMs > 0 else {
      throw DangguiAlarmBridgeError.invalidTriggerDate
    }

    guard let scheduleRevision = ReminderPlatformBridge.integer(
      values,
      keys: ["scheduleRevision", "revision"]
    ), scheduleRevision > 0 else {
      throw DangguiAlarmBridgeError.invalidScheduleRevision
    }
    self.scheduleRevision = scheduleRevision
    self.reminderID = reminderID
    deviceGeneration = try ReminderPlatformBridge.optionalDeviceGeneration(values)
    platformAlarmID = DangguiAlarmIdentifier.platformID(
      for: reminderID,
      revision: scheduleRevision,
      deviceGeneration: deviceGeneration
    )
    taskID = ReminderPlatformBridge.string(values, keys: ["taskId"]) ?? ""
    self.triggerAtEpochMs = triggerAtEpochMs
    title = ReminderPlatformBridge.string(values, keys: ["title"]) ?? "当归提醒"
    body = ReminderPlatformBridge.string(values, keys: ["body"]) ?? ""
    vibrationEnabled = ReminderPlatformBridge.boolean(
      values,
      keys: ["vibrationEnabled"]
    ) ?? true
    defaultSnoozeMinutes = min(
      1_440,
      max(
        1,
        ReminderPlatformBridge.integer(
          values,
          keys: ["defaultSnoozeMinutes", "snoozeMinutes"]
        ) ?? 10
      )
    )
    localeTag = ReminderPlatformBridge.string(values, keys: ["localeTag"]) ?? "zh-Hans"
    lastState = "pending"
    firedEventRecorded = false
  }

  var triggerDate: Date {
    Date(timeIntervalSince1970: TimeInterval(triggerAtEpochMs) / 1_000)
  }

  /// Immutable scheduling content for one revision. Runtime state is
  /// deliberately excluded so retries can be compared after reconciliation.
  var configurationFingerprint: DangguiAlarmConfigurationFingerprint {
    DangguiAlarmConfigurationFingerprint(
      taskID: taskID,
      triggerAtEpochMs: triggerAtEpochMs,
      title: title,
      body: body,
      vibrationEnabled: vibrationEnabled,
      defaultSnoozeMinutes: defaultSnoozeMinutes,
      localeTag: localeTag
    )
  }

  var snapshotMap: [String: Any] {
    var value: [String: Any] = [
      "reminderId": reminderID,
      "platformId": platformAlarmID,
      "platformAlarmId": platformAlarmID,
      "revision": scheduleRevision,
      "scheduleRevision": scheduleRevision,
      "triggerAtEpochMs": triggerAtEpochMs,
      "state": lastState,
    ]
    if let deviceGeneration {
      value["deviceGeneration"] = deviceGeneration
    }
    return value
  }

  var legacyFlutterMap: [String: Any] {
    var value = snapshotMap
    value["taskId"] = taskID
    value["title"] = title
    return value
  }
}

struct DangguiAlarmConfigurationFingerprint: Codable, Hashable, Sendable {
  let taskID: String
  let triggerAtEpochMs: Int64
  let title: String
  let body: String
  let vibrationEnabled: Bool
  let defaultSnoozeMinutes: Int
  let localeTag: String
}

enum DangguiAlarmEventType: String, Codable, CaseIterable, Sendable {
  case registered
  case delivered
  case systemAlert
  case audio
  case vibration
  case missed
  case stopped
  case snoozed
  case error
}

struct DangguiAlarmEvent: Codable, Hashable, Sendable {
  var eventID: String
  var type: String
  var reminderID: String
  var taskID: String
  var scheduleRevision: Int
  var occurredAtEpochMs: Int64
  var snoozeMinutes: Int?
  var platformAlarmID: String?
  var deviceGeneration: String?
  var state: String?
  var errorCode: String?
  var delayedByMs: Int64?
  var successorTriggerAtEpochMs: Int64?

  var mutatesBusinessState: Bool {
    guard let eventType = DangguiAlarmEventType(rawValue: type) else { return false }
    switch eventType {
    case .delivered, .missed, .stopped, .snoozed:
      return true
    case .registered, .systemAlert, .audio, .vibration, .error:
      return false
    }
  }

  init(
    type: DangguiAlarmEventType,
    record: DangguiAlarmRecord,
    snoozeMinutes: Int? = nil,
    state: String? = nil,
    errorCode: String? = nil,
    delayedByMs: Int64? = nil,
    occurredAtEpochMs: Int64? = nil,
    successorTriggerAtEpochMs: Int64? = nil,
    usesStableID: Bool = false
  ) {
    eventID = usesStableID
      ? Self.stableID(type: type, record: record)
      : UUID().uuidString
    self.type = type.rawValue
    reminderID = record.reminderID
    taskID = record.taskID
    scheduleRevision = record.scheduleRevision
    self.occurredAtEpochMs = occurredAtEpochMs
      ?? Int64(Date().timeIntervalSince1970 * 1_000)
    self.snoozeMinutes = snoozeMinutes
    platformAlarmID = record.platformAlarmID
    deviceGeneration = record.deviceGeneration
    self.state = state
    self.errorCode = errorCode
    self.delayedByMs = delayedByMs
    self.successorTriggerAtEpochMs = successorTriggerAtEpochMs
  }

  static func stableID(
    type: DangguiAlarmEventType,
    record: DangguiAlarmRecord
  ) -> String {
    "danggui.alarm.\(type.rawValue).\(record.platformAlarmID.lowercased()).r\(record.scheduleRevision)"
  }

  var flutterMap: [String: Any] {
    var value: [String: Any] = [
      "eventId": eventID,
      "type": type,
      "reminderId": reminderID,
      "taskId": taskID,
      "scheduleRevision": scheduleRevision,
      "occurredAtEpochMs": occurredAtEpochMs,
    ]
    if let snoozeMinutes {
      value["snoozeMinutes"] = snoozeMinutes
    }
    if let platformAlarmID {
      value["platformId"] = platformAlarmID
      value["sessionId"] = platformAlarmID
      value["session"] = platformAlarmID
    }
    if let deviceGeneration {
      value["deviceGeneration"] = deviceGeneration
    }
    if let state {
      value["state"] = state
    }
    if let errorCode {
      value["errorCode"] = errorCode
    }
    if let delayedByMs {
      value["delayedByMs"] = delayedByMs
    }
    if let successorTriggerAtEpochMs {
      value["successorTriggerAtEpochMs"] = successorTriggerAtEpochMs
    }
    return value
  }
}

enum DangguiAlarmTransactionPhase: String, Codable, CaseIterable, Sendable {
  case pending
  case replacementScheduled = "replacement-scheduled"
  case confirmed
  case retired

  func canAdvance(to next: DangguiAlarmTransactionPhase) -> Bool {
    switch (self, next) {
    case (.pending, .replacementScheduled),
         (.replacementScheduled, .confirmed),
         (.confirmed, .retired):
      return true
    default:
      return self == next
    }
  }
}

struct DangguiAlarmTransaction: Codable, Hashable, Sendable {
  var transactionID: String
  var reminderID: String
  var previousPlatformAlarmID: String?
  var previousRecord: DangguiAlarmRecord?
  var replacement: DangguiAlarmRecord
  var phase: DangguiAlarmTransactionPhase
  var updatedAtEpochMs: Int64
  /// Optional for backward-compatible decoding of v1 transactions.
  var stopPreviousWhenConfirmed: Bool?
  /// A stable-ID event written durably before the transaction is removed.
  var completionEvent: DangguiAlarmEvent?
  /// Missing-mirror repair remains transaction-owned through its terminal
  /// decision, preventing repeated foreground reconciliation from scheduling
  /// audible duplicates. Optional for v1.1.4 transactions.
  var ownsMissingRecovery: Bool?

  init(
    replacement: DangguiAlarmRecord,
    previousPlatformAlarmID: String?,
    previousRecord: DangguiAlarmRecord? = nil,
    stopPreviousWhenConfirmed: Bool = false,
    completionEvent: DangguiAlarmEvent? = nil,
    ownsMissingRecovery: Bool = false
  ) {
    transactionID = UUID().uuidString
    reminderID = replacement.reminderID
    self.previousPlatformAlarmID = previousPlatformAlarmID
    self.previousRecord = previousRecord
    self.replacement = replacement
    phase = .pending
    updatedAtEpochMs = Int64(Date().timeIntervalSince1970 * 1_000)
    self.stopPreviousWhenConfirmed = stopPreviousWhenConfirmed
    self.completionEvent = completionEvent
    self.ownsMissingRecovery = ownsMissingRecovery
  }

  mutating func advance(to next: DangguiAlarmTransactionPhase) throws {
    guard phase.canAdvance(to: next) else {
      throw DangguiAlarmBridgeError.invalidTransactionTransition
    }
    phase = next
    updatedAtEpochMs = Int64(Date().timeIntervalSince1970 * 1_000)
  }
}

enum DangguiAlarmCancellationPhase: String, Codable, CaseIterable, Sendable {
  case pending
  case daemonCleared = "daemon-cleared"
  case mirrorRemoved = "mirror-removed"
  case completed

  func canAdvance(to next: DangguiAlarmCancellationPhase) -> Bool {
    switch (self, next) {
    case (.pending, .daemonCleared),
         (.daemonCleared, .mirrorRemoved),
         (.mirrorRemoved, .completed):
      return true
    default:
      return self == next
    }
  }
}

enum DangguiAlarmCancellationDaemonAction: String, Codable, Sendable {
  case cancel
  case stop
}

struct DangguiAlarmCancellation: Codable, Hashable, Sendable {
  var cancellationID: String
  var reminderID: String
  /// Scope for the revision high-water mark. Missing is the legacy database
  /// generation, not a wildcard over future restored databases.
  var deviceGeneration: String?
  var cancelledThroughRevision: Int
  var platformAlarmIDs: [String]
  var phase: DangguiAlarmCancellationPhase
  var updatedAtEpochMs: Int64
  /// Optional so v1.1.4 cancellation tombstones decode as ordinary cancels.
  var daemonAction: DangguiAlarmCancellationDaemonAction?
  /// Only the user-selected alarm is stopped; related predecessors/successors
  /// are cancelled after the same tombstone has made them recoverable.
  var stopPlatformAlarmID: String?
  /// A stable terminal event persisted before the mirror is retired.
  var completionEvent: DangguiAlarmEvent?
  /// Optional terminal ledger classification. v1.1.4 tombstones decode nil.
  var terminalState: String?

  init(
    reminderID: String,
    deviceGeneration: String? = nil,
    cancelledThroughRevision: Int,
    platformAlarmIDs: Set<String>,
    nowEpochMs: Int64,
    daemonAction: DangguiAlarmCancellationDaemonAction = .cancel,
    stopPlatformAlarmID: String? = nil,
    completionEvent: DangguiAlarmEvent? = nil,
    terminalState: String = "cancelled"
  ) {
    cancellationID = UUID().uuidString
    self.reminderID = reminderID
    self.deviceGeneration = deviceGeneration
    self.cancelledThroughRevision = cancelledThroughRevision
    self.platformAlarmIDs = platformAlarmIDs.map { $0.lowercased() }.sorted()
    phase = .pending
    updatedAtEpochMs = nowEpochMs
    self.daemonAction = daemonAction
    self.stopPlatformAlarmID = stopPlatformAlarmID?.lowercased()
    self.completionEvent = completionEvent
    self.terminalState = terminalState
  }

  mutating func advance(
    to next: DangguiAlarmCancellationPhase,
    nowEpochMs: Int64
  ) throws {
    guard phase.canAdvance(to: next) else {
      throw DangguiAlarmBridgeError.invalidCancellationTransition
    }
    phase = next
    updatedAtEpochMs = nowEpochMs
  }
}

enum DangguiAlarmScheduleDecision: Equatable {
  case install
  case idempotent
  case staleRevision
  case revisionConflict
}

enum DangguiAlarmGeneration {
  static func normalized(_ value: String) -> String? {
    guard let parsed = UUID(uuidString: value) else { return nil }
    let normalized = parsed.uuidString.lowercased()
    let characters = Array(normalized)
    guard characters.count == 36,
          "12345678".contains(characters[14]),
          "89ab".contains(characters[19]) else {
      return nil
    }
    return normalized
  }

  static func isValid(_ value: String?) -> Bool {
    guard let value else { return true }
    guard let normalized = normalized(value) else { return false }
    // Persisted authoritative images are canonical lowercase UUIDs. Method
    // channel input is normalized before storage, so accepting a different
    // spelling here would only broaden the corruption/forgery surface.
    return normalized == value
  }

  static func matches(_ lhs: String?, _ rhs: String?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil):
      return true
    case let (lhs?, rhs?):
      return lhs.caseInsensitiveCompare(rhs) == .orderedSame
    default:
      return false
    }
  }

  static func scopedReminderKey(
    reminderID: String,
    deviceGeneration: String?
  ) -> String {
    "\(reminderID)\u{1f}\(deviceGeneration?.lowercased() ?? "<legacy>")"
  }
}

struct DangguiAlarmActiveGenerationState: Codable, Equatable, Sendable {
  let deviceGeneration: String?
  let updatedAtEpochMs: Int64
}

/// Computes only native route identifiers. Generation activation is never a
/// business cancellation and therefore deliberately creates no high-water
/// tombstone or terminal event.
enum DangguiAlarmGenerationActivationPolicy {
  static func inactivePlatformAlarmIDs(
    records: [DangguiAlarmRecord],
    transactions: [DangguiAlarmTransaction],
    cancellations: [DangguiAlarmCancellation],
    activeDeviceGeneration: String?
  ) -> Set<String> {
    var inactiveIDs = Set<String>()
    var activeIDs = Set<String>()
    for record in records where !DangguiAlarmGeneration.matches(
      record.deviceGeneration,
      activeDeviceGeneration
    ) {
      inactiveIDs.insert(record.platformAlarmID.lowercased())
    }
    activeIDs.formUnion(
      records.lazy.filter {
        DangguiAlarmGeneration.matches(
          $0.deviceGeneration,
          activeDeviceGeneration
        )
      }.map { $0.platformAlarmID.lowercased() }
    )
    for transaction in transactions {
      if !DangguiAlarmGeneration.matches(
        transaction.replacement.deviceGeneration,
        activeDeviceGeneration
      ) {
        inactiveIDs.insert(transaction.replacement.platformAlarmID.lowercased())
        if transaction.previousRecord == nil,
           let previousPlatformAlarmID = transaction.previousPlatformAlarmID {
          // Semantic validation only permits an image-less predecessor for a
          // same-generation legacy transaction.
          inactiveIDs.insert(previousPlatformAlarmID.lowercased())
        }
      }
      if let previousRecord = transaction.previousRecord,
         !DangguiAlarmGeneration.matches(
           previousRecord.deviceGeneration,
           activeDeviceGeneration
         ) {
        inactiveIDs.insert(previousRecord.platformAlarmID.lowercased())
      }
      if DangguiAlarmGeneration.matches(
        transaction.replacement.deviceGeneration,
        activeDeviceGeneration
      ) {
        activeIDs.insert(transaction.replacement.platformAlarmID.lowercased())
        if transaction.previousRecord == nil,
           let previousPlatformAlarmID = transaction.previousPlatformAlarmID {
          activeIDs.insert(previousPlatformAlarmID.lowercased())
        }
      }
      if let previousRecord = transaction.previousRecord,
         DangguiAlarmGeneration.matches(
           previousRecord.deviceGeneration,
           activeDeviceGeneration
         ) {
        activeIDs.insert(previousRecord.platformAlarmID.lowercased())
      }
    }
    for cancellation in cancellations where !DangguiAlarmGeneration.matches(
      cancellation.deviceGeneration,
      activeDeviceGeneration
    ) {
      inactiveIDs.formUnion(cancellation.platformAlarmIDs.map { $0.lowercased() })
    }
    // Historical business tombstones may intentionally capture predecessor
    // IDs from more than one generation. A route proven active by the current
    // mirror/transaction always wins over an older tombstone's coarse list.
    return inactiveIDs.subtracting(activeIDs)
  }
}

/// AlarmManager only exposes alarms owned by this application. Once the
/// authoritative stores are healthy, any daemon ID not owned by an active
/// record, replacement transaction, predecessor, or cancellation is an
/// orphan that could otherwise alert after a database replacement.
enum DangguiAlarmSystemSnapshotPolicy {
  static func orphanPlatformAlarmIDs(
    remotePlatformAlarmIDs: Set<String>,
    records: [DangguiAlarmRecord],
    transactions: [DangguiAlarmTransaction],
    cancellations: [DangguiAlarmCancellation]
  ) -> Set<String> {
    var ownedIDs = Set(records.map { $0.platformAlarmID.lowercased() })
    for transaction in transactions {
      ownedIDs.insert(transaction.replacement.platformAlarmID.lowercased())
      if let predecessor = transaction.previousPlatformAlarmID {
        ownedIDs.insert(predecessor.lowercased())
      }
      if let predecessor = transaction.previousRecord {
        ownedIDs.insert(predecessor.platformAlarmID.lowercased())
      }
    }
    for cancellation in cancellations {
      ownedIDs.formUnion(cancellation.platformAlarmIDs.map { $0.lowercased() })
    }
    return Set(remotePlatformAlarmIDs.map { $0.lowercased() })
      .subtracting(ownedIDs)
  }
}

/// Immutable identity carried by every stop/snooze action. The platform alarm
/// ID is a deterministic session token for one database generation and
/// reminder revision, so delayed actions cannot mutate a later edit or a
/// replacement-restored database.
struct DangguiAlarmActionIdentity: Equatable, Sendable {
  let reminderID: String
  let scheduleRevision: Int
  let platformAlarmID: String

  var isInternallyConsistent: Bool {
    !reminderID.isEmpty
      && scheduleRevision > 0
      && UUID(uuidString: platformAlarmID) != nil
  }

  func matches(_ record: DangguiAlarmRecord) -> Bool {
    isInternallyConsistent
      && record.reminderID == reminderID
      && record.scheduleRevision == scheduleRevision
      && record.platformAlarmID.caseInsensitiveCompare(platformAlarmID) == .orderedSame
  }
}

/// Pure compare-and-swap rules shared by method-channel and AppIntent paths.
enum DangguiAlarmMutationPolicy {
  static func scheduleDecision(
    requested: DangguiAlarmRecord,
    current: DangguiAlarmRecord?,
    transactions: [DangguiAlarmTransaction],
    cancellation: DangguiAlarmCancellation?
  ) -> DangguiAlarmScheduleDecision {
    let related = transactions.filter {
      $0.reminderID == requested.reminderID
        && DangguiAlarmGeneration.matches(
          $0.replacement.deviceGeneration,
          requested.deviceGeneration
        )
    }
    let scopedCurrent = current.flatMap {
      DangguiAlarmGeneration.matches(
        $0.deviceGeneration,
        requested.deviceGeneration
      ) ? $0 : nil
    }
    let knownRecords = ([scopedCurrent].compactMap { $0 }
      + related.map(\.replacement))
      .filter { $0.reminderID == requested.reminderID }
    let highestRecordRevision = knownRecords.map(\.scheduleRevision).max()
    let highestKnownRevision = [
      highestRecordRevision,
      cancellation.flatMap {
        DangguiAlarmGeneration.matches(
          $0.deviceGeneration,
          requested.deviceGeneration
        ) ? $0.cancelledThroughRevision : nil
      },
    ].compactMap { $0 }.max()

    guard let highestKnownRevision else { return .install }
    if let cancellation,
       DangguiAlarmGeneration.matches(
         cancellation.deviceGeneration,
         requested.deviceGeneration
       ) {
      let permitsSameRevisionRouteReinstall =
        DangguiAlarmCancellationPolicy.permitsSameRevisionRouteReinstall(
          cancellation: cancellation,
          revision: requested.scheduleRevision,
          deviceGeneration: requested.deviceGeneration
        )
      if cancellation.phase != .completed
        || requested.scheduleRevision < cancellation.cancelledThroughRevision
        || (requested.scheduleRevision == cancellation.cancelledThroughRevision
          && !permitsSameRevisionRouteReinstall) {
        return .staleRevision
      }
    }
    if requested.scheduleRevision < highestKnownRevision {
      return .staleRevision
    }
    if requested.scheduleRevision > highestKnownRevision {
      return .install
    }
    let sameRevision = knownRecords.filter {
      $0.scheduleRevision == requested.scheduleRevision
    }
    guard !sameRevision.isEmpty else {
      if DangguiAlarmCancellationPolicy.permitsSameRevisionRouteReinstall(
        cancellation: cancellation,
        revision: requested.scheduleRevision,
        deviceGeneration: requested.deviceGeneration
      ) {
        return .install
      }
      // Equality with a cancellation high-water mark must not resurrect it.
      return .staleRevision
    }
    let matches = sameRevision.allSatisfy {
      $0.platformAlarmID.caseInsensitiveCompare(requested.platformAlarmID) == .orderedSame
        && $0.configurationFingerprint == requested.configurationFingerprint
    }
    return matches ? .idempotent : .revisionConflict
  }

  static func isAuthoritativeAction(
    reminderID: String,
    expectedRevision: Int?,
    expectedPlatformAlarmID: String?,
    current: DangguiAlarmRecord?,
    cancellation: DangguiAlarmCancellation? = nil
  ) -> Bool {
    guard let current, current.reminderID == reminderID else { return false }
    if let cancellation,
       DangguiAlarmGeneration.matches(
         cancellation.deviceGeneration,
         current.deviceGeneration
       ) {
      let permitsSameRevisionRouteReinstall =
        DangguiAlarmCancellationPolicy.permitsSameRevisionRouteReinstall(
          cancellation: cancellation,
          revision: current.scheduleRevision,
          deviceGeneration: current.deviceGeneration
        )
      if cancellation.phase != .completed
        || current.scheduleRevision < cancellation.cancelledThroughRevision
        || (current.scheduleRevision == cancellation.cancelledThroughRevision
          && !permitsSameRevisionRouteReinstall) {
        return false
      }
    }
    guard let expectedRevision,
          current.scheduleRevision == expectedRevision else {
      return false
    }
    guard let expectedPlatformAlarmID, !expectedPlatformAlarmID.isEmpty,
          current.platformAlarmID.caseInsensitiveCompare(expectedPlatformAlarmID) == .orderedSame
    else {
      return false
    }
    return true
  }
}

enum DangguiAlarmCancellationPolicy {
  static let routeRetiredTerminalState = "route-retired"

  static func makeTombstone(
    reminderID: String,
    current: DangguiAlarmRecord?,
    transactions: [DangguiAlarmTransaction],
    existing: DangguiAlarmCancellation?,
    nowEpochMs: Int64
  ) -> DangguiAlarmCancellation {
    let related = transactions.filter { $0.reminderID == reminderID }
    let deviceGeneration: String?
    if let current {
      deviceGeneration = current.deviceGeneration
    } else if let latestTransaction = related.max(by: {
      $0.updatedAtEpochMs < $1.updatedAtEpochMs
    }) {
      deviceGeneration = latestTransaction.replacement.deviceGeneration
    } else {
      deviceGeneration = existing?.deviceGeneration
    }
    let scopedExisting = existing.flatMap {
      DangguiAlarmGeneration.matches($0.deviceGeneration, deviceGeneration)
        ? $0 : nil
    }
    // The revision fence is generation-scoped, while the captured daemon IDs
    // intentionally include every known predecessor so an explicit business
    // cancellation also cleans legacy native remnants.
    var ids = Set(scopedExisting?.platformAlarmIDs ?? [])
    var revisions = [scopedExisting?.cancelledThroughRevision, current?.scheduleRevision]
      .compactMap { $0 }
    if let current { ids.insert(current.platformAlarmID.lowercased()) }
    for transaction in related {
      ids.insert(transaction.replacement.platformAlarmID.lowercased())
      if DangguiAlarmGeneration.matches(
        transaction.replacement.deviceGeneration,
        deviceGeneration
      ) {
        revisions.append(transaction.replacement.scheduleRevision)
      }
      if let previous = transaction.previousPlatformAlarmID {
        ids.insert(previous.lowercased())
      }
      if let previousRecord = transaction.previousRecord {
        if DangguiAlarmGeneration.matches(
          previousRecord.deviceGeneration,
          deviceGeneration
        ) {
          revisions.append(previousRecord.scheduleRevision)
        }
        ids.insert(previousRecord.platformAlarmID.lowercased())
      }
    }
    return DangguiAlarmCancellation(
      reminderID: reminderID,
      deviceGeneration: deviceGeneration,
      cancelledThroughRevision: revisions.max() ?? 0,
      platformAlarmIDs: ids,
      nowEpochMs: nowEpochMs
    )
  }

  static func makeStopTombstone(
    record: DangguiAlarmRecord,
    transactions: [DangguiAlarmTransaction],
    existing: DangguiAlarmCancellation?,
    nowEpochMs: Int64
  ) -> DangguiAlarmCancellation {
    var tombstone = makeTombstone(
      reminderID: record.reminderID,
      current: record,
      transactions: transactions,
      existing: existing,
      nowEpochMs: nowEpochMs
    )
    tombstone.daemonAction = .stop
    tombstone.stopPlatformAlarmID = record.platformAlarmID.lowercased()
    tombstone.terminalState = "stopped"
    tombstone.completionEvent = DangguiAlarmEvent(
      type: .stopped,
      record: record,
      occurredAtEpochMs: nowEpochMs,
      usesStableID: true
    )
    return tombstone
  }

  static func makeRouteRetirementTombstone(
    record: DangguiAlarmRecord,
    currentMirror: DangguiAlarmRecord? = nil,
    transactions: [DangguiAlarmTransaction],
    existing: DangguiAlarmCancellation?,
    nowEpochMs: Int64
  ) -> DangguiAlarmCancellation {
    var tombstone = makeRevisionScopedTerminalTombstone(
      record: record,
      currentMirror: currentMirror,
      transactions: transactions,
      existing: existing,
      nowEpochMs: nowEpochMs
    )
    tombstone.daemonAction = .cancel
    tombstone.stopPlatformAlarmID = nil
    tombstone.completionEvent = nil
    tombstone.terminalState = routeRetiredTerminalState
    return tombstone
  }

  static func permitsSameRevisionRouteReinstall(
    cancellation: DangguiAlarmCancellation?,
    revision: Int,
    deviceGeneration: String?
  ) -> Bool {
    guard let cancellation else { return false }
    return cancellation.phase == .completed
      && cancellation.terminalState == routeRetiredTerminalState
      && cancellation.cancelledThroughRevision == revision
      && DangguiAlarmGeneration.matches(
        cancellation.deviceGeneration,
        deviceGeneration
      )
  }

  /// Once a pending replacement transaction durably owns the exact route,
  /// the completed route-only tombstone can be released before AlarmKit is
  /// touched. This ordering closes the crash window where recovery would
  /// otherwise cancel the newly installed deterministic ID before the
  /// transaction had a chance to remove the old route marker.
  static func transactionOwnsSameRevisionRouteReinstall(
    transaction: DangguiAlarmTransaction,
    cancellation: DangguiAlarmCancellation?
  ) -> Bool {
    let replacement = transaction.replacement
    guard transaction.reminderID == replacement.reminderID,
          permitsSameRevisionRouteReinstall(
            cancellation: cancellation,
            revision: replacement.scheduleRevision,
            deviceGeneration: replacement.deviceGeneration
          ),
          let cancellation else {
      return false
    }
    return cancellation.reminderID == transaction.reminderID
      && cancellation.platformAlarmIDs.contains {
        $0.caseInsensitiveCompare(replacement.platformAlarmID) == .orderedSame
      }
  }

  static func makeMissedTombstone(
    record: DangguiAlarmRecord,
    currentMirror: DangguiAlarmRecord? = nil,
    transactions: [DangguiAlarmTransaction],
    existing: DangguiAlarmCancellation?,
    nowEpochMs: Int64
  ) -> DangguiAlarmCancellation {
    if let existing,
       DangguiAlarmGeneration.matches(
         existing.deviceGeneration,
         record.deviceGeneration
       ),
       existing.cancelledThroughRevision > record.scheduleRevision {
      return existing
    }
    var tombstone = makeRevisionScopedTerminalTombstone(
      record: record,
      currentMirror: currentMirror,
      transactions: transactions,
      existing: existing,
      nowEpochMs: nowEpochMs
    )
    var missed = record
    missed.lastState = DangguiAlarmFailureMapper.state(for: .expired)
    tombstone.terminalState = "missed"
    tombstone.completionEvent = DangguiAlarmEvent(
      type: .missed,
      record: missed,
      state: missed.lastState,
      delayedByMs: max(0, nowEpochMs - missed.triggerAtEpochMs),
      occurredAtEpochMs: nowEpochMs,
      usesStableID: true
    )
    return tombstone
  }

  static func makeObservedRetirementTombstone(
    record: DangguiAlarmRecord,
    currentMirror: DangguiAlarmRecord? = nil,
    transactions: [DangguiAlarmTransaction],
    existing: DangguiAlarmCancellation?,
    nowEpochMs: Int64
  ) -> DangguiAlarmCancellation {
    if let existing,
       DangguiAlarmGeneration.matches(
         existing.deviceGeneration,
         record.deviceGeneration
       ),
       existing.cancelledThroughRevision > record.scheduleRevision {
      return existing
    }
    var tombstone = makeRevisionScopedTerminalTombstone(
      record: record,
      currentMirror: currentMirror,
      transactions: transactions,
      existing: existing,
      nowEpochMs: nowEpochMs
    )
    tombstone.terminalState = "delivered-retired"
    tombstone.completionEvent = nil
    return tombstone
  }

  private static func makeRevisionScopedTerminalTombstone(
    record: DangguiAlarmRecord,
    currentMirror: DangguiAlarmRecord?,
    transactions: [DangguiAlarmTransaction],
    existing: DangguiAlarmCancellation?,
    nowEpochMs: Int64
  ) -> DangguiAlarmCancellation {
    let related = transactions.filter {
      $0.reminderID == record.reminderID
        && DangguiAlarmGeneration.matches(
          $0.replacement.deviceGeneration,
          record.deviceGeneration
        )
        && $0.replacement.scheduleRevision <= record.scheduleRevision
    }
    let scopedExisting = existing.flatMap {
      DangguiAlarmGeneration.matches(
        $0.deviceGeneration,
        record.deviceGeneration
      ) ? $0 : nil
    }
    var ids = Set(scopedExisting?.platformAlarmIDs ?? [])
    ids.insert(record.platformAlarmID.lowercased())
    if let currentMirror,
       currentMirror.reminderID == record.reminderID,
       DangguiAlarmGeneration.matches(
         currentMirror.deviceGeneration,
         record.deviceGeneration
       ),
       currentMirror.scheduleRevision <= record.scheduleRevision {
      ids.insert(currentMirror.platformAlarmID.lowercased())
    }
    for transaction in related {
      ids.insert(transaction.replacement.platformAlarmID.lowercased())
      if let previous = transaction.previousPlatformAlarmID {
        ids.insert(previous.lowercased())
      }
      if let previousRecord = transaction.previousRecord,
         previousRecord.scheduleRevision <= record.scheduleRevision {
        ids.insert(previousRecord.platformAlarmID.lowercased())
      }
    }
    return DangguiAlarmCancellation(
      reminderID: record.reminderID,
      deviceGeneration: record.deviceGeneration,
      cancelledThroughRevision: max(
        record.scheduleRevision,
        scopedExisting?.cancelledThroughRevision ?? 0
      ),
      platformAlarmIDs: ids,
      nowEpochMs: nowEpochMs
    )
  }

  static func activeTargetIDs(
    cancellation: DangguiAlarmCancellation,
    activeIDs: Set<String>
  ) -> [String] {
    cancellation.platformAlarmIDs
      .map { $0.lowercased() }
      .filter(activeIDs.contains)
      .sorted()
  }

  static func allowsRepair(
    record: DangguiAlarmRecord,
    cancellations: [DangguiAlarmCancellation]
  ) -> Bool {
    let related = cancellations.filter {
      $0.reminderID == record.reminderID
        && DangguiAlarmGeneration.matches(
          $0.deviceGeneration,
          record.deviceGeneration
        )
    }
    guard !related.isEmpty else { return true }
    if related.contains(where: { $0.phase != .completed }) { return false }
    let highWater = related.map(\.cancelledThroughRevision).max() ?? 0
    if let sameRevisionRouteRetirement = related.first(where: {
      permitsSameRevisionRouteReinstall(
        cancellation: $0,
        revision: record.scheduleRevision,
        deviceGeneration: record.deviceGeneration
      )
    }), sameRevisionRouteRetirement.cancelledThroughRevision == highWater {
      return record.scheduleRevision >= highWater
    }
    return record.scheduleRevision > highWater
  }

  static func isSupersededByCompletedCancellation(
    record: DangguiAlarmRecord,
    cancellations: [DangguiAlarmCancellation]
  ) -> Bool {
    let completed = cancellations.filter {
      $0.reminderID == record.reminderID
        && DangguiAlarmGeneration.matches(
          $0.deviceGeneration,
          record.deviceGeneration
        )
        && $0.phase == .completed
    }
    guard let completedHighWater = completed.map(\.cancelledThroughRevision).max()
    else { return false }
    if completed.contains(where: {
      permitsSameRevisionRouteReinstall(
        cancellation: $0,
        revision: record.scheduleRevision,
        deviceGeneration: record.deviceGeneration
      )
    }), record.scheduleRevision == completedHighWater {
      return false
    }
    return record.scheduleRevision <= completedHighWater
  }
}

struct DangguiAlarmSnoozePlan: Equatable {
  let replacement: DangguiAlarmRecord
  let completionEvent: DangguiAlarmEvent
}

enum DangguiAlarmSnoozePolicy {
  static func hasUnresolvedTransaction(
    reminderID: String,
    deviceGeneration: String? = nil,
    transactions: [DangguiAlarmTransaction]
  ) -> Bool {
    transactions.contains {
      $0.reminderID == reminderID
        && DangguiAlarmGeneration.matches(
          $0.replacement.deviceGeneration,
          deviceGeneration
        )
        && !($0.ownsMissingRecovery == true && $0.phase == .retired)
    }
  }

  static func makePlan(
    record: DangguiAlarmRecord,
    minutes: Int,
    occurredAtEpochMs: Int64
  ) -> DangguiAlarmSnoozePlan {
    let successorTriggerAtEpochMs = occurredAtEpochMs + Int64(minutes * 60 * 1_000)
    var replacement = record
    replacement.scheduleRevision += 1
    replacement.platformAlarmID = DangguiAlarmIdentifier.platformID(
      for: replacement.reminderID,
      revision: replacement.scheduleRevision,
      deviceGeneration: replacement.deviceGeneration
    )
    replacement.triggerAtEpochMs = successorTriggerAtEpochMs
    replacement.lastState = "pending"
    replacement.firedEventRecorded = false
    let event = DangguiAlarmEvent(
      type: .snoozed,
      record: record,
      snoozeMinutes: minutes,
      occurredAtEpochMs: occurredAtEpochMs,
      successorTriggerAtEpochMs: successorTriggerAtEpochMs,
      usesStableID: true
    )
    return DangguiAlarmSnoozePlan(replacement: replacement, completionEvent: event)
  }

  static func shouldStopPredecessor(
    transaction: DangguiAlarmTransaction
  ) -> Bool {
    transaction.stopPreviousWhenConfirmed == true && transaction.phase == .confirmed
  }
}

enum DangguiMissingAlarmDecision: Equatable {
  case recoverScheduled
  case recoverLate
  case retireObserved
  case missed
}

enum DangguiAlarmRecoveryPolicy {
  static let lateRecoveryWindowMs: Int64 = 15 * 60 * 1_000

  static func isExpired(triggerAtEpochMs: Int64, nowEpochMs: Int64) -> Bool {
    nowEpochMs - triggerAtEpochMs > lateRecoveryWindowMs
  }

  static func effectiveTriggerDate(triggerAtEpochMs: Int64, now: Date) -> Date {
    let requested = Date(timeIntervalSince1970: TimeInterval(triggerAtEpochMs) / 1_000)
    return max(requested, now.addingTimeInterval(1))
  }

  static func missingAlarmDecision(
    triggerAtEpochMs: Int64,
    nowEpochMs: Int64,
    observedDelivered: Bool = false
  ) -> DangguiMissingAlarmDecision {
    if observedDelivered { return .retireObserved }
    if triggerAtEpochMs > nowEpochMs { return .recoverScheduled }
    return isExpired(triggerAtEpochMs: triggerAtEpochMs, nowEpochMs: nowEpochMs)
      ? .missed
      : .recoverLate
  }

  static func shouldRetryMissingTransaction(
    ownsMissingRecovery: Bool,
    triggerAtEpochMs: Int64,
    nowEpochMs: Int64
  ) -> Bool {
    !ownsMissingRecovery || triggerAtEpochMs > nowEpochMs
  }

  static func shouldPersistRecoveryFailure(
    transactionID: String,
    transactions: [DangguiAlarmTransaction]
  ) -> Bool {
    transactions.contains { $0.transactionID == transactionID }
  }
}

enum DangguiAlarmDeliveryRecorder {
  static func recordDeliveredIfNeeded(
    _ record: inout DangguiAlarmRecord,
    delayedByMs: Int64? = nil
  ) throws {
    guard !record.firedEventRecorded else { return }
    // `delivered` changes durable Dart state, so it must never use the
    // best-effort diagnostic append path. Its stable ID makes the business
    // write safe to retry; the separate systemAlert diagnostic cannot block
    // the durable fired marker.
    try DangguiAlarmStore.appendEventDurably(
      DangguiAlarmEvent(
        type: .delivered,
        record: record,
        state: "ringing",
        delayedByMs: delayedByMs,
        usesStableID: true
      )
    )
    DangguiAlarmStore.appendEvent(
      DangguiAlarmEvent(
        type: .systemAlert,
        record: record,
        state: "ringing",
        delayedByMs: delayedByMs,
        usesStableID: true
      )
    )
    record.firedEventRecorded = true
    try DangguiAlarmStore.upsert(record)
  }
}

enum DangguiAlarmBridgeError: LocalizedError {
  case invalidArguments
  case missingReminderID
  case missingTriggerDate
  case invalidTriggerDate
  case invalidScheduleRevision
  case invalidDeviceGeneration
  case inactiveDeviceGeneration
  case alarmNotFound
  case invalidPlatformAlarmID
  case invalidTransactionTransition
  case invalidCancellationTransition
  case authoritativeStoreCorrupt
  case businessEventCapacityExceeded

  var errorDescription: String? {
    switch self {
    case .invalidArguments:
      return "Alarm arguments must be a map."
    case .missingReminderID:
      return "A non-empty reminderId is required."
    case .missingTriggerDate:
      return "A triggerAtEpochMs value is required."
    case .invalidTriggerDate:
      return "The alarm trigger must be a positive epoch timestamp."
    case .invalidScheduleRevision:
      return "A positive alarm schedule revision is required."
    case .invalidDeviceGeneration:
      return "deviceGeneration must be a UUID when present."
    case .inactiveDeviceGeneration:
      return "The alarm belongs to a database generation that is not active."
    case .alarmNotFound:
      return "The requested alarm is not scheduled."
    case .invalidPlatformAlarmID:
      return "The stored AlarmKit identifier is invalid."
    case .invalidTransactionTransition:
      return "The persisted alarm transaction has an invalid state transition."
    case .invalidCancellationTransition:
      return "The persisted alarm cancellation has an invalid state transition."
    case .authoritativeStoreCorrupt:
      return "Persisted alarm state is corrupt and has no complete last-known-good image."
    case .businessEventCapacityExceeded:
      return "Unacknowledged alarm actions must be synchronized before more can be recorded."
    }
  }
}

enum DangguiAlarmFailureKind: Equatable {
  case capacity
  case expired
  case verification
  case other
}

enum DangguiAlarmOperationError: LocalizedError {
  case capacityDeferred
  case expired
  case verificationFailed
  case staleRevision
  case revisionConflict
  case operationInProgress

  var errorDescription: String? {
    switch self {
    case .capacityDeferred:
      return "AlarmKit has reached its scheduled alarm limit; the reminder is queued for repair."
    case .expired:
      return "The reminder is more than 15 minutes late and will not be recreated."
    case .verificationFailed:
      return "AlarmKit did not confirm the replacement alarm."
    case .staleRevision:
      return "The requested alarm revision is older than durable native state."
    case .revisionConflict:
      return "The requested alarm revision conflicts with different immutable content."
    case .operationInProgress:
      return "A durable alarm replacement is still unresolved; retry after recovery completes."
    }
  }
}

enum DangguiAlarmFailureMapper {
  static func state(for kind: DangguiAlarmFailureKind) -> String {
    switch kind {
    case .capacity:
      return "capacity-deferred"
    case .expired:
      return "missed"
    case .verification:
      return "repair-pending"
    case .other:
      return "error"
    }
  }

  static func flutterError(
    for error: Error,
    fallbackCode: String
  ) -> (code: String, message: String, details: Any?) {
    let message = error.localizedDescription
    if let bridgeError = error as? DangguiAlarmBridgeError {
      switch bridgeError {
      case .authoritativeStoreCorrupt:
        return (
          "authoritative_store_corrupt",
          message,
          ["state": "repair-pending"]
        )
      case .businessEventCapacityExceeded:
        return (
          "business_event_backpressure",
          message,
          ["state": "sync-required"]
        )
      case .inactiveDeviceGeneration:
        return (
          "inactive_device_generation",
          message,
          ["state": "stale-generation"]
        )
      default:
        return (fallbackCode, message, nil)
      }
    }
    guard let operationError = error as? DangguiAlarmOperationError else {
      return (fallbackCode, message, nil)
    }
    switch operationError {
    case .capacityDeferred:
      return (
        "capacity_deferred",
        message,
        ["state": state(for: .capacity)]
      )
    case .expired:
      return (
        "alarm_missed",
        message,
        ["state": state(for: .expired)]
      )
    case .verificationFailed:
      return (
        "alarm_verification_failed",
        message,
        ["state": state(for: .verification)]
      )
    case .staleRevision:
      return ("stale_revision", message, ["state": "stale-revision"])
    case .revisionConflict:
      return ("revision_conflict", message, ["state": "revision-conflict"])
    case .operationInProgress:
      return ("operation_in_progress", message, ["state": "repair-pending"])
    }
  }
}

private struct DangguiLossyValue<Value: Decodable>: Decodable {
  let value: Value?

  init(from decoder: Decoder) throws {
    value = try? Value(from: decoder)
  }
}

private struct DangguiLossyArray<Value> {
  let values: [Value]
  let isComplete: Bool
}

enum DangguiAlarmStore {
  private static let lock = NSLock()
  private static let legacyRecordsKey = "danggui.nativeAlarms.records.v1"
  private static let legacyEventsKey = "danggui.nativeAlarms.events.v1"
  private static let recordsFilename = "native-alarms-v2.json"
  /// v1.1.4 stored business actions and lossy diagnostics together here.
  /// It remains a strict, read-only migration source once v1.1.5 creates the
  /// separated stores below.
  private static let legacyMixedEventsFilename = "alarm-events-v2.json"
  private static let businessEventsFilename = "alarm-business-events-v1.json"
  private static let diagnosticEventsFilename = "alarm-diagnostics-v1.json"
  private static let transactionsFilename = "alarm-transactions-v1.json"
  private static let cancellationsFilename = "alarm-cancellations-v1.json"
  private static let activeGenerationFilename = "alarm-active-generation-v1.json"
  private static let maximumDiagnosticEvents = 200
  /// This is a back-pressure threshold, never an eviction threshold. Stable
  /// IDs deduplicate retries, and a full unacknowledged business queue causes
  /// the owning tombstone/transaction to remain retryable instead of silently
  /// dropping a Stop, Snooze, Missed, or Delivered transition.
  private static let maximumBusinessEvents = 4_096
  private static var baseDirectoryOverride: URL?

  static func assertAuthoritativeStoresHealthy() throws {
    try withLock { try assertAuthoritativeStoresHealthyUnlocked() }
  }

  /// Missing state is the v1.1.4 legacy generation. Once a replacement
  /// generation is activated, the one-element authoritative image makes that
  /// decision durable before any obsolete daemon route is retired.
  static func activeDeviceGeneration() throws -> String? {
    try withLock {
      try assertAuthoritativeStoresHealthyUnlocked()
      return loadActiveGenerationUnlocked()
    }
  }

  static func activeGenerationMatches(_ deviceGeneration: String?) throws -> Bool {
    try withLock {
      try assertAuthoritativeStoresHealthyUnlocked()
      return DangguiAlarmGeneration.matches(
        loadActiveGenerationUnlocked(),
        deviceGeneration
      )
    }
  }

  static func activateDeviceGeneration(_ deviceGeneration: String?) throws {
    try withLock {
      guard DangguiAlarmGeneration.isValid(deviceGeneration) else {
        throw DangguiAlarmBridgeError.invalidDeviceGeneration
      }
      try assertAuthoritativeStoresHealthyUnlocked()
      if DangguiAlarmGeneration.matches(
        loadActiveGenerationUnlocked(),
        deviceGeneration
      ), authoritativeFileImageExistsUnlocked(
        filename: activeGenerationFilename
      ) {
        return
      }
      let state = DangguiAlarmActiveGenerationState(
        deviceGeneration: deviceGeneration,
        updatedAtEpochMs: Int64(Date().timeIntervalSince1970 * 1_000)
      )
      try saveArrayUnlocked(
        [state],
        filename: activeGenerationFilename,
        authoritative: false
      )
    }
  }

  static func inactiveRoutePlatformAlarmIDs() throws -> Set<String> {
    try withLock {
      try assertAuthoritativeStoresHealthyUnlocked()
      return DangguiAlarmGenerationActivationPolicy.inactivePlatformAlarmIDs(
        records: loadRecordsUnlocked(),
        transactions: loadTransactionsUnlocked(),
        cancellations: loadCancellationsUnlocked(),
        activeDeviceGeneration: loadActiveGenerationUnlocked()
      )
    }
  }

  static func records() -> [DangguiAlarmRecord] {
    withLock { loadRecordsUnlocked() }
  }

  static func record(reminderID: String) -> DangguiAlarmRecord? {
    withLock {
      loadRecordsUnlocked().first { $0.reminderID == reminderID }
    }
  }

  static func record(platformAlarmID: String) -> DangguiAlarmRecord? {
    withLock {
      loadRecordsUnlocked().first(where: {
        $0.platformAlarmID.caseInsensitiveCompare(platformAlarmID) == .orderedSame
      })
    }
  }

  static func authoritativeActionRecord(
    reminderID: String,
    scheduleRevision: Int,
    platformAlarmID: String
  ) -> DangguiAlarmRecord? {
    withLock {
      guard (try? assertAuthoritativeStoresHealthyUnlocked()) != nil else {
        return nil
      }
      let current = loadRecordsUnlocked().first { $0.reminderID == reminderID }
      let transactions = loadTransactionsUnlocked().filter {
        $0.reminderID == reminderID
      }
      let candidates = ([current].compactMap { $0 } + transactions.map(\.replacement))
      guard let candidate = candidates.first(where: {
              $0.scheduleRevision == scheduleRevision
                && $0.platformAlarmID.caseInsensitiveCompare(platformAlarmID) == .orderedSame
            }) else {
        return nil
      }
      guard DangguiAlarmGeneration.matches(
        candidate.deviceGeneration,
        loadActiveGenerationUnlocked()
      ) else {
        return nil
      }
      let generationCandidates = candidates.filter {
        DangguiAlarmGeneration.matches(
          $0.deviceGeneration,
          candidate.deviceGeneration
        )
      }
      guard let highestRevision = generationCandidates.map(\.scheduleRevision).max(),
            highestRevision == scheduleRevision,
            current.map({ currentRecord in
              DangguiAlarmGeneration.matches(
                currentRecord.deviceGeneration,
                candidate.deviceGeneration
              ) || transactions.contains(where: { transaction in
                transaction.replacement.platformAlarmID.caseInsensitiveCompare(
                  candidate.platformAlarmID
                ) == .orderedSame
                  && transaction.previousPlatformAlarmID?.caseInsensitiveCompare(
                    currentRecord.platformAlarmID
                  ) == .orderedSame
              })
            }) ?? true else {
        return nil
      }
      let isSupersededByCrossGenerationHandoff = transactions.contains {
        !DangguiAlarmGeneration.matches(
          $0.replacement.deviceGeneration,
          candidate.deviceGeneration
        )
          && $0.previousPlatformAlarmID?.caseInsensitiveCompare(
            candidate.platformAlarmID
          ) == .orderedSame
      }
      guard !isSupersededByCrossGenerationHandoff else { return nil }
      guard DangguiAlarmActionIdentity(
        reminderID: reminderID,
        scheduleRevision: scheduleRevision,
        platformAlarmID: platformAlarmID
      ).matches(candidate) else {
        return nil
      }
      if let cancellation = loadCancellationsUnlocked().first(where: {
        $0.reminderID == reminderID
          && DangguiAlarmGeneration.matches(
            $0.deviceGeneration,
            candidate.deviceGeneration
          )
      }) {
        let permitsSameRevisionRouteReinstall =
          DangguiAlarmCancellationPolicy.permitsSameRevisionRouteReinstall(
            cancellation: cancellation,
            revision: scheduleRevision,
            deviceGeneration: candidate.deviceGeneration
          )
        guard cancellation.phase == .completed,
              scheduleRevision > cancellation.cancelledThroughRevision
                || permitsSameRevisionRouteReinstall else {
          return nil
        }
      }
      return candidate
    }
  }

  static func upsert(_ record: DangguiAlarmRecord) throws {
    try withLock {
      try assertAuthoritativeStoresHealthyUnlocked()
      var records = loadRecordsUnlocked()
      records.removeAll { $0.reminderID == record.reminderID }
      records.append(record)
      try saveRecordsUnlocked(records)
    }
  }

  @discardableResult
  static func remove(reminderID: String) throws -> DangguiAlarmRecord? {
    try withLock {
      try assertAuthoritativeStoresHealthyUnlocked()
      var records = loadRecordsUnlocked()
      guard let index = records.firstIndex(where: { $0.reminderID == reminderID }) else {
        return nil
      }
      let removed = records.remove(at: index)
      try saveRecordsUnlocked(records)
      return removed
    }
  }

  @discardableResult
  static func remove(
    reminderID: String,
    deviceGeneration: String?
  ) throws -> DangguiAlarmRecord? {
    try withLock {
      try assertAuthoritativeStoresHealthyUnlocked()
      var records = loadRecordsUnlocked()
      guard let index = records.firstIndex(where: {
        $0.reminderID == reminderID
          && DangguiAlarmGeneration.matches(
            $0.deviceGeneration,
            deviceGeneration
          )
      }) else {
        return nil
      }
      let removed = records.remove(at: index)
      try saveRecordsUnlocked(records)
      return removed
    }
  }

  static func transactions() -> [DangguiAlarmTransaction] {
    withLock { loadTransactionsUnlocked() }
  }

  static func upsertTransaction(_ transaction: DangguiAlarmTransaction) throws {
    try withLock {
      try assertAuthoritativeStoresHealthyUnlocked()
      var transactions = loadTransactionsUnlocked()
      transactions.removeAll { $0.transactionID == transaction.transactionID }
      transactions.append(transaction)
      try saveTransactionsUnlocked(transactions)
    }
  }

  static func replaceTransactionsAtomically(
    reminderID: String,
    removingTransactionIDs: Set<String>,
    adding transaction: DangguiAlarmTransaction
  ) throws {
    try withLock {
      try assertAuthoritativeStoresHealthyUnlocked()
      var transactions = loadTransactionsUnlocked()
      transactions.removeAll {
        $0.reminderID == reminderID
          && removingTransactionIDs.contains($0.transactionID)
      }
      transactions.removeAll { $0.transactionID == transaction.transactionID }
      transactions.append(transaction)
      // One atomic authoritative file replacement means a crash observes
      // either every predecessor owner or the complete successor transaction.
      try saveTransactionsUnlocked(transactions)
    }
  }

  static func removeTransaction(transactionID: String) throws {
    try withLock {
      try assertAuthoritativeStoresHealthyUnlocked()
      let remaining = loadTransactionsUnlocked().filter {
        $0.transactionID != transactionID
      }
      try saveTransactionsUnlocked(remaining)
    }
  }

  static func removeTransactions(reminderID: String) throws {
    try withLock {
      try assertAuthoritativeStoresHealthyUnlocked()
      let remaining = loadTransactionsUnlocked().filter {
        $0.reminderID != reminderID
      }
      try saveTransactionsUnlocked(remaining)
    }
  }

  static func removeTransactions(
    reminderID: String,
    deviceGeneration: String?
  ) throws {
    try withLock {
      try assertAuthoritativeStoresHealthyUnlocked()
      let remaining = loadTransactionsUnlocked().filter {
        $0.reminderID != reminderID
          || !DangguiAlarmGeneration.matches(
            $0.replacement.deviceGeneration,
            deviceGeneration
          )
      }
      try saveTransactionsUnlocked(remaining)
    }
  }

  static func removeRecordsAndTransactions(
    reminderID: String,
    platformAlarmIDs: Set<String>
  ) throws {
    try withLock {
      try assertAuthoritativeStoresHealthyUnlocked()
      let normalizedIDs = Set(platformAlarmIDs.map { $0.lowercased() })
      var records = loadRecordsUnlocked()
      records.removeAll {
        $0.reminderID == reminderID
          && normalizedIDs.contains($0.platformAlarmID.lowercased())
      }
      var transactions = loadTransactionsUnlocked()
      transactions.removeAll {
        $0.reminderID == reminderID
          && normalizedIDs.contains($0.replacement.platformAlarmID.lowercased())
      }
      // Both files remain individually atomic. The durable cancellation
      // tombstone is written first and remains authoritative across a crash
      // between these two derived-state updates.
      try saveRecordsUnlocked(records)
      try saveTransactionsUnlocked(transactions)
    }
  }

  static func cancellations() -> [DangguiAlarmCancellation] {
    withLock { loadCancellationsUnlocked() }
  }

  static func cancellation(reminderID: String) -> DangguiAlarmCancellation? {
    withLock {
      loadCancellationsUnlocked()
        .filter { $0.reminderID == reminderID }
        .max { $0.updatedAtEpochMs < $1.updatedAtEpochMs }
    }
  }

  static func cancellation(
    reminderID: String,
    deviceGeneration: String?
  ) -> DangguiAlarmCancellation? {
    withLock {
      loadCancellationsUnlocked().first {
        $0.reminderID == reminderID
          && DangguiAlarmGeneration.matches(
            $0.deviceGeneration,
            deviceGeneration
          )
      }
    }
  }

  static func upsertCancellation(_ cancellation: DangguiAlarmCancellation) throws {
    try withLock {
      try assertAuthoritativeStoresHealthyUnlocked()
      var cancellations = loadCancellationsUnlocked()
      cancellations.removeAll {
        $0.reminderID == cancellation.reminderID
          && DangguiAlarmGeneration.matches(
            $0.deviceGeneration,
            cancellation.deviceGeneration
          )
      }
      cancellations.append(cancellation)
      try saveCancellationsUnlocked(cancellations)
    }
  }

  static func removeCancellation(
    reminderID: String,
    deviceGeneration: String? = nil
  ) throws {
    try withLock {
      try assertAuthoritativeStoresHealthyUnlocked()
      let remaining = loadCancellationsUnlocked().filter {
        $0.reminderID != reminderID
          || !DangguiAlarmGeneration.matches(
            $0.deviceGeneration,
            deviceGeneration
          )
      }
      try saveCancellationsUnlocked(remaining)
    }
  }

  static func appendEvent(_ event: DangguiAlarmEvent) {
    do {
      try appendEventDurably(event)
    } catch {
      NSLog("Danggui could not persist an alarm diagnostic event.")
    }
  }

  static func appendEventDurably(_ event: DangguiAlarmEvent) throws {
    try withLock {
      try ensureEventStoresMigratedUnlocked()
      if event.mutatesBusinessState {
        // This outbox is authoritative: corruption in its primary image blocks
        // every mutation even when a complete backup can still be shown for
        // diagnosis. No terminal transition may be inferred away.
        try assertAuthoritativeStoresHealthyUnlocked()
        var events = loadBusinessEventsUnlocked()
        let alreadyExists = events.contains { $0.eventID == event.eventID }
        let generationEventCount = events.lazy.filter {
          DangguiAlarmGeneration.matches(
            $0.deviceGeneration,
            event.deviceGeneration
          )
        }.count
        if !alreadyExists, generationEventCount >= maximumBusinessEvents {
          throw DangguiAlarmBridgeError.businessEventCapacityExceeded
        }
        events.removeAll { $0.eventID == event.eventID }
        events.append(event)
        try saveBusinessEventsUnlocked(events)
      } else {
        var diagnostics = loadDiagnosticEventsUnlocked()
        diagnostics.removeAll { $0.eventID == event.eventID }
        diagnostics.append(event)
        try saveDiagnosticEventsUnlocked(diagnostics)
      }
    }
  }

  static func events() -> [DangguiAlarmEvent] {
    withLock {
      do {
        try ensureEventStoresMigratedUnlocked()
      } catch {
        // A strict LKG may still be exposed for diagnosis and delivery retry,
        // but the corrupt primary remains untouched and all writes fail closed.
      }
      return loadBusinessEventsUnlocked() + loadDiagnosticEventsUnlocked()
    }
  }

  static func activeEvents() -> [DangguiAlarmEvent] {
    (try? activeEventsDurably()) ?? []
  }

  static func activeEventsDurably() throws -> [DangguiAlarmEvent] {
    try withLock {
      try assertAuthoritativeStoresHealthyUnlocked()
      try ensureEventStoresMigratedUnlocked()
      let activeGeneration = loadActiveGenerationUnlocked()
      return (loadBusinessEventsUnlocked() + loadDiagnosticEventsUnlocked())
        .filter {
          DangguiAlarmGeneration.matches(
            $0.deviceGeneration,
            activeGeneration
          )
        }
    }
  }

  static func acknowledgeEvents(_ eventIDs: Set<String>) {
    guard !eventIDs.isEmpty else { return }
    withLock {
      do {
        try ensureEventStoresMigratedUnlocked()
        try assertAuthoritativeStoresHealthyUnlocked()
        let remainingBusiness = loadBusinessEventsUnlocked().filter {
          !eventIDs.contains($0.eventID)
        }
        let remainingDiagnostics = loadDiagnosticEventsUnlocked().filter {
          !eventIDs.contains($0.eventID)
        }
        try saveBusinessEventsUnlocked(remainingBusiness)
        try saveDiagnosticEventsUnlocked(remainingDiagnostics)
      } catch {
        NSLog("Danggui could not acknowledge alarm events.")
      }
    }
  }

  static func acknowledgeActiveEvents(_ eventIDs: Set<String>) {
    do {
      try acknowledgeActiveEventsDurably(eventIDs)
    } catch {
      NSLog("Danggui could not acknowledge active alarm events.")
    }
  }

  static func acknowledgeActiveEventsDurably(
    _ eventIDs: Set<String>
  ) throws {
    guard !eventIDs.isEmpty else { return }
    try withLock {
      try ensureEventStoresMigratedUnlocked()
      try assertAuthoritativeStoresHealthyUnlocked()
      let activeGeneration = loadActiveGenerationUnlocked()
      let activeEventIDs = Set(
        (loadBusinessEventsUnlocked() + loadDiagnosticEventsUnlocked())
          .filter {
            DangguiAlarmGeneration.matches(
              $0.deviceGeneration,
              activeGeneration
            )
          }
          .map(\.eventID)
      )
      let acknowledgedIDs = eventIDs.intersection(activeEventIDs)
      guard !acknowledgedIDs.isEmpty else { return }
      try saveBusinessEventsUnlocked(
        loadBusinessEventsUnlocked().filter {
          !acknowledgedIDs.contains($0.eventID)
        }
      )
      try saveDiagnosticEventsUnlocked(
        loadDiagnosticEventsUnlocked().filter {
          !acknowledgedIDs.contains($0.eventID)
        }
      )
    }
  }

  /// Internal test seam; production callers always use Application Support.
  static func setBaseDirectoryForTesting(_ directoryURL: URL?) {
    withLock { baseDirectoryOverride = directoryURL }
  }

  static func replaceRecordsDataForTesting(_ data: Data) throws {
    try withLock {
      let url = try fileURLUnlocked(filename: recordsFilename)
      try data.write(to: url, options: .atomic)
    }
  }

  static func replaceTransactionsDataForTesting(_ data: Data) throws {
    try withLock {
      let url = try fileURLUnlocked(filename: transactionsFilename)
      try data.write(to: url, options: .atomic)
    }
  }

  static func replaceCancellationsDataForTesting(_ data: Data) throws {
    try withLock {
      let url = try fileURLUnlocked(filename: cancellationsFilename)
      try data.write(to: url, options: .atomic)
    }
  }

  static func replaceBusinessEventsDataForTesting(_ data: Data) throws {
    try withLock {
      let url = try fileURLUnlocked(filename: businessEventsFilename)
      try data.write(to: url, options: .atomic)
    }
  }

  static func replaceLegacyMixedEventsDataForTesting(_ data: Data) throws {
    try withLock {
      let url = try fileURLUnlocked(filename: legacyMixedEventsFilename)
      try data.write(to: url, options: .atomic)
    }
  }

  static func replaceActiveGenerationDataForTesting(_ data: Data) throws {
    try withLock {
      let url = try fileURLUnlocked(filename: activeGenerationFilename)
      try data.write(to: url, options: .atomic)
    }
  }

  private static func withLock<T>(_ body: () throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    return try body()
  }

  private static func loadActiveGenerationUnlocked() -> String? {
    guard authoritativeFileImageExistsUnlocked(
      filename: activeGenerationFilename
    ) else {
      return nil
    }
    return loadArrayUnlocked(
      DangguiAlarmActiveGenerationState.self,
      filename: activeGenerationFilename,
      allowLossy: false,
      semanticValidator: activeGenerationStatesAreSemanticallyValid
    )?.first?.deviceGeneration
  }

  private static func activeGenerationStatesAreSemanticallyValid(
    _ states: [DangguiAlarmActiveGenerationState]
  ) -> Bool {
    states.count == 1
      && states[0].updatedAtEpochMs > 0
      && DangguiAlarmGeneration.isValid(states[0].deviceGeneration)
  }

  private static func loadRecordsUnlocked() -> [DangguiAlarmRecord] {
    if let records = loadArrayUnlocked(
      DangguiAlarmRecord.self,
      filename: recordsFilename,
      allowLossy: false,
      semanticValidator: recordsAreSemanticallyValid
    ) {
      return records
    }
    guard let legacy = UserDefaults.standard.data(forKey: legacyRecordsKey) else {
      return []
    }
    guard let migrated = decodeLossyArray(DangguiAlarmRecord.self, from: legacy) else {
      return []
    }
    guard migrated.isComplete, recordsAreSemanticallyValid(migrated.values)
    else { return [] }
    do {
      try saveRecordsUnlocked(migrated.values)
      UserDefaults.standard.removeObject(forKey: legacyRecordsKey)
    } catch {
      NSLog("Danggui could not migrate the legacy alarm mirror.")
    }
    return migrated.values
  }

  private static func saveRecordsUnlocked(_ records: [DangguiAlarmRecord]) throws {
    guard recordsAreSemanticallyValid(records) else {
      throw DangguiAlarmBridgeError.authoritativeStoreCorrupt
    }
    try saveArrayUnlocked(records, filename: recordsFilename, authoritative: true)
  }

  private static func loadBusinessEventsUnlocked() -> [DangguiAlarmEvent] {
    if authoritativeFileImageExistsUnlocked(filename: businessEventsFilename) {
      return loadArrayUnlocked(
        DangguiAlarmEvent.self,
        filename: businessEventsFilename,
        allowLossy: false,
        semanticValidator: businessEventsAreSemanticallyValid
      ) ?? []
    }
    return strictLegacyMixedEventsForReadingUnlocked()
      .filter(\.mutatesBusinessState)
  }

  private static func saveBusinessEventsUnlocked(
    _ events: [DangguiAlarmEvent]
  ) throws {
    guard businessEventsAreSemanticallyValid(events) else {
      throw DangguiAlarmBridgeError.authoritativeStoreCorrupt
    }
    // Callers have already passed the complete authoritative health gate.
    // Avoid recursively invoking it while the first migration image is being
    // established; saveArray still provides atomic primary/LKG replacement.
    try saveArrayUnlocked(
      events,
      filename: businessEventsFilename,
      authoritative: false
    )
  }

  private static func loadDiagnosticEventsUnlocked() -> [DangguiAlarmEvent] {
    if authoritativeFileImageExistsUnlocked(filename: businessEventsFilename) {
      let diagnostics = loadArrayUnlocked(
        DangguiAlarmEvent.self,
        filename: diagnosticEventsFilename,
        allowLossy: true
      ) ?? []
      return normalizedDiagnosticEvents(diagnostics)
    }
    return normalizedDiagnosticEvents(
      strictLegacyMixedEventsForReadingUnlocked().filter {
        !$0.mutatesBusinessState
      }
    )
  }

  private static func saveDiagnosticEventsUnlocked(
    _ events: [DangguiAlarmEvent]
  ) throws {
    try saveArrayUnlocked(
      normalizedDiagnosticEvents(events),
      filename: diagnosticEventsFilename,
      authoritative: false
    )
  }

  private static func normalizedDiagnosticEvents(
    _ events: [DangguiAlarmEvent]
  ) -> [DangguiAlarmEvent] {
    // Keep the newest image for a stable retry ID while preserving the journal
    // order of distinct events.
    var lastIndexByID: [String: Int] = [:]
    for (index, event) in events.enumerated() {
      lastIndexByID[event.eventID] = index
    }
    let deduplicated = events.enumerated().compactMap { index, event in
      lastIndexByID[event.eventID] == index ? event : nil
    }
    return Array(
      deduplicated.lazy
        .filter { !$0.mutatesBusinessState }
        .suffix(maximumDiagnosticEvents)
    )
  }

  private static func ensureEventStoresMigratedUnlocked() throws {
    if authoritativeFileImageExistsUnlocked(filename: businessEventsFilename) {
      guard authoritativeFileIsHealthyUnlocked(
        DangguiAlarmEvent.self,
        filename: businessEventsFilename,
        semanticValidator: businessEventsAreSemanticallyValid
      ) else {
        throw DangguiAlarmBridgeError.authoritativeStoreCorrupt
      }
      return
    }

    let manager = FileManager.default
    let mixedURL = try fileURLUnlocked(filename: legacyMixedEventsFilename)
    let mixedBackupURL = backupURL(for: mixedURL)
    let hasMixedImage = manager.fileExists(atPath: mixedURL.path)
      || manager.fileExists(atPath: mixedBackupURL.path)
    let legacyData = UserDefaults.standard.data(forKey: legacyEventsKey)

    let sourceEvents: [DangguiAlarmEvent]
    if hasMixedImage {
      // A backup without a primary, or any incomplete primary, is evidence of
      // an interrupted terminal write. It may be read as an LKG below but must
      // never be promoted into the new authoritative outbox.
      guard manager.fileExists(atPath: mixedURL.path),
            let data = try? Data(contentsOf: mixedURL),
            let decoded = decodeLossyArray(DangguiAlarmEvent.self, from: data),
            decoded.isComplete,
            mixedEventsAreSemanticallyValid(decoded.values) else {
        throw DangguiAlarmBridgeError.authoritativeStoreCorrupt
      }
      sourceEvents = decoded.values
    } else if let legacyData {
      guard let decoded = decodeLossyArray(
        DangguiAlarmEvent.self,
        from: legacyData
      ), decoded.isComplete,
         mixedEventsAreSemanticallyValid(decoded.values) else {
        throw DangguiAlarmBridgeError.authoritativeStoreCorrupt
      }
      sourceEvents = decoded.values
    } else {
      sourceEvents = []
    }

    try saveBusinessEventsUnlocked(
      sourceEvents.filter(\.mutatesBusinessState)
    )
    try saveDiagnosticEventsUnlocked(
      sourceEvents.filter { !$0.mutatesBusinessState }
    )
    if legacyData != nil {
      UserDefaults.standard.removeObject(forKey: legacyEventsKey)
    }
  }

  private static func strictLegacyMixedEventsForReadingUnlocked()
    -> [DangguiAlarmEvent] {
    if let events = loadArrayUnlocked(
      DangguiAlarmEvent.self,
      filename: legacyMixedEventsFilename,
      allowLossy: false,
      semanticValidator: mixedEventsAreSemanticallyValid
    ) {
      return events
    }
    guard let legacy = UserDefaults.standard.data(forKey: legacyEventsKey),
          let decoded = decodeLossyArray(DangguiAlarmEvent.self, from: legacy),
          decoded.isComplete,
          mixedEventsAreSemanticallyValid(decoded.values) else {
      return []
    }
    return decoded.values
  }

  private static func loadTransactionsUnlocked() -> [DangguiAlarmTransaction] {
    loadArrayUnlocked(
      DangguiAlarmTransaction.self,
      filename: transactionsFilename,
      allowLossy: false,
      semanticValidator: transactionsAreSemanticallyValid
    ) ?? []
  }

  private static func saveTransactionsUnlocked(
    _ transactions: [DangguiAlarmTransaction]
  ) throws {
    guard transactionsAreSemanticallyValid(transactions) else {
      throw DangguiAlarmBridgeError.authoritativeStoreCorrupt
    }
    try saveArrayUnlocked(
      transactions,
      filename: transactionsFilename,
      authoritative: true
    )
  }

  private static func loadCancellationsUnlocked() -> [DangguiAlarmCancellation] {
    loadArrayUnlocked(
      DangguiAlarmCancellation.self,
      filename: cancellationsFilename,
      allowLossy: false,
      semanticValidator: cancellationsAreSemanticallyValid
    ) ?? []
  }

  private static func saveCancellationsUnlocked(
    _ cancellations: [DangguiAlarmCancellation]
  ) throws {
    guard cancellationsAreSemanticallyValid(cancellations) else {
      throw DangguiAlarmBridgeError.authoritativeStoreCorrupt
    }
    try saveArrayUnlocked(
      cancellations,
      filename: cancellationsFilename,
      authoritative: true
    )
  }

  private static func saveArrayUnlocked<Value: Codable>(
    _ values: [Value],
    filename: String,
    authoritative: Bool
  ) throws {
    if authoritative {
      try assertAuthoritativeStoresHealthyUnlocked()
    }
    let data = try JSONEncoder().encode(values)
    let url = try fileURLUnlocked(filename: filename)
    if let existing = try? Data(contentsOf: url),
       let decoded = decodeLossyArray(Value.self, from: existing),
       decoded.isComplete {
      try? existing.write(to: backupURL(for: url), options: .atomic)
    }
    try data.write(to: url, options: .atomic)
  }

  private static func mixedEventsAreSemanticallyValid(
    _ events: [DangguiAlarmEvent]
  ) -> Bool {
    var eventIDs = Set<String>()
    for event in events {
      guard eventHasValidEnvelope(event),
            eventIDs.insert(event.eventID).inserted else { return false }
      if event.mutatesBusinessState,
         !businessEventIsSemanticallyValid(event) {
        return false
      }
    }
    return true
  }

  private static func businessEventsAreSemanticallyValid(
    _ events: [DangguiAlarmEvent]
  ) -> Bool {
    var eventIDs = Set<String>()
    for event in events {
      guard businessEventIsSemanticallyValid(event),
            eventIDs.insert(event.eventID).inserted else { return false }
    }
    return true
  }

  private static func businessEventIsSemanticallyValid(
    _ event: DangguiAlarmEvent
  ) -> Bool {
    guard event.mutatesBusinessState,
          eventHasValidEnvelope(event),
          let platformAlarmID = event.platformAlarmID else {
      return false
    }
    let deterministicPlatformID = platformAlarmID.caseInsensitiveCompare(
      DangguiAlarmIdentifier.platformID(
        for: event.reminderID,
        revision: event.scheduleRevision,
        deviceGeneration: event.deviceGeneration
      )
    ) == .orderedSame
    let stableEventID = "danggui.alarm.\(event.type)."
      + "\(platformAlarmID.lowercased()).r\(event.scheduleRevision)"
    // v1.1.4 business events used random UUID event IDs. v1.1.5 uses the
    // deterministic form for retry idempotency, but strict migration must keep
    // the older valid outbox entries rather than rejecting them.
    let hasCompatibleEventID = event.eventID == stableEventID
      || UUID(uuidString: event.eventID) != nil
    return deterministicPlatformID && hasCompatibleEventID
  }

  private static func eventHasValidEnvelope(
    _ event: DangguiAlarmEvent
  ) -> Bool {
    guard !event.eventID.isEmpty,
          !event.reminderID.isEmpty,
          DangguiAlarmGeneration.isValid(event.deviceGeneration),
          event.scheduleRevision > 0,
          event.occurredAtEpochMs > 0,
          DangguiAlarmEventType(rawValue: event.type) != nil else {
      return false
    }
    if let platformAlarmID = event.platformAlarmID {
      guard platformAlarmID.caseInsensitiveCompare(
        DangguiAlarmIdentifier.platformID(
          for: event.reminderID,
          revision: event.scheduleRevision,
          deviceGeneration: event.deviceGeneration
        )
      ) == .orderedSame else { return false }
      if event.eventID.hasPrefix("danggui.alarm.") {
        let stableEventID = "danggui.alarm.\(event.type)."
          + "\(platformAlarmID.lowercased()).r\(event.scheduleRevision)"
        guard event.eventID == stableEventID else { return false }
      }
    }
    return true
  }

  private static func recordsAreSemanticallyValid(
    _ records: [DangguiAlarmRecord]
  ) -> Bool {
    var reminderIDs = Set<String>()
    var platformIDs = Set<String>()
    for record in records {
      guard recordIsSemanticallyValid(record),
            reminderIDs.insert(record.reminderID).inserted,
            platformIDs.insert(record.platformAlarmID.lowercased()).inserted
      else { return false }
    }
    return true
  }

  private static func recordIsSemanticallyValid(
    _ record: DangguiAlarmRecord
  ) -> Bool {
    !record.reminderID.isEmpty
      && DangguiAlarmGeneration.isValid(record.deviceGeneration)
      && record.scheduleRevision > 0
      && record.triggerAtEpochMs > 0
      && (1...1_440).contains(record.defaultSnoozeMinutes)
      && UUID(uuidString: record.platformAlarmID) != nil
      && record.platformAlarmID.caseInsensitiveCompare(
        DangguiAlarmIdentifier.platformID(
          for: record.reminderID,
          revision: record.scheduleRevision,
          deviceGeneration: record.deviceGeneration
        )
      ) == .orderedSame
  }

  private static func transactionsAreSemanticallyValid(
    _ transactions: [DangguiAlarmTransaction]
  ) -> Bool {
    var transactionIDs = Set<String>()
    for transaction in transactions {
      guard !transaction.transactionID.isEmpty,
            UUID(uuidString: transaction.transactionID) != nil,
            transactionIDs.insert(transaction.transactionID).inserted,
            !transaction.reminderID.isEmpty,
            transaction.reminderID == transaction.replacement.reminderID,
            transaction.updatedAtEpochMs > 0,
            recordIsSemanticallyValid(transaction.replacement)
      else { return false }
      if let previousPlatformAlarmID = transaction.previousPlatformAlarmID,
         UUID(uuidString: previousPlatformAlarmID) == nil {
        return false
      }
      if let previousPlatformAlarmID = transaction.previousPlatformAlarmID,
         transaction.previousRecord == nil {
        // v1.1.4 may omit the full predecessor image, but its predecessor ID
        // must still be a deterministic earlier revision in the same legacy
        // generation. New cross-generation handoffs always persist the record.
        let previousRevision = transaction.replacement.scheduleRevision - 1
        let earlierRevisionMatches = previousRevision > 0
          && previousPlatformAlarmID.caseInsensitiveCompare(
            DangguiAlarmIdentifier.platformID(
              for: transaction.reminderID,
              revision: previousRevision,
              deviceGeneration: transaction.replacement.deviceGeneration
            )
          ) == .orderedSame
        guard earlierRevisionMatches else { return false }
      }
      if let previousRecord = transaction.previousRecord {
        guard recordIsSemanticallyValid(previousRecord),
              previousRecord.reminderID == transaction.reminderID,
              (!DangguiAlarmGeneration.matches(
                previousRecord.deviceGeneration,
                transaction.replacement.deviceGeneration
              ) || previousRecord.scheduleRevision
                < transaction.replacement.scheduleRevision),
              let previousPlatformAlarmID = transaction.previousPlatformAlarmID,
              previousRecord.platformAlarmID.caseInsensitiveCompare(
                previousPlatformAlarmID
              ) == .orderedSame else {
          return false
        }
      }
      if transaction.stopPreviousWhenConfirmed == true,
         (transaction.previousPlatformAlarmID == nil
          || transaction.previousRecord == nil
          || !DangguiAlarmGeneration.matches(
            transaction.previousRecord?.deviceGeneration,
            transaction.replacement.deviceGeneration
          )
          || transaction.completionEvent?.type
            != DangguiAlarmEventType.snoozed.rawValue) {
          return false
      }
      if let completionEvent = transaction.completionEvent {
        guard completionEvent.type == DangguiAlarmEventType.snoozed.rawValue,
              transaction.stopPreviousWhenConfirmed == true,
              let previousRecord = transaction.previousRecord,
              DangguiAlarmGeneration.matches(
                completionEvent.deviceGeneration,
                previousRecord.deviceGeneration
              ),
              DangguiAlarmGeneration.matches(
                previousRecord.deviceGeneration,
                transaction.replacement.deviceGeneration
              ),
              transaction.replacement.scheduleRevision
                == previousRecord.scheduleRevision + 1,
              completionEvent.scheduleRevision == previousRecord.scheduleRevision,
              completionEvent.successorTriggerAtEpochMs
                == transaction.replacement.triggerAtEpochMs,
              [10, 30, 60].contains(completionEvent.snoozeMinutes ?? -1),
              eventIsSemanticallyValid(
                completionEvent,
                reminderID: transaction.reminderID,
                maximumRevision: transaction.replacement.scheduleRevision,
                deviceGeneration: transaction.replacement.deviceGeneration
              ) else { return false }
      }
      if transaction.ownsMissingRecovery == true,
         (transaction.previousPlatformAlarmID != nil
          || transaction.previousRecord != nil
          || transaction.stopPreviousWhenConfirmed == true
          || transaction.completionEvent != nil) {
        return false
      }
      if (transaction.phase == .pending
          || transaction.phase == .replacementScheduled),
         transaction.replacement.lastState == "scheduled" {
        // A scheduled mirror is only written while advancing to confirmed.
        // Accepting it in an earlier phase lets a forged JSON image claim a
        // route was verified when the daemon transaction still says it was not.
        return false
      }
      if transaction.phase == .confirmed || transaction.phase == .retired {
        guard transaction.replacement.lastState == "scheduled" else {
          return false
        }
      }
    }
    return true
  }

  private static func cancellationsAreSemanticallyValid(
    _ cancellations: [DangguiAlarmCancellation]
  ) -> Bool {
    let allowedTerminalStates: Set<String?> = [
      nil,
      "cancelled",
      "stopped",
      "missed",
      "delivered-retired",
      DangguiAlarmCancellationPolicy.routeRetiredTerminalState,
    ]
    var cancellationIDs = Set<String>()
    var reminderGenerations = Set<String>()
    for cancellation in cancellations {
      let platformIDs = cancellation.platformAlarmIDs.map { $0.lowercased() }
      let generationKey = cancellation.deviceGeneration?.lowercased() ?? "<legacy>"
      guard !cancellation.cancellationID.isEmpty,
            UUID(uuidString: cancellation.cancellationID) != nil,
            cancellationIDs.insert(cancellation.cancellationID).inserted,
            !cancellation.reminderID.isEmpty,
            DangguiAlarmGeneration.isValid(cancellation.deviceGeneration),
            reminderGenerations.insert(
              "\(cancellation.reminderID)\u{1f}\(generationKey)"
            ).inserted,
            cancellation.cancelledThroughRevision >= 0,
            cancellation.updatedAtEpochMs > 0,
            Set(platformIDs).count == platformIDs.count,
            platformIDs.allSatisfy({ UUID(uuidString: $0) != nil }),
            allowedTerminalStates.contains(cancellation.terminalState)
      else { return false }
      if cancellation.cancelledThroughRevision == 0 {
        guard platformIDs.isEmpty else { return false }
      } else {
        // Every tombstone is anchored by the deterministic ID at its scoped
        // revision high-water mark. Extra predecessor IDs remain compatible
        // with v1.1.4, but a random UUID can no longer forge the only owner of
        // a supposedly cancelled revision.
        let highWaterPlatformID = DangguiAlarmIdentifier.platformID(
          for: cancellation.reminderID,
          revision: cancellation.cancelledThroughRevision,
          deviceGeneration: cancellation.deviceGeneration
        ).lowercased()
        guard platformIDs.contains(highWaterPlatformID) else { return false }
      }
      if cancellation.daemonAction == .stop {
        guard let stopPlatformAlarmID = cancellation.stopPlatformAlarmID,
              platformIDs.contains(stopPlatformAlarmID.lowercased()) else {
          return false
        }
      } else if cancellation.stopPlatformAlarmID != nil {
        return false
      }
      if let completionEvent = cancellation.completionEvent {
        guard eventIsSemanticallyValid(
          completionEvent,
          reminderID: cancellation.reminderID,
          maximumRevision: cancellation.cancelledThroughRevision,
          deviceGeneration: cancellation.deviceGeneration
        ), platformIDs.contains(completionEvent.platformAlarmID?.lowercased() ?? "")
        else { return false }
      }
      switch cancellation.terminalState {
      case "stopped":
        if cancellation.daemonAction != .stop
          || cancellation.completionEvent?.type
            != DangguiAlarmEventType.stopped.rawValue
          || cancellation.completionEvent?.scheduleRevision
            != cancellation.cancelledThroughRevision {
          return false
        }
      case "missed":
        if cancellation.daemonAction == .stop
          || cancellation.completionEvent?.type
            != DangguiAlarmEventType.missed.rawValue
          || cancellation.completionEvent?.scheduleRevision
            != cancellation.cancelledThroughRevision {
          return false
        }
      case DangguiAlarmCancellationPolicy.routeRetiredTerminalState,
           "delivered-retired",
           "cancelled":
        if cancellation.daemonAction == .stop
          || cancellation.stopPlatformAlarmID != nil
          || cancellation.completionEvent != nil {
          return false
        }
      default:
        if cancellation.daemonAction != nil
          || cancellation.stopPlatformAlarmID != nil
          || cancellation.completionEvent != nil {
          return false
        }
      }
    }
    return true
  }

  private static func eventIsSemanticallyValid(
    _ event: DangguiAlarmEvent,
    reminderID: String,
    maximumRevision: Int,
    deviceGeneration: String?
  ) -> Bool {
    guard businessEventIsSemanticallyValid(event),
          event.reminderID == reminderID,
          DangguiAlarmGeneration.matches(
            event.deviceGeneration,
            deviceGeneration
          ),
          event.scheduleRevision <= maximumRevision,
          let platformAlarmID = event.platformAlarmID else {
      return false
    }
    return platformAlarmID.caseInsensitiveCompare(
      DangguiAlarmIdentifier.platformID(
        for: reminderID,
        revision: event.scheduleRevision,
        deviceGeneration: deviceGeneration
      )
    ) == .orderedSame
  }

  private static func authoritativeStoresAreCrossConsistentUnlocked() -> Bool {
    let records = loadArrayUnlocked(
      DangguiAlarmRecord.self,
      filename: recordsFilename,
      allowLossy: false,
      semanticValidator: recordsAreSemanticallyValid
    ) ?? []
    let transactions = loadArrayUnlocked(
      DangguiAlarmTransaction.self,
      filename: transactionsFilename,
      allowLossy: false,
      semanticValidator: transactionsAreSemanticallyValid
    ) ?? []
    let cancellations = loadArrayUnlocked(
      DangguiAlarmCancellation.self,
      filename: cancellationsFilename,
      allowLossy: false,
      semanticValidator: cancellationsAreSemanticallyValid
    ) ?? []
    var identityByPlatformID: [String: String] = [:]
    let recordImages = records
      + transactions.map(\.replacement)
      + transactions.compactMap(\.previousRecord)
    for record in recordImages {
      let platformID = record.platformAlarmID.lowercased()
      let generation = record.deviceGeneration?.lowercased() ?? "<legacy>"
      let identity = "\(record.reminderID)\u{1f}\(record.scheduleRevision)\u{1f}\(generation)"
      if let existing = identityByPlatformID[platformID], existing != identity {
        return false
      }
      identityByPlatformID[platformID] = identity
    }
    for cancellation in cancellations {
      let cancellationGeneration = cancellation.deviceGeneration?.lowercased()
        ?? "<legacy>"
      for platformID in cancellation.platformAlarmIDs.map({ $0.lowercased() }) {
        guard let knownIdentity = identityByPlatformID[platformID] else {
          // Completed v1.1.4 tombstones may be the only remaining image of an
          // older deterministic route, so unknown historical IDs are allowed.
          continue
        }
        let components = knownIdentity.split(
          separator: "\u{1f}",
          omittingEmptySubsequences: false
        )
        guard components.count == 3,
              String(components[0]) == cancellation.reminderID else {
          return false
        }
        if String(components[2]) == cancellationGeneration,
           let revision = Int(components[1]),
           revision > cancellation.cancelledThroughRevision {
          return false
        }
      }
      guard let event = cancellation.completionEvent,
            let platformID = event.platformAlarmID?.lowercased() else { continue }
      let generation = event.deviceGeneration?.lowercased() ?? "<legacy>"
      let identity = "\(event.reminderID)\u{1f}\(event.scheduleRevision)\u{1f}\(generation)"
      if let existing = identityByPlatformID[platformID], existing != identity {
        return false
      }
      identityByPlatformID[platformID] = identity
    }
    return true
  }

  private static func loadArrayUnlocked<Value: Decodable>(
    _ type: Value.Type,
    filename: String,
    allowLossy: Bool,
    semanticValidator: (([Value]) -> Bool)? = nil
  ) -> [Value]? {
    guard let url = try? fileURLUnlocked(filename: filename) else { return nil }
    var salvagedPrimary: [Value]?
    if let data = try? Data(contentsOf: url),
       let decoded = decodeLossyArray(type, from: data) {
      if decoded.isComplete,
         semanticValidator?(decoded.values) ?? true {
        return decoded.values
      }
      salvagedPrimary = decoded.values
    }
    var salvagedBackup: [Value]?
    if let backupData = try? Data(contentsOf: backupURL(for: url)),
       let decodedBackup = decodeLossyArray(type, from: backupData) {
      if decodedBackup.isComplete,
         semanticValidator?(decodedBackup.values) ?? true {
        return decodedBackup.values
      }
      salvagedBackup = decodedBackup.values
    }
    // Prefer a complete last-known-good image over a partially decoded
    // primary. Partial salvage is reserved for the lossy diagnostic journal;
    // authoritative records, transactions, cancellations, and business-event
    // outbox entries return nil and the health gate prevents replacement.
    return allowLossy ? (salvagedPrimary ?? salvagedBackup) : nil
  }

  private static func assertAuthoritativeStoresHealthyUnlocked() throws {
    let activeGenerationIsHealthy = !authoritativeFileImageExistsUnlocked(
      filename: activeGenerationFilename
    ) || authoritativeFileIsHealthyUnlocked(
      DangguiAlarmActiveGenerationState.self,
      filename: activeGenerationFilename,
      semanticValidator: activeGenerationStatesAreSemanticallyValid
    )
    guard activeGenerationIsHealthy,
      authoritativeFileIsHealthyUnlocked(
      DangguiAlarmRecord.self,
      filename: recordsFilename,
      semanticValidator: recordsAreSemanticallyValid
    ), authoritativeFileIsHealthyUnlocked(
      DangguiAlarmTransaction.self,
      filename: transactionsFilename,
      semanticValidator: transactionsAreSemanticallyValid
    ), authoritativeFileIsHealthyUnlocked(
      DangguiAlarmCancellation.self,
      filename: cancellationsFilename,
      semanticValidator: cancellationsAreSemanticallyValid
    ), businessEventOutboxIsHealthyUnlocked() else {
      throw DangguiAlarmBridgeError.authoritativeStoreCorrupt
    }
    if !authoritativeFileImageExistsUnlocked(filename: recordsFilename),
       let legacy = UserDefaults.standard.data(forKey: legacyRecordsKey) {
      guard let decoded = decodeLossyArray(DangguiAlarmRecord.self, from: legacy),
            decoded.isComplete,
            recordsAreSemanticallyValid(decoded.values) else {
        throw DangguiAlarmBridgeError.authoritativeStoreCorrupt
      }
    }
    guard authoritativeStoresAreCrossConsistentUnlocked() else {
      throw DangguiAlarmBridgeError.authoritativeStoreCorrupt
    }
  }

  private static func businessEventOutboxIsHealthyUnlocked() -> Bool {
    if authoritativeFileImageExistsUnlocked(filename: businessEventsFilename) {
      return authoritativeFileIsHealthyUnlocked(
        DangguiAlarmEvent.self,
        filename: businessEventsFilename,
        semanticValidator: businessEventsAreSemanticallyValid
      )
    }

    if authoritativeFileImageExistsUnlocked(
      filename: legacyMixedEventsFilename
    ) {
      return authoritativeFileIsHealthyUnlocked(
        DangguiAlarmEvent.self,
        filename: legacyMixedEventsFilename,
        semanticValidator: mixedEventsAreSemanticallyValid
      )
    }

    guard let legacy = UserDefaults.standard.data(forKey: legacyEventsKey)
    else { return true }
    guard let decoded = decodeLossyArray(
      DangguiAlarmEvent.self,
      from: legacy
    ) else { return false }
    return decoded.isComplete && mixedEventsAreSemanticallyValid(decoded.values)
  }

  private static func authoritativeFileImageExistsUnlocked(
    filename: String
  ) -> Bool {
    guard let url = try? fileURLUnlocked(filename: filename) else { return false }
    let manager = FileManager.default
    return manager.fileExists(atPath: url.path)
      || manager.fileExists(atPath: backupURL(for: url).path)
  }

  private static func authoritativeFileIsHealthyUnlocked<Value: Decodable>(
    _ type: Value.Type,
    filename: String,
    semanticValidator: ([Value]) -> Bool
  ) -> Bool {
    guard let url = try? fileURLUnlocked(filename: filename) else { return false }
    let manager = FileManager.default
    let backup = backupURL(for: url)
    if !manager.fileExists(atPath: url.path) {
      // A backup without its primary is recovery evidence, not authoritative
      // current state. Only an explicit recovery flow may promote it.
      return !manager.fileExists(atPath: backup.path)
    }
    if let data = try? Data(contentsOf: url),
       let decoded = decodeLossyArray(type, from: data),
       decoded.isComplete,
       semanticValidator(decoded.values) {
      return true
    }
    // Never continue writes from a backup when a primary exists but is
    // malformed or partial: it may omit the newest terminal tombstone.
    return false
  }

  private static func decodeLossyArray<Value: Decodable>(
    _ type: Value.Type,
    from data: Data
  ) -> DangguiLossyArray<Value>? {
    guard let values = try? JSONDecoder().decode(
      [DangguiLossyValue<Value>].self,
      from: data
    ) else {
      return nil
    }
    let decoded = values.compactMap(\.value)
    return DangguiLossyArray(
      values: decoded,
      isComplete: decoded.count == values.count
    )
  }

  private static func backupURL(for url: URL) -> URL {
    url.appendingPathExtension("bak")
  }

  private static func fileURLUnlocked(filename: String) throws -> URL {
    let directory: URL
    if let baseDirectoryOverride {
      directory = baseDirectoryOverride
    } else {
      directory = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      ).appendingPathComponent("danggui", isDirectory: true)
    }
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true,
      attributes: nil
    )
    var excludedDirectory = directory
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = true
    try? excludedDirectory.setResourceValues(resourceValues)
    return directory.appendingPathComponent(filename, isDirectory: false)
  }
}

// MARK: Serialized AlarmKit operations (iOS 26+ only)

#if canImport(AlarmKit)
@available(iOS 26.0, *)
struct DangguiAlarmMetadata: AlarmMetadata {
  let reminderID: String
  let taskID: String
  let scheduleRevision: Int
  let deviceGeneration: String?
}

@available(iOS 26.0, *)
struct DangguiStopAlarmIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "停止当归提醒"
  static var description = IntentDescription("停止正在响铃的当归提醒")

  @Parameter(title: "Alarm ID")
  var platformAlarmID: String

  @Parameter(title: "Reminder ID")
  var reminderID: String?

  @Parameter(title: "Schedule revision")
  var scheduleRevision: Int?

  init(
    platformAlarmID: String,
    reminderID: String? = nil,
    scheduleRevision: Int? = nil
  ) {
    self.platformAlarmID = platformAlarmID
    self.reminderID = reminderID
    self.scheduleRevision = scheduleRevision
  }

  init() {
    platformAlarmID = ""
    reminderID = nil
    scheduleRevision = nil
  }

  func perform() async throws -> some IntentResult {
    if let reminderID, let scheduleRevision {
      try await DangguiAlarmOperationActor.shared.stop(
        reminderID: reminderID,
        expectedRevision: scheduleRevision,
        expectedSession: platformAlarmID
      )
      return .result()
    }
    // Compatibility for already-registered v1.1.4 AlarmKit intents, which
    // encoded only the platform ID. A missing mirror remains a safe no-op.
    guard let record = DangguiAlarmStore.record(platformAlarmID: platformAlarmID) else {
      return .result()
    }
    try await DangguiAlarmOperationActor.shared.stop(
      reminderID: record.reminderID,
      expectedRevision: record.scheduleRevision,
      expectedSession: platformAlarmID
    )
    return .result()
  }
}

@available(iOS 26.0, *)
struct DangguiSnoozeAlarmIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "稍后提醒"
  static var description = IntentDescription("按事项的默认时长稍后再次提醒")

  @Parameter(title: "Alarm ID")
  var platformAlarmID: String

  @Parameter(title: "Reminder ID")
  var reminderID: String?

  @Parameter(title: "Schedule revision")
  var scheduleRevision: Int?

  init(
    platformAlarmID: String,
    reminderID: String? = nil,
    scheduleRevision: Int? = nil
  ) {
    self.platformAlarmID = platformAlarmID
    self.reminderID = reminderID
    self.scheduleRevision = scheduleRevision
  }

  init() {
    platformAlarmID = ""
    reminderID = nil
    scheduleRevision = nil
  }

  func perform() async throws -> some IntentResult {
    if let reminderID, let scheduleRevision {
      let record = DangguiAlarmStore.authoritativeActionRecord(
        reminderID: reminderID,
        scheduleRevision: scheduleRevision,
        platformAlarmID: platformAlarmID
      )
      try await DangguiAlarmOperationActor.shared.snooze(
        reminderID: reminderID,
        minutes: record?.defaultSnoozeMinutes,
        expectedRevision: scheduleRevision,
        expectedSession: platformAlarmID
      )
      return .result()
    }
    // Compatibility for already-registered v1.1.4 AlarmKit intents.
    guard let record = DangguiAlarmStore.record(platformAlarmID: platformAlarmID) else {
      return .result()
    }
    try await DangguiAlarmOperationActor.shared.snooze(
      reminderID: record.reminderID,
      minutes: record.defaultSnoozeMinutes,
      expectedRevision: record.scheduleRevision,
      expectedSession: platformAlarmID
    )
    return .result()
  }
}

@available(iOS 26.0, *)
actor DangguiAlarmOperationActor {
  static let shared = DangguiAlarmOperationActor()
  private var operationInProgress = false
  private var operationWaiters: [CheckedContinuation<Void, Never>] = []

  func activateDeviceGeneration(_ deviceGeneration: String?) async throws {
    try await withExclusiveOperation {
      let previousGeneration = try DangguiAlarmStore.activeDeviceGeneration()
      let generationChanged = !DangguiAlarmGeneration.matches(
        previousGeneration,
        deviceGeneration
      )
      try DangguiAlarmStore.activateDeviceGeneration(deviceGeneration)
      // The activation image is durable before daemon mutation. A crash at
      // any later point is recovered by the same cleanup at initialization.
      do {
        try await retireInactiveGenerationRoutesUnlocked()
        try await recoverPersistedTransactionsUnlocked(
          retireInactiveRoutesFirst: false
        )
      } catch {
        if generationChanged {
          // The database swap has not happened until this call succeeds.
          // Restore the old generation fence and best-effort repair any old
          // route already retired during the failed handoff.
          try? DangguiAlarmStore.activateDeviceGeneration(previousGeneration)
          try? await retireInactiveGenerationRoutesUnlocked()
          try? await recoverPersistedTransactionsUnlocked(
            retireInactiveRoutesFirst: false
          )
          if let alarms = try? await DangguiAlarmKitControllerV2.alarms() {
            await reconcileUnlocked(alarms, recoverFirst: false)
          }
        }
        throw error
      }
    }
  }

  private func assertActiveGeneration(_ deviceGeneration: String?) throws {
    guard DangguiAlarmGeneration.matches(
      deviceGeneration,
      try DangguiAlarmStore.activeDeviceGeneration()
    ) else {
      throw DangguiAlarmBridgeError.inactiveDeviceGeneration
    }
  }

  private func activeRecords() throws -> [DangguiAlarmRecord] {
    let generation = try DangguiAlarmStore.activeDeviceGeneration()
    return DangguiAlarmStore.records().filter {
      DangguiAlarmGeneration.matches($0.deviceGeneration, generation)
    }
  }

  private func activeRecord(reminderID: String) throws -> DangguiAlarmRecord? {
    let records = try activeRecords()
    return records.first { $0.reminderID == reminderID }
  }

  private func activeTransactions() throws -> [DangguiAlarmTransaction] {
    let generation = try DangguiAlarmStore.activeDeviceGeneration()
    return DangguiAlarmStore.transactions().filter {
      DangguiAlarmGeneration.matches(
        $0.replacement.deviceGeneration,
        generation
      )
    }
  }

  private func activeCancellations() throws -> [DangguiAlarmCancellation] {
    let generation = try DangguiAlarmStore.activeDeviceGeneration()
    return DangguiAlarmStore.cancellations().filter {
      DangguiAlarmGeneration.matches($0.deviceGeneration, generation)
    }
  }

  private func retireInactiveGenerationRoutesUnlocked() async throws {
    let inactiveIDs = try DangguiAlarmStore.inactiveRoutePlatformAlarmIDs()
    guard !inactiveIDs.isEmpty else { return }
    var activeIDs = try await DangguiAlarmKitControllerV2.activeIDs()
    for platformAlarmID in inactiveIDs where activeIDs.contains(
      platformAlarmID.lowercased()
    ) {
      try await DangguiAlarmKitControllerV2.cancel(
        platformAlarmID: platformAlarmID
      )
      activeIDs.remove(platformAlarmID.lowercased())
    }
  }

  func schedule(_ requestedRecord: DangguiAlarmRecord) async throws {
    try await withExclusiveOperation {
      try await scheduleUnlocked(requestedRecord)
    }
  }

  private func scheduleUnlocked(_ requestedRecord: DangguiAlarmRecord) async throws {
    try DangguiAlarmStore.assertAuthoritativeStoresHealthy()
    try assertActiveGeneration(requestedRecord.deviceGeneration)
    try await recoverPersistedTransactionsUnlocked()
    let relatedTransactions = DangguiAlarmStore.transactions().filter {
      $0.reminderID == requestedRecord.reminderID
    }
    let current = DangguiAlarmStore.record(reminderID: requestedRecord.reminderID)
    let decision = DangguiAlarmMutationPolicy.scheduleDecision(
      requested: requestedRecord,
      current: current,
      transactions: relatedTransactions,
      cancellation: DangguiAlarmStore.cancellation(
        reminderID: requestedRecord.reminderID,
        deviceGeneration: requestedRecord.deviceGeneration
      )
    )
    switch decision {
    case .staleRevision:
      throw DangguiAlarmOperationError.staleRevision
    case .revisionConflict:
      throw DangguiAlarmOperationError.revisionConflict
    case .install, .idempotent:
      break
    }

    let nowEpochMs = Self.nowEpochMs
    guard !DangguiAlarmRecoveryPolicy.isExpired(
      triggerAtEpochMs: requestedRecord.triggerAtEpochMs,
      nowEpochMs: nowEpochMs
    ) else {
      try await persistMissed(requestedRecord, nowEpochMs: nowEpochMs)
      throw DangguiAlarmOperationError.expired
    }

    if decision == .idempotent,
       let sameRevision = relatedTransactions.first(where: {
      $0.replacement.scheduleRevision == requestedRecord.scheduleRevision
        && $0.replacement.platformAlarmID.caseInsensitiveCompare(
          requestedRecord.platformAlarmID
        ) == .orderedSame
    }) {
      // Recovery deliberately swallows deferred-capacity failures so one bad
      // transaction cannot block others. A direct retry must surface that
      // stable error to Dart and must not create another pending transaction.
      try await continueTransaction(sameRevision)
      return
    }

    var activeIDs = try await DangguiAlarmKitControllerV2.activeIDs()
    if decision == .idempotent,
       current?.scheduleRevision == requestedRecord.scheduleRevision,
       current?.platformAlarmID.caseInsensitiveCompare(
         requestedRecord.platformAlarmID
       ) == .orderedSame,
       activeIDs.contains(requestedRecord.platformAlarmID.lowercased()) {
      return
    }

    var previousPlatformAlarmID = current?.platformAlarmID
    var previousRecord = current
    let supersedingTransactionIDs = Set(relatedTransactions.map(\.transactionID))
    if !relatedTransactions.isEmpty {
      let reliablePredecessors = relatedTransactions
        .compactMap(\.previousPlatformAlarmID)
        .map { $0.lowercased() }
      previousPlatformAlarmID = reliablePredecessors.first(where: activeIDs.contains)
        ?? relatedTransactions
          .map { $0.replacement.platformAlarmID.lowercased() }
          .first(where: activeIDs.contains)
        ?? previousPlatformAlarmID
      let predecessorID = previousPlatformAlarmID?.lowercased()
      if let predecessorID {
        previousRecord = relatedTransactions
          .compactMap(\.previousRecord)
          .first { $0.platformAlarmID.lowercased() == predecessorID }
          ?? relatedTransactions
            .map(\.replacement)
            .first { $0.platformAlarmID.lowercased() == predecessorID }
          ?? current
      }

      // A newer database revision supersedes any deferred replacement. Keep
      // at most the one active predecessor until the newest alarm is confirmed.
      for transaction in relatedTransactions {
        let replacementID = transaction.replacement.platformAlarmID.lowercased()
        if activeIDs.contains(replacementID), replacementID != (predecessorID ?? "") {
          try await DangguiAlarmKitControllerV2.cancel(platformAlarmID: replacementID)
          activeIDs.remove(replacementID)
        }
      }
    }

    try await beginReplacement(
      requestedRecord,
      previousPlatformAlarmID: previousPlatformAlarmID,
      previousRecord: previousRecord,
      supersedingTransactionIDs: supersedingTransactionIDs
    )
  }

  func cancel(
    reminderID: String,
    expectedDeviceGeneration: String?
  ) async throws {
    try await withExclusiveOperation {
      try await cancelUnlocked(
        reminderID: reminderID,
        expectedDeviceGeneration: expectedDeviceGeneration
      )
    }
  }

  private func cancelUnlocked(
    reminderID: String,
    expectedDeviceGeneration: String?
  ) async throws {
    try DangguiAlarmStore.assertAuthoritativeStoresHealthy()
    guard try DangguiAlarmStore.activeGenerationMatches(
      expectedDeviceGeneration
    ) else {
      // A delayed cancel from a replaced database is idempotent, but must not
      // acquire cancellation ownership for the current same-ID reminder.
      return
    }
    try await retireInactiveGenerationRoutesUnlocked()
    let targetGeneration = expectedDeviceGeneration
    let current = try activeRecord(reminderID: reminderID)
    let relatedTransactions = (try activeTransactions()).filter {
      $0.reminderID == reminderID
    }
    if let unfinished = DangguiAlarmStore.cancellation(
      reminderID: reminderID,
      deviceGeneration: targetGeneration
    ), unfinished.phase != .completed {
      // Never overwrite an unfinished Stop/Missed/Snooze-adjacent terminal
      // ledger with a later business cancel. Its durable event must settle
      // first; a daemon failure leaves it retryable and blocks this mutation.
      try await continueCancellation(unfinished)
    }
    let cancellation = DangguiAlarmCancellationPolicy.makeTombstone(
      reminderID: reminderID,
      current: current,
      transactions: relatedTransactions,
      existing: DangguiAlarmStore.cancellation(
        reminderID: reminderID,
        deviceGeneration: targetGeneration
      ),
      nowEpochMs: Self.nowEpochMs
    )
    // This write must succeed before the first irreversible daemon mutation.
    try DangguiAlarmStore.upsertCancellation(cancellation)
    try await continueCancellation(cancellation)
  }

  func retireNativeRoute(
    reminderID: String,
    expectedRevision: Int,
    expectedSession: String,
    expectedDeviceGeneration: String?
  ) async throws {
    try await withExclusiveOperation {
      try await retireNativeRouteUnlocked(
        reminderID: reminderID,
        expectedRevision: expectedRevision,
        expectedSession: expectedSession,
        expectedDeviceGeneration: expectedDeviceGeneration
      )
    }
  }

  private func retireNativeRouteUnlocked(
    reminderID: String,
    expectedRevision: Int,
    expectedSession: String,
    expectedDeviceGeneration: String?
  ) async throws {
    try DangguiAlarmStore.assertAuthoritativeStoresHealthy()
    guard DangguiAlarmGeneration.matches(
      expectedDeviceGeneration,
      try DangguiAlarmStore.activeDeviceGeneration()
    ) else {
      // A delayed fallback completion from the losing database generation is
      // an idempotent no-op, never a failure that can abort current reconcile.
      return
    }
    try await recoverPersistedTransactionsUnlocked()
    let identity = DangguiAlarmActionIdentity(
      reminderID: reminderID,
      scheduleRevision: expectedRevision,
      platformAlarmID: expectedSession
    )
    guard identity.isInternallyConsistent else { return }

    guard let record = targetRecord(
      reminderID: reminderID,
      expectedRevision: expectedRevision,
      expectedSession: expectedSession
    ) else {
      return
    }
    guard DangguiAlarmGeneration.matches(
      record.deviceGeneration,
      expectedDeviceGeneration
    ) else {
      return
    }
    let existing = DangguiAlarmStore.cancellation(
      reminderID: reminderID,
      deviceGeneration: record.deviceGeneration
    )
    if let existing,
       existing.cancelledThroughRevision >= expectedRevision {
      if existing.phase != .completed {
        try await continueCancellation(existing)
      }
      return
    }
    let tombstone = DangguiAlarmCancellationPolicy.makeRouteRetirementTombstone(
      record: record,
      currentMirror: DangguiAlarmStore.record(reminderID: reminderID),
      transactions: DangguiAlarmStore.transactions(),
      existing: existing,
      nowEpochMs: Self.nowEpochMs
    )
    try DangguiAlarmStore.upsertCancellation(tombstone)
    try await continueCancellation(tombstone)
  }

  func stop(
    reminderID: String,
    expectedRevision: Int?,
    expectedSession: String?
  ) async throws {
    try await withExclusiveOperation {
      try await stopUnlocked(
        reminderID: reminderID,
        expectedRevision: expectedRevision,
        expectedSession: expectedSession
      )
    }
  }

  private func stopUnlocked(
    reminderID: String,
    expectedRevision: Int?,
    expectedSession: String?
  ) async throws {
    try DangguiAlarmStore.assertAuthoritativeStoresHealthy()
    try await recoverPersistedTransactionsUnlocked()
    guard let expectedRevision, let expectedSession else { return }
    let identity = DangguiAlarmActionIdentity(
      reminderID: reminderID,
      scheduleRevision: expectedRevision,
      platformAlarmID: expectedSession
    )
    guard identity.isInternallyConsistent else { return }

    guard let record = targetRecord(
      reminderID: reminderID,
      expectedRevision: expectedRevision,
      expectedSession: expectedSession
    ) else {
      // Without an authoritative mirror we cannot durably bind the action to
      // business state. Fail closed rather than mutating AlarmKit first.
      return
    }
    let existing = DangguiAlarmStore.cancellation(
      reminderID: reminderID,
      deviceGeneration: record.deviceGeneration
    )
    if let existing,
       existing.cancelledThroughRevision >= expectedRevision {
      if existing.phase != .completed {
        try await continueCancellation(existing)
      }
      return
    }

    let tombstone = DangguiAlarmCancellationPolicy.makeStopTombstone(
      record: record,
      transactions: DangguiAlarmStore.transactions(),
      existing: existing,
      nowEpochMs: Self.nowEpochMs
    )
    // The tombstone, terminal event identity, and revision high-water mark are
    // durable before stop/cancel touches the system daemon.
    try DangguiAlarmStore.upsertCancellation(tombstone)
    try await continueCancellation(tombstone)
  }

  func snooze(
    reminderID: String,
    minutes: Int?,
    expectedRevision: Int?,
    expectedSession: String?
  ) async throws {
    try await withExclusiveOperation {
      try await snoozeUnlocked(
        reminderID: reminderID,
        minutes: minutes,
        expectedRevision: expectedRevision,
        expectedSession: expectedSession
      )
    }
  }

  private func snoozeUnlocked(
    reminderID: String,
    minutes: Int?,
    expectedRevision: Int?,
    expectedSession: String?
  ) async throws {
    try DangguiAlarmStore.assertAuthoritativeStoresHealthy()
    try await recoverPersistedTransactionsUnlocked()
    guard var record = targetRecord(
      reminderID: reminderID,
      expectedRevision: expectedRevision,
      expectedSession: expectedSession
    ) else {
      // Delayed/repeated system actions are intentionally idempotent. A stale
      // snooze must not create a successor for a newer reminder revision.
      return
    }
    guard !DangguiAlarmSnoozePolicy.hasUnresolvedTransaction(
      reminderID: reminderID,
      deviceGeneration: record.deviceGeneration,
      transactions: DangguiAlarmStore.transactions()
    ) else {
      // An unresolved replacement in this database generation may still own
      // an alerting predecessor. A stale transaction from a replaced database
      // must not block the current generation's user action.
      throw DangguiAlarmOperationError.operationInProgress
    }

    let allowedMinutes = [10, 30, 60]
    let preferred = minutes ?? record.defaultSnoozeMinutes
    let snoozeMinutes = allowedMinutes.contains(preferred)
      ? preferred
      : (allowedMinutes.contains(record.defaultSnoozeMinutes)
          ? record.defaultSnoozeMinutes
          : 10)
    let occurredAtEpochMs = Self.nowEpochMs
    try DangguiAlarmDeliveryRecorder.recordDeliveredIfNeeded(&record)
    let plan = DangguiAlarmSnoozePolicy.makePlan(
      record: record,
      minutes: snoozeMinutes,
      occurredAtEpochMs: occurredAtEpochMs
    )
    let settledRecoveryIDs = Set(
      DangguiAlarmStore.transactions().filter {
        $0.reminderID == reminderID
          && $0.ownsMissingRecovery == true
          && $0.phase == .retired
          && $0.replacement.platformAlarmID.caseInsensitiveCompare(
            record.platformAlarmID
          ) == .orderedSame
      }.map(\.transactionID)
    )
    // beginReplacement writes the pending successor first. Its confirmed
    // phase is the only place allowed to stop the alerting predecessor.
    try await beginReplacement(
      plan.replacement,
      previousPlatformAlarmID: record.platformAlarmID,
      previousRecord: record,
      stopPreviousWhenConfirmed: true,
      completionEvent: plan.completionEvent,
      supersedingTransactionIDs: settledRecoveryIDs
    )
  }

  func reconcileAndList() async throws -> [DangguiAlarmRecord] {
    try await withExclusiveOperation {
      try await reconcileAndListUnlocked()
    }
  }

  private func reconcileAndListUnlocked() async throws -> [DangguiAlarmRecord] {
    try DangguiAlarmStore.assertAuthoritativeStoresHealthy()
    try await recoverPersistedTransactionsUnlocked()
    let alarms = try await DangguiAlarmKitControllerV2.alarms()
    await reconcileUnlocked(alarms, recoverFirst: false)
    let cancellations = try activeCancellations()
    return (try activeRecords()).filter {
      DangguiAlarmCancellationPolicy.allowsRepair(
        record: $0,
        cancellations: cancellations
      )
    }.sorted {
      $0.triggerAtEpochMs < $1.triggerAtEpochMs
    }
  }

  func reconcile(_ suppliedAlarms: [Alarm]) async {
    await withExclusiveOperation {
      await reconcileUnlocked(suppliedAlarms, recoverFirst: true)
    }
  }

  func recoverPersistedTransactions() async {
    await withExclusiveOperation {
      try? await recoverPersistedTransactionsUnlocked()
    }
  }

  private func recoverPersistedTransactionsUnlocked(
    retireInactiveRoutesFirst: Bool = true
  ) async throws {
    try DangguiAlarmStore.assertAuthoritativeStoresHealthy()
    if retireInactiveRoutesFirst {
      try await retireInactiveGenerationRoutesUnlocked()
    }
    let activeGeneration = try DangguiAlarmStore.activeDeviceGeneration()
    try await recoverPersistedCancellationsUnlocked(
      activeDeviceGeneration: activeGeneration
    )
    let cancellations = try activeCancellations()
    for transaction in (try activeTransactions()) {
      guard (try activeTransactions()).contains(where: {
        $0.transactionID == transaction.transactionID
      }) else { continue }
      let relatedCancellations = cancellations.filter {
        $0.reminderID == transaction.reminderID
          && DangguiAlarmGeneration.matches(
            $0.deviceGeneration,
            transaction.replacement.deviceGeneration
          )
      }
      if relatedCancellations.contains(where: { $0.phase != .completed }) {
        continue
      }
      let cancelledThroughRevision = relatedCancellations
        .map(\.cancelledThroughRevision)
        .max()
      if let cancelledThroughRevision,
         transaction.replacement.scheduleRevision <= cancelledThroughRevision,
         !relatedCancellations.contains(where: {
           DangguiAlarmCancellationPolicy.permitsSameRevisionRouteReinstall(
             cancellation: $0,
             revision: transaction.replacement.scheduleRevision,
             deviceGeneration: transaction.replacement.deviceGeneration
           )
         }) {
        await discardNonAuthoritativeTransaction(transaction)
        continue
      }
      let current = try activeRecord(reminderID: transaction.reminderID)
      let decision = DangguiAlarmMutationPolicy.scheduleDecision(
        requested: transaction.replacement,
        current: current,
        transactions: try activeTransactions(),
        cancellation: relatedCancellations.first
      )
      if decision == .staleRevision {
        await discardNonAuthoritativeTransaction(transaction)
        continue
      }
      if decision == .revisionConflict {
        for conflict in (try activeTransactions()).filter({
          $0.reminderID == transaction.reminderID
            && DangguiAlarmGeneration.matches(
              $0.replacement.deviceGeneration,
              transaction.replacement.deviceGeneration
            )
            && $0.replacement.scheduleRevision
              == transaction.replacement.scheduleRevision
        }) {
          await discardNonAuthoritativeTransaction(conflict)
        }
        continue
      }
      do {
        try await continueTransaction(transaction)
      } catch DangguiAlarmOperationError.capacityDeferred {
        // Keep the pending transaction. A later AlarmKit update, launch, or
        // list operation retries it when the system has capacity again.
      } catch DangguiAlarmOperationError.expired {
        // persistMissed already installed the authoritative terminal tombstone.
        // Never recreate the transaction after that terminal transition.
      } catch {
        guard DangguiAlarmRecoveryPolicy.shouldPersistRecoveryFailure(
          transactionID: transaction.transactionID,
          transactions: (try? activeTransactions()) ?? []
        ) else {
          // A terminal path removed this transaction before throwing.
          continue
        }
        var record = transaction.replacement
        record.lastState = DangguiAlarmFailureMapper.state(for: .verification)
        try? persistPendingTransactionState(
          record.lastState,
          transaction: transaction
        )
        DangguiAlarmStore.appendEvent(
          DangguiAlarmEvent(
            type: .error,
            record: record,
            state: record.lastState,
            errorCode: "transaction_recovery_failed"
          )
        )
      }
    }
  }

  private func discardNonAuthoritativeTransaction(
    _ transaction: DangguiAlarmTransaction
  ) async {
    let replacementID = transaction.replacement.platformAlarmID.lowercased()
    let currentID = DangguiAlarmStore.record(reminderID: transaction.reminderID)?
      .platformAlarmID.lowercased()
    let isCurrentRecord = currentID.map { $0 == replacementID } ?? false
    if !isCurrentRecord,
       let activeIDs = try? await DangguiAlarmKitControllerV2.activeIDs(),
       activeIDs.contains(replacementID) {
      try? await DangguiAlarmKitControllerV2.cancel(platformAlarmID: replacementID)
    }
    try? DangguiAlarmStore.removeTransaction(transactionID: transaction.transactionID)
  }

  private func recoverPersistedCancellationsUnlocked(
    activeDeviceGeneration: String?
  ) async throws {
    let cancellations = DangguiAlarmStore.cancellations().filter {
      DangguiAlarmGeneration.matches(
        $0.deviceGeneration,
        activeDeviceGeneration
      )
    }
    var activeIDs = (try? await DangguiAlarmKitControllerV2.activeIDs()) ?? []
    for cancellation in cancellations where cancellation.phase == .completed {
      for platformID in DangguiAlarmCancellationPolicy.activeTargetIDs(
        cancellation: cancellation,
        activeIDs: activeIDs
      ) {
        do {
          try await DangguiAlarmKitControllerV2.cancel(platformAlarmID: platformID)
          activeIDs.remove(platformID)
        } catch {
          // Keep the completed high-water mark and retry the orphan cleanup on
          // the next recovery pass.
        }
      }
    }
    for cancellation in cancellations where cancellation.phase != .completed {
      do {
        try await continueCancellation(cancellation)
      } catch {
        // The durable tombstone remains authoritative. A later launch, update,
        // list, or explicit cancel retries without allowing repair to schedule.
      }
    }
  }

  private func continueCancellation(
    _ persistedCancellation: DangguiAlarmCancellation
  ) async throws {
    var cancellation = persistedCancellation
    try assertActiveGeneration(cancellation.deviceGeneration)
    guard cancellation.phase != .completed else { return }

    var activeIDs = try await DangguiAlarmKitControllerV2.activeIDs()
    let targets = DangguiAlarmCancellationPolicy.activeTargetIDs(
      cancellation: cancellation,
      activeIDs: activeIDs
    )
    for platformID in targets {
      if cancellation.daemonAction == .stop,
         cancellation.stopPlatformAlarmID.map({
           $0.caseInsensitiveCompare(platformID) == .orderedSame
         }) == true {
        do {
          try await DangguiAlarmKitControllerV2.stop(platformAlarmID: platformID)
          let afterStop = try await DangguiAlarmKitControllerV2.activeIDs()
          if afterStop.contains(platformID.lowercased()) {
            try await DangguiAlarmKitControllerV2.cancel(platformAlarmID: platformID)
          }
        } catch {
          try await DangguiAlarmKitControllerV2.cancel(platformAlarmID: platformID)
        }
      } else {
        try await DangguiAlarmKitControllerV2.cancel(platformAlarmID: platformID)
      }
    }
    activeIDs = try await DangguiAlarmKitControllerV2.activeIDs()
    guard DangguiAlarmCancellationPolicy.activeTargetIDs(
      cancellation: cancellation,
      activeIDs: activeIDs
    ).isEmpty else {
      throw DangguiAlarmOperationError.verificationFailed
    }

    if cancellation.phase == .pending {
      try cancellation.advance(to: .daemonCleared, nowEpochMs: Self.nowEpochMs)
      try DangguiAlarmStore.upsertCancellation(cancellation)
    }
    if cancellation.phase == .daemonCleared {
      if let completionEvent = cancellation.completionEvent {
        try DangguiAlarmStore.appendEventDurably(completionEvent)
      }
      try DangguiAlarmStore.removeRecordsAndTransactions(
        reminderID: cancellation.reminderID,
        platformAlarmIDs: Set(cancellation.platformAlarmIDs)
      )
      try cancellation.advance(to: .mirrorRemoved, nowEpochMs: Self.nowEpochMs)
      try DangguiAlarmStore.upsertCancellation(cancellation)
    }
    if cancellation.phase == .mirrorRemoved {
      try cancellation.advance(to: .completed, nowEpochMs: Self.nowEpochMs)
      // Completed entries are retained as a compact revision high-water mark.
      try DangguiAlarmStore.upsertCancellation(cancellation)
    }
  }

  private func reconcileUnlocked(
    _ suppliedAlarms: [Alarm],
    recoverFirst: Bool
  ) async {
    guard (try? DangguiAlarmStore.assertAuthoritativeStoresHealthy()) != nil else {
      return
    }
    if recoverFirst {
      guard (try? await recoverPersistedTransactionsUnlocked()) != nil else {
        return
      }
    }
    let alarms = (try? await DangguiAlarmKitControllerV2.alarms()) ?? suppliedAlarms
    let remoteByID = Dictionary(
      uniqueKeysWithValues: alarms.map { ($0.id.uuidString.lowercased(), $0) }
    )
    let nowEpochMs = Self.nowEpochMs
    guard let activeTransactions = try? activeTransactions(),
          let cancellations = try? activeCancellations(),
          let records = try? activeRecords() else {
      return
    }
    let orphanPlatformAlarmIDs = DangguiAlarmSystemSnapshotPolicy
      .orphanPlatformAlarmIDs(
        remotePlatformAlarmIDs: Set(remoteByID.keys),
        records: records,
        transactions: activeTransactions,
        cancellations: cancellations
      )
    for platformAlarmID in orphanPlatformAlarmIDs {
      do {
        try await DangguiAlarmKitControllerV2.cancel(
          platformAlarmID: platformAlarmID
        )
      } catch {
        // No mirror is fabricated for an unknown system route. A later
        // AlarmKit update or launch re-observes and retries the orphan cleanup.
      }
    }
    let pendingReminderGenerations = Set(
      activeTransactions.map {
        DangguiAlarmGeneration.scopedReminderKey(
          reminderID: $0.reminderID,
          deviceGeneration: $0.replacement.deviceGeneration
        )
      }
    )
    for var record in records {
      if DangguiAlarmCancellationPolicy.isSupersededByCompletedCancellation(
        record: record,
        cancellations: cancellations
      ) {
        // A last-known-good backup may restore a mirror older than a completed
        // cancellation. The high-water mark remains authoritative.
        _ = try? DangguiAlarmStore.remove(reminderID: record.reminderID)
        continue
      }
      guard DangguiAlarmCancellationPolicy.allowsRepair(
        record: record,
        cancellations: cancellations
      ) else {
        // A pending cancellation owns recovery for this reminder. Reconcile
        // must neither emit delivery events nor recreate it.
        continue
      }
      if let alarm = remoteByID[record.platformAlarmID.lowercased()] {
        let state = DangguiAlarmKitControllerV2.stateName(alarm.state)
        if state == "ringing" {
          do {
            try DangguiAlarmDeliveryRecorder.recordDeliveredIfNeeded(&record)
          } catch {
            // Do not persist a false `firedEventRecorded` marker. AlarmKit's
            // next update/reconciliation can retry the stable business event.
            continue
          }
        }
        if record.lastState != state {
          record.lastState = state
          try? DangguiAlarmStore.upsert(record)
        }
        continue
      }

      // A durable transaction already owns this missing alarm. Its recovery
      // pass above either completed or deliberately retained it for retry.
      if record.firedEventRecorded {
        // Ringing was observed earlier, but AlarmKit absence still does not
        // prove a Stop action. Retire without manufacturing a stopped event.
        try? await persistObservedRetirement(record, nowEpochMs: nowEpochMs)
        continue
      }
      let scopedReminderKey = DangguiAlarmGeneration.scopedReminderKey(
        reminderID: record.reminderID,
        deviceGeneration: record.deviceGeneration
      )
      guard !pendingReminderGenerations.contains(scopedReminderKey) else { continue }

      switch DangguiAlarmRecoveryPolicy.missingAlarmDecision(
        triggerAtEpochMs: record.triggerAtEpochMs,
        nowEpochMs: nowEpochMs,
        observedDelivered: record.firedEventRecorded
      ) {
      case .missed:
        try? await persistMissed(record, nowEpochMs: nowEpochMs)
      case .retireObserved:
        // AlarmKit absence after an observed ring does not prove the user
        // pressed Stop. Retire the mirror without fabricating that action.
        try? await persistObservedRetirement(record, nowEpochMs: nowEpochMs)
      case .recoverLate, .recoverScheduled:
        do {
          // The transaction is the atomic recovery owner. It is written before
          // AlarmKit is touched and retained through the terminal decision,
          // avoiding both a crash-prone marker and repeated audible repairs.
          try await beginReplacement(
            record,
            previousPlatformAlarmID: nil,
            ownsMissingRecovery: true
          )
        } catch {
          // Apple classifies a missing persisted one-shot alarm as fired, but
          // absence does not prove that its alert UI, audio, or haptics reached
          // the user. Keep the mirror during Danggui's bounded recovery window
          // rather than manufacturing stronger diagnostic milestones.
        }
      }
    }
  }

  private func beginReplacement(
    _ requestedRecord: DangguiAlarmRecord,
    previousPlatformAlarmID: String?,
    previousRecord: DangguiAlarmRecord? = nil,
    stopPreviousWhenConfirmed: Bool = false,
    completionEvent: DangguiAlarmEvent? = nil,
    ownsMissingRecovery: Bool = false,
    supersedingTransactionIDs: Set<String> = []
  ) async throws {
    var pendingRecord = requestedRecord
    pendingRecord.lastState = "pending"
    pendingRecord.firedEventRecorded = false
    let transaction = DangguiAlarmTransaction(
      replacement: pendingRecord,
      previousPlatformAlarmID: previousPlatformAlarmID,
      previousRecord: previousRecord,
      stopPreviousWhenConfirmed: stopPreviousWhenConfirmed,
      completionEvent: completionEvent,
      ownsMissingRecovery: ownsMissingRecovery
    )
    if supersedingTransactionIDs.isEmpty {
      try DangguiAlarmStore.upsertTransaction(transaction)
    } else {
      try DangguiAlarmStore.replaceTransactionsAtomically(
        reminderID: requestedRecord.reminderID,
        removingTransactionIDs: supersedingTransactionIDs,
        adding: transaction
      )
    }
    try await continueTransaction(transaction)
  }

  private func continueTransaction(
    _ persistedTransaction: DangguiAlarmTransaction
  ) async throws {
    var transaction = persistedTransaction
    try assertActiveGeneration(transaction.replacement.deviceGeneration)
    let routeRetirement = DangguiAlarmStore.cancellation(
      reminderID: transaction.reminderID,
      deviceGeneration: transaction.replacement.deviceGeneration
    )
    if DangguiAlarmCancellationPolicy.transactionOwnsSameRevisionRouteReinstall(
      transaction: transaction,
      cancellation: routeRetirement
    ) {
      // The transaction was persisted before this point. Removing the
      // route-only marker now is therefore crash safe: a process death before
      // AlarmKit scheduling leaves a pending owner that startup can retry.
      // Business Stop/Cancel/Missed tombstones never satisfy this predicate.
      try DangguiAlarmStore.removeCancellation(
        reminderID: transaction.reminderID,
        deviceGeneration: transaction.replacement.deviceGeneration
      )
    }
    let now = Date()
    let nowEpochMs = Int64(now.timeIntervalSince1970 * 1_000)
    var activeIDs = try await DangguiAlarmKitControllerV2.activeIDs()
    let replacementID = transaction.replacement.platformAlarmID.lowercased()

    if transaction.ownsMissingRecovery == true,
       let current = DangguiAlarmStore.record(reminderID: transaction.reminderID),
       current.platformAlarmID.caseInsensitiveCompare(
         transaction.replacement.platformAlarmID
       ) == .orderedSame,
       current.firedEventRecorded {
      if activeIDs.contains(replacementID) {
        // A ringing alarm remains system-owned until an explicit Stop/Snooze.
        return
      }
      // Delivery was observed, but disappearance is not proof of Stop.
      try await persistObservedRetirement(current, nowEpochMs: nowEpochMs)
      return
    }

    if DangguiAlarmRecoveryPolicy.isExpired(
      triggerAtEpochMs: transaction.replacement.triggerAtEpochMs,
      nowEpochMs: nowEpochMs
    ) {
      try persistCompletionEventIfNeeded(transaction)
      try await persistMissed(
        transaction.replacement,
        nowEpochMs: nowEpochMs
      )
      throw DangguiAlarmOperationError.expired
    }

    if transaction.phase != .pending, !activeIDs.contains(replacementID) {
      if !DangguiAlarmRecoveryPolicy.shouldRetryMissingTransaction(
        ownsMissingRecovery: transaction.ownsMissingRecovery == true,
        triggerAtEpochMs: transaction.replacement.triggerAtEpochMs,
        nowEpochMs: nowEpochMs
      ) {
        // A transaction-owned repair was scheduled once but disappeared after
        // its due time. Repeating it could create an audible duplicate; retain
        // ownership until the strict 15-minute expiry path records `missed`.
        return
      }
      do {
        let triggerDate = DangguiAlarmRecoveryPolicy.effectiveTriggerDate(
          triggerAtEpochMs: transaction.replacement.triggerAtEpochMs,
          now: now
        )
        try await DangguiAlarmKitControllerV2.schedule(
          transaction.replacement,
          triggerDate: triggerDate
        )
        activeIDs = try await DangguiAlarmKitControllerV2.activeIDs()
      } catch {
        try persistScheduleFailure(error, transaction: transaction)
        throw mappedScheduleError(error)
      }
    }

    if transaction.phase == .pending {
      if !activeIDs.contains(replacementID) {
        do {
          let triggerDate = DangguiAlarmRecoveryPolicy.effectiveTriggerDate(
            triggerAtEpochMs: transaction.replacement.triggerAtEpochMs,
            now: now
          )
          try await DangguiAlarmKitControllerV2.schedule(
            transaction.replacement,
            triggerDate: triggerDate
          )
        } catch {
          try persistScheduleFailure(error, transaction: transaction)
          throw mappedScheduleError(error)
        }
      }
      try transaction.advance(to: .replacementScheduled)
      try DangguiAlarmStore.upsertTransaction(transaction)
    }

    if transaction.phase == .replacementScheduled {
      activeIDs = try await DangguiAlarmKitControllerV2.activeIDs()
      guard activeIDs.contains(replacementID) else {
        try? persistPendingTransactionState(
          DangguiAlarmFailureMapper.state(for: .verification),
          transaction: transaction
        )
        throw DangguiAlarmOperationError.verificationFailed
      }
      var confirmed = transaction.replacement
      confirmed.lastState = "scheduled"
      confirmed.firedEventRecorded = false
      transaction.replacement = confirmed
      try DangguiAlarmStore.upsert(confirmed)
      try transaction.advance(to: .confirmed)
      try DangguiAlarmStore.upsertTransaction(transaction)
    }

    if transaction.phase == .confirmed {
      if let previous = transaction.previousPlatformAlarmID?.lowercased(),
         previous != replacementID {
        activeIDs = try await DangguiAlarmKitControllerV2.activeIDs()
        if activeIDs.contains(previous) {
          do {
            if DangguiAlarmSnoozePolicy.shouldStopPredecessor(
              transaction: transaction
            ) {
              do {
                try await DangguiAlarmKitControllerV2.stop(platformAlarmID: previous)
              } catch {
                try await DangguiAlarmKitControllerV2.cancel(platformAlarmID: previous)
              }
            } else {
              try await DangguiAlarmKitControllerV2.cancel(platformAlarmID: previous)
            }
          } catch {
            DangguiAlarmStore.appendEvent(
              DangguiAlarmEvent(
                type: .error,
                record: transaction.replacement,
                state: "confirmed",
                errorCode: "retire_old_failed"
              )
            )
            // New alarm is confirmed. Keep the transaction at confirmed so a
            // later recovery retires the old alarm without losing the new one.
            return
          }
        }
      }
      try transaction.advance(to: .retired)
      try DangguiAlarmStore.upsertTransaction(transaction)
    }

    if transaction.phase == .retired {
      try persistCompletionEventIfNeeded(transaction)
      // Registration is diagnostic only. A lossy journal write must never
      // retain a completed transaction or block later reminder revisions.
      DangguiAlarmStore.appendEvent(
        DangguiAlarmEvent(
          type: .registered,
          record: transaction.replacement,
          state: "scheduled",
          usesStableID: true
        )
      )
      if transaction.ownsMissingRecovery == true {
        // Keep the journal through delivery/missed/cancel/edit resolution. A
        // mere scheduled snapshot cannot prove that later delivery occurred.
        return
      }
      try DangguiAlarmStore.removeTransaction(transactionID: transaction.transactionID)
    }
  }

  private func persistCompletionEventIfNeeded(
    _ transaction: DangguiAlarmTransaction
  ) throws {
    if let completionEvent = transaction.completionEvent {
      try DangguiAlarmStore.appendEventDurably(completionEvent)
    }
  }

  private func persistScheduleFailure(
    _ error: Error,
    transaction: DangguiAlarmTransaction
  ) throws {
    let kind = DangguiAlarmKitControllerV2.failureKind(for: error)
    var record = transaction.replacement
    record.lastState = DangguiAlarmFailureMapper.state(for: kind)
    try persistPendingTransactionState(record.lastState, transaction: transaction)
    DangguiAlarmStore.appendEvent(
      DangguiAlarmEvent(
        type: .error,
        record: record,
        state: record.lastState,
        errorCode: kind == .capacity ? "capacity_deferred" : "alarm_schedule_failed"
      )
    )
  }

  private func persistPendingTransactionState(
    _ state: String,
    transaction: DangguiAlarmTransaction
  ) throws {
    guard transaction.phase == .pending
      || transaction.phase == .replacementScheduled else {
      // Confirmed/retired phases have already established a scheduled mirror.
      // A later daemon repair failure is diagnostic and must not rewrite that
      // phase image into a semantically impossible pre-confirmation state.
      return
    }
    var updatedTransaction = transaction
    updatedTransaction.replacement.lastState = state
    try DangguiAlarmStore.upsertTransaction(updatedTransaction)
    if transaction.previousPlatformAlarmID == nil && transaction.previousRecord == nil {
      try DangguiAlarmStore.upsert(updatedTransaction.replacement)
    }
  }

  private func mappedScheduleError(_ error: Error) -> Error {
    if DangguiAlarmKitControllerV2.failureKind(for: error) == .capacity {
      return DangguiAlarmOperationError.capacityDeferred
    }
    return error
  }

  private func persistMissed(
    _ record: DangguiAlarmRecord,
    nowEpochMs: Int64
  ) async throws {
    let tombstone = DangguiAlarmCancellationPolicy.makeMissedTombstone(
      record: record,
      currentMirror: DangguiAlarmStore.record(reminderID: record.reminderID),
      transactions: DangguiAlarmStore.transactions(),
      existing: DangguiAlarmStore.cancellation(
        reminderID: record.reminderID,
        deviceGeneration: record.deviceGeneration
      ),
      nowEpochMs: nowEpochMs
    )
    // Terminal ownership is durable before any AlarmKit cancellation. A
    // daemon failure leaves this pending tombstone for launch-time recovery.
    try DangguiAlarmStore.upsertCancellation(tombstone)
    do {
      try await continueCancellation(tombstone)
    } catch {
      // The tombstone remains authoritative and blocks revision resurrection.
    }
  }

  private func persistObservedRetirement(
    _ record: DangguiAlarmRecord,
    nowEpochMs: Int64
  ) async throws {
    let tombstone = DangguiAlarmCancellationPolicy.makeObservedRetirementTombstone(
      record: record,
      currentMirror: DangguiAlarmStore.record(reminderID: record.reminderID),
      transactions: DangguiAlarmStore.transactions(),
      existing: DangguiAlarmStore.cancellation(
        reminderID: record.reminderID,
        deviceGeneration: record.deviceGeneration
      ),
      nowEpochMs: nowEpochMs
    )
    try DangguiAlarmStore.upsertCancellation(tombstone)
    do {
      try await continueCancellation(tombstone)
    } catch {
      // Recovery owns any raced daemon registration; no stopped event exists.
    }
  }

  private func targetRecord(
    reminderID: String,
    expectedRevision: Int?,
    expectedSession: String?
  ) -> DangguiAlarmRecord? {
    guard let expectedRevision, let expectedSession else { return nil }
    return DangguiAlarmStore.authoritativeActionRecord(
      reminderID: reminderID,
      scheduleRevision: expectedRevision,
      platformAlarmID: expectedSession
    )
  }

  private func discardSupersededTransactions(
    reminderID: String,
    preservingPlatformAlarmID: String
  ) async throws {
    var activeIDs = try await DangguiAlarmKitControllerV2.activeIDs()
    let preserved = preservingPlatformAlarmID.lowercased()
    for transaction in DangguiAlarmStore.transactions()
      where transaction.reminderID == reminderID {
      let replacementID = transaction.replacement.platformAlarmID.lowercased()
      if activeIDs.contains(replacementID), replacementID != preserved {
        try await DangguiAlarmKitControllerV2.cancel(platformAlarmID: replacementID)
        activeIDs.remove(replacementID)
      }
      try DangguiAlarmStore.removeTransaction(transactionID: transaction.transactionID)
    }
  }

  private func cancelOtherActiveAlarms(
    reminderID: String,
    excludingPlatformAlarmID: String
  ) async throws {
    var candidates = Set<String>()
    if let current = DangguiAlarmStore.record(reminderID: reminderID) {
      candidates.insert(current.platformAlarmID.lowercased())
    }
    for transaction in DangguiAlarmStore.transactions()
      where transaction.reminderID == reminderID {
      candidates.insert(transaction.replacement.platformAlarmID.lowercased())
      if let previous = transaction.previousPlatformAlarmID {
        candidates.insert(previous.lowercased())
      }
    }
    candidates.remove(excludingPlatformAlarmID.lowercased())
    let activeIDs = try await DangguiAlarmKitControllerV2.activeIDs()
    for platformID in candidates where activeIDs.contains(platformID) {
      try await DangguiAlarmKitControllerV2.cancel(platformAlarmID: platformID)
    }
  }

  private static var nowEpochMs: Int64 {
    Int64(Date().timeIntervalSince1970 * 1_000)
  }

  private func withExclusiveOperation<Value>(
    _ operation: () async throws -> Value
  ) async rethrows -> Value {
    await acquireExclusiveOperation()
    defer { releaseExclusiveOperation() }
    return try await operation()
  }

  private func acquireExclusiveOperation() async {
    if !operationInProgress {
      operationInProgress = true
      return
    }
    await withCheckedContinuation { continuation in
      operationWaiters.append(continuation)
    }
  }

  private func releaseExclusiveOperation() {
    guard !operationWaiters.isEmpty else {
      operationInProgress = false
      return
    }
    operationWaiters.removeFirst().resume()
  }
}

@available(iOS 26.0, *)
enum DangguiAlarmKitControllerV2 {
  typealias Configuration = AlarmManager.AlarmConfiguration<DangguiAlarmMetadata>

  @MainActor
  static func alarms() throws -> [Alarm] {
    try AlarmManager.shared.alarms
  }

  @MainActor
  static func activeIDs() throws -> Set<String> {
    Set(try alarms().map { $0.id.uuidString.lowercased() })
  }

  @MainActor
  static func schedule(
    _ record: DangguiAlarmRecord,
    triggerDate: Date
  ) async throws {
    guard let alarmID = UUID(uuidString: record.platformAlarmID) else {
      throw DangguiAlarmBridgeError.invalidPlatformAlarmID
    }
    let configuration = makeConfiguration(for: record, triggerDate: triggerDate)
    _ = try await AlarmManager.shared.schedule(id: alarmID, configuration: configuration)
  }

  @MainActor
  static func cancel(platformAlarmID: String) throws {
    guard let alarmID = UUID(uuidString: platformAlarmID) else {
      throw DangguiAlarmBridgeError.invalidPlatformAlarmID
    }
    try AlarmManager.shared.cancel(id: alarmID)
  }

  @MainActor
  static func stop(platformAlarmID: String) throws {
    guard let alarmID = UUID(uuidString: platformAlarmID) else {
      throw DangguiAlarmBridgeError.invalidPlatformAlarmID
    }
    try AlarmManager.shared.stop(id: alarmID)
  }

  static func failureKind(for error: Error) -> DangguiAlarmFailureKind {
    guard let alarmError = error as? AlarmManager.AlarmError else {
      return .other
    }
    switch alarmError {
    case .maximumLimitReached:
      return .capacity
    @unknown default:
      return .other
    }
  }

  static func stateName(_ state: Alarm.State) -> String {
    switch state {
    case .scheduled:
      return "scheduled"
    case .alerting:
      return "ringing"
    case .countdown:
      return "countdown"
    case .paused:
      return "paused"
    @unknown default:
      return "unknown"
    }
  }

  @MainActor
  private static func makeConfiguration(
    for record: DangguiAlarmRecord,
    triggerDate: Date
  ) -> Configuration {
    let label = LocalizedStringResource(
      stringLiteral: record.title.isEmpty ? "当归提醒" : record.title
    )
    let buttonLabels = localizedButtonLabels(localeTag: record.localeTag)
    let secondaryButton = AlarmButton(
      text: LocalizedStringResource(stringLiteral: buttonLabels.snooze),
      textColor: .white,
      systemImageName: "clock.arrow.circlepath"
    )
    let alert: AlarmPresentation.Alert
    if #available(iOS 26.1, *) {
      alert = AlarmPresentation.Alert(
        title: label,
        secondaryButton: secondaryButton,
        secondaryButtonBehavior: .custom
      )
    } else {
      alert = AlarmPresentation.Alert(
        title: label,
        stopButton: AlarmButton(
          text: LocalizedStringResource(stringLiteral: buttonLabels.stop),
          textColor: .white,
          systemImageName: "stop.circle.fill"
        ),
        secondaryButton: secondaryButton,
        secondaryButtonBehavior: .custom
      )
    }
    let attributes = AlarmAttributes(
      presentation: AlarmPresentation(alert: alert),
      metadata: DangguiAlarmMetadata(
        reminderID: record.reminderID,
        taskID: record.taskID,
        scheduleRevision: record.scheduleRevision,
        deviceGeneration: record.deviceGeneration
      ),
      tintColor: Color(red: 0.46, green: 0.55, blue: 0.46)
    )
    return Configuration.alarm(
      schedule: .fixed(triggerDate),
      attributes: attributes,
      stopIntent: DangguiStopAlarmIntent(
        platformAlarmID: record.platformAlarmID,
        reminderID: record.reminderID,
        scheduleRevision: record.scheduleRevision
      ),
      secondaryIntent: DangguiSnoozeAlarmIntent(
        platformAlarmID: record.platformAlarmID,
        reminderID: record.reminderID,
        scheduleRevision: record.scheduleRevision
      )
    )
  }

  private static func localizedButtonLabels(
    localeTag: String
  ) -> (stop: String, snooze: String) {
    let normalized = localeTag.lowercased()
    if normalized.hasPrefix("en") {
      return ("Stop", "Snooze")
    }
    if normalized.hasPrefix("ja") {
      return ("停止", "スヌーズ")
    }
    if normalized.hasPrefix("ru") {
      return ("Остановить", "Отложить")
    }
    return ("停止", "稍后提醒")
  }
}
#endif
