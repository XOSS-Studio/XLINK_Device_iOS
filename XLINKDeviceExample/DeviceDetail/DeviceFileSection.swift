//
//  DeviceFileSection.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-10.
//

import SwiftUI
import UniformTypeIdentifiers
import XLINKDevice

/// 文件段：四类配置的读取与回写、轨迹同步与删除、星历文件下发、传输控制。
struct DeviceFileSection: View {
    let device: XLINKBikeComputerDevice
    @ObservedObject var viewModel: DeviceDetailViewModel
    @ObservedObject var state: DeviceFileState
    @State private var isShowingFileImporter = false
    @State private var isConfirmingDelete = false

    var body: some View {
        VStack(spacing: 24) {
            configReadSection
            configWriteSection
            workoutSection
            sendFileSection
            maintenanceSection
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                state.sendEphemerisFile(at: url, device: device, viewModel: viewModel)
            case let .failure(error):
                viewModel.alert = DemoAlert(title: "选择文件失败", message: error.localizedDescription)
            }
        }
        .alert("删除轨迹", isPresented: $isConfirmingDelete) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                state.deleteSelectedWorkout(device: device, viewModel: viewModel)
            }
        } message: {
            Text("将删除设备上的 \(state.selectedWorkout?.formatName ?? "所选文件")，不可恢复。")
        }
    }

    private var availability: (isEnabled: Bool, reason: String?) {
        viewModel.actionAvailability()
    }

    /// 互斥操作中只在当前调用卡片展示进度，结束后由该卡片的结果承接状态。
    private func progress(for result: DemoActionResult) -> FileTransferProgress? {
        result.isRunning ? viewModel.transferProgress : nil
    }

    // MARK: - 读取配置

    private var configReadSection: some View {
        DemoSection("读取配置", subtitle: "从设备下载 JSON 配置文件并解码") {
            DemoActionCard(
                title: "用户配置",
                signature: "try await device.getUserProfile()",
                isEnabled: availability.isEnabled,
                disabledReason: availability.reason,
                result: state.getUserProfileResult,
                transferProgress: progress(for: state.getUserProfileResult),
                action: { state.getUserProfile(device: device, viewModel: viewModel) }
            )
            DemoActionCard(
                title: "系统设置",
                signature: "try await device.getSettings()",
                isEnabled: availability.isEnabled,
                disabledReason: availability.reason,
                result: state.getSettingsResult,
                transferProgress: progress(for: state.getSettingsResult),
                action: { state.getSettings(device: device, viewModel: viewModel) }
            )
            DemoActionCard(
                title: "单车配置",
                signature: "try await device.getGearProfile()",
                isEnabled: availability.isEnabled,
                disabledReason: availability.reason,
                result: state.getGearResult,
                transferProgress: progress(for: state.getGearResult),
                action: { state.getGearProfile(device: device, viewModel: viewModel) }
            )
            DemoActionCard(
                title: "表盘配置",
                signature: "try await device.getPanels()",
                isEnabled: availability.isEnabled,
                disabledReason: availability.reason,
                result: state.getPanelsResult,
                transferProgress: progress(for: state.getPanelsResult),
                action: { state.getPanels(device: device, viewModel: viewModel) }
            )
        }
    }

    // MARK: - 回写配置

    private var configWriteSection: some View {
        DemoSection("回写配置", subtitle: "演示往返：先读取，再把读到的内容原样写回设备") {
            DemoActionCard(
                title: "回写用户配置",
                signature: "try await device.sendUserProfile(_:)",
                note: "需要先执行上面的「用户配置」读取。",
                isEnabled: availability.isEnabled && state.userProfile != nil,
                disabledReason: state.userProfile == nil ? "请先读取用户配置" : availability.reason,
                result: state.sendUserProfileResult,
                transferProgress: progress(for: state.sendUserProfileResult),
                action: { state.sendUserProfile(device: device, viewModel: viewModel) }
            )
            DemoActionCard(
                title: "回写系统设置",
                signature: "try await device.sendSettings(_:)",
                note: "需要先执行上面的「系统设置」读取。",
                isEnabled: availability.isEnabled && state.settings != nil,
                disabledReason: state.settings == nil ? "请先读取系统设置" : availability.reason,
                result: state.sendSettingsResult,
                transferProgress: progress(for: state.sendSettingsResult),
                action: { state.sendSettings(device: device, viewModel: viewModel) }
            )
            DemoActionCard(
                title: "回写单车配置",
                signature: "try await device.sendGearProfile(_:)",
                note: "需要先执行上面的「单车配置」读取。",
                isEnabled: availability.isEnabled && state.gearProfile != nil,
                disabledReason: state.gearProfile == nil ? "请先读取单车配置" : availability.reason,
                result: state.sendGearResult,
                transferProgress: progress(for: state.sendGearResult),
                action: { state.sendGearProfile(device: device, viewModel: viewModel) }
            )
            DemoActionCard(
                title: "回写表盘配置",
                signature: "try await device.sendPanels(_:)",
                note: "需要先执行上面的「表盘配置」读取。",
                isEnabled: availability.isEnabled && state.panels != nil,
                disabledReason: state.panels == nil ? "请先读取表盘配置" : availability.reason,
                result: state.sendPanelsResult,
                transferProgress: progress(for: state.sendPanelsResult),
                action: { state.sendPanels(device: device, viewModel: viewModel) }
            )
        }
    }

    // MARK: - 轨迹

    private var workoutSection: some View {
        DemoSection("骑行记录", subtitle: "先取列表，再对选中的单条同步或删除") {
            DemoActionCard(
                title: "读取记录列表",
                signature: "try await device.getWorkouts()",
                isEnabled: availability.isEnabled,
                disabledReason: availability.reason,
                result: state.workoutsResult,
                transferProgress: progress(for: state.workoutsResult),
                action: { state.getWorkouts(device: device, viewModel: viewModel) }
            )

            if !state.workouts.isEmpty {
                workoutPicker
            }

            DemoActionCard(
                title: "同步选中记录",
                signature: "try await device.syncWorkout(_:)",
                note: "返回 FIT 二进制数据，这里只展示字节数。",
                isEnabled: availability.isEnabled && state.selectedWorkout != nil,
                disabledReason: state.selectedWorkout == nil ? "请先选择一条记录" : availability.reason,
                result: state.syncWorkoutResult,
                transferProgress: progress(for: state.syncWorkoutResult),
                action: { state.syncSelectedWorkout(device: device, viewModel: viewModel) }
            )

            DemoActionCard(
                title: "删除选中记录",
                signature: "try await device.deleteWorkout(_:)",
                isEnabled: availability.isEnabled && state.selectedWorkout != nil,
                disabledReason: state.selectedWorkout == nil ? "请先选择一条记录" : availability.reason,
                result: state.deleteWorkoutResult,
                transferProgress: progress(for: state.deleteWorkoutResult),
                action: { isConfirmingDelete = true }
            )
        }
    }

    private var workoutPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择记录（\(state.workouts.count) 条）")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(state.workouts, id: \.fileName) { workout in
                    Button {
                        state.selectedWorkout = workout
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: state.selectedWorkout?.fileName == workout.fileName
                                ? "largecircle.fill.circle"
                                : "circle")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(workout.formatName)
                                    .font(.system(.subheadline, design: .monospaced))
                                Text("\(workout.fileSize) 字节 · \(DeviceFileState.statusText(workout.status))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .demoGlassCard()
        }
    }

    // MARK: - 下发与维护

    private var sendFileSection: some View {
        DemoSection("下发文件") {
            DemoActionCard(
                title: "发送星历文件",
                signature: "try await device.sendFile(data, filename: \"\(DeviceFileState.ephemerisFilename)\")",
                note: "选择本地星历数据，发送时自动使用 \(DeviceFileState.ephemerisFilename)。",
                actionTitle: "选择文件并发送",
                isEnabled: availability.isEnabled,
                disabledReason: availability.reason,
                result: state.sendFileResult,
                transferProgress: progress(for: state.sendFileResult),
                action: { isShowingFileImporter = true }
            )
        }
    }

    private var maintenanceSection: some View {
        DemoSection("传输控制") {
            DemoActionCard(
                title: "取消当前传输",
                signature: "try await device.cancelFileTransfer()",
                isEnabled: viewModel.isConnected,
                disabledReason: "设备未连接",
                result: state.cancelResult,
                action: { state.cancelTransfer(device: device, viewModel: viewModel) }
            )
            DemoActionCard(
                title: "清除传输进度",
                signature: "try await device.resetFileTransferServices()",
                note: "清除 SDK 缓存的传输进度。正在传输时请先取消传输。",
                isEnabled: viewModel.isConnected,
                disabledReason: "设备未连接",
                result: state.resetServicesResult,
                action: { state.resetTransferServices(device: device) }
            )
        }
    }
}

