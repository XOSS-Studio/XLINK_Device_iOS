//
//  DeviceDetailView.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-08.
//

import SwiftUI
import XLINKDevice

enum DeviceDetailSegment: String, CaseIterable {
    case overview = "概览"
    case commands = "命令"
    case files = "文件"
    case firmware = "固件"
}

/// 详情页容器：解析设备、切分段、展示连接态。分段内容各自独立，容器不发起任何 SDK 调用。
struct DeviceDetailView: View {
    @StateObject private var viewModel: DeviceDetailViewModel
    /// 三个分段的状态由容器持有。放在 `switch` 分支里的话，ViewBuilder 会给每个分支独立身份，
    /// 切走就销毁——用户选好的固件包、读到的四份配置都会丢，回写往返演示得从头做。
    @StateObject private var commandState = DeviceCommandState()
    @StateObject private var fileState = DeviceFileState()
    @StateObject private var firmwareState = DeviceFirmwareState()
    @Environment(\.dismiss) private var dismiss
    @State private var segment: DeviceDetailSegment = .overview

    init(deviceID: String) {
        _viewModel = StateObject(wrappedValue: DeviceDetailViewModel(deviceID: deviceID))
    }

    var body: some View {
        Group {
            if viewModel.missingDevice {
                missingPane
            } else {
                content
            }
        }
        .background { DemoCanvas() }
        .navigationTitle(viewModel.missingDevice ? "设备详情" : viewModel.deviceName)
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $viewModel.alert) { item in
            Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("确定")))
        }
        .fullScreenCover(item: $viewModel.firmwareSession) { session in
            if let device = viewModel.device {
                DFUProgressView(device: device, firmwareURL: session.url, detailViewModel: viewModel)
            }
        }
    }

    private var missingPane: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("设备不在 SDK 的设备账本里")
                .font(.headline)
            Text("设备账本会在 reset() 后清空。返回设备页重新扫描即可。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("返回") { dismiss() }
                .demoGlassButton()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 12) {
            connectionBanner

            Picker("分段", selection: $segment) {
                ForEach(DeviceDetailSegment.allCases, id: \.self) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)

            ScrollView {
                VStack(spacing: 24) {
                    if let device = viewModel.device {
                        switch segment {
                        case .overview:
                            DeviceOverviewSection(viewModel: viewModel)
                        case .commands:
                            DeviceCommandSection(device: device, viewModel: viewModel, state: commandState)
                        case .files:
                            DeviceFileSection(device: device, viewModel: viewModel, state: fileState)
                        case .firmware:
                            DeviceFirmwareSection(device: device, viewModel: viewModel, state: firmwareState)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
        }
    }

    private var connectionBanner: some View {
        let state = DeviceDisplayText.connectionState(viewModel.deviceState)
        return HStack(spacing: 10) {
            Circle()
                .fill(state.color)
                .frame(width: 8, height: 8)
            Text(state.text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(state.color)
            if let reason = viewModel.busyReason {
                Text("· \(reason)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if viewModel.batteryLevel != nil {
                Label(viewModel.batteryText, systemImage: "battery.50")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}
