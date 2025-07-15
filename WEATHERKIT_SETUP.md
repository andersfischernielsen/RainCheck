# WeatherKit Setup Guide

This guide explains how to set up Apple WeatherKit for production builds of RainCheck.

## Requirements

WeatherKit requires:

- Apple Developer Account ($99/year)
- Proper app entitlements
- Code signing certificate

## Development vs Production

### Development Mode (Current)

- WeatherKit will fail with `xpcConnectionFailed` errors
- Application automatically falls back to Yr.no only
- No additional setup required
- Full functionality available with Yr.no data

### Production Mode (With WeatherKit)

- Both Yr.no and WeatherKit data sources active
- Weighted combination (70% Yr.no, 30% WeatherKit)
- Enhanced forecast accuracy
- Requires Apple Developer Account

## Setting Up WeatherKit for Production

### 1. Apple Developer Account

- Sign up for Apple Developer Program ($99/year)
- Create an App ID in Apple Developer Portal

### 2. Add WeatherKit Capability

1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Navigate to Certificates, Identifiers & Profiles
3. Select your App ID
4. Add "WeatherKit" capability
5. Save configuration

### 3. Update Project Settings

Add to your app's entitlements file (`RainCheck.entitlements`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.weatherkit</key>
    <true/>
</dict>
</plist>
```

For Xcode projects, you can also enable this through:

1. Select your target in Xcode
2. Go to "Signing & Capabilities" tab
3. Click "+ Capability"
4. Add "WeatherKit"

#### For Swift Package Manager (Current Setup)

Since this project uses Swift Package Manager, you'll need to:

1. Use the included `RainCheck.entitlements` file (already provided in the project root), or create your own:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.weatherkit</key>
    <true/>
    <!-- Optional: Add network access for API calls -->
    <key>com.apple.security.network.client</key>
    <true/>
    <!-- Optional: For location services if needed -->
    <key>com.apple.security.personal-information.location</key>
    <true/>
</dict>
</plist>
```

> **Note**: The additional entitlements (network.client, location) may be required for macOS App Store distribution but are optional for development and direct distribution.

2. Update `Package.swift` to include the entitlements:

```swift
.executableTarget(
    name: "RainCheck",
    dependencies: ["RainCheckLib"],
    resources: [
        .copy("Assets.xcassets")
    ],
    swiftSettings: [
        .unsafeFlags([
            "-Xlinker", "-sectcreate",
            "-Xlinker", "__TEXT",
            "-Xlinker", "__entitlements",
            "-Xlinker", "RainCheck.entitlements"
        ])
    ]
),
```

3. Or use Xcode to create an Xcode project from the Package.swift:

```bash
swift package generate-xcodeproj
```

Then configure entitlements through Xcode as described above.

### 4. Code Signing

- Create/download provisioning profile that includes WeatherKit capability
- Update Xcode project settings with proper Team ID
- Enable code signing

#### Team Configuration

Add your development team to the Package.swift (if using Xcode project):

```swift
// In project settings, not Package.swift directly
// Set DEVELOPMENT_TEAM = "YOUR_TEAM_ID"
// Set CODE_SIGN_IDENTITY = "Apple Development"
```

Or configure through Xcode:

1. Open the generated Xcode project
2. Select the RainCheck target
3. In "Signing & Capabilities":
   - Check "Automatically manage signing"
   - Select your Team
   - Ensure WeatherKit capability is listed

### 5. Build and Test

- Build with proper provisioning profile
- Test that both Yr.no and WeatherKit data appear in logs
- Verify statistics show "Both sources" counts

## Verification

When WeatherKit is working correctly, you should see:

```
Data source statistics:
  Both sources: X/Y (where X > 0)
  Yr.no only: 0/Y
  WeatherKit only: 0/Y
  No data: 0/Y
```

## Troubleshooting

### Common Issues

1. **xpcConnectionFailed**: Missing entitlements or wrong provisioning profile
2. **Authorization errors**: App ID not properly configured
3. **Network errors**: Check internet connection and WeatherKit service status

### Fallback Behavior

- Application always falls back to Yr.no when WeatherKit fails
- No functionality is lost without WeatherKit
- Yr.no provides excellent coverage, especially in Europe

## Cost Considerations

WeatherKit has usage limits:

- 500,000 API calls per month (free tier)
- Additional calls cost $0.50 per 10,000 calls
- RainCheck typically uses 50-100 calls per forecast update

For personal use, you'll likely stay within the free tier.