/// 文件段各动作的结果与读到的配置缓存。
@MainActor
final class DeviceFileState: ObservableObject {
    /// 设备端星历接收名，与 SDK 的 offlineGNSS 文件类型一致。
    static let ephemerisFilename = "offline.gnss"

    @Published var getUserProfileResult = DemoActionResult.idle
    @Published var getSettingsResult = DemoActionResult.idle
    @Published var getGearResult = DemoActionResult.idle
    @Published var getPanelsResult = DemoActionResult.idle

    @Published var sendUserProfileResult = DemoActionResult.idle
    @Published var sendSettingsResult = DemoActionResult.idle
    @Published var sendGearResult = DemoActionResult.idle
    @Published var sendPanelsResult = DemoActionResult.idle

    @Published var workoutsResult = DemoActionResult.idle
    @Published var syncWorkoutResult = DemoActionResult.idle
    @Published var deleteWorkoutResult = DemoActionResult.idle

    @Published var sendFileResult = DemoActionResult.idle
    @Published var cancelResult = DemoActionResult.idle
    @Published var resetServicesResult = DemoActionResult.idle

    @Published var workouts: [WorkoutStruct] = []
    @Published var selectedWorkout: WorkoutStruct?

    /// 读到的配置，供回写演示使用。
    @Published private(set) var userProfile: UserProfileSetting?
    @Published private(set) var settings: DeviceSetting?
    @Published private(set) var gearProfile: GearSetting?
    @Published private(set) var panels: PanelSetting?

