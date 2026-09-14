//
//  DemoActionRunner.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-10.
//

import Foundation

/// 统一执行一次 SDK 调用并把过程写进宿主的 `DemoActionResult` 属性：置执行中、计时、成功摘要、失败错误名。
/// 不吞错、不重试，失败原样反映 SDK 的返回。
///
/// 结果用 KeyPath 写回而不是 `inout`：`inout` 跨 `await` 会与 SwiftUI 的属性访问冲突。
@MainActor
enum DemoActionRunner {

    /// 有返回值的调用。
    @discardableResult
    static func run<Owner: AnyObject, T>(
        _ owner: Owner,
        _ keyPath: ReferenceWritableKeyPath<Owner, DemoActionResult>,
        operation: () async throws -> T,
        summarize: (T) -> (summary: String, detail: String?)
    ) async -> T? {
        owner[keyPath: keyPath] = DemoActionResult(phase: .running, summary: "执行中…")
        let start = Date()
        do {
            let value = try await operation()
            let described = summarize(value)
            owner[keyPath: keyPath] = DemoActionResult(
                phase: .succeeded,
                duration: Date().timeIntervalSince(start),
                summary: described.summary,
                detail: described.detail,
                errorName: nil,
                finishedAt: Date()
            )
            return value
        } catch {
            let described = DemoErrorText.describe(error)
            owner[keyPath: keyPath] = DemoActionResult(
                phase: .failed,
                duration: Date().timeIntervalSince(start),
                summary: described.message,
                detail: nil,
                errorName: described.name,
                finishedAt: Date()
            )
            return nil
        }
    }

    /// 无返回值的调用。
    static func run<Owner: AnyObject>(
        _ owner: Owner,
        _ keyPath: ReferenceWritableKeyPath<Owner, DemoActionResult>,
        successSummary: String,
        operation: () async throws -> Void
    ) async {
        await run(
            owner,
            keyPath,
            operation: operation,
            summarize: { _ in (successSummary, nil) }
        )
    }

    /// 把 SDK 的同步布尔返回也纳入统一展示。
    static func runSync<Owner: AnyObject>(
        _ owner: Owner,
        _ keyPath: ReferenceWritableKeyPath<Owner, DemoActionResult>,
        successSummary: String,
        failureSummary: String,
        operation: () -> Bool
    ) {
        let start = Date()
        let succeeded = operation()
        owner[keyPath: keyPath] = DemoActionResult(
            phase: succeeded ? .succeeded : .failed,
            duration: Date().timeIntervalSince(start),
            summary: succeeded ? successSummary : failureSummary,
            detail: nil,
            errorName: succeeded ? nil : "returnedFalse",
            finishedAt: Date()
        )
    }
}
