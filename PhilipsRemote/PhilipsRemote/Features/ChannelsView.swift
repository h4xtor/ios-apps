import SwiftUI

struct ChannelsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""

    private var filtered: [TVChannel] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return model.snapshot.channels
        }
        return model.snapshot.channels.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.displayNumber.contains(query)
        }
    }

    var body: some View {
        PageScaffold(title: "Kanaler") {
            VStack(spacing: 12) {
                SearchField(text: $query, placeholder: "Søg kanal eller nummer")

                HStack {
                    Text("\(filtered.count) kanaler")
                        .font(.label(10, weight: .semibold))
                        .foregroundStyle(Palette.textFaint)
                    Spacer()
                    if !model.snapshot.currentChannel.isEmpty {
                        Text("Nu: \(model.snapshot.currentChannel)")
                            .font(.label(10, weight: .semibold))
                            .foregroundStyle(Palette.mint)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 4)

                if filtered.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(filtered) { channel in
                                row(channel)
                            }
                        }
                        .padding(.bottom, 96)
                    }
                }
            }
        }
    }

    private func row(_ channel: TVChannel) -> some View {
        Button {
            model.tune(channel)
        } label: {
            HStack(spacing: 14) {
                Text(channel.displayNumber)
                    .font(.label(12, weight: .bold))
                    .foregroundStyle(Palette.ember)
                    .frame(minWidth: 42)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Palette.raised)
                    }

                Text(channel.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)

                Spacer(minLength: 6)

                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.textFaint)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
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

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tv.slash")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Palette.textFaint)
            Text(query.isEmpty ? "TV'et sendte ingen kanalliste." : "Ingen kanaler matcher \"\(query)\".")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
        .frame(maxWidth: .infinity)
    }
}
