import SwiftUI
import RainCheckLib

@available(macOS 13.0, *)
@main
struct RainCheckApp: App {
    @StateObject private var viewModel = WeatherViewModel()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(viewModel)
        } label: {
            MenuBarLabel(status: viewModel.status)
        }
        .menuBarExtraStyle(.window)
    }
}
