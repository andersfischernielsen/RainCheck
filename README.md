# RainCheck ☔

A macOS menu bar app that provides rain forecasts for cycling routes and daily commutes.

![RainCheck Screenshot](Images/screenshot.png)

---

RainCheck is a macOS menu bar application designed specifically for cyclists and commuters who need to know when and where rain will affect their routes.

Unlike traditional weather apps that show general forecasts for a single location, RainCheck analyzes weather conditions along an entire journey to provide precise information on when to ride.

## Features

RainCheck provides four distinct advisory states:

- **Fully Clear**: No rain expected along your route
- **Clear Now**: Currently dry, but rain is coming - shows when and where
- **Raining Now**: Currently raining - provides timing for when conditions will improve
- **Partial Rain**: Mixed conditions with dry windows - identifies the best time to travel
- **Route-specific locations**: Tells you if rain will be "near start", "mid-route", or "near destination"
- **Intensity tracking**: Shows rain intensity levels to help you decide if it's rideable
- **Custom start and end locations**: Set your daily commute route

![RainCheck States](Images/states.png)

## Implementation

1. **Route Analysis**: Points are calculated along a given route (every ~200-500 meters)
2. **Weather Sampling**: Precipitation forecasts are fetched for each point from the Yr.no API
3. **Searching**: Data is combined to find the worst conditions along the route
4. **Actionable Advice**: Clear time-based recommendations in are shown in the menu bar

## Usage

### First Time Setup

1. Launch RainCheck and click the RainCheck icon in the menu bar
2. Click _Settings_ to configure your route
3. Enter your starting location and destination
4. Save settings and monitor the menu bar icon

#### Reading the Menu Bar

The menu bar icon changes based on current conditions:

- **☀️ Sun**: Clear weather ahead
- **🌧️ Cloud with rain**: Rain is coming
- **⛅ Cloud with sun and rain**: Currently raining with improving conditions
- **🌧️ Filled rain cloud**: Heavy rain or prolonged wet conditions

The text next to the icon shows timing:

- `15m` = Rain starts/stops in 15 minutes
- `1h30m` = Rain starts/stops in 1 hour and 30 minutes

## Data Source

RainCheck uses weather data from [Yr.no](https://yr.no), a free weather service provided by the Norwegian Meteorological Institute.

## Contributing

Contributions are welcome! Please feel free to submit pull requests, report bugs, or suggest new features.

## Privacy

RainCheck respects your privacy:

- Location data is only used for weather API requests
- No personal data is stored or transmitted
- All weather requests are made directly to Yr.no
- No analytics or tracking

## Installation

### Requirements

- macOS 13.0 or later
- Swift 6.1 or later (for building from source)

### Building from Source

1. Clone the repository:

   ```bash
   git clone https://github.com/yourusername/RainCheck.git
   cd RainCheck
   ```

2. Build the application:

   ```bash
   swift build -c release
   ```

3. Run the application:
   ```bash
   swift run
   ```

## Acknowledgments

- Weather data provided by [Yr.no](https://yr.no) (Norwegian Meteorological Institute)
- Built with Swift and SwiftUI
- Icons from SF Symbols

---

Stay dry! 🚴‍♀️ ☔
