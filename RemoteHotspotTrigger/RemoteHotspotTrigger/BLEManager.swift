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

/// Represents a discovered BLE device
struct DiscoveredDevice: Identifiable {
    let id: UUID
    let peripheral: CBPeripheral
    let name: String
    let rssi: Int
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
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var hotspotCharacteristic: CBCharacteristic?
    private var lastCommandTime: Date?
    private let minimumCommandInterval: TimeInterval = 0.5 // 500ms between commands
    
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
        print("🔵 triggerHotspot called - enable: \(enable)")
        print("🔵 isSendingCommand: \(isSendingCommand)")
        print("🔵 isConnected: \(isConnected)")
        print("🔵 Peripheral state: \(connectedPeripheral?.state.rawValue ?? -1)")
        print("🔵 Characteristic: \(hotspotCharacteristic != nil)")
        
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
        
        // Safety timeout - reset flag if no response after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self else { return }
            if self.isSendingCommand {
                self.isSendingCommand = false
                self.lastStatusMessage = "Command timeout - please try again"
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
                lastStatusMessage = "Ready to trigger hotspot"
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print("🟢 didWriteValueFor callback - error: \(error?.localizedDescription ?? "none")")
        
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
            return
        }
        
        if let data = characteristic.value,
           let response = String(data: data, encoding: .utf8) {
            lastStatusMessage = "Response: \(response)"
        }
    }
}
