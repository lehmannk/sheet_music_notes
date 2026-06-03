// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "sheet_music_notes",
    platforms: [
        .macOS("10.14"),
    ],
    products: [
        .library(name: "sheet-music-notes", targets: ["sheet_music_notes"]),
    ],
    targets: [
        .target(
            name: "sheet_music_notes"
        ),
    ]
)
