import SwiftUI

struct ConnectView: View {
    @EnvironmentObject private var model: AppModel

    @State private var address = ""
    @State private var pin = ""
    @State private var shake = false
    @FocusState private var focus: Field?

    private enum Field { case address, pin }

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 26) {
                    Spacer(minLength: 40)
                    brand
                    addressCard
                    pairCard
                    Spacer(minLength: 24)
                    footnote
                }
                .padding(.horizontal, 22)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear { address = model.config.address }
        .onChange(of: model.connection) { _, newValue in
            if newValue == .unpaired { Haptics.tick() }
        }
        .overlay(alignment: .top) {
            if let message = model.errorMessage {
                ErrorBanner(message: message) { model.errorMessage = nil }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: Pieces

    private var background: some View {
        ZStack {
            Palette.ink.ignoresSafeArea()
            RadialGradient(
                colors: [Palette.ember.opacity(0.16), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
    }

    private var brand: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Palette.ember.opacity(0.12))
                    .frame(width: 92, height: 92)
                    .blur(radius: 18)
                Image(systemName: "tv.inset.filled")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Palette.ember)
            }

            Text("Philips Remote")
                .font(.display(30, weight: .bold))
                .foregroundStyle(Palette.text)

            Text("Direkte på dit LAN. Ingen cloud, ingen konto.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.textMuted)
        }
    }

    private var addressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "TV-adresse")

            HStack(spacing: 10) {
                TextField("192.168.0.110", text: $address)
                    .focused($focus, equals: .address)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Palette.raised)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Palette.hairline, lineWidth: 1)
                            }
                    }

                Button {
                    Haptics.confirm()
                    focus = nil
                    model.config.address = address
                    Task { await model.connect() }
                } label: {
                    Group {
                        if model.connection == .connecting {
                            ProgressView().tint(Palette.ink)
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .frame(width: 54, height: 54)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Palette.ember)
                    }
                }
                .buttonStyle(.plain)
                .disabled(model.connection == .connecting)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(statusColour)
                    .frame(width: 6, height: 6)
                Text(statusLine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.textMuted)
            }

            Text("Find adressen på TV'et: Indstillinger → Netværk → Netværkskonfiguration.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textFaint)
        }
        .padding(18)
        .card()
    }

    @ViewBuilder
    private var pairCard: some View {
        if model.connection == .unpaired || model.connection == .connected {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Parring")

                if model.awaitingPin {
                    Text("TV'et viser en firecifret kode nu. Skriv den her.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.textMuted)

                    HStack(spacing: 10) {
                        TextField("••••", text: $pin)
                            .focused($focus, equals: .pin)
                            .keyboardType(.numberPad)
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .tracking(10)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Palette.text)
                            .padding(.vertical, 14)
                            .background {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Palette.raised)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(Palette.ember.opacity(0.5), lineWidth: 1)
                                    }
                            }
                            .onChange(of: pin) { _, value in
                                let filtered = String(value.filter(\.isNumber).prefix(4))
                                if filtered != value { pin = filtered }
                                if filtered.count == 4 {
                                    Haptics.confirm()
                                    focus = nil
                                    Task { await model.completePairing(pin: filtered) }
                                }
                            }
                            .offset(x: shake ? -8 : 0)
                            .animation(.default, value: shake)

                        Button("Annullér") { model.cancelPairing(); pin = "" }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.textMuted)
                    }
                } else {
                    Button {
                        Haptics.confirm()
                        Task { await model.beginPairing() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "key.horizontal")
                            Text(model.isBusy ? "Sender…" : "Par TV")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Palette.mint)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isBusy)

                    Text("Tryk Par TV, og bekræft derefter koden på fjernsynet.")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textFaint)
                }

                if model.connection == .connected && model.config.isPaired() {
                    Button("Glem parring") {
                        model.forgetPairing()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.ember)
                }
            }
            .padding(18)
            .card()
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private var footnote: some View {
        Text("Appen bruger Philips' JointSpace-API over lokal HTTPS. Den forlader aldrig hjemmenetværket og spørger aldrig Apples servere.")
            .font(.system(size: 11))
            .foregroundStyle(Palette.textFaint)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
    }

    private var statusColour: Color {
        switch model.connection {
        case .connected:  return Palette.mint
        case .connecting: return Palette.sun
        case .unpaired:   return Palette.sun
        case .failed:     return Palette.ember
        case .idle:       return Palette.textFaint
        }
    }

    private var statusLine: String {
        switch model.connection {
        case .connected:  return "Forbundet · \(model.snapshot.latencyMS) ms"
        case .connecting: return "Kontakter TV'et…"
        case .unpaired:   return "TV'et svarer — klar til parring"
        case .failed:     return "Ingen forbindelse"
        case .idle:       return "Klar"
        }
    }
}
