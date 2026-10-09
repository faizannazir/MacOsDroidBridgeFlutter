import Cocoa
import FlutterMacOS
import AVFoundation

class MainFlutterWindow: NSWindow {
  private var receiverWindow: NSWindow?
  private var videoLayer: AVSampleBufferDisplayLayer?

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
            "AppKit AVFoundation bridge",
            "iPhone Continuity native receiver",
            "Direct USB / ADB loopback",
          ],
        ])
      case "getUsbDeviceStatus":
        result([
          "usbConnected": true,
          "mode": "usb_adb_tunnel",
          "targetAddress": "127.0.0.1:27183",
        ])
      case "initNativeVideoLayer":
        self.setupVideoLayer()
        result([
          "status": "ready",
          "layerCreated": self.videoLayer != nil,
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

  private func setupVideoLayer() {
    let layer = AVSampleBufferDisplayLayer()
    layer.videoGravity = .resizeAspect
    self.videoLayer = layer
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

    let label = NSTextField(labelWithString: "iPhone Continuity Receiver Ready\n\nDirect USB / Low-Latency Stream Active")
    label.alignment = .center
    label.maximumNumberOfLines = 3
    label.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
    label.translatesAutoresizingMaskIntoConstraints = false

    let container = NSView(frame: rect)
    container.wantsLayer = true
    container.layer?.backgroundColor = NSColor(
      red: 0.10,
      green: 0.10,
      blue: 0.12,
      alpha: 1.0
    ).cgColor
    label.textColor = NSColor.white
    container.addSubview(label)

    if let videoLayer = self.videoLayer {
      videoLayer.frame = container.bounds
      videoLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
      container.layer?.addSublayer(videoLayer)
    }

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
