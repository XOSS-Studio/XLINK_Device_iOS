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