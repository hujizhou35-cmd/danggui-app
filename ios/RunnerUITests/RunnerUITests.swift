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
    app.launchArguments += [
      "--danggui-xcui-scenario=\(scenario)",
      "-AppleLanguages", "(en)",
      "-AppleLocale", "en_US",
    ]
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
      predicate: NSPredicate(
        format: "label == %@ OR label BEGINSWITH %@",
        expected,
        "XCUITEST FAIL"
      ),
      object: result
    )
    let outcome = XCTWaiter().wait(for: [completion], timeout: timeout)
    XCTAssertEqual(
      outcome,
      .completed,
      "Scenario timed out with visible result: \(result.label)"
    )
    XCTAssertEqual(
      result.label,
      expected,
      "Scenario failed with visible result: \(result.label)"
    )
  }
}
