# XLINK 对外演示 Demo

本目录是 XLINKDevice iOS SDK 的演示工程，完整覆盖 SDK 的公开能力：授权初始化、扫描连接、设备命令、文件读写与同步、固件升级、诊断事件。工程直接链接随目录提供的 **Release XLINKDevice.xcframework 1.2.1**，不依赖任何 SDK 源码工程。

## 打开与使用

1. 使用 Xcode 26.6 或兼容版本打开 `XLINKDeviceExample.xcodeproj`，选择 `XLINKDeviceExample` scheme。
2. 最低部署版本为 iOS 17.0。真机运行前，在 Signing & Capabilities 选择自己的 Team；工程保留 `com.imxingzhe.xlink` Bundle Identifier，修改时应核对 API Key 的授权信息。
3. 在 Demo 的「SDK」页填写自己的 API Key 并初始化。源码不包含固定 API Key；Debug 可从 `XLINK_API_KEY` 环境变量读取初始值。
4. 蓝牙开启后，到「设备」页扫描、连接，再进入命令、文件、固件与诊断界面。

## 文件与进度

- 配置读取、配置回写、骑行记录同步、删除及星历下发都在对应操作卡片中显示当前文件进度，页面顶部没有统一进度条。
- 同时只执行一个普通操作。取消文件传输时，在停止调用完成前禁止新操作，避免旧取消事件进入下一张卡片。
- 「发送星历文件」从文件 App 读取原始数据，以 `offline.gnss` 下发；源文件无需重命名。
- 「清除传输进度」只清空 SDK 的进度缓存；需要停止传输时使用取消入口。
- `N9_V1.09.3075_APP_DFU_250506_153501.zip` 是随 Demo 打包的示例固件，「用内置固件」取的就是它。文件名里带着型号与固件版本，便于确认目标设备是否匹配——只有确认是 N9 时才使用；其他机型请用「选择固件包」挑对应的本地 ZIP。

## SDK 接入文档与二进制

完整公开 API 说明见 [SDK_README.md](SDK_README.md)，包括授权、连接、文件格式、进度、固件升级与错误处理。第三方许可证见 [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)。

工程通过 Frameworks / Embed Frameworks 直接引用根目录 `XLINKDevice.xcframework`，不需要再额外添加 Swift Package。根目录 `Package.swift` 是供其他 App 以本地 Swift Package 方式接入 SDK 的可选入口，两种方式不要同时使用。

发行包里的 SDK 指南在本目录改名为 `SDK_README.md`，避免与本文件冲突；二进制与原始发行包保持一致。发行包附带的校验清单不随本仓库分发——仓库自身的版本控制已经承担了同样的作用。
