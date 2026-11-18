import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // m3-design §3.2: opens at 1200 × 800, centred; no smaller than 800 × 600.
    self.contentMinSize = NSSize(width: 800, height: 600)
    self.setContentSize(NSSize(width: 1200, height: 800))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
