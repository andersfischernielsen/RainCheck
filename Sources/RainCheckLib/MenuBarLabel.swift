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
            if minutesUntilRain < 60 {
                return "\(minutesUntilRain)m"
            } else {
                let hours = minutesUntilRain / 60
                let remainingMinutes = minutesUntilRain % 60
                if remainingMinutes == 0 {
                    return "\(hours)h"
                } else {
                    return "\(hours)h\(remainingMinutes)m"
                }
            }
        case .rainingNow(let minutesUntilLeastRain, _, _):
            if minutesUntilLeastRain < 60 {
                return "\(minutesUntilLeastRain)m"
            } else {
                let hours = minutesUntilLeastRain / 60
                let remainingMinutes = minutesUntilLeastRain % 60
                if remainingMinutes == 0 {
                    return "\(hours)h"
                } else {
                    return "\(hours)h\(remainingMinutes)m"
                }
            }
        case .partialRain(let dryStart, _, _):
            if dryStart < 60 {
                return "\(dryStart)m"
            } else {
                let hours = dryStart / 60
                let remainingMinutes = dryStart % 60
                if remainingMinutes == 0 {
                    return "\(hours)h"
                } else {
                    return "\(hours)h\(remainingMinutes)m"
                }
            }
        }
    }
}
