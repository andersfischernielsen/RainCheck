import CoreLocation
import Foundation

@available(macOS 13.0, *)
struct RainAnalyzer {
    struct RouteWeatherInfo {
        let routePoints: [CLLocationCoordinate2D]
        let weatherData: [[(Date, Double)]]
        let startLocation: String
        let endLocation: String
    }

    static func analyze(summary: [(Date, Double)], routeInfo: RouteWeatherInfo? = nil)
        -> WeatherViewModel.AdvisoryStatus
    {
        let now = Date()
        let currentRain = summary.first?.1 ?? 0
        let isRainingNow = currentRain > 0

        if !isRainingNow {
            if let (start, intensity) = summary.first(where: { $0.1 > 0 }) {
                let delta = Int(start.timeIntervalSince(now) / 60)

                var location: String? = nil
                if let routeInfo = routeInfo {
                    location = determineRainLocation(
                        at: start, routeInfo: routeInfo, intensity: intensity)
                }

                return .clearNow(minutesUntilRain: delta, location: location)
            } else {
                return .fullyClear
            }
        } else {
            let dryPeriods = findDryWindows(in: summary)
            if let firstDryWindow = dryPeriods.first {
                let startMinutes = Int(firstDryWindow.start.timeIntervalSince(now) / 60)
                let endMinutes = Int(firstDryWindow.end.timeIntervalSince(now) / 60)
                let maxIntensity =
                    summary.filter { $0.0 >= now && $0.0 <= firstDryWindow.start }.max(by: {
                        $0.1 < $1.1
                    })?.1 ?? currentRain

                return .partialRain(
                    dryWindowStart: startMinutes, dryWindowEnd: endMinutes,
                    maxIntensity: maxIntensity)
            } else {
                let driest = summary.min { $0.1 < $1.1 }!
                let delta = Int(driest.0.timeIntervalSince(now) / 60)

                var affectedPortion: String? = nil
                if let routeInfo = routeInfo {
                    affectedPortion = analyzeRouteRainDistribution(routeInfo: routeInfo)
                }

                return .rainingNow(
                    minutesUntilLeastRain: delta, rainIntensity: driest.1,
                    affectedPortion: affectedPortion)
            }
        }
    }

    private static func findDryWindows(in summary: [(Date, Double)]) -> [(start: Date, end: Date)] {
        var dryWindows: [(start: Date, end: Date)] = []
        var currentDryStart: Date? = nil

        for (date, precipitation) in summary {
            if precipitation <= 0.1 {
                if currentDryStart == nil {
                    currentDryStart = date
                }
            } else {
                if let start = currentDryStart {
                    dryWindows.append((start: start, end: date))
                    currentDryStart = nil
                }
            }
        }

        if let start = currentDryStart, let lastEntry = summary.last {
            dryWindows.append((start: start, end: lastEntry.0))
        }

        return dryWindows.filter {
            $0.end.timeIntervalSince($0.start) >= 15 * 60
        }
    }

    private static func determineRainLocation(
        at time: Date, routeInfo: RouteWeatherInfo, intensity: Double
    ) -> String? {
        guard !routeInfo.weatherData.isEmpty else { return nil }

        let timeIndex = routeInfo.weatherData[0].firstIndex {
            abs($0.0.timeIntervalSince(time)) < 30 * 60
        }
        guard let index = timeIndex else { return nil }

        var maxRainIndex = 0
        var maxRain = 0.0

        for (pointIndex, weatherData) in routeInfo.weatherData.enumerated() {
            if index < weatherData.count {
                let rain = weatherData[index].1
                if rain > maxRain {
                    maxRain = rain
                    maxRainIndex = pointIndex
                }
            }
        }

        let totalPoints = routeInfo.routePoints.count
        let position = Double(maxRainIndex) / Double(totalPoints - 1)

        if position < 0.3 {
            return "near \(routeInfo.startLocation)"
        } else if position > 0.7 {
            return "near \(routeInfo.endLocation)"
        } else {
            return "mid-route"
        }
    }

    private static func analyzeRouteRainDistribution(routeInfo: RouteWeatherInfo) -> String? {
        guard !routeInfo.weatherData.isEmpty else { return nil }

        var rainIntensities: [Double] = []
        for weatherData in routeInfo.weatherData {
            rainIntensities.append(weatherData.first?.1 ?? 0.0)
        }

        let totalPoints = rainIntensities.count
        let startThird = rainIntensities.prefix(totalPoints / 3)
        let middleThird = rainIntensities.dropFirst(totalPoints / 3).prefix(totalPoints / 3)
        let endThird = rainIntensities.suffix(totalPoints / 3)

        let startAvg = startThird.reduce(0, +) / Double(startThird.count)
        let middleAvg = middleThird.reduce(0, +) / Double(middleThird.count)
        let endAvg = endThird.reduce(0, +) / Double(endThird.count)

        let maxAvg = max(startAvg, middleAvg, endAvg)

        if startAvg == maxAvg && startAvg > 0.2 {
            return "heaviest near start"
        } else if endAvg == maxAvg && endAvg > 0.2 {
            return "heaviest near destination"
        } else if middleAvg == maxAvg && middleAvg > 0.2 {
            return "heaviest mid-route"
        }

        return "throughout route"
    }
}
