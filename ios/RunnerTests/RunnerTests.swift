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

  func testAlarmRequestRejectsMissingOrNonPositiveRevision() throws {
    let triggerAtEpochMs = Int64(Date().addingTimeInterval(120).timeIntervalSince1970 * 1_000)
    XCTAssertThrowsError(
      try DangguiAlarmRecord(arguments: [
        "reminderId": "missing-revision",
        "triggerAtEpochMs": triggerAtEpochMs,
      ])
    )
    XCTAssertThrowsError(
      try DangguiAlarmRecord(arguments: [
        "reminderId": "zero-revision",
        "scheduleRevision": 0,
        "triggerAtEpochMs": triggerAtEpochMs,
      ])
    )
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

  func testPlatformAlarmIdentifierMatchesCrossPlatformGenerationVector() throws {
    let generation = "99999999-9999-4999-8999-999999999999"
    let generated = DangguiAlarmIdentifier.platformID(
      for: "r1",
      revision: 7,
      deviceGeneration: generation
    )
    XCTAssertEqual(generated, "7583af8c-382e-5b5d-ae26-48dd1489d676")
    XCTAssertNotEqual(
      generated,
      DangguiAlarmIdentifier.platformID(for: "r1", revision: 7)
    )

    let record = try makeRecord(
      reminderID: "r1",
      revision: 7,
      deviceGeneration: generation
    )
    XCTAssertEqual(record.platformAlarmID, generated)
    XCTAssertEqual(record.deviceGeneration, generation)
    XCTAssertEqual(record.snapshotMap["deviceGeneration"] as? String, generation)
  }

  func testAlarmRequestRejectsMalformedDeviceGeneration() {
    let invalidGenerations: [Any] = ["not-a-uuid", "", 42]
    for invalidGeneration in invalidGenerations {
      XCTAssertThrowsError(
        try DangguiAlarmRecord(arguments: [
          "reminderId": "bad-generation",
          "scheduleRevision": 1,
          "deviceGeneration": invalidGeneration,
          "triggerAtEpochMs": Int64(1_000),
        ])
      )
    }
    XCTAssertThrowsError(
      try DangguiAlarmRecord(arguments: [
        "reminderId": "conflicting-generation-aliases",
        "scheduleRevision": 1,
        "deviceGeneration": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
        "generation": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
        "triggerAtEpochMs": Int64(1_000),
      ])
    )
  }

  func testDeviceGenerationMethodChannelParserIsStrictAndLegacyCompatible() {
    XCTAssertNil(
      try ReminderPlatformBridge.optionalDeviceGeneration(nil)
    )
    XCTAssertNil(
      try ReminderPlatformBridge.optionalDeviceGeneration([
        "deviceGeneration": NSNull(),
      ])
    )
    XCTAssertEqual(
      try ReminderPlatformBridge.optionalDeviceGeneration([
        "deviceGeneration": "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA",
      ]),
      "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
    )
    XCTAssertEqual(
      try ReminderPlatformBridge.optionalDeviceGeneration([
        "generation": "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA",
      ]),
      "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
    )
    XCTAssertThrowsError(
      try ReminderPlatformBridge.optionalDeviceGeneration([
        "deviceGeneration": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
        "generation": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      ])
    )
    XCTAssertThrowsError(
      try ReminderPlatformBridge.optionalDeviceGeneration([
        "deviceGeneration": NSNull(),
        "generation": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      ])
    )
    let invalidValues: [Any] = ["", "not-a-uuid", 42]
    for invalid in invalidValues {
      XCTAssertThrowsError(
        try ReminderPlatformBridge.optionalDeviceGeneration([
          "deviceGeneration": invalid,
        ])
      )
    }
  }

  func testPersistedDeviceGenerationRequiresCanonicalLowercaseUUID() {
    let uppercase = "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA"
    let lowercase = uppercase.lowercased()
    XCTAssertFalse(DangguiAlarmGeneration.isValid(uppercase))
    XCTAssertTrue(DangguiAlarmGeneration.isValid(lowercase))
    XCTAssertEqual(DangguiAlarmGeneration.normalized(uppercase), lowercase)
  }

  func testGenerationActivationPersistsBeforeInactiveRouteCleanup() throws {
    let generationA = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
    let generationB = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
    let legacy = try makeRecord(
      reminderID: "generation-activation",
      revision: 7
    )
    let restoredA = try makeRecord(
      reminderID: legacy.reminderID,
      revision: legacy.scheduleRevision,
      deviceGeneration: generationA
    )
    let handoffA = DangguiAlarmTransaction(
      replacement: restoredA,
      previousPlatformAlarmID: legacy.platformAlarmID,
      previousRecord: legacy
    )
    try DangguiAlarmStore.upsert(legacy)
    try DangguiAlarmStore.upsertTransaction(handoffA)

    XCTAssertNil(try DangguiAlarmStore.activeDeviceGeneration())
    try DangguiAlarmStore.activateDeviceGeneration(generationA)
    XCTAssertEqual(
      try DangguiAlarmStore.activeDeviceGeneration(),
      generationA
    )
    let legacyToAInactiveIDs = try DangguiAlarmStore
      .inactiveRoutePlatformAlarmIDs()
    XCTAssertTrue(legacyToAInactiveIDs.contains(legacy.platformAlarmID))
    XCTAssertFalse(legacyToAInactiveIDs.contains(restoredA.platformAlarmID))

    let restoredB = try makeRecord(
      reminderID: legacy.reminderID,
      revision: legacy.scheduleRevision,
      deviceGeneration: generationB
    )
    try DangguiAlarmStore.upsertTransaction(
      DangguiAlarmTransaction(
        replacement: restoredB,
        previousPlatformAlarmID: restoredA.platformAlarmID,
        previousRecord: restoredA
      )
    )
    try DangguiAlarmStore.activateDeviceGeneration(generationB)

    // Re-pointing the test seam models process death after the activation file
    // is committed but before every stale AlarmKit route is cancelled.
    DangguiAlarmStore.setBaseDirectoryForTesting(nil)
    DangguiAlarmStore.setBaseDirectoryForTesting(storeDirectory)
    XCTAssertEqual(
      try DangguiAlarmStore.activeDeviceGeneration(),
      generationB
    )
    let aToBInactiveIDs = try DangguiAlarmStore.inactiveRoutePlatformAlarmIDs()
    XCTAssertTrue(aToBInactiveIDs.contains(legacy.platformAlarmID))
    XCTAssertTrue(aToBInactiveIDs.contains(restoredA.platformAlarmID))
    XCTAssertFalse(aToBInactiveIDs.contains(restoredB.platformAlarmID))
    XCTAssertTrue(DangguiAlarmStore.cancellations().isEmpty)
    XCTAssertTrue(DangguiAlarmStore.events().isEmpty)
  }

  func testInactiveGenerationCleanupNeverCancelsRouteProvenCurrent() throws {
    let generation = "abababab-abab-4bab-8bab-abababababab"
    let legacy = try makeRecord(
      reminderID: "mixed-cancellation-generation",
      revision: 3
    )
    let current = try makeRecord(
      reminderID: legacy.reminderID,
      revision: legacy.scheduleRevision,
      deviceGeneration: generation
    )
    let historicalCancellation = DangguiAlarmCancellation(
      reminderID: legacy.reminderID,
      deviceGeneration: nil,
      cancelledThroughRevision: legacy.scheduleRevision,
      platformAlarmIDs: Set([
        legacy.platformAlarmID,
        current.platformAlarmID,
      ]),
      nowEpochMs: 20_000
    )
    let handoff = DangguiAlarmTransaction(
      replacement: current,
      previousPlatformAlarmID: legacy.platformAlarmID,
      previousRecord: legacy
    )

    let inactiveIDs = DangguiAlarmGenerationActivationPolicy
      .inactivePlatformAlarmIDs(
        records: [legacy],
        transactions: [handoff],
        cancellations: [historicalCancellation],
        activeDeviceGeneration: generation
      )
    XCTAssertTrue(inactiveIDs.contains(legacy.platformAlarmID))
    XCTAssertFalse(inactiveIDs.contains(current.platformAlarmID))
  }

  func testSystemSnapshotDifferenceRetiresOnlyUnownedAlarmKitIDs() throws {
    let current = try makeRecord(reminderID: "snapshot-current", revision: 2)
    let replacement = try makeRecord(
      reminderID: current.reminderID,
      revision: 3
    )
    let transaction = DangguiAlarmTransaction(
      replacement: replacement,
      previousPlatformAlarmID: current.platformAlarmID,
      previousRecord: current
    )
    let cancelled = try makeRecord(reminderID: "snapshot-cancelled", revision: 4)
    let cancellation = DangguiAlarmCancellationPolicy.makeTombstone(
      reminderID: cancelled.reminderID,
      current: cancelled,
      transactions: [],
      existing: nil,
      nowEpochMs: 4_000
    )
    let orphan = UUID().uuidString.lowercased()

    let orphans = DangguiAlarmSystemSnapshotPolicy.orphanPlatformAlarmIDs(
      remotePlatformAlarmIDs: Set([
        current.platformAlarmID,
        replacement.platformAlarmID,
        cancelled.platformAlarmID,
        orphan,
      ]),
      records: [current],
      transactions: [transaction],
      cancellations: [cancellation]
    )

    XCTAssertEqual(orphans, [orphan])
  }

  func testOnlyActiveGenerationEventsAreDrainedOrAcknowledged() throws {
    let generation = "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
    let legacy = try makeRecord(reminderID: "legacy-event", revision: 1)
    let restored = try makeRecord(
      reminderID: "restored-event",
      revision: 1,
      deviceGeneration: generation
    )
    let legacyEvent = DangguiAlarmEvent(
      type: .delivered,
      record: legacy,
      usesStableID: true
    )
    let restoredEvent = DangguiAlarmEvent(
      type: .delivered,
      record: restored,
      usesStableID: true
    )
    try DangguiAlarmStore.appendEventDurably(legacyEvent)
    try DangguiAlarmStore.appendEventDurably(restoredEvent)

    XCTAssertEqual(DangguiAlarmStore.activeEvents(), [legacyEvent])
    try DangguiAlarmStore.activateDeviceGeneration(generation)
    XCTAssertEqual(DangguiAlarmStore.activeEvents(), [restoredEvent])
    DangguiAlarmStore.acknowledgeActiveEvents(
      Set([legacyEvent.eventID, restoredEvent.eventID])
    )
    XCTAssertEqual(DangguiAlarmStore.events(), [legacyEvent])
    try DangguiAlarmStore.activateDeviceGeneration(nil)
    XCTAssertEqual(DangguiAlarmStore.activeEvents(), [legacyEvent])
  }

  func testDelayedCancelFromOldGenerationCannotRemoveCurrentSameID() throws {
    let oldGeneration = "12121212-1212-4212-8212-121212121212"
    let currentGeneration = "34343434-3434-4434-8434-343434343434"
    let current = try makeRecord(
      reminderID: "same-id-after-restore",
      revision: 5,
      deviceGeneration: currentGeneration
    )
    try DangguiAlarmStore.upsert(current)
    try DangguiAlarmStore.activateDeviceGeneration(currentGeneration)

    XCTAssertFalse(
      try DangguiAlarmStore.activeGenerationMatches(oldGeneration)
    )
    XCTAssertTrue(
      try DangguiAlarmStore.activeGenerationMatches(currentGeneration)
    )
    XCTAssertNil(
      try DangguiAlarmStore.remove(
        reminderID: current.reminderID,
        deviceGeneration: oldGeneration
      )
    )
    try DangguiAlarmStore.removeTransactions(
      reminderID: current.reminderID,
      deviceGeneration: oldGeneration
    )
    XCTAssertEqual(
      DangguiAlarmStore.record(reminderID: current.reminderID),
      current
    )
    XCTAssertTrue(DangguiAlarmStore.cancellations().isEmpty)
    XCTAssertTrue(DangguiAlarmStore.events().isEmpty)
  }

  func testCorruptActiveGenerationImageFailsClosedWithoutUsingBackup() throws {
    let generationA = "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
    let generationB = "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"
    try DangguiAlarmStore.activateDeviceGeneration(generationA)
    try DangguiAlarmStore.activateDeviceGeneration(generationB)
    let corruptPrimary = Data(
      "[{\"deviceGeneration\":\"not-a-uuid\",\"updatedAtEpochMs\":1}]".utf8
    )
    try DangguiAlarmStore.replaceActiveGenerationDataForTesting(corruptPrimary)

    XCTAssertThrowsError(try DangguiAlarmStore.activeDeviceGeneration())
    XCTAssertThrowsError(try DangguiAlarmStore.assertAuthoritativeStoresHealthy())
    XCTAssertThrowsError(
      try DangguiAlarmStore.activateDeviceGeneration(generationA)
    )
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

  func testAuthoritativeCorruptionMapsToStableFlutterError() {
    let mapped = DangguiAlarmFailureMapper.flutterError(
      for: DangguiAlarmBridgeError.authoritativeStoreCorrupt,
      fallbackCode: "alarm_event_drain_failed"
    )
    XCTAssertEqual(mapped.code, "authoritative_store_corrupt")
    XCTAssertEqual(
      (mapped.details as? [String: String])?["state"],
      "repair-pending"
    )
  }

  func testPartiallyCorruptAuthoritativeMirrorWithoutLKGFailsClosed() throws {
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

    XCTAssertTrue(DangguiAlarmStore.records().isEmpty)
    XCTAssertThrowsError(try DangguiAlarmStore.assertAuthoritativeStoresHealthy())
    XCTAssertThrowsError(
      try DangguiAlarmStore.upsert(
        makeRecord(reminderID: "must-not-overwrite", revision: 5)
      )
    )
    XCTAssertEqual(
      try Data(contentsOf: storeDirectory.appendingPathComponent("native-alarms-v2.json")),
      corruptedData
    )
  }

  func testPartiallyCorruptTransactionWithoutLKGFailsClosed() throws {
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
    validObject.removeValue(forKey: "ownsMissingRecovery")
    let legacyDecoded = try JSONDecoder().decode(
      DangguiAlarmTransaction.self,
      from: JSONSerialization.data(withJSONObject: validObject)
    )
    XCTAssertNil(legacyDecoded.stopPreviousWhenConfirmed)
    XCTAssertNil(legacyDecoded.completionEvent)
    XCTAssertNil(legacyDecoded.ownsMissingRecovery)
    let corruptedData = try JSONSerialization.data(
      withJSONObject: [
        ["phase": "confirmed", "replacement": "not-an-alarm"],
        validObject,
      ]
    )
    try DangguiAlarmStore.replaceTransactionsDataForTesting(corruptedData)

    XCTAssertTrue(DangguiAlarmStore.transactions().isEmpty)
    XCTAssertThrowsError(try DangguiAlarmStore.assertAuthoritativeStoresHealthy())
    XCTAssertThrowsError(try DangguiAlarmStore.upsertTransaction(valid))
    XCTAssertEqual(
      try Data(contentsOf: storeDirectory.appendingPathComponent("alarm-transactions-v1.json")),
      corruptedData
    )
  }

  func testPartiallyCorruptCancellationWithoutLKGFailsClosed() throws {
    let record = try makeRecord(reminderID: "cancel-corrupt", revision: 2)
    let valid = DangguiAlarmCancellationPolicy.makeTombstone(
      reminderID: record.reminderID,
      current: record,
      transactions: [],
      existing: nil,
      nowEpochMs: 1_000
    )
    let validObject = try JSONSerialization.jsonObject(
      with: JSONEncoder().encode(valid)
    )
    let corruptedData = try JSONSerialization.data(
      withJSONObject: [validObject, ["phase": "not-a-phase"]]
    )
    try DangguiAlarmStore.replaceCancellationsDataForTesting(corruptedData)

    XCTAssertTrue(DangguiAlarmStore.cancellations().isEmpty)
    XCTAssertThrowsError(try DangguiAlarmStore.assertAuthoritativeStoresHealthy())
    XCTAssertThrowsError(try DangguiAlarmStore.upsertCancellation(valid))
    XCTAssertEqual(
      try Data(contentsOf: storeDirectory.appendingPathComponent("alarm-cancellations-v1.json")),
      corruptedData
    )
  }

  func testDiagnosticJournalIsBoundedToTwoHundredEvents() throws {
    let record = try makeRecord(reminderID: "event-reminder", revision: 1)
    for _ in 0..<205 {
      DangguiAlarmStore.appendEvent(DangguiAlarmEvent(type: .registered, record: record))
    }
    XCTAssertEqual(DangguiAlarmStore.events().count, 200)
  }

  func testDiagnosticPressureNeverEvictsUnacknowledgedBusinessEvent() throws {
    let terminalRecord = try makeRecord(reminderID: "terminal-event", revision: 4)
    let stopped = DangguiAlarmEvent(
      type: .stopped,
      record: terminalRecord,
      usesStableID: true
    )
    try DangguiAlarmStore.appendEventDurably(stopped)
    for index in 0..<205 {
      let diagnosticRecord = try makeRecord(
        reminderID: "diagnostic-\(index)",
        revision: 1
      )
      try DangguiAlarmStore.appendEventDurably(
        DangguiAlarmEvent(type: .error, record: diagnosticRecord)
      )
    }

    let events = DangguiAlarmStore.events()
    XCTAssertEqual(events.filter(\.mutatesBusinessState), [stopped])
    XCTAssertEqual(events.filter { !$0.mutatesBusinessState }.count, 200)
    XCTAssertEqual(events.count, 201)
  }

  func testV114MixedEventsMigrateStrictlyIntoSeparatedStores() throws {
    let record = try makeRecord(reminderID: "legacy-mixed-event", revision: 3)
    var stopped = DangguiAlarmEvent(type: .stopped, record: record)
    // v1.1.4 used random UUID event IDs for business actions.
    stopped.eventID = UUID().uuidString
    let diagnostic = DangguiAlarmEvent(type: .registered, record: record)
    try DangguiAlarmStore.replaceLegacyMixedEventsDataForTesting(
      JSONEncoder().encode([stopped, diagnostic])
    )

    let migrated = DangguiAlarmStore.events()

    XCTAssertEqual(migrated.filter(\.mutatesBusinessState), [stopped])
    XCTAssertEqual(migrated.filter { !$0.mutatesBusinessState }, [diagnostic])
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: storeDirectory
          .appendingPathComponent("alarm-business-events-v1.json").path
      )
    )
    XCTAssertNoThrow(try DangguiAlarmStore.assertAuthoritativeStoresHealthy())
  }

  func testPartiallyCorruptV114MixedJournalFailsClosedWithoutMigration() throws {
    let record = try makeRecord(reminderID: "legacy-corrupt-event", revision: 2)
    var stopped = DangguiAlarmEvent(type: .stopped, record: record)
    stopped.eventID = UUID().uuidString
    let stoppedObject = try JSONSerialization.jsonObject(
      with: JSONEncoder().encode(stopped)
    )
    let diagnostic = DangguiAlarmEvent(type: .registered, record: record)
    let diagnosticObject = try JSONSerialization.jsonObject(
      with: JSONEncoder().encode(diagnostic)
    )
    let corruptMixedData = try JSONSerialization.data(
      withJSONObject: [
        stoppedObject,
        ["type": "snoozed", "eventID": UUID().uuidString],
        diagnosticObject,
      ]
    )
    try DangguiAlarmStore.replaceLegacyMixedEventsDataForTesting(
      corruptMixedData
    )

    XCTAssertTrue(DangguiAlarmStore.events().isEmpty)
    XCTAssertThrowsError(try DangguiAlarmStore.assertAuthoritativeStoresHealthy())
    XCTAssertThrowsError(
      try DangguiAlarmStore.appendEventDurably(
        DangguiAlarmEvent(type: .missed, record: record, usesStableID: true)
      )
    )
    XCTAssertEqual(
      try Data(
        contentsOf: storeDirectory.appendingPathComponent("alarm-events-v2.json")
      ),
      corruptMixedData
    )
    XCTAssertFalse(
      FileManager.default.fileExists(
        atPath: storeDirectory
          .appendingPathComponent("alarm-business-events-v1.json").path
      )
    )
  }

  func testCorruptBusinessPrimaryKeepsTerminalLKGAndSeparateDiagnostics() throws {
    let terminalRecord = try makeRecord(reminderID: "event-lkg", revision: 4)
    let stopped = DangguiAlarmEvent(
      type: .stopped,
      record: terminalRecord,
      usesStableID: true
    )
    let delivered = DangguiAlarmEvent(
      type: .delivered,
      record: terminalRecord,
      usesStableID: true
    )
    let diagnostic = DangguiAlarmEvent(
      type: .registered,
      record: terminalRecord,
      usesStableID: true
    )
    try DangguiAlarmStore.appendEventDurably(stopped)
    try DangguiAlarmStore.appendEventDurably(delivered)
    try DangguiAlarmStore.appendEventDurably(diagnostic)

    let stoppedObject = try JSONSerialization.jsonObject(
      with: JSONEncoder().encode(stopped)
    )
    let corruptBusinessData = try JSONSerialization.data(
      withJSONObject: [
        stoppedObject,
        ["type": "snoozed", "eventID": UUID().uuidString],
      ]
    )
    try DangguiAlarmStore.replaceBusinessEventsDataForTesting(
      corruptBusinessData
    )

    let readable = DangguiAlarmStore.events()
    XCTAssertEqual(readable.filter(\.mutatesBusinessState), [stopped])
    XCTAssertEqual(readable.filter { !$0.mutatesBusinessState }, [diagnostic])
    XCTAssertThrowsError(try DangguiAlarmStore.assertAuthoritativeStoresHealthy())
    XCTAssertThrowsError(try DangguiAlarmStore.activeEventsDurably())
    XCTAssertThrowsError(
      try DangguiAlarmStore.acknowledgeActiveEventsDurably([stopped.eventID])
    )
    XCTAssertThrowsError(
      try DangguiAlarmStore.appendEventDurably(
        DangguiAlarmEvent(type: .missed, record: terminalRecord, usesStableID: true)
      )
    )
    XCTAssertEqual(
      try Data(
        contentsOf: storeDirectory
          .appendingPathComponent("alarm-business-events-v1.json")
      ),
      corruptBusinessData
    )
  }

  func testDeliveredWriteFailureLeavesFiredMarkerRetryable() throws {
    var record = try makeRecord(reminderID: "delivery-retry", revision: 2)
    try DangguiAlarmStore.upsert(record)
    let healthyDirectory = storeDirectory!
    let blockingFile = healthyDirectory.appendingPathComponent("not-a-directory")
    try Data([0]).write(to: blockingFile)
    DangguiAlarmStore.setBaseDirectoryForTesting(blockingFile)

    XCTAssertThrowsError(
      try DangguiAlarmDeliveryRecorder.recordDeliveredIfNeeded(&record)
    )
    XCTAssertFalse(record.firedEventRecorded)

    DangguiAlarmStore.setBaseDirectoryForTesting(healthyDirectory)
    XCTAssertFalse(
      try XCTUnwrap(DangguiAlarmStore.record(reminderID: record.reminderID))
        .firedEventRecorded
    )
    XCTAssertTrue(DangguiAlarmStore.events().isEmpty)
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

  func testRestoredGenerationMayReplaceSameRevisionAndIgnoresOldHighWater() throws {
    let oldGeneration = "11111111-1111-4111-8111-111111111111"
    let restoredGeneration = "22222222-2222-4222-8222-222222222222"
    let old = try makeRecord(
      reminderID: "restored-same-revision",
      revision: 8,
      deviceGeneration: oldGeneration,
      triggerAtEpochMs: 2_000_000
    )
    let restored = try makeRecord(
      reminderID: old.reminderID,
      revision: 8,
      deviceGeneration: restoredGeneration,
      triggerAtEpochMs: 3_000_000
    )
    var oldCancellation = DangguiAlarmCancellationPolicy.makeTombstone(
      reminderID: old.reminderID,
      current: old,
      transactions: [],
      existing: nil,
      nowEpochMs: 10_000
    )
    try oldCancellation.advance(to: .daemonCleared, nowEpochMs: 10_001)
    try oldCancellation.advance(to: .mirrorRemoved, nowEpochMs: 10_002)
    try oldCancellation.advance(to: .completed, nowEpochMs: 10_003)

    XCTAssertEqual(
      DangguiAlarmMutationPolicy.scheduleDecision(
        requested: restored,
        current: old,
        transactions: [],
        cancellation: oldCancellation
      ),
      .install
    )
    XCTAssertTrue(
      DangguiAlarmCancellationPolicy.allowsRepair(
        record: restored,
        cancellations: [oldCancellation]
      )
    )
    XCTAssertFalse(
      DangguiAlarmCancellationPolicy.isSupersededByCompletedCancellation(
        record: restored,
        cancellations: [oldCancellation]
      )
    )
    XCTAssertNotEqual(old.platformAlarmID, restored.platformAlarmID)

    let handoff = DangguiAlarmTransaction(
      replacement: restored,
      previousPlatformAlarmID: old.platformAlarmID,
      previousRecord: old
    )
    try DangguiAlarmStore.upsert(old)
    try DangguiAlarmStore.upsertTransaction(handoff)
    try DangguiAlarmStore.activateDeviceGeneration(restoredGeneration)
    XCTAssertNil(
      DangguiAlarmStore.authoritativeActionRecord(
        reminderID: old.reminderID,
        scheduleRevision: old.scheduleRevision,
        platformAlarmID: old.platformAlarmID
      ),
      "An old-generation action must stop being authoritative once restore handoff exists."
    )
    XCTAssertEqual(
      DangguiAlarmStore.authoritativeActionRecord(
        reminderID: restored.reminderID,
        scheduleRevision: restored.scheduleRevision,
        platformAlarmID: restored.platformAlarmID
      ),
      restored
    )
  }

  func testCrossGenerationTransactionAndCancellationValidatorsStayScoped() throws {
    let old = try makeRecord(
      reminderID: "generation-validator",
      revision: 4,
      deviceGeneration: "33333333-3333-4333-8333-333333333333"
    )
    let restored = try makeRecord(
      reminderID: old.reminderID,
      revision: 4,
      deviceGeneration: "44444444-4444-4444-8444-444444444444"
    )
    let handoff = DangguiAlarmTransaction(
      replacement: restored,
      previousPlatformAlarmID: old.platformAlarmID,
      previousRecord: old
    )
    XCTAssertNoThrow(try DangguiAlarmStore.upsertTransaction(handoff))

    var invalidTransaction = handoff
    invalidTransaction.transactionID = UUID().uuidString
    invalidTransaction.replacement.platformAlarmID = old.platformAlarmID
    XCTAssertThrowsError(try DangguiAlarmStore.upsertTransaction(invalidTransaction))
    var unboundPredecessor = handoff
    unboundPredecessor.transactionID = UUID().uuidString
    unboundPredecessor.previousRecord = nil
    unboundPredecessor.previousPlatformAlarmID = UUID().uuidString
    XCTAssertThrowsError(try DangguiAlarmStore.upsertTransaction(unboundPredecessor))
    try DangguiAlarmStore.upsert(restored)
    try DangguiAlarmStore.removeRecordsAndTransactions(
      reminderID: old.reminderID,
      platformAlarmIDs: Set([old.platformAlarmID])
    )
    XCTAssertEqual(DangguiAlarmStore.record(reminderID: old.reminderID), restored)
    XCTAssertEqual(DangguiAlarmStore.transactions(), [handoff])

    let oldCancellation = DangguiAlarmCancellationPolicy.makeTombstone(
      reminderID: old.reminderID,
      current: old,
      transactions: [],
      existing: nil,
      nowEpochMs: 19_000
    )
    let restoredCancellation = DangguiAlarmCancellationPolicy.makeTombstone(
      reminderID: restored.reminderID,
      current: restored,
      transactions: [],
      existing: oldCancellation,
      nowEpochMs: 19_001
    )
    try DangguiAlarmStore.upsertCancellation(oldCancellation)
    try DangguiAlarmStore.upsertCancellation(restoredCancellation)
    XCTAssertEqual(DangguiAlarmStore.cancellations().count, 2)
    XCTAssertEqual(
      DangguiAlarmStore.cancellation(
        reminderID: old.reminderID,
        deviceGeneration: old.deviceGeneration
      ),
      oldCancellation
    )
    XCTAssertEqual(
      DangguiAlarmStore.cancellation(
        reminderID: restored.reminderID,
        deviceGeneration: restored.deviceGeneration
      ),
      restoredCancellation
    )

    var invalidCancellation = DangguiAlarmCancellationPolicy.makeStopTombstone(
      record: old,
      transactions: [],
      existing: nil,
      nowEpochMs: 20_000
    )
    invalidCancellation.deviceGeneration = restored.deviceGeneration
    XCTAssertThrowsError(try DangguiAlarmStore.upsertCancellation(invalidCancellation))
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

  func testRouteRetirementAllowsOnlySameRevisionDeliveryRouteReinstall() throws {
    let record = try makeRecord(reminderID: "route-transition", revision: 8)
    var routeRetirement = DangguiAlarmCancellationPolicy
      .makeRouteRetirementTombstone(
        record: record,
        currentMirror: record,
        transactions: [],
        existing: nil,
        nowEpochMs: 8_000
      )
    XCTAssertEqual(
      routeRetirement.terminalState,
      DangguiAlarmCancellationPolicy.routeRetiredTerminalState
    )
    XCTAssertNil(routeRetirement.completionEvent)
    XCTAssertEqual(routeRetirement.daemonAction, .cancel)

    XCTAssertEqual(
      DangguiAlarmMutationPolicy.scheduleDecision(
        requested: record,
        current: record,
        transactions: [],
        cancellation: routeRetirement
      ),
      .staleRevision,
      "A pending route cleanup must still own crash recovery."
    )
    try routeRetirement.advance(to: .daemonCleared, nowEpochMs: 8_001)
    try routeRetirement.advance(to: .mirrorRemoved, nowEpochMs: 8_002)
    try routeRetirement.advance(to: .completed, nowEpochMs: 8_003)

    XCTAssertEqual(
      DangguiAlarmMutationPolicy.scheduleDecision(
        requested: record,
        current: nil,
        transactions: [],
        cancellation: routeRetirement
      ),
      .install,
      "Restored AlarmKit authorization may reinstall the unchanged revision."
    )
    let routeOwner = DangguiAlarmTransaction(
      replacement: record,
      previousPlatformAlarmID: nil
    )
    XCTAssertTrue(
      DangguiAlarmCancellationPolicy.transactionOwnsSameRevisionRouteReinstall(
        transaction: routeOwner,
        cancellation: routeRetirement
      ),
      "The pending transaction must release the route marker before touching AlarmKit."
    )
    XCTAssertTrue(
      DangguiAlarmCancellationPolicy.allowsRepair(
        record: record,
        cancellations: [routeRetirement]
      )
    )
    XCTAssertFalse(
      DangguiAlarmCancellationPolicy.isSupersededByCompletedCancellation(
        record: record,
        cancellations: [routeRetirement]
      )
    )

    var businessCancellation = DangguiAlarmCancellationPolicy.makeTombstone(
      reminderID: record.reminderID,
      current: record,
      transactions: [],
      existing: nil,
      nowEpochMs: 9_000
    )
    try businessCancellation.advance(to: .daemonCleared, nowEpochMs: 9_001)
    try businessCancellation.advance(to: .mirrorRemoved, nowEpochMs: 9_002)
    try businessCancellation.advance(to: .completed, nowEpochMs: 9_003)
    XCTAssertEqual(
      DangguiAlarmMutationPolicy.scheduleDecision(
        requested: record,
        current: nil,
        transactions: [],
        cancellation: businessCancellation
      ),
      .staleRevision,
      "A real business cancel must retain its revision high-water semantics."
    )
    XCTAssertFalse(
      DangguiAlarmCancellationPolicy.transactionOwnsSameRevisionRouteReinstall(
        transaction: routeOwner,
        cancellation: businessCancellation
      )
    )

    let nextRevision = try makeRecord(
      reminderID: record.reminderID,
      revision: record.scheduleRevision + 1
    )
    XCTAssertFalse(
      DangguiAlarmCancellationPolicy.transactionOwnsSameRevisionRouteReinstall(
        transaction: DangguiAlarmTransaction(
          replacement: nextRevision,
          previousPlatformAlarmID: record.platformAlarmID,
          previousRecord: record
        ),
        cancellation: routeRetirement
      ),
      "Only the exact immutable revision may consume a route-only marker."
    )
  }

  func testRouteReinstallCrashOwnerReleasesMarkerBeforeDaemonMutation() throws {
    let generation = "56565656-5656-4656-8656-565656565656"
    let record = try makeRecord(
      reminderID: "route-reinstall-crash",
      revision: 12,
      deviceGeneration: generation
    )
    var routeRetirement = DangguiAlarmCancellationPolicy
      .makeRouteRetirementTombstone(
        record: record,
        currentMirror: record,
        transactions: [],
        existing: nil,
        nowEpochMs: 12_000
      )
    try routeRetirement.advance(to: .daemonCleared, nowEpochMs: 12_001)
    try routeRetirement.advance(to: .mirrorRemoved, nowEpochMs: 12_002)
    try routeRetirement.advance(to: .completed, nowEpochMs: 12_003)
    try DangguiAlarmStore.activateDeviceGeneration(generation)
    try DangguiAlarmStore.upsertCancellation(routeRetirement)

    let owner = DangguiAlarmTransaction(
      replacement: record,
      previousPlatformAlarmID: nil
    )
    try DangguiAlarmStore.upsertTransaction(owner)
    XCTAssertTrue(
      DangguiAlarmCancellationPolicy.transactionOwnsSameRevisionRouteReinstall(
        transaction: owner,
        cancellation: DangguiAlarmStore.cancellation(
          reminderID: record.reminderID,
          deviceGeneration: generation
        )
      )
    )

    // This is the first store mutation performed by continueTransaction. A
    // process death immediately afterwards still leaves the pending owner,
    // while startup no longer sees a completed marker that would cancel the
    // deterministic replacement ID on every recovery pass.
    try DangguiAlarmStore.removeCancellation(
      reminderID: record.reminderID,
      deviceGeneration: generation
    )
    XCTAssertNil(
      DangguiAlarmStore.cancellation(
        reminderID: record.reminderID,
        deviceGeneration: generation
      )
    )
    XCTAssertEqual(DangguiAlarmStore.transactions(), [owner])
    XCTAssertNoThrow(try DangguiAlarmStore.assertAuthoritativeStoresHealthy())
  }

  func testSnoozePlanUsesOneClockSampleAndDefersPredecessorStop() throws {
    let generation = "55555555-5555-4555-8555-555555555555"
    let record = try makeRecord(
      reminderID: "snooze-reminder",
      revision: 3,
      deviceGeneration: generation
    )
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
    XCTAssertEqual(plan.replacement.deviceGeneration, generation)
    XCTAssertEqual(
      plan.replacement.platformAlarmID,
      DangguiAlarmIdentifier.platformID(
        for: record.reminderID,
        revision: 4,
        deviceGeneration: generation
      )
    )
    XCTAssertEqual(plan.completionEvent.deviceGeneration, generation)
    XCTAssertEqual(
      plan.completionEvent.flutterMap["deviceGeneration"] as? String,
      generation
    )
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
    XCTAssertEqual(
      plan.completionEvent.eventID,
      DangguiAlarmEvent.stableID(type: .snoozed, record: record)
    )
    var confirmed = transaction
    try confirmed.advance(to: .replacementScheduled)
    try confirmed.advance(to: .confirmed)
    XCTAssertTrue(
      DangguiAlarmSnoozePolicy.shouldStopPredecessor(transaction: confirmed)
    )
  }

  func testSnoozeConservativelyRejectsAnyUnresolvedTransaction() throws {
    let record = try makeRecord(reminderID: "snooze-busy", revision: 8)
    let unrelated = try makeRecord(reminderID: "other", revision: 1)
    XCTAssertFalse(
      DangguiAlarmSnoozePolicy.hasUnresolvedTransaction(
        reminderID: record.reminderID,
        transactions: [
          DangguiAlarmTransaction(replacement: unrelated, previousPlatformAlarmID: nil),
        ]
      )
    )
    XCTAssertTrue(
      DangguiAlarmSnoozePolicy.hasUnresolvedTransaction(
        reminderID: record.reminderID,
        transactions: [
          DangguiAlarmTransaction(
            replacement: record,
            previousPlatformAlarmID: nil
          ),
        ]
      )
    )
    var settledRecovery = DangguiAlarmTransaction(
      replacement: record,
      previousPlatformAlarmID: nil,
      ownsMissingRecovery: true
    )
    try settledRecovery.advance(to: .replacementScheduled)
    try settledRecovery.advance(to: .confirmed)
    try settledRecovery.advance(to: .retired)
    XCTAssertFalse(
      DangguiAlarmSnoozePolicy.hasUnresolvedTransaction(
        reminderID: record.reminderID,
        transactions: [settledRecovery]
      ),
      "A fully retired recovery owner may be resolved by the explicit snooze action."
    )
  }

  func testSnoozeAtomicallyReplacesSettledRecoveryOwnerWithSuccessor() throws {
    let record = try makeRecord(reminderID: "snooze-atomic", revision: 4)
    var owner = DangguiAlarmTransaction(
      replacement: record,
      previousPlatformAlarmID: nil,
      ownsMissingRecovery: true
    )
    try owner.advance(to: .replacementScheduled)
    try owner.advance(to: .confirmed)
    try owner.advance(to: .retired)
    try DangguiAlarmStore.upsert(record)
    try DangguiAlarmStore.upsertTransaction(owner)

    let plan = DangguiAlarmSnoozePolicy.makePlan(
      record: record,
      minutes: 10,
      occurredAtEpochMs: 100_000
    )
    let successor = DangguiAlarmTransaction(
      replacement: plan.replacement,
      previousPlatformAlarmID: record.platformAlarmID,
      previousRecord: record,
      stopPreviousWhenConfirmed: true,
      completionEvent: plan.completionEvent
    )
    try DangguiAlarmStore.replaceTransactionsAtomically(
      reminderID: record.reminderID,
      removingTransactionIDs: [owner.transactionID],
      adding: successor
    )

    XCTAssertEqual(DangguiAlarmStore.transactions(), [successor])
    XCTAssertEqual(DangguiAlarmStore.record(reminderID: record.reminderID), record)
    XCTAssertEqual(successor.phase, .pending)
  }

  func testGeneralRevisionHandoffAtomicallyReplacesEveryPreviousOwner() throws {
    let revision1 = try makeRecord(reminderID: "handoff-owner", revision: 1)
    let revision2 = try makeRecord(reminderID: revision1.reminderID, revision: 2)
    let revision3 = try makeRecord(reminderID: revision1.reminderID, revision: 3)
    let firstOwner = DangguiAlarmTransaction(
      replacement: revision2,
      previousPlatformAlarmID: revision1.platformAlarmID,
      previousRecord: revision1
    )
    let secondOwner = DangguiAlarmTransaction(
      replacement: revision3,
      previousPlatformAlarmID: revision2.platformAlarmID,
      previousRecord: revision2
    )
    try DangguiAlarmStore.upsertTransaction(firstOwner)
    try DangguiAlarmStore.upsertTransaction(secondOwner)
    XCTAssertEqual(
      Set(DangguiAlarmStore.transactions().map(\.transactionID)),
      Set([firstOwner.transactionID, secondOwner.transactionID])
    )

    let revision4 = try makeRecord(reminderID: revision1.reminderID, revision: 4)
    let successorOwner = DangguiAlarmTransaction(
      replacement: revision4,
      previousPlatformAlarmID: revision3.platformAlarmID,
      previousRecord: revision3
    )
    try DangguiAlarmStore.replaceTransactionsAtomically(
      reminderID: revision1.reminderID,
      removingTransactionIDs: Set([
        firstOwner.transactionID,
        secondOwner.transactionID,
      ]),
      adding: successorOwner
    )

    XCTAssertEqual(DangguiAlarmStore.transactions(), [successorOwner])
    XCTAssertNoThrow(try DangguiAlarmStore.assertAuthoritativeStoresHealthy())
  }

  func testReplacementOwnershipSurvivesEveryPersistedCrashPhase() throws {
    for (index, crashPhase) in DangguiAlarmTransactionPhase.allCases.enumerated() {
      let reminderID = "handoff-crash-\(index)"
      let revision1 = try makeRecord(reminderID: reminderID, revision: 1)
      let revision2 = try makeRecord(reminderID: reminderID, revision: 2)
      let revision3 = try makeRecord(reminderID: reminderID, revision: 3)
      let oldOwner = DangguiAlarmTransaction(
        replacement: revision2,
        previousPlatformAlarmID: revision1.platformAlarmID,
        previousRecord: revision1
      )
      try DangguiAlarmStore.upsert(revision1)
      try DangguiAlarmStore.upsertTransaction(oldOwner)

      var successorOwner = DangguiAlarmTransaction(
        replacement: revision3,
        previousPlatformAlarmID: revision2.platformAlarmID,
        previousRecord: revision2
      )
      while successorOwner.phase != crashPhase {
        let next: DangguiAlarmTransactionPhase
        switch successorOwner.phase {
        case .pending:
          next = .replacementScheduled
        case .replacementScheduled:
          successorOwner.replacement.lastState = "scheduled"
          next = .confirmed
        case .confirmed:
          next = .retired
        case .retired:
          XCTFail("Cannot advance beyond retired")
          next = .retired
        }
        if successorOwner.phase == .retired { break }
        try successorOwner.advance(to: next)
      }
      try DangguiAlarmStore.replaceTransactionsAtomically(
        reminderID: reminderID,
        removingTransactionIDs: [oldOwner.transactionID],
        adding: successorOwner
      )

      // Reloading the store models a process death after any durable phase.
      let reloaded = DangguiAlarmStore.transactions().filter {
        $0.reminderID == reminderID
      }
      XCTAssertEqual(reloaded, [successorOwner])
      XCTAssertEqual(
        DangguiAlarmMutationPolicy.scheduleDecision(
          requested: revision3,
          current: revision1,
          transactions: reloaded,
          cancellation: nil
        ),
        .idempotent
      )
      XCTAssertEqual(
        DangguiAlarmMutationPolicy.scheduleDecision(
          requested: revision2,
          current: revision1,
          transactions: reloaded,
          cancellation: nil
        ),
        .staleRevision
      )
      XCTAssertNoThrow(try DangguiAlarmStore.assertAuthoritativeStoresHealthy())
    }
  }

  func testStopTombstonePrecommitsStableEventAndRevisionHighWater() throws {
    let current = try makeRecord(reminderID: "stop-durable", revision: 11)
    let successor = try makeRecord(reminderID: current.reminderID, revision: 12)
    let transaction = DangguiAlarmTransaction(
      replacement: successor,
      previousPlatformAlarmID: current.platformAlarmID,
      previousRecord: current
    )
    let tombstone = DangguiAlarmCancellationPolicy.makeStopTombstone(
      record: successor,
      transactions: [transaction],
      existing: nil,
      nowEpochMs: 9_000
    )

    XCTAssertEqual(tombstone.phase, .pending)
    XCTAssertEqual(tombstone.cancelledThroughRevision, 12)
    XCTAssertEqual(tombstone.daemonAction, .stop)
    XCTAssertEqual(
      tombstone.stopPlatformAlarmID,
      successor.platformAlarmID.lowercased()
    )
    XCTAssertEqual(tombstone.completionEvent?.type, DangguiAlarmEventType.stopped.rawValue)
    XCTAssertEqual(
      tombstone.completionEvent?.eventID,
      DangguiAlarmEvent.stableID(type: .stopped, record: successor)
    )
    XCTAssertEqual(tombstone.completionEvent?.occurredAtEpochMs, 9_000)

    var legacyObject = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(tombstone))
        as? [String: Any]
    )
    legacyObject.removeValue(forKey: "daemonAction")
    legacyObject.removeValue(forKey: "stopPlatformAlarmID")
    legacyObject.removeValue(forKey: "completionEvent")
    legacyObject.removeValue(forKey: "terminalState")
    let legacy = try JSONDecoder().decode(
      DangguiAlarmCancellation.self,
      from: JSONSerialization.data(withJSONObject: legacyObject)
    )
    XCTAssertNil(legacy.daemonAction)
    XCTAssertNil(legacy.stopPlatformAlarmID)
    XCTAssertNil(legacy.completionEvent)
    XCTAssertNil(legacy.terminalState)
  }

  func testMissedTombstoneScopesRevisionAndSurvivesCancelFailure() throws {
    let activeRevision4 = try makeRecord(reminderID: "missed-scope", revision: 4)
    let expiredRevision5 = try makeRecord(reminderID: "missed-scope", revision: 5)
    let transaction5 = DangguiAlarmTransaction(
      replacement: expiredRevision5,
      previousPlatformAlarmID: activeRevision4.platformAlarmID,
      previousRecord: activeRevision4
    )
    try DangguiAlarmStore.upsert(activeRevision4)
    try DangguiAlarmStore.upsertTransaction(transaction5)

    var tombstone = DangguiAlarmCancellationPolicy.makeMissedTombstone(
      record: expiredRevision5,
      transactions: [transaction5],
      existing: nil,
      nowEpochMs: expiredRevision5.triggerAtEpochMs + 901_000
    )
    // Persisting pending without advancing models AlarmKit cancellation
    // throwing before daemon-cleared is durable.
    try DangguiAlarmStore.upsertCancellation(tombstone)

    XCTAssertEqual(tombstone.cancelledThroughRevision, 5)
    XCTAssertEqual(tombstone.terminalState, "missed")
    XCTAssertEqual(
      Set(tombstone.platformAlarmIDs),
      Set([
        activeRevision4.platformAlarmID.lowercased(),
        expiredRevision5.platformAlarmID.lowercased(),
      ])
    )
    XCTAssertEqual(tombstone.completionEvent?.type, DangguiAlarmEventType.missed.rawValue)
    XCTAssertFalse(
      DangguiAlarmStore.events().contains {
        $0.type == DangguiAlarmEventType.stopped.rawValue
      }
    )
    XCTAssertEqual(DangguiAlarmStore.record(reminderID: activeRevision4.reminderID), activeRevision4)
    XCTAssertEqual(DangguiAlarmStore.transactions(), [transaction5])

    XCTAssertEqual(
      DangguiAlarmMutationPolicy.scheduleDecision(
        requested: expiredRevision5,
        current: activeRevision4,
        transactions: [transaction5],
        cancellation: tombstone
      ),
      .staleRevision
    )
    let revision6 = try makeRecord(reminderID: activeRevision4.reminderID, revision: 6)
    XCTAssertEqual(
      DangguiAlarmMutationPolicy.scheduleDecision(
        requested: revision6,
        current: activeRevision4,
        transactions: [transaction5],
        cancellation: tombstone
      ),
      .staleRevision,
      "No revision may race a pending terminal daemon cleanup."
    )

    try tombstone.advance(to: .daemonCleared, nowEpochMs: 2)
    try tombstone.advance(to: .mirrorRemoved, nowEpochMs: 3)
    try tombstone.advance(to: .completed, nowEpochMs: 4)
    XCTAssertEqual(
      DangguiAlarmMutationPolicy.scheduleDecision(
        requested: expiredRevision5,
        current: nil,
        transactions: [],
        cancellation: tombstone
      ),
      .staleRevision
    )
    XCTAssertEqual(
      DangguiAlarmMutationPolicy.scheduleDecision(
        requested: revision6,
        current: nil,
        transactions: [],
        cancellation: tombstone
      ),
      .install
    )
  }

  func testExpiredRevision5TombstoneAlsoTargetsActiveRevision4Mirror() throws {
    let active4 = try makeRecord(reminderID: "expired-current", revision: 4)
    let expired5 = try makeRecord(reminderID: active4.reminderID, revision: 5)
    let tombstone = DangguiAlarmCancellationPolicy.makeMissedTombstone(
      record: expired5,
      currentMirror: active4,
      transactions: [],
      existing: nil,
      nowEpochMs: expired5.triggerAtEpochMs + 901_000
    )

    XCTAssertEqual(tombstone.cancelledThroughRevision, 5)
    XCTAssertEqual(
      Set(tombstone.platformAlarmIDs),
      Set([
        active4.platformAlarmID.lowercased(),
        expired5.platformAlarmID.lowercased(),
      ]),
      "The older active daemon registration must be recoverably retired."
    )
  }

  func testExpiredRevision5ExcludesAndPreservesNewerRevision6Mirror() throws {
    let expired5 = try makeRecord(reminderID: "expired-newer", revision: 5)
    let current6 = try makeRecord(reminderID: expired5.reminderID, revision: 6)
    try DangguiAlarmStore.upsert(current6)
    let tombstone = DangguiAlarmCancellationPolicy.makeMissedTombstone(
      record: expired5,
      currentMirror: current6,
      transactions: [],
      existing: nil,
      nowEpochMs: expired5.triggerAtEpochMs + 901_000
    )

    XCTAssertEqual(
      Set(tombstone.platformAlarmIDs),
      Set([expired5.platformAlarmID.lowercased()])
    )
    XCTAssertFalse(
      tombstone.platformAlarmIDs.contains(current6.platformAlarmID.lowercased())
    )
    try DangguiAlarmStore.upsertCancellation(tombstone)
    try DangguiAlarmStore.removeRecordsAndTransactions(
      reminderID: expired5.reminderID,
      platformAlarmIDs: Set(tombstone.platformAlarmIDs)
    )
    XCTAssertEqual(DangguiAlarmStore.record(reminderID: current6.reminderID), current6)
  }

  func testTerminalCleanupPreservesNewerRevision() throws {
    let expired5 = try makeRecord(reminderID: "terminal-scope", revision: 5)
    let current6 = try makeRecord(reminderID: "terminal-scope", revision: 6)
    let transaction5 = DangguiAlarmTransaction(
      replacement: expired5,
      previousPlatformAlarmID: nil
    )
    let transaction6 = DangguiAlarmTransaction(
      replacement: current6,
      previousPlatformAlarmID: expired5.platformAlarmID,
      previousRecord: expired5
    )
    try DangguiAlarmStore.upsert(current6)
    try DangguiAlarmStore.upsertTransaction(transaction5)
    try DangguiAlarmStore.upsertTransaction(transaction6)

    try DangguiAlarmStore.removeRecordsAndTransactions(
      reminderID: expired5.reminderID,
      platformAlarmIDs: Set([expired5.platformAlarmID])
    )

    XCTAssertEqual(DangguiAlarmStore.record(reminderID: current6.reminderID), current6)
    XCTAssertEqual(DangguiAlarmStore.transactions(), [transaction6])
  }

  func testObservedRetirementCreatesHighWaterWithoutStoppedEvent() throws {
    let delivered = try makeRecord(reminderID: "delivered-retired", revision: 7)
    let tombstone = DangguiAlarmCancellationPolicy.makeObservedRetirementTombstone(
      record: delivered,
      transactions: [],
      existing: nil,
      nowEpochMs: 5_000
    )
    XCTAssertEqual(tombstone.cancelledThroughRevision, 7)
    XCTAssertEqual(tombstone.terminalState, "delivered-retired")
    XCTAssertNil(tombstone.completionEvent)
    var completed = tombstone
    try completed.advance(to: .daemonCleared, nowEpochMs: 5_001)
    try completed.advance(to: .mirrorRemoved, nowEpochMs: 5_002)
    try completed.advance(to: .completed, nowEpochMs: 5_003)

    XCTAssertEqual(
      DangguiAlarmMutationPolicy.scheduleDecision(
        requested: delivered,
        current: nil,
        transactions: [],
        cancellation: completed
      ),
      .staleRevision
    )
    let next = try makeRecord(reminderID: delivered.reminderID, revision: 8)
    XCTAssertEqual(
      DangguiAlarmMutationPolicy.scheduleDecision(
        requested: next,
        current: nil,
        transactions: [],
        cancellation: completed
      ),
      .install
    )
  }

  func testLifecycleEventIDsAreStableButErrorsRemainUnique() throws {
    let record = try makeRecord(reminderID: "stable-events", revision: 5)
    for type in [
      DangguiAlarmEventType.registered,
      .delivered,
      .systemAlert,
      .missed,
      .stopped,
    ] {
      let first = DangguiAlarmEvent(type: type, record: record, usesStableID: true)
      let retry = DangguiAlarmEvent(type: type, record: record, usesStableID: true)
      XCTAssertEqual(first.eventID, retry.eventID)
    }
    XCTAssertNotEqual(
      DangguiAlarmEvent(type: .error, record: record).eventID,
      DangguiAlarmEvent(type: .error, record: record).eventID
    )

    let registered = DangguiAlarmEvent(
      type: .registered,
      record: record,
      usesStableID: true
    )
    try DangguiAlarmStore.appendEventDurably(registered)
    try DangguiAlarmStore.appendEventDurably(registered)
    XCTAssertEqual(DangguiAlarmStore.events(), [registered])
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

  func testPartiallyCorruptLegacyMirrorWithoutNativeLKGAlsoFailsClosed() throws {
    let legacyKey = "danggui.nativeAlarms.records.v1"
    let record = try makeRecord(reminderID: "legacy-corrupt", revision: 2)
    let validObject = try JSONSerialization.jsonObject(
      with: JSONEncoder().encode(record)
    )
    let corruptLegacy = try JSONSerialization.data(
      withJSONObject: [validObject, ["reminderID": false]]
    )
    UserDefaults.standard.set(corruptLegacy, forKey: legacyKey)

    XCTAssertTrue(DangguiAlarmStore.records().isEmpty)
    XCTAssertThrowsError(try DangguiAlarmStore.assertAuthoritativeStoresHealthy())
    XCTAssertThrowsError(
      try DangguiAlarmStore.upsert(
        makeRecord(reminderID: "must-not-replace-legacy", revision: 3)
      )
    )
    XCTAssertEqual(UserDefaults.standard.data(forKey: legacyKey), corruptLegacy)
  }

  func testCorruptPrimaryExposesLKGForDiagnosisButBlocksWrites() throws {
    let first = try makeRecord(reminderID: "backup-first", revision: 1)
    let second = try makeRecord(reminderID: "backup-second", revision: 1)
    try DangguiAlarmStore.upsert(first)
    try DangguiAlarmStore.upsert(second)
    try DangguiAlarmStore.replaceRecordsDataForTesting(Data("not-json".utf8))

    XCTAssertEqual(DangguiAlarmStore.records(), [first])
    XCTAssertThrowsError(try DangguiAlarmStore.assertAuthoritativeStoresHealthy())
    XCTAssertThrowsError(
      try DangguiAlarmStore.upsert(
        makeRecord(reminderID: "blocked-write", revision: 2)
      )
    )
  }

  func testSemanticallyForgedRecordPrimaryFallsBackAndFailsClosed() throws {
    let lastKnownGood = try makeRecord(reminderID: "semantic-record", revision: 1)
    let latest = try makeRecord(reminderID: lastKnownGood.reminderID, revision: 2)
    try DangguiAlarmStore.upsert(lastKnownGood)
    try DangguiAlarmStore.upsert(latest)

    var forged = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(latest))
        as? [String: Any]
    )
    forged["platformAlarmID"] = UUID().uuidString
    try DangguiAlarmStore.replaceRecordsDataForTesting(
      JSONSerialization.data(withJSONObject: [forged])
    )

    XCTAssertEqual(DangguiAlarmStore.records(), [lastKnownGood])
    XCTAssertThrowsError(try DangguiAlarmStore.assertAuthoritativeStoresHealthy())
  }

  func testSemanticallyForgedTransactionPrimaryFallsBackAndFailsClosed() throws {
    let previous = try makeRecord(reminderID: "semantic-transaction", revision: 1)
    let replacement = try makeRecord(reminderID: previous.reminderID, revision: 2)
    let lastKnownGood = DangguiAlarmTransaction(
      replacement: replacement,
      previousPlatformAlarmID: previous.platformAlarmID,
      previousRecord: previous
    )
    try DangguiAlarmStore.upsertTransaction(lastKnownGood)
    var latest = lastKnownGood
    try latest.advance(to: .replacementScheduled)
    try DangguiAlarmStore.upsertTransaction(latest)

    var forged = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(latest))
        as? [String: Any]
    )
    forged["reminderID"] = "different-reminder"
    try DangguiAlarmStore.replaceTransactionsDataForTesting(
      JSONSerialization.data(withJSONObject: [forged])
    )

    XCTAssertEqual(DangguiAlarmStore.transactions(), [lastKnownGood])
    XCTAssertThrowsError(try DangguiAlarmStore.assertAuthoritativeStoresHealthy())
  }

  func testSemanticallyForgedTransactionCannotClaimScheduledBeforeConfirmation() throws {
    let replacement = try makeRecord(
      reminderID: "semantic-transaction-phase",
      revision: 2
    )
    let transaction = DangguiAlarmTransaction(
      replacement: replacement,
      previousPlatformAlarmID: nil
    )
    try DangguiAlarmStore.upsertTransaction(transaction)

    var forged = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(transaction))
        as? [String: Any]
    )
    var forgedReplacement = try XCTUnwrap(
      forged["replacement"] as? [String: Any]
    )
    forgedReplacement["lastState"] = "scheduled"
    forged["replacement"] = forgedReplacement
    try DangguiAlarmStore.replaceTransactionsDataForTesting(
      JSONSerialization.data(withJSONObject: [forged])
    )

    XCTAssertThrowsError(try DangguiAlarmStore.assertAuthoritativeStoresHealthy())
  }

  func testSemanticallyForgedCancellationPrimaryFallsBackAndFailsClosed() throws {
    let record = try makeRecord(reminderID: "semantic-cancellation", revision: 3)
    let lastKnownGood = DangguiAlarmCancellationPolicy.makeTombstone(
      reminderID: record.reminderID,
      current: record,
      transactions: [],
      existing: nil,
      nowEpochMs: 3_000
    )
    try DangguiAlarmStore.upsertCancellation(lastKnownGood)
    var latest = lastKnownGood
    try latest.advance(to: .daemonCleared, nowEpochMs: 3_001)
    try DangguiAlarmStore.upsertCancellation(latest)

    var forged = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(latest))
        as? [String: Any]
    )
    forged["cancelledThroughRevision"] = -1
    try DangguiAlarmStore.replaceCancellationsDataForTesting(
      JSONSerialization.data(withJSONObject: [forged])
    )

    XCTAssertEqual(DangguiAlarmStore.cancellations(), [lastKnownGood])
    XCTAssertThrowsError(try DangguiAlarmStore.assertAuthoritativeStoresHealthy())
  }

  func testCancellationHighWaterMustOwnItsDeterministicPlatformID() throws {
    let record = try makeRecord(reminderID: "semantic-cancel-id", revision: 6)
    let cancellation = DangguiAlarmCancellationPolicy.makeTombstone(
      reminderID: record.reminderID,
      current: record,
      transactions: [],
      existing: nil,
      nowEpochMs: 6_000
    )
    try DangguiAlarmStore.upsertCancellation(cancellation)

    var forged = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(cancellation))
        as? [String: Any]
    )
    forged["platformAlarmIDs"] = [UUID().uuidString.lowercased()]
    try DangguiAlarmStore.replaceCancellationsDataForTesting(
      JSONSerialization.data(withJSONObject: [forged])
    )
    XCTAssertThrowsError(try DangguiAlarmStore.assertAuthoritativeStoresHealthy())
  }

  func testCancellationCannotTargetKnownDifferentReminderRoute() throws {
    let cancelled = try makeRecord(reminderID: "semantic-cancel-owner", revision: 2)
    let unrelated = try makeRecord(reminderID: "semantic-cancel-victim", revision: 1)
    try DangguiAlarmStore.upsert(unrelated)
    var cancellation = DangguiAlarmCancellationPolicy.makeTombstone(
      reminderID: cancelled.reminderID,
      current: cancelled,
      transactions: [],
      existing: nil,
      nowEpochMs: 7_000
    )
    cancellation.platformAlarmIDs.append(unrelated.platformAlarmID.lowercased())
    cancellation.platformAlarmIDs.sort()
    try DangguiAlarmStore.replaceCancellationsDataForTesting(
      JSONEncoder().encode([cancellation])
    )
    XCTAssertThrowsError(try DangguiAlarmStore.assertAuthoritativeStoresHealthy())
  }

  func testV114OptionalTransactionAndCancellationFieldsRemainHealthy() throws {
    let previous = try makeRecord(reminderID: "v114-fixture", revision: 4)
    let replacement = try makeRecord(reminderID: previous.reminderID, revision: 5)
    let transaction = DangguiAlarmTransaction(
      replacement: replacement,
      previousPlatformAlarmID: previous.platformAlarmID,
      previousRecord: previous
    )
    var transactionObject = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(transaction))
        as? [String: Any]
    )
    transactionObject.removeValue(forKey: "ownsMissingRecovery")
    let legacyTransaction = try JSONDecoder().decode(
      DangguiAlarmTransaction.self,
      from: JSONSerialization.data(withJSONObject: transactionObject)
    )

    let cancellation = DangguiAlarmCancellationPolicy.makeTombstone(
      reminderID: previous.reminderID,
      current: previous,
      transactions: [],
      existing: nil,
      nowEpochMs: 4_000
    )
    var cancellationObject = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(cancellation))
        as? [String: Any]
    )
    for key in [
      "daemonAction",
      "stopPlatformAlarmID",
      "completionEvent",
      "terminalState",
    ] {
      cancellationObject.removeValue(forKey: key)
    }
    let legacyCancellation = try JSONDecoder().decode(
      DangguiAlarmCancellation.self,
      from: JSONSerialization.data(withJSONObject: cancellationObject)
    )

    try DangguiAlarmStore.upsertTransaction(legacyTransaction)
    try DangguiAlarmStore.upsertCancellation(legacyCancellation)
    XCTAssertNoThrow(try DangguiAlarmStore.assertAuthoritativeStoresHealthy())
  }

  func testPartiallyDecodablePrimaryCannotReplaceLastKnownGoodMirror() throws {
    let lastKnownGood = try makeRecord(reminderID: "backup-lkg", revision: 1)
    let next = try makeRecord(reminderID: "backup-next", revision: 1)
    try DangguiAlarmStore.upsert(lastKnownGood)
    try DangguiAlarmStore.upsert(next)

    let nextObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(next))
    let partiallyCorrupt = try JSONSerialization.data(
      withJSONObject: [nextObject, ["reminderID": 42, "platformAlarmID": false]]
    )
    try DangguiAlarmStore.replaceRecordsDataForTesting(partiallyCorrupt)
    XCTAssertEqual(
      DangguiAlarmStore.records(),
      [lastKnownGood],
      "A complete LKG must win immediately over a partially decoded primary."
    )

    let third = try makeRecord(reminderID: "backup-third", revision: 1)
    XCTAssertThrowsError(try DangguiAlarmStore.upsert(third))
    XCTAssertEqual(DangguiAlarmStore.records(), [lastKnownGood])
    XCTAssertThrowsError(try DangguiAlarmStore.assertAuthoritativeStoresHealthy())
  }

  func testCorruptCancellationPrimaryCannotRollBackLatestTerminalTombstone() throws {
    let revision4 = try makeRecord(reminderID: "terminal-lkg", revision: 4)
    let revision5 = try makeRecord(reminderID: revision4.reminderID, revision: 5)
    let old = DangguiAlarmCancellationPolicy.makeObservedRetirementTombstone(
      record: revision4,
      transactions: [],
      existing: nil,
      nowEpochMs: 4_000
    )
    let latest = DangguiAlarmCancellationPolicy.makeMissedTombstone(
      record: revision5,
      transactions: [],
      existing: old,
      nowEpochMs: 5_000
    )
    try DangguiAlarmStore.upsertCancellation(old)
    try DangguiAlarmStore.upsertCancellation(latest)
    let corruptPrimary = Data("not-json".utf8)
    try DangguiAlarmStore.replaceCancellationsDataForTesting(corruptPrimary)

    XCTAssertEqual(
      DangguiAlarmStore.cancellations(),
      [old],
      "The backup is diagnostic-only and may omit the latest rev5 tombstone."
    )
    XCTAssertThrowsError(try DangguiAlarmStore.assertAuthoritativeStoresHealthy())
    let revision6 = try makeRecord(reminderID: revision4.reminderID, revision: 6)
    XCTAssertThrowsError(
      try DangguiAlarmStore.upsertCancellation(
        DangguiAlarmCancellationPolicy.makeObservedRetirementTombstone(
          record: revision6,
          transactions: [],
          existing: old,
          nowEpochMs: 6_000
        )
      )
    )
    XCTAssertNil(
      DangguiAlarmStore.authoritativeActionRecord(
        reminderID: revision6.reminderID,
        scheduleRevision: revision6.scheduleRevision,
        platformAlarmID: revision6.platformAlarmID
      )
    )
    XCTAssertEqual(
      try Data(
        contentsOf: storeDirectory.appendingPathComponent("alarm-cancellations-v1.json")
      ),
      corruptPrimary
    )
  }

  func testMissingAlarmWithinLateWindowRequiresRecoveryNotSyntheticDelivery() {
    let now: Int64 = 2_000_000
    XCTAssertEqual(
      DangguiAlarmRecoveryPolicy.missingAlarmDecision(
        triggerAtEpochMs: now - 1,
        nowEpochMs: now
      ),
      .recoverLate
    )
    XCTAssertEqual(
      DangguiAlarmRecoveryPolicy.missingAlarmDecision(
        triggerAtEpochMs: now - DangguiAlarmRecoveryPolicy.lateRecoveryWindowMs,
        nowEpochMs: now
      ),
      .recoverLate
    )
    XCTAssertEqual(
      DangguiAlarmRecoveryPolicy.missingAlarmDecision(
        triggerAtEpochMs: now - DangguiAlarmRecoveryPolicy.lateRecoveryWindowMs - 1,
        nowEpochMs: now
      ),
      .missed
    )
    XCTAssertEqual(
      DangguiAlarmRecoveryPolicy.missingAlarmDecision(
        triggerAtEpochMs: now + 1,
        nowEpochMs: now
      ),
      .recoverScheduled
    )
    XCTAssertEqual(
      DangguiAlarmRecoveryPolicy.missingAlarmDecision(
        triggerAtEpochMs: now - 1,
        nowEpochMs: now,
        observedDelivered: true
      ),
      .retireObserved
    )
    XCTAssertFalse(
      DangguiAlarmRecoveryPolicy.shouldRetryMissingTransaction(
        ownsMissingRecovery: true,
        triggerAtEpochMs: now,
        nowEpochMs: now
      ),
      "A due transaction-owned repair must not be replayed as an audible duplicate."
    )
    XCTAssertTrue(
      DangguiAlarmRecoveryPolicy.shouldRetryMissingTransaction(
        ownsMissingRecovery: true,
        triggerAtEpochMs: now + 1,
        nowEpochMs: now
      ),
      "A future registration missing from AlarmKit may be repaired safely."
    )
    XCTAssertTrue(
      DangguiAlarmRecoveryPolicy.shouldRetryMissingTransaction(
        ownsMissingRecovery: false,
        triggerAtEpochMs: now - 1,
        nowEpochMs: now
      )
    )
  }

  func testMissingRecoveryIsOwnedByBackwardCompatibleTransaction() throws {
    let record = try makeRecord(reminderID: "repair-transaction", revision: 3)
    let transaction = DangguiAlarmTransaction(
      replacement: record,
      previousPlatformAlarmID: nil,
      ownsMissingRecovery: true
    )
    let roundTrip = try JSONDecoder().decode(
      DangguiAlarmTransaction.self,
      from: JSONEncoder().encode(transaction)
    )
    XCTAssertEqual(roundTrip.ownsMissingRecovery, true)

    var legacyObject = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(transaction))
        as? [String: Any]
    )
    legacyObject.removeValue(forKey: "ownsMissingRecovery")
    let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
    let legacy = try JSONDecoder().decode(DangguiAlarmTransaction.self, from: legacyData)
    XCTAssertNil(legacy.ownsMissingRecovery)
    XCTAssertTrue(
      DangguiAlarmRecoveryPolicy.shouldPersistRecoveryFailure(
        transactionID: transaction.transactionID,
        transactions: [transaction]
      )
    )
    XCTAssertFalse(
      DangguiAlarmRecoveryPolicy.shouldPersistRecoveryFailure(
        transactionID: transaction.transactionID,
        transactions: []
      ),
      "A terminally removed transaction must never be recreated by an outer catch."
    )
  }

  func testAppIntentIdentityMustBindReminderRevisionAndPlatformSession() throws {
    let record = try makeRecord(reminderID: "intent-cas", revision: 9)
    XCTAssertTrue(
      DangguiAlarmActionIdentity(
        reminderID: record.reminderID,
        scheduleRevision: record.scheduleRevision,
        platformAlarmID: record.platformAlarmID
      ).matches(record)
    )
    XCTAssertFalse(
      DangguiAlarmActionIdentity(
        reminderID: record.reminderID,
        scheduleRevision: record.scheduleRevision - 1,
        platformAlarmID: record.platformAlarmID
      ).matches(record)
    )
    XCTAssertFalse(
      DangguiAlarmActionIdentity(
        reminderID: record.reminderID,
        scheduleRevision: record.scheduleRevision,
        platformAlarmID: DangguiAlarmIdentifier.platformID(
          for: record.reminderID,
          revision: record.scheduleRevision + 1
        )
      ).matches(record)
    )
  }

  func testAppIntentTargetsNewestDurableTransactionRevision() throws {
    let previous = try makeRecord(reminderID: "intent-transaction", revision: 4)
    let replacement = try makeRecord(reminderID: "intent-transaction", revision: 5)
    try DangguiAlarmStore.upsert(previous)
    try DangguiAlarmStore.upsertTransaction(
      DangguiAlarmTransaction(
        replacement: replacement,
        previousPlatformAlarmID: previous.platformAlarmID,
        previousRecord: previous
      )
    )

    XCTAssertNil(
      DangguiAlarmStore.authoritativeActionRecord(
        reminderID: previous.reminderID,
        scheduleRevision: previous.scheduleRevision,
        platformAlarmID: previous.platformAlarmID
      ),
      "An old action cannot mutate the successor while replacement is in flight."
    )
    XCTAssertEqual(
      DangguiAlarmStore.authoritativeActionRecord(
        reminderID: replacement.reminderID,
        scheduleRevision: replacement.scheduleRevision,
        platformAlarmID: replacement.platformAlarmID
      ),
      replacement
    )
  }

  private func makeRecord(
    reminderID: String,
    revision: Int,
    deviceGeneration: String? = nil,
    triggerAtEpochMs: Int64? = nil,
    vibrationEnabled: Bool = true,
    snoozeMinutes: Int = 10
  ) throws -> DangguiAlarmRecord {
    var arguments: [String: Any] = [
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
    ]
    if let deviceGeneration {
      arguments["deviceGeneration"] = deviceGeneration
    }
    return try DangguiAlarmRecord(arguments: arguments)
  }
}
