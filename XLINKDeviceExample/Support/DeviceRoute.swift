//
//  DeviceRoute.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-08.
//

import Foundation

/// Demo 导航路由。详情页用设备 ID 解析，避免跨页持有设备实例。
enum DeviceRoute: Hashable {
    case detail(deviceID: String)
}

/// 可标识的告警，供 SwiftUI `.alert(item:)` 使用。
struct DemoAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
