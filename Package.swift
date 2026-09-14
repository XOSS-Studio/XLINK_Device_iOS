// swift-tools-version: 6.0
// Created by Skyler Liu on 2026-09-11.
import PackageDescription

let package = Package(
    name: "XLINKDevice",
    platforms: [.iOS(.v17)],
    products: [.library(name: "XLINKDevice", targets: ["XLINKDevice"])],
    targets: [.binaryTarget(name: "XLINKDevice", path: "XLINKDevice.xcframework")]
)
