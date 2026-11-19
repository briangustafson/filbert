import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Menu commands handled in Dart (`menuChannel` in lib/app/app.dart).
  static var menuChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // m3-design §3.2: opens at 1200 × 800, centred; no smaller than 800 × 600.
    self.contentMinSize = NSSize(width: 800, height: 600)
    self.setContentSize(NSSize(width: 1200, height: 800))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)
    MainFlutterWindow.menuChannel = FlutterMethodChannel(
      name: "filbert/menu",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    // Show in Finder after Save to file… (m3-design §3.5).
    let finder = FlutterMethodChannel(
      name: "filbert/finder",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    finder.setMethodCallHandler { call, result in
      guard call.method == "reveal", let path = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
      result(nil)
    }

    super.awakeFromNib()
  }
}
