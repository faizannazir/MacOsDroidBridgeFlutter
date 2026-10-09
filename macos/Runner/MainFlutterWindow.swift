import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var receiverWindow: NSWindow?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let channel = FlutterMethodChannel(
      name: "droid_bridge/platform",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getPlatformSnapshot":
        result([
          "platformName": "macOS Desktop Continuity",
          "platformRole": "desktop",
          "deviceName": Host.current().localizedName ?? "MacBook Pro",
          "isNativeChannelAvailable": true,
          "capabilities": [
            "Native window host",
            "AppKit bridge",
            "iPhone Continuity receiver",
          ],
        ])
      case "getMirroringStatus":
        result([
          "supported": true,
          "mode": "macos_receiver",
          "isActive": self.receiverWindow != nil,
          "permissionGranted": true,
          "message": self.receiverWindow == nil
            ? "Open the native receiver window on macOS to prepare for iPhone Continuity."
            : "Continuity receiver window is active.",
        ])
      case "openMirrorReceiverWindow":
        self.openReceiverWindow()
        result([
          "supported": true,
          "mode": "macos_receiver",
          "isActive": true,
          "permissionGranted": true,
          "message": "Native receiver window opened on macOS.",
        ])
      case "stopMirroringSession":
        self.receiverWindow?.close()
        self.receiverWindow = nil
        result([
          "supported": true,
          "mode": "macos_receiver",
          "isActive": false,
          "permissionGranted": true,
          "message": "Continuity receiver window closed.",
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  private func openReceiverWindow() {
    if let receiverWindow {
      receiverWindow.makeKeyAndOrderFront(nil)
      return
    }

    let rect = NSRect(x: 0, y: 0, width: 720, height: 440)
    let window = NSWindow(
      contentRect: rect,
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.center()
    window.title = "iPhone Mirroring Receiver"

    let label = NSTextField(labelWithString: "iPhone Continuity Receiver Ready\n\nConnected stream will render inside this AppKit window.")
    label.alignment = .center
    label.maximumNumberOfLines = 3
    label.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
    label.translatesAutoresizingMaskIntoConstraints = false

    let container = NSView(frame: rect)
    container.wantsLayer = true
    container.layer?.backgroundColor = NSColor(
      red: 0.12,
      green: 0.12,
      blue: 0.14,
      alpha: 1.0
    ).cgColor
    label.textColor = NSColor.white
    container.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      label.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 24),
      label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24),
    ])

    window.contentView = container
    window.makeKeyAndOrderFront(nil)
    receiverWindow = window
  }
}
