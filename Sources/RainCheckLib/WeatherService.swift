import CoreLocation
import Foundation
import WeatherKit

struct YrWeatherData: Decodable {
    let properties: Properties

    struct Properties: Decodable {
        let timeseries: [Timeseries]
    }

    struct Timeseries: Decodable {
        let time: String
        let data: TimeseriesData
    }

    struct TimeseriesData: Decodable {
        let instant: Instant
        let next1Hours: NextHours?

        struct Instant: Decodable {
            let details: Details
        }

        struct NextHours: Decodable {
            let details: Details
        }

        struct Details: Decodable {
            let precipitationAmount: Double?

            enum CodingKeys: String, CodingKey {
                case precipitationAmount = "precipitation_amount"
            }
        }
    }
}

struct CombinedWeatherData {
    let time: Date
    let yrPrecipitation: Double?
    let weatherKitPrecipitation: Double?
    let combinedPrecipitation: Double

    init(time: Date, yrPrecipitation: Double?, weatherKitPrecipitation: Double?) {
        self.time = time
        self.yrPrecipitation = yrPrecipitation
        self.weatherKitPrecipitation = weatherKitPrecipitation

        // Weighted combination: Yr.no has 70% weight, WeatherKit has 30% weight
        let yrWeight = 0.7
        let weatherKitWeight = 0.3

        switch (yrPrecipitation, weatherKitPrecipitation) {
        case let (yr?, wk?):
            // Both sources available - use weighted average
            self.combinedPrecipitation = (yr * yrWeight) + (wk * weatherKitWeight)
        case let (yr?, nil):
            // Only Yr.no available
            self.combinedPrecipitation = yr
        case let (nil, wk?):
            // Only WeatherKit available
            self.combinedPrecipitation = wk
        case (nil, nil):
            // No data available
            self.combinedPrecipitation = 0.0
        }
    }
}

class WeatherService: @unchecked Sendable {
    private let session = URLSession.shared
    private let geocoder = CLGeocoder()
    private let weatherService = WeatherKit.WeatherService()

    // Note: WeatherKit requires proper app entitlements and may fail in development.
    // The implementation gracefully falls back to Yr.no data when WeatherKit is unavailable.

    @available(macOS 13.0, iOS 15.0, *)
    func fetchRainTimeline() async throws -> (
        timeline: [(Date, Double)], routeInfo: RainAnalyzer.RouteWeatherInfo
    ) {
        let startLocation = Settings.getStartLocation() ?? "Copenhagen, Denmark"
        let endLocation = Settings.getEndLocation() ?? "Copenhagen, Denmark"

        let startCoordinate = try await geocodeLocation(startLocation)
        let endCoordinate = try await geocodeLocation(endLocation)

        let routeDistance = calculateRouteDistance(from: startCoordinate, to: endCoordinate)
        print("Analyzing route: \(startLocation) → \(endLocation)")
        print("Route distance: \(String(format: "%.1f", routeDistance / 1000))km")

        let routePoints = calculateRoutePoints(from: startCoordinate, to: endCoordinate)
        let deduplicatedPoints = deduplicateCloseCoordinates(routePoints)

        print("Sampling weather at \(deduplicatedPoints.count) points along the route")

        var allCombinedWeatherData: [[CombinedWeatherData]] = []
        for coordinate in deduplicatedPoints {
            let combinedData = await fetchCombinedWeatherForLocation(coordinate)
            allCombinedWeatherData.append(combinedData)
        }

        let combinedTimeline = combineRouteWeatherDataNew(allCombinedWeatherData)

        // Convert to legacy format for compatibility
        let legacyTimeline = combinedTimeline.map { ($0.time, $0.combinedPrecipitation) }

        // Convert to legacy format for route info
        let legacyWeatherData = allCombinedWeatherData.map { combinedData in
            combinedData.map { ($0.time, $0.combinedPrecipitation) }
        }

        let routeInfo = RainAnalyzer.RouteWeatherInfo(
            routePoints: deduplicatedPoints,
            weatherData: legacyWeatherData,
            startLocation: startLocation,
            endLocation: endLocation
        )

        return (timeline: legacyTimeline, routeInfo: routeInfo)
    }

