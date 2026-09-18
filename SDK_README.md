# XLINKDevice iOS SDK 1.2.1

XLINKDevice 提供码表扫描、连接、配置读写、骑行记录同步、星历文件下发和固件升级。对外模块只有 `XLINKDevice`，无需集成内部协议包或另外安装 NordicDFU、ZIPFoundation。

## 交付内容与集成

- `XLINKDevice.xcframework`：Release 二进制，包含 iOS 真机与 iOS Simulator 版本。
- `Package.swift`：发行包内的本地 Swift Package 入口，引用同目录的 XCFramework。
- `THIRD_PARTY_LICENSES.md`：内置第三方代码的许可证。
- `RELEASE_MANIFEST.json`：构建工具链、构建配置、公开接口清单、二进制运行时依赖与随包文件校验值。**仅随发行压缩包提供**；若你是从 Demo 仓库取得本 SDK，文件完整性由该仓库的版本控制保证，不再附带这份清单。

最低部署版本为 **iOS 17.0**。自 1.2.0 起为破坏性变更，低于 17.0 的宿主无法链接。本次使用 Xcode 26.6 构建；接入时应使用能够读取发行包 Swift 接口的兼容 Xcode。Simulator 二进制供编译与界面开发使用，蓝牙协议联调仍需真机。

手动集成：将整个 `XLINKDevice.xcframework` 加到 App target 的 Frameworks, Libraries, and Embedded Content，动态 framework 选择 **Embed & Sign**。也可以将解压后的发行包作为本地 Swift Package 添加，并选择 `XLINKDevice` product。两种方式选择一种，避免重复链接。

App 的 Info.plist 需要配置：

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>用于发现、连接码表并同步设备数据</string>
```

需要后台蓝牙通信时，再配置 `UIBackgroundModes` 的 `bluetooth-central`。SDK 不替 App 管理生命周期策略。

## 调用与状态约定

`XLINKDeviceManager`、`XLINKBaseDevice`、`XLINKBikeComputerDevice` 为 `@MainActor` 类型。在 `@MainActor` 对象或 `Task { @MainActor in ... }` 中调用。文件读取等耗时 I/O 应在合适的后台上下文完成，再把 `Data` 交给 SDK。

- 同一设备的普通命令与文件操作经过实例级串行队列。
- `startScan`、`connect` 的 `Bool` 表示请求是否接受，不表示扫描已发现设备或连接已完成。
- `initialize` 无返回值，正常返回即授权通过；请以 `isAuthenticated` 判断授权，而不是仅看 `isInitialized`。
- 操作完成与失败以 `async throws` 的结果为准；Publisher 用于持续展示状态和进度。
- 先订阅再发起操作。多数 Publisher 为事件流，不会重放历史值；当前值从对应只读属性获取。
- `cancelFileTransfer()` 和 `cancelFirmwareUpdate()` 是在途操作的控制入口，不应排在普通命令后等待。

## 初始化、扫描与连接

```swift
import Combine
import CoreBluetooth
import Foundation
import XLINKDevice

@MainActor
final class DeviceSession {
    private let manager = XLINKDeviceManager.shared
    private var subscriptions = Set<AnyCancellable>()
    private(set) var devices: [XLINKBaseDevice] = []

