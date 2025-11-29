//
//  BLEManager.swift
//  RemoteHotspotTrigger
//
//  Manages Bluetooth Low Energy communication with Android device
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import CoreBluetooth
import Combine
import NetworkExtension

/// Represents a discovered BLE device
struct DiscoveredDevice: Identifiable {
    let id: UUID
    let peripheral: CBPeripheral
    let name: String
    let rssi: Int
}

/// Represents WiFi hotspot credentials received from Android device
struct HotspotCredentials: Codable {
    let ssid: String
    let password: String
}

/// BLE Manager handles all Bluetooth Low Energy communication
class BLEManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isScanning = false
    @Published var isConnected = false
    @Published var connectionStatus = "Disconnected"
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var lastStatusMessage: String?
    @Published var isSendingCommand = false
    @Published var receivedCredentials: HotspotCredentials?
    @Published var isJoiningWiFi = false
    @Published var wifiJoinStatus: String?
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var hotspotCharacteristic: CBCharacteristic?
    private var lastCommandTime: Date?
    private let minimumCommandInterval: TimeInterval = 0.5 // 500ms between commands
    private let commandTimeoutInterval: TimeInterval = 5.0 // 5 seconds timeout for stuck commands
    
    // MARK: - Configuration Constants
    
    /// Timeout duration for BLE scanning in seconds
    static let scanTimeoutSeconds: TimeInterval = 30
    
    // MARK: - BLE Service and Characteristic UUIDs
    // These UUIDs should match the Android BLE server implementation
    // IMPORTANT: Replace these with your own unique UUIDs generated using `uuidgen` command
    // or an online UUID generator to avoid conflicts with other applications
    static let hotspotServiceUUID = CBUUID(string: "C15ABA22-C32C-4A01-A770-80B82782D92F")
    static let hotspotCharacteristicUUID = CBUUID(string: "19A0B431-9E31-41C4-9DB0-D8EA70E81501")
    
    // Command bytes matching Android app expectations
    static let enableHotspotCommand: Data = Data([0x01])
    static let disableHotspotCommand: Data = Data([0x00])
    
    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    
    /// Start scanning for BLE devices
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            lastStatusMessage = "Bluetooth is not available"
            return
        }
        
        discoveredDevices.removeAll()
        isScanning = true
        connectionStatus = "Scanning..."
        lastStatusMessage = "Looking for devices..."
        
        // First try scanning for devices advertising the specific hotspot service
        // This is more efficient but requires the Android app to advertise the service UUID
        centralManager.scanForPeripherals(
            withServices: [BLEManager.hotspotServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        // After a short delay, also scan for all devices to find Android phones
        // that might not advertise the specific service UUID
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self, self.isScanning else { return }
            
            // If no devices found with specific service, scan all devices
            if self.discoveredDevices.isEmpty {
                self.centralManager.scanForPeripherals(
                    withServices: nil,
                    options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
                )
            }
        }
        
        // Auto-stop scanning after timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + BLEManager.scanTimeoutSeconds) { [weak self] in
            if self?.isScanning == true {
                self?.stopScanning()
                self?.lastStatusMessage = "Scan completed"
            }
        }
    }
    
    /// Stop scanning for BLE devices
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        connectionStatus = discoveredDevices.isEmpty ? "No devices found" : "Disconnected"
    }
    
    /// Connect to a discovered device
    func connect(to device: DiscoveredDevice) {
        stopScanning()
        connectionStatus = "Connecting..."
        lastStatusMessage = "Connecting to \(device.name)..."
        centralManager.connect(device.peripheral, options: nil)
    }
    
    /// Disconnect from the connected device
    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    /// Send command to enable or disable hotspot on the connected Android device
    /// - Parameter enable: true to enable hotspot, false to disable
    func triggerHotspot(enable: Bool) {
        #if DEBUG
        print("🔵 triggerHotspot called - enable: \(enable)")
        print("🔵 isSendingCommand: \(isSendingCommand)")
        print("🔵 isConnected: \(isConnected)")
        print("🔵 Peripheral state: \(connectedPeripheral?.state.rawValue ?? -1)")
        print("🔵 Characteristic: \(hotspotCharacteristic != nil)")
        #endif
        
        // Check if enough time has passed since last command
        if let lastTime = lastCommandTime,
           Date().timeIntervalSince(lastTime) < minimumCommandInterval {
            lastStatusMessage = "Please wait before sending another command"
            return
        }
        
        // Validate connection
        guard let peripheral = connectedPeripheral,
              let characteristic = hotspotCharacteristic,
              peripheral.state == .connected else {
            lastStatusMessage = "Not connected to device"
            isSendingCommand = false
            return
        }
        
        // Prevent multiple simultaneous commands
        guard !isSendingCommand else {
            lastStatusMessage = "Command already in progress"
            return
        }
        
        isSendingCommand = true
        lastCommandTime = Date()
        let command = enable ? BLEManager.enableHotspotCommand : BLEManager.disableHotspotCommand
        lastStatusMessage = enable ? "Enabling hotspot..." : "Disabling hotspot..."
        
        peripheral.writeValue(command, for: characteristic, type: .withResponse)
        
        // Safety timeout - reset flag if no response after timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + commandTimeoutInterval) { [weak self] in
            guard let self = self else { return }
            if self.isSendingCommand {
                self.isSendingCommand = false
                self.lastStatusMessage = "Command timeout - please try again"
            }
        }
    }
    
    /// Attempts to join the WiFi network with the provided credentials
    /// - Parameters:
    ///   - ssid: The WiFi network name
    ///   - password: The WiFi network password
    private func joinWiFiNetwork(ssid: String, password: String) {
        print("🟢 Attempting to join WiFi: \(ssid)")
        
        isJoiningWiFi = true
        wifiJoinStatus = "Joining \(ssid)..."
        lastStatusMessage = "Connecting to WiFi network..."
        
        let config = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
        config.joinOnce = false // Remember the network for future use
        
        NEHotspotConfigurationManager.shared.apply(config) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isJoiningWiFi = false
                
                if let error = error {
                    let nsError = error as NSError
                    
                    // Handle specific error cases
                    switch nsError.code {
                    case 7: // Already associated
                        self.wifiJoinStatus = "Already connected to \(ssid)"
                        self.lastStatusMessage = "Already connected to WiFi network"
                        print("🟢 Already connected to WiFi")
                    default:
                        self.wifiJoinStatus = "Failed to join \(ssid)"
                        self.lastStatusMessage = "Failed to join WiFi: \(error.localizedDescription)"
                        print("🔴 WiFi join error: \(error.localizedDescription)")
                    }
                } else {
                    self.wifiJoinStatus = "Connected to \(ssid)"
                    self.lastStatusMessage = "Successfully connected to \(ssid)!"
                    print("🟢 Successfully joined WiFi: \(ssid)")
                    
                    // Optionally disconnect BLE after successfully joining WiFi
                    // Uncomment the next line if you want to auto-disconnect
                    // self.disconnect()
                }
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            connectionStatus = "Ready to scan"
            lastStatusMessage = "Bluetooth is ready"
        case .poweredOff:
            connectionStatus = "Bluetooth Off"
            lastStatusMessage = "Please turn on Bluetooth"
        case .unauthorized:
            connectionStatus = "Unauthorized"
            lastStatusMessage = "Please allow Bluetooth access in System Preferences"
        case .unsupported:
            connectionStatus = "Unsupported"
            lastStatusMessage = "Bluetooth LE is not supported on this device"
        case .resetting:
            connectionStatus = "Resetting"
            lastStatusMessage = "Bluetooth is resetting..."
        case .unknown:
            connectionStatus = "Unknown"
            lastStatusMessage = "Bluetooth state is unknown"
        @unknown default:
            connectionStatus = "Unknown"
            lastStatusMessage = "Unknown Bluetooth state"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Filter out devices without names
        guard let name = peripheral.name, !name.isEmpty else { return }
        
        // Check if device is already in the list
        if !discoveredDevices.contains(where: { $0.peripheral.identifier == peripheral.identifier }) {
            let device = DiscoveredDevice(
                id: peripheral.identifier,
                peripheral: peripheral,
                name: name,
                rssi: RSSI.intValue
            )
            DispatchQueue.main.async {
                self.discoveredDevices.append(device)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        isConnected = true
        connectionStatus = "Connected to \(peripheral.name ?? "Device")"
        lastStatusMessage = "Discovering services..."
        
        // Discover the hotspot service
        peripheral.discoverServices([BLEManager.hotspotServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionStatus = "Connection Failed"
        lastStatusMessage = error?.localizedDescription ?? "Failed to connect"
        isConnected = false
        connectedPeripheral = nil
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isConnected = false
            self.connectionStatus = "Disconnected"
            self.connectedPeripheral = nil
            self.hotspotCharacteristic = nil
            self.isSendingCommand = false // Reset command flag on disconnect
            
            if let error = error {
                self.lastStatusMessage = "Disconnected: \(error.localizedDescription)"
            } else {
                self.lastStatusMessage = "Disconnected from device"
            }
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            lastStatusMessage = "Service discovery failed: \(error.localizedDescription)"
            return
        }
        
        guard let services = peripheral.services else {
            lastStatusMessage = "No services found"
            return
        }
        
        for service in services {
            if service.uuid == BLEManager.hotspotServiceUUID {
                peripheral.discoverCharacteristics([BLEManager.hotspotCharacteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            lastStatusMessage = "Characteristic discovery failed: \(error.localizedDescription)"
            return
        }
        
        guard let characteristics = service.characteristics else {
            lastStatusMessage = "No characteristics found"
            return
        }
        
        for characteristic in characteristics {
            if characteristic.uuid == BLEManager.hotspotCharacteristicUUID {
                hotspotCharacteristic = characteristic
                
                // Enable notifications to receive credentials
                peripheral.setNotifyValue(true, for: characteristic)
                
                lastStatusMessage = "Ready to trigger hotspot"
                print("🔵 Notifications enabled for characteristic")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        #if DEBUG
        print("🟢 didWriteValueFor callback - error: \(error?.localizedDescription ?? "none")")
        #endif
        
        // Use main thread for UI updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isSendingCommand = false
            
            if let error = error {
                self.lastStatusMessage = "Failed to send command: \(error.localizedDescription)"
            } else {
                self.lastStatusMessage = "Command sent successfully!"
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            lastStatusMessage = "Error reading response: \(error.localizedDescription)"
            print("🔴 Error updating value: \(error.localizedDescription)")
            return
        }
        
        guard characteristic.uuid == BLEManager.hotspotCharacteristicUUID,
              let data = characteristic.value else {
            return
        }
        
        print("🟢 Received notification data: \(data.count) bytes")
        
        // Try to decode as JSON credentials
        do {
            let credentials = try JSONDecoder().decode(HotspotCredentials.self, from: data)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.receivedCredentials = credentials
                self.lastStatusMessage = "Received credentials for \(credentials.ssid)"
                print("🟢 Parsed credentials - SSID: \(credentials.ssid)")
                
                // Automatically join the WiFi network
                self.joinWiFiNetwork(ssid: credentials.ssid, password: credentials.password)
            }
        } catch {
            // If not JSON, try to decode as plain text response
            if let response = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async { [weak self] in
                    self?.lastStatusMessage = "Response: \(response)"
                    print("🟡 Received text response: \(response)")
                }
            } else {
                print("🔴 Failed to decode notification data: \(error.localizedDescription)")
            }
        }
    }
}
