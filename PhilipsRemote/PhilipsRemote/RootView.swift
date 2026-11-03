import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var tab: Tab = .remote

    enum Tab: Hashable {
        case remote, apps, channels, ambilight, arsenal
    }

    var body: some View {
        ZStack {
            Palette.ink.ignoresSafeArea()

            if model.connection.isLive {
                shell
            } else {
                ConnectView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.connection.isLive)
        .task { model.bootstrap() }
    }

    private var shell: some View {
        TabView(selection: $tab) {
            RemoteView()
                .tag(Tab.remote)
                .tabItem { Label("Remote", systemImage: "dot.radiowaves.left.and.right") }

            AppsView()
                .tag(Tab.apps)
                .tabItem { Label("Apps", systemImage: "square.grid.2x2") }

            ChannelsView()
                .tag(Tab.channels)
                .tabItem { Label("Kanaler", systemImage: "tv") }

            AmbilightView()
                .tag(Tab.ambilight)
                .tabItem { Label("Ambilight", systemImage: "light.max") }

            ArsenalView()
                .tag(Tab.arsenal)
                .tabItem { Label("Alle taster", systemImage: "square.grid.3x3") }
        }
    }
}

// MARK: - Shared chrome

/// Every screen wears the same header: who we are talking to, whether it is
/// awake, and a way back to the connection screen.
struct ScreenHeader: View {
    @EnvironmentObject private var model: AppModel
    let title: String
    @State private var showConnect = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.display(22, weight: .bold))
                    .foregroundStyle(Palette.text)
                HStack(spacing: 6) {
                    StatusDot(colour: statusColour, pulsing: model.connection.isLive)
                    Text(subtitle)
                        .font(.label(10, weight: .medium))
                        .foregroundStyle(Palette.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Button {
                showConnect = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.textMuted)
                    .frame(width: 38, height: 38)
                    .background {
                        Circle().fill(Palette.raised)
                            .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: 1) }
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .sheet(isPresented: $showConnect) {
            ConnectView()
                .environmentObject(model)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
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

    private var subtitle: String {
        switch model.connection {
        case .connected:
            let latency = model.snapshot.latencyMS
            return "\(model.config.address) · \(latency) ms"
        case .connecting: return "forbinder…"
        case .unpaired:   return "ikke parret"
        case .failed(let message): return message
        case .idle:       return "offline"
        }
    }
}

// MARK: - Layout helpers

struct PageScaffold<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 14) {
            ScreenHeader(title: title)
            content
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.ink)
    }
}
