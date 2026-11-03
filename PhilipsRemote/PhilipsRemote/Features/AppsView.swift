import SwiftUI

struct AppsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""

    private var filtered: [TVApplication] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return model.snapshot.applications
        }
        return model.snapshot.applications.filter {
            $0.label.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        PageScaffold(title: "Apps") {
            VStack(spacing: 12) {
                SearchField(text: $query, placeholder: "Søg i TV'ets apps")

                if filtered.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)
                            ],
                            spacing: 10
                        ) {
                            ForEach(filtered) { app in
                                appTile(app)
                            }
                        }
                        .padding(.bottom, 96)
                    }
                }
            }
        }
    }

    private func appTile(_ app: TVApplication) -> some View {
        Button {
            model.launch(app)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Palette.raised)
                        .frame(width: 40, height: 40)
                    Text(String(app.label.prefix(1)).uppercased())
                        .font(.display(17, weight: .bold))
                        .foregroundStyle(Palette.ember)
                }
                Text(app.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .card(radius: 20)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Palette.textFaint)
            Text(query.isEmpty ? "TV'et sendte ingen app-liste." : "Ingen apps matcher \"\(query)\".")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shared search field

struct SearchField: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.textFaint)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.text)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.textFaint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 1)
                }
        }
    }
}
