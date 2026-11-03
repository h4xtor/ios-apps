import SwiftUI

struct AmbilightView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        PageScaffold(title: "Ambilight") {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    powerCard
                    presetGrid
                    telemetry
                }
                .padding(.bottom, 96)
            }
        }
    }

    private var powerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(model.snapshot.ambilightPower ? Palette.ember.opacity(0.18) : Palette.raised)
                    .frame(width: 58, height: 58)
                Circle()
                    .fill(model.snapshot.ambilightPower ? Palette.ember : Palette.textFaint)
                    .frame(width: 14, height: 14)
                    .shadow(
                        color: model.snapshot.ambilightPower ? Palette.ember : .clear,
                        radius: 12
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(model.snapshot.ambilightPower ? "Ambilight er tændt" : "Ambilight er slukket")
                    .font(.display(16, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Text(model.snapshot.ambilightStyle.isEmpty
                     ? "Ingen aktiv profil rapporteret"
                     : "\(model.snapshot.ambilightStyle) · \(model.snapshot.ambilightSetting)")
                    .font(.label(10, weight: .medium))
                    .foregroundStyle(Palette.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(
                get: { model.snapshot.ambilightPower },
                set: { model.setAmbilight(power: $0) }
            ))
            .labelsHidden()
            .tint(Palette.ember)
        }
        .padding(16)
        .card(glow: model.snapshot.ambilightPower ? Palette.ember : Optional<Color>.none)
    }

    private var presetGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Profiler")
                .padding(.horizontal, 4)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(AmbilightPreset.all) { preset in
                    Button {
                        model.setAmbilight(preset: preset)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Circle()
                                .fill(Color(hex: UInt32(preset.tint)))
                                .frame(width: 10, height: 10)
                                .shadow(color: Color(hex: UInt32(preset.tint)).opacity(0.8), radius: 8)

                            Text(preset.label)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Palette.text)

                            Text(preset.setting.replacingOccurrences(of: "_", with: " ").lowercased())
                                .font(.label(9, weight: .medium))
                                .foregroundStyle(Palette.textFaint)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .card(radius: 18)
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(
                                    isActive(preset) ? Color(hex: UInt32(preset.tint)).opacity(0.8) : .clear,
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var telemetry: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Telemetri")

            row("Power", model.snapshot.ambilightPower ? "On" : "Off")
            row("Style", model.snapshot.ambilightStyle.isEmpty ? "—" : model.snapshot.ambilightStyle)
            row("Setting", model.snapshot.ambilightSetting.isEmpty ? "—" : model.snapshot.ambilightSetting)
            row("TV", "\(model.config.address) · \(model.snapshot.latencyMS) ms")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.textMuted)
            Spacer()
            Text(value)
                .font(.label(11, weight: .semibold))
                .foregroundStyle(Palette.text)
                .lineLimit(1)
        }
    }

    private func isActive(_ preset: AmbilightPreset) -> Bool {
        model.snapshot.ambilightStyle == preset.style &&
        model.snapshot.ambilightSetting == preset.setting
    }
}
