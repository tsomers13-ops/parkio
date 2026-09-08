//
//  GitProvenance.swift
//  dining-export
//
//  Resolves `sourceCommit` / `sourceDirty` from Git at runtime.
//

import Foundation

enum ExportError: Error, CustomStringConvertible {
    case git(String)
    case io(String)
    case validation([String])

    var description: String {
        switch self {
        case .git(let m):        return "git: \(m)"
        case .io(let m):         return "io: \(m)"
        case .validation(let f): return "validation failed:\n" + f.map { "  - \($0)" }.joined(separator: "\n")
        }
    }
}

enum GitProvenance {

    /// Paths that are intentionally untracked and must not mark an export dirty.
    ///
    /// Narrow by design: a path here is ignored ONLY when Git reports it as
    /// untracked ("??"). If PARKIO_ACTIVE_CONTEXT.md is ever committed, any
    /// later modification to it will correctly mark the export dirty.
    static let intentionallyUntracked: Set<String> = ["PARKIO_ACTIVE_CONTEXT.md"]

    static func git(_ args: [String], in repo: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + args
        process.currentDirectoryURL = repo
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do { try process.run() } catch { throw ExportError.git("could not launch git: \(error)") }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(decoding: errData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ExportError.git("`git \(args.joined(separator: " "))` exited \(process.terminationStatus): \(message)")
        }
        // Trim ONLY trailing newlines: `git status --porcelain` encodes staged
        // vs unstaged state in column 1, so a leading space is significant.
        var text = String(decoding: data, as: UTF8.self)
        while let last = text.last, last.isNewline { text.removeLast() }
        return text
    }

    /// Returns the resolved commit, dirty flag, and the paths that caused dirtiness.
    static func resolve(repo: URL) throws -> (commit: String, dirty: Bool, dirtyPaths: [String]) {
        let commit = try git(["rev-parse", "HEAD"], in: repo)
        let status = try git(["status", "--porcelain"], in: repo)

        var dirtyPaths: [String] = []
        for line in status.split(separator: "\n", omittingEmptySubsequences: true) {
            guard line.count > 3 else { continue }
            let code = String(line.prefix(2))
            let path = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            if code == "??" && intentionallyUntracked.contains(path) { continue }
            dirtyPaths.append("\(code) \(path)")
        }
        return (commit, !dirtyPaths.isEmpty, dirtyPaths.sorted())
    }
}
