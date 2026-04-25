// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "iTermGUI",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(
            name: "iTermGUI",
            targets: ["iTermGUI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "iTermGUI",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/iTermGUI",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "iTermGUITests",
            dependencies: ["iTermGUI"],
            path: "Tests/iTermGUITests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
