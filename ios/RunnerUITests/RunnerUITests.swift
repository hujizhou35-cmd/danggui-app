import XCTest

final class RunnerUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testTaskReminderDeleteAndRestoreContract() throws {
    assertScenario("task-reminder-trash-restore", timeout: 90)
  }

  func testBackupRestoreRebuildsReminderContract() throws {
    assertScenario("backup-restore-reminder-rebuild", timeout: 120)
  }

  private func assertScenario(_ scenario: String, timeout: TimeInterval) {
    let app = XCUIApplication()
    if app.state != .notRunning {
      app.terminate()
    }
    app.launchEnvironment["DANGGUI_XCUITEST_SCENARIO"] = scenario
    app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    app.launch()
    defer { app.terminate() }

    let result = app.descendants(matching: .any)
      .matching(identifier: "xcui-scenario-result")
      .firstMatch
    XCTAssertTrue(
      result.waitForExistence(timeout: 15),
      "Scenario produced no result. Visible labels: \(app.descendants(matching: .any).allElementsBoundByIndex.map(\.label))"
    )
    let expected = "XCUITEST PASS \(scenario)"
    let completion = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", expected),
      object: result
    )
    let outcome = XCTWaiter().wait(for: [completion], timeout: timeout)
    XCTAssertEqual(
      outcome,
      .completed,
      "Scenario failed with visible result: \(result.label)"
    )
  }
}
