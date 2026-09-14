//
//  DeviceCommandSection.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-10.
//

import SwiftUI
import XLINKDevice

/// 命令段：设备状态、存储、时间同步、星历状态与四种重置。
struct DeviceCommandSection: View {
    let device: XLINKBikeComputerDevice
    @ObservedObject var viewModel: DeviceDetailViewModel
    @ObservedObject var state: DeviceCommandState
    @State private var pendingReset: XLINKResetMode?

    var body: some View {
        VStack(spacing: 24) {
            DemoSection("设备命令", subtitle: "同一设备的命令按调用顺序串行执行") {
                DemoActionCard(
                    title: "读取设备状态",
                    signature: "try await device.requestDeviceState()",
                    note: "命令本身没有返回值，结果反映在 deviceState 上。设备正在记录时会变成 recording。",
                    isEnabled: availability.isEnabled,
                    disabledReason: availability.reason,
                    result: state.deviceStateResult,
                    action: { state.requestDeviceState(device: device, viewModel: viewModel) }
                )

                DemoActionCard(
                    title: "读取存储信息",
                    signature: "try await device.requestDeviceStorage()",
                    note: "返回值单位是 KB。",
                    isEnabled: availability.isEnabled,
                    disabledReason: availability.reason,
                    result: state.storageResult,
                    action: { state.requestStorage(device: device, viewModel: viewModel) }
                )

                DemoActionCard(
                    title: "同步时间",
                    signature: "try await device.syncTime()",
                    note: "把 App 当前时间下发给设备。",
                    isEnabled: availability.isEnabled,
                    disabledReason: availability.reason,
                    result: state.syncTimeResult,
                    action: { state.syncTime(device: device, viewModel: viewModel) }
                )

                DemoActionCard(
                    title: "读取星历状态",
                    signature: "try await device.requestGNSSState()",
                    note: "返回定位芯片型号与离线星历过期时间。部分机型不支持该查询，会以超时结束。",
                    isEnabled: availability.isEnabled,
                    disabledReason: availability.reason,
                    result: state.gnssResult,
                    action: { state.requestGNSSState(device: device, viewModel: viewModel) }
                )
            }

            DemoSection("设备重置", subtitle: "四种模式，均不可撤销") {
                DemoSignatureLabel(signature: "try await device.resetDevice(_ mode: XLINKResetMode)")
                VStack(spacing: 10) {
                    ForEach(DeviceCommandSection.resetModes, id: \.title) { item in
                        Button {
                            pendingReset = item.mode
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(item.signature)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .demoGlassCard(cornerRadius: 14)
                        }
                        .buttonStyle(.plain)
                        .disabled(!availability.isEnabled)
                    }
                }
                DemoActionResultView(result: state.resetResult, onShowDetail: {})
            }
        }
        .alert(item: Binding(
            get: { pendingReset.map { ResetConfirmation(mode: $0) } },
            set: { if $0 == nil { pendingReset = nil } }
        )) { confirmation in
            Alert(
                title: Text(DeviceCommandSection.title(for: confirmation.mode)),
                message: Text(DeviceCommandSection.warning(for: confirmation.mode)),
                primaryButton: .destructive(Text("确定执行")) {
                    state.resetDevice(confirmation.mode, device: device, viewModel: viewModel)
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    private var availability: (isEnabled: Bool, reason: String?) {
        viewModel.actionAvailability()
    }

    static let resetModes: [(mode: XLINKResetMode, title: String, signature: String)] = [
        (.resetODO, "清除总里程", ".resetODO"),
        (.restoreFactory, "恢复出厂设置", ".restoreFactory"),
        (.unbind, "清除绑定信息", ".unbind"),
        (.formatDevice, "格式化设备", ".formatDevice"),
    ]

    static func title(for mode: XLINKResetMode) -> String {
        resetModes.first { $0.mode == mode }?.title ?? "设备重置"
    }

    static func warning(for mode: XLINKResetMode) -> String {
        switch mode {
        case .resetODO:
            return "设备累计里程将清零，无法恢复。"
        case .restoreFactory:
            return "设备将恢复出厂设置，全部本地配置丢失。"
        case .unbind:
            return "设备将清除绑定信息，需要重新绑定。"
        case .formatDevice:
            return "设备存储将被格式化，未同步的骑行记录会一并丢失。"
        @unknown default:
            return "该操作不可撤销。"
        }
    }
}

private struct ResetConfirmation: Identifiable {
    let mode: XLINKResetMode
    var id: String { String(describing: mode) }
}

/// 命令段各动作的结果。
@MainActor
final class DeviceCommandState: ObservableObject {
    @Published var deviceStateResult = DemoActionResult.idle
    @Published var storageResult = DemoActionResult.idle
    @Published var syncTimeResult = DemoActionResult.idle
    @Published var gnssResult = DemoActionResult.idle
    @Published var resetResult = DemoActionResult.idle

    func requestDeviceState(device: XLINKBikeComputerDevice, viewModel: DeviceDetailViewModel) {
        perform(viewModel: viewModel, reason: "读取设备状态") {
            await DemoActionRunner.run(
                self,
                \.deviceStateResult,
                operation: { try await device.requestDeviceState() },
                summarize: { _ in
                    ("命令已完成，当前 deviceState = \(DeviceDisplayText.connectionState(device.deviceState).text)", nil)
                }
            )
            viewModel.refresh()
        }
    }

    func requestStorage(device: XLINKBikeComputerDevice, viewModel: DeviceDetailViewModel) {
        perform(viewModel: viewModel, reason: "读取存储信息") {
            await DemoActionRunner.run(
                self,
                \.storageResult,
                operation: { try await device.requestDeviceStorage() },
                summarize: { result in
                    let remain = ByteCountFormatter.string(fromByteCount: Int64(result.remainStorage) * 1024, countStyle: .decimal)
                    let total = ByteCountFormatter.string(fromByteCount: Int64(result.totalStorage) * 1024, countStyle: .decimal)
                    return (
                        "剩余 \(remain) / 共 \(total)",
                        "remainStorage = \(result.remainStorage) KB\ntotalStorage = \(result.totalStorage) KB"
                    )
                }
            )
            viewModel.refresh()
        }
    }

    func syncTime(device: XLINKBikeComputerDevice, viewModel: DeviceDetailViewModel) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        let now = Date()
        perform(viewModel: viewModel, reason: "同步时间") {
            await DemoActionRunner.run(
                self,
                \.syncTimeResult,
                successSummary: "已下发 \(formatter.string(from: now))",
                operation: { try await device.syncTime() }
            )
        }
    }

    func requestGNSSState(device: XLINKBikeComputerDevice, viewModel: DeviceDetailViewModel) {
        perform(viewModel: viewModel, reason: "读取星历状态") {
            await DemoActionRunner.run(
                self,
                \.gnssResult,
                operation: { try await device.requestGNSSState() },
                summarize: { state in
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    let expired = formatter.string(from: state.expiredTime)
                    let status = state.isExpired ? "已过期或不足 24 小时，建议刷新" : "有效"
                    return (
                        "芯片 \(state.model) · \(status)",
                        "model = \(state.model)\nexpiredTime = \(expired)\nisExpired = \(state.isExpired)"
                    )
                }
            )
            if self.gnssResult.errorName == "timeout" {
                self.gnssResult.summary += "。该机型可能不支持星历状态查询。"
            }
        }
    }

    func resetDevice(_ mode: XLINKResetMode, device: XLINKBikeComputerDevice, viewModel: DeviceDetailViewModel) {
        let title = DeviceCommandSection.title(for: mode)
        perform(viewModel: viewModel, reason: title) {
            await DemoActionRunner.run(
                self,
                \.resetResult,
                successSummary: "\(title) 命令已被设备接受",
                operation: { try await device.resetDevice(mode) }
            )
        }
    }

    private func perform(viewModel: DeviceDetailViewModel, reason: String, _ body: @escaping () async -> Void) {
        viewModel.beginWork(reason)
        Task {
            await body()
            viewModel.endWork()
        }
    }
}
