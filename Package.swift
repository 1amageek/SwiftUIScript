// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "SwiftUIScript",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "SwiftUIScriptCore", targets: ["SwiftUIScriptCore"]),
        .library(name: "SwiftUIScriptCompiler", targets: ["SwiftUIScriptCompiler"]),
        .library(name: "SwiftUIScript", targets: ["SwiftUIScript"]),
        .library(name: "SwiftUIScriptGallery", targets: ["SwiftUIScriptGallery"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            exact: "603.0.2"
        ),
    ],
    targets: [
        .target(
            name: "SwiftUIScriptCore",
            path: "Sources/SwiftUIScriptCore",
            exclude: ["DESIGN.md"]
        ),
        .target(
            name: "SwiftUIScriptCompiler",
            dependencies: [
                "SwiftUIScriptCore",
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ],
            path: "Sources/SwiftUIScriptCompiler",
            exclude: ["DESIGN.md"]
        ),
        .target(
            name: "SwiftUIScript",
            dependencies: ["SwiftUIScriptCore"],
            path: "Sources/SwiftUIScript",
            exclude: ["DESIGN.md"]
        ),
        .target(
            name: "SwiftUIScriptGallery",
            dependencies: ["SwiftUIScript", "SwiftUIScriptCompiler"],
            path: "Sources/SwiftUIScriptGallery",
            exclude: ["DESIGN.md"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "SwiftUIScriptCompilerTests",
            dependencies: ["SwiftUIScriptCompiler", "SwiftUIScriptCore"],
            path: "Tests/SwiftUIScriptCompilerTests"
        ),
        .testTarget(
            name: "SwiftUIScriptCoreTests",
            dependencies: ["SwiftUIScriptCore"],
            path: "Tests/SwiftUIScriptCoreTests"
        ),
        .testTarget(
            name: "SwiftUIScriptTests",
            dependencies: ["SwiftUIScript", "SwiftUIScriptCompiler", "SwiftUIScriptCore"],
            path: "Tests/SwiftUIScriptTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
