import Foundation
import AppKit
import SQLite3
import Darwin

enum CycleError: Error { case indexUnavailable, queryFailed, emptyIndex, appMissing }

func recentChats() throws -> [String] {
    var connection: OpaquePointer?
    let path = NSHomeDirectory() + "/.codex/state_5.sqlite"
    guard sqlite3_open_v2(path, &connection, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
          let db = connection else {
        if connection != nil { sqlite3_close(connection) }
        throw CycleError.indexUnavailable
    }
    defer { sqlite3_close(db) }
    sqlite3_busy_timeout(db, 1000)
    let sql = """
    SELECT id FROM threads
    WHERE archived=0 AND preview<>'' AND source='vscode'
      AND COALESCE(thread_source,'user') IN ('user','chatgpt_handoff','agent_created_thread')
      AND attached_thread_parent_id IS NULL
    ORDER BY CASE WHEN recency_at_ms>0 THEN recency_at_ms ELSE updated_at_ms END DESC,id DESC
    LIMIT 5
    """
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
        throw CycleError.queryFailed
    }
    defer { sqlite3_finalize(statement) }
    var ids: [String] = []
    var result = sqlite3_step(statement)
    while result == SQLITE_ROW {
        if let text = sqlite3_column_text(statement, 0) { ids.append(String(cString: text)) }
        result = sqlite3_step(statement)
    }
    guard result == SQLITE_DONE else { throw CycleError.queryFailed }
    return ids
}

do {
    let root = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/CodexRemoteCycle")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let lock = open(root.appendingPathComponent("cycle.lock").path, O_CREAT | O_RDWR, 0o600)
    guard lock >= 0, flock(lock, LOCK_EX | LOCK_NB) == 0 else { exit(0) }
    defer { close(lock) }
    let file = root.appendingPathComponent("state.json")
    let previous = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(CycleState.self, from: $0) }
    let backwards = Bundle.main.bundleIdentifier?.hasSuffix("previous") == true
        || CommandLine.arguments.contains("--previous")
    guard let state = nextState(recent: try recentChats(), previous: previous, backwards: backwards) else {
        throw CycleError.emptyIndex
    }
    if CommandLine.arguments.contains("--dry-run") {
        print("count=\(state.ids.count) direction=\(backwards ? "previous" : "next") target=\(state.current)")
        exit(0)
    }
    guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") else {
        throw CycleError.appMissing
    }
    let config = NSWorkspace.OpenConfiguration()
    config.activates = true
    let url = URL(string: "codex://threads/\(state.current)")!
    NSWorkspace.shared.open([url], withApplicationAt: app, configuration: config) { _, error in
        guard error == nil else { fputs("Codex did not accept the open request.\n", stderr); exit(4) }
        do { try JSONEncoder().encode(state).write(to: file, options: .atomic) }
        catch { fputs("Could not save cycle position.\n", stderr); exit(5) }
        exit(0)
    }
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 10))
    fputs("Codex open request timed out.\n", stderr)
    exit(6)
} catch {
    fputs("CodexRemoteCycle: \(error).\n", stderr)
    exit(1)
}
