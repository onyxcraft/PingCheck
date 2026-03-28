import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: PingViewModel

    var body: some View {
        ScrollView {
            TabView {
                DashboardView(viewModel: viewModel)
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                    }

                LatencyGraphView(viewModel: viewModel)
                    .tabItem {
                        Label("Graph", systemImage: "chart.xyaxis.line")
                    }

                TracerouteView(viewModel: viewModel)
                    .tabItem {
                        Label("Traceroute", systemImage: "point.3.connected.trianglepath.dotted")
                    }

                HistoryView(viewModel: viewModel)
                    .tabItem {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }

                SettingsView(viewModel: viewModel)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
}

struct DashboardView: View {
    @ObservedObject var viewModel: PingViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("PingCheck")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)

            ZStack {
                Circle()
                    .fill(colorForStatus(viewModel.latencyColor).opacity(0.2))
                    .frame(width: 120, height: 120)

                VStack(spacing: 4) {
                    Text(viewModel.displayLatency)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(colorForStatus(viewModel.latencyColor))

                    Text("ms")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()

            VStack(spacing: 8) {
                HStack {
                    Text("Packet Loss:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", viewModel.packetLoss))
                        .fontWeight(.semibold)
                }

                Divider()

                ForEach(viewModel.settingsManager.targets.filter { $0.isEnabled }) { target in
                    if let result = viewModel.currentResults[target.host] {
                        HStack {
                            Circle()
                                .fill(colorForStatus(result.colorStatus))
                                .frame(width: 8, height: 8)

                            Text(target.name)
                                .font(.caption)

                            Spacer()

                            Text(result.displayLatency)
                                .font(.caption.monospacedDigit())
                                .foregroundColor(colorForStatus(result.colorStatus))
                        }
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            HStack {
                Button(action: {
                    if viewModel.isRunning {
                        viewModel.stopPinging()
                    } else {
                        viewModel.startPinging()
                    }
                }) {
                    HStack {
                        Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                        Text(viewModel.isRunning ? "Stop" : "Start")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("Quit")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            if !viewModel.isRunning {
                viewModel.startPinging()
            }
        }
        .onChange(of: viewModel.averageLatency) { _ in
            NotificationCenter.default.post(name: NSNotification.Name("UpdateMenuBar"), object: nil)
        }
    }

    private func colorForStatus(_ status: ColorStatus) -> Color {
        switch status {
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        }
    }
}
