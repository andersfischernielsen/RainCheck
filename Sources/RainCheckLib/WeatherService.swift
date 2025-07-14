import CoreLocation
import Foundation

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

class WeatherService: @unchecked Sendable {
    private let session = URLSession.shared
    private let geocoder = CLGeocoder()

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

        var allWeatherData: [[(Date, Double)]] = []
        for coordinate in deduplicatedPoints {
            let weatherData = try await fetchWeatherForLocation(coordinate)
            allWeatherData.append(weatherData)
        }

        let combinedTimeline = combineRouteWeatherData(allWeatherData)

        let routeInfo = RainAnalyzer.RouteWeatherInfo(
            routePoints: deduplicatedPoints,
            weatherData: allWeatherData,
            startLocation: startLocation,
            endLocation: endLocation
        )

        return (timeline: combinedTimeline, routeInfo: routeInfo)
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
