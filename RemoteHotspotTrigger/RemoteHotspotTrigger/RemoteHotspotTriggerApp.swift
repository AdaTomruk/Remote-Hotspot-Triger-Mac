//
//  RemoteHotspotTriggerApp.swift
//  RemoteHotspotTrigger
//
//  A SwiftUI menu bar app that triggers BLE commands to enable hotspot on an Android phone
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import SwiftUI

@main
struct RemoteHotspotTriggerApp: App {
    @StateObject private var bleManager = BLEManager()
    
    var body: some Scene {
        MenuBarExtra("Remote Hotspot", systemImage: "wifi.router") {
            MenuBarView()
                .environmentObject(bleManager)
        }
        .menuBarExtraStyle(.window)
    }
}
