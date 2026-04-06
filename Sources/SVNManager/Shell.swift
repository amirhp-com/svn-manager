import Foundation

enum Shell {
    /// Run a command, return (exitCode, stdout+stderr combined).
    /// PATH used when launched from a .app bundle, where Finder strips the
    /// shell PATH and Homebrew binaries (svn, git) wouldn't otherwise be found.
    private static let extendedPath =
        "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin"

    @discardableResult
    static func run(_ launchPath: String, _ args: [String], cwd: String? = nil) -> (Int32, String) {
        let p = Process()
        p.launchPath = "/usr/bin/env"
        p.arguments = [launchPath] + args
        if let cwd { p.currentDirectoryURL = URL(fileURLWithPath: cwd) }

        var env = ProcessInfo.processInfo.environment
        let inherited = env["PATH"] ?? ""
        env["PATH"] = inherited.isEmpty ? extendedPath : "\(extendedPath):\(inherited)"
        if env["HOME"] == nil { env["HOME"] = NSHomeDirectory() }
        p.environment = env

        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch {
            return (-1, "Failed to launch \(launchPath): \(error.localizedDescription)")
        }
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (p.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }

    static func svn(_ args: [String], cwd: String? = nil, auth: AuthProfile? = nil) -> (Int32, String) {
        var full = args
        if let a = auth {
            full.insert(contentsOf: [
                "--username", a.username,
                "--password", a.password,
                "--non-interactive",
                "--no-auth-cache",
                "--trust-server-cert-failures=unknown-ca,cn-mismatch,expired,not-yet-valid,other"
            ], at: 0)
        }
        return run("svn", full, cwd: cwd)
    }

    static func git(_ args: [String], cwd: String? = nil) -> (Int32, String) {
        return run("git", args, cwd: cwd)
    }

    static func isDirectory(_ path: String) -> Bool {
        var b: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &b) && b.boolValue
    }
}
