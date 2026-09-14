//
//  DeviceBrowserView.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-10.
//

import SwiftUI
import XLINKDevice

struct DeviceBrowserView: View {
    @Binding var path: [DeviceRoute]
    @StateObject private var viewModel = DeviceBrowserViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.isAuthorized {
                    scanSection
                    connectedSection
                    discoveredSection
                    querySection
                } else {
                    unauthorizedPane
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background { DemoCanvas() }
        .navigationTitle("设备")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { viewModel.syncScanningState() }
        .onChange(of: viewModel.route) { route in
            guard let route else { return }
            path.append(route)
            viewModel.route = nil
        }
        .alert(item: $viewModel.alert) { item in
            Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("确定")))
        }
    }

    private var unauthorizedPane: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("SDK 尚未授权")
                .font(.headline)
            Text("请先到「SDK」页填入 API Key 完成初始化，扫描与连接都以授权为前提。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var scanSection: some View {
        DemoSection("扫描", subtitle: "timeout 传 0 表示不自动停止") {
            DemoActionCard(
                title: viewModel.isScanning ? "停止扫描" : "开始扫描",
                signature: viewModel.isScanning
                    ? "XLINKDeviceManager.shared.stopScan()"
                    : "XLINKDeviceManager.shared.startScan(timeout: \(Int(viewModel.scanTimeout)))",
                note: "扫描不会清掉已连接的设备，它们始终留在下方「已连接」区。",
                actionTitle: viewModel.isScanning ? "停止" : "开始",
                result: viewModel.scanResult,
                parameters: {
                    Picker("超时", selection: $viewModel.scanTimeout) {
                        ForEach(DeviceBrowserViewModel.timeoutOptions, id: \.self) { value in
                            Text(value > 0 ? "\(Int(value))s" : "不限").tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(viewModel.isScanning)
                },
                action: { viewModel.toggleScan() }
            )
        }
    }

    private var connectedSection: some View {
        DemoSection("已连接（\(viewModel.connectedDevices.count)）", subtitle: "对应 XLINKDeviceManager.shared.connectedDevices") {
            if viewModel.connectedDevices.isEmpty {
                DemoEmptyRow(text: "暂无已连接设备")
            } else {
                ForEach(viewModel.connectedDevices, id: \.broadcastInfo.id) { device in
                    DeviceRow(
                        device: device,
                        trailing: {
                            Button("断开") { viewModel.disconnect(device) }
                                .font(.caption.weight(.semibold))
                                .tint(.red)
                                .buttonStyle(.borderless)
                        },
                        onTap: { path.append(.detail(deviceID: device.broadcastInfo.id)) }
                    )
                }
            }
        }
    }

    private var discoveredSection: some View {
        DemoSection("本次发现（\(viewModel.discoveredDevices.count)）", subtitle: "点击一行发起连接，连接成功后自动进入详情页") {
            DemoActionResultView(result: viewModel.connectResult, onShowDetail: {})

            if viewModel.discoveredDevices.isEmpty {
                DemoEmptyRow(text: viewModel.isScanning ? "扫描中，尚未发现设备" : "未开始扫描")
            } else {
                ForEach(viewModel.discoveredDevices, id: \.broadcastInfo.id) { device in
                    DeviceRow(
                        device: device,
                        trailing: {
                            if device.deviceState.isConnecting {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        },
                        onTap: { viewModel.connect(device) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var querySection: some View {
        DemoSection("设备查询", subtitle: "在已发现的设备账本里检索") {
            DemoActionCard(
                title: "按名称筛选",
                signature: "XLINKDeviceManager.shared.getDevices(byName:)",
                result: viewModel.queryByNameResult,
                parameters: {
                    TextField("名称包含", text: $viewModel.queryName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.subheadline, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                },
                action: { viewModel.queryByName() }
            )

            DemoActionCard(
                title: "按设备 ID 查询",
                signature: "XLINKDeviceManager.shared.getDevice(byId:)",
                note: "设备 ID 可从上面的列表或详情页复制。",
                result: viewModel.queryByIDResult,
                parameters: {
                    TextField("设备 ID", text: $viewModel.queryDeviceID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                },
                action: { viewModel.queryByID() }
            )

            DemoActionCard(
                title: "按广播类型筛选",
                signature: "XLINKDeviceManager.shared.getDevices(byType:)",
                actionTitle: "查询码表",
                result: viewModel.queryByTypeResult,
                parameters: {
                    Button("查询 DFU 模式设备") { viewModel.queryByType(.dfuMode) }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderless)
                },
                action: { viewModel.queryByType(.bikeComputer) }
            )
        }
    }
}

/// 设备行：名称、产品标识、型号、信号与连接态。
private struct DeviceRow<Trailing: View>: View {
    let device: XLINKBaseDevice
    @ViewBuilder let trailing: Trailing
    let onTap: () -> Void

    var body: some View {
        // 整行不能用 Button：行内还有「断开」按钮，SwiftUI 不保证嵌套 Button 只有内层响应，
        // 两个 action 同时触发就会一边断开一边推入该设备的详情页。
        content
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
    }

    private var content: some View {
        HStack(spacing: 12) {
                Image(systemName: device.broadcastInfo.deviceType == .dfuMode ? "arrow.up.circle" : "bicycle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 36, height: 36)
                    .background(.blue.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.broadcastInfo.name ?? "未命名设备")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        Text(DeviceDisplayText.broadcastType(device.broadcastInfo.deviceType))
                        if let modelId = device.broadcastInfo.modelId {
                            Text("PID \(modelId)")
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.blue.opacity(0.12), in: Capsule())
                        }
                        if let model = device.broadcastInfo.model {
                            Text(model)
                        }
                        Text("\(device.broadcastInfo.rssi) dBm")
                        if let batteryLevel = device.batteryLevel {
                            Label("\(batteryLevel)%", systemImage: "battery.50")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                let state = DeviceDisplayText.connectionState(device.deviceState)
                Text(state.text)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(state.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(state.color.opacity(0.14), in: Capsule())

            trailing
        }
        .padding(12)
        .demoGlassCard(cornerRadius: 14)
    }
}

private struct DemoEmptyRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .demoGlassCard(cornerRadius: 14)
    }
}
