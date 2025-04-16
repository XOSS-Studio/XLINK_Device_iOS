import Combine
import CoreBluetooth
import UIKit
import XLINKDevice

class DeviceListViewController: UIViewController {
    // MARK: - UI元素

    private let tableView = UITableView()
    private let scanButton = UIButton(type: .system)
    private let autoScanSwitch = UISwitch()
    private let autoScanLabel = UILabel()
    private let scanStatusLabel = UILabel()

    // MARK: - 属性

    private var cancellables = Set<AnyCancellable>()
    private let deviceManager = XLINKDeviceManager.shared
    private var devices: [XLINKBaseDevice] = []
    private var isScanning = false
    private var scanTimer: Timer?

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupObservers()
        setupTableView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateScanStatus()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    // MARK: - UI设置

    private func setupUI() {
        title = "设备列表"
        view.backgroundColor = .systemBackground

        // 扫描状态标签
        scanStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        scanStatusLabel.textAlignment = .center
        scanStatusLabel.font = .systemFont(ofSize: 14)
        scanStatusLabel.textColor = .secondaryLabel
        scanStatusLabel.text = "未扫描"
        view.addSubview(scanStatusLabel)

        // 扫描按钮
        scanButton.translatesAutoresizingMaskIntoConstraints = false
        scanButton.setTitle("开始扫描", for: .normal)
        scanButton.backgroundColor = .systemBlue
        scanButton.setTitleColor(.white, for: .normal)
        scanButton.layer.cornerRadius = 8
        scanButton.addTarget(self, action: #selector(toggleScan), for: .touchUpInside)
        view.addSubview(scanButton)

        // 自动扫描开关标签
        autoScanLabel.translatesAutoresizingMaskIntoConstraints = false
        autoScanLabel.text = "自动扫描"
        autoScanLabel.font = .systemFont(ofSize: 16)
        view.addSubview(autoScanLabel)

        // 自动扫描开关
        autoScanSwitch.translatesAutoresizingMaskIntoConstraints = false
        autoScanSwitch.addTarget(self, action: #selector(autoScanSwitchChanged), for: .valueChanged)
        view.addSubview(autoScanSwitch)

        // 表格视图
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .systemBackground
        tableView.separatorStyle = .singleLine
        view.addSubview(tableView)

        // 约束设置
        NSLayoutConstraint.activate([
            scanStatusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            scanStatusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scanStatusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scanButton.topAnchor.constraint(equalTo: scanStatusLabel.bottomAnchor, constant: 10),
            scanButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scanButton.heightAnchor.constraint(equalToConstant: 44),
            scanButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6, constant: -30),

            autoScanLabel.centerYAnchor.constraint(equalTo: scanButton.centerYAnchor),
            autoScanLabel.leadingAnchor.constraint(equalTo: scanButton.trailingAnchor, constant: 20),

            autoScanSwitch.centerYAnchor.constraint(equalTo: autoScanLabel.centerYAnchor),
            autoScanSwitch.leadingAnchor.constraint(equalTo: autoScanLabel.trailingAnchor, constant: 10),
            autoScanSwitch.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: scanButton.bottomAnchor, constant: 20),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(DeviceCell.self, forCellReuseIdentifier: "DeviceCell")
        tableView.rowHeight = 80
        tableView.tableFooterView = UIView()
    }

    // MARK: - 观察者设置

    private func setupObservers() {
        // 监听设备发现
        deviceManager.deviceDiscoveredPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] device in
                self?.deviceDiscovered(device)
            }
            .store(in: &cancellables)

        // 监听连接状态变化
        deviceManager.deviceConnectionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] device, state in
                self?.deviceConnectionChanged(device, state: state)
            }
            .store(in: &cancellables)
    }

    // MARK: - 扫描控制

    @objc private func toggleScan() {
        if isScanning {
            stopScanning()
        } else {
            startScanning()
        }
    }

    private func startScanning() {
        guard !isScanning else { return }

        let success = deviceManager.startScan(timeout: 10.0)
        if success {
            isScanning = true
            scanButton.setTitle("停止扫描", for: .normal)
            scanButton.backgroundColor = .systemRed

            scanStatusLabel.text = "正在扫描设备..."
            scanStatusLabel.textColor = .systemBlue

            // 设置10秒后自动停止
            scanTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false, block: { [weak self] _ in
                self?.stopScanning()
            })
        } else {
            showAlert(title: "错误", message: "无法开始扫描，请检查蓝牙状态和授权状态")
        }
    }

    private func stopScanning() {
        guard isScanning else { return }

        deviceManager.stopScan()
        isScanning = false
        scanButton.setTitle("开始扫描", for: .normal)
        scanButton.backgroundColor = .systemBlue

        scanStatusLabel.text = "扫描已停止，已发现 \(devices.count) 个设备"
        scanStatusLabel.textColor = .secondaryLabel

        scanTimer?.invalidate()
        scanTimer = nil
    }

    @objc private func autoScanSwitchChanged() {
        if autoScanSwitch.isOn {
            // 启用自动扫描
            startScanning()
        } else {
            // 禁用自动扫描
            stopScanning()
        }
    }

    private func updateScanStatus() {
        isScanning = deviceManager.isScanning

        if isScanning {
            scanButton.setTitle("停止扫描", for: .normal)
            scanButton.backgroundColor = .systemRed
            scanStatusLabel.text = "正在扫描设备..."
            scanStatusLabel.textColor = .systemBlue
        } else {
            scanButton.setTitle("开始扫描", for: .normal)
            scanButton.backgroundColor = .systemBlue
            scanStatusLabel.text = "扫描已停止，已发现 \(devices.count) 个设备"
            scanStatusLabel.textColor = .secondaryLabel
        }
    }

    // MARK: - 设备处理

    private func deviceDiscovered(_ device: XLINKBaseDevice) {
        // 检查设备是否已存在
        if !devices.contains(where: { $0.broadcastInfo.id == device.broadcastInfo.id }) {
            devices.append(device)
            devices.sort { $0.broadcastInfo.rssi > $1.broadcastInfo.rssi } // 按信号强度排序
            tableView.reloadData()
        } else {
            // 如果设备已存在，更新RSSI和其他可能变化的信息
            if let index = devices.firstIndex(where: { $0.broadcastInfo.id == device.broadcastInfo.id }) {
                devices[index] = device
                tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
            }
        }
    }

    private func deviceConnectionChanged(_ device: XLINKBaseDevice, state: XLINKConnectionState) {
        // 查找设备并更新其状态
        if let index = devices.firstIndex(where: { $0.broadcastInfo.id == device.broadcastInfo.id }) {
            // 获取旧状态
            let oldState = devices[index].connectionState
            
            // 更新设备
            devices[index] = device
            tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)

            // 只有在状态从非connected变为connected时才跳转到详情页
            // 防止多次收到connected状态导致重复跳转
            if state == .connected && oldState != .connected {
                let deviceDetailVC = DeviceDetailViewController(device: device)
                navigationController?.pushViewController(deviceDetailVC, animated: true)
            }
        }
    }

    // MARK: - 工具方法

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    private func getRSSIImage(rssi: Int) -> UIImage? {
        let systemName: String

        if rssi >= -50 {
            systemName = "wifi"
        } else if rssi >= -65 {
            systemName = "wifi"
        } else if rssi >= -80 {
            systemName = "wifi"
        } else {
            systemName = "wifi.slash"
        }

        return UIImage(systemName: systemName)
    }

    private func getRSSIDescription(rssi: Int) -> String {
        if rssi >= -50 {
            return "信号极好"
        } else if rssi >= -65 {
            return "信号良好"
        } else if rssi >= -80 {
            return "信号一般"
        } else {
            return "信号较弱"
        }
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension DeviceListViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = devices.count
        if count == 0 {
            tableView.setEmptyMessage("未发现设备，请开始扫描")
        } else {
            tableView.restore()
        }
        return count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath) as! DeviceCell
        let device = devices[indexPath.row]

        cell.configure(with: device, rssiImage: getRSSIImage(rssi: device.broadcastInfo.rssi),
                       rssiDescription: getRSSIDescription(rssi: device.broadcastInfo.rssi))

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let device = devices[indexPath.row]

        // 检查设备是否已连接
        if device.connectionState == .connected {
            let deviceDetailVC = DeviceDetailViewController(device: device)
            navigationController?.pushViewController(deviceDetailVC, animated: true)
        } else {
            // 尝试连接设备
            let success = device.connect()
            if success {
                showAlert(title: "连接中", message: "正在连接到设备: \(device.broadcastInfo.name ?? "未命名设备")")
            } else {
                showAlert(title: "错误", message: "无法连接到设备")
            }
        }
    }
}