    // MARK: - 读取

    func getUserProfile(device: XLINKBikeComputerDevice, viewModel: DeviceDetailViewModel) {
        perform(viewModel, "读取用户配置") {
            let value = await DemoActionRunner.run(
                self,
                \.getUserProfileResult,
                operation: { try await device.getUserProfile() },
                summarize: { profile in
                    guard let profile else { return ("设备返回空配置", nil) }
                    return ("已读取用户配置", DemoJSON.string(from: profile))
                }
            )
            self.userProfile = value ?? nil
        }
    }

    func getSettings(device: XLINKBikeComputerDevice, viewModel: DeviceDetailViewModel) {
        perform(viewModel, "读取系统设置") {
            let value = await DemoActionRunner.run(
                self,
                \.getSettingsResult,
                operation: { try await device.getSettings() },
                summarize: { setting in
                    guard let setting else { return ("设备返回空配置", nil) }
                    return ("已读取系统设置 version=\(setting.version)", DemoJSON.string(from: setting))
                }
            )
            self.settings = value ?? nil
        }
    }

    func getGearProfile(device: XLINKBikeComputerDevice, viewModel: DeviceDetailViewModel) {
        perform(viewModel, "读取单车配置") {
            let value = await DemoActionRunner.run(
                self,
                \.getGearResult,
                operation: { try await device.getGearProfile() },
                summarize: { gear in
                    ("已读取 \(gear.gears?.count ?? 0) 台单车", DemoJSON.string(from: gear))
                }
            )
            self.gearProfile = value
        }
    }

