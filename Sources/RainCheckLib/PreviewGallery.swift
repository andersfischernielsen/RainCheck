import SwiftUI

@available(macOS 13.0, *)
struct PreviewGallery: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                Text("RainCheck Preview Gallery")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)

                PreviewCard(title: "Loading State") {
                    ContentView()
                        .environmentObject(WeatherViewModel.previewLoading)
                }

                PreviewCard(title: "Fully Clear") {
                    ContentView()
                        .environmentObject(WeatherViewModel.previewFullyClear)
                }

                PreviewCard(title: "Clear Now - Rain Soon (15 min)") {
                    ContentView()
                        .environmentObject(WeatherViewModel.previewClearNowSoon)
                }

                PreviewCard(title: "Clear Now - Rain Later (90 min)") {
                    ContentView()
                        .environmentObject(WeatherViewModel.previewClearNowLater)
                }

                PreviewCard(title: "Raining Now - Light") {
                    ContentView()
                        .environmentObject(WeatherViewModel.previewRainingLight)
                }

                PreviewCard(title: "Raining Now - Heavy") {
                    ContentView()
                        .environmentObject(WeatherViewModel.previewRainingHeavy)
                }

                PreviewCard(title: "Partial Rain - Short Window") {
                    ContentView()
                        .environmentObject(WeatherViewModel.previewPartialRainShort)
                }

                PreviewCard(title: "Partial Rain - Long Window") {
                    ContentView()
                        .environmentObject(WeatherViewModel.previewPartialRainLong)
                }

                Divider()
                    .padding(.vertical)

                Text("Menu Bar Label States")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.bottom, 10)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(
                        Array(WeatherViewModel.AdvisoryStatus.previewStates.enumerated()),
                        id: \.offset
                    ) { index, status in
                        VStack {
                            MenuBarLabel(status: status)
                                .padding(8)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)

                            Text(statusDescription(status))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    VStack {
                        MenuBarLabel(status: nil)
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)

                        Text("Loading")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)
        }
        .frame(width: 800, height: 600)
    }

    private func statusDescription(_ status: WeatherViewModel.AdvisoryStatus) -> String {
        switch status {
        case .fullyClear:
            return "Fully Clear"
        case .clearNow(let minutes, _):
            return "Clear Now\n(\(minutes)m until rain)"
        case .rainingNow(let minutes, let intensity, _):
            return
                "Raining Now\n(\(minutes)m until lighter, \(String(format: "%.1f", intensity))mm/h)"
        case .partialRain(let start, let end, let maxIntensity):
            return
                "Partial Rain\n(dry \(start)m-\(end)m, max \(String(format: "%.1f", maxIntensity))mm/h)"
        }
    }
}

@available(macOS 13.0, *)
struct PreviewCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            content
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

@available(macOS 13.0, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {

            ContentView()
                .environmentObject(WeatherViewModel.previewLoading)
                .previewDisplayName("Loading")

            ContentView()
                .environmentObject(WeatherViewModel.previewFullyClear)
                .previewDisplayName("Fully Clear")

            ContentView()
                .environmentObject(WeatherViewModel.previewClearNowSoon)
                .previewDisplayName("Clear Now - Rain Soon")

            ContentView()
                .environmentObject(WeatherViewModel.previewClearNowLater)
                .previewDisplayName("Clear Now - Rain Later")

            ContentView()
                .environmentObject(WeatherViewModel.previewRainingLight)
                .previewDisplayName("Raining Light")

            ContentView()
                .environmentObject(WeatherViewModel.previewRainingHeavy)
                .previewDisplayName("Raining Heavy")

            ContentView()
                .environmentObject(WeatherViewModel.previewPartialRainShort)
                .previewDisplayName("Partial Rain - Short Window")

            ContentView()
                .environmentObject(WeatherViewModel.previewPartialRainLong)
                .previewDisplayName("Partial Rain - Long Window")
        }
    }
}

@available(macOS 13.0, *)
struct MenuBarLabel_Previews: PreviewProvider {
    static var previews: some View {
        Group {

            ForEach(Array(WeatherViewModel.AdvisoryStatus.previewStates.enumerated()), id: \.offset)
            { index, status in
                MenuBarLabel(status: status)
                    .padding()
                    .previewDisplayName("Status \(index + 1)")
            }

            MenuBarLabel(status: nil)
                .padding()
                .previewDisplayName("Loading")
        }
    }
}

@available(macOS 13.0, *)
struct WeatherStatusView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ForEach(Array(WeatherViewModel.AdvisoryStatus.previewStates.enumerated()), id: \.offset)
            { index, status in
                WeatherStatusView(status: status)
                    .padding()
                    .frame(width: 250)
                    .previewDisplayName("Status \(index + 1)")
            }
        }
    }
}

@available(macOS 13.0, *)
struct PreviewGallery_Previews: PreviewProvider {
    static var previews: some View {
        PreviewGallery()
            .previewDisplayName("Full Preview Gallery")
    }
}