// MARK: - 空表格视图提示扩展

extension UITableView {
    func setEmptyMessage(_ message: String) {
        let messageLabel = UILabel(frame: CGRect(x: 0, y: 0, width: bounds.size.width, height: bounds.size.height))
        messageLabel.text = message
        messageLabel.textColor = .systemGray
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.font = .systemFont(ofSize: 16)
        messageLabel.sizeToFit()

        backgroundView = messageLabel
    }

    func restore() {
        backgroundView = nil
    }
}

// MARK: - DeviceCell 自定义表格单元格

class DeviceCell: UITableViewCell {
    private let deviceNameLabel = UILabel()
    private let deviceTypeLabel = UILabel()
    private let deviceModelLabel = UILabel()
    private let rssiImageView = UIImageView()
    private let rssiLabel = UILabel()
    private let connectionStateLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        // 设备名称标签
        deviceNameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        deviceNameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(deviceNameLabel)

        // 设备类型标签
        deviceTypeLabel.font = .systemFont(ofSize: 14)
        deviceTypeLabel.textColor = .secondaryLabel
        deviceTypeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(deviceTypeLabel)

        // 设备型号标签
        deviceModelLabel.font = .systemFont(ofSize: 12)
        deviceModelLabel.textColor = .tertiaryLabel
        deviceModelLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(deviceModelLabel)

