// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iTermGUI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "iTermGUI",
            targets: ["iTermGUI"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "iTermGUI",
            dependencies: [],
            path: "Sources/iTermGUI"
        ),
        .testTarget(
            name: "iTermGUITests",
            dependencies: ["iTermGUI"],
            path: "Tests/iTermGUITests"
        )
    ]
)