import Flutter
import UIKit
import GoogleMaps
import FirebaseCore
import FirebaseMessaging
import KlaviyoSwift
import klaviyo_flutter_sdk

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Same channel MainActivity uses on Android: hands a tapped Klaviyo push to
  // Dart so the open also reaches product analytics with its campaign name.
  private static let pushChannelName = "com.starregistration.planetarium/klaviyo_push"
  private var pushChannel: FlutterMethodChannel?
  private var pendingPush: [String: String]?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyCc4LPIozIoEHVAMFz5uyQ_LrT1nAlbmfc")

    // Configure Firebase
    FirebaseApp.configure()

    // The links on Klaviyo pushes are web links, to the shop or to any other
    // website. Without a handler
    // of its own, Klaviyo's SDK treats an https link as a link into this app
    // and passes it to Flutter, which has no route for it. Open every push
    // link in the browser instead.
    KlaviyoSDK().registerDeepLinkHandler { url in
      UIApplication.shared.open(url)
    }

    // Set up push notification delegate for iOS 10+
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    // Register for remote notifications
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Make sure this class is still the notification-centre delegate once the
    // plugins have registered. Klaviyo's official SDK leaves it alone, but the
    // package used before it took the delegate for itself and forwarded to no
    // one, which silently cut Firebase Messaging off from notification taps.
    UNUserNotificationCenter.current().delegate = self

    let channel = FlutterMethodChannel(
      name: AppDelegate.pushChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "takePendingPush" {
        result(self?.pendingPush)
        self?.pendingPush = nil
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    pushChannel = channel
  }

  // A notification was tapped.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    guard let payload = AppDelegate.klaviyoPushPayload(response) else {
      // Not Klaviyo's: let the plugins see it (Firebase Messaging reports it
      // to Dart).
      super.userNotificationCenter(
        center, didReceive: response, withCompletionHandler: completionHandler)
      return
    }

    // Kept until Dart collects it, so a tap that launches the app is not lost.
    pendingPush = payload
    pushChannel?.invokeMethod("onPushOpened", arguments: nil)

    // Reports "Opened Push" to Klaviyo and opens the push's link or runs its
    // action button.
    KlaviyoFlutterSdkPlugin.shared.handleNotificationResponse(response)
    completionHandler()
  }

  // A notification arrived while the app is in the foreground.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Keep showing every notification as a banner, as klaviyo_flutter did
    // while it was the delegate.
    let banner: UNNotificationPresentationOptions = [.list, .banner]
    if AppDelegate.isKlaviyoPush(notification.request.content.userInfo) {
      completionHandler(banner)
    } else {
      // Let the plugins see it (Firebase Messaging reports it to Dart).
      super.userNotificationCenter(center, willPresent: notification) { options in
        completionHandler(options.union(banner))
      }
    }
  }

  private static func isKlaviyoPush(_ userInfo: [AnyHashable: Any]) -> Bool {
    guard let body = userInfo["body"] as? [String: Any] else { return false }
    return body["_k"] != nil
  }

  /// The parts of a tapped Klaviyo push that analytics needs: Klaviyo's
  /// tracking block (`_k`, as a JSON string like on Android) and the title.
  private static func klaviyoPushPayload(_ response: UNNotificationResponse) -> [String: String]? {
    let content = response.notification.request.content
    guard let body = content.userInfo["body"] as? [String: Any],
      let tracking = body["_k"]
    else { return nil }

    var payload: [String: String] = ["_k": "{}"]
    if let json = tracking as? String {
      payload["_k"] = json
    } else if JSONSerialization.isValidJSONObject(tracking),
      let data = try? JSONSerialization.data(withJSONObject: tracking),
      let json = String(data: data, encoding: .utf8)
    {
      payload["_k"] = json
    }
    if !content.title.isEmpty { payload["title"] = content.title }
    return payload
  }

  // Handle device token registration
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Pass token to Firebase Messaging
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
}
