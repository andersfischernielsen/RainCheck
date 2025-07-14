import SwiftUI

@available(macOS 13.0, *)
struct LocationSearchField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @State private var suggestions: [String] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    private let weatherService = WeatherService()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: text) { newValue in
                    searchForLocations(query: newValue)
                }

            List(suggestions, id: \.self) { suggestion in
                Text(suggestion)
                    .truncationMode(.tail)
                    .lineLimit(1)
                    .padding(.vertical, 4)
                    .onTapGesture {
                        text = suggestion
                        suggestions = []
                    }
            }
            .listStyle(.plain)
            .background(Color(NSColor.controlBackgroundColor))

            if isSearching {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.7)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 4)
            }
        }
    }

    private func searchForLocations(query: String) {
        searchTask?.cancel()

        guard query.count >= 2 else {
            suggestions = []
            isSearching = false
            return
        }

        isSearching = true

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)

            if Task.isCancelled { return }

            do {
                let results = try await weatherService.searchLocations(query)

                if Task.isCancelled { return }

                await MainActor.run {
                    suggestions = results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    suggestions = []
                    isSearching = false
                }
            }
        }
    }
}

@available(macOS 13.0, *)
struct SettingsView: View {
    @State private var startLocation: String = ""
    @State private var endLocation: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Configure the two locations for rain checking")
                .font(.subheadline)
                .foregroundColor(.secondary)

            LocationSearchField(
                title: "Start Location", placeholder: "Nørreport St.", text: $startLocation)

            LocationSearchField(
                title: "End Location", placeholder: "Østerport St.", text: $endLocation)

            HStack {
                Button("Save") {
                    saveSettings()
                }
            }
            .padding(.top, 16)
        }
        .padding(20)
        .onAppear {
            loadSettings()
        }
        .alert("Settings", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    private func closeWindow() {
        NSApplication.shared.keyWindow?.close()
    }

    private func loadSettings() {
        startLocation = Settings.getStartLocation() ?? ""
        endLocation = Settings.getEndLocation() ?? ""
    }

    private func saveSettings() {
        guard !startLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "Please enter a start location"
            showingAlert = true
            return
        }

        guard !endLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "Please enter an end location"
            showingAlert = true
            return
        }

        Settings.saveStartLocation(startLocation.trimmingCharacters(in: .whitespacesAndNewlines))
        Settings.saveEndLocation(endLocation.trimmingCharacters(in: .whitespacesAndNewlines))

        closeWindow()
    }
}

@available(macOS 13.0, *)
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