    init() {
        manager.deviceDiscoveredPublisher
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.devices = XLINKDeviceManager.shared.discoveredDevices
                }
            }
            .store(in: &subscriptions)

        manager.deviceConnectionPublisher
            .sink { device, state in
                print("设备 \(device.broadcastInfo.id)：\(state)")
            }
            .store(in: &subscriptions)
    }

    func initialize(apiKey: String) async throws {
        try await manager.initialize(apiKey: apiKey)
    }

    func startScan() -> Bool {
        guard manager.isAuthenticated, manager.bluetoothState == .poweredOn else {
            return false
        }
        return manager.startScan(timeout: 30)
    }

    func connect(_ device: XLINKBaseDevice) -> Bool {
        manager.connect(device: device)
    }
}
```

初始化需要有效 API Key 和网络。蓝牙开启状态通过 `bluetoothState` / `bluetoothStatePublisher` 获取。认证后的瞬时网络再验证错误会重试；授权被服务端撤销时，SDK 会停止扫描并断开设备。切换 API Key 前调用 `reset()`，再重新初始化。

| Manager 方法或属性 | 当前行为 |
|---|---|
| `shared` | 共享管理器；无公开初始化器 |
| `initialize(apiKey:) async throws` | 初始化和认证；已认证时直接返回。认证被拒、取消、超时与网络故障一律抛出 `XLINKDeviceError` |
| `reset()` | 清除 SDK 授权和设备账本，停止扫描并断开设备 |
| `startScan(timeout:) -> Bool` | 默认 120 秒；传 0 不自动停止；未认证、蓝牙不可用或已在扫描时返回 false |
| `stopScan()` / `isScanning` | 停止扫描 / 查询扫描状态 |
| `connect(device:) -> Bool` | 发起连接；后续观察连接状态 |
| `disconnect(device:)` / `disconnectAll()` | 请求断开指定设备 / 全部设备 |
| `discoveredDevices` / `connectedDevices` | 当前发现列表 / 已连接列表 |
| `getDevice(byId:)` | 在 SDK 设备账本中按 ID 查询，不会发起扫描 |
| `getDevices(byName:)` | 对已发现设备名称做区分大小写的包含匹配 |
| `getDevices(byType:)` | 对已发现设备按广播类型查询 |
| `getAuthExpirationDate()` / `getAuthRemainingTime()` | 授权到期日期 / 剩余秒数 |

主要 Manager 事件：`initCompletedPublisher`、`authExpirationPublisher`、`bluetoothStatePublisher`、`deviceDiscoveredPublisher`、`deviceConnectionPublisher`。

### 发现范围与设备信息

扫描候选按码表协议识别，**不要求产品 ID 在登记表内**。广播携带码表主服务时不限制名称或制造商数据；未广播主服务的既有固件保留名称识别回退。无法识别为码表的普通外设被过滤，DFU 广播保留独立准入。

扫描识别不等于协议连接成功。连接时会校验 DIS 与码表所需的命令、传输服务和特征。电池服务、读取和通知属于可选能力，电池不可用不会单独阻止码表主通道连接。

`broadcastInfo.id` 是 iOS 外设标识，不是 MAC 地址。公开广播信息包括 `name`、`rssi`、`deviceType`、`modelId`、`serialNumber`、`model`、`firmwareVersion`、`hardwareVersion`、`manufacturer`。有效广播 PID 会在连接前写入 `modelId`；缺失时为 nil。`model` 和固件等 DIS 字段在连接后补全。原始广播、服务 UUID 列表和制造商原始数据没有作为公开字段提供。

连接状态以 `deviceState`、`deviceStatePublisher` 或 Manager 的 `deviceConnectionPublisher` 为准。`.idle` 表示服务准备完成；`.connecting` / `.discoveringServices` 仍在连接，`.offline` 表示离线。设备对象由扫描结果获取，不由调用方自行构造。`XLINKBaseDfuDevice` 虽继承码表类型，但不允许执行普通码表命令和文件操作；可通过 `broadcastInfo.deviceType` 区分。

## 码表命令

对扫描获得的设备做 `as? XLINKBikeComputerDevice` 转换，并确认其类型为 `.bikeComputer`、连接已经完成。

| 方法 | 返回与用途 |
|---|---|
| `requestDeviceState() async throws` | 请求并更新设备状态 |
| `requestDeviceStorage() async throws -> BikeComputerConfig` | 获取剩余和总存储空间，单位 **KB**；同时更新 `config` |
| `syncTime() async throws` | 发送当前 Unix 时间戳 |
| `resetDevice(_:) async throws` | `.resetODO`、`.restoreFactory`、`.unbind`、`.formatDevice` |
| `requestGNSSState() async throws -> XLINKGNSSEphemerisState` | 返回 `model`、`expiredTime`、`isExpired`；不支持的机型可能超时 |
| `enterDFUMode() async throws` | 请求进入 DFU；方法返回后设备仍可能处于重启或重新广播阶段 |

其他只读值与事件包括 `config` / `configPublisher`、`batteryLevel` / `batteryLevelPublisher`、`batteryStatus` / `batteryStatusPublisher`、`deviceInfoUpdatedPublisher`。电量单位为百分比，未知时为 nil。`bikeComputerStatePublisher` 是兼容事件入口，不应替代完整的 `deviceStatePublisher` 连接状态流。

## 文件读写与进度

### 配置与骑行记录

| 读取或下载 | 写入或删除 | 设备文件名 / 说明 |
|---|---|---|
| `getUserProfile() async throws -> UserProfileSetting?` | `sendUserProfile(_:) async throws` | `user_profile.json` |
| `getSettings() async throws -> DeviceSetting?` | `sendSettings(_:) async throws` | `settings.json` |
| `getGearProfile() async throws -> GearSetting` | `sendGearProfile(_:) async throws` | `gear_profile.json` |
| `getPanels() async throws -> PanelSetting` | `sendPanels(_:) async throws` | `panels.json` |
| `getWorkouts() async throws -> [WorkoutStruct]` | — | `workouts.json`；空数组表示没有记录 |
| `syncWorkout(_:) async throws -> Data` | `deleteWorkout(_:) async throws` | 使用列表项的 `formatName`，即对应 FIT 文件名 |

配置模型为 Codable；推荐读取设备配置、修改公开字段后再发送，保留设备已有字段。也可以使用符合设备格式的 JSON，经 `JSONDecoder` 解码。模型的 Swift 属性名与设备侧 JSON 键名逐字一致（`device_model`、`update_at`、`FTP` 等按原样保留），模型不声明 `CodingKeys`，线格式由属性名直接决定——自行构造 JSON 时按属性名写键即可。

写操作不返回值：失败一律抛出 `XLINKDeviceError`，调用返回即表示设备已接受。读取配置的方法返回可选值，解码失败会抛错，调用方仍应处理 nil。

### 计圈配置（SDK 1.2.1）

`settings.lap` 对应配置协议 v2.0.2 的计圈配置。该字段为可选值：设备未返回时为 `nil`，编码时省略；不要仅为启用计圈而修改文件的 `version`。

| 字段 | 类型 | 含义 |
|---|---|---|
| `lap.mode` | `SettingsModel.AutoLapMode` | `.manual` = 0、`.location` = 1、`.distance` = 2、`.time` = 3 |
| `lap.value` | `Int?` | 距离模式为米，时间模式为秒；距离范围 1–100000 米，时间范围 10–86400 秒 |
| `lap.lat` | `Int?` | 位置纬度，保留设备返回的整数表示 |
| `lap.lon` | `Int?` | 位置经度，保留设备返回的整数表示 |

`LapModel` 提供公开初始化方法，默认模式为 `.manual`，其余字段默认为 `nil`。SDK 按原值编解码，不执行坐标换算或范围裁剪；未知计圈模式可通过 `AutoLapMode(rawValue:)` 保留。

```swift
@MainActor
func setDistanceLap(on device: XLINKBikeComputerDevice) async throws {
    guard var file = try await device.getSettings(),
          var settings = file.settings,
          settings.lap != nil else { return }
    settings.lap = SettingsModel.LapModel(mode: .distance, value: 5000)
    file.settings = settings
    try await device.sendSettings(file)
}
```

示例仅修改设备已经提供的计圈配置。调用方应按设备能力选择模式；位置模式保留 `lat`、`lon` 的协议整数值。

### 任意文件与星历

```swift
@MainActor
func sendEphemeris(_ data: Data, to device: XLINKBikeComputerDevice) async throws {
    let accepted = try await device.sendFile(data, filename: "offline.gnss")
    print(accepted ? "星历文件下发完成" : "设备未接受文件")
}
```

`sendFile(_:filename:)` 使用原始 `Data`，`filename` 是**设备端接收名**，同时用于下发命令和传输文件头。源文件不需要实际重命名。空数据或空文件名会失败。SDK 不会把任意文件内容转换为星历格式；传入数据应适合目标设备。

Demo 的“发送星历文件”允许从文件 App 选择文件，并以 `offline.gnss` 下发。读取过程保留系统文件访问权限处理。固件 ZIP 应走下面的固件升级接口。

### 展示文件进度

```swift
@MainActor
final class FileTransferDisplay {
    private var subscription: AnyCancellable?
    private(set) var progressByFilename: [String: FileTransferProgress] = [:]

