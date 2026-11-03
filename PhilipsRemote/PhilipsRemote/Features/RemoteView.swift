import SwiftUI

struct RemoteView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        PageScaffold(title: "Fjernbetjening") {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    quickRow
                    hero
                    volumeCard
                    channelCard
                    transportRow
                    colourRow
                    appStrip
                }
                .padding(.bottom, 96)
            }
        }
    }

    // MARK: Quick keys

    private var quickRow: some View {
        HStack(spacing: 8) {
            quick("Power",   "power",     Palette.ember) { model.power() }
            quick("Home",    "house",     Palette.text)  { model.send("Home") }
            quick("Back",    "arrow.uturn.backward", Palette.text) { model.send("Back") }
            quick("Kilde",   "rectangle.on.rectangle", Palette.text) { model.send("Source") }
            quick("Info",    "info.circle", Palette.text) { model.send("Info") }
        }
    }

    private func quick(_ title: String, _ symbol: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Palette.textMuted)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Palette.hairline, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: D-pad

    private var hero: some View {
        VStack(spacing: 0) {
            DPad(
                onKey: { model.send($0) },
                onConfirm: { model.send("Confirm") }
            )
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .card(radius: 32, glow: Palette.ember)
    }

    // MARK: Volume

    private var volumeCard: some View {
        VStack(spacing: 12) {
            HStack {
                SectionLabel(text: "Lyd")
                Spacer()
                Text("\(model.snapshot.volume.current)")
                    .font(.label(13, weight: .bold))
                    .foregroundStyle(Palette.ember)
                Text("/ \(model.snapshot.volume.max)")
                    .font(.label(10))
                    .foregroundStyle(Palette.textFaint)
            }

            HStack(spacing: 14) {
                Button {
                    model.toggleMute()
                } label: {
                    Image(systemName: model.snapshot.volume.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(model.snapshot.volume.muted ? Palette.ink : Palette.text)
                        .frame(width: 46, height: 46)
                        .background {
                            Circle()
                                .fill(model.snapshot.volume.muted ? Palette.ember : Palette.raised)
                        }
                }
                .buttonStyle(.plain)

                Slider(
                    value: Binding(
                        get: { Double(model.snapshot.volume.current) },
                        set: { model.previewVolume(Int($0.rounded())) }
                    ),
                    in: Double(model.snapshot.volume.min)...Double(max(model.snapshot.volume.max, 1)),
                    onEditingChanged: { editing in
                        if !editing {
                            Haptics.confirm()
                            model.commitVolume()
                        }
                    }
                )
                .tint(Palette.ember)

                Button {
                    model.volumeUp()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .frame(width: 46, height: 46)
                        .background { Circle().fill(Palette.raised) }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .card()
    }

    // MARK: Channel

    private var channelCard: some View {
        HStack(spacing: 12) {
            Button {
                model.send("ChannelStepDown")
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 50, height: 50)
            }
            .buttonStyle(RoundKeyStyle(tint: Palette.text, diameter: 50))

            VStack(spacing: 2) {
                Text(model.snapshot.currentChannel.isEmpty ? "Live TV" : model.snapshot.currentChannel)
                    .font(.display(16, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("kanal")
                    .font(.label(9, weight: .medium))
                    .foregroundStyle(Palette.textFaint)
            }
            .frame(maxWidth: .infinity)

            Button {
                model.send("ChannelStepUp")
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 50, height: 50)
            }
            .buttonStyle(RoundKeyStyle(tint: Palette.text, diameter: 50))

            Button {
                model.send("Guide")
            } label: {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 50, height: 50)
            }
            .buttonStyle(RoundKeyStyle(tint: Palette.iris, diameter: 50))
        }
        .padding(14)
        .card()
    }

    // MARK: Transport

    private var transportRow: some View {
        HStack(spacing: 10) {
            transport("backward.end.fill", "Previous") { model.send("Previous") }
            transport("backward.fill", "Rewind") { model.send("Rewind") }
            Button {
                model.send("PlayPause")
            } label: {
                Image(systemName: "playpause.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 62, height: 62)
                    .background { Circle().fill(Palette.text) }
            }
            .buttonStyle(.plain)
            transport("forward.fill", "Fast forward") { model.send("FastForward") }
            transport("forward.end.fill", "Next") { model.send("Next") }
        }
    }

    private func transport(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.textMuted)
                .frame(width: 54, height: 54)
                .background {
                    Circle()
                        .fill(Palette.surface)
                        .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: 1) }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Colours

    private var colourRow: some View {
        HStack(spacing: 10) {
            colour("Red",    Palette.red,    "RedColour")
            colour("Green",  Palette.green,  "GreenColour")
            colour("Yellow", Palette.yellow, "YellowColour")
            colour("Blue",   Palette.blue,   "BlueColour")
        }
    }

    private func colour(_ name: String, _ tint: Color, _ key: String) -> some View {
        Button {
            model.send(key)
        } label: {
            Capsule()
                .fill(tint.opacity(0.9))
                .frame(height: 40)
                .overlay {
                    Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: tint.opacity(0.35), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
    }

    // MARK: App hotkeys

    @ViewBuilder
    private var appStrip: some View {
        if !model.snapshot.applications.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Genveje")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(model.snapshot.applications.prefix(10)) { app in
                            Button {
                                model.launch(app)
                            } label: {
                                Text(app.label)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Palette.text)
                                    .lineLimit(1)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 11)
                                    .background {
                                        Capsule()
                                            .fill(Palette.surface)
                                            .overlay {
                                                Capsule().strokeBorder(Palette.hairline, lineWidth: 1)
                                            }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - D-pad

struct DPad: View {
    let onKey: (String) -> Void
    let onConfirm: () -> Void

    private let size: CGFloat = 224
    private let offset: CGFloat = 74

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Palette.raised, Palette.surface],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    Circle().strokeBorder(Palette.hairline, lineWidth: 1)
                }
                .frame(width: size, height: size)

            Circle()
                .strokeBorder(Palette.ember.opacity(0.16), lineWidth: 10)
                .frame(width: size + 18, height: size + 18)
                .blur(radius: 10)

            arrow("chevron.up",    angle: .degrees(0))    { onKey("CursorUp") }
                .offset(y: -offset)
            arrow("chevron.down",  angle: .degrees(180))  { onKey("CursorDown") }
                .offset(y: offset)
            arrow("chevron.left",  angle: .degrees(-90))  { onKey("CursorLeft") }
                .offset(x: -offset)
            arrow("chevron.right", angle: .degrees(90))   { onKey("CursorRight") }
                .offset(x: offset)

            Button {
                Haptics.confirm()
                onConfirm()
            } label: {
                Text("OK")
                    .font(.display(19, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 92, height: 92)
                    .background {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Palette.ember, Palette.emberDim],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Palette.ember.opacity(0.45), radius: 18)
                    }
            }
            .buttonStyle(.plain)
        }
        .frame(width: size + 40, height: size + 40)
        .accessibilityElement(children: .contain)
    }

    private func arrow(_ symbol: String, angle: Angle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Palette.textMuted)
                .frame(width: 58, height: 58)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
