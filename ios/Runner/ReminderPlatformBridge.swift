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
    case "cancelAlarm":
      cancelAlarm(arguments: call.arguments, result: result)
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
      DispatchQueue.main.async {
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
#if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      Task { @MainActor in
        do {
          try await DangguiAlarmOperationActor.shared.cancel(reminderID: reminderID)
          result(nil)
        } catch {
          result(self.alarmError("alarm_cancel_failed", error))
        }
      }
      return
    }
#endif
    try? DangguiAlarmStore.remove(reminderID: reminderID)
    try? DangguiAlarmStore.removeTransactions(reminderID: reminderID)
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
        result(DangguiAlarmStore.events().map(\.flutterMap))
      }
      return
    }
#endif
    result(DangguiAlarmStore.events().map(\.flutterMap))
  }

  private func acknowledgeAlarmEvents(
    arguments: Any?,
    result: @escaping FlutterResult
  ) {
    let values = arguments as? [String: Any]
    let eventIDs = Set((values?["eventIds"] as? [String]) ?? [])
    DangguiAlarmStore.acknowledgeEvents(eventIDs)
    result(nil)
  }

  private func scheduleTestAlarm(arguments: Any?, result: @escaping FlutterResult) {
    let values = arguments as? [String: Any]
    let now = Date().timeIntervalSince1970
    let delaySeconds = min(
      3_600,
      max(15, Self.integer(values, keys: ["delaySeconds"]) ?? 15)
    )
    let request: [String: Any] = [
      "reminderId": "danggui-test-\(UUID().uuidString)",
      "taskId": "danggui-test",
      "scheduleRevision": 1,
      "triggerAtEpochMs": Int64((now + Double(delaySeconds)) * 1_000),
      "title": Self.string(values, keys: ["title"]) ?? "当归测试闹钟",
      "body": Self.string(values, keys: ["body"]) ?? "用于检查提醒是否可靠送达",
      "vibrationEnabled": Self.boolean(values, keys: ["vibrationEnabled"]) ?? true,
      "defaultSnoozeMinutes": 10,
    ]
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
  static func platformID(for reminderID: String, revision: Int) -> String {
    let bytes = Array("\(reminderID)\u{1f}\(revision)".utf8)
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

    scheduleRevision = ReminderPlatformBridge.integer(
      values,
      keys: ["scheduleRevision", "revision"]
    ) ?? 0
    self.reminderID = reminderID
    platformAlarmID = DangguiAlarmIdentifier.platformID(
      for: reminderID,
      revision: scheduleRevision
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
    [
      "reminderId": reminderID,
      "platformId": platformAlarmID,
      "platformAlarmId": platformAlarmID,
      "revision": scheduleRevision,
      "scheduleRevision": scheduleRevision,
      "triggerAtEpochMs": triggerAtEpochMs,
      "state": lastState,
    ]
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
  var state: String?
  var errorCode: String?
  var delayedByMs: Int64?
  var successorTriggerAtEpochMs: Int64?

  init(
    type: DangguiAlarmEventType,
    record: DangguiAlarmRecord,
    snoozeMinutes: Int? = nil,
    state: String? = nil,
    errorCode: String? = nil,
    delayedByMs: Int64? = nil,
    occurredAtEpochMs: Int64? = nil,
    successorTriggerAtEpochMs: Int64? = nil
  ) {
    eventID = UUID().uuidString
    self.type = type.rawValue
    reminderID = record.reminderID
    taskID = record.taskID
    scheduleRevision = record.scheduleRevision
    self.occurredAtEpochMs = occurredAtEpochMs
      ?? Int64(Date().timeIntervalSince1970 * 1_000)
    self.snoozeMinutes = snoozeMinutes
    platformAlarmID = record.platformAlarmID
    self.state = state
    self.errorCode = errorCode
    self.delayedByMs = delayedByMs
    self.successorTriggerAtEpochMs = successorTriggerAtEpochMs
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

  init(
    replacement: DangguiAlarmRecord,
    previousPlatformAlarmID: String?,
    previousRecord: DangguiAlarmRecord? = nil,
    stopPreviousWhenConfirmed: Bool = false,
    completionEvent: DangguiAlarmEvent? = nil
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

struct DangguiAlarmCancellation: Codable, Hashable, Sendable {
  var cancellationID: String
  var reminderID: String
  var cancelledThroughRevision: Int
  var platformAlarmIDs: [String]
  var phase: DangguiAlarmCancellationPhase
  var updatedAtEpochMs: Int64

  init(
    reminderID: String,
    cancelledThroughRevision: Int,
    platformAlarmIDs: Set<String>,
    nowEpochMs: Int64
  ) {
    cancellationID = UUID().uuidString
    self.reminderID = reminderID
    self.cancelledThroughRevision = cancelledThroughRevision
    self.platformAlarmIDs = platformAlarmIDs.map { $0.lowercased() }.sorted()
    phase = .pending
    updatedAtEpochMs = nowEpochMs
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

/// Pure compare-and-swap rules shared by method-channel and AppIntent paths.
enum DangguiAlarmMutationPolicy {
  static func scheduleDecision(
    requested: DangguiAlarmRecord,
    current: DangguiAlarmRecord?,
    transactions: [DangguiAlarmTransaction],
    cancellation: DangguiAlarmCancellation?
  ) -> DangguiAlarmScheduleDecision {
    let related = transactions.filter { $0.reminderID == requested.reminderID }
    let knownRecords = ([current].compactMap { $0 } + related.map(\.replacement))
      .filter { $0.reminderID == requested.reminderID }
    let highestRecordRevision = knownRecords.map(\.scheduleRevision).max()
    let highestKnownRevision = [
      highestRecordRevision,
      cancellation?.cancelledThroughRevision,
    ].compactMap { $0 }.max()

    guard let highestKnownRevision else { return .install }
    if let cancellation {
      if cancellation.phase != .completed
        || requested.scheduleRevision <= cancellation.cancelledThroughRevision {
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
    if let cancellation {
      if cancellation.phase != .completed
        || current.scheduleRevision <= cancellation.cancelledThroughRevision {
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
  static func makeTombstone(
    reminderID: String,
    current: DangguiAlarmRecord?,
    transactions: [DangguiAlarmTransaction],
    existing: DangguiAlarmCancellation?,
    nowEpochMs: Int64
  ) -> DangguiAlarmCancellation {
    let related = transactions.filter { $0.reminderID == reminderID }
    var ids = Set(existing?.platformAlarmIDs ?? [])
    var revisions = [existing?.cancelledThroughRevision, current?.scheduleRevision]
      .compactMap { $0 }
    if let current { ids.insert(current.platformAlarmID.lowercased()) }
    for transaction in related {
      ids.insert(transaction.replacement.platformAlarmID.lowercased())
      revisions.append(transaction.replacement.scheduleRevision)
      if let previous = transaction.previousPlatformAlarmID {
        ids.insert(previous.lowercased())
      }
      if let previousRecord = transaction.previousRecord {
        revisions.append(previousRecord.scheduleRevision)
        ids.insert(previousRecord.platformAlarmID.lowercased())
      }
    }
    return DangguiAlarmCancellation(
      reminderID: reminderID,
      cancelledThroughRevision: revisions.max() ?? 0,
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
    }
    guard !related.isEmpty else { return true }
    if related.contains(where: { $0.phase != .completed }) { return false }
    let highWater = related.map(\.cancelledThroughRevision).max() ?? 0
    return record.scheduleRevision > highWater
  }

  static func isSupersededByCompletedCancellation(
    record: DangguiAlarmRecord,
    cancellations: [DangguiAlarmCancellation]
  ) -> Bool {
    let completedHighWater = cancellations
      .filter { $0.reminderID == record.reminderID && $0.phase == .completed }
      .map(\.cancelledThroughRevision)
      .max()
    guard let completedHighWater else { return false }
    return record.scheduleRevision <= completedHighWater
  }
}

struct DangguiAlarmSnoozePlan: Equatable {
  let replacement: DangguiAlarmRecord
  let completionEvent: DangguiAlarmEvent
}

enum DangguiAlarmSnoozePolicy {
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
      revision: replacement.scheduleRevision
    )
    replacement.triggerAtEpochMs = successorTriggerAtEpochMs
    replacement.lastState = "pending"
    replacement.firedEventRecorded = false
    let event = DangguiAlarmEvent(
      type: .snoozed,
      record: record,
      snoozeMinutes: minutes,
      occurredAtEpochMs: occurredAtEpochMs,
      successorTriggerAtEpochMs: successorTriggerAtEpochMs
    )
    return DangguiAlarmSnoozePlan(replacement: replacement, completionEvent: event)
  }

  static func shouldStopPredecessor(
    transaction: DangguiAlarmTransaction
  ) -> Bool {
    transaction.stopPreviousWhenConfirmed == true && transaction.phase == .confirmed
  }
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
}

enum DangguiAlarmBridgeError: LocalizedError {
  case invalidArguments
  case missingReminderID
  case missingTriggerDate
  case invalidTriggerDate
  case alarmNotFound
  case invalidPlatformAlarmID
  case invalidTransactionTransition
  case invalidCancellationTransition

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
    case .alarmNotFound:
      return "The requested alarm is not scheduled."
    case .invalidPlatformAlarmID:
      return "The stored AlarmKit identifier is invalid."
    case .invalidTransactionTransition:
      return "The persisted alarm transaction has an invalid state transition."
    case .invalidCancellationTransition:
      return "The persisted alarm cancellation has an invalid state transition."
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
    }
  }
}

private struct DangguiLossyValue<Value: Decodable>: Decodable {
  let value: Value?

  init(from decoder: Decoder) throws {
    value = try? Value(from: decoder)
  }
}

enum DangguiAlarmStore {
  private static let lock = NSLock()
  private static let legacyRecordsKey = "danggui.nativeAlarms.records.v1"
  private static let legacyEventsKey = "danggui.nativeAlarms.events.v1"
  private static let recordsFilename = "native-alarms-v2.json"
  private static let eventsFilename = "alarm-events-v2.json"
  private static let transactionsFilename = "alarm-transactions-v1.json"
  private static let cancellationsFilename = "alarm-cancellations-v1.json"
  private static let maximumEvents = 200
  private static var baseDirectoryOverride: URL?

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

  static func upsert(_ record: DangguiAlarmRecord) throws {
    try withLock {
      var records = loadRecordsUnlocked()
      records.removeAll { $0.reminderID == record.reminderID }
      records.append(record)
      try saveRecordsUnlocked(records)
    }
  }

  @discardableResult
  static func remove(reminderID: String) throws -> DangguiAlarmRecord? {
    try withLock {
      var records = loadRecordsUnlocked()
      guard let index = records.firstIndex(where: { $0.reminderID == reminderID }) else {
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
      var transactions = loadTransactionsUnlocked()
      transactions.removeAll { $0.transactionID == transaction.transactionID }
      transactions.append(transaction)
      try saveTransactionsUnlocked(transactions)
    }
  }

  static func removeTransaction(transactionID: String) throws {
    try withLock {
      let remaining = loadTransactionsUnlocked().filter {
        $0.transactionID != transactionID
      }
      try saveTransactionsUnlocked(remaining)
    }
  }

  static func removeTransactions(reminderID: String) throws {
    try withLock {
      let remaining = loadTransactionsUnlocked().filter {
        $0.reminderID != reminderID
      }
      try saveTransactionsUnlocked(remaining)
    }
  }

  static func cancellations() -> [DangguiAlarmCancellation] {
    withLock { loadCancellationsUnlocked() }
  }

  static func cancellation(reminderID: String) -> DangguiAlarmCancellation? {
    withLock {
      loadCancellationsUnlocked().first { $0.reminderID == reminderID }
    }
  }

  static func upsertCancellation(_ cancellation: DangguiAlarmCancellation) throws {
    try withLock {
      var cancellations = loadCancellationsUnlocked()
      cancellations.removeAll { $0.reminderID == cancellation.reminderID }
      cancellations.append(cancellation)
      try saveCancellationsUnlocked(cancellations)
    }
  }

  static func appendEvent(_ event: DangguiAlarmEvent) {
    do {
      try appendEventDurably(event)
    } catch {
      NSLog("Danggui could not persist an alarm diagnostic event: %@", error.localizedDescription)
    }
  }

  static func appendEventDurably(_ event: DangguiAlarmEvent) throws {
    try withLock {
      var events = loadEventsUnlocked()
      // Transaction recovery may retry after the event write but before the
      // transaction removal. Stable event IDs make that retry idempotent.
      events.removeAll { $0.eventID == event.eventID }
      events.append(event)
      if events.count > maximumEvents {
        events.removeFirst(events.count - maximumEvents)
      }
      try saveEventsUnlocked(events)
    }
  }

  static func events() -> [DangguiAlarmEvent] {
    withLock { loadEventsUnlocked() }
  }

  static func acknowledgeEvents(_ eventIDs: Set<String>) {
    guard !eventIDs.isEmpty else { return }
    withLock {
      do {
        let remaining = loadEventsUnlocked().filter { !eventIDs.contains($0.eventID) }
        try saveEventsUnlocked(remaining)
      } catch {
        NSLog("Danggui could not acknowledge alarm events: %@", error.localizedDescription)
      }
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

  private static func withLock<T>(_ body: () throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    return try body()
  }

  private static func loadRecordsUnlocked() -> [DangguiAlarmRecord] {
    if let records = loadArrayUnlocked(
      DangguiAlarmRecord.self,
      filename: recordsFilename
    ) {
      return records
    }
    guard let legacy = UserDefaults.standard.data(forKey: legacyRecordsKey) else {
      return []
    }
    guard let migrated = decodeLossyArray(DangguiAlarmRecord.self, from: legacy) else {
      return []
    }
    do {
      try saveRecordsUnlocked(migrated)
      UserDefaults.standard.removeObject(forKey: legacyRecordsKey)
    } catch {
      NSLog("Danggui could not migrate the legacy alarm mirror: %@", error.localizedDescription)
    }
    return migrated
  }

  private static func saveRecordsUnlocked(_ records: [DangguiAlarmRecord]) throws {
    try saveArrayUnlocked(records, filename: recordsFilename)
  }

  private static func loadEventsUnlocked() -> [DangguiAlarmEvent] {
    if let events = loadArrayUnlocked(
      DangguiAlarmEvent.self,
      filename: eventsFilename
    ) {
      return Array(events.suffix(maximumEvents))
    }
    guard let legacy = UserDefaults.standard.data(forKey: legacyEventsKey) else {
      return []
    }
    guard let legacyEvents = decodeLossyArray(DangguiAlarmEvent.self, from: legacy) else {
      return []
    }
    let migrated = Array(legacyEvents.suffix(maximumEvents))
    do {
      try saveEventsUnlocked(migrated)
      UserDefaults.standard.removeObject(forKey: legacyEventsKey)
    } catch {
      NSLog("Danggui could not migrate the legacy alarm events: %@", error.localizedDescription)
    }
    return migrated
  }

  private static func saveEventsUnlocked(_ events: [DangguiAlarmEvent]) throws {
    try saveArrayUnlocked(Array(events.suffix(maximumEvents)), filename: eventsFilename)
  }

  private static func loadTransactionsUnlocked() -> [DangguiAlarmTransaction] {
    loadArrayUnlocked(
      DangguiAlarmTransaction.self,
      filename: transactionsFilename
    ) ?? []
  }

  private static func saveTransactionsUnlocked(
    _ transactions: [DangguiAlarmTransaction]
  ) throws {
    try saveArrayUnlocked(transactions, filename: transactionsFilename)
  }

  private static func loadCancellationsUnlocked() -> [DangguiAlarmCancellation] {
    loadArrayUnlocked(
      DangguiAlarmCancellation.self,
      filename: cancellationsFilename
    ) ?? []
  }

  private static func saveCancellationsUnlocked(
    _ cancellations: [DangguiAlarmCancellation]
  ) throws {
    try saveArrayUnlocked(cancellations, filename: cancellationsFilename)
  }

  private static func saveArrayUnlocked<Value: Codable>(
    _ values: [Value],
    filename: String
  ) throws {
    let data = try JSONEncoder().encode(values)
    let url = try fileURLUnlocked(filename: filename)
    if let existing = try? Data(contentsOf: url),
       decodeLossyArray(Value.self, from: existing) != nil {
      try? existing.write(to: backupURL(for: url), options: .atomic)
    }
    try data.write(to: url, options: .atomic)
  }

  private static func loadArrayUnlocked<Value: Decodable>(
    _ type: Value.Type,
    filename: String
  ) -> [Value]? {
    guard let url = try? fileURLUnlocked(filename: filename) else { return nil }
    if let data = try? Data(contentsOf: url),
       let decoded = decodeLossyArray(type, from: data) {
      return decoded
    }
    if let backupData = try? Data(contentsOf: backupURL(for: url)),
       let decodedBackup = decodeLossyArray(type, from: backupData) {
      return decodedBackup
    }
    return nil
  }

  private static func decodeLossyArray<Value: Decodable>(
    _ type: Value.Type,
    from data: Data
  ) -> [Value]? {
    guard let values = try? JSONDecoder().decode(
      [DangguiLossyValue<Value>].self,
      from: data
    ) else {
      return nil
    }
    return values.compactMap(\.value)
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
}

@available(iOS 26.0, *)
struct DangguiStopAlarmIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "停止当归提醒"
  static var description = IntentDescription("停止正在响铃的当归提醒")

  @Parameter(title: "Alarm ID")
  var platformAlarmID: String

  init(platformAlarmID: String) {
    self.platformAlarmID = platformAlarmID
  }

  init() {
    platformAlarmID = ""
  }

  func perform() async throws -> some IntentResult {
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

  init(platformAlarmID: String) {
    self.platformAlarmID = platformAlarmID
  }

  init() {
    platformAlarmID = ""
  }

  func perform() async throws -> some IntentResult {
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

  func schedule(_ requestedRecord: DangguiAlarmRecord) async throws {
    try await withExclusiveOperation {
      try await scheduleUnlocked(requestedRecord)
    }
  }

  private func scheduleUnlocked(_ requestedRecord: DangguiAlarmRecord) async throws {
    await recoverPersistedTransactionsUnlocked()
    let relatedTransactions = DangguiAlarmStore.transactions().filter {
      $0.reminderID == requestedRecord.reminderID
    }
    let current = DangguiAlarmStore.record(reminderID: requestedRecord.reminderID)
    let decision = DangguiAlarmMutationPolicy.scheduleDecision(
      requested: requestedRecord,
      current: current,
      transactions: relatedTransactions,
      cancellation: DangguiAlarmStore.cancellation(reminderID: requestedRecord.reminderID)
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
      persistMissed(requestedRecord, nowEpochMs: nowEpochMs)
      throw DangguiAlarmOperationError.expired
    }

    if decision == .idempotent,
       let sameRevision = relatedTransactions.first(where: {
      $0.replacement.scheduleRevision == requestedRecord.scheduleRevision
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
       activeIDs.contains(requestedRecord.platformAlarmID.lowercased()) {
      return
    }

    var previousPlatformAlarmID = current?.platformAlarmID
    var previousRecord = current
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
        try DangguiAlarmStore.removeTransaction(transactionID: transaction.transactionID)
      }
    }

    try await beginReplacement(
      requestedRecord,
      previousPlatformAlarmID: previousPlatformAlarmID,
      previousRecord: previousRecord
    )
  }

  func cancel(reminderID: String) async throws {
    try await withExclusiveOperation {
      try await cancelUnlocked(reminderID: reminderID)
    }
  }

  private func cancelUnlocked(reminderID: String) async throws {
    let cancellation = DangguiAlarmCancellationPolicy.makeTombstone(
      reminderID: reminderID,
      current: DangguiAlarmStore.record(reminderID: reminderID),
      transactions: DangguiAlarmStore.transactions(),
      existing: DangguiAlarmStore.cancellation(reminderID: reminderID),
      nowEpochMs: Self.nowEpochMs
    )
    // This write must succeed before the first irreversible daemon mutation.
    try DangguiAlarmStore.upsertCancellation(cancellation)
    try await continueCancellation(cancellation)
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
    guard var record = targetRecord(
      reminderID: reminderID,
      expectedRevision: expectedRevision,
      expectedSession: expectedSession
    ) else { return }

    let activeIDs = try await DangguiAlarmKitControllerV2.activeIDs()
    if activeIDs.contains(record.platformAlarmID.lowercased()) {
      do {
        try await DangguiAlarmKitControllerV2.stop(platformAlarmID: record.platformAlarmID)
      } catch {
        try await DangguiAlarmKitControllerV2.cancel(platformAlarmID: record.platformAlarmID)
      }
    }
    recordDeliveredIfNeeded(&record)
    DangguiAlarmStore.appendEvent(DangguiAlarmEvent(type: .stopped, record: record))
    try await cancelOtherActiveAlarms(
      reminderID: reminderID,
      excludingPlatformAlarmID: record.platformAlarmID
    )
    _ = try DangguiAlarmStore.remove(reminderID: reminderID)
    try DangguiAlarmStore.removeTransactions(reminderID: reminderID)
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
    guard var record = targetRecord(
      reminderID: reminderID,
      expectedRevision: expectedRevision,
      expectedSession: expectedSession
    ) else {
      throw DangguiAlarmBridgeError.alarmNotFound
    }

    let allowedMinutes = [10, 30, 60]
    let preferred = minutes ?? record.defaultSnoozeMinutes
    let snoozeMinutes = allowedMinutes.contains(preferred)
      ? preferred
      : (allowedMinutes.contains(record.defaultSnoozeMinutes)
          ? record.defaultSnoozeMinutes
          : 10)
    let occurredAtEpochMs = Self.nowEpochMs
    recordDeliveredIfNeeded(&record)
    let plan = DangguiAlarmSnoozePolicy.makePlan(
      record: record,
      minutes: snoozeMinutes,
      occurredAtEpochMs: occurredAtEpochMs
    )
    try await discardSupersededTransactions(
      reminderID: reminderID,
      preservingPlatformAlarmID: record.platformAlarmID
    )
    // beginReplacement writes the pending successor first. Its confirmed
    // phase is the only place allowed to stop the alerting predecessor.
    try await beginReplacement(
      plan.replacement,
      previousPlatformAlarmID: record.platformAlarmID,
      previousRecord: record,
      stopPreviousWhenConfirmed: true,
      completionEvent: plan.completionEvent
    )
  }

  func reconcileAndList() async throws -> [DangguiAlarmRecord] {
    try await withExclusiveOperation {
      try await reconcileAndListUnlocked()
    }
  }

  private func reconcileAndListUnlocked() async throws -> [DangguiAlarmRecord] {
    await recoverPersistedTransactionsUnlocked()
    let alarms = try await DangguiAlarmKitControllerV2.alarms()
    await reconcileUnlocked(alarms, recoverFirst: false)
    let cancellations = DangguiAlarmStore.cancellations()
    return DangguiAlarmStore.records().filter {
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
      await recoverPersistedTransactionsUnlocked()
    }
  }

  private func recoverPersistedTransactionsUnlocked() async {
    await recoverPersistedCancellationsUnlocked()
    let cancellations = DangguiAlarmStore.cancellations()
    for transaction in DangguiAlarmStore.transactions() {
      guard DangguiAlarmStore.transactions().contains(where: {
        $0.transactionID == transaction.transactionID
      }) else { continue }
      let relatedCancellations = cancellations.filter {
        $0.reminderID == transaction.reminderID
      }
      if relatedCancellations.contains(where: { $0.phase != .completed }) {
        continue
      }
      let cancelledThroughRevision = relatedCancellations
        .map(\.cancelledThroughRevision)
        .max()
      if let cancelledThroughRevision,
         transaction.replacement.scheduleRevision <= cancelledThroughRevision {
        await discardNonAuthoritativeTransaction(transaction)
        continue
      }
      let current = DangguiAlarmStore.record(reminderID: transaction.reminderID)
      let decision = DangguiAlarmMutationPolicy.scheduleDecision(
        requested: transaction.replacement,
        current: current,
        transactions: DangguiAlarmStore.transactions(),
        cancellation: relatedCancellations.first
      )
      if decision == .staleRevision {
        await discardNonAuthoritativeTransaction(transaction)
        continue
      }
      if decision == .revisionConflict {
        for conflict in DangguiAlarmStore.transactions().filter({
          $0.reminderID == transaction.reminderID
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
      } catch {
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

  private func recoverPersistedCancellationsUnlocked() async {
    let cancellations = DangguiAlarmStore.cancellations()
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
    guard cancellation.phase != .completed else { return }

    var activeIDs = try await DangguiAlarmKitControllerV2.activeIDs()
    let targets = DangguiAlarmCancellationPolicy.activeTargetIDs(
      cancellation: cancellation,
      activeIDs: activeIDs
    )
    for platformID in targets {
      try await DangguiAlarmKitControllerV2.cancel(platformAlarmID: platformID)
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
      _ = try DangguiAlarmStore.remove(reminderID: cancellation.reminderID)
      try DangguiAlarmStore.removeTransactions(reminderID: cancellation.reminderID)
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
    if recoverFirst {
      await recoverPersistedTransactionsUnlocked()
    }
    let alarms = (try? await DangguiAlarmKitControllerV2.alarms()) ?? suppliedAlarms
    let remoteByID = Dictionary(
      uniqueKeysWithValues: alarms.map { ($0.id.uuidString.lowercased(), $0) }
    )
    let nowEpochMs = Self.nowEpochMs
    let pendingReminderIDs = Set(
      DangguiAlarmStore.transactions().map(\.reminderID)
    )
    let cancellations = DangguiAlarmStore.cancellations()

    for var record in DangguiAlarmStore.records() {
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
          recordDeliveredIfNeeded(&record)
        }
        if record.lastState != state {
          record.lastState = state
          try? DangguiAlarmStore.upsert(record)
        }
        continue
      }

      if record.triggerAtEpochMs <= nowEpochMs {
        let delayedByMs = max(0, nowEpochMs - record.triggerAtEpochMs)
        if DangguiAlarmRecoveryPolicy.isExpired(
          triggerAtEpochMs: record.triggerAtEpochMs,
          nowEpochMs: nowEpochMs
        ) {
          persistMissed(record, nowEpochMs: nowEpochMs)
        } else {
          recordDeliveredIfNeeded(&record, delayedByMs: delayedByMs)
          DangguiAlarmStore.appendEvent(
            DangguiAlarmEvent(type: .stopped, record: record, delayedByMs: delayedByMs)
          )
          _ = try? DangguiAlarmStore.remove(reminderID: record.reminderID)
        }
        continue
      }

      guard !pendingReminderIDs.contains(record.reminderID) else { continue }
      do {
        try await beginReplacement(record, previousPlatformAlarmID: nil)
      } catch {
        // beginReplacement persists a repair state and diagnostic. Keep the
        // mirror so the next reconciliation can retry rather than dropping it.
      }
    }
  }

  private func beginReplacement(
    _ requestedRecord: DangguiAlarmRecord,
    previousPlatformAlarmID: String?,
    previousRecord: DangguiAlarmRecord? = nil,
    stopPreviousWhenConfirmed: Bool = false,
    completionEvent: DangguiAlarmEvent? = nil
  ) async throws {
    var pendingRecord = requestedRecord
    pendingRecord.lastState = "pending"
    pendingRecord.firedEventRecorded = false
    let transaction = DangguiAlarmTransaction(
      replacement: pendingRecord,
      previousPlatformAlarmID: previousPlatformAlarmID,
      previousRecord: previousRecord,
      stopPreviousWhenConfirmed: stopPreviousWhenConfirmed,
      completionEvent: completionEvent
    )
    try DangguiAlarmStore.upsertTransaction(transaction)
    try await continueTransaction(transaction)
  }

  private func continueTransaction(
    _ persistedTransaction: DangguiAlarmTransaction
  ) async throws {
    var transaction = persistedTransaction
    let now = Date()
    let nowEpochMs = Int64(now.timeIntervalSince1970 * 1_000)
    if DangguiAlarmRecoveryPolicy.isExpired(
      triggerAtEpochMs: transaction.replacement.triggerAtEpochMs,
      nowEpochMs: nowEpochMs
    ) {
      let activeIDs = (try? await DangguiAlarmKitControllerV2.activeIDs()) ?? []
      let candidateIDs = [
        transaction.replacement.platformAlarmID,
        transaction.previousPlatformAlarmID,
      ].compactMap { $0?.lowercased() }
      for platformID in candidateIDs where activeIDs.contains(platformID) {
        try? await DangguiAlarmKitControllerV2.cancel(platformAlarmID: platformID)
      }
      try persistCompletionEventIfNeeded(transaction)
      persistMissed(transaction.replacement, nowEpochMs: nowEpochMs)
      try? DangguiAlarmStore.removeTransaction(transactionID: transaction.transactionID)
      throw DangguiAlarmOperationError.expired
    }

    var activeIDs = try await DangguiAlarmKitControllerV2.activeIDs()
    let replacementID = transaction.replacement.platformAlarmID.lowercased()

    if transaction.phase != .pending, !activeIDs.contains(replacementID) {
      if transaction.replacement.triggerAtEpochMs <= nowEpochMs {
        // Apple documents that a one-shot alarm disappears from `alarms` after
        // it fires and stops. A previously scheduled transaction must therefore
        // be finalized, not recreated as a duplicate late alarm.
        var delivered = transaction.replacement
        try persistCompletionEventIfNeeded(transaction)
        recordDeliveredIfNeeded(
          &delivered,
          delayedByMs: max(0, nowEpochMs - delivered.triggerAtEpochMs)
        )
        DangguiAlarmStore.appendEvent(
          DangguiAlarmEvent(type: .stopped, record: delivered)
        )
        if let previous = transaction.previousPlatformAlarmID?.lowercased(),
           activeIDs.contains(previous) {
          try? await DangguiAlarmKitControllerV2.cancel(platformAlarmID: previous)
        }
        _ = try? DangguiAlarmStore.remove(reminderID: delivered.reminderID)
        try? DangguiAlarmStore.removeTransaction(transactionID: transaction.transactionID)
        return
      }

      do {
        try await DangguiAlarmKitControllerV2.schedule(
          transaction.replacement,
          triggerDate: transaction.replacement.triggerDate
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
      DangguiAlarmStore.appendEvent(
        DangguiAlarmEvent(
          type: .registered,
          record: transaction.replacement,
          state: "scheduled"
        )
      )
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
  ) {
    var missed = record
    missed.lastState = DangguiAlarmFailureMapper.state(for: .expired)
    DangguiAlarmStore.appendEvent(
      DangguiAlarmEvent(
        type: .missed,
        record: missed,
        state: missed.lastState,
        delayedByMs: max(0, nowEpochMs - missed.triggerAtEpochMs)
      )
    )
    _ = try? DangguiAlarmStore.remove(reminderID: missed.reminderID)
    try? DangguiAlarmStore.removeTransactions(reminderID: missed.reminderID)
  }

  private func recordDeliveredIfNeeded(
    _ record: inout DangguiAlarmRecord,
    delayedByMs: Int64? = nil
  ) {
    guard !record.firedEventRecorded else { return }
    DangguiAlarmStore.appendEvent(
      DangguiAlarmEvent(
        type: .delivered,
        record: record,
        state: "ringing",
        delayedByMs: delayedByMs
      )
    )
    DangguiAlarmStore.appendEvent(
      DangguiAlarmEvent(
        type: .systemAlert,
        record: record,
        state: "ringing",
        delayedByMs: delayedByMs
      )
    )
    record.firedEventRecorded = true
    try? DangguiAlarmStore.upsert(record)
  }

  private func targetRecord(
    reminderID: String,
    expectedRevision: Int?,
    expectedSession: String?
  ) -> DangguiAlarmRecord? {
    let current = DangguiAlarmStore.record(reminderID: reminderID)
    guard DangguiAlarmMutationPolicy.isAuthoritativeAction(
      reminderID: reminderID,
      expectedRevision: expectedRevision,
      expectedPlatformAlarmID: expectedSession,
      current: current,
      cancellation: DangguiAlarmStore.cancellation(reminderID: reminderID)
    ) else { return nil }
    return current
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
        scheduleRevision: record.scheduleRevision
      ),
      tintColor: Color(red: 0.46, green: 0.55, blue: 0.46)
    )
    return Configuration.alarm(
      schedule: .fixed(triggerDate),
      attributes: attributes,
      stopIntent: DangguiStopAlarmIntent(platformAlarmID: record.platformAlarmID),
      secondaryIntent: DangguiSnoozeAlarmIntent(platformAlarmID: record.platformAlarmID)
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
