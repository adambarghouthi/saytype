// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SayType",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "SayType",
            dependencies: ["WhisperKit"],
            path: "Sources/SayType",
            exclude: ["Resources"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreML"),
                .linkedFramework("Metal"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
