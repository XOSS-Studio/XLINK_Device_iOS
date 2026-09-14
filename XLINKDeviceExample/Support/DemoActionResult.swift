//
//  DemoActionResult.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-10.
//

import Foundation

/// 一次 SDK 调用所处的阶段。
enum DemoActionPhase: Equatable {
    case idle
    case running
    case succeeded
    case failed
}

/// 一次 SDK 调用的结果，供动作卡展示。
struct DemoActionResult: Equatable {
    var phase: DemoActionPhase = .idle
    /// 调用耗时，仅在结束后有值
    var duration: TimeInterval?
    /// 一行摘要
    var summary: String = ""
    /// 完整响应，非空时动作卡提供展开入口
    var detail: String?
    /// 失败时的错误名，例如 `timeout`
    var errorName: String?
    /// 结束时间，用于展示「刚刚执行」
    var finishedAt: Date?

    static let idle = DemoActionResult()

    var isRunning: Bool { phase == .running }

    /// 耗时文案：毫秒级用 ms，秒级保留一位小数。
    var durationText: String? {
        guard let duration else { return nil }
        if duration < 1 {
            return String(format: "%.0f ms", duration * 1000)
        }
        return String(format: "%.1f s", duration)
    }
}
