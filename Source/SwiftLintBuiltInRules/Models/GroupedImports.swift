import SwiftSyntax

/// Where a module sits in an import run: Apple's frameworks, then the project's own, then everything else.
///
/// An unrecognised name is third-party rather than Apple, because a new dependency is far more likely than
/// an Apple framework nobody has listed.
enum ImportGroup: Int, Comparable {
    case apple
    case ours
    case thirdParty

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// One line of a run: where it sits, what moves, and the group it belongs to.
struct GroupedImportLine {
    let index: Int
    let declaration: ImportDeclSyntax
    let text: String
    let group: ImportGroup

    var position: AbsolutePosition {
        declaration.positionAfterSkippingLeadingTrivia
    }
}

extension CodeBlockItemListSyntax {
    /// The runs of imports the grouping reorders, as index ranges into this list.
    ///
    /// A run is what the eye reads as one block: consecutive single-module imports with nothing between them.
    /// A blank line, a comment, a submodule import (`import os.log`) or any other statement ends one and may
    /// begin the next, so a file's header comment and its grouped imports never trade places.
    func importRuns(ourModules: Set<String>) -> [[GroupedImportLine]] {
        var runs: [[GroupedImportLine]] = []
        var current: [GroupedImportLine] = []

        for (index, item) in enumerated() {
            guard let declaration = item.item.as(ImportDeclSyntax.self),
                declaration.path.count == 1,
                let module = declaration.path.first?.name.text
            else {
                if current.count > 1 {
                    runs.append(current)
                }
                current = []
                continue
            }
            let trivia = item.leadingTrivia
            if !current.isEmpty, trivia.containsComment || trivia.containsBlankLine {
                if current.count > 1 {
                    runs.append(current)
                }
                current = []
            }
            current.append(
                GroupedImportLine(
                    index: index,
                    declaration: declaration,
                    text: declaration.trimmedDescription,
                    group: module.importGroup(ourModules: ourModules)
                ))
        }
        if current.count > 1 {
            runs.append(current)
        }
        return runs
    }
}

extension [GroupedImportLine] {
    /// The run's lines in the order the rule wants them: by group, alphabetically within a group ignoring
    /// case, and with an exact duplicate dropped.
    var grouped: [String] {
        var seen: Set<String> = []
        return
            filter { seen.insert($0.text).inserted }
            .sorted {
                if $0.group != $1.group {
                    return $0.group < $1.group
                }
                let left = $0.text.lowercased()
                let right = $1.text.lowercased()
                return left == right ? $0.text < $1.text : left < right
            }
            .map(\.text)
    }

    /// The first line that would move, which is where the violation is reported.
    var firstOutOfPlace: GroupedImportLine? {
        let wanted = grouped
        return first { line in
            let offset = line.index - self[0].index
            return offset >= wanted.count || wanted[offset] != line.text
        }
    }
}

private extension String {
    func importGroup(ourModules: Set<String>) -> ImportGroup {
        if ourModules.contains(self) {
            return .ours
        }
        return appleFrameworks.contains(self) ? .apple : .thirdParty
    }
}

/// Apple's own modules, which is knowledge about the SDK rather than about any project.
private let appleFrameworks: Set<String> = [
    "ARKit", "AVFoundation", "AVKit", "Accelerate", "ActivityKit", "Android", "AppKit",
    "AppTrackingTransparency", "AudioToolbox", "AudioUnit", "AuthenticationServices",
    "AutomaticAssessmentConfiguration", "BackgroundAssets", "BackgroundTasks", "Bionic", "Builtin",
    "CFNetwork", "CRT", "CallKit", "CarPlay", "Charts", "ClockKit", "CloudKit", "Combine", "Contacts",
    "ContactsUI", "CoreAnimation", "CoreAudio", "CoreBluetooth", "CoreData", "CoreFoundation",
    "CoreGraphics", "CoreHaptics", "CoreImage", "CoreLocation", "CoreMIDI", "CoreML", "CoreMedia",
    "CoreMotion", "CoreNFC", "CoreSpotlight", "CoreTelephony", "CoreText", "CreateML", "CryptoKit",
    "CryptoTokenKit", "Darwin", "DeveloperToolsSupport", "DeviceActivity", "DeviceCheck", "Dispatch",
    "EventKit", "EventKitUI", "ExternalAccessory", "FamilyControls", "FileProvider", "Foundation",
    "FoundationEssentials", "FoundationModels", "FoundationNetworking", "GameController", "GameKit",
    "GameplayKit", "Glibc", "GroupActivities", "HealthKit", "HomeKit", "ImageIO", "Intents", "IntentsUI",
    "LinkPresentation", "LocalAuthentication", "ManagedSettings", "MapKit", "MediaPlayer", "MessageUI",
    "Messages", "Metal", "MetalKit", "MetalPerformanceShaders", "MetricKit", "MobileCoreServices",
    "MultipeerConnectivity", "MusicKit", "Musl", "NaturalLanguage", "NearbyInteraction", "Network",
    "NetworkExtension", "NotificationCenter", "OSLog", "ObjectiveC", "Observation", "PDFKit",
    "PackageDescription", "PackagePlugin", "PassKit", "PencilKit", "Photos", "PhotosUI", "PushKit",
    "QuartzCore", "QuickLook", "QuickLookThumbnailing", "RealityKit", "ReplayKit", "SQLite3",
    "SafariServices", "SceneKit", "ScreenCaptureKit", "Security", "SensorKit", "ServiceManagement",
    "ShazamKit", "SimulationKit", "Social", "SoundAnalysis", "Speech", "SpriteKit", "StoreKit", "Swift",
    "SwiftData", "SwiftShims", "SwiftUI", "SwiftUICore", "Synchronization", "SystemConfiguration",
    "TabularData", "Testing", "ThreadNetwork", "TipKit", "Translation", "UIKit",
    "UniformTypeIdentifiers", "UserNotifications", "UserNotificationsUI", "VideoToolbox", "Vision",
    "VisionKit", "WASILibc", "WatchKit", "WeatherKit", "WebKit", "WidgetKit", "WinSDK", "XCTest",
    "XcodeProjectPlugin", "os", "ucrt", "wasi_pthread",
]

extension Trivia {
    var containsBlankLine: Bool {
        pieces.contains { piece in
            if case let .newlines(count) = piece {
                return count > 1
            }
            return false
        }
    }
}
