//
//  SDKConsoleViewModel.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-10.
//

import Combine
import CoreBluetooth
import SwiftUI
import XLINKDevice

/// SDK 页状态：授权、蓝牙、有效期、全局配置，以及三个全局 publisher 的最近事件。
@MainActor
final class SDKConsoleViewModel: ObservableObject {
    @Published var apiKey: String = SDKConsoleViewModel.initialAPIKey()

    @Published private(set) var isInitialized = false
    @Published private(set) var isAuthenticated = false
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var expirationDate: Date?
    @Published private(set) var remainingTime: TimeInterval = 0

    @Published var diagnosticsEnabled = true {
        didSet {
            guard oldValue != diagnosticsEnabled else { return }
            deviceManager.setDiagnosticsEnabled(diagnosticsEnabled)
        }
    }

    @Published var initializeResult = DemoActionResult.idle
    @Published var disconnectAllResult = DemoActionResult.idle
    @Published var resetResult = DemoActionResult.idle

    /// publisher 最近一次事件，用来证明订阅确实在工作。
    @Published private(set) var lastInitEvent: String?
    @Published private(set) var lastExpirationEvent: String?
    @Published private(set) var lastBluetoothEvent: String?

    private let deviceManager = XLINKDeviceManager.shared
    private var cancellables = Set<AnyCancellable>()
    private static let eventTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        // 固定格式必须锁 locale：用户区域为佛历/和历时 yyyy 会渲染成 2569 之类。
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    init() {
        subscribe()
        refresh()
    }

    var canInitialize: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var connectedCount: Int {
        deviceManager.connectedDevices.count
    }

    /// 初始化 SDK。SDK 未初始化前其余功能都不可用，这是演示的第一步。
    func initializeSDK() {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await DemoActionRunner.run(
                self,
                \.initializeResult,
                successSummary: "授权成功",
                operation: { try await deviceManager.initialize(apiKey: key) }
            )
            refresh()
        }
    }

    func disconnectAll() {
        let before = deviceManager.connectedDevices.count
        DemoActionRunner.runSync(
            self,
            \.disconnectAllResult,
            successSummary: "已对 \(before) 台在线设备发起断开",
            failureSummary: "",
            operation: {
                deviceManager.disconnectAll()
                return true
            }
        )
    }

    /// 重置会清空授权与设备账本，用于演示 SDK 的完整生命周期。
    func resetSDK() {
        DemoActionRunner.runSync(
            self,
            \.resetResult,
            successSummary: "已重置：授权与设备账本清空",
            failureSummary: "",
            operation: {
                deviceManager.reset()
                return true
            }
        )
        refresh()
    }

    func refresh() {
        isInitialized = deviceManager.isInitialized
        isAuthenticated = deviceManager.isAuthenticated
        bluetoothState = deviceManager.bluetoothState
        expirationDate = deviceManager.getAuthExpirationDate()
        remainingTime = deviceManager.getAuthRemainingTime()
    }

    // MARK: - 展示文案

    var authorizationStatusText: String {
        if !isInitialized { return "未初始化" }
        return isAuthenticated ? "已授权" : "授权失败"
    }

    var authorizationStatusColor: Color {
        if !isInitialized { return .orange }
        return isAuthenticated ? .green : .red
    }

    var bluetoothStatusText: String {
        switch bluetoothState {
        case .poweredOn: return "已开启"
        case .poweredOff: return "已关闭"
        case .unauthorized: return "未授权"
        case .unsupported: return "不支持"
        case .resetting: return "重置中"
        case .unknown: return "未知"
        @unknown default: return "未知"
        }
    }

    var bluetoothStatusColor: Color {
        switch bluetoothState {
        case .poweredOn: return .green
        case .poweredOff, .unsupported: return .red
        case .unauthorized, .resetting: return .orange
        default: return .secondary
        }
    }

    /// 到期时间格式化器。`expirationText` 挂在每次渲染上，不能逐次新建。
    private static let expirationFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    var expirationText: String {
        guard isAuthenticated else { return "未授权" }
        guard let expirationDate else { return "未提供到期时间" }
        return Self.expirationFormatter.string(from: expirationDate)
    }

    /// 剩余时间按天、小时、分钟三档。
    var remainingText: String {
        guard isAuthenticated else { return "未授权" }
        let seconds = expirationDate.map { $0.timeIntervalSince(Date()) } ?? remainingTime
        guard seconds > 0 else { return "已过期" }
        let days = Int(seconds / 86400)
        let hours = Int(seconds.truncatingRemainder(dividingBy: 86400) / 3600)
        let minutes = Int(seconds.truncatingRemainder(dividingBy: 3600) / 60)
        if days > 0 { return "\(days) 天 \(hours) 小时" }
        if hours > 0 { return "\(hours) 小时 \(minutes) 分钟" }
        return "\(minutes) 分钟"
    }

    var remainingColor: Color {
        guard isAuthenticated else { return .secondary }
        let seconds = expirationDate.map { $0.timeIntervalSince(Date()) } ?? remainingTime
        if seconds <= 0 { return .red }
        return seconds < 86400 ? .orange : .primary
    }

    // MARK: - Private

    private func subscribe() {
        deviceManager.initCompletedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] granted in
                self?.lastInitEvent = "\(Self.stamp()) 初始化完成 granted=\(granted)"
                self?.refresh()
            }
            .store(in: &cancellables)

        deviceManager.authExpirationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] date in
                let text = date.map { Self.eventTimeFormatter.string(from: $0) } ?? "nil"
                self?.lastExpirationEvent = "\(Self.stamp()) 有效期更新 \(text)"
                self?.refresh()
            }
            .store(in: &cancellables)

        deviceManager.bluetoothStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.bluetoothState = state
                self?.lastBluetoothEvent = "\(Self.stamp()) 蓝牙状态 \(state.rawValue)"
            }
            .store(in: &cancellables)
    }

    private static func stamp() -> String {
        eventTimeFormatter.string(from: Date())
    }

    private static func initialAPIKey() -> String {
        #if DEBUG
        ProcessInfo.processInfo.environment["XLINK_API_KEY"] ?? ""
        #else
        ""
        #endif
    }
}
