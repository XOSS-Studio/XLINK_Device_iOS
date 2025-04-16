import Combine
import CoreBluetooth
import UIKit
import XLINKDevice

class ViewController: UIViewController {
    // MARK: - UI元素

    private let statusLabel = UILabel()
    private let bluetoothStatusLabel = UILabel()
    private let authExpiryLabel = UILabel()
    private let apiKeyTextField = UITextField()
    private let authorizeButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)

    // MARK: - 属性

    private var cancellables = Set<AnyCancellable>()
    private let deviceManager = XLINKDeviceManager.shared

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupObservers()
        updateStatus()
    }

    // MARK: - UI设置

    private func setupUI() {
        title = "XLINK设备SDK"
        view.backgroundColor = .systemBackground

        // 状态标签
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textAlignment = .center
        statusLabel.font = .systemFont(ofSize: 18, weight: .medium)
        statusLabel.numberOfLines = 0
        view.addSubview(statusLabel)

        // 蓝牙状态标签
        bluetoothStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        bluetoothStatusLabel.textAlignment = .center
        bluetoothStatusLabel.font = .systemFont(ofSize: 16)
        bluetoothStatusLabel.numberOfLines = 0
        view.addSubview(bluetoothStatusLabel)

        // 授权过期时间标签
        authExpiryLabel.translatesAutoresizingMaskIntoConstraints = false
        authExpiryLabel.textAlignment = .center
        authExpiryLabel.font = .systemFont(ofSize: 14)
        authExpiryLabel.textColor = .secondaryLabel
        authExpiryLabel.numberOfLines = 0
        view.addSubview(authExpiryLabel)

        // API Key输入框
        apiKeyTextField.translatesAutoresizingMaskIntoConstraints = false
        apiKeyTextField.placeholder = "请输入API Key"
        apiKeyTextField.borderStyle = .roundedRect
        apiKeyTextField.text = "" // 默认值
        view.addSubview(apiKeyTextField)

        // 授权按钮
        authorizeButton.translatesAutoresizingMaskIntoConstraints = false
        authorizeButton.setTitle("授权SDK", for: .normal)
        authorizeButton.backgroundColor = .systemBlue
        authorizeButton.setTitleColor(.white, for: .normal)
        authorizeButton.layer.cornerRadius = 8
        authorizeButton.addTarget(self, action: #selector(authorizeSDK), for: .touchUpInside)
        view.addSubview(authorizeButton)

        // 下一步按钮
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.setTitle("进入设备列表", for: .normal)
        nextButton.backgroundColor = .systemGreen
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.layer.cornerRadius = 8
        nextButton.addTarget(self, action: #selector(navigateToDeviceList), for: .touchUpInside)
        nextButton.isEnabled = false
        view.addSubview(nextButton)

        // 约束设置
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            bluetoothStatusLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            bluetoothStatusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            bluetoothStatusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            authExpiryLabel.topAnchor.constraint(equalTo: bluetoothStatusLabel.bottomAnchor, constant: 20),
            authExpiryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            authExpiryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            apiKeyTextField.topAnchor.constraint(equalTo: authExpiryLabel.bottomAnchor, constant: 40),
            apiKeyTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            apiKeyTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            apiKeyTextField.heightAnchor.constraint(equalToConstant: 44),

            authorizeButton.topAnchor.constraint(equalTo: apiKeyTextField.bottomAnchor, constant: 20),
            authorizeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            authorizeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            authorizeButton.heightAnchor.constraint(equalToConstant: 44),

            nextButton.topAnchor.constraint(equalTo: authorizeButton.bottomAnchor, constant: 20),
            nextButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nextButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            nextButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    // MARK: - 观察者设置

    private func setupObservers() {
        // 监听蓝牙状态变化
        deviceManager.bluetoothStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateBluetoothStatus(state)
            }
            .store(in: &cancellables)

        // 监听SDK初始化完成
        deviceManager.initCompletedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatus()
            }
            .store(in: &cancellables)

        // 监听授权有效期变更
        deviceManager.authExpirationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] expirationDate in
                self?.updateAuthExpiryInfo(with: expirationDate)
            }
            .store(in: &cancellables)
    }

    // MARK: - 状态更新

    private func updateStatus() {
        if deviceManager.isInitialized {
            if deviceManager.isAuthenticated {
                statusLabel.text = "SDK状态: 已授权 ✅"
                statusLabel.textColor = .systemGreen
                nextButton.isEnabled = true
            } else {
                statusLabel.text = "SDK状态: 授权失败 ❌"
                statusLabel.textColor = .systemRed
                nextButton.isEnabled = false
            }
        } else {
            statusLabel.text = "SDK状态: 未初始化"
            statusLabel.textColor = .systemOrange
            nextButton.isEnabled = false
        }

        updateBluetoothStatus(deviceManager.bluetoothState)
        updateAuthExpiryInfo()
    }

    private func updateBluetoothStatus(_ state: CBManagerState) {
        switch state {
        case .poweredOn:
            bluetoothStatusLabel.text = "蓝牙状态: 已开启 ✅"
            bluetoothStatusLabel.textColor = .systemGreen
        case .poweredOff:
            bluetoothStatusLabel.text = "蓝牙状态: 已关闭 ❌"
            bluetoothStatusLabel.textColor = .systemRed
        case .unauthorized:
            bluetoothStatusLabel.text = "蓝牙状态: 未授权 ⚠️"
            bluetoothStatusLabel.textColor = .systemOrange
        case .unsupported:
            bluetoothStatusLabel.text = "蓝牙状态: 不支持 ❌"
            bluetoothStatusLabel.textColor = .systemRed
        case .resetting:
            bluetoothStatusLabel.text = "蓝牙状态: 重置中 ⚠️"
            bluetoothStatusLabel.textColor = .systemOrange
        case .unknown:
            bluetoothStatusLabel.text = "蓝牙状态: 未知 ❓"
            bluetoothStatusLabel.textColor = .systemGray
        @unknown default:
            bluetoothStatusLabel.text = "蓝牙状态: 未知状态 ❓"
            bluetoothStatusLabel.textColor = .systemGray
        }
    }

    private func updateAuthExpiryInfo() {
        // 使用XLINKDeviceManager方法获取授权有效期
        if deviceManager.isAuthenticated {
            if let expirationDate = deviceManager.getAuthExpirationDate() {
                updateAuthExpiryInfo(with: expirationDate)
            } else {
                let remainingTime = deviceManager.getAuthRemainingTime()
                let expiryDate = Date().addingTimeInterval(remainingTime)
                updateAuthExpiryInfo(with: expiryDate)
            }
        } else {
            authExpiryLabel.text = "授权有效期: 未授权"
        }
    }

    private func updateAuthExpiryInfo(with expirationDate: Date?) {
        if let expirationDate = expirationDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .medium
            let expiryDateString = dateFormatter.string(from: expirationDate)

            // 计算剩余时间
            let remainingTime = expirationDate.timeIntervalSince(Date())

            if remainingTime <= 0 {
                authExpiryLabel.text = "授权已过期"
                authExpiryLabel.textColor = .systemRed
            } else {
                // 格式化剩余时间
                let days = Int(remainingTime / 86400)
                let hours = Int((remainingTime.truncatingRemainder(dividingBy: 86400)) / 3600)
                let minutes = Int((remainingTime.truncatingRemainder(dividingBy: 3600)) / 60)

                if days > 0 {
                    authExpiryLabel.text = "授权有效期至: \(expiryDateString) (剩余\(days)天\(hours)小时)"
                } else if hours > 0 {
                    authExpiryLabel.text = "授权有效期至: \(expiryDateString) (剩余\(hours)小时\(minutes)分钟)"
                } else {
                    authExpiryLabel.text = "授权有效期至: \(expiryDateString) (剩余\(minutes)分钟)"
                }

                // 根据剩余时间设置颜色
                if days < 1 {
                    authExpiryLabel.textColor = .systemOrange
                } else {
                    authExpiryLabel.textColor = .secondaryLabel
                }
            }
        } else {
            authExpiryLabel.text = "授权有效期: 未授权"
            authExpiryLabel.textColor = .systemRed
        }
    }

    // MARK: - 按钮事件

    @objc private func authorizeSDK() {
        guard let apiKey = apiKeyTextField.text, !apiKey.isEmpty else {
            showAlert(title: "错误", message: "请输入有效的API Key")
            return
        }

        // 禁用按钮，显示加载状态
        authorizeButton.isEnabled = false
        authorizeButton.setTitle("授权中...", for: .normal)

        Task {
            do {
                let result = try await deviceManager.initialize(apiKey: apiKey)

                // 返回主线程更新UI
                await MainActor.run {
                    authorizeButton.isEnabled = true
                    authorizeButton.setTitle("授权SDK", for: .normal)

                    if result {
                        showAlert(title: "成功", message: "SDK授权成功")
                    } else {
                        showAlert(title: "失败", message: "SDK授权失败")
                    }

                    updateStatus()
                }
            } catch let error as XLINKDeviceError {
                await MainActor.run {
                    authorizeButton.isEnabled = true
                    authorizeButton.setTitle("授权SDK", for: .normal)
                    showAlert(title: "错误", message: "授权失败: \(error.localizedDescription)")
                    updateStatus()
                }
            } catch {
                await MainActor.run {
                    authorizeButton.isEnabled = true
                    authorizeButton.setTitle("授权SDK", for: .normal)
                    showAlert(title: "错误", message: "未知错误: \(error.localizedDescription)")
                    updateStatus()
                }
            }
        }
    }

    @objc private func navigateToDeviceList() {
        let deviceListVC = DeviceListViewController()
        navigationController?.pushViewController(deviceListVC, animated: true)
    }

    // MARK: - 工具方法

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
