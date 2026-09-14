//
//  DeviceOverviewSection.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-10.
//

import SwiftUI
import XLINKDevice

/// 概览段：广播信息、运行状态、订阅事件回显与断开连接。
struct DeviceOverviewSection: View {
    @ObservedObject var viewModel: DeviceDetailViewModel

    private static let watchedPublishers = [
        "deviceStatePublisher",
        "deviceInfoUpdatedPublisher",
        "batteryLevelPublisher",
        "batteryStatusPublisher",
        "bikeComputerStatePublisher",
        "configPublisher",
        "fileTransferProgressPublisher",
        "fileTransferPublisher",
    ]

    var body: some View {
        VStack(spacing: 24) {
            DemoSection("广播信息", subtitle: "对应 XLINKBaseDevice.broadcastInfo") {
                DemoValueCard(items: viewModel.broadcastItems)
            }

            DemoSection("运行状态") {
                VStack(spacing: 0) {
                    DemoValueRow(title: "连接状态", value: DeviceDisplayText.connectionState(viewModel.deviceState).text)
                    Divider()
                    DemoValueRow(title: "电池电量", value: viewModel.batteryText)
                    Divider()
                    DemoValueRow(title: "电池状态", value: viewModel.batteryStatusText)
                    Divider()
                    DemoValueRow(title: "存储", value: viewModel.storageText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .demoGlassCard()
                Text("存储在「命令」段执行一次读取后才有值。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            DemoSection("订阅事件", subtitle: "设备级 publisher 的最近一次推送与累计次数") {
                VStack(spacing: 0) {
                    ForEach(Array(Self.watchedPublishers.enumerated()), id: \.offset) { index, key in
                        DemoValueRow(
                            title: key,
                            value: viewModel.eventLog[key]?.displayText ?? "暂无",
                            isMonospaced: true
                        )
                        if index != Self.watchedPublishers.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .demoGlassCard()
            }

            DemoSection("连接") {
                DemoActionCard(
                    title: "断开连接",
                    signature: "XLINKDeviceManager.shared.disconnect(device:)",
                    note: "断开后设备回到设备页的「本次发现」区，可重新连接。",
                    actionTitle: "断开",
                    isEnabled: viewModel.isConnected,
                    disabledReason: "设备当前未连接",
                    result: viewModel.disconnectResult,
                    action: { viewModel.disconnect() }
                )
            }
        }
    }
}
