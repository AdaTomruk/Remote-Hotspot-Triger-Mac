# Remote Hotspot Trigger for Mac

A SwiftUI menu bar application for macOS that triggers a Bluetooth Low Energy (BLE) command to your Android phone to enable its hotspot feature.

## Features

- **Menu Bar App**: Lives in your Mac's menu bar for quick access
- **BLE Communication**: Uses Bluetooth Low Energy for power-efficient communication
- **Device Discovery**: Automatically scans and lists available BLE devices
- **Simple Interface**: One-click hotspot enable/disable

## Requirements

### macOS
- macOS 13.0 (Ventura) or later
- Bluetooth LE capable Mac
- Xcode 15.0+ (for building)

### Android
- Android phone with BLE GATT server capability
- Companion Android app that:
  - Advertises the BLE service with UUID: `C15ABA22-C32C-4A01-A770-80B82782D92F`
  - Exposes a writable characteristic with UUID: `19A0B431-9E31-41C4-9DB0-D8EA70E81501`
  - Handles byte commands: `0x01` to enable hotspot, `0x00` to disable hotspot

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
5. Once connected, click "Enable Hotspot" to turn on the hotspot or "Disable Hotspot" to turn it off

## Android Companion App

To use this Mac app, you need a companion Android app that runs a BLE GATT server. The Android app should:

1. **Advertise a BLE Service** with the UUID: `C15ABA22-C32C-4A01-A770-80B82782D92F`

2. **Expose a Characteristic** with the UUID: `19A0B431-9E31-41C4-9DB0-D8EA70E81501`
   - Properties: Write
   - Permissions: Write

3. **Handle the Commands**: When receiving byte `0x01`, enable the hotspot. When receiving byte `0x00`, disable the hotspot.

### Sample Android Implementation

```kotlin
// BLE Service UUIDs
const val HOTSPOT_SERVICE_UUID = "C15ABA22-C32C-4A01-A770-80B82782D92F"
const val HOTSPOT_CHARACTERISTIC_UUID = "19A0B431-9E31-41C4-9DB0-D8EA70E81501"

// Command bytes
const val COMMAND_ENABLE_HOTSPOT: Byte = 0x01
const val COMMAND_DISABLE_HOTSPOT: Byte = 0x00

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
        if (value.isNotEmpty()) {
            when (value[0]) {
                COMMAND_ENABLE_HOTSPOT -> enableHotspot()
                COMMAND_DISABLE_HOTSPOT -> disableHotspot()
            }
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

The command bytes sent to the Android device are:
- `0x01` (1) to enable hotspot
- `0x00` (0) to disable hotspot

To change these values, modify in `BLEManager.swift`:

```swift
static let enableHotspotCommand: Data = Data([0x01])
static let disableHotspotCommand: Data = Data([0x00])
```

## Permissions

The app requires the following permissions:
- **Bluetooth**: To communicate with your Android device via BLE
- **Hotspot Configuration**: To automatically join WiFi networks
- **Network Client**: To establish network connections

On first launch, macOS will prompt you to allow Bluetooth access.

## Automatic WiFi Connection

When you click "Enable Hotspot", the app will:

1. **Send BLE Command**: Sends the enable command to your Android device
2. **Receive Credentials**: Android responds with hotspot SSID and password
3. **Auto-Join WiFi**: Automatically connects your Mac to the hotspot
4. **Show Status**: Displays connection status in the menu

### Credential Format

The Android app sends credentials as JSON:
```json
{"ssid":"MyHotspot","password":"12345678"}
```

The Mac app automatically parses this and joins the network.

### Requirements

- macOS 13.0 (Ventura) or later
- Hotspot Configuration entitlement
- Network client capability

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

### WiFi Connection Issues

**"Failed to join WiFi" error:**
- Ensure the hotspot is fully started (wait a few seconds)
- Check that the password is correct
- Try manually connecting once to trust the network

**"Already connected" message:**
- Your Mac is already on the hotspot network
- This is normal and not an error

**WiFi doesn't auto-connect:**
- Check System Settings → Privacy & Security → Local Network
- Ensure the app has network permissions

## License

This project is licensed under the Mozilla Public License Version 2.0 - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
