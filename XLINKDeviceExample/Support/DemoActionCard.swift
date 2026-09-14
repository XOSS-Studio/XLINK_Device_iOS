//
//  DemoActionCard.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-10.
//

import SwiftUI
import UIKit
import XLINKDevice

/// 演示台的基本单元：一次 SDK 调用。
///
/// 卡片同时给出「调了哪个 API」「传了什么」「用了多久」「返回或错在哪」，
/// 让看 Demo 的人不用读源码就能对上 SDK 的调用方式。
struct DemoActionCard<Parameters: View>: View {
    let title: String
    /// 实际调用的公开 API 签名，等宽展示
    let signature: String
    var note: String?
    var actionTitle: String = "执行"
    var isEnabled: Bool = true
    var disabledReason: String?
    let result: DemoActionResult
    var transferProgress: FileTransferProgress?
    @ViewBuilder var parameters: Parameters
    let action: () -> Void

    @State private var isShowingDetail = false

    init(
        title: String,
        signature: String,
        note: String? = nil,
        actionTitle: String = "执行",
        isEnabled: Bool = true,
        disabledReason: String? = nil,
        result: DemoActionResult,
        transferProgress: FileTransferProgress? = nil,
        @ViewBuilder parameters: () -> Parameters = { EmptyView() },
        action: @escaping () -> Void
    ) {
        self.title = title
        self.signature = signature
        self.note = note
        self.actionTitle = actionTitle
        self.isEnabled = isEnabled
        self.disabledReason = disabledReason
        self.result = result
        self.transferProgress = transferProgress
        self.parameters = parameters()
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            DemoSignatureLabel(signature: signature)

            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            parameters

            Button(action: action) {
                HStack(spacing: 8) {
                    if result.isRunning {
                        ProgressView().controlSize(.small)
                    }
                    Text(result.isRunning ? "执行中…" : actionTitle)
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
            }
            .demoGlassButton(size: .regular)
            .disabled(!isEnabled || result.isRunning)

            if !isEnabled, let disabledReason {
                Text(disabledReason)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let transferProgress {
                DemoFileTransferProgressView(progress: transferProgress)
            }

            DemoActionResultView(result: result) {
                isShowingDetail = true
            }
        }
        .padding(16)
        .demoGlassCard()
        .sheet(isPresented: $isShowingDetail) {
            DemoResultSheet(title: title, text: result.detail ?? "")
        }
    }
}

/// 将当前文件及进度放在发起操作的卡片内。
private struct DemoFileTransferProgressView: View {
    let progress: FileTransferProgress

    private var fraction: Double {
        progress.progress.isFinite ? min(max(progress.progress, 0), 1) : 0
    }

    private var statusText: String {
        switch progress.state {
        case .preparing: return "准备中"
        case .transferring: return "传输中 \(Int(fraction * 100))%"
        case .processing: return "处理中"
        case .deleting: return "删除中"
        case .completed: return "已完成"
        case let .failed(error): return DemoErrorText.describe(error).message
        @unknown default: return "未知状态"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(progress.filename)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
            ProgressView(value: fraction)
            HStack {
                Text(statusText)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(progress.transferredBytes) / \(progress.fileSize) 字节")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// API 签名行。
struct DemoSignatureLabel: View {
    let signature: String

    var body: some View {
        Text(signature)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.blue)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// 结果区：状态点、摘要、耗时、错误名、完整响应入口。
struct DemoActionResultView: View {
    let result: DemoActionResult
    let onShowDetail: () -> Void

    var body: some View {
        if result.phase != .idle {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                    if let errorName = result.errorName {
                        Text(errorName)
                            .font(.system(.caption2, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red.opacity(0.12), in: Capsule())
                    }
                    Spacer(minLength: 8)
                    if let durationText = result.durationText {
                        Text(durationText)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                if !result.summary.isEmpty {
                    Text(result.summary)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }

                if result.detail?.isEmpty == false {
                    Button("查看完整响应", action: onShowDetail)
                        .font(.caption.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(statusColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var statusColor: Color {
        switch result.phase {
        case .idle: return .secondary
        case .running: return .blue
        case .succeeded: return .green
        case .failed: return .red
        }
    }

    private var statusText: String {
        switch result.phase {
        case .idle: return "未执行"
        case .running: return "执行中"
        case .succeeded: return "成功"
        case .failed: return "失败"
        }
    }
}

/// 带标题的分组容器。
struct DemoSection<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            content
        }
    }
}

/// 键值行。
struct DemoValueRow: View {
    let title: String
    let value: String
    var valueColor: Color = .primary
    var isMonospaced: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(isMonospaced ? .system(.subheadline, design: .monospaced) : .subheadline.weight(.medium))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.vertical, 8)
    }
}

/// 键值卡片：一组 `DemoValueRow` 加分隔线。
struct DemoValueCard: View {
    let items: [(title: String, value: String)]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                DemoValueRow(title: item.title, value: item.value)
                if index != items.count - 1 {
                    Divider()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .demoGlassCard()
    }
}

/// 完整响应展示。
struct DemoResultSheet: View {
    let title: String
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background { DemoCanvas() }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("复制") {
                        UIPasteboard.general.string = text
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