    @available(macOS 12.0, iOS 15.0, *)
    private func fetchWeatherForLocation(_ coordinate: CLLocationCoordinate2D) async throws -> [(
        Date, Double
    )] {
        let urlString =
            "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=\(coordinate.latitude)&lon=\(coordinate.longitude)"
        guard let url = URL(string: urlString) else {
            throw WeatherServiceError.invalidLocation
        }

        var request = URLRequest(url: url)
        request.setValue("RainCheck/1.0 (contact@example.com)", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)
        let decoded = try JSONDecoder().decode(YrWeatherData.self, from: data)

        return decoded.properties.timeseries.compactMap { timeseries in
            guard let time = ISO8601DateFormatter().date(from: timeseries.time) else { return nil }

            let precipitation = timeseries.data.next1Hours?.details.precipitationAmount ?? 0.0

            return (time, precipitation)
        }.prefix(2).map { $0 }
    }

    @available(macOS 13.0, iOS 15.0, *)
    private func fetchCombinedWeatherForLocation(_ coordinate: CLLocationCoordinate2D) async
        -> [CombinedWeatherData]
    {
        async let yrDataTask = fetchYrWeatherForLocation(coordinate)
        async let weatherKitDataTask = fetchWeatherKitData(for: coordinate)

        let yrData = try? await yrDataTask
        let weatherKitData = try? await weatherKitDataTask

        return combineSingleLocationData(yrData: yrData, weatherKitData: weatherKitData)
    }

    @available(macOS 12.0, iOS 15.0, *)
    private func fetchYrWeatherForLocation(_ coordinate: CLLocationCoordinate2D) async throws -> [(
        Date, Double
    )] {
        let urlString =
            "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=\(coordinate.latitude)&lon=\(coordinate.longitude)"
        guard let url = URL(string: urlString) else {
            throw WeatherServiceError.invalidLocation
        }

        var request = URLRequest(url: url)
        request.setValue("RainCheck/1.0 (contact@example.com)", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)
        let decoded = try JSONDecoder().decode(YrWeatherData.self, from: data)

        return decoded.properties.timeseries.compactMap { timeseries in
            guard let time = ISO8601DateFormatter().date(from: timeseries.time) else { return nil }

            let precipitation = timeseries.data.next1Hours?.details.precipitationAmount ?? 0.0

            return (time, precipitation)
        }.prefix(2).map { $0 }
    }

