import Foundation

enum Shell {
    /// Run a command, return (exitCode, stdout+stderr combined).
    @discardableResult
    static func run(_ launchPath: String, _ args: [String], cwd: String? = nil) -> (Int32, String) {
        let p = Process()
        // Use /usr/bin/env so we honor PATH for `svn`, `git`.
        p.launchPath = "/usr/bin/env"
        p.arguments = [launchPath] + args
        if let cwd { p.currentDirectoryURL = URL(fileURLWithPath: cwd) }
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
