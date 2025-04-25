import Combine
import UIKit
import XLINKDevice

class DeviceDetailViewController: UIViewController {
    // MARK: - UI元素

    private let deviceNameLabel = UILabel()
    private let deviceTypeLabel = UILabel()
    private let deviceInfoTableView = UITableView(frame: .zero, style: .insetGrouped)
    private let disconnectButton = UIButton(type: .system)
    private let actionsStackView = UIStackView()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let progressLabel = UILabel()
    private let cancelTransferButton = UIButton(type: .system)

    // MARK: - 属性

    private let device: XLINKBikeComputerDevice
    private var isTransferring = false
    private var cancellables = Set<AnyCancellable>()
    private var deviceInfoItems: [(title: String, value: String)] = []

    // MARK: - 初始化

    init(device: XLINKBaseDevice) {
        self.device = device as! XLINKBikeComputerDevice
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        updateDeviceInfo()
        setupObservers()
    }

    // MARK: - UI设置

    private func setupUI() {
        title = "设备详情"
        view.backgroundColor = .systemGroupedBackground

        // 设备名称标签
        deviceNameLabel.translatesAutoresizingMaskIntoConstraints = false
        deviceNameLabel.font = .systemFont(ofSize: 24, weight: .bold)
        deviceNameLabel.textAlignment = .center
        deviceNameLabel.text = device.broadcastInfo.name ?? "未命名设备"
        view.addSubview(deviceNameLabel)

        // 设备类型标签
        deviceTypeLabel.translatesAutoresizingMaskIntoConstraints = false
        deviceTypeLabel.font = .systemFont(ofSize: 16)
        deviceTypeLabel.textAlignment = .center
        deviceTypeLabel.textColor = .secondaryLabel

        switch device.broadcastInfo.deviceType {
        case .bikeComputer:
            deviceTypeLabel.text = "智能码表"
        case .dfuMode:
            deviceTypeLabel.text = "DFU模式"
        case .unknown:
            deviceTypeLabel.text = "未知设备类型"
        @unknown default:
            deviceTypeLabel.text = "未知设备类型"
        }

        view.addSubview(deviceTypeLabel)

        // 设备信息表格视图
        deviceInfoTableView.translatesAutoresizingMaskIntoConstraints = false
        deviceInfoTableView.backgroundColor = .systemGroupedBackground
        view.addSubview(deviceInfoTableView)

        // 断开连接按钮
        disconnectButton.translatesAutoresizingMaskIntoConstraints = false
        disconnectButton.setTitle("断开连接", for: .normal)
        disconnectButton.setTitleColor(.white, for: .normal)
        disconnectButton.backgroundColor = .systemRed
        disconnectButton.layer.cornerRadius = 8
        disconnectButton.addTarget(self, action: #selector(disconnectDevice), for: .touchUpInside)
        view.addSubview(disconnectButton)

        // 进度条
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progress = 0
        progressView.isHidden = true
        view.addSubview(progressView)

        // 进度标签
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.font = .systemFont(ofSize: 12)
        progressLabel.textAlignment = .center
        progressLabel.textColor = .secondaryLabel
        progressLabel.isHidden = true
        view.addSubview(progressLabel)

        // 取消传输按钮
        cancelTransferButton.translatesAutoresizingMaskIntoConstraints = false
        cancelTransferButton.setTitle("取消传输", for: .normal)
        cancelTransferButton.setTitleColor(.white, for: .normal)
        cancelTransferButton.backgroundColor = .systemOrange
        cancelTransferButton.layer.cornerRadius = 8
        cancelTransferButton.addTarget(self, action: #selector(cancelTransfer), for: .touchUpInside)
        cancelTransferButton.isHidden = true
        view.addSubview(cancelTransferButton)

        // 操作按钮容器
        actionsStackView.translatesAutoresizingMaskIntoConstraints = false
        actionsStackView.axis = .vertical
        actionsStackView.distribution = .fillEqually
        actionsStackView.spacing = 10
        view.addSubview(actionsStackView)

        // 添加操作按钮
        let sendFileButton = createActionButton(title: "发送文件", action: #selector(sendFile))
        let receiveFileButton = createActionButton(title: "接收文件", action: #selector(receiveFile))
        let resetButton = createActionButton(title: "设备重置", action: #selector(resetDevice))
        let dfuButton = createActionButton(title: "DFU升级", action: #selector(enterDFU))
        let receiveFitButton = createActionButton(title: "获取Fit", action: #selector(receiveFitData))
        let deleteFitButton = createActionButton(title: "删除Fit", action: #selector(deleteFitData))
        let storageInfoButton = createActionButton(title: "设备存储信息", action: #selector(showDeviceStorageInfo))

        // 第一排按钮
        let firstRowStack = UIStackView(arrangedSubviews: [sendFileButton, receiveFileButton, resetButton])
        firstRowStack.axis = .horizontal
        firstRowStack.distribution = .fillEqually
        firstRowStack.spacing = 10
        // 第二排按钮
        let secondRowStack = UIStackView(arrangedSubviews: [dfuButton, receiveFitButton, deleteFitButton])
        secondRowStack.axis = .horizontal
        secondRowStack.distribution = .fillEqually
        secondRowStack.spacing = 10
        // 第三排按钮
        let thirdRowStack = UIStackView(arrangedSubviews: [storageInfoButton])
        thirdRowStack.axis = .horizontal
        thirdRowStack.distribution = .fillEqually
        thirdRowStack.spacing = 10
        // 添加到主StackView
        actionsStackView.addArrangedSubview(firstRowStack)
        actionsStackView.addArrangedSubview(secondRowStack)
        actionsStackView.addArrangedSubview(thirdRowStack)

        // 设置约束
        NSLayoutConstraint.activate([
            deviceNameLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            deviceNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            deviceNameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            deviceTypeLabel.topAnchor.constraint(equalTo: deviceNameLabel.bottomAnchor, constant: 8),
            deviceTypeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            deviceTypeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            deviceInfoTableView.topAnchor.constraint(equalTo: deviceTypeLabel.bottomAnchor, constant: 20),
            deviceInfoTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            deviceInfoTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            actionsStackView.topAnchor.constraint(equalTo: deviceInfoTableView.bottomAnchor, constant: 20),
            actionsStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            actionsStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            actionsStackView.heightAnchor.constraint(equalToConstant: 152),

            progressView.topAnchor.constraint(equalTo: actionsStackView.bottomAnchor, constant: 20),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            progressLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 4),
            progressLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            cancelTransferButton.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 8),
            cancelTransferButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelTransferButton.widthAnchor.constraint(equalToConstant: 120),
            cancelTransferButton.heightAnchor.constraint(equalToConstant: 36),

            disconnectButton.topAnchor.constraint(equalTo: cancelTransferButton.bottomAnchor, constant: 20),
            disconnectButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            disconnectButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            disconnectButton.heightAnchor.constraint(equalToConstant: 44),
            disconnectButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])
    }

    private func createActionButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 8
        button.titleLabel?.font = .systemFont(ofSize: 13)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.8
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func setupTableView() {
        deviceInfoTableView.dataSource = self
        deviceInfoTableView.delegate = self
        deviceInfoTableView.register(DeviceInfoCell.self, forCellReuseIdentifier: "DeviceInfoCell")
        deviceInfoTableView.isScrollEnabled = true
        deviceInfoTableView.estimatedRowHeight = 44
        deviceInfoTableView.rowHeight = UITableView.automaticDimension
    }

    // MARK: - 设备信息更新

    private func updateDeviceInfo() {
        // 构建设备信息列表
        deviceInfoItems = [
            ("设备ID", device.broadcastInfo.id),
            ("连接状态", getConnectionStateString(device.deviceState)),
            ("设备名称", device.broadcastInfo.name ?? "未知"),
            ("设备类型", getDeviceTypeString(device.broadcastInfo.deviceType)),
            ("设备型号", device.broadcastInfo.model ?? "未知"),
            ("固件版本", device.broadcastInfo.firmwareVersion ?? "未知"),
            ("硬件版本", device.broadcastInfo.hardwareVersion ?? "未知"),
            ("厂商", device.broadcastInfo.manufacturer ?? "未知"),
            ("信号强度", "\(device.broadcastInfo.rssi) dBm"),
            ("电池电量", device.batteryLevel != nil ? "\(device.batteryLevel!)%" : "未知"),
        ]

        deviceInfoTableView.reloadData()
    }

    private func getDeviceTypeString(_ type: XLINKBroadcastType) -> String {
        switch type {
        case .bikeComputer:
            return "智能码表"
        case .dfuMode:
            return "DFU模式"
        case .unknown:
            return "未知设备类型"
        @unknown default:
            return "未知设备类型"
        }
    }

    private func getConnectionStateString(_ state: XLINKDeviceState) -> String {
        // 设置连接状态
        switch state {
        case .offline:
            return "未连接"

        case .connecting:
            return "连接中..."

        case .disconnecting:
            return "断开中..."

        case .discoveringServices:
            return "发现服务中..."

        case .idle:
            return "已连接"

        case .busy:
            return "忙碌中..."

        case .recording:
            return "记录中..."

        case .syncing:
            return "同步中..."

        case .upgrading:
            return "升级中..."

        case .noResponse:
            return "未连接"
        }
    }

    // MARK: - 观察者设置

    private func setupObservers() {
        // 监听设备信息更新
        device.deviceInfoUpdatedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateDeviceInfo()
            }
            .store(in: &cancellables)

        // 监听电池电量更新
        device.batteryLevelPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateDeviceInfo()
            }
            .store(in: &cancellables)

        // 监听连接状态变化
        device.deviceStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateDeviceInfo()

                if state.isDisconnect {
                    self?.showAlert(title: "设备断开", message: "设备已断开连接") { _ in }
                }
            }
            .store(in: &cancellables)

        // 监听文件传输状态
        device.fileTransferProgressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] fileTransfer in
                switch fileTransfer.state {
                case .preparing:
                    self?.handleFileTransferState(state: .started)

                case let .transferring(progress):
                    self?.handleFileTransferState(state: .progress(progress))

                case .processing:
                    // 处理中状态可以显示为100%进度但尚未完成
                    self?.handleFileTransferState(state: .progress(1.0))
                    self?.progressLabel.text = "处理中:"

                case .deleting:
                    self?.progressLabel.text = "删除中: "

                case .completed:
                    self?.handleFileTransferState(state: .completed)

                case let .failed(error):
                    self?.handleFileTransferState(state: .failed(error))
                }
            }
            .store(in: &cancellables)

        // 监听文件传输进度
        device.fileTransferProgressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.handleFileTransferProgress(progress)
            }
            .store(in: &cancellables)
    }

    // 处理文件传输进度更新
    private func handleFileTransferProgress(_ progress: FileTransferProgress) {
        // 显示进度条
        progressView.isHidden = false
        progressLabel.isHidden = false

        // 根据传输状态显示或隐藏取消按钮
        switch progress.state {
        case .preparing, .transferring, .processing:
            cancelTransferButton.isHidden = false
        default:
            cancelTransferButton.isHidden = true
        }

        // 更新进度条值
        progressView.progress = Float(progress.progress)

        // 更新状态标签
        switch progress.state {
        case .preparing:
            progressLabel.text = "准备传输:"
            isTransferring = true

        case .transferring:
            progressLabel.text = "传输中:  (\(Int(progress.progress * 100))%)"
            isTransferring = true

        case .processing:
            progressLabel.text = "处理中: "
            isTransferring = true

        case .deleting:
            progressLabel.text = "删除中: "
            isTransferring = true

        case .completed:
            progressLabel.text = "传输完成: "
            progressView.progress = 1.0
            isTransferring = false

            // 延迟隐藏进度条和取消按钮
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.progressView.isHidden = true
                self?.progressLabel.isHidden = true
                self?.cancelTransferButton.isHidden = true
            }

        case let .failed(error):
            progressLabel.text = "传输失败: \(error.localizedDescription)"
            isTransferring = false

            // 延迟隐藏进度条和取消按钮
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.progressView.isHidden = true
                self?.progressLabel.isHidden = true
                self?.cancelTransferButton.isHidden = true
            }
        }
    }

    // MARK: - 文件传输处理

    private func handleFileTransferState(state: FileTransferState) {
        switch state {
        case .started:
            progressView.isHidden = false
            progressLabel.isHidden = false
            cancelTransferButton.isHidden = false
            progressView.progress = 0
            progressLabel.text = "开始传输:"
            isTransferring = true

        case let .progress(progress):
            progressView.isHidden = false
            progressLabel.isHidden = false
            cancelTransferButton.isHidden = false
            progressView.progress = Float(progress)
            progressLabel.text = "传输中: (\(Int(progress * 100))%)"

        case .completed:
            progressView.isHidden = false
            progressLabel.isHidden = false
            cancelTransferButton.isHidden = true
            progressView.progress = 1.0
            progressLabel.text = "传输完成: "
            isTransferring = false

            // 延迟隐藏进度条
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.progressView.isHidden = true
                self?.progressLabel.isHidden = true
            }

        case let .failed(error):
            progressView.isHidden = false
            progressLabel.isHidden = false
            cancelTransferButton.isHidden = true
            progressLabel.text = "传输失败: \(error.localizedDescription)"
            isTransferring = false

            // 延迟隐藏进度条
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.progressView.isHidden = true
                self?.progressLabel.isHidden = true
            }
        }
    }

    // MARK: - 设备操作

    @objc private func disconnectDevice() {
        device.disconnect()
    }

    @objc private func sendFile() {
        guard !isTransferring else {
            showAlert(title: "错误", message: "当前有正在进行的传输任务")
            return
        }

        // 准备UI
        progressView.isHidden = false
        progressLabel.isHidden = false
        progressView.progress = 0
        progressLabel.text = "准备发送用户配置..."
        isTransferring = true

        // 在实际应用中，应该使用文件选择器让用户选择文件
        Task {
            do {
                guard let profile = try? await device.getUserProfile() else {
                    throw NSError(domain: "获取用户配置失败", code: -1, userInfo: nil)
                }
                _ = try await device.sendUserProfile(profile)
                // 注意：实际传输状态和进度会通过fileTransferPublisher返回
            } catch let error as XLINKDeviceError {
                debugPrint("文件发送失败: \(error.localizedDescription)")
                await MainActor.run {
                    self.handleFileTransferState(state: .failed(error))
                }
            }
        }
    }

    @objc private func receiveFile() {
        guard !isTransferring else {
            showAlert(title: "错误", message: "当前有正在进行的传输任务")
            return
        }

        // 在实际应用中，应该让用户输入要接收的文件名
        // 这里仅演示API调用方式
        let alert = UIAlertController(title: "选择接收文件", message: nil, preferredStyle: .actionSheet)

        // 定义通用的处理函数
        func handleFileFetch<T: Encodable>(
            action: @escaping () async throws -> T,
            successTitle: String,
            filename: String
        ) {
            // 准备UI
            progressView.isHidden = false
            progressLabel.isHidden = false
            progressView.progress = 0
            progressLabel.text = "准备接收\(filename)..."
            isTransferring = true

            Task {
                do {
                    let data = try await action()
                    let jsonData = try JSONEncoder().encode(data)
                    let jsonString = String(data: jsonData, encoding: .utf8) ?? "无法解析为字符串"
                    showResultAlert(title: successTitle, message: "\(jsonString)")
                } catch let error as XLINKDeviceError {
                    debugPrint("文件接收失败: \(error.localizedDescription)")
                    await MainActor.run {
                        self.handleFileTransferState(state: .failed(error))
                    }
                    showResultAlert(title: "文件接收失败", message: error.localizedDescription)
                }
            }
        }

        // 统一的结果显示方法
        @MainActor
        func showResultAlert(title: String, message: String) {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
        }

        // 添加动作
        alert.addAction(UIAlertAction(title: "获取用户配置", style: .default) { _ in
            handleFileFetch(action: self.device.getUserProfile, successTitle: "文件接收成功", filename: "用户配置")
        })
        alert.addAction(UIAlertAction(title: "获取系统配置", style: .default) { _ in
            handleFileFetch(action: self.device.getSettings, successTitle: "文件接收成功", filename: "系统配置")
        })
        alert.addAction(UIAlertAction(title: "获取单车配置", style: .default) { _ in
            handleFileFetch(action: self.device.getGearProfile, successTitle: "文件接收成功", filename: "单车配置")
        })
        alert.addAction(UIAlertAction(title: "获取表盘配置", style: .default) { _ in
            handleFileFetch(action: self.device.getPanels, successTitle: "文件接收成功", filename: "表盘配置")
        })
        alert.addAction(UIAlertAction(title: "获取轨迹文件", style: .default) { _ in
            handleFileFetch(action: self.device.getWorkouts, successTitle: "文件接收成功", filename: "轨迹文件")
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func resetDevice() {
        let alert = UIAlertController(
            title: "设备重置",
            message: "确定要重置设备吗？此操作将恢复设备出厂设置，且无法撤销。",
            preferredStyle: .actionSheet
        )

        // 取消按钮
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        // 重置选项
        for (title, type) in [
            ("重启", XLINKResetMode.restart),
            ("恢复出厂设置", XLINKResetMode.factoryReset),
            ("格式化存储", XLINKResetMode.formatStorage),
        ] {
            alert.addAction(UIAlertAction(title: title, style: .destructive) { [weak self] _ in
                Task {
                    guard let self = self else { return }

                    do {
                        try await self.device.resetDevice(type)
                        await MainActor.run {
                            self.showAlert(
                                title: "重置命令已发送",
                                message: "设备正在\(type == .restart ? "重启" : type == .factoryReset ? "恢复出厂设置" : "格式化存储")"
                            )
                        }
                    } catch {
                        await MainActor.run {
                            self.showAlert(title: "重置失败", message: error.localizedDescription)
                        }
                    }
                }
            })
        }

        present(alert, animated: true)
    }

    @objc private func enterDFU() {
        guard let firmwareURL = Bundle.main.url(forResource: "N9_V1.09.3069_APP_DFU_250421_175427", withExtension: "zip") else {
            return
        }
        // 跳转到DFU进度页面
        let dfuVC = DFUProgressViewController(device: device, firmwareURL: firmwareURL)
        navigationController?.pushViewController(dfuVC, animated: true)
    }

    @objc private func cancelDownload() {
        // 获取并取消下载任务
        if let downloadTask = objc_getAssociatedObject(self, "currentDownloadTask") as? URLSessionDownloadTask {
            downloadTask.cancel()
            progressView.isHidden = true
            progressLabel.isHidden = true
            cancelTransferButton.isHidden = true
            showAlert(title: "下载取消", message: "固件下载已取消")
        }
    }

    @objc private func receiveFitData() {
        let alert = UIAlertController(
            title: "获取单条FIT数据",
            message: "确定要获取当前设备的单条FIT数据吗？",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            Task {
                guard let self = self else { return }

                do {
                    let workouts = try await self.device.getWorkouts()
                    if workouts.isEmpty {
                        await MainActor.run {
                            self.showAlert(title: "获取失败", message: "没有FIT数据可供获取")
                        }
                        return
                    }
                    // 等待500ms以确保数据准备好
                    try await Task.sleep(nanoseconds: 500_000_000)
                    let fitData = try await self.device.syncWorkout(workouts.last!)
                    await MainActor.run {
                        self.showAlert(title: "获取成功", message: "FIT数据：\(fitData)")
                    }
                } catch {
                    await MainActor.run {
                        self.showAlert(title: "获取失败", message: error.localizedDescription)
                    }
                }
            }
        })

        present(alert, animated: true)
    }

    @objc private func deleteFitData() {
        let alert = UIAlertController(
            title: "删除FIT文件",
            message: "确定要删除设备上的最后一条FIT数据吗？此操作不可恢复！",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .destructive) { [weak self] _ in
            Task {
                guard let self = self else { return }

                do {
                    // 获取workout列表
                    let workouts = try await self.device.getWorkouts()
                    if workouts.isEmpty {
                        await MainActor.run {
                            self.showAlert(title: "删除失败", message: "没有FIT数据可供删除")
                        }
                        return
                    }

                    // 获取最后一个workout并删除
                    let lastWorkout = workouts.last!
                    let result = try await self.device.deleteWorkout(lastWorkout)

                    await MainActor.run {
                        if result {
                            self.showAlert(title: "删除成功", message: "已成功删除文件：\(lastWorkout.formatName)")
                        } else {
                            self.showAlert(title: "删除失败", message: "设备返回删除失败")
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.showAlert(title: "删除失败", message: error.localizedDescription)
                    }
                }
            }
        })

        present(alert, animated: true)
    }

    @objc private func cancelTransfer() {
        let alert = UIAlertController(
            title: "取消传输",
            message: "确定要取消当前文件传输吗？",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .destructive) { [weak self] _ in
            Task {
                guard let self = self else { return }

                do {
                    try await self.device.cancelFileTransfer()
                    // 取消传输的UI更新会通过fileTransferPublisher来处理
                } catch {
                    await MainActor.run {
                        self.showAlert(title: "取消传输失败", message: error.localizedDescription)
                    }
                }
            }
        })

        present(alert, animated: true)
    }

    @objc private func showDeviceStorageInfo() {
        Task {
            do {
                let (remain, total) = try await device.requestDeviceStorage()
                let remainMB = ByteCountFormatter.string(fromByteCount: Int64(remain) * 1024, countStyle: .decimal)
                let totalMB = ByteCountFormatter.string(fromByteCount: Int64(total) * 1024, countStyle: .decimal)
                let message = "总容量：\(totalMB)\n剩余容量：\(remainMB)"
                await MainActor.run {
                    self.showAlert(title: "设备存储信息", message: message)
                }
            } catch {
                await MainActor.run {
                    self.showAlert(title: "获取失败", message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - 工具方法

    private func showAlert(title: String, message: String, handler: ((UIAlertAction) -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: handler))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate

extension DeviceDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return deviceInfoItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceInfoCell", for: indexPath) as! DeviceInfoCell
        let item = deviceInfoItems[indexPath.row]
        cell.configure(title: item.title, value: item.value)
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "设备信息"
    }
}

// MARK: - 自定义设备信息Cell

class DeviceInfoCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        selectionStyle = .none

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16)
        titleLabel.textColor = .label
        contentView.addSubview(titleLabel)

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .systemFont(ofSize: 16)
        valueLabel.textColor = .secondaryLabel
        valueLabel.textAlignment = .right
        valueLabel.numberOfLines = 0
        contentView.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            titleLabel.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.4),

            valueLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 10),
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            valueLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            valueLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    func configure(title: String, value: String) {
        titleLabel.text = title
        valueLabel.text = value
    }
}

// MARK: - 文件传输状态枚举

enum FileTransferState {
    case started
    case progress(Double)
    case completed
    case failed(Error)
}
