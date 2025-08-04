import Foundation
import SwiftUI

@available(macOS 13.0, *)
@MainActor
public class WeatherViewModel: ObservableObject {
    public enum AdvisoryStatus: Sendable {
        case fullyClear
        case clearNow(minutesUntilRain: Int, location: String?)
        case rainingNow(minutesUntilLeastRain: Int, rainIntensity: Double, affectedPortion: String?)
        case partialRain(dryWindowStart: Int, dryWindowEnd: Int, maxIntensity: Double)
        case error(String)
        case loading
    }

    @Published public var status: AdvisoryStatus?

    private let weatherService = WeatherService()
    private var timer: Timer?

    public init() {
        fetch()
    }

    public init(previewStatus: AdvisoryStatus?) {
        self.status = previewStatus
    }

    public func fetch() {
        Task { @MainActor in
            self.status = .loading
            do {
                let service = self.weatherService
                let result = try await service.fetchRainTimeline()
                self.status = RainAnalyzer.analyze(
                    summary: result.timeline, routeInfo: result.routeInfo)
            } catch {
                let errorMessage: String
                if let weatherError = error as? WeatherServiceError {
                    errorMessage = weatherError.localizedDescription
                } else {
                    errorMessage = "Failed to fetch weather data."
                }
                print("Error fetching forecast: \(error)")
                self.status = .error(errorMessage)
            }

            timer?.invalidate()
            let interval: TimeInterval
            if case .error(_) = self.status {
                let randomOffset = TimeInterval.random(in: -10...10)
                interval = 20 + randomOffset
            } else {
                let randomOffset = TimeInterval.random(in: -60...60)
                interval = 300 + randomOffset
            }

            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                Task { @MainActor in
                    self.fetch()
                }
            }
        }
    }
}
