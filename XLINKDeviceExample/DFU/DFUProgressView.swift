//
//  DFUProgressView.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-08.
//

import SwiftUI
import XLINKDevice

/// 固件升级进度。以 `fullScreenCover` 呈现：升级期间没有任何可用的关闭入口，
/// 拦截不依赖「隐藏返回按钮是否连带禁用侧滑」这种系统行为。
struct DFUProgressView: View {
    @StateObject private var viewModel: DFUProgressViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingCancel = false

    init(device: XLINKBikeComputerDevice, firmwareURL: URL, detailViewModel: DeviceDetailViewModel?) {
        _viewModel = StateObject(
            wrappedValue: DFUProgressViewModel(
                device: device,
                firmwareURL: firmwareURL,
                detailViewModel: detailViewModel
            )
        )
    }

    var body: some View {
        NavigationStack {
            content
                .background { DemoCanvas() }
                .navigationTitle("固件升级")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        // 传输中不给关闭入口，其余任何状态都给——包括「既没在传也没结束」这种
                        // 理论上不该出现的状态，避免全屏页把用户困住。
                        if !viewModel.isTransferring {
                            Button("关闭") { dismiss() }
                        }
                    }
                }
        }
        .interactiveDismissDisabled(viewModel.isTransferring)
        .onAppear { viewModel.startIfNeeded() }
        .alert("取消升级", isPresented: $isConfirmingCancel) {
            Button("继续升级", role: .cancel) {}
            Button("确定取消", role: .destructive) { viewModel.cancelUpdate() }
        } message: {
            Text("中断固件写入可能让设备停留在 DFU 模式，需要重新升级才能恢复。")
        }
    }

    private var content: some View {
        VStack {
            Spacer(minLength: 24)
            VStack(spacing: 20) {
                Image(systemName: viewModel.isFinished ? "checkmark.circle" : "arrow.up.circle")
                    .font(.largeTitle.weight(.medium))
                    .foregroundStyle(.blue)

                Text(viewModel.statusText)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(viewModel.firmwareName)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                ProgressView(value: viewModel.progress)

                Text(viewModel.progressPercentText)
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)

                if let elapsedText = viewModel.elapsedText {
                    Text(elapsedText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if viewModel.isTransferring {
                    Text("升级期间请勿断开设备或退出 App。这段时间详情页的命令与文件操作会被一并占用。")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                    Button("取消升级") { isConfirmingCancel = true }
                        .tint(.orange)
                        .demoGlassButton()
                } else {
                    Button("关闭") { dismiss() }
                        .demoGlassButton()
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .demoGlassCard()
            .padding(.horizontal, 24)
            Spacer()
        }
    }
}
