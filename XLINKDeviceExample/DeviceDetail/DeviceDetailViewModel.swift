//
//  DeviceDetailViewModel.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-08.
//

import Combine
import Foundation
import SwiftUI
import XLINKDevice

/// 详情页共享状态：设备解析、连接态、电池与存储、传输进度、订阅事件回显。
///
/// 命令、文件、固件三段共用 `isBusy` 互斥标记，避免同时对同一设备发起多个操作。
@MainActor
final class DeviceDetailViewModel: ObservableObject {
    @Published private(set) var missingDevice = false
    @Published private(set) var deviceName = "未命名设备"
    @Published private(set) var deviceState: XLINKDeviceState = .offline
    @Published private(set) var batteryLevel: UInt8?
    @Published private(set) var batteryStatus: BatteryStatus?
    @Published private(set) var config: BikeComputerConfig?
    @Published private(set) var broadcastItems: [(title: String, value: String)] = []

    /// 传输进度，由文件段与固件段共用展示
    @Published private(set) var transferProgress: FileTransferProgress?
    @Published private(set) var transferStateText = ""

    /// 各 publisher 的最近事件与累计次数
    @Published private(set) var eventLog: [String: DeviceEventTrace] = [:]

    /// 全段互斥：任一 SDK 操作在途时其余动作禁用
    @Published var isBusy = false
    @Published var isCancellingFileTransfer = false
    @Published var busyReason: String?

    @Published var disconnectResult = DemoActionResult.idle
    @Published var alert: DemoAlert?

    /// 固件升级会话。由容器而不是分段呈现：分段切换会销毁未选中的分段视图，
    /// 挂在分段上的话，升级中切到别的分段会把进度页连同它的 ViewModel 一起销毁，
    /// 而非结构化的升级任务仍在后台跑，`isBusy` 就再也解不掉了。
    @Published var firmwareSession: FirmwareSession?

    private(set) var device: XLINKBikeComputerDevice?
    private let deviceManager = XLINKDeviceManager.shared
    private var cancellables = Set<AnyCancellable>()
    /// 传输事件回显的去重基准，只在阶段文案变化时记一条。
    private var lastTracedTransferState = ""
    private static let eventTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        // 固定格式必须锁 locale：用户区域为佛历/和历时 yyyy 会渲染成 2569 之类。
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// 按设备 ID 从 SDK 的设备账本解析。用 `getDevice(byId:)` 而不是本轮扫描结果，
    /// 已连接但不在本轮发现列表里的设备也能正常打开。
    init(deviceID: String) {
        guard let found = deviceManager.getDevice(byId: deviceID) as? XLINKBikeComputerDevice else {
            missingDevice = true
            return
        }
        device = found
        subscribe(found)
        refresh()
    }

    var isConnected: Bool {
        deviceState.isConnected
    }

    /// 供各分段判断动作是否可用。
    func actionAvailability(requiresConnection: Bool = true) -> (isEnabled: Bool, reason: String?) {
        if requiresConnection, !isConnected {
            return (false, "设备未连接")
        }
        if isCancellingFileTransfer {
            return (false, "正在取消文件传输")
        }
        if isBusy {
            return (false, busyReason.map { "正在执行：\($0)" } ?? "有操作正在执行")
        }
        return (true, nil)
    }

    /// 分段在发起操作前后调用，维护互斥标记。
    func beginWork(_ reason: String) {
        transferProgress = nil
        transferStateText = ""
        isBusy = true
        busyReason = reason
    }

    func endWork() {
        isBusy = false
        busyReason = nil
    }

    func disconnect() {
        guard let device else { return }
        DemoActionRunner.runSync(
            self,
            \.disconnectResult,
            successSummary: "已发起断开",
            failureSummary: "",
            operation: {
                deviceManager.disconnect(device: device)
                return true
            }
        )
    }

    func refresh() {
        guard let device else { return }
        deviceName = device.broadcastInfo.name ?? "未命名设备"
        deviceState = device.deviceState
        batteryLevel = device.batteryLevel
        batteryStatus = device.batteryStatus
        config = device.config

        let info = device.broadcastInfo
        broadcastItems = [
            ("设备 ID", info.id),
            ("名称", info.name ?? "未知"),
            ("型号", info.model ?? "未读取"),
            ("产品 ID", info.modelId ?? "未携带"),
            ("序列号", info.serialNumber ?? "未知"),
            ("固件版本", info.firmwareVersion ?? "未读取"),
            ("硬件版本", info.hardwareVersion ?? "未读取"),
            ("厂商", info.manufacturer ?? "未读取"),
            ("信号强度", "\(info.rssi) dBm"),
            ("广播类型", DeviceDisplayText.broadcastType(info.deviceType)),
        ]
    }

    // MARK: - 展示文案

    var batteryText: String {
        guard let batteryLevel else { return "未读取" }
        return "\(batteryLevel)%"
    }

