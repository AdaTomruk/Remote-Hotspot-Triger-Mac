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
                // Trigger Hotspot Button
                Button(action: {
                    bleManager.triggerHotspot()
                }) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("Enable Hotspot")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.horizontal)
                .disabled(bleManager.isSendingCommand)
                
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
