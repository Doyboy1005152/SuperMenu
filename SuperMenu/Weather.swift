import WeatherKit
import CoreLocation
import Foundation

class Weather {
    static let shared = Weather()

    private let service = WeatherService()

    func getCurrentTemperature(for location: CLLocation) async throws -> Double {
        let weather = try await service.weather(for: location)
        return weather.currentWeather.temperature.value
    }

    func getCurrentWeatherSymbol(for location: CLLocation) async throws -> String {
        let weather = try await service.weather(for: location)
        return weather.currentWeather.symbolName
    }

    func getTemperatureAndSymbol(for coordinates: CLLocationCoordinate2D) async throws -> (Double, String) {
        let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
        let weather = try await service.weather(for: location)
        return (weather.currentWeather.temperature.value, weather.currentWeather.symbolName)
    }
}
