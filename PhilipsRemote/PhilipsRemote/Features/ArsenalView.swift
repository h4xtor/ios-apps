import SwiftUI

struct ArsenalView: View {
    @EnvironmentObject private var model: AppModel
    @State private var group: TVCommand.KeyGroup = .system

    private var keys: [(label: String, key: String, group: TVCommand.KeyGroup)] {
        TVCommand.all.filter { $0.group == group }
    }

    var body: some View {
        PageScaffold(title: "Alle taster") {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    numpadCard
                    sourceCard
                    keyCard
                }
                .padding(.bottom, 96)
            }
        }
    }

    private var numpadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Kanaltastatur")

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                ForEach(1...9, id: \.self) { number in
                    digit(number)
                }
                Color.clear.frame(height: 46)
                digit(0)
                Button {
                    model.send("Back")
                } label: {
                    Image(systemName: "delete.left")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(KeyStyle(tint: Palette.textMuted, height: 46, radius: 13))
            }
        }
        .padding(16)
        .card()
    }

    private func digit(_ number: Int) -> some View {
        Button {
            model.digited(number)
        } label: {
            Text("\(number)")
                .font(.display(19, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
        }
        .buttonStyle(KeyStyle(tint: Palette.text, height: 46, radius: 13))
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Kilder")

            HStack(spacing: 8) {
                ForEach(SourceRoute.all) { route in
                    Button {
                        model.selectSource(route)
                    } label: {
                        Text(route.label)
                            .font(.label(11, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(KeyStyle(
                        tint: route.label == "TV" ? Palette.mint : Palette.text,
                        height: 44,
                        radius: 13
                    ))
                }
            }
        }
        .padding(16)
        .card()
    }

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: "Tastatur")
                Spacer()
                Text("\(TVCommand.all.count) taster")
                    .font(.label(9, weight: .semibold))
                    .foregroundStyle(Palette.textFaint)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TVCommand.KeyGroup.allCases) { item in
                        Button {
                            group = item
                            Haptics.tick()
                        } label: {
                            Text(item.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(group == item ? Palette.ink : Palette.textMuted)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background {
                                    Capsule()
                                        .fill(group == item ? Palette.text : Palette.raised)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                ForEach(keys.indices, id: \.self) { index in
                    let item = keys[index]
                    Button {
                        model.send(item.key)
                    } label: {
                        Text(item.label)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                    }
                    .buttonStyle(KeyStyle(tint: Palette.text, height: 46, radius: 13))
                }
            }
        }
        .padding(16)
        .card()
    }
}
