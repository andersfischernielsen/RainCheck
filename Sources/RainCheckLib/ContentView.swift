import SwiftUI

@available(macOS 13.0, *)
public struct ContentView: View {
    @EnvironmentObject var viewModel: WeatherViewModel
    @StateObject private var settingsManager = SettingsManager()

    public init() {}

    private let loadingMessages = [
        "Checking weather...",
        "Consulting the clouds...",
        "Reading the sky...",
        "Checking atmospheric conditions...",
        "Interrogating rain drops...",
        "Scanning the horizon...",
        "Calculating precipitation...",
        "Talking to weather satellites...",
        "Tracking cloud movements...",
        "Evaluating evaporation rates...",
        "Forecasting the future...",
        "Detecting drizzle patterns...",
        "Surveying storm systems...",
        "Probing pressure changes...",
    ]

    public var body: some View {
        VStack(alignment: .leading) {
            Group {
                if let status = viewModel.status {
                    WeatherStatusView(status: status)
                } else {
                    HStack {
                        Spacer()
                        ProgressView(loadingMessages.randomElement() ?? "Checking weather...")
                            .progressViewStyle(DefaultProgressViewStyle())
                        Spacer()
                    }
                }
            }
            .frame(minHeight: 64, alignment: .center)

            if let start = Settings.getStartLocation(),
                let end = Settings.getEndLocation(),
                !start.isEmpty && !end.isEmpty
            {
                Divider()

                Text("Route: \(formatLocationName(start)) → \(formatLocationName(end))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }

            Text("Weather data provided by Yr.no and Apple.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .italic()
                .padding(.top, 1)

            Divider()

            HStack {
                Button("Refresh") {
                    viewModel.fetch()
                }

                Spacer()

                Button("Settings") {
                    settingsManager.showSettings()
                }

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .frame(height: 24)

        }
        .padding(12)
        .frame(width: 250)
    }

    private func formatLocationName(_ location: String) -> String {
        return location.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces)
            ?? location
    }
}
