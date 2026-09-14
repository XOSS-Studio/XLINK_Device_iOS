//
//  DemoChrome.swift
//  XLINKDeviceExample
//
//  Created by Skyler Liu on 2026-09-08.
//

import SwiftUI

/// Demo 视觉底：iOS 26 走 Liquid Glass，更早系统用材质卡片。
enum DemoChrome {
    static let cardRadius: CGFloat = 20
}

/// 授权页 / 设备页共用的浅色到蓝灰渐变底。
struct DemoCanvas: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color(red: 0.10, green: 0.14, blue: 0.22),
                    Color(red: 0.06, green: 0.06, blue: 0.08),
                ]
                : [
                    Color(red: 0.86, green: 0.91, blue: 1.00),
                    Color(red: 0.94, green: 0.95, blue: 0.98),
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct DemoGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = DemoChrome.cardRadius
    var interactive: Bool = false

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        }
    }

    @available(iOS 26.0, *)
    private var glass: Glass {
        interactive ? .regular.interactive() : .regular
    }
}

/// 同屏多块玻璃时合批，低版本原样透传。
struct DemoGlassGroup<Content: View>: View {
    var spacing: CGFloat = 20
    @ViewBuilder var content: Content

    init(spacing: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

extension View {
    /// 卡片容器：iOS 26 为 `glassEffect`，否则材质 + 轻阴影。
    func demoGlassCard(cornerRadius: CGFloat = DemoChrome.cardRadius, interactive: Bool = false) -> some View {
        modifier(DemoGlassCardModifier(cornerRadius: cornerRadius, interactive: interactive))
    }

    @ViewBuilder
    func demoProminentButton(size: ControlSize = .large) -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent).controlSize(size)
        } else {
            buttonStyle(.borderedProminent).controlSize(size)
        }
    }

    @ViewBuilder
    func demoGlassButton(size: ControlSize = .large) -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass).controlSize(size)
        } else {
            buttonStyle(.bordered).controlSize(size)
        }
    }
}
