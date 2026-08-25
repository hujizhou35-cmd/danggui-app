import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testAlarmRequestUsesSharedDartContract() throws {
    let triggerAtEpochMs = Int64(Date().addingTimeInterval(120).timeIntervalSince1970 * 1_000)
    let record = try DangguiAlarmRecord(arguments: [
      "reminderId": "reminder-1",
      "taskId": "task-1",
      "scheduleRevision": 7,
      "triggerAtEpochMs": triggerAtEpochMs,
      "title": "复习",
      "body": "开始复习",
      "vibrationEnabled": false,
      "defaultSnoozeMinutes": 30,
      "localeTag": "zh-Hans",
    ])

    XCTAssertEqual(record.reminderID, "reminder-1")
    XCTAssertEqual(record.taskID, "task-1")
    XCTAssertEqual(record.scheduleRevision, 7)
    XCTAssertEqual(record.triggerAtEpochMs, triggerAtEpochMs)
    XCTAssertEqual(record.defaultSnoozeMinutes, 30)
    XCTAssertFalse(record.vibrationEnabled)
    XCTAssertNotNil(UUID(uuidString: record.platformAlarmID))
  }

  func testAlarmRequestAcceptsCompatibilityAliasesAndClampsSnooze() throws {
    let triggerAtEpochMs = Int64(Date().addingTimeInterval(120).timeIntervalSince1970 * 1_000)
    let record = try DangguiAlarmRecord(arguments: [
      "alarmId": "legacy-reminder",
      "revision": 3,
      "scheduledAtEpochMs": triggerAtEpochMs,
      "snoozeMinutes": 10_000,
    ])

    XCTAssertEqual(record.reminderID, "legacy-reminder")
    XCTAssertEqual(record.scheduleRevision, 3)
    XCTAssertEqual(record.defaultSnoozeMinutes, 1_440)
  }

  func testPlatformAlarmIdentifierIsStableAndValid() {
    let first = DangguiAlarmIdentifier.platformID(for: "stable-reminder")
    let second = DangguiAlarmIdentifier.platformID(for: "stable-reminder")

    XCTAssertEqual(first, second)
    XCTAssertNotNil(UUID(uuidString: first))
    XCTAssertEqual(
      first.split(separator: "-").map(\.count),
      [8, 4, 4, 4, 12]
    )
  }

  func testAlarmRequestRejectsPastTrigger() {
    let triggerAtEpochMs = Int64(Date().addingTimeInterval(-10).timeIntervalSince1970 * 1_000)
    XCTAssertThrowsError(
      try DangguiAlarmRecord(arguments: [
        "reminderId": "past-reminder",
        "triggerAtEpochMs": triggerAtEpochMs,
      ])
    )
  }

}
