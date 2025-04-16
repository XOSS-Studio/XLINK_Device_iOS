# XLINKDeviceiOSSDK 使用文档

## 简介

XLINKDeviceiOSSDK 是一个用于与XLINK自行车码表设备进行通信的iOS SDK。该SDK提供了一系列API，用于发现、连接和管理XLINK设备，以及与设备进行数据交换和配置管理。

## 运行条件

* iOS 14.0 或更高版本
* Swift 5.5 或更高版本
* 设备需支持蓝牙4.0或更高版本
* Xcode 13.0 或更高版本

## 集成方法

### Swift Package Manager

有两种方式可以使用Swift Package Manager集成XLINKDevice SDK：

#### 1. 从GitHub仓库添加

在Xcode中，选择`File > Add Packages...`，然后输入SDK的仓库URL：

```
https://github.com/XOSS-Studio/XLINK_Device_iOS.git
```

#### 2. 本地集成XCFramework

如果您已下载XLINKDevice.xcframework，可以通过以下步骤进行集成：

1. 将XLINKDevice.xcframework放置在您项目的根目录下
2. 在项目根目录创建`Package.swift`文件，内容如下：

```swift
// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "XLINKDevice",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "XLINKDevice",
            targets: ["XLINKDevice"]
        ),
    ],
    dependencies: [],
    targets: [
        .binaryTarget(
            name: "XLINKDevice",
            path: "XLINKDevice.xcframework"
        ),
    ]
)
```

3. 在您的应用项目中，通过本地路径添加包依赖：
   - 选择`File > Add Packages...`
   - 点击`Add Local...`按钮
   - 浏览并选择包含上述Package.swift文件的文件夹


#### 3. 手动集成

1. 下载最新的XLINKDeviceiOSSDK.xcframework
2. 将XLINKDeviceiOSSDK.xcframework拖拽到项目中
3. 在项目设置中的"General"选项卡下，将XLINKDeviceiOSSDK.xcframework添加到"Frameworks, Libraries, and Embedded Content"中

## 使用说明

### 初始化SDK

在使用SDK之前，需要先进行初始化并通过API密钥进行认证：

```swift
import XLINKDevice

// 在应用启动时初始化SDK
func initializeSDK() async {
    do {
        let result = try await XLINKDeviceManager.shared.initialize(apiKey: "YOUR_API_KEY")
        if result {
            print("SDK初始化成功")
        } else {
            print("SDK初始化失败")
        }
    } catch {
        print("SDK初始化出错: \(error)")
    }
}
```

### 监听SDK状态

SDK提供了多个发布者（Publisher），可以通过Combine框架订阅这些发布者来监听SDK状态变化：

```swift
import Combine
import XLINKDevice

var cancellables = Set<AnyCancellable>()

func setupObservers() {
    // 监听初始化完成事件
    XLINKDeviceManager.shared.initCompletedPublisher
        .sink { result in
            print("SDK初始化完成: \(result)")
        }
        .store(in: &cancellables)
    
    // 监听授权过期时间变更
    XLINKDeviceManager.shared.authExpirationPublisher
        .sink { date in
            if let date = date {
                print("授权过期时间: \(date)")
            }
        }
        .store(in: &cancellables)
    
    // 监听蓝牙状态变化
    XLINKDeviceManager.shared.bluetoothStatePublisher
        .sink { state in
            print("蓝牙状态变化: \(state)")
        }
        .store(in: &cancellables)
}
```

### 扫描设备

初始化SDK成功后，可以开始扫描附近的XLINK设备：

```swift
// 开始扫描设备，超时时间为10秒
func startScan() {
    XLINKDeviceManager.shared.startScan(timeout: 10.0)
    
    // 监听设备发现事件
    XLINKDeviceManager.shared.deviceDiscoveredPublisher
        .sink { device in
            print("发现设备: \(device.broadcastInfo.name ?? "未知设备")")
        }
        .store(in: &cancellables)
}

// 停止扫描
func stopScan() {
    XLINKDeviceManager.shared.stopScan()
}
```

### 连接设备

发现设备后，可以选择连接到特定设备：

```swift
// 连接到设备
func connectToDevice(device: XLINKBaseDevice) {
    let success = XLINKDeviceManager.shared.connect(device: device)
    if success {
        print("开始连接设备")
    } else {
        print("连接设备失败")
    }
    
    // 监听设备连接状态变化
    XLINKDeviceManager.shared.deviceConnectionPublisher
        .sink { (device, state) in
            print("设备 \(device.broadcastInfo.name ?? "未知设备") 连接状态变化: \(state)")
            
            if state == .connected {
                // 设备已连接，可以开始与设备交互
                print("设备已连接")
            } else if state == .disconnected {
                // 设备已断开连接
                print("设备已断开连接")
            }
        }
        .store(in: &cancellables)
}

// 断开设备连接
func disconnectDevice(device: XLINKBaseDevice) {
    XLINKDeviceManager.shared.disconnect(device: device)
}

// 断开所有设备
func disconnectAllDevices() {
    XLINKDeviceManager.shared.disconnectAll()
}
```

### 获取设备列表

SDK提供了多种方法来获取和筛选设备：

```swift
// 获取所有发现的设备
let allDevices = XLINKDeviceManager.shared.discoveredDevices

// 获取所有已连接的设备
let connectedDevices = XLINKDeviceManager.shared.connectedDevices

// 根据设备ID获取设备
let device = XLINKDeviceManager.shared.getDevice(byId: "设备ID")

// 根据设备名称筛选设备
let devicesByName = XLINKDeviceManager.shared.getDevices(byName: "XLINK")

// 根据设备类型筛选设备
let bikeComputers = XLINKDeviceManager.shared.getDevices(byType: .bikeComputer)
```

