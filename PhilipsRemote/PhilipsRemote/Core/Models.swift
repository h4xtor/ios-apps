import Foundation
import UIKit

// MARK: - Domain

struct TVApplication: Identifiable, Equatable {
    let id: String
    let label: String
    let intent: [String: Any]
    let type: String

    static func == (lhs: TVApplication, rhs: TVApplication) -> Bool {
        lhs.id == rhs.id && lhs.label == rhs.label
    }
}

struct TVChannel: Identifiable, Equatable, Hashable {
    let ccid: Int
    let preset: String
    let name: String
    let listID: String

    var id: Int { ccid }

    var displayNumber: String {
        preset.isEmpty ? "\(ccid)" : preset
    }
}

struct TVSnapshot: Equatable {
    var system: [String: Any] = [:]
    var latencyMS: Int = 0
    var applications: [TVApplication] = []
    var channels: [TVChannel] = []
    var volume: VolumeState = .init()
    var powerState: String = "Unknown"
    var activity: String = ""
    var currentChannel: String = ""
    var ambilightPower: Bool = false
    var ambilightStyle: String = ""
    var ambilightSetting: String = ""
    var warnings: [String] = []

    static func == (lhs: TVSnapshot, rhs: TVSnapshot) -> Bool {
        lhs.latencyMS == rhs.latencyMS
            && lhs.applications == rhs.applications
            && lhs.channels == rhs.channels
            && lhs.volume == rhs.volume
            && lhs.powerState == rhs.powerState
            && lhs.activity == rhs.activity
            && lhs.currentChannel == rhs.currentChannel
            && lhs.ambilightPower == rhs.ambilightPower
            && lhs.ambilightStyle == rhs.ambilightStyle
    }
}

struct VolumeState: Equatable {
    var current: Int = 0
    var min: Int = 0
    var max: Int = 60
    var muted: Bool = false

    var fraction: Double {
        guard max > min else { return 0 }
        return Double(current - min) / Double(max - min)
    }
}

// MARK: - Static catalogue

enum TVCommand {
    /// Every key the JointSpace API accepts on 2016-and-later Philips sets.
    /// Label, API key, and the group it belongs to on the Arsenal screen.
    static let all: [(label: String, key: String, group: KeyGroup)] = [
        ("Standby",      "Standby",             .system),
        ("Home",         "Home",                .system),
        ("Source",       "Source",              .system),
        ("Back",         "Back",                .system),
        ("Options",      "Options",             .system),
        ("Info",         "Info",                .system),
        ("Guide",        "Guide",               .system),
        ("Adjust",       "Adjust",              .system),
        ("Find",         "Find",                .system),
        ("Online",       "Online",              .system),
        ("Watch TV",     "WatchTV",             .system),
        ("Ambilight",    "AmbilightOnOff",      .system),
        ("Subtitle",     "Subtitle",            .system),
        ("Teletext",     "Teletext",            .system),
        ("View mode",    "Viewmode",            .system),
        ("Play / Pause", "PlayPause",           .media),
        ("Play",         "Play",                .media),
        ("Pause",        "Pause",               .media),
        ("Stop",         "Stop",                .media),
        ("Record",       "Record",              .media),
        ("Previous",     "Previous",            .media),
        ("Next",         "Next",                .media),
        ("Rewind",       "Rewind",              .media),
        ("Fast fwd",     "FastForward",         .media),
        ("Red",          "RedColour",           .colour),
        ("Green",        "GreenColour",         .colour),
        ("Yellow",       "YellowColour",        .colour),
        ("Blue",         "BlueColour",          .colour),
        ("Cursor up",    "CursorUp",            .cursor),
        ("Cursor down",  "CursorDown",          .cursor),
        ("Cursor left",  "CursorLeft",          .cursor),
        ("Cursor right", "CursorRight",         .cursor),
        ("Confirm",      "Confirm",             .cursor),
        ("Channel +",    "ChannelStepUp",       .cursor),
        ("Channel −",    "ChannelStepDown",     .cursor),
        ("Volume +",     "VolumeUp",            .cursor),
        ("Volume −",     "VolumeDown",          .cursor),
        ("Mute",         "Mute",                .cursor)
    ]

    enum KeyGroup: String, CaseIterable, Identifiable {
        case system = "System"
        case cursor = "Navigation"
        case media  = "Transport"
        case colour = "Colour"
        var id: String { rawValue }
    }
}

struct SourceRoute: Identifiable, Hashable {
    let label: String
    let service: String
    var id: String { label }

    static let all: [SourceRoute] = [
        SourceRoute(label: "TV",     service: "content://android.media.tv/channel"),
        SourceRoute(label: "HDMI 1", service: "HW5"),
        SourceRoute(label: "HDMI 2", service: "HW6"),
        SourceRoute(label: "HDMI 3", service: "HW7"),
        SourceRoute(label: "HDMI 4", service: "HW8")
    ]
}

struct AmbilightPreset: Identifiable, Hashable {
    let label: String
    let style: String
    let setting: String
    let tint: Int
    var id: String { label }

    static let all: [AmbilightPreset] = [
        .init(label: "Natural",   style: "FOLLOW_VIDEO", setting: "NATURAL",                   tint: 0x3DD9B0),
        .init(label: "Game",      style: "FOLLOW_VIDEO", setting: "GAME",                      tint: 0x3FA9FF),
        .init(label: "Energy",    style: "FOLLOW_AUDIO", setting: "ENERGY_ADAPTIVE_BRIGHTNESS", tint: 0xFFC24B),
        .init(label: "Party",     style: "FOLLOW_AUDIO", setting: "PARTY",                      tint: 0x8E7DFF),
        .init(label: "Hot Lava",  style: "Lounge light", setting: "HOT_LAVA",                   tint: 0xFF5A3C),
        .init(label: "Deep Water", style: "Lounge light", setting: "DEEP_WATER",                tint: 0x3B7BF0)
    ]
}

enum PairingConstant {
    /// Philips' public pairing shared secret, identical on every 2016+ set.
    static let secret = Data(base64Encoded:
        "ZmVay1EQVFOaZhwQ4Kv81ypLAZNczV9sG4KkseXWn1NEk6cXmPKO/MCa9sryslvLCFMnNe4Z4CPXzToowvhHvA=="
    )!

    static let appID    = "dk.h4xtor.philipsremote"
    static let appName  = "H4XTOR Remote"
    static let deviceOS = "iOS \(UIDevice.current.systemVersion)"
}
