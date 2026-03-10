import Foundation

enum AttachmentResolver {
  static func resolve(_ path: String) -> (resolved: String, missing: Bool) {
    guard !path.isEmpty else { return ("", true) }
    let expanded = (path as NSString).expandingTildeInPath
    var isDir: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir)
    return (expanded, !(exists && !isDir.boolValue))
  }

  /// Convert .caf audio to .m4a (Whisper-compatible) if needed.
  /// Returns the converted path, or the original if conversion isn't needed/fails.
  static func convertAudioIfNeeded(_ resolvedPath: String) -> (path: String, mimeType: String?) {
    guard resolvedPath.lowercased().hasSuffix(".caf") else { return (resolvedPath, nil) }
    let cafURL = URL(fileURLWithPath: resolvedPath)
    let m4aURL = cafURL.deletingPathExtension().appendingPathExtension("m4a")
    let m4aPath = m4aURL.path

    // If already converted, reuse
    if FileManager.default.fileExists(atPath: m4aPath) {
      return (m4aPath, "audio/mp4")
    }

    // Check source exists
    guard FileManager.default.fileExists(atPath: resolvedPath) else {
      return (resolvedPath, nil)
    }

    // Convert using ffmpeg (handles Opus-in-CAF from iMessage)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
    process.arguments = [
      "-i", resolvedPath,
      "-c:a", "aac",        // AAC codec
      "-b:a", "128k",       // 128kbps bitrate
      "-y",                  // Overwrite without prompting
      m4aPath
    ]
    do {
      try process.run()
      process.waitUntilExit()
      if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: m4aPath) {
        return (m4aPath, "audio/mp4")
      }
    } catch {
      // Conversion failed, return original
    }
    return (resolvedPath, nil)
  }

  /// Convert GIF to static PNG (first frame) for model compatibility.
  static func convertGifIfNeeded(_ resolvedPath: String) -> (path: String, mimeType: String?) {
    guard resolvedPath.lowercased().hasSuffix(".gif") else { return (resolvedPath, nil) }
    let gifURL = URL(fileURLWithPath: resolvedPath)
    let pngURL = gifURL.deletingPathExtension().appendingPathExtension("png")
    let pngPath = pngURL.path

    if FileManager.default.fileExists(atPath: pngPath) {
      return (pngPath, "image/png")
    }

    guard FileManager.default.fileExists(atPath: resolvedPath) else {
      return (resolvedPath, nil)
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
    process.arguments = [
      "-i", resolvedPath,
      "-vframes", "1",       // First frame only
      "-y",
      pngPath
    ]
    do {
      try process.run()
      process.waitUntilExit()
      if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: pngPath) {
        return (pngPath, "image/png")
      }
    } catch {
      // Conversion failed, return original
    }
    return (resolvedPath, nil)
  }

  static func displayName(filename: String, transferName: String) -> String {
    if !transferName.isEmpty { return transferName }
    if !filename.isEmpty { return filename }
    return "(unknown)"
  }
}
