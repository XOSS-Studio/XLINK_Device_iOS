//
//  SDKConsoleView.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-10.
//

import SwiftUI
import XLINKDevice

struct SDKConsoleView: View {
    @StateObject private var viewModel = SDKConsoleViewModel()
    @State private var isConfirmingReset = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                authorizationSection
                statusSection
                configurationSection
                globalActionSection
                eventSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background { DemoCanvas() }
        .navigationTitle("XLINK SDK")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { viewModel.refresh() }
        .confirmationDialog("重置 SDK", isPresented: $isConfirmingReset, titleVisibility: .visible) {
            Button("确定重置", role: .destructive) { viewModel.resetSDK() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将撤销授权、停止扫描、断开全部设备并清空设备账本。之后需要重新初始化。")
        }
    }

    private var authorizationSection: some View {
        DemoSection("授权", subtitle: "SDK 的所有能力都以初始化成功为前提") {
            DemoActionCard(
                title: "初始化 SDK",
                signature: "try await XLINKDeviceManager.shared.initialize(apiKey:)",
                note: "首次初始化需要网络。之后的周期性再验证遇到瞬时网络错误不会撤销授权。",
                actionTitle: "初始化",
                isEnabled: viewModel.canInitialize,
                disabledReason: "请先填写 API Key",
                result: viewModel.initializeResult,
                parameters: {
                    TextField("API Key", text: $viewModel.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.subheadline, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                },
                action: { viewModel.initializeSDK() }
            )
        }
    }

    private var statusSection: some View {
        DemoSection("运行状态", subtitle: "对应 isInitialized / isAuthenticated / bluetoothState 等只读属性") {
            VStack(spacing: 0) {
                DemoValueRow(
                    title: "isInitialized",
                    value: viewModel.isInitialized ? "true" : "false",
                    isMonospaced: true
                )
                Divider()
                DemoValueRow(
                    title: "isAuthenticated",
                    value: viewModel.isAuthenticated ? "true" : "false",
                    valueColor: viewModel.authorizationStatusColor,
                    isMonospaced: true
                )
                Divider()
                DemoValueRow(title: "授权状态", value: viewModel.authorizationStatusText, valueColor: viewModel.authorizationStatusColor)
                Divider()
                DemoValueRow(title: "蓝牙状态", value: viewModel.bluetoothStatusText, valueColor: viewModel.bluetoothStatusColor)
                Divider()
                DemoValueRow(title: "授权到期", value: viewModel.expirationText)
                Divider()
                DemoValueRow(title: "剩余时长", value: viewModel.remainingText, valueColor: viewModel.remainingColor)
                Divider()
                DemoValueRow(title: "已连接设备", value: "\(viewModel.connectedCount)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .demoGlassCard()
        }
    }

    private var configurationSection: some View {
        DemoSection("全局配置", subtitle: "SDK 对外只投递错误级诊断事件") {
            VStack(alignment: .leading, spacing: 14) {
                DemoSignatureLabel(signature: "XLINKDeviceManager.shared.setDiagnosticsEnabled(_:)")
                Toggle("投递诊断事件", isOn: $viewModel.diagnosticsEnabled)
                    .font(.subheadline)
                Text("关闭后「诊断」页不再收到任何事件。SDK 的内部日志——协议交互、蓝牙收发、扫描明细——始终不对外，本开关与它们无关。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .demoGlassCard()
        }
    }

    private var globalActionSection: some View {
        DemoSection("全局操作") {
            DemoActionCard(
                title: "断开全部设备",
                signature: "XLINKDeviceManager.shared.disconnectAll()",
                note: "覆盖连接中与已连接的设备。",
                actionTitle: "断开全部",
                result: viewModel.disconnectAllResult,
                action: { viewModel.disconnectAll() }
            )

            DemoActionCard(
                title: "重置 SDK",
                signature: "XLINKDeviceManager.shared.reset()",
                note: "撤销授权、停扫、断连并清空设备账本。",
                actionTitle: "重置",
                result: viewModel.resetResult,
                action: { isConfirmingReset = true }
            )
        }
    }

    private var eventSection: some View {
        DemoSection("订阅事件", subtitle: "三个全局 publisher 的最近一次推送") {
            VStack(spacing: 0) {
                DemoValueRow(
                    title: "initCompletedPublisher",
                    value: viewModel.lastInitEvent ?? "暂无",
                    isMonospaced: true
                )
                Divider()
                DemoValueRow(
                    title: "authExpirationPublisher",
                    value: viewModel.lastExpirationEvent ?? "暂无",
                    isMonospaced: true
                )
                Divider()
                DemoValueRow(
                    title: "bluetoothStatePublisher",
                    value: viewModel.lastBluetoothEvent ?? "暂无",
                    isMonospaced: true
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .demoGlassCard()
        }
    }
}