    func getPanels(device: XLINKBikeComputerDevice, viewModel: DeviceDetailViewModel) {
        perform(viewModel, "读取表盘配置") {
            let value = await DemoActionRunner.run(
                self,
                \.getPanelsResult,
                operation: { try await device.getPanels() },
                summarize: { panel in
                    ("已读取 \(panel.pages.count) 页表盘", DemoJSON.string(from: panel))
                }
            )
            self.panels = value
        }
    }

    // MARK: - 回写

    func sendUserProfile(device: XLINKBikeComputerDevice, viewModel: DeviceDetailViewModel) {
        guard let userProfile else { return }
        perform(viewModel, "回写用户配置") {
            await DemoActionRunner.run(
                self,
                \.sendUserProfileResult,
                successSummary: "设备已接受",
                operation: { try await device.sendUserProfile(userProfile) }
            )
        }
    }

    func sendSettings(device: XLINKBikeComputerDevice, viewModel: DeviceDetailViewModel) {
        guard let settings else { return }
        perform(viewModel, "回写系统设置") {
            await DemoActionRunner.run(
                self,
                \.sendSettingsResult,
                successSummary: "设备已接受",
                operation: { try await device.sendSettings(settings) }
            )
        }
    }

    func sendGearProfile(device: XLINKBikeComputerDevice, viewModel: DeviceDetailViewModel) {
        guard let gearProfile else { return }
        perform(viewModel, "回写单车配置") {
            await DemoActionRunner.run(
                self,
                \.sendGearResult,
                successSummary: "设备已接受",
                operation: { try await device.sendGearProfile(gearProfile) }
            )
        }
    }

    func sendPanels(device: XLINKBikeComputerDevice, viewModel: DeviceDetailViewModel) {
        guard let panels else { return }
        perform(viewModel, "回写表盘配置") {
            await DemoActionRunner.run(
                self,
                \.sendPanelsResult,
                successSummary: "设备已接受",
                operation: { try await device.sendPanels(panels) }
            )
        }
    }

    // MARK: - 轨迹

    func getWorkouts(device: XLINKBikeComputerDevice, viewModel: DeviceDetailViewModel) {
        perform(viewModel, "读取记录列表") {
            let value = await DemoActionRunner.run(
                self,
                \.workoutsResult,
                operation: { try await device.getWorkouts() },
                summarize: { Self.workoutSummary($0) }
            )
            self.applyWorkouts(value)
        }
    }

    func syncSelectedWorkout(device: XLINKBikeComputerDevice, viewModel: DeviceDetailViewModel) {
        guard let workout = selectedWorkout else { return }
        perform(viewModel, "同步 \(workout.formatName)") {
            await DemoActionRunner.run(
                self,
                \.syncWorkoutResult,
                operation: { try await device.syncWorkout(workout) },
                summarize: { data in
                    ("已取回 \(workout.formatName)，\(data.count) 字节", nil)
                }
            )
        }
    }

    func deleteSelectedWorkout(device: XLINKBikeComputerDevice, viewModel: DeviceDetailViewModel) {
        guard let workout = selectedWorkout else { return }
        perform(viewModel, "删除 \(workout.formatName)") {
            let deleted = await DemoActionRunner.run(
                self,
                \.deleteWorkoutResult,
                operation: { try await device.deleteWorkout(workout) },
                summarize: { _ in ("已删除 \(workout.formatName)", nil) }
            )
            if deleted != nil {
                self.workouts.removeAll { $0.fileName == workout.fileName }
                self.selectedWorkout = nil
            }
        }
    }

    // MARK: - 下发与维护

