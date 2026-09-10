import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let updateChannel = FlutterMethodChannel(
      name: "post_killer/update",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    updateChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "install",
            let arguments = call.arguments as? [String: Any],
            let filePath = arguments["filePath"] as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        try self?.installUpdate(dmgPath: filePath)
        result(nil)
      } catch {
        result(FlutterError(code: "update_failed", message: error.localizedDescription, details: nil))
      }
    }

    super.awakeFromNib()
  }

  private func installUpdate(dmgPath: String) throws {
    guard FileManager.default.fileExists(atPath: dmgPath) else {
      throw NSError(domain: "PostKiller", code: 1, userInfo: [NSLocalizedDescriptionKey: "Update file is missing."])
    }
    let scriptURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("post-killer-updater-\(UUID().uuidString).sh")
    let appPath = Bundle.main.bundlePath
    let script = """
    #!/bin/sh
    set -eu
    sleep 1
    dmg=\"$1\"
    target=\"$2\"
    mount=\"$(mktemp -d)\"
    cleanup() { hdiutil detach \"$mount\" -quiet 2>/dev/null || true; rmdir \"$mount\" 2>/dev/null || true; rm -f \"$dmg\" \"$0\"; }
    trap cleanup EXIT
    hdiutil attach \"$dmg\" -nobrowse -readonly -mountpoint \"$mount\" -quiet
    source=\"$(find \"$mount\" -maxdepth 1 -type d -name '*.app' -print -quit)\"
    test -n \"$source\"
    staging=\"${target}.updating\"
    rm -rf \"$staging\"
    ditto \"$source\" \"$staging\"
    rm -rf \"$target\"
    mv \"$staging\" \"$target\"
    open \"$target\"
    """
    try script.write(to: scriptURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = [scriptURL.path, dmgPath, appPath]
    try process.run()
    NSApp.terminate(nil)
  }
}
