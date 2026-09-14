//
//  DeviceDisplayText.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-08.
//

import SwiftUI
import XLINKDevice

/// 连接态、广播类型、RSSI 的展示映射，供扫描页与详情页共用。
enum DeviceDisplayText {
    /// 连接状态文案与颜色，规则与原 `DeviceCell.configure` 相同。
    static func connectionState(_ state: XLINKDeviceState) -> (text: String, color: Color) {
        switch state {
        case .offline:
            return ("未连接", .gray)
        case .connecting:
            return ("连接中...", .blue)
        case .disconnecting:
            return ("断开中...", .orange)
        case .discoveringServices:
            return ("发现服务中...", .blue)
        case .idle:
            return ("已连接", .green)
        case .busy:
            return ("忙碌中...", .orange)
        case .recording:
            return ("记录中...", .orange)
        case .syncing:
            return ("同步中...", .orange)
        case .upgrading:
            return ("升级中...", .orange)
        case .noResponse:
            return ("未连接", .gray)
        @unknown default:
            return ("未连接", .gray)
        }
    }

    /// 广播设备类型的枚举 case 名，用于展示实际调用的参数。
    static func broadcastTypeRawName(_ type: XLINKBroadcastType) -> String {
        switch type {
        case .bikeComputer:
            return "bikeComputer"
        case .dfuMode:
            return "dfuMode"
        case .unknown:
            return "unknown"
        @unknown default:
            return "unknown"
        }
    }

    /// 广播设备类型文案，规则与原 `DeviceCell.configure` 相同。
    static func broadcastType(_ type: XLINKBroadcastType) -> String {
        switch type {
        case .bikeComputer:
            return "智能码表"
        case .dfuMode:
            return "DFU模式"
        case .unknown:
            return "未知设备类型"
        @unknown default:
            return "未知设备类型"
        }
    }

    /// RSSI 的 SF Symbol 名与描述，阈值与原 `getRSSIImage` / `getRSSIDescription` 相同。
    static func rssi(_ rssi: Int) -> (symbolName: String, description: String) {
        if rssi >= -50 {
            return ("wifi", "信号极好")
        }
        if rssi >= -65 {
            return ("wifi", "信号良好")
        }
        if rssi >= -80 {
            return ("wifi", "信号一般")
        }
        return ("wifi.slash", "信号较弱")
    }
}
