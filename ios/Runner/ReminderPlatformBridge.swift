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
          "timeSensitiveSupported": true,
          "timeSensitiveEnabled": timeSensitiveEnabled,
          "timeSensitiveAuthorized": timeSensitiveEnabled,
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
            try await DangguiAlarmKitController.schedule(record)
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
      do {
        try DangguiAlarmKitController.cancel(reminderID: reminderID)
      } catch {
        result(alarmError("alarm_cancel_failed", error))
        return
      }
    } else {
      DangguiAlarmStore.remove(reminderID: reminderID)
    }
#else
    DangguiAlarmStore.remove(reminderID: reminderID)
#endif
    result(nil)
  }

  private func stopAlarm(arguments: Any?, result: @escaping FlutterResult) {
    guard let reminderID = reminderID(from: arguments) else {
      result(missingReminderIDError())
      return
    }
#if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      do {
        try DangguiAlarmKitController.stop(reminderID: reminderID)
        result(nil)
      } catch {
        result(alarmError("alarm_stop_failed", error))
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
#if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      Task { @MainActor in
        do {
          try await DangguiAlarmKitController.snooze(
            reminderID: reminderID,
            minutes: requestedMinutes
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
      do {
        let records = try DangguiAlarmKitController.reconcileAndList()
        result(records.map(\.flutterMap))
      } catch {
        result(alarmError("alarm_list_failed", error))
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
      try? DangguiAlarmKitController.reconcileAndList()
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

  private func alarmError(_ code: String, _ error: Error) -> FlutterError {
    FlutterError(code: code, message: error.localizedDescription, details: nil)
  }

  // MARK: Alarm observation

  private func startObservingAlarmKit() {
#if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      alarmObserverTask = Task {
        for await alarms in AlarmManager.shared.alarmUpdates {
          if Task.isCancelled { break }
          DangguiAlarmKitController.reconcile(alarms)
        }
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
  /// Produces a stable UUID-shaped identifier from the app's reminder ID.
  /// AlarmKit requires UUID identifiers while Danggui's durable IDs are
  /// strings. A deterministic mapping also prevents concurrent reconciliation
  /// attempts from creating orphan platform alarms.
  static func platformID(for reminderID: String) -> String {
    let bytes = Array(reminderID.utf8)
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
    guard triggerAtEpochMs > Int64(Date().timeIntervalSince1970 * 1_000) else {
      throw DangguiAlarmBridgeError.triggerDateNotInFuture
    }

    self.reminderID = reminderID
    platformAlarmID = DangguiAlarmStore.record(reminderID: reminderID)?.platformAlarmID
      ?? DangguiAlarmIdentifier.platformID(for: reminderID)
    taskID = ReminderPlatformBridge.string(values, keys: ["taskId"]) ?? ""
    scheduleRevision = ReminderPlatformBridge.integer(
      values,
      keys: ["scheduleRevision", "revision"]
    ) ?? 0
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
    lastState = "scheduled"
    firedEventRecorded = false
  }

  var triggerDate: Date {
    Date(timeIntervalSince1970: TimeInterval(triggerAtEpochMs) / 1_000)
  }

  var flutterMap: [String: Any] {
    [
      "reminderId": reminderID,
      "platformAlarmId": platformAlarmID,
      "taskId": taskID,
      "scheduleRevision": scheduleRevision,
      "triggerAtEpochMs": triggerAtEpochMs,
      "title": title,
      "state": lastState,
    ]
  }
}

struct DangguiAlarmEvent: Codable, Hashable, Sendable {
  var eventID: String
  var type: String
  var reminderID: String
  var taskID: String
  var scheduleRevision: Int
  var occurredAtEpochMs: Int64
  var snoozeMinutes: Int?

  init(type: String, record: DangguiAlarmRecord, snoozeMinutes: Int? = nil) {
    eventID = UUID().uuidString
    self.type = type
    reminderID = record.reminderID
    taskID = record.taskID
    scheduleRevision = record.scheduleRevision
    occurredAtEpochMs = Int64(Date().timeIntervalSince1970 * 1_000)
    self.snoozeMinutes = snoozeMinutes
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
    return value
  }
}

enum DangguiAlarmBridgeError: LocalizedError {
  case invalidArguments
  case missingReminderID
  case missingTriggerDate
  case triggerDateNotInFuture
  case alarmNotFound
  case invalidPlatformAlarmID

  var errorDescription: String? {
    switch self {
    case .invalidArguments:
      return "Alarm arguments must be a map."
    case .missingReminderID:
      return "A non-empty reminderId is required."
    case .missingTriggerDate:
      return "A triggerAtEpochMs value is required."
    case .triggerDateNotInFuture:
      return "The alarm trigger must be in the future."
    case .alarmNotFound:
      return "The requested alarm is not scheduled."
    case .invalidPlatformAlarmID:
      return "The stored AlarmKit identifier is invalid."
    }
  }
}

enum DangguiAlarmStore {
  private static let lock = NSLock()
  private static let recordsKey = "danggui.nativeAlarms.records.v1"
  private static let eventsKey = "danggui.nativeAlarms.events.v1"
  private static let maximumEvents = 256

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
      loadRecordsUnlocked().first { $0.platformAlarmID == platformAlarmID }
    }
  }

  static func upsert(_ record: DangguiAlarmRecord) {
    withLock {
      var records = loadRecordsUnlocked()
      records.removeAll { $0.reminderID == record.reminderID }
      records.append(record)
      saveRecordsUnlocked(records)
    }
  }

  @discardableResult
  static func remove(reminderID: String) -> DangguiAlarmRecord? {
    withLock {
      var records = loadRecordsUnlocked()
      guard let index = records.firstIndex(where: { $0.reminderID == reminderID }) else {
        return nil
      }
      let removed = records.remove(at: index)
      saveRecordsUnlocked(records)
      return removed
    }
  }

  static func appendEvent(_ event: DangguiAlarmEvent) {
    withLock {
      var events = loadEventsUnlocked()
      events.append(event)
      if events.count > maximumEvents {
        events.removeFirst(events.count - maximumEvents)
      }
      saveEventsUnlocked(events)
    }
  }

  static func events() -> [DangguiAlarmEvent] {
    withLock {
      loadEventsUnlocked()
    }
  }

  static func acknowledgeEvents(_ eventIDs: Set<String>) {
    guard !eventIDs.isEmpty else { return }
    withLock {
      let remaining = loadEventsUnlocked().filter { !eventIDs.contains($0.eventID) }
      saveEventsUnlocked(remaining)
    }
  }

  private static func withLock<T>(_ body: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return body()
  }

  private static func loadRecordsUnlocked() -> [DangguiAlarmRecord] {
    guard let data = UserDefaults.standard.data(forKey: recordsKey) else { return [] }
    return (try? JSONDecoder().decode([DangguiAlarmRecord].self, from: data)) ?? []
  }

  private static func saveRecordsUnlocked(_ records: [DangguiAlarmRecord]) {
    guard let data = try? JSONEncoder().encode(records) else { return }
    UserDefaults.standard.set(data, forKey: recordsKey)
  }

  private static func loadEventsUnlocked() -> [DangguiAlarmEvent] {
    guard let data = UserDefaults.standard.data(forKey: eventsKey) else { return [] }
    return (try? JSONDecoder().decode([DangguiAlarmEvent].self, from: data)) ?? []
  }

  private static func saveEventsUnlocked(_ events: [DangguiAlarmEvent]) {
    guard let data = try? JSONEncoder().encode(events) else { return }
    UserDefaults.standard.set(data, forKey: eventsKey)
  }
}

// MARK: AlarmKit implementation (iOS 26+ only)

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

  func perform() throws -> some IntentResult {
    guard
      let record = DangguiAlarmStore.record(platformAlarmID: platformAlarmID)
    else {
      return .result()
    }
    try DangguiAlarmKitController.stop(reminderID: record.reminderID)
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
    try await DangguiAlarmKitController.snooze(
      reminderID: record.reminderID,
      minutes: record.defaultSnoozeMinutes
    )
    return .result()
  }
}

@available(iOS 26.0, *)
enum DangguiAlarmKitController {
  typealias Configuration = AlarmManager.AlarmConfiguration<DangguiAlarmMetadata>

  static func schedule(_ requestedRecord: DangguiAlarmRecord) async throws {
    var record = requestedRecord
    guard let alarmID = UUID(uuidString: record.platformAlarmID) else {
      throw DangguiAlarmBridgeError.invalidPlatformAlarmID
    }

    // Reuse the stable platform UUID for edits. AlarmKit doesn't expose an
    // update API, so cancel before replacing; Dart's durable outbox retries a
    // failed replacement on the next reconciliation.
    if try AlarmManager.shared.alarms.contains(where: { $0.id == alarmID }) {
      try AlarmManager.shared.cancel(id: alarmID)
    }
    let configuration = makeConfiguration(for: record)
    _ = try await AlarmManager.shared.schedule(id: alarmID, configuration: configuration)
    record.lastState = "scheduled"
    record.firedEventRecorded = false
    DangguiAlarmStore.upsert(record)
  }

  static func cancel(reminderID: String) throws {
    guard let record = DangguiAlarmStore.record(reminderID: reminderID) else { return }
    guard let alarmID = UUID(uuidString: record.platformAlarmID) else {
      throw DangguiAlarmBridgeError.invalidPlatformAlarmID
    }
    if try AlarmManager.shared.alarms.contains(where: { $0.id == alarmID }) {
      try AlarmManager.shared.cancel(id: alarmID)
    }
    DangguiAlarmStore.remove(reminderID: reminderID)
  }

  static func stop(reminderID: String) throws {
    guard var record = DangguiAlarmStore.record(reminderID: reminderID) else { return }
    guard let alarmID = UUID(uuidString: record.platformAlarmID) else {
      throw DangguiAlarmBridgeError.invalidPlatformAlarmID
    }
    if try AlarmManager.shared.alarms.contains(where: { $0.id == alarmID }) {
      try AlarmManager.shared.stop(id: alarmID)
    }
    if !record.firedEventRecorded {
      DangguiAlarmStore.appendEvent(DangguiAlarmEvent(type: "fired", record: record))
      record.firedEventRecorded = true
    }
    DangguiAlarmStore.appendEvent(DangguiAlarmEvent(type: "stopped", record: record))
    DangguiAlarmStore.remove(reminderID: reminderID)
  }

  static func snooze(reminderID: String, minutes: Int?) async throws {
    guard var record = DangguiAlarmStore.record(reminderID: reminderID) else {
      throw DangguiAlarmBridgeError.alarmNotFound
    }
    let snoozeMinutes = min(1_440, max(1, minutes ?? record.defaultSnoozeMinutes))
    if !record.firedEventRecorded {
      DangguiAlarmStore.appendEvent(DangguiAlarmEvent(type: "fired", record: record))
      record.firedEventRecorded = true
      DangguiAlarmStore.upsert(record)
    }
    guard let alarmID = UUID(uuidString: record.platformAlarmID) else {
      throw DangguiAlarmBridgeError.invalidPlatformAlarmID
    }
    if try AlarmManager.shared.alarms.contains(where: { $0.id == alarmID }) {
      do {
        try AlarmManager.shared.stop(id: alarmID)
      } catch {
        try AlarmManager.shared.cancel(id: alarmID)
      }
      if try AlarmManager.shared.alarms.contains(where: { $0.id == alarmID }) {
        try AlarmManager.shared.cancel(id: alarmID)
      }
    }

    // The event belongs to the alarm revision the user just snoozed. The
    // replacement must advance its revision so multiple native snoozes can be
    // replayed in order even when Flutter was not running between them.
    let snoozedEvent = DangguiAlarmEvent(
      type: "snoozed",
      record: record,
      snoozeMinutes: snoozeMinutes
    )
    record.scheduleRevision += 1
    record.triggerAtEpochMs = Int64(
      Date().addingTimeInterval(TimeInterval(snoozeMinutes * 60)).timeIntervalSince1970
        * 1_000
    )
    record.lastState = "scheduled"
    record.firedEventRecorded = false
    let configuration = makeConfiguration(for: record)
    _ = try await AlarmManager.shared.schedule(id: alarmID, configuration: configuration)
    DangguiAlarmStore.upsert(record)
    DangguiAlarmStore.appendEvent(snoozedEvent)
  }

  static func reconcileAndList() throws -> [DangguiAlarmRecord] {
    let alarms = try AlarmManager.shared.alarms
    reconcile(alarms)
    let activeIDs = Set(alarms.map { $0.id.uuidString.lowercased() })
    return DangguiAlarmStore.records()
      .filter { activeIDs.contains($0.platformAlarmID.lowercased()) }
      .sorted { $0.triggerAtEpochMs < $1.triggerAtEpochMs }
  }

  static func reconcile(_ alarms: [Alarm]) {
    let remoteByID = Dictionary(
      uniqueKeysWithValues: alarms.map { ($0.id.uuidString.lowercased(), $0) }
    )
    let nowEpochMs = Int64(Date().timeIntervalSince1970 * 1_000)

    for var record in DangguiAlarmStore.records() {
      let platformID = record.platformAlarmID.lowercased()
      guard let alarm = remoteByID[platformID] else {
        if record.triggerAtEpochMs <= nowEpochMs {
          if !record.firedEventRecorded {
            DangguiAlarmStore.appendEvent(DangguiAlarmEvent(type: "fired", record: record))
          }
          // A custom intent is unavailable before the device's first unlock.
          // When AlarmKit has already removed this alarm, mirror the terminal
          // system transition so Flutter cannot leave it scheduled forever.
          DangguiAlarmStore.appendEvent(DangguiAlarmEvent(type: "stopped", record: record))
        }
        // A missing future alarm is also removed from the mirror so Dart's
        // reconciliation can restore it from the database.
        DangguiAlarmStore.remove(reminderID: record.reminderID)
        continue
      }

      let state = stateName(alarm.state)
      if state == "alerting" && !record.firedEventRecorded {
        DangguiAlarmStore.appendEvent(DangguiAlarmEvent(type: "fired", record: record))
        record.firedEventRecorded = true
      }
      if record.lastState != state || state == "alerting" {
        record.lastState = state
        DangguiAlarmStore.upsert(record)
      }
    }
  }

  static func makeConfiguration(for record: DangguiAlarmRecord) -> Configuration {
    let label = LocalizedStringResource(
      stringLiteral: record.title.isEmpty ? "当归提醒" : record.title
    )
    let buttonLabels = localizedButtonLabels(localeTag: record.localeTag)
    let alert = AlarmPresentation.Alert(
      title: label,
      secondaryButton: AlarmButton(
        text: LocalizedStringResource(stringLiteral: buttonLabels.snooze),
        textColor: .white,
        systemImageName: "clock.arrow.circlepath"
      ),
      secondaryButtonBehavior: .custom
    )
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
      schedule: .fixed(record.triggerDate),
      attributes: attributes,
      stopIntent: DangguiStopAlarmIntent(platformAlarmID: record.platformAlarmID),
      secondaryIntent: DangguiSnoozeAlarmIntent(platformAlarmID: record.platformAlarmID)
    )
  }

  private static func stateName(_ state: Alarm.State) -> String {
    switch state {
    case .scheduled:
      return "scheduled"
    case .alerting:
      return "alerting"
    case .countdown:
      return "countdown"
    case .paused:
      return "paused"
    @unknown default:
      return "unknown"
    }
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
