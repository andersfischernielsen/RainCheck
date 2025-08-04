import SwiftUI

@available(macOS 13.0, *)
public struct MenuBarLabel: View {
    let status: WeatherViewModel.AdvisoryStatus?

    public init(status: WeatherViewModel.AdvisoryStatus?) {
        self.status = status
    }

    public var body: some View {
        HStack(spacing: 2) {
            Image(systemName: iconName)
            if let text = displayText {
                Text(text)
                    .font(.system(size: 12, weight: .medium))
            }
        }
    }

    private var iconName: String {
        guard let status = status else {
            return "questionmark"
        }

        switch status {
        case .fullyClear:
            return "sun.max"
        case .clearNow(_, _):
            return "cloud.rain"
        case .rainingNow(_, _, _):
            return "cloud.sun.rain"
        case .partialRain(_, _, _):
            return "cloud.sun.rain.fill"
        case .error(_):
            return "xmark"
        case .loading:
            return "questionmark"
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h\(remainingMinutes)m"
            }
        }
    }

    private var displayText: String? {
        guard let status = status else {
            return nil
        }

        switch status {
        case .fullyClear:
            return nil
        case .clearNow(let minutesUntilRain, _):
            return formatMinutes(minutesUntilRain)
        case .rainingNow(let minutesUntilLeastRain, _, _):
            return formatMinutes(minutesUntilLeastRain)
        case .partialRain(let dryStart, _, _):
            return formatMinutes(dryStart)
        case .error(_):
            return nil
        case .loading:
            return nil
        }
    }
}
