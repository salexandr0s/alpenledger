// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AlpenLedgerKit",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "ALDomain", targets: ["ALDomain"]),
        .library(name: "ALAudit", targets: ["ALAudit"]),
        .library(name: "ALStorage", targets: ["ALStorage"]),
        .library(name: "ALWorkspace", targets: ["ALWorkspace"]),
        .library(name: "ALImports", targets: ["ALImports"]),
        .library(name: "ALLedger", targets: ["ALLedger"]),
        .library(name: "ALDocuments", targets: ["ALDocuments"]),
        .library(name: "ALEvidence", targets: ["ALEvidence"]),
        .library(name: "ALTaxCore", targets: ["ALTaxCore"]),
        .library(name: "ALTaxCH", targets: ["ALTaxCH"]),
        .library(name: "ALDesignSystem", targets: ["ALDesignSystem"]),
        .library(name: "ALFeatures", targets: ["ALFeatures"]),
    ],
    dependencies: [
        .package(path: "../Vendor/GRDB.swift"),
    ],
    targets: [
        .target(
            name: "ALDomain"
        ),
        .target(
            name: "ALStorage",
            dependencies: [
                "ALDomain",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .target(
            name: "ALAudit",
            dependencies: [
                "ALDomain",
                "ALStorage",
            ]
        ),
        .target(
            name: "ALWorkspace",
            dependencies: [
                "ALDomain",
                "ALStorage",
                "ALAudit",
            ]
        ),
        .target(
            name: "ALLedger",
            dependencies: [
                "ALDomain",
                "ALStorage",
                "ALAudit",
                "ALWorkspace",
            ]
        ),
        .target(
            name: "ALDocuments",
            dependencies: [
                "ALDomain",
                "ALStorage",
                "ALAudit",
                "ALWorkspace",
            ]
        ),
        .target(
            name: "ALImports",
            dependencies: [
                "ALDomain",
                "ALStorage",
                "ALAudit",
                "ALDocuments",
                "ALLedger",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .target(
            name: "ALEvidence",
            dependencies: [
                "ALDomain",
                "ALStorage",
                "ALAudit",
                "ALLedger",
                "ALDocuments",
                "ALWorkspace",
            ]
        ),
        .target(
            name: "ALTaxCore",
            dependencies: [
                "ALDomain",
                "ALStorage",
                "ALAudit",
                "ALLedger",
                "ALEvidence",
                "ALWorkspace",
            ]
        ),
        .target(
            name: "ALTaxCH",
            dependencies: [
                "ALDomain",
                "ALTaxCore",
                "ALEvidence",
                "ALLedger",
                "ALWorkspace",
            ]
        ),
        .target(
            name: "ALDesignSystem"
        ),
        .target(
            name: "ALFeatures",
            dependencies: [
                "ALDesignSystem",
                "ALDomain",
                "ALWorkspace",
            ]
        ),
        .testTarget(
            name: "ALDomainTests",
            dependencies: ["ALDomain"]
        ),
        .testTarget(
            name: "ALStorageTests",
            dependencies: [
                "ALStorage",
                "ALDomain",
                "ALWorkspace",
                "ALTaxCore",
            ]
        ),
        .testTarget(
            name: "ALImportsTests",
            dependencies: [
                "ALImports",
                "ALStorage",
                "ALDocuments",
                "ALLedger",
                "ALWorkspace",
            ]
        ),
        .testTarget(
            name: "ALLedgerTests",
            dependencies: [
                "ALLedger",
                "ALDomain",
            ]
        ),
        .testTarget(
            name: "ALDocumentsTests",
            dependencies: [
                "ALDocuments",
                "ALStorage",
            ]
        ),
        .testTarget(
            name: "ALEvidenceTests",
            dependencies: [
                "ALEvidence",
                "ALAudit",
                "ALDocuments",
                "ALImports",
                "ALStorage",
                "ALWorkspace",
                "ALLedger",
                "ALDomain",
            ]
        ),
        .testTarget(
            name: "ALTaxCoreTests",
            dependencies: [
                "ALTaxCore",
                "ALTaxCH",
                "ALDocuments",
                "ALStorage",
                "ALWorkspace",
                "ALImports",
                "ALLedger",
                "ALAudit",
                "ALEvidence",
                "ALDomain",
            ]
        ),
    ]
)
