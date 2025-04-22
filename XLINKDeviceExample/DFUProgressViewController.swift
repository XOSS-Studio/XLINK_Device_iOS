import Combine
import UIKit
import XLINKDevice

/// 固件升级进度页面
class DFUProgressViewController: UIViewController {
    private let device: XLINKBikeComputerDevice
    private let firmwareURL: URL
    private var cancellables = Set<AnyCancellable>()

    // UI元素
    private let statusLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let progressLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    // MARK: - 初始化

    /// 初始化DFU升级页面
    /// - Parameters:
    ///   - device: 要升级的设备
    ///   - firmwareURL: 固件文件URL（本地或远程）
    init(device: XLINKBikeComputerDevice, firmwareURL: URL) {
        self.device = device
        self.firmwareURL = firmwareURL
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startFirmwareUpdate()
        observeFirmwareUpdate()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "固件升级"

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 18, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.text = "准备升级..."
        view.addSubview(statusLabel)

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progress = 0
        view.addSubview(progressView)

        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.font = .systemFont(ofSize: 14)
        progressLabel.textAlignment = .center
        progressLabel.text = "0%"
        view.addSubview(progressLabel)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("关闭", for: .normal)
        closeButton.isHidden = true
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            progressView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 40),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            progressLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 8),
            progressLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            closeButton.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 40),
            closeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            closeButton.widthAnchor.constraint(equalToConstant: 120),
        ])
    }

    private func startFirmwareUpdate() {
        Task {
            do {
                // 直接使用传入的固件URL进行更新
                try await device.updateFirmware(firmwareURL: firmwareURL)
            } catch {
                await MainActor.run {
                    self.statusLabel.text = "固件升级失败: \(error.localizedDescription)"
                    self.closeButton.isHidden = false
                }
            }
        }
    }

    private func observeFirmwareUpdate() {
        device.firmwareUpdateProgressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                guard let self = self else { return }

                // 更新进度显示
                self.progressView.progress = Float(progress.progress / 100)
                self.progressLabel.text = String(format: "%.0f%%", progress.progress)

                // 根据状态更新UI
                switch progress.state {
                case .initial:
                    self.statusLabel.text = "初始状态"

                case .preparingDFU:
                    self.statusLabel.text = "准备进入DFU模式..."

                case .searchingDFUDevice:
                    self.statusLabel.text = "搜索DFU设备..."

                case .connectingDFUDevice:
                    self.statusLabel.text = "连接DFU设备..."

                case .transferring:
                    self.statusLabel.text = "固件上传中..."

                case .validating:
                    self.statusLabel.text = "固件验证中..."

                case .completed:
                    self.statusLabel.text = "升级完成！"
                    self.closeButton.isHidden = false

                case let .failed(error):
                    self.statusLabel.text = "升级失败: \(error.localizedDescription)"
                    self.closeButton.isHidden = false
                }
            }
            .store(in: &cancellables)
    }

    @objc private func closeTapped() {
        navigationController?.popViewController(animated: true)
    }
}
