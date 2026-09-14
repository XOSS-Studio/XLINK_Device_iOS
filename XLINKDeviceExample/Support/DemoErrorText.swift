//
//  DemoErrorText.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-10.
//

import Foundation
import XLINKDevice

/// 把 SDK 错误翻成「错误名 + 描述」两段，让演示界面既能显示错误类型也能显示原因。
enum DemoErrorText {
    static func describe(_ error: any Error) -> (name: String, message: String) {
        guard let deviceError = error as? XLINKDeviceError else {
            return (String(describing: type(of: error)), error.localizedDescription)
        }
        return (name(for: deviceError), deviceError.errorDescription ?? deviceError.localizedDescription)
    }

    private static func name(for error: XLINKDeviceError) -> String {
        switch error {
        case .sdkNotInitialized: return "sdkNotInitialized"
        case .authenticationFailed: return "authenticationFailed"
        case .tokenInvalid: return "tokenInvalid"
        case .tokenExpired: return "tokenExpired"
        case .tokenMissing: return "tokenMissing"
        case .deviceNotFound: return "deviceNotFound"
        case .deviceNotConnected: return "deviceNotConnected"
        case .connectionFailed: return "connectionFailed"
        case .disconnected: return "disconnected"
        case .timeout: return "timeout"
        case .commandFailed: return "commandFailed"
        case .deviceBusy: return "deviceBusy"
        case .commandNotSupported: return "commandNotSupported"
        case .invalidParameter: return "invalidParameter"
        case .operationFailed: return "operationFailed"
        case .operationNotPermitted: return "operationNotPermitted"
        case .fileNotFound: return "fileNotFound"
        case .fileDecodeFailed: return "fileDecodeFailed"
        case .storageFull: return "storageFull"
        case .dataCorrupted: return "dataCorrupted"
        case .fileTransferFailed: return "fileTransferFailed"
        case .operationCancelled: return "operationCancelled"
        case .checksumError: return "checksumError"
        case .operationRejected: return "operationRejected"
        case .networkError: return "networkError"
        case .unknownError: return "unknownError"
        @unknown default: return "unknown"
        }
    }
}

/// JSON 编码工具：接收文件类演示统一用它把响应转成可读文本。
enum DemoJSON {
    static func string<T: Encodable>(from value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value),
              let text = String(data: data, encoding: .utf8)
        else {
            return String(describing: value)
        }
        return text
    }
}
