// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GluCoPilot",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "GluCoPilot",
            targets: ["GluCoPilot"]
        ),
    ],
    targets: [
        .target(
            name: "GluCoPilot",
            path: "GluCoPilot"
        ),
    ]
)
