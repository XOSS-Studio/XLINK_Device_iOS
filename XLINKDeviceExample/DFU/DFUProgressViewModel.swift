//
//  DFUProgressViewModel.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-08.
//

import Combine
import Foundation
import XLINKDevice

/// DFU 进度页：订阅八种升级状态并驱动 `updateFirmware`。
///
/// 升级任务是 ViewModel 自己持有的非结构化 `Task`：不能挂在视图的 `.task` 上，
/// 否则用户离开页面就会取消它，正在写入的固件被中途打断。只有用户显式取消才中止。
@MainActor
final class DFUProgressViewModel: ObservableObject {
    @Published private(set) var statusText = "准备升级…"
    @Published private(set) var progress: Double = 0
    @Published private(set) var progressPercentText = "0%"
    @Published private(set) var isTransferring = false
    @Published private(set) var isFinished = false
    @Published private(set) var elapsedText: String?

    private let device: XLINKBikeComputerDevice
    private let firmwareURL: URL
    /// 详情页的互斥标记宿主。升级期间占用它，避免用户回到详情页后同时发命令或传文件。
    private weak var detailViewModel: DeviceDetailViewModel?
    private var cancellables = Set<AnyCancellable>()
    private var updateTask: Task<Void, Never>?
    private var startedAt: Date?
    private var didClaimBusy = false
    /// 幂等门用独立标记，不用 `updateTask == nil`：任务结束后会把它置回 nil 以便取消与释放，
    /// 那时再触发一次 onAppear 不应该重新发起升级。
    private var didStart = false
    /// 用户主动取消。用于区分「取消导致的抛错」与真正的升级失败。
    private var didCancel = false

    init(device: XLINKBikeComputerDevice, firmwareURL: URL, detailViewModel: DeviceDetailViewModel?) {
        self.device = device
        self.firmwareURL = firmwareURL
        self.detailViewModel = detailViewModel
        subscribe()
    }

    var firmwareName: String {
        firmwareURL.lastPathComponent
    }

    /// 幂等：重复进入页面不会重复发起升级。
    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        isTransferring = true
        isFinished = false
        startedAt = Date()
        detailViewModel?.beginWork("固件升级")
        didClaimBusy = true
        updateTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await device.updateFirmware(firmwareURL: firmwareURL)
                // 正常返回也要兜底收尾：不能只等 `.completed` 进度事件。
                // 事件没来的话，全屏页的唯一出口（以 isFinished 为门的关闭按钮）永远不出现。
                if !isFinished {
                    statusText = "升级流程已结束"
                    finish()
                }
            } catch {
                // 主动取消会让 updateFirmware 抛错，但那不是失败——保留取消文案。
                if !didCancel {
                    let described = DemoErrorText.describe(error)
                    statusText = "升级失败：\(described.name) — \(described.message)"
                }
                finish()
            }
            updateTask = nil
        }
    }

    /// 用户显式取消。
    func cancelUpdate() {
        didCancel = true
        device.cancelFirmwareUpdate()
        updateTask?.cancel()
        updateTask = nil
        statusText = "已请求取消升级"
        finish()
    }

    // MARK: - Private

    private func subscribe() {
        device.firmwareUpdateProgressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.apply(update)
            }
            .store(in: &cancellables)
    }

    private func apply(_ update: XLINKFirmwareUpdateProgress) {
        progress = min(max(update.progress / 100, 0), 1)
        progressPercentText = String(format: "%.0f%%", update.progress)
        switch update.state {
        case .initial:
            statusText = "初始状态"
        case .preparingDFU:
            statusText = "准备进入 DFU 模式…"
            isTransferring = true
        case .searchingDFUDevice:
            statusText = "搜索 DFU 设备…"
            isTransferring = true
        case .connectingDFUDevice:
            statusText = "连接 DFU 设备…"
            isTransferring = true
        case .transferring:
            statusText = "固件上传中…"
            isTransferring = true
        case .validating:
            statusText = "固件校验中…"
            isTransferring = true
        case .completed:
            statusText = "升级完成"
            progress = 1
            progressPercentText = "100%"
            finish()
        case let .failed(error):
            let described = DemoErrorText.describe(error)
            statusText = "升级失败：\(described.name) — \(described.message)"
            finish()
        @unknown default:
            statusText = "未知状态"
        }
    }

    private func finish() {
        isTransferring = false
        isFinished = true
        if didClaimBusy {
            detailViewModel?.endWork()
            didClaimBusy = false
        }
        if let startedAt {
            let seconds = Date().timeIntervalSince(startedAt)
            elapsedText = String(format: "耗时 %.1f 秒", seconds)
        }
    }
}
