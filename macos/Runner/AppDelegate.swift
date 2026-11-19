import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  /// Settings… in the app menu (m3-design §3.3): Dart opens the screen.
  @IBAction func showSettings(_ sender: Any?) {
    MainFlutterWindow.menuChannel?.invokeMethod("settings", arguments: nil)
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
