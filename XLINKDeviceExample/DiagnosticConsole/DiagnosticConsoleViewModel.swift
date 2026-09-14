//
//  DiagnosticConsoleViewModel.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-10.
//

import Combine
import SwiftUI
import UIKit
import XLINKDevice

/// 一条展示用诊断事件。
struct DiagnosticRow: Identifiable {
    let id = UUID()
    let event: XLINKDiagnosticEvent

    var timeText: String {
        DiagnosticConsoleViewModel.timeFormatter.string(from: event.date)
    }

    var codeText: String { event.code.rawValue }

    /// 内部异常偏“实现层”，其余是集成方能直接处置的失败，配色上区分开。
    var codeColor: Color {
        event.code == .internalError ? .orange : .red
    }

    var deviceText: String? {
        guard let deviceId = event.deviceId else { return nil }
        return String(deviceId.prefix(8))
    }
}

/// 诊断面板：消费 SDK 的诊断事件出口。
///
/// SDK 只在错误路径投递事件——协议交互、GATT 收发、扫描明细都不经由此流对外，
/// 所以这里长时间空白是正常的，不代表订阅没生效。
/// 缓冲上限固定，超出丢弃最旧的条目；暂停期间不入缓冲，也不补投。
@MainActor
final class DiagnosticConsoleViewModel: ObservableObject {
    static let bufferLimit = 2000

    @Published private(set) var rows: [DiagnosticRow] = []
    /// 过滤结果缓存。视图一次求值会读它四五次，逐次全量过滤 2000 条撑不住推送频率。
    @Published private(set) var filteredRows: [DiagnosticRow] = []
    /// 单调递增的追加计数。缓冲触顶后 `rows.count` 恒等于上限，不能再用它驱动自动滚动。
    @Published private(set) var appendCount = 0

    /// nil 表示不按诊断码筛选。
    @Published var codeFilter: XLINKDiagnosticCode? {
        didSet {
            guard oldValue != codeFilter else { return }
            rebuildFiltered()
        }
    }

    @Published var keyword = "" {
        didSet {
            guard oldValue != keyword else { return }
            // 归一化只在关键词变化时做一次，不在每行比对上重算。
            normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            rebuildFiltered()
        }
    }

    private var normalizedKeyword = ""

    @Published var isPaused = false
    @Published private(set) var didReachLimit = false

    private var cancellables = Set<AnyCancellable>()
    private let deviceManager = XLINKDeviceManager.shared

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        // 固定格式必须锁 locale：用户区域为佛历/和历时 yyyy 会渲染成 2569 之类。
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// 诊断码筛选的可选项，顺序稳定。
    static let allCodes: [XLINKDiagnosticCode] = [
        .notInitialized,
        .authenticationFailed,
        .authorizationRevoked,
        .bluetoothUnavailable,
        .connectionFailed,
        .connectionLost,
        .serviceDiscoveryFailed,
        .firmwareUpdateFailed,
        .internalError,
    ]

    init() {
        deviceManager.diagnosticPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.append(event)
            }
            .store(in: &cancellables)
    }

    var statusText: String {
        var text = "\(filteredRows.count) / \(rows.count) 条"
        if didReachLimit {
            text += " · 已达 \(Self.bufferLimit) 条上限"
        }
        if isPaused {
            text += " · 已暂停"
        }
        return text
    }

    func clear() {
        rows.removeAll()
        filteredRows.removeAll()
        didReachLimit = false
    }

    func copyAll() {
        let text = filteredRows
            .map { row in
                let device = row.event.deviceId.map { " device=\($0)" } ?? ""
                return "[\(row.timeText)] [\(row.codeText)] \(row.event.message)\(device)"
            }
            .joined(separator: "\n")
        UIPasteboard.general.string = text
    }

    private func append(_ event: XLINKDiagnosticEvent) {
        guard !isPaused else { return }
        let row = DiagnosticRow(event: event)
        rows.append(row)
        appendCount &+= 1

        if rows.count > Self.bufferLimit {
            let overflow = rows.count - Self.bufferLimit
            let dropped = Set(rows.prefix(overflow).map(\.id))
            rows.removeFirst(overflow)
            didReachLimit = true
            if !dropped.isEmpty {
                filteredRows.removeAll { dropped.contains($0.id) }
            }
        }

        // 增量追加，不重扫整个缓冲。
        if matches(row) {
            filteredRows.append(row)
        }
    }

    /// 仅在筛选条件或缓冲整体变化时全量重算。
    private func rebuildFiltered() {
        filteredRows = rows.filter(matches)
    }

    private func matches(_ row: DiagnosticRow) -> Bool {
        if let codeFilter, row.event.code != codeFilter { return false }
        guard !normalizedKeyword.isEmpty else { return true }
        if row.event.message.lowercased().contains(normalizedKeyword) { return true }
        if row.event.code.rawValue.lowercased().contains(normalizedKeyword) { return true }
        return row.event.deviceId?.lowercased().contains(normalizedKeyword) ?? false
    }
}