    @available(macOS 13.0, iOS 15.0, *)
    private func fetchWeatherKitData(for coordinate: CLLocationCoordinate2D) async throws -> [(
        Date, Double
    )] {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let forecast = try await weatherService.weather(for: location, including: .hourly)

            let now = Date()
            let twoHoursFromNow = now.addingTimeInterval(2 * 60 * 60)

            return forecast.forecast
                .filter { $0.date >= now && $0.date <= twoHoursFromNow }
                .prefix(2)
                .map { hour in
                    let precipitationAmount = hour.precipitationAmount.value
                    return (hour.date, precipitationAmount)
                }
        } catch {
            // WeatherKit requires proper entitlements and may fail in development
            // Log the error but don't crash - we'll fall back to Yr.no only
            if !error.localizedDescription.contains("xpcConnectionFailed") {
                print("WeatherKit error for coordinate \(coordinate): \(error)")
            }
            throw error
        }
    }

    private func combineSingleLocationData(
        yrData: [(Date, Double)]?, weatherKitData: [(Date, Double)]?
    ) -> [CombinedWeatherData] {
        // Create a timeline that covers the next 2 hours
        let now = Date()
        let timeSlots = (0..<2).map { hour in
            now.addingTimeInterval(TimeInterval(hour * 3600))
        }

        // Log data source availability for debugging
        let hasYr = yrData != nil
        let hasWeatherKit = weatherKitData != nil

        if hasYr && hasWeatherKit {
            // Both sources available - optimal case
        } else if hasYr && !hasWeatherKit {
            // Only Yr.no available - still good coverage
        } else if !hasYr && hasWeatherKit {
            // Only WeatherKit available - less preferred but usable
        } else {
            // No data available - fallback to zero values
            print("Warning: No weather data available from either source")
        }

        return timeSlots.map { time in
            let yrPrecip = yrData?.first { abs($0.0.timeIntervalSince(time)) < 30 * 60 }?.1
            let wkPrecip = weatherKitData?.first { abs($0.0.timeIntervalSince(time)) < 30 * 60 }?.1

            return CombinedWeatherData(
                time: time,
                yrPrecipitation: yrPrecip,
                weatherKitPrecipitation: wkPrecip
            )
        }
    }

    private func combineRouteWeatherDataNew(_ allCombinedData: [[CombinedWeatherData]])
        -> [CombinedWeatherData]
    {
        guard !allCombinedData.isEmpty else { return [] }

        let baseTimeline = allCombinedData[0]
        var combined: [CombinedWeatherData] = []

        for (index, baseEntry) in baseTimeline.enumerated() {
            var maxYrPrecipitation: Double? = baseEntry.yrPrecipitation
            var maxWeatherKitPrecipitation: Double? = baseEntry.weatherKitPrecipitation

            for combinedData in allCombinedData {
                if index < combinedData.count {
                    let entry = combinedData[index]
                    if let yr = entry.yrPrecipitation {
                        maxYrPrecipitation = max(maxYrPrecipitation ?? 0, yr)
                    }
                    if let wk = entry.weatherKitPrecipitation {
                        maxWeatherKitPrecipitation = max(maxWeatherKitPrecipitation ?? 0, wk)
                    }
                }
            }

            let combinedEntry = CombinedWeatherData(
                time: baseEntry.time,
                yrPrecipitation: maxYrPrecipitation,
                weatherKitPrecipitation: maxWeatherKitPrecipitation
            )

            combined.append(combinedEntry)
        }

        // Log the combined results for debugging
        let rainPeriods = combined.filter { $0.combinedPrecipitation > 0 }

        // Calculate data source statistics
        let totalDataPoints = combined.count
        let yrOnlyCount = combined.filter {
            $0.yrPrecipitation != nil && $0.weatherKitPrecipitation == nil
        }.count
        let weatherKitOnlyCount = combined.filter {
            $0.yrPrecipitation == nil && $0.weatherKitPrecipitation != nil
        }.count
        let bothSourcesCount = combined.filter {
            $0.yrPrecipitation != nil && $0.weatherKitPrecipitation != nil
        }.count
        let noDataCount = combined.filter {
            $0.yrPrecipitation == nil && $0.weatherKitPrecipitation == nil
        }.count

        print("Data source statistics:")
        print("  Both sources: \(bothSourcesCount)/\(totalDataPoints)")
        print("  Yr.no only: \(yrOnlyCount)/\(totalDataPoints)")
        print("  WeatherKit only: \(weatherKitOnlyCount)/\(totalDataPoints)")
        print("  No data: \(noDataCount)/\(totalDataPoints)")

        if !rainPeriods.isEmpty {
            print("Rain detected at \(rainPeriods.count) time periods along the route")
            let maxRain = rainPeriods.max(by: {
                $0.combinedPrecipitation < $1.combinedPrecipitation
            })
            if let maxRain = maxRain {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                print(
                    "Maximum combined precipitation: \(String(format: "%.1f", maxRain.combinedPrecipitation))mm at \(formatter.string(from: maxRain.time))"
                )
                if let yr = maxRain.yrPrecipitation, let wk = maxRain.weatherKitPrecipitation {
                    print(
                        "  Yr.no: \(String(format: "%.1f", yr))mm, WeatherKit: \(String(format: "%.1f", wk))mm"
                    )
                } else if let yr = maxRain.yrPrecipitation {
                    print("  Yr.no only: \(String(format: "%.1f", yr))mm")
                } else if let wk = maxRain.weatherKitPrecipitation {
                    print("  WeatherKit only: \(String(format: "%.1f", wk))mm")
                }
            }
        } else {
            print("No rain expected along the route for the next 2 hours")
        }

        return combined
    }

    private func combineRouteWeatherData(_ allWeatherData: [[(Date, Double)]]) -> [(Date, Double)] {
        guard !allWeatherData.isEmpty else { return [] }

        let baseTimeline = allWeatherData[0]
        var combined: [(Date, Double)] = []

        for (index, baseEntry) in baseTimeline.enumerated() {
            var maxPrecipitation = baseEntry.1

            for weatherData in allWeatherData {
                if index < weatherData.count {
                    maxPrecipitation = max(maxPrecipitation, weatherData[index].1)
                }
            }

            combined.append((baseEntry.0, maxPrecipitation))
        }

        let rainPeriods = combined.filter { $0.1 > 0 }
        if !rainPeriods.isEmpty {
            print("Rain detected at \(rainPeriods.count) time periods along the route")
            let maxRain = rainPeriods.max(by: { $0.1 < $1.1 })
            if let maxRain = maxRain {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                print(
                    "Maximum precipitation: \(String(format: "%.1f", maxRain.1))mm at \(formatter.string(from: maxRain.0))"
                )
            }
        } else {
            print("No rain expected along the route for the next 2 hours")
        }

        return combined
    }

    private func combineWeatherData(start: [(Date, Double)], end: [(Date, Double)]) -> [(
        Date, Double
    )] {
        var combined: [(Date, Double)] = []

        for (i, startEntry) in start.enumerated() {
            if i < end.count {
                let endEntry = end[i]
                let maxPrecipitation = max(startEntry.1, endEntry.1)
                combined.append((startEntry.0, maxPrecipitation))
            } else {
                combined.append(startEntry)
            }
        }

        return combined
    }

    @available(macOS 10.15, iOS 13.0, *)
    private func geocodeLocation(_ locationString: String) async throws -> CLLocationCoordinate2D {
        return try await withCheckedThrowingContinuation { continuation in
            geocoder.geocodeAddressString(locationString) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let placemark = placemarks?.first,
                    let location = placemark.location
                else {
                    continuation.resume(throwing: WeatherServiceError.geocodingFailed)
                    return
                }

                continuation.resume(returning: location.coordinate)
            }
        }
    }

    @available(macOS 10.15, iOS 13.0, *)
    func searchLocations(_ query: String) async throws -> [String] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        return try await withCheckedThrowingContinuation { continuation in
            geocoder.geocodeAddressString(query) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let locationStrings =
                    placemarks?.compactMap { placemark -> String? in
                        var components: [String] = []

                        if let thoroughfare = placemark.thoroughfare {
                            components.append(thoroughfare)
                        }

                        if let locality = placemark.locality {
                            components.append(locality)
                        }

                        if let adminArea = placemark.administrativeArea,
                            adminArea != placemark.locality
                        {
                            components.append(adminArea)
                        }

                        if let country = placemark.country {
                            components.append(country)
                        }

                        return components.isEmpty ? nil : components.joined(separator: ", ")
                    } ?? []

                let uniqueLocations = Array(Set(locationStrings)).prefix(8)
                continuation.resume(returning: Array(uniqueLocations))
            }
        }
    }

    private func calculateRoutePoints(
        from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D,
        intervalMeters: Double = 200.0
    ) -> [CLLocationCoordinate2D] {
        let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLocation = CLLocation(latitude: end.latitude, longitude: end.longitude)

        let totalDistance = startLocation.distance(from: endLocation)
        let numberOfPoints = max(2, Int(ceil(totalDistance / intervalMeters)) + 1)

        var points: [CLLocationCoordinate2D] = []

        for i in 0..<numberOfPoints {
            let ratio = Double(i) / Double(numberOfPoints - 1)

            let lat = start.latitude + (end.latitude - start.latitude) * ratio
            let lon = start.longitude + (end.longitude - start.longitude) * ratio

            points.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }

        return points
    }

    private func deduplicateCloseCoordinates(
        _ coordinates: [CLLocationCoordinate2D], minimumDistanceMeters: Double = 500.0
    ) -> [CLLocationCoordinate2D] {
        guard !coordinates.isEmpty else { return [] }

        var deduplicated: [CLLocationCoordinate2D] = [coordinates[0]]

        for coordinate in coordinates.dropFirst() {
            let lastCoordinate = deduplicated.last!
            let lastLocation = CLLocation(
                latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let currentLocation = CLLocation(
                latitude: coordinate.latitude, longitude: coordinate.longitude)

            if lastLocation.distance(from: currentLocation) >= minimumDistanceMeters {
                deduplicated.append(coordinate)
            }
        }

        return deduplicated
    }

    private func calculateRouteDistance(
        from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D
    ) -> Double {
        let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLocation = CLLocation(latitude: end.latitude, longitude: end.longitude)
        return startLocation.distance(from: endLocation)
    }
}

enum WeatherServiceError: Error {
    case geocodingFailed
    case invalidLocation
}
