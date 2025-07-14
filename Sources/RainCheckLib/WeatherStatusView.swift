import SwiftUI

@available(macOS 13.0, *)
struct WeatherStatusView: View {
    let status: WeatherViewModel.AdvisoryStatus

    private var iconName: String {
        switch status {
        case .fullyClear:
            return "sun.max.fill"
        case .clearNow:
            return "cloud.sun.fill"
        case .rainingNow:
            return "cloud.rain.fill"
        case .partialRain:
            return "cloud.sun.rain.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: iconName)
                .foregroundColor(.primary)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 4) {
                switch status {
                case .fullyClear:
                    Text("Clear skies along route")
                        .font(.body)
                    Text("No rain expected for the next 2 hours")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                case .clearNow(let minutesUntilRain, let location):
                    Text("Rain approaching in \(formatTime(minutesUntilRain))")
                        .font(.body)
                    if let location = location {
                        Text("Expected \(location)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                case .rainingNow(let min, let intensity, let affectedPortion):
                    Text("Rain along route")
                        .font(.body)
                    Text(
                        "Lightest rain in \(formatTime(min)) (\(intensity, specifier: "%.1f") mm/h)"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    if let portion = affectedPortion {
                        Text("Rain is \(portion)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                case .partialRain(let dryStart, let dryEnd, let maxIntensity):
                    Text("Dry window opportunity")
                        .font(.body)
                    Text("Clear from \(formatTime(dryStart)) to \(formatTime(dryEnd))")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("Current max: \(maxIntensity, specifier: "%.1f") mm/h")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func formatTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) hour\(hours > 1 ? "s" : "")"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }
}
