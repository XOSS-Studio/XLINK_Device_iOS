//
//  DeviceBrowserViewModel.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-10.
//

import Combine
import SwiftUI
import XLINKDevice

/// 设备页状态：扫描控制、过滤配置、两个分区、连接跳转与设备查询。
///
/// 本页不做任何持久化：设备不落盘，启动也不自动连接。重连策略由集成方自行决定。
@MainActor
final class DeviceBrowserViewModel: ObservableObject {
    /// 扫描超时候选值，0 表示不自动停止
    static let timeoutOptions: [TimeInterval] = [10, 30, 120, 0]

    @Published private(set) var connectedDevices: [XLINKBaseDevice] = []
    @Published private(set) var discoveredDevices: [XLINKBaseDevice] = []
    @Published private(set) var isScanning = false
    @Published var scanTimeout: TimeInterval = 30

    @Published var scanResult = DemoActionResult.idle
    @Published var connectResult = DemoActionResult.idle

    /// 三个查询各自独立的结果位，避免互相覆盖
    @Published var queryByNameResult = DemoActionResult.idle
    @Published var queryByIDResult = DemoActionResult.idle
    @Published var queryByTypeResult = DemoActionResult.idle

    /// 授权态。设为 `@Published` 并跟随 `initCompletedPublisher`，
    /// 停留在本页时授权被撤销或补上都能即时反映。
    @Published private(set) var isAuthorized = false

    /// 设备查询卡的输入
    @Published var queryName = ""
    @Published var queryDeviceID = ""

    @Published var alert: DemoAlert?

    /// 连接成功后由本页写入，视图消费一次后清空，避免重复入栈。
    @Published var route: DeviceRoute?

    private let deviceManager = XLINKDeviceManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var pendingConnectionID: String?

    init() {
        subscribe()
        refreshAuthorization()
        refreshDevices()
    }

    // MARK: - 扫描

    func toggleScan() {
        if isScanning {
            stopScan()
        } else {
            startScan()
        }
    }

    func startScan() {
        let timeout = scanTimeout
        DemoActionRunner.runSync(
            self,
            \.scanResult,
            successSummary: timeout > 0 ? "扫描已开始，\(Int(timeout)) 秒后自动停止" : "扫描已开始，不自动停止",
            failureSummary: "无法开始扫描：需要已授权、蓝牙已开启且当前未在扫描",
            operation: { deviceManager.startScan(timeout: timeout) }
        )
        isScanning = deviceManager.isScanning
        refreshDevices()
    }

    /// `stopScan()` 在未扫描时会直接返回。演示台要如实反映这一点，不能无条件报成功。
    func stopScan() {
        let wasScanning = deviceManager.isScanning
        deviceManager.stopScan()
        isScanning = deviceManager.isScanning
        scanResult = DemoActionResult(
            phase: wasScanning ? .succeeded : .failed,
            duration: nil,
            summary: wasScanning
                ? "扫描已停止，本轮发现 \(discoveredDevices.count) 台"
                : "当前并未在扫描，stopScan() 直接返回",
            detail: nil,
            errorName: wasScanning ? nil : "notScanning",
            finishedAt: Date()
        )
    }

    func syncScanningState() {
        isScanning = deviceManager.isScanning
        refreshAuthorization()
        refreshDevices()
    }

    func refreshAuthorization() {
        isAuthorized = deviceManager.isAuthenticated
    }

    // MARK: - 连接

    /// 经 Manager 发起连接。结果由 `deviceConnectionPublisher` 决定，不在点击时刻判断成败。
    func connect(_ device: XLINKBaseDevice) {
        let name = device.broadcastInfo.name ?? "未命名设备"
        pendingConnectionID = device.broadcastInfo.id
        DemoActionRunner.runSync(
            self,
            \.connectResult,
            successSummary: "正在连接 \(name)…",
            failureSummary: "连接请求被拒绝：SDK 未授权或设备已在连接中",
            operation: { deviceManager.connect(device: device) }
        )
        if connectResult.phase == .failed {
            pendingConnectionID = nil
        }
    }

    func disconnect(_ device: XLINKBaseDevice) {
        deviceManager.disconnect(device: device)
    }

    // MARK: - 查询

    func queryByName() {
        let keyword = queryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = deviceManager.getDevices(byName: keyword)
        queryByNameResult = Self.queryOutcome(
            title: "getDevices(byName: \"\(keyword)\")",
            devices: matches
        )
    }

    func queryByType(_ type: XLINKBroadcastType) {
        let matches = deviceManager.getDevices(byType: type)
        queryByTypeResult = Self.queryOutcome(
            title: "getDevices(byType: .\(DeviceDisplayText.broadcastTypeRawName(type)))",
            devices: matches
        )
    }

    func queryByID() {
        let id = queryDeviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let device = deviceManager.getDevice(byId: id)
        queryByIDResult = Self.queryOutcome(
            title: "getDevice(byId:)",
            devices: device.map { [$0] } ?? []
        )
    }

    // MARK: - Private

    private func subscribe() {
        deviceManager.initCompletedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshAuthorization()
            }
            .store(in: &cancellables)

        // 发现事件按广播包频率推送（扫描以 allowDuplicates 运行），几台设备就能到每秒几十次。
        // 列表只需要跟上人眼，节流到 200 毫秒。
        deviceManager.deviceDiscoveredPublisher
            .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.refreshDevices()
            }
            .store(in: &cancellables)

        deviceManager.deviceConnectionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleConnectionChange(device: event.device, state: event.state)
            }
            .store(in: &cancellables)
    }

    /// 连接成功才跳转；失败或断开只更新结果，页面停在列表。
    private func handleConnectionChange(device: XLINKBaseDevice, state: XLINKDeviceState) {
        refreshDevices()
        isScanning = deviceManager.isScanning

        guard device.broadcastInfo.id == pendingConnectionID else { return }
        let name = device.broadcastInfo.name ?? "未命名设备"

        if state.isConnected {
            pendingConnectionID = nil
            connectResult = DemoActionResult(
                phase: .succeeded,
                duration: nil,
                summary: "\(name) 已连接，进入详情页",
                detail: nil,
                errorName: nil,
                finishedAt: Date()
            )
            route = .detail(deviceID: device.broadcastInfo.id)
        } else if state == .offline {
            pendingConnectionID = nil
            connectResult = DemoActionResult(
                phase: .failed,
                duration: nil,
                summary: "\(name) 连接未建立，设备已回到离线状态",
                detail: nil,
                errorName: "connectionFailed",
                finishedAt: Date()
            )
        }
    }

    /// 频率由订阅侧的节流控制，这里不再按 ID 序列去重：设备是引用类型，
    /// 不重新赋值数组就不会触发刷新，列表里的信号强度会停住不动。
    private func refreshDevices() {
        let connected = deviceManager.connectedDevices
        connectedDevices = connected
        let connectedIDs = Set(connected.map(\.broadcastInfo.id))
        discoveredDevices = deviceManager.discoveredDevices.filter {
            !connectedIDs.contains($0.broadcastInfo.id)
        }
    }

    private static func queryOutcome(title: String, devices: [XLINKBaseDevice]) -> DemoActionResult {
        let names = devices.map { device -> String in
            let name = device.broadcastInfo.name ?? "未命名设备"
            return "\(name) — \(device.broadcastInfo.id)"
        }
        return DemoActionResult(
            phase: .succeeded,
            duration: nil,
            summary: "\(title) 命中 \(devices.count) 台",
            detail: names.isEmpty ? nil : names.joined(separator: "\n"),
            errorName: nil,
            finishedAt: Date()
        )
    }
}
