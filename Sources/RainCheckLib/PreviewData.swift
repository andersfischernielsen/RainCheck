import SwiftUI

@available(macOS 13.0, *)
extension WeatherViewModel.AdvisoryStatus {
    static let previewStates: [WeatherViewModel.AdvisoryStatus] = [
        .fullyClear,
        .clearNow(minutesUntilRain: 15, location: "near downtown"),
        .clearNow(minutesUntilRain: 45, location: "along highway"),
        .clearNow(minutesUntilRain: 90, location: "at destination"),
        .rainingNow(
            minutesUntilLeastRain: 10, rainIntensity: 2.5, affectedPortion: "light throughout"),
        .rainingNow(
            minutesUntilLeastRain: 25, rainIntensity: 5.2, affectedPortion: "heavy at start"),
        .rainingNow(minutesUntilLeastRain: 60, rainIntensity: 1.8, affectedPortion: "scattered"),
        .partialRain(dryWindowStart: 5, dryWindowEnd: 25, maxIntensity: 3.1),
        .partialRain(dryWindowStart: 20, dryWindowEnd: 80, maxIntensity: 4.7),
        .partialRain(dryWindowStart: 45, dryWindowEnd: 120, maxIntensity: 2.3),
    ]
}

@available(macOS 13.0, *)
extension WeatherViewModel {
    static func preview(with status: AdvisoryStatus?) -> WeatherViewModel {
        return WeatherViewModel(previewStatus: status)
    }

    static var previewLoading: WeatherViewModel {
        preview(with: nil)
    }

    static var previewFullyClear: WeatherViewModel {
        preview(with: .fullyClear)
    }

    static var previewClearNowSoon: WeatherViewModel {
        preview(with: .clearNow(minutesUntilRain: 15, location: "near downtown"))
    }

    static var previewClearNowLater: WeatherViewModel {
        preview(with: .clearNow(minutesUntilRain: 90, location: "at destination"))
    }

    static var previewRainingLight: WeatherViewModel {
        preview(
            with: .rainingNow(
                minutesUntilLeastRain: 10, rainIntensity: 2.5, affectedPortion: "light throughout"))
    }

    static var previewRainingHeavy: WeatherViewModel {
        preview(
            with: .rainingNow(
                minutesUntilLeastRain: 25, rainIntensity: 5.2, affectedPortion: "heavy at start"))
    }

    static var previewPartialRainShort: WeatherViewModel {
        preview(with: .partialRain(dryWindowStart: 5, dryWindowEnd: 25, maxIntensity: 3.1))
    }

    static var previewPartialRainLong: WeatherViewModel {
        preview(with: .partialRain(dryWindowStart: 20, dryWindowEnd: 80, maxIntensity: 4.7))
    }
}

@available(macOS 13.0, *)
struct PreviewSettings {

    static func setupMockRoute() {}
}
