import Foundation
import Combine

@MainActor
class PingViewModel: ObservableObject {
    @Published var currentResults: [String: PingResult] = [:]
    @Published var averageLatency: Double?
    @Published var packetLoss: Double = 0.0
    @Published var isRunning: Bool = false
    @Published var selectedTimeRange: TimeRange = .oneHour
    @Published var tracerouteHops: [TracerouteHop] = []
    @Published var isTracerouteRunning: Bool = false

    let pingService = PingService()
    let historyService = HistoryService()
    let tracerouteService = TracerouteService()
    var alertManager = AlertManager()
    var settingsManager = SettingsManager()

    private var cancellables = Set<AnyCancellable>()
    private var pingResultCount: [String: (success: Int, total: Int)] = [:]

    init() {
        settingsManager.$targets
            .sink { [weak self] _ in
                self?.restartPinging()
            }
            .store(in: &cancellables)
    }

    func startPinging() {
        guard !isRunning else { return }
        isRunning = true

        for target in settingsManager.targets where target.isEnabled {
            pingService.startContinuousPing(host: target.host, interval: settingsManager.pingInterval) { [weak self] result in
                Task { @MainActor in
                    self?.handlePingResult(result)
                }
            }
        }
    }

    func stopPinging() {
        guard isRunning else { return }
        isRunning = false
        pingService.stopAllPings()
    }

    private func restartPinging() {
        if isRunning {
            stopPinging()
            startPinging()
        }
    }

    private func handlePingResult(_ result: PingResult) {
        currentResults[result.targetHost] = result

        if result.success {
            historyService.addResult(result)
        }

        updatePacketLoss(for: result)
        updateAverageLatency()

        alertManager.checkLatency(result)
    }

    private func updatePacketLoss(for result: PingResult) {
        var stats = pingResultCount[result.targetHost] ?? (success: 0, total: 0)
        stats.total += 1
        if result.success {
            stats.success += 1
        }
        pingResultCount[result.targetHost] = stats

        let allSuccess = pingResultCount.values.reduce(0) { $0 + $1.success }
        let allTotal = pingResultCount.values.reduce(0) { $0 + $1.total }

        if allTotal > 0 {
            packetLoss = Double(allTotal - allSuccess) / Double(allTotal) * 100.0
        }
    }

    private func updateAverageLatency() {
        let latencies = currentResults.values.compactMap { $0.latency }
        if !latencies.isEmpty {
            averageLatency = latencies.reduce(0, +) / Double(latencies.count)
        } else {
            averageLatency = nil
        }
    }

    func getHistoryForGraph() -> [LatencyHistory] {
        return historyService.getHistory(for: selectedTimeRange)
    }

    func exportHistory(to url: URL) throws {
        try historyService.saveCSV(to: url)
    }

    func performTraceroute(to host: String) {
        guard !isTracerouteRunning else { return }

        Task {
            isTracerouteRunning = true
            tracerouteHops = []

            let hops = await tracerouteService.performTraceroute(to: host)
            tracerouteHops = hops

            isTracerouteRunning = false
        }
    }

    func clearHistory() {
        historyService.clearHistory()
    }

    var displayLatency: String {
        guard let avg = averageLatency else { return "—" }
        return String(format: "%.0f", avg)
    }

    var latencyColor: ColorStatus {
        guard let avg = averageLatency else { return .red }
        if avg < 50 { return .green }
        if avg < 150 { return .yellow }
        return .red
    }
}
