import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  private var storeDirectory: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    storeDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("danggui-runner-tests-\(UUID().uuidString)", isDirectory: true)
    DangguiAlarmStore.setBaseDirectoryForTesting(storeDirectory)
  }

  override func tearDownWithError() throws {
    DangguiAlarmStore.setBaseDirectoryForTesting(nil)
    UserDefaults.standard.removeObject(forKey: "danggui.nativeAlarms.records.v1")
    UserDefaults.standard.removeObject(forKey: "danggui.nativeAlarms.events.v1")
    if let storeDirectory {
      try? FileManager.default.removeItem(at: storeDirectory)
    }
    try super.tearDownWithError()
  }

  func testAlarmRequestUsesSharedDartContractAndSnapshotAliases() throws {
    let triggerAtEpochMs = Int64(Date().addingTimeInterval(120).timeIntervalSince1970 * 1_000)
    let record = try makeRecord(
      reminderID: "reminder-1",
      revision: 7,
      triggerAtEpochMs: triggerAtEpochMs,
      vibrationEnabled: false,
      snoozeMinutes: 30
    )

    XCTAssertEqual(record.reminderID, "reminder-1")
    XCTAssertEqual(record.taskID, "task-1")
    XCTAssertEqual(record.scheduleRevision, 7)
    XCTAssertEqual(record.triggerAtEpochMs, triggerAtEpochMs)
    XCTAssertEqual(record.defaultSnoozeMinutes, 30)
    XCTAssertFalse(record.vibrationEnabled)
    XCTAssertNotNil(UUID(uuidString: record.platformAlarmID))
    XCTAssertEqual(record.snapshotMap["platformId"] as? String, record.platformAlarmID)
    XCTAssertEqual(record.snapshotMap["revision"] as? Int, 7)
    XCTAssertEqual(record.snapshotMap["state"] as? String, "pending")
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

  func testPlatformAlarmIdentifierIsStableValidAndRevisionSpecific() {
    let first = DangguiAlarmIdentifier.platformID(for: "stable-reminder", revision: 7)
    let second = DangguiAlarmIdentifier.platformID(for: "stable-reminder", revision: 7)
    let edited = DangguiAlarmIdentifier.platformID(for: "stable-reminder", revision: 8)

    XCTAssertEqual(first, second)
    XCTAssertNotEqual(first, edited)
    XCTAssertNotNil(UUID(uuidString: first))
    XCTAssertNotNil(UUID(uuidString: edited))
    XCTAssertEqual(first.split(separator: "-").map(\.count), [8, 4, 4, 4, 12])
  }

  func testTransactionOnlyAdvancesThroughDurableReplacementPhases() throws {
    let record = try makeRecord(reminderID: "tx-reminder", revision: 2)
    var transaction = DangguiAlarmTransaction(
      replacement: record,
      previousPlatformAlarmID: DangguiAlarmIdentifier.platformID(
        for: record.reminderID,
        revision: 1
      )
    )

    XCTAssertEqual(transaction.phase, .pending)
    XCTAssertThrowsError(try transaction.advance(to: .confirmed))
    try transaction.advance(to: .replacementScheduled)
    try transaction.advance(to: .confirmed)
    try transaction.advance(to: .retired)
    XCTAssertEqual(transaction.phase, .retired)
  }

  func testLateRecoveryWindowExpiresStrictlyAfterFifteenMinutes() {
    let now: Int64 = 2_000_000
    XCTAssertFalse(
      DangguiAlarmRecoveryPolicy.isExpired(
        triggerAtEpochMs: now - DangguiAlarmRecoveryPolicy.lateRecoveryWindowMs,
        nowEpochMs: now
      )
    )
    XCTAssertTrue(
      DangguiAlarmRecoveryPolicy.isExpired(
        triggerAtEpochMs: now - DangguiAlarmRecoveryPolicy.lateRecoveryWindowMs - 1,
        nowEpochMs: now
      )
    )
  }

  func testPastRequestCanBeDecodedForMissedEventInsteadOfBeingSilentlyLost() throws {
    let triggerAtEpochMs = Int64(Date().addingTimeInterval(-901).timeIntervalSince1970 * 1_000)
    let record = try makeRecord(
      reminderID: "past-reminder",
      revision: 1,
      triggerAtEpochMs: triggerAtEpochMs
    )
    XCTAssertTrue(
      DangguiAlarmRecoveryPolicy.isExpired(
        triggerAtEpochMs: record.triggerAtEpochMs,
        nowEpochMs: Int64(Date().timeIntervalSince1970 * 1_000)
      )
    )
  }

  func testCapacityFailureMapsToDeferredStateAndStableFlutterError() {
    XCTAssertEqual(DangguiAlarmFailureMapper.state(for: .capacity), "capacity-deferred")
    let mapped = DangguiAlarmFailureMapper.flutterError(
      for: DangguiAlarmOperationError.capacityDeferred,
      fallbackCode: "alarm_schedule_failed"
    )
    XCTAssertEqual(mapped.code, "capacity_deferred")
    XCTAssertEqual(
      (mapped.details as? [String: String])?["state"],
      "capacity-deferred"
    )
  }

  func testCorruptedMirrorEntryDoesNotDiscardValidRecords() throws {
    let valid = try makeRecord(reminderID: "surviving-reminder", revision: 4)
    let validObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(valid))
    let corruptedData = try JSONSerialization.data(
      withJSONObject: [
        validObject,
        ["reminderID": 42, "platformAlarmID": false],
        NSNull(),
      ]
    )
    try DangguiAlarmStore.replaceRecordsDataForTesting(corruptedData)

    let recovered = DangguiAlarmStore.records()
    XCTAssertEqual(recovered.count, 1)
    XCTAssertEqual(recovered.first?.reminderID, "surviving-reminder")
    XCTAssertEqual(recovered.first?.scheduleRevision, 4)
  }

  func testCorruptedTransactionEntryDoesNotDiscardRecoverableTransaction() throws {
    let record = try makeRecord(reminderID: "recoverable-transaction", revision: 5)
    let valid = DangguiAlarmTransaction(
      replacement: record,
      previousPlatformAlarmID: DangguiAlarmIdentifier.platformID(
        for: record.reminderID,
        revision: 4
      )
    )
    var validObject = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(valid)) as? [String: Any]
    )
    // v1 transactions did not carry these optional successor semantics.
    validObject.removeValue(forKey: "stopPreviousWhenConfirmed")
    validObject.removeValue(forKey: "completionEvent")
    let corruptedData = try JSONSerialization.data(
      withJSONObject: [
        ["phase": "confirmed", "replacement": "not-an-alarm"],
        validObject,
      ]
    )
    try DangguiAlarmStore.replaceTransactionsDataForTesting(corruptedData)

    let recovered = DangguiAlarmStore.transactions()
    XCTAssertEqual(recovered.count, 1)
    XCTAssertEqual(recovered.first?.reminderID, "recoverable-transaction")
    XCTAssertEqual(recovered.first?.phase, .pending)
    XCTAssertNil(recovered.first?.stopPreviousWhenConfirmed)
    XCTAssertNil(recovered.first?.completionEvent)
  }

  func testDiagnosticJournalIsBoundedToTwoHundredEvents() throws {
    let record = try makeRecord(reminderID: "event-reminder", revision: 1)
    for _ in 0..<205 {
      DangguiAlarmStore.appendEvent(DangguiAlarmEvent(type: .registered, record: record))
    }
    XCTAssertEqual(DangguiAlarmStore.events().count, 200)
  }

  func testPreviousRevisionCannotTargetStopOrSnooze() throws {
    let previous = try makeRecord(reminderID: "cas-reminder", revision: 7)
    let current = try makeRecord(reminderID: "cas-reminder", revision: 8)
    let transaction = DangguiAlarmTransaction(
      replacement: current,
      previousPlatformAlarmID: previous.platformAlarmID,
      previousRecord: previous
    )
    try DangguiAlarmStore.upsert(current)
    try DangguiAlarmStore.upsertTransaction(transaction)

    XCTAssertNil(DangguiAlarmStore.record(platformAlarmID: previous.platformAlarmID))
    XCTAssertFalse(
      DangguiAlarmMutationPolicy.isAuthoritativeAction(
        reminderID: previous.reminderID,
        expectedRevision: current.scheduleRevision,
        expectedPlatformAlarmID: previous.platformAlarmID,
        current: current
      ),
      "A delayed stop intent must not target the previous transaction record."
    )
    XCTAssertFalse(
      DangguiAlarmMutationPolicy.isAuthoritativeAction(
        reminderID: previous.reminderID,
        expectedRevision: previous.scheduleRevision,
        expectedPlatformAlarmID: previous.platformAlarmID,
        current: current
      ),
      "A delayed snooze intent must not create a successor from an old revision."
    )
    XCTAssertTrue(
      DangguiAlarmMutationPolicy.isAuthoritativeAction(
        reminderID: current.reminderID,
        expectedRevision: current.scheduleRevision,
        expectedPlatformAlarmID: current.platformAlarmID,
        current: current
      )
    )
    XCTAssertFalse(
      DangguiAlarmMutationPolicy.isAuthoritativeAction(
        reminderID: current.reminderID,
        expectedRevision: nil,
        expectedPlatformAlarmID: nil,
        current: current
      )
    )
  }

  func testSchedulePolicyRejectsLowerRevision() throws {
    let current = try makeRecord(reminderID: "revision-reminder", revision: 8)
    let requested = try makeRecord(reminderID: "revision-reminder", revision: 7)

    XCTAssertEqual(
      DangguiAlarmMutationPolicy.scheduleDecision(
        requested: requested,
        current: current,
        transactions: [],
        cancellation: nil
      ),
      .staleRevision
    )
  }

  func testSchedulePolicyRejectsSameRevisionWithDifferentFingerprint() throws {
    let current = try makeRecord(
      reminderID: "conflict-reminder",
      revision: 4,
      triggerAtEpochMs: 2_000_000
    )
    let conflicting = try makeRecord(
      reminderID: "conflict-reminder",
      revision: 4,
      triggerAtEpochMs: 2_000_001
    )

    XCTAssertNotEqual(current.configurationFingerprint, conflicting.configurationFingerprint)
    XCTAssertEqual(
      DangguiAlarmMutationPolicy.scheduleDecision(
        requested: conflicting,
        current: current,
        transactions: [],
        cancellation: nil
      ),
      .revisionConflict
    )
    XCTAssertEqual(
      DangguiAlarmMutationPolicy.scheduleDecision(
        requested: current,
        current: current,
        transactions: [],
        cancellation: nil
      ),
      .idempotent
    )
    var conflictingContent = current
    conflictingContent.title = "Different immutable title"
    XCTAssertEqual(
      DangguiAlarmMutationPolicy.scheduleDecision(
        requested: conflictingContent,
        current: current,
        transactions: [],
        cancellation: nil
      ),
      .revisionConflict
    )
  }

  func testCancellationRecoveryBlocksRepairAtEveryCrashPhase() throws {
    let current = try makeRecord(reminderID: "cancel-reminder", revision: 9)
    let replacement = try makeRecord(reminderID: "cancel-reminder", revision: 10)
    let transaction = DangguiAlarmTransaction(
      replacement: replacement,
      previousPlatformAlarmID: current.platformAlarmID,
      previousRecord: current
    )
    var cancellation = DangguiAlarmCancellationPolicy.makeTombstone(
      reminderID: current.reminderID,
      current: current,
      transactions: [transaction],
      existing: nil,
      nowEpochMs: 1_000
    )
    try DangguiAlarmStore.upsertCancellation(cancellation)
    let pendingCancellation = cancellation
    XCTAssertEqual(
      DangguiAlarmStore.cancellation(reminderID: current.reminderID),
      cancellation
    )

    XCTAssertEqual(cancellation.cancelledThroughRevision, 10)
    XCTAssertFalse(
      DangguiAlarmMutationPolicy.isAuthoritativeAction(
        reminderID: current.reminderID,
        expectedRevision: current.scheduleRevision,
        expectedPlatformAlarmID: current.platformAlarmID,
        current: current,
        cancellation: cancellation
      )
    )
    XCTAssertEqual(
      Set(cancellation.platformAlarmIDs),
      Set([current.platformAlarmID.lowercased(), replacement.platformAlarmID.lowercased()])
    )
    XCTAssertEqual(
      DangguiAlarmCancellationPolicy.activeTargetIDs(
        cancellation: cancellation,
        activeIDs: Set([
          current.platformAlarmID.lowercased(),
          replacement.platformAlarmID.lowercased(),
          "unrelated",
        ])
      ),
      [current.platformAlarmID.lowercased(), replacement.platformAlarmID.lowercased()].sorted()
    )

    for phase in [
      DangguiAlarmCancellationPhase.pending,
      .daemonCleared,
      .mirrorRemoved,
    ] {
      XCTAssertEqual(cancellation.phase, phase)
      XCTAssertFalse(
        DangguiAlarmCancellationPolicy.allowsRepair(
          record: current,
          cancellations: [cancellation]
        )
      )
      let next: DangguiAlarmCancellationPhase
      switch phase {
      case .pending:
        next = .daemonCleared
      case .daemonCleared:
        next = .mirrorRemoved
      case .mirrorRemoved, .completed:
        next = .completed
      }
      try cancellation.advance(to: next, nowEpochMs: cancellation.updatedAtEpochMs + 1)
      try DangguiAlarmStore.upsertCancellation(cancellation)
      XCTAssertEqual(
        DangguiAlarmStore.cancellation(reminderID: current.reminderID)?.phase,
        next
      )
    }

    XCTAssertEqual(cancellation.phase, .completed)
    XCTAssertFalse(
      DangguiAlarmCancellationPolicy.allowsRepair(
        record: current,
        cancellations: [cancellation]
      ),
      "The completed high-water mark must still block an old mirror from resurrection."
    )
    XCTAssertTrue(
      DangguiAlarmCancellationPolicy.isSupersededByCompletedCancellation(
        record: current,
        cancellations: [cancellation]
      )
    )
    let future = try makeRecord(reminderID: current.reminderID, revision: 11)
    XCTAssertEqual(
      DangguiAlarmMutationPolicy.scheduleDecision(
        requested: future,
        current: current,
        transactions: [transaction],
        cancellation: pendingCancellation
      ),
      .staleRevision
    )
    XCTAssertTrue(
      DangguiAlarmCancellationPolicy.allowsRepair(
        record: future,
        cancellations: [cancellation]
      )
    )
    XCTAssertEqual(
      DangguiAlarmMutationPolicy.scheduleDecision(
        requested: future,
        current: nil,
        transactions: [],
        cancellation: cancellation
      ),
      .install
    )
    XCTAssertEqual(
      DangguiAlarmMutationPolicy.scheduleDecision(
        requested: replacement,
        current: nil,
        transactions: [],
        cancellation: cancellation
      ),
      .staleRevision
    )
  }

  func testSnoozePlanUsesOneClockSampleAndDefersPredecessorStop() throws {
    let record = try makeRecord(reminderID: "snooze-reminder", revision: 3)
    let occurredAtEpochMs: Int64 = 10_000_000
    let plan = DangguiAlarmSnoozePolicy.makePlan(
      record: record,
      minutes: 30,
      occurredAtEpochMs: occurredAtEpochMs
    )
    let transaction = DangguiAlarmTransaction(
      replacement: plan.replacement,
      previousPlatformAlarmID: record.platformAlarmID,
      previousRecord: record,
      stopPreviousWhenConfirmed: true,
      completionEvent: plan.completionEvent
    )

    XCTAssertEqual(transaction.phase, .pending)
    XCTAssertEqual(transaction.stopPreviousWhenConfirmed, true)
    XCTAssertFalse(
      DangguiAlarmSnoozePolicy.shouldStopPredecessor(transaction: transaction)
    )
    XCTAssertEqual(plan.replacement.scheduleRevision, 4)
    XCTAssertEqual(plan.replacement.triggerAtEpochMs, occurredAtEpochMs + 30 * 60 * 1_000)
    XCTAssertEqual(plan.completionEvent.occurredAtEpochMs, occurredAtEpochMs)
    XCTAssertEqual(
      plan.completionEvent.flutterMap["successorTriggerAtEpochMs"] as? Int64,
      plan.replacement.triggerAtEpochMs
    )
    XCTAssertEqual(
      plan.completionEvent.successorTriggerAtEpochMs,
      plan.replacement.triggerAtEpochMs
    )
    XCTAssertEqual(transaction.completionEvent, plan.completionEvent)
    var confirmed = transaction
    try confirmed.advance(to: .replacementScheduled)
    try confirmed.advance(to: .confirmed)
    XCTAssertTrue(
      DangguiAlarmSnoozePolicy.shouldStopPredecessor(transaction: confirmed)
    )
  }

  func testLegacyMigrationKeepsSourceWhenAtomicWriteFails() throws {
    let legacyKey = "danggui.nativeAlarms.records.v1"
    let record = try makeRecord(reminderID: "legacy-write-failure", revision: 2)
    UserDefaults.standard.set(try JSONEncoder().encode([record]), forKey: legacyKey)
    try FileManager.default.createDirectory(
      at: storeDirectory,
      withIntermediateDirectories: true
    )
    let blockingFile = storeDirectory.appendingPathComponent("not-a-directory")
    try Data([0]).write(to: blockingFile)
    DangguiAlarmStore.setBaseDirectoryForTesting(blockingFile)

    let migrated = DangguiAlarmStore.records()

    XCTAssertEqual(migrated, [record])
    XCTAssertNotNil(UserDefaults.standard.data(forKey: legacyKey))
    DangguiAlarmStore.setBaseDirectoryForTesting(storeDirectory)
  }

  func testCorruptPrimaryFallsBackToLastKnownGoodMirror() throws {
    let first = try makeRecord(reminderID: "backup-first", revision: 1)
    let second = try makeRecord(reminderID: "backup-second", revision: 1)
    try DangguiAlarmStore.upsert(first)
    try DangguiAlarmStore.upsert(second)
    try DangguiAlarmStore.replaceRecordsDataForTesting(Data("not-json".utf8))

    XCTAssertEqual(DangguiAlarmStore.records(), [first])
  }

  private func makeRecord(
    reminderID: String,
    revision: Int,
    triggerAtEpochMs: Int64? = nil,
    vibrationEnabled: Bool = true,
    snoozeMinutes: Int = 10
  ) throws -> DangguiAlarmRecord {
    try DangguiAlarmRecord(arguments: [
      "reminderId": reminderID,
      "taskId": "task-1",
      "scheduleRevision": revision,
      "triggerAtEpochMs": triggerAtEpochMs
        ?? Int64(Date().addingTimeInterval(120).timeIntervalSince1970 * 1_000),
      "title": "复习",
      "body": "开始复习",
      "vibrationEnabled": vibrationEnabled,
      "defaultSnoozeMinutes": snoozeMinutes,
      "localeTag": "zh-Hans",
    ])
  }
}