    var batteryStatusText: String {
        guard let batteryStatus else { return "未读取" }
        switch batteryStatus {
        case .reserved: return "保留值"
        case .full: return "已充满"
        case .good: return "电量良好"
        case .middle: return "电量中等"
        case .low: return "电量偏低"
        case .critical: return "电量极低"
        case .charging: return "充电中"
        @unknown default: return "未知状态"
        }
    }

    var storageText: String {
        guard let config else { return "未读取" }
        let total = ByteCountFormatter.string(fromByteCount: Int64(config.totalStorage) * 1024, countStyle: .decimal)
        let remain = ByteCountFormatter.string(fromByteCount: Int64(config.remainStorage) * 1024, countStyle: .decimal)
        return "剩余 \(remain) / 共 \(total)"
    }

    // MARK: - Private

    private func subscribe(_ device: XLINKBikeComputerDevice) {
        device.deviceStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                trace("deviceStatePublisher", detail: DeviceDisplayText.connectionState(state).text)
                refresh()
                if state == .offline, firmwareSession == nil {
                    // 设备掉线后解除互斥，否则页面会一直卡在「执行中」。
                    // 固件升级期间设备重启进 DFU 模式必然掉一次线，那是预期的，
                    // 此时不能解——升级任务还在跑，解了等于在写固件的同时放开命令与文件操作。
                    endWork()
                }
            }
            .store(in: &cancellables)

        // 广播信息按广播包频率更新（扫描开着时尤其密），逐包重建 11 项信息表会把整页拖进重渲染。
        // RSSI 这类字段没有逐包刷新的必要，节流到 500 毫秒。
        device.deviceInfoUpdatedPublisher
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] info in
                self?.trace("deviceInfoUpdatedPublisher", detail: info.name ?? info.id)
                self?.refresh()
            }
            .store(in: &cancellables)

        device.batteryLevelPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.trace("batteryLevelPublisher", detail: "\(level)%")
                self?.refresh()
            }
            .store(in: &cancellables)

        device.batteryStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refresh()
                self?.trace("batteryStatusPublisher", detail: self?.batteryStatusText ?? "")
            }
            .store(in: &cancellables)

        device.bikeComputerStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.trace("bikeComputerStatePublisher", detail: String(describing: state))
            }
            .store(in: &cancellables)

        device.configPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refresh()
                self?.trace("configPublisher", detail: self?.storageText ?? "")
            }
            .store(in: &cancellables)

        device.fileTransferProgressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.applyTransfer(progress)
            }
            .store(in: &cancellables)

        // 只带文件名与状态的精简通道，信息量少于上面的进度流，按需二选一订阅即可。
        device.fileTransferPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.trace("fileTransferPublisher", detail: "\(event.filename) · \(Self.transferStateName(event.state))")
            }
            .store(in: &cancellables)
    }

    private static func transferStateName(_ state: FileTransferState) -> String {
        switch state {
        case .preparing: return "preparing"
        case .transferring: return "transferring"
        case .processing: return "processing"
        case .deleting: return "deleting"
        case .completed: return "completed"
        case .failed: return "failed"
        @unknown default: return "unknown"
        }
    }

    private func applyTransfer(_ progress: FileTransferProgress) {
        switch progress.state {
        case .preparing, .deleting:
            break
        default:
            // 新操作开始后，延迟到达的旧完成/取消事件不能成为新卡片的首条进度。
            guard transferProgress?.filename == progress.filename else { return }
        }
        transferProgress = progress
        switch progress.state {
        case .preparing:
            transferStateText = "准备中"
        case .transferring:
            transferStateText = "传输中 \(Int(progress.progress * 100))%"
        case .processing:
            transferStateText = "处理中"
        case .deleting:
            transferStateText = "删除中"
        case .completed:
            transferStateText = "已完成"
        case let .failed(error):
            transferStateText = "失败：\(DemoErrorText.describe(error).name)"
        @unknown default:
            transferStateText = "未知状态"
        }
        // 进度按 BLE 包频率推送。事件回显只关心阶段变化，逐包写字典会白白多一次
        // DateFormatter 与一次整页扇出；进度本身已经由上面两个属性驱动了。
        if transferStateText != lastTracedTransferState {
            lastTracedTransferState = transferStateText
            trace("fileTransferProgressPublisher", detail: transferStateText)
        }
    }

    private func trace(_ key: String, detail: String) {
        var entry = eventLog[key] ?? DeviceEventTrace(count: 0, detail: "", stamp: "")
        entry.count += 1
        entry.detail = detail
        entry.stamp = Self.eventTimeFormatter.string(from: Date())
        eventLog[key] = entry
    }
}

/// 一次固件升级会话。`Identifiable` 用于驱动 `fullScreenCover(item:)`，固件 URL 随会话固定。
struct FirmwareSession: Identifiable {
    let id = UUID()
    let url: URL
}

/// 一个 publisher 的最近事件与累计次数。
struct DeviceEventTrace {
    var count: Int
    var detail: String
    var stamp: String

    var displayText: String {
        detail.isEmpty ? "第 \(count) 次 · \(stamp)" : "\(detail) · 第 \(count) 次 · \(stamp)"
    }
}
