import Foundation
import Combine
import SwiftUI

@MainActor
final class AppModel: ObservableObject {

    // MARK: Published state

    @Published private(set) var snapshot = TVSnapshot()
    @Published private(set) var connection: Connection = .idle
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?
    @Published private(set) var lastAction: String = ""

    let config = ConfigStore()

    enum Connection: Equatable {
        case idle
        case connecting
        case connected
        case unpaired
        case failed(String)

        var isLive: Bool { self == .connected }
    }

    // MARK: Private

    private var client: PhilipsTVClient?
    private var refreshTask: Task<Void, Never>?

    // MARK: Lifecycle

    func bootstrap() {
        guard connection == .idle else { return }
        Task { await connect() }
    }

    // MARK: Connection

    func connect() async {
        connection = .connecting
        errorMessage = nil

        let validation = ConfigStore.validate(address: config.address)
        let host: String
        switch validation {
        case .success(let value):
            host = value
        case .failure(let error):
            connection = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
            return
        }

        config.address = host
        let client = PhilipsTVClient(address: host)
        self.client = client

        do {
            let (info, latency) = try await client.testConnection()
            if let name = info["name"] as? String {
                lastAction = name
            }
            snapshot.latencyMS = latency

            guard config.isPaired(host) else {
                connection = .unpaired
                return
            }

            connection = .connected
            await refresh()
        } catch {
            connection = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        guard let client, connection.isLive || connection == .unpaired else { return }
        do {
            let fresh = try await client.loadSnapshot()
            snapshot = fresh
            if connection == .unpaired { return }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Pairing

    @Published var awaitingPin = false

    private var pendingPairing: PhilipsTVClient.PendingPairing?

    func beginPairing() async {
        guard let client else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            pendingPairing = try await client.startPairing()
            awaitingPin = true
            Haptics.confirm()
        } catch {
            Haptics.failure()
            errorMessage = error.localizedDescription
        }
    }

    func completePairing(pin: String) async {
        guard let client, let pending = pendingPairing else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            try await client.completePairing(pending, pin: pin)
            pendingPairing = nil
            awaitingPin = false
            Haptics.success()
            connection = .connected
            await refresh()
        } catch {
            Haptics.failure()
            errorMessage = error.localizedDescription
        }
    }

    func cancelPairing() {
        pendingPairing = nil
        awaitingPin = false
    }

    func forgetPairing() {
        config.forgetCredentials()
        connection = .unpaired
        snapshot = TVSnapshot()
    }

    func disconnect() {
        client = nil
        connection = .idle
        snapshot = TVSnapshot()
    }

    // MARK: Commands

    func send(_ key: String) {
        guard let client else { return }
        Task {
            do {
                try await client.sendKey(key)
                lastAction = key
                scheduleRefresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func power() {
        guard let client else { return }
        let next = snapshot.powerState.lowercased() == "on" ? "Standby" : "On"
        Task {
            do {
                try await client.setPower(next)
                snapshot.powerState = next
                Haptics.confirm()
                lastAction = next == "On" ? "Tændt" : "Standby"
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func volumeUp() {
        snapshot.volume.current = min(snapshot.volume.max, snapshot.volume.current + 1)
        send("VolumeUp")
    }

    func volumeDown() {
        snapshot.volume.current = max(snapshot.volume.min, snapshot.volume.current - 1)
        send("VolumeDown")
    }

    func toggleMute() {
        snapshot.volume.muted.toggle()
        send("Mute")
    }

    func setVolume(_ value: Int) {
        guard let client else { return }
        Task {
            do {
                snapshot.volume = try await client.setVolume(value)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Local preview while the finger is on the slider; nothing is sent until
    /// the gesture ends.
    func previewVolume(_ value: Int) {
        snapshot.volume.current = min(snapshot.volume.max, max(snapshot.volume.min, value))
    }

    func commitVolume() {
        setVolume(snapshot.volume.current)
    }

    func tune(_ channel: TVChannel) {
        guard let client else { return }
        Task {
            do {
                try await client.tune(channel)
                Haptics.confirm()
                lastAction = channel.name
                scheduleRefresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func launch(_ app: TVApplication) {
        guard let client else { return }
        Task {
            do {
                try await client.launch(app)
                Haptics.confirm()
                lastAction = app.label
                scheduleRefresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func selectSource(_ route: SourceRoute) {
        guard let client else { return }
        Task {
            do {
                try await client.selectSource(route)
                Haptics.confirm()
                lastAction = route.label
                scheduleRefresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func setAmbilight(power: Bool) {
        guard let client else { return }
        Task {
            do {
                try await client.setAmbilight(power: power)
                snapshot.ambilightPower = power
                Haptics.confirm()
                lastAction = power ? "Ambilight til" : "Ambilight fra"
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func setAmbilight(preset: AmbilightPreset) {
        guard let client else { return }
        Task {
            do {
                try await client.setAmbilight(style: preset.style, setting: preset.setting)
                snapshot.ambilightStyle = preset.style
                snapshot.ambilightSetting = preset.setting
                Haptics.confirm()
                lastAction = preset.label
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func digited(_ number: Int) {
        send("Digit\(number)")
    }

    // MARK: Helpers

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }
}
