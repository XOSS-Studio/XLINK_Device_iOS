//
//  DemoRootView.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-10.
//

import SwiftUI

/// 演示台入口：SDK 全局、设备、诊断三条线。
/// 设备详情从设备页推入，路径由本视图持有，扫描页在连接成功后直接往里追加。
struct DemoRootView: View {
    @State private var devicePath: [DeviceRoute] = []

    var body: some View {
        TabView {
            NavigationStack {
                SDKConsoleView()
            }
            .tabItem {
                Label("SDK", systemImage: "gearshape")
            }

            NavigationStack(path: $devicePath) {
                DeviceBrowserView(path: $devicePath)
                    .navigationDestination(for: DeviceRoute.self) { route in
                        switch route {
                        case let .detail(deviceID):
                            DeviceDetailView(deviceID: deviceID)
                        }
                    }
            }
            .tabItem {
                Label("设备", systemImage: "dot.radiowaves.left.and.right")
            }

            NavigationStack {
                DiagnosticConsoleView()
            }
            .tabItem {
                Label("诊断", systemImage: "stethoscope")
            }
        }
    }
}