    func observe(_ device: XLINKBikeComputerDevice) {
        subscription = device.fileTransferProgressPublisher
            .sink { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.progressByFilename[progress.filename] = progress
                }
            }
    }
}
```

`FileTransferProgress` 包含 `filename`、`state`、`progress`（0...1）、`fileSize`、`transferredBytes`（字节）。阶段包括 `.preparing`、`.transferring(progress:)`、`.processing`、`.deleting`、`.completed`、`.failed(error:)`。100% 数据传输不应独立作为业务完成标志，应继续等待完成阶段及异步方法返回。

`await device.currentFileTransfer` 只表示当前在途快照，操作结束后会清空。需要保留历史结果时由接入方保存。`fileTransferPublisher` 是仅含文件名和状态的兼容事件流，通常选用信息更完整的 `fileTransferProgressPublisher` 即可。相同文件名可同时用于读取和回写；页面有多个操作入口时，还应按发起的操作关联进度。

Demo 将进度放在当前运行的文件操作卡片下，显示实际文件名、百分比和字节数；页面顶部不再显示统一进度。完成、失败及返回内容由同一卡片的动作结果继续展示。

| 传输控制 | 当前行为 |
|---|---|
| `cancelFileTransfer() async throws` | 取消设备实例队列中的在途/排队操作，并尝试发送停止文件同步命令；会发布取消失败状态，不只清除 UI |
| `resetFileTransferServices() async throws` | 仅清空实例的传输进度缓存；不重建 BLE 通道，也不取消正在执行的传输 |

## 固件升级

```swift
@MainActor
func installFirmware(_ localZIP: URL, on device: XLINKBikeComputerDevice) async throws {
    try await device.updateFirmware(firmwareURL: localZIP)
}
```

`updateFirmware(firmwareURL:)` 接受可读取的**本地固件 ZIP URL**。远程文件由接入方先下载到本地。普通码表可由 SDK 请求进入 DFU 并继续升级；已经处于 DFU 模式的设备也可使用升级入口。

该 URL 必须在整个升级过程中持续可读——升级要跨越「下发进入 DFU、设备重启、重新搜索并连接 DFU 设备、传输固件」数十秒，SDK 在末段才真正读取文件内容。**来自 `UIDocumentPicker` / SwiftUI `fileImporter` 的安全作用域 URL 不能直接传入**：离开 `startAccessingSecurityScopedResource()` 区间后该路径读不到，升级会以 `invalidParameter` 结束。正确做法是选中后立即拷贝到应用沙盒，再把副本的 URL 传给 SDK。`invalidParameter` 在升级路径上只有两个来源：传入路径读不到，以及 ZIP 不是有效的 Nordic DFU 包（需包含 `manifest.json` 与其声明的 bin/dat）。

升级进度使用 `firmwareUpdateProgressPublisher`，类型为 `XLINKFirmwareUpdateProgress`，包含 `state`、`progress`、`description`。它与普通文件进度是独立的事件流。`cancelFirmwareUpdate()` 请求取消升级；完成结果仍由正在等待的异步调用和升级事件反映。协议级完成不表示升级后的设备已经重新连接。

## 错误与诊断

方法可能抛出 `XLINKDeviceError`，配置解码等路径也可能返回底层解码错误。调用方保留最终 `catch`，不要只处理某几个枚举分支。

| 类别 | 常见错误 |
|---|---|
| 初始化与授权 | `sdkNotInitialized`、`authenticationFailed(String)`、`tokenInvalid`、`tokenExpired`、`tokenMissing` |
| 连接 | `deviceNotFound`、`deviceNotConnected`、`connectionFailed`、`disconnected`、`timeout` |
| 命令与状态 | `deviceBusy`、`commandNotSupported`、`commandFailed`、`invalidParameter`、`operationNotPermitted`、`operationRejected` |
| 文件 | `fileNotFound`、`fileDecodeFailed`、`fileTransferFailed`、`storageFull`、`dataCorrupted`、`checksumError`、`operationCancelled` |
| 其他 | `operationFailed`、`networkError(domain:code:message:)`、`unknownError(String)` |

```swift
@MainActor
func observeDiagnostics() -> AnyCancellable {
    XLINKDeviceManager.shared.diagnosticPublisher
        .sink { event in
            print("\(event.code.rawValue)：\(event.message)")
        }
}
```

保存 `observeDiagnostics()` 返回的订阅对象以持续接收事件。诊断流只提供错误级事件。`XLINKDiagnosticEvent` 公开 `date`、`code`、`message`、`deviceId`。稳定诊断码：`notInitialized`、`authenticationFailed`、`authorizationRevoked`、`bluetoothUnavailable`、`connectionFailed`、`connectionLost`、`serviceDiscoveryFailed`、`firmwareUpdateFailed`、`internalError`。

`setDiagnosticsEnabled(_:)` 可启停诊断，可从任意线程调用。Release 不生成内部调试日志文本；SDK 的蓝牙原始数据、内部协议类型与第三方实现不属于公开接口。

全部事件流对外类型均为 `AnyPublisher`，只能订阅、不能写入。

## 状态与错误枚举对照

以下枚举会出现在 publisher、回调与 `catch` 分支里，`switch` 时需要覆盖全部分支。

### XLINKDeviceState

设备状态只有这一个枚举。`deviceStatePublisher` 在状态真实变化时去重投递；`bikeComputerStatePublisher` 载荷相同，但只在命令开始与结束时投递且不去重。

| case | 含义 |
|---|---|
| `offline` | 未连接 |
| `connecting` | 连接中 |
| `disconnecting` | 正在断开连接 |
| `discoveringServices` | 发现服务中 |
| `idle` | 连接成功但无活动 |
| `busy` | 设备正在执行某项操作 |
| `recording` | 设备正在记录活动 |
| `syncing` | 正在进行数据同步 |
| `upgrading` | 固件升级中 |
| `noResponse` | 设备无响应 |

`connecting` 与 `discoveringServices` 可用 `isConnecting` 一并判断。`busy`、`recording`、`syncing`、`upgrading` 期间下发新命令通常会收到 `XLINKDeviceError.deviceBusy`。

### XLINKDeviceError 的处置分类

上面「错误与诊断」按来源分了类，这里按**该怎么办**再分一次，便于直接落到重试逻辑上。

| 处置 | 错误 | 说明 |
|---|---|---|
| 可重试 | `deviceBusy`、`timeout`、`checksumError` | 设备忙或单次交互失败，退避后重发；超过自定阈值再转为提示连接问题 |
| 需用户介入 | `storageFull`、`operationNotPermitted`、`operationRejected`、`deviceNotConnected` | 重试无用，要先让用户清理存储、确认授权绑定或重新连接 |
| 需重新授权 | `sdkNotInitialized`、`authenticationFailed`、`tokenInvalid`、`tokenExpired`、`tokenMissing` | 走初始化与授权流程，不要在业务层重试 |
| 不应重试 | `commandNotSupported`、`invalidParameter`、`fileNotFound`、`fileDecodeFailed`、`dataCorrupted`、`commandFailed`、`operationFailed` | 参数、能力或数据本身的问题，重发结果相同 |
| 按上下文判断 | `deviceNotFound`、`connectionFailed`、`disconnected`、`fileTransferFailed`、`operationCancelled`、`networkError`、`unknownError` | 取决于当时是否在扫描、是否用户主动取消、是否处于升级重启窗口 |

`operationCancelled` 在用户主动取消传输或升级时也会出现，不应按故障上报。升级过程中的 `disconnected` 属正常流程，设备进入 DFU 会断开重连。

### XLINKFirmwareUpdateState

升级是多阶段流程，进度条需要覆盖全部中间态，否则会出现长时间停在同一百分比的观感。

| case | 含义 |
|---|---|
| `initial` | 初始状态 |
| `preparingDFU` | 准备进入 DFU 模式 |
| `searchingDFUDevice` | 搜索 DFU 设备中 |
| `connectingDFUDevice` | 连接 DFU 设备中 |
| `transferring` | 传输固件中 |
| `validating` | 固件验证中 |
| `completed` | 更新完成 |
| `failed(XLINKDeviceError)` | 更新失败，关联值为具体原因 |

设备进入 DFU 会先断开原连接并以新的广播重新出现，`searchingDFUDevice` 到 `connectingDFUDevice` 之间出现短暂断连属正常流程。

### FileSyncState

| case | 含义 |
|---|---|
| `unSync` | 未同步 |
| `recording` | 正在记录，暂不可同步 |
| `syncing` | 正在同步 |
| `synced` | 已同步 |
| `error` | 同步错误 |
| `overSize` | 文件过大 |

### FileTransferState

| case | 含义 |
|---|---|
| `preparing` | 准备中 |
| `transferring(progress:)` | 传输中，关联值为 0 到 1 的进度 |
| `processing` | 设备端处理中 |
| `deleting` | 删除中 |
| `completed` | 完成 |
| `failed(error:)` | 失败，关联值为具体原因 |

### BatteryStatus

原始值为 `Int`，来自设备电量等级上报。

| case | 原始值 | 含义 |
|---|---|---|
| `reserved` | 0 | 保留，不代表有效电量 |
| `full` | 1 | 满电 |
| `good` | 2 | 电量充足 |
| `middle` | 3 | 电量中等 |
| `low` | 4 | 电量偏低 |
| `critical` | 5 | 电量极低 |
| `charging` | 6 | 充电中 |

### XLINKBroadcastType

| case | 含义 |
|---|---|
| `unknown` | 未知设备 |
| `bikeComputer` | 智能码表 |
| `dfuMode` | 处于 DFU 模式的设备 |

升级流程中同一台设备会先后以 `bikeComputer` 和 `dfuMode` 两种类型出现，扫描过滤时不要只保留前者。

### XLINKResetMode

| case | 含义 |
|---|---|
| `resetODO` | 重置里程 |
| `restoreFactory` | 恢复出厂设置 |
| `unbind` | 解除绑定 |
| `formatDevice` | 格式化设备 |

`restoreFactory` 与 `formatDevice` 会清除设备上尚未同步的骑行记录，调用前应先确认同步完成。

## 当前版本与兼容性

本发行包版本与 SDK 认证版本均为 **1.2.1**。从发行压缩包取得时，随包文件的校验值以包内 `RELEASE_MANIFEST.json` 为准；从 Demo 仓库取得时以版本控制为准。

1.2.1 新增 `SettingsModel.lap`、公开的 `LapModel` 与 `AutoLapMode`，支持计圈配置的读取、构造、修改和回写。兼容 1.2.0 的已有接口；旧文件缺少 `lap` 时仍可解析，回写时不补出该字段。

1.2.0 的变更包括：最低部署版本提升到 iOS 17.0；进入 DFU 模式后等待设备重启期间若升级被取消，不再错误清除重启预期，避免后续升级直接失败。接口上：公开面做了一次性收口，事件流改为只读、部分方法签名与属性名变更、若干不可达类型移除——**既有接入代码需要按下节迁移**。

旧文档中“仅允许已登记产品”“优化入口采用不同取数协议”“支持远程固件 URL”“重置接口修复设备通道”等说法不适用于当前实现。

## 从 1.0 迁移

1.2.0 不保留 1.0 的旧名。最低部署版本同时提到 iOS 17.0，1.0 的接入方无论如何都要改一遍代码，因此公开面一次性理顺，不设过渡别名。

### 事件流

全部事件流的对外类型由 `PassthroughSubject` 改为 `AnyPublisher`。订阅写法不变，但不能再对它们调用 `send(_:)`。两个流的载荷由元组改为具名类型：

| 流 | 1.0 载荷 | 1.2.0 载荷 |
|---|---|---|
| `fileTransferPublisher` | `(String, FileTransferState)` | `FileTransferEvent`（`filename`、`state`） |
| `deviceConnectionPublisher` | `(XLINKBaseDevice, XLINKDeviceState)` | `DeviceConnectionEvent`（`device`、`state`） |

`bikeComputerStatePublisher` 的载荷由 `BikeComputerConnectionState` 改为 `XLINKDeviceState`；`BikeComputerConnectionState` 已删除。

### 方法签名

| 1.0 | 1.2.0 |
|---|---|
| `requestDeviceStorage() -> (remainStorage:totalStorage:)` | `requestDeviceStorage() -> BikeComputerConfig`（成员名不变） |
| `sendUserProfile / sendSettings / sendGearProfile / sendPanels / sendFile / deleteWorkout` 返回 `Bool` | 无返回值，失败抛 `XLINKDeviceError` |
| `initialize(apiKey:) async throws -> Bool` | 无返回值，失败抛 `XLINKDeviceError` |
| `getWorkoutsWithOptimization()` | 已删除，改用 `getWorkouts()` |

`initialize(apiKey:)` 的 `Bool` 在 1.0 里已经恒为 `true`——认证失败、被拒、取消、超时与网络故障一律抛错，`false` 不可达——本次直接去掉返回值。原先写成 `if try await initialize(...) { ... }` 的调用方改为直接 `try await`，失败按 `catch` 处理。`startScan(timeout:)` 与 `connect(device:)` 是同步入口，返回值语义不变，`false` 确实可达。

### 命名

配置模型（`DeviceSetting`、`SettingsModel`、`GearSetting`、`UserGearModel`、`PanelSetting`、`UserProfileSetting`、`BasicUserModel`、`UserProfile`）的属性名与设备侧 JSON 键名逐字一致，1.2.0 未做改动：`device_model`、`update_at`、`updated_at`、`user_name`、`user_profile`、`wheel_size`、`pages_count`、`language_i18n`、`temperature_unit`、`time_zone`、`time_formatter`、`auto_pause`、`gps_model`、`sport_model`、`ALAHR`、`MAXHR`、`LTHR`、`FTP`、`ALASPEED` 均按原样保留。

改名只发生在枚举式常量上，原始值（`rawValue`）不变：

| 类型 | 1.0 | 1.2.0 |
|---|---|---|
| `BatteryStatus` | `.Full`、`.Good`、`.Middle`、`.Low`、`.Critical`、`.Charging`、`.Reserved` | 首字母小写，原始值不变 |
| `XLINKResetMode` | `.ResetODO`、`.RestoreFactory`、`.Unbind`、`.FormatDevice` | 首字母小写 |
| `UserGearModel.GearType` | `.Bike` | `.bike` |
| `SettingsModel.Languagei18n` | `.Chinese` 等 | 首字母小写，`rawValue` 不变 |

### 错误

`networkError` 不再持有底层 `Error`，改为 `networkError(domain:code:message:)`，`XLINKDeviceError` 因此可 `Equatable`、可跨隔离域传递。`FileTransferState.failed` 现在按错误内容比较，两个同因失败判定为相等。

### 已移除的类型

`ResponseError`、`FirmwareCheckModel`、`WorkoutStructList` 原本就不出现在任何公开方法签名里，已转为内部类型。DFU 模式的设备身份由 `XLINKBroadcastType.dfuMode` 判定。

`removeSensor(_:)` 已删除。它在 1.0 里带着"改用 `disconnect(device:)`"的废弃提示，但两者并不等价：`disconnect(device:)` 只断开连接，而 `removeSensor(_:)` 还会把该设备从 SDK 的发现与连接账本中一并移除。1.2.0 不提供按单台设备清账本的入口，但等效路径是现成的：`disconnect(device:)` 之后设备转为离线，下一次 `startScan(timeout:)` 会把 `discoveredDevices` 里所有离线设备清掉（已连接与连接中的设备不受影响），该设备只有仍在广播才会重新出现。要一次清空全部账本用 `reset()`，但它同时清除授权，之后需重新 `initialize(apiKey:)`。
