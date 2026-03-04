// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EmbyPulse",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "EmbyPulse",
            targets: ["EmbyPulse"]),
    ],
    dependencies: [
        // 网络请求
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.1"),
        // SwiftUI 图表
        .package(url: "https://github.com/AppPear/ChartView.git", from: "3.0.0"),
        // 图标
        .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI.git", from: "2.0.0"),
        // Keychain 存储
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
        // 本地缓存
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.1"),
    ],
    targets: [
        .target(
            name: "EmbyPulse",
            dependencies: [
                "Alamofire",
                "ChartView",
                "SDWebImageSwiftUI",
                "KeychainAccess",
                .product(name: "SQLite", package: "SQLite.swift"),
            ]),
        .testTarget(
            name: "EmbyPulseTests",
            dependencies: ["EmbyPulse"]),
    ]
)