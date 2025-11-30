//
//  MenuBarView.swift
//  RemoteHotspotTrigger
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var bleManager: BLEManager
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "wifi.router")
                    .font(.title2)
                Text("Remote Hotspot Trigger")
                    .font(.headline)
            }
            .padding(.top, 8)
            
            Divider()
            
            // Connection Status
            HStack {
                Circle()
                    .fill(bleManager.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(bleManager.connectionStatus)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            
            // Scan/Connect Button
            if !bleManager.isConnected {
                Button(action: {
                    if bleManager.isScanning {
                        bleManager.stopScanning()
                    } else {
                        bleManager.startScanning()
                    }
                }) {
                    HStack {
                        Image(systemName: bleManager.isScanning ? "stop.circle" : "magnifyingglass")
                        Text(bleManager.isScanning ? "Stop Scanning" : "Scan for Device")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                
                // Discovered Devices List
                if !bleManager.discoveredDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Discovered Devices:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        ForEach(bleManager.discoveredDevices) { device in
                            Button(action: {
                                bleManager.connect(to: device)
                            }) {
                                HStack {
                                    Image(systemName: "iphone")
                                    Text(device.name)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                // Enable Hotspot Button
                Button(action: {
                    bleManager.triggerHotspot(enable: true)
                }) {
                    HStack {
                        Image(systemName: "wifi")
                        Text("Enable Hotspot")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(bleManager.isSendingCommand)
                .padding(.horizontal)
                
                // Disable Hotspot Button
                Button(action: {
                    bleManager.triggerHotspot(enable: false)
                }) {
                    HStack {
                        Image(systemName: "wifi.slash")
                        Text("Disable Hotspot")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(bleManager.isSendingCommand)
                .padding(.horizontal)
                
                // Display received credentials
                if let credentials = bleManager.receivedCredentials {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "wifi")
                                .foregroundColor(.blue)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("WiFi Network")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(credentials.ssid)
                                    .font(.body)
                                    .bold()
                            }
                            Spacer()
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                        
                        if let status = bleManager.wifiJoinStatus {
                            Text(status)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        Divider()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "hand.point.up.left.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Click WiFi icon in menu bar to connect")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
                
                // Disconnect Button
                Button(action: {
                    bleManager.disconnect()
                }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Disconnect")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }
            
            // Status Message
            if let message = bleManager.lastStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }
            
            Divider()
            
            // Quit Button
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
            .padding(.bottom, 8)
        }
        .frame(width: 280)
        .padding(.vertical, 4)
    }
}

#Preview {
    MenuBarView()
        .environmentObject(BLEManager())
}
