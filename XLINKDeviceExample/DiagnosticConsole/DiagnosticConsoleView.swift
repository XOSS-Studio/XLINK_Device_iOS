//
//  DiagnosticConsoleView.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-10.
//

import SwiftUI
import XLINKDevice

struct DiagnosticConsoleView: View {
    @StateObject private var viewModel = DiagnosticConsoleViewModel()
    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 12) {
            toolbar
            eventList
        }
        .background { DemoCanvas() }
        .navigationTitle("诊断")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var toolbar: some View {
        VStack(spacing: 10) {
            DemoSignatureLabel(signature: "XLINKDeviceManager.shared.diagnosticPublisher")

            HStack(spacing: 10) {
                Menu {
                    Button("全部") { viewModel.codeFilter = nil }
                    Divider()
                    ForEach(DiagnosticConsoleViewModel.allCodes, id: \.self) { code in
                        Button(code.rawValue) { viewModel.codeFilter = code }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.codeFilter?.rawValue ?? "全部诊断码")
                            .font(.system(.caption, design: .monospaced))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                TextField("关键词过滤", text: $viewModel.keyword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack(spacing: 10) {
                Button(viewModel.isPaused ? "继续" : "暂停") {
                    viewModel.isPaused.toggle()
                }
                .demoGlassButton(size: .small)

                Button("清空") { viewModel.clear() }
                    .demoGlassButton(size: .small)

                Button("复制") { viewModel.copyAll() }
                    .demoGlassButton(size: .small)

                Toggle("自动滚动", isOn: $autoScroll)
                    .font(.caption)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            Text(viewModel.statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .demoGlassCard()
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var eventList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if viewModel.filteredRows.isEmpty {
                        emptyPane
                    } else {
                        ForEach(viewModel.filteredRows) { row in
                            DiagnosticRowView(row: row)
                                .id(row.id)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            // 用单调递增的追加计数而不是 rows.count：缓冲触顶后后者恒为上限，自动滚动会永久失效。
            .onChange(of: viewModel.appendCount) { _ in
                guard autoScroll, let last = viewModel.filteredRows.last else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var emptyPane: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("暂无诊断事件")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("SDK 只在出错时投递事件。协议交互、蓝牙收发与扫描明细属于内部日志，不经由此流对外。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

private struct DiagnosticRowView: View {
    let row: DiagnosticRow

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(row.timeText)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(row.codeText)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(row.codeColor)
                if let deviceText = row.deviceText {
                    Text(deviceText)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.secondary.opacity(0.12), in: Capsule())
                }
            }
            Text(row.event.message)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
}
