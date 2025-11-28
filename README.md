# Remote Hotspot Trigger for Mac

A SwiftUI menu bar application for macOS that triggers a Bluetooth Low Energy (BLE) command to your Android phone to enable its hotspot feature.

## Features

- **Menu Bar App**: Lives in your Mac's menu bar for quick access
- **BLE Communication**: Uses Bluetooth Low Energy for power-efficient communication
- **Device Discovery**: Automatically scans and lists available BLE devices
- **Simple Interface**: One-click hotspot activation

## Requirements

### macOS
- macOS 13.0 (Ventura) or later
- Bluetooth LE capable Mac
- Xcode 15.0+ (for building)

### Android
- Android phone with BLE GATT server capability
- Companion Android app that:
  - Advertises the BLE service with UUID: `A1B2C3D4-E5F6-7890-ABCD-EF1234567890`
  - Exposes a writable characteristic with UUID: `A1B2C3D4-E5F6-7890-ABCD-EF1234567891`
  - Handles the `ENABLE_HOTSPOT` command to toggle hotspot

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/AdaTomruk/Remote-Hotspot-Triger-Mac.git
   ```

2. Open the Xcode project:
   ```bash
   cd Remote-Hotspot-Triger-Mac/RemoteHotspotTrigger
   open RemoteHotspotTrigger.xcodeproj
   ```

3. Build and run the project (⌘+R)

## Usage

1. Launch the app - it will appear in your menu bar with a Wi-Fi router icon
2. Click the icon to open the menu
3. Click "Scan for Device" to discover your Android phone
4. Select your Android device from the list to connect
5. Once connected, click "Enable Hotspot" to trigger the hotspot on your Android phone

## Android Companion App

To use this Mac app, you need a companion Android app that runs a BLE GATT server. The Android app should:

1. **Advertise a BLE Service** with the UUID: `12345678-1234-5678-1234-56789ABCDEF0`

2. **Expose a Characteristic** with the UUID: `12345678-1234-5678-1234-56789ABCDEF1`
   - Properties: Write
   - Permissions: Write

3. **Handle the Command**: When receiving `ENABLE_HOTSPOT` (UTF-8 string), toggle the device's hotspot

### Sample Android Implementation

```kotlin
// BLE Service UUIDs
const val HOTSPOT_SERVICE_UUID = "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
const val HOTSPOT_CHARACTERISTIC_UUID = "A1B2C3D4-E5F6-7890-ABCD-EF1234567891"

// In your GattServerCallback
override fun onCharacteristicWriteRequest(
    device: BluetoothDevice,
    requestId: Int,
    characteristic: BluetoothGattCharacteristic,
    preparedWrite: Boolean,
    responseNeeded: Boolean,
    offset: Int,
    value: ByteArray
) {
    if (characteristic.uuid == UUID.fromString(HOTSPOT_CHARACTERISTIC_UUID)) {
        val command = String(value, Charsets.UTF_8)
        if (command == "ENABLE_HOTSPOT") {
            // Toggle hotspot using appropriate Android API
            toggleHotspot()
        }
        if (responseNeeded) {
            gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
        }
    }
}
```

## Customization

### Changing BLE UUIDs

If you need to use different UUIDs (to match your existing Android app), edit `BLEManager.swift`:

```swift
static let hotspotServiceUUID = CBUUID(string: "YOUR-SERVICE-UUID-HERE")
static let hotspotCharacteristicUUID = CBUUID(string: "YOUR-CHARACTERISTIC-UUID-HERE")
```

### Changing the Command

To change the command sent to the Android device, modify:

```swift
static let triggerHotspotCommand: Data = "YOUR_COMMAND".data(using: .utf8)!
```

## Permissions

The app requires the following permissions:
- **Bluetooth**: To communicate with your Android device via BLE

On first launch, macOS will prompt you to allow Bluetooth access.

## Architecture

- **RemoteHotspotTriggerApp.swift**: Main app entry point, configures the menu bar
- **MenuBarView.swift**: SwiftUI view for the menu bar dropdown interface
- **BLEManager.swift**: Handles all BLE communication (scanning, connecting, writing)

## Troubleshooting

### Device not found
- Ensure Bluetooth is enabled on both devices
- Make sure the Android app is running and advertising the BLE service
- Try moving the devices closer together

### Connection fails
- Restart Bluetooth on both devices
- Ensure no other app is connected to the Android's BLE service
- Check that the UUIDs match between Mac and Android apps

### Command not received
- Verify the characteristic UUID is correct
- Ensure the characteristic has write permissions
- Check Android app logs for incoming connections

## License

This project is licensed under the Mozilla Public License Version 2.0 - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
