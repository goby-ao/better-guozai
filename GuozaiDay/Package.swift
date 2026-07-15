// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GuozaiCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "GuozaiCore", targets: ["GuozaiCore"]),
        .library(name: "GuozaiData", targets: ["GuozaiData"])
    ],
    targets: [
        .target(
            name: "GuozaiCore",
            path: "GuozaiCore/Sources/GuozaiCore"
        ),
        .testTarget(
            name: "GuozaiCoreTests",
            dependencies: ["GuozaiCore"],
            path: "GuozaiCore/Tests/GuozaiCoreTests"
        ),
        .target(
            name: "GuozaiData",
            dependencies: ["GuozaiCore"],
            path: "GuozaiDay/Data",
            exclude: [
                "Backup/AnalyticsCSVService.swift",
                "Notifications"
            ],
            sources: [
                "PersistenceModels.swift",
                "AppDataServices.swift",
                "AchievementStore.swift",
                "CoreSnapshotAdapters.swift",
                "Backup/AppBackupService.swift",
                "Backup/BackupDocuments.swift"
            ]
        ),
        .testTarget(
            name: "GuozaiDataTests",
            dependencies: ["GuozaiData", "GuozaiCore"],
            path: "GuozaiDayTests"
        )
    ]
)
