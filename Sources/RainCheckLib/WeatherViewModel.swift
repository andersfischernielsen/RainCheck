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
            self.status = nil
            do {
                let service = self.weatherService
                let result = try await service.fetchRainTimeline()
                self.status = RainAnalyzer.analyze(
                    summary: result.timeline, routeInfo: result.routeInfo)
            } catch {
                print("Error fetching forecast: \(error)")
            }
        }

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { _ in
            Task { @MainActor in
                self.fetch()
            }
        }
    }
}
