// ConnectivityMonitor.swift — NWPathMonitor wrapped as @Observable.
//
// Usage (inject via environment in App.swift):
//   .environment(ConnectivityMonitor.shared)
//
// In views / ViewModels:
//   @Environment(ConnectivityMonitor.self) private var connectivity
//   if connectivity.isConnected { ... }
//
// Design notes:
//   • Uses NWPathMonitor (Network.framework) — more reliable than Reachability.
//   • Reports both connection state AND whether the path is expensive (cellular).
//   • Change notifications are debounced 300ms to avoid toggling on weak signal.
//   • @Observable means SwiftUI views update automatically.

import Network
import Foundation
import Observation

@Observable
final class ConnectivityMonitor {

    // ── Singleton ─────────────────────────────────────────────────────────────
    static let shared = ConnectivityMonitor()

    // ── Published state ───────────────────────────────────────────────────────

    /// True when the device has any usable network path.
    private(set) var isConnected: Bool = true

    /// True when the active path uses cellular (expensive) — useful for
    /// deciding whether to download heavy assets.
    private(set) var isExpensive: Bool = false

    /// True when the active path is constrained (Low Data Mode).
    private(set) var isConstrained: Bool = false

    /// The last time connectivity state changed.
    private(set) var lastChangedAt: Date = Date()

    // ── Internal ──────────────────────────────────────────────────────────────

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.disneytracker.connectivity", qos: .utility)
    private var debounceTask: Task<Void, Never>?

    // ── Init / lifecycle ──────────────────────────────────────────────────────

    private init() {
        self.monitor = NWPathMonitor()
        start()
    }

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
        debounceTask?.cancel()
    }

    // ── Path update ───────────────────────────────────────────────────────────

    private func handlePathUpdate(_ path: NWPath) {
        // Debounce: don't thrash on quick toggling at park entry gates
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                let wasConnected = self.isConnected
                self.isConnected   = path.status == .satisfied
                self.isExpensive   = path.isExpensive
                self.isConstrained = path.isConstrained

                if self.isConnected != wasConnected {
                    self.lastChangedAt = Date()
                }
            }
        }
    }
}

// MARK: - Convenience helpers used by WaitTimeViewModel

extension ConnectivityMonitor {
    /// True when connected and not in Low Data Mode.
    var shouldFetchFreshData: Bool {
        isConnected && !isConstrained
    }

    /// Human-readable banner copy for the offline state.
    var offlineBannerText: String {
        if !isConnected {
            return "No connection — showing cached wait times"
        }
        if isConstrained {
            return "Low Data Mode — cached wait times"
        }
        return ""
    }
}