        // 信号强度图像
        rssiImageView.contentMode = .scaleAspectFit
        rssiImageView.tintColor = .systemBlue
        rssiImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rssiImageView)

        // 信号强度标签
        rssiLabel.font = .systemFont(ofSize: 12)
        rssiLabel.textColor = .secondaryLabel
        rssiLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rssiLabel)

        // 连接状态标签
        connectionStateLabel.font = .systemFont(ofSize: 12, weight: .medium)
        connectionStateLabel.textAlignment = .right
        connectionStateLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(connectionStateLabel)

        // 布局约束
        NSLayoutConstraint.activate([
            deviceNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            deviceNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            deviceNameLabel.trailingAnchor.constraint(equalTo: connectionStateLabel.leadingAnchor, constant: -10),

            deviceTypeLabel.topAnchor.constraint(equalTo: deviceNameLabel.bottomAnchor, constant: 4),
            deviceTypeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            deviceTypeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            deviceModelLabel.topAnchor.constraint(equalTo: deviceTypeLabel.bottomAnchor, constant: 4),
            deviceModelLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            deviceModelLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10),

            rssiImageView.centerYAnchor.constraint(equalTo: deviceModelLabel.centerYAnchor),
            rssiImageView.leadingAnchor.constraint(equalTo: deviceModelLabel.trailingAnchor, constant: 10),
            rssiImageView.widthAnchor.constraint(equalToConstant: 20),
            rssiImageView.heightAnchor.constraint(equalToConstant: 20),

            rssiLabel.centerYAnchor.constraint(equalTo: rssiImageView.centerYAnchor),
            rssiLabel.leadingAnchor.constraint(equalTo: rssiImageView.trailingAnchor, constant: 4),

            connectionStateLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            connectionStateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            connectionStateLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
        ])

        accessoryType = .disclosureIndicator
    }

    func configure(with device: XLINKBaseDevice, rssiImage: UIImage?, rssiDescription: String) {
        deviceNameLabel.text = device.broadcastInfo.name ?? "未命名设备"

        // 设置设备类型
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

        // 设置设备型号
        deviceModelLabel.text = device.broadcastInfo.model ?? "未知型号"

        // 设置信号强度
        rssiImageView.image = rssiImage
        rssiLabel.text = rssiDescription

        // 设置连接状态
        switch device.connectionState {
        case .connected:
            connectionStateLabel.text = "已连接"
            connectionStateLabel.textColor = .systemGreen
        case .connecting:
            connectionStateLabel.text = "连接中..."
            connectionStateLabel.textColor = .systemBlue
        case .disconnecting:
            connectionStateLabel.text = "断开中..."
            connectionStateLabel.textColor = .systemOrange
        case .disconnected:
            connectionStateLabel.text = "未连接"
            connectionStateLabel.textColor = .systemGray
        @unknown default:
            connectionStateLabel.text = "未连接"
            connectionStateLabel.textColor = .systemGray
        }
    }
}