### 与自行车码表设备交互

当连接到自行车码表设备后，可以使用`XLINKBikeComputerDevice`类提供的API进行交互：

```swift
// 确保设备是自行车码表类型
guard let bikeComputer = device as? XLINKBikeComputerDevice else {
    print("设备不是自行车码表")
    return
}

// 监听自行车码表状态变化
bikeComputer.bikeComputerStatePublisher
    .sink { state in
        print("自行车码表状态变化: \(state)")
    }
    .store(in: &cancellables)

// 监听配置信息变化
bikeComputer.configPublisher
    .sink { config in
        print("配置信息更新: 总存储空间 \(config.totalStorage)字节, 剩余空间 \(config.remainStorage)字节")
    }
    .store(in: &cancellables)
```

### 获取和设置设备配置

```swift
// 获取用户配置
func getUserProfile() async {
    do {
        if let userProfile = try await bikeComputer.getUserProfile() {
            print("获取用户配置成功: \(userProfile)")
        }
    } catch {
        print("获取用户配置失败: \(error)")
    }
}

// 设置用户配置
func setUserProfile(userProfile: UserProfileSetting) async {
    do {
        let success = try await bikeComputer.sendUserProfile(userProfile)
        if success {
            print("设置用户配置成功")
        } else {
            print("设置用户配置失败")
        }
    } catch {
        print("设置用户配置出错: \(error)")
    }
}

// 获取系统设置
func getSystemSettings() async {
    do {
        if let settings = try await bikeComputer.getSettings() {
            print("获取系统设置成功: \(settings)")
        }
    } catch {
        print("获取系统设置失败: \(error)")
    }
}

// 设置系统设置
func setSystemSettings(settings: DeviceSetting) async {
    do {
        let success = try await bikeComputer.sendSettings(settings)
        if success {
            print("设置系统设置成功")
        } else {
            print("设置系统设置失败")
        }
    } catch {
        print("设置系统设置出错: \(error)")
    }
}
```

### 同步骑行数据

```swift
// 获取骑行记录列表
func getWorkouts() async {
    do {
        let workouts = try await bikeComputer.getWorkouts()
        print("获取到 \(workouts.count) 条骑行记录")
        
        // 同步每条骑行记录
        for workout in workouts {
            if workout.status == .unSync {
                do {
                    let fitData = try await bikeComputer.syncWorkout(workout)
                    print("同步骑行记录成功: \(workout.fileName), 大小: \(fitData.count)字节")
                    // 处理FIT文件数据...
                } catch {
                    print("同步骑行记录失败: \(error)")
                }
            }
        }
    } catch {
        print("获取骑行记录列表失败: \(error)")
    }
}

// 监听文件传输进度
func monitorFileTransferProgress() {
    bikeComputer.fileTransferProgressPublisher
        .sink { progress in
            print("文件传输进度: \(progress.filename) - \(progress.progress * 100)%")
        }
        .store(in: &cancellables)
}

// 取消文件传输
func cancelFileTransfer() async {
    do {
        try await bikeComputer.cancelFileTransfer()
        print("文件传输已取消")
    } catch {
        print("取消文件传输失败: \(error)")
    }
}
```

### 设备管理操作

```swift
// 同步设备时间
func syncDeviceTime() async {
    do {
        try await bikeComputer.syncTime()
        print("同步时间成功")
    } catch {
        print("同步时间失败: \(error)")
    }
}

// 重启设备
func restartDevice() async {
    do {
        try await bikeComputer.resetDevice(.restart)
        print("重启设备命令已发送")
    } catch {
        print("重启设备失败: \(error)")
    }
}

// 恢复出厂设置
func factoryResetDevice() async {
    do {
        try await bikeComputer.resetDevice(.factoryReset)
        print("恢复出厂设置命令已发送")
    } catch {
        print("恢复出厂设置失败: \(error)")
    }
}

// 格式化设备存储
func formatDeviceStorage() async {
    do {
        try await bikeComputer.resetDevice(.formatStorage)
        print("格式化存储命令已发送")
    } catch {
        print("格式化存储失败: \(error)")
    }
}

// 进入DFU模式（固件升级模式）
func enterDFUMode() async {
    do {
        try await bikeComputer.enterDFUMode()
        print("设备已进入DFU模式")
    } catch {
        print("进入DFU模式失败: \(error)")
    }
}
```

## 错误处理

SDK可能抛出以下错误类型：

- `XLINKDeviceError.deviceNotFound`: 设备未找到
- `XLINKDeviceError.deviceNotConnected`: 设备未连接
- `XLINKDeviceError.commandTimeout`: 命令执行超时
- `XLINKDeviceError.commandFailed`: 命令执行失败
- `XLINKDeviceError.fileTransferFailed`: 文件传输失败
- `XLINKDeviceError.operationCancelled`: 操作被取消
- `XLINKDeviceError.invalidParameter`: 参数无效
- `XLINKDeviceError.authenticationFailed`: 认证失败

## 最佳实践

1. **初始化顺序**：应用启动后尽早初始化SDK，确保在使用其他功能前完成初始化。
2. **资源管理**：不再使用SDK时，调用`disconnectAll()`断开所有连接，释放资源。
3. **错误处理**：所有可能抛出异常的方法都应使用try-catch包裹，妥善处理异常情况。
4. **后台模式**：当应用进入后台时，考虑是否需要断开设备连接或保持连接以继续接收数据。
5. **权限请求**：确保应用在使用SDK前已获取蓝牙权限。

## 示例代码

完整的示例应用程序可以在SDK示例目录中找到，展示了如何使用SDK的各项功能。

## 技术支持

如有任何问题或需要技术支持，请联系我们的开发团队。

## 版本历史

- 0.1.0: 初始版本