    /// 保留所选文件内容，仅将设备端接收名设为星历协议规定的名称。
    func sendEphemerisFile(at url: URL, device: XLINKBikeComputerDevice, viewModel: DeviceDetailViewModel) {
        let availability = viewModel.actionAvailability()
        guard availability.isEnabled else {
            viewModel.alert = DemoAlert(title: "暂时无法发送", message: availability.reason ?? "设备当前不可用")
            return
        }
        let sourceFilename = url.lastPathComponent
        viewModel.beginWork("读取 \(sourceFilename)")
        Task {
            // 用户可能选中 iCloud 上尚未下载的文件或很大的文件，读取不能占着主线程。
            let result = await Self.readFile(at: url)
            viewModel.endWork()
            switch result {
            case let .success(data):
                self.send(data: data, filename: Self.ephemerisFilename, device: device, viewModel: viewModel)
            case let .failure(error):
                viewModel.alert = DemoAlert(title: "读取文件失败", message: error.localizedDescription)
            }
        }
    }

    private static func readFile(at url: URL) async -> Result<Data, any Error> {
        await Task.detached(priority: .userInitiated) {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                return .success(try Data(contentsOf: url))
            } catch {
                return .failure(error)
            }
        }.value
    }

    private func send(data: Data, filename: String, device: XLINKBikeComputerDevice, viewModel: DeviceDetailViewModel) {
        perform(viewModel, "下发 \(filename)") {
            await DemoActionRunner.run(
                self,
                \.sendFileResult,
                operation: { try await device.sendFile(data, filename: filename) },
                summarize: { _ in ("\(filename) 已下发，\(data.count) 字节", nil) }
            )
        }
    }

    /// 取消绕过普通操作队列；等待停止命令结束期间继续禁用新操作。
    func cancelTransfer(device: XLINKBikeComputerDevice, viewModel: DeviceDetailViewModel) {
        guard !viewModel.isCancellingFileTransfer else { return }
        viewModel.isCancellingFileTransfer = true
        Task {
            defer { viewModel.isCancellingFileTransfer = false }
            await DemoActionRunner.run(
                self,
                \.cancelResult,
                successSummary: "已请求取消传输",
                operation: { try await device.cancelFileTransfer() }
            )
        }
    }

    func resetTransferServices(device: XLINKBikeComputerDevice) {
        Task {
            await DemoActionRunner.run(
                self,
                \.resetServicesResult,
                successSummary: "SDK 传输进度已清除",
                operation: { try await device.resetFileTransferServices() }
            )
        }
    }

    static func statusText(_ status: FileSyncState) -> String {
        switch status {
        case .unSync: return "未同步"
        case .recording: return "记录中"
        case .syncing: return "同步中"
        case .synced: return "已同步"
        @unknown default: return "未知"
        }
    }

    // MARK: - Private

    private func applyWorkouts(_ value: [WorkoutStruct]?) {
        guard let value else { return }
        workouts = value
        if let selectedWorkout, !value.contains(where: { $0.fileName == selectedWorkout.fileName }) {
            self.selectedWorkout = nil
        }
        if selectedWorkout == nil {
            selectedWorkout = value.first
        }
    }

    private static func workoutSummary(_ workouts: [WorkoutStruct]) -> (summary: String, detail: String?) {
        guard !workouts.isEmpty else { return ("设备上没有骑行记录", nil) }
        let lines = workouts.map { "\($0.formatName) · \($0.fileSize) 字节 · \(statusText($0.status))" }
        return ("共 \(workouts.count) 条记录", lines.joined(separator: "\n"))
    }

    private func perform(_ viewModel: DeviceDetailViewModel, _ reason: String, _ body: @escaping () async -> Void) {
        let availability = viewModel.actionAvailability()
        guard availability.isEnabled else {
            viewModel.alert = DemoAlert(title: "暂时无法执行", message: availability.reason ?? "设备当前不可用")
            return
        }
        viewModel.beginWork(reason)
        Task {
            await body()
            viewModel.endWork()
        }
    }
}
