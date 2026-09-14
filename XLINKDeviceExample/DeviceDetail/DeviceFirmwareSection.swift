//
//  DeviceFirmwareSection.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-10.
//

import SwiftUI
import UniformTypeIdentifiers
import XLINKDevice

/// 固件段：版本信息、进入 DFU 模式、选择固件并升级。
struct DeviceFirmwareSection: View {
    let device: XLINKBikeComputerDevice
    @ObservedObject var viewModel: DeviceDetailViewModel
    @ObservedObject var state: DeviceFirmwareState
    @State private var isShowingFileImporter = false

    /// 随 Demo 打包的示例固件。文件名保留型号与固件版本，方便核对目标设备是否匹配——
    /// 这正是不把它改名成 ota.zip 之类通用名的原因。
    private static let bundledFirmwareName = "N9_V1.09.3075_APP_DFU_250506_153501"
    private static let bundledFirmwareURL = Bundle.main.url(forResource: bundledFirmwareName, withExtension: "zip")

    var body: some View {
        VStack(spacing: 24) {
            versionSection
            dfuModeSection
            updateSection
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [UTType(filenameExtension: "zip") ?? .archive],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                state.selectFirmware(at: url)
            case let .failure(error):
                viewModel.alert = DemoAlert(title: "选择固件失败", message: error.localizedDescription)
            }
        }
    }

    private var availability: (isEnabled: Bool, reason: String?) {
        viewModel.actionAvailability()
    }

    private var selectedFirmwareURL: URL? {
        state.selectedFirmwareURL ?? Self.bundledFirmwareURL
    }

    private var disabledUpdateReason: String {
        if let reason = availability.reason { return reason }
        return "请先选择固件包"
    }

    private var versionSection: some View {
        DemoSection("版本信息") {
            VStack(spacing: 0) {
                DemoValueRow(title: "固件版本", value: device.broadcastInfo.firmwareVersion ?? "未读取")
                Divider()
                DemoValueRow(title: "硬件版本", value: device.broadcastInfo.hardwareVersion ?? "未读取")
                Divider()
                DemoValueRow(title: "产品 ID", value: device.broadcastInfo.modelId ?? "未携带")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .demoGlassCard()
        }
    }

    private var dfuModeSection: some View {
        DemoSection("DFU 模式") {
            DemoActionCard(
                title: "进入 DFU 模式",
                signature: "try await device.enterDFUMode()",
                note: "设备会重启并以 DFU 名称重新广播。之后回到设备页重新扫描，连接那台 DFU 设备再升级。",
                actionTitle: "进入 DFU",
                isEnabled: availability.isEnabled,
                disabledReason: availability.reason,
                result: state.enterDFUResult,
                action: { state.enterDFUMode(device: device, viewModel: viewModel) }
            )
        }
    }

    private var updateSection: some View {
        DemoSection("固件升级", subtitle: "升级过程中请勿断开设备") {
            VStack(alignment: .leading, spacing: 12) {
                DemoSignatureLabel(signature: "try await device.updateFirmware(firmwareURL:)")

                DemoValueRow(
                    title: "固件文件",
                    value: selectedFirmwareURL?.lastPathComponent ?? "未找到",
                    valueColor: selectedFirmwareURL == nil ? .orange : .primary
                )

                if let selectionError = state.selectionError {
                    Text(selectionError)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if selectedFirmwareURL == nil {
                    Text("Demo 未内置示例固件，请手动选择一个固件包。")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                HStack(spacing: 10) {
                    Button("选择固件包") { isShowingFileImporter = true }
                        .demoGlassButton(size: .small)
                    if state.selectedFirmwareURL != nil {
                        Button("用内置固件") {
                            state.selectedFirmwareURL = nil
                            state.selectionError = nil
                        }
                            .demoGlassButton(size: .small)
                    }
                }

                if let url = selectedFirmwareURL, availability.isEnabled {
                    Button {
                        viewModel.firmwareSession = FirmwareSession(url: url)
                    } label: {
                        Text("开始升级")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .demoProminentButton(size: .regular)
                } else {
                    Text(disabledUpdateReason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .demoGlassCard()
        }
    }
}

@MainActor
final class DeviceFirmwareState: ObservableObject {
    @Published var enterDFUResult = DemoActionResult.idle
    @Published var selectedFirmwareURL: URL?
    /// 选择固件失败的说明。为空表示没有失败。
    @Published var selectionError: String?

    /// 文件选择器返回的是安全作用域 URL。离开 `startAccessingSecurityScopedResource()`
    /// 区间后，连 `FileManager.fileExists` 都会返回 false，SDK 拿到它会直接以
    /// `invalidParameter` 结束升级。而一次升级要跨越「下发进入 DFU、设备重启、
    /// 重新搜索并连接 DFU 设备、传输」几十秒，让作用域一路开着既脆弱也没必要，
    /// 所以在选中时就拷进应用沙盒，之后一律传普通 file URL。
    func selectFirmware(at url: URL) {
        do {
            selectedFirmwareURL = try Self.copyIntoSandbox(url)
            selectionError = nil
        } catch {
            selectedFirmwareURL = nil
            selectionError = "读取固件包失败：\(error.localizedDescription)"
        }
    }

    private static func copyIntoSandbox(_ url: URL) throws -> URL {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent("SelectedFirmware", isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(url.lastPathComponent)
        if manager.fileExists(atPath: destination.path) {
            try manager.removeItem(at: destination)
        }
        try manager.copyItem(at: url, to: destination)
        return destination
    }

    func enterDFUMode(device: XLINKBikeComputerDevice, viewModel: DeviceDetailViewModel) {
        viewModel.beginWork("进入 DFU 模式")
        Task {
            await DemoActionRunner.run(
                self,
                \.enterDFUResult,
                successSummary: "命令已下发，设备将重启进入 DFU 模式",
                operation: { try await device.enterDFUMode() }
            )
            viewModel.endWork()
        }
    }
}
