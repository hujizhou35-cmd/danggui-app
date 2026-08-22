import Flutter
import UIKit
import UserNotifications
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludeDangguiDataFromSystemBackups()
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Danggui deliberately keeps its private database and automatic backups on
  /// this device. Application Support participates in iOS device backups by
  /// default, so mark the app-owned directory as excludable on every launch.
  /// Users can still create an explicit portable backup from inside the app.
  private func excludeDangguiDataFromSystemBackups() {
    do {
      let fileManager = FileManager.default
      let supportURL = try fileManager.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      )
      var dangguiURL = supportURL.appendingPathComponent("danggui", isDirectory: true)
      try fileManager.createDirectory(
        at: dangguiURL,
        withIntermediateDirectories: true,
        attributes: nil
      )
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try dangguiURL.setResourceValues(values)
    } catch {
      // Do not make the local database unavailable if the filesystem refuses
      // this advisory resource value. The static release audit ensures the
      // exclusion attempt remains wired into every build.
      NSLog("Danggui could not mark its private data directory as excluded from system backup.")
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
