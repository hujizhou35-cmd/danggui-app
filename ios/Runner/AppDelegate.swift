import Flutter
import UIKit
import UserNotifications
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var notificationSettingsChannel: FlutterMethodChannel?
  private var dataProtectionChannel: FlutterMethodChannel?
  private var reminderPlatformBridge: ReminderPlatformBridge?
  private lazy var dataProtectionCoordinator = DangguiDataProtectionCoordinator {
    let fileManager = FileManager.default
    let supportURL = try fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let dangguiURL = supportURL.appendingPathComponent("danggui", isDirectory: true)
    try DangguiDataProtection.apply(to: dangguiURL, fileManager: fileManager)
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    _ = excludeDangguiDataFromSystemBackups()
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Danggui deliberately keeps its private database and automatic backups on
  /// this device. Application Support participates in iOS device backups by
  /// default, so mark the app-owned directory as excludable on every launch.
  /// Users can still create an explicit portable backup from inside the app.
  private func excludeDangguiDataFromSystemBackups() -> DangguiDataProtectionStatus {
    dataProtectionCoordinator.retry()
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "com.danggui.memo/settings",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "openNotificationSettings" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let settingsURLString: String
      if #available(iOS 16.0, *) {
        settingsURLString = UIApplication.openNotificationSettingsURLString
      } else if #available(iOS 15.4, *) {
        settingsURLString = UIApplicationOpenNotificationSettingsURLString
      } else {
        settingsURLString = UIApplication.openSettingsURLString
      }
      guard let url = URL(string: settingsURLString) else {
        result(
          FlutterError(
            code: "settings_unavailable",
            message: "The application settings URL is unavailable.",
            details: nil
          )
        )
        return
      }
      UIApplication.shared.open(url, options: [:]) { opened in
        if opened {
          result(nil)
        } else {
          result(
            FlutterError(
              code: "settings_unavailable",
              message: "The operating system did not open application settings.",
              details: nil
            )
          )
        }
      }
    }
    notificationSettingsChannel = channel
    let protectionChannel = FlutterMethodChannel(
      name: "com.danggui.memo/data_protection",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    protectionChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(["status": "unavailable", "errorCode": "bridge-unavailable"])
        return
      }
      switch call.method {
      case "getDataProtectionStatus":
        result(self.dataProtectionCoordinator.currentStatus().flutterPayload)
      case "retryDataProtection":
        result(self.excludeDangguiDataFromSystemBackups().flutterPayload)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    dataProtectionChannel = protectionChannel
    reminderPlatformBridge = ReminderPlatformBridge(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
  }
}
