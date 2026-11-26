import SwiftUI

/// Search words, emoji, places, times and dates; results grouped by day, newest first.
struct SearchView: View {
    @Environment(RecordStore.self) private var store
    @Environment(AppModel.self) private var app
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var app = app
        ZStack {
            BrandBackground()
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    CircleIconButton(accessibilityLabel: "검색 닫기", action: close) {
                        Image("IconBack").renderingMode(.template).resizable().scaledToFit()
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.secondary)
                        TextField("", text: $app.searchQuery, prompt: Text("단어, 장소, 날짜 검색").foregroundStyle(Palette.secondary.opacity(0.7)))
                            .font(.brand(16))
                            .foregroundStyle(Palette.primary)
                            .focused($focused)
                            .submitLabel(.search)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        if !app.searchQuery.isEmpty {
                            Button { app.searchQuery = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.secondary)
                                    .frame(width: 32, height: 44)
                            }
                            .accessibilityLabel("검색어 지우기")
                        }
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, 6)
                    .frame(height: 48)
                    .background(Color.white.opacity(0.05), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                results
            }
        }
        .onAppear {
            if app.searchReturn == nil { app.searchReturn = (app.level, app.selectedDay) }
            if app.searchHighlight == nil { focused = true }
        }
    }

    @ViewBuilder
    private var results: some View {
        let found = store.search(app.searchQuery)
        if app.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            Spacer()
        } else if found.isEmpty {
            Text("검색 결과가 없어요.")
                .font(.brand(15))
                .foregroundStyle(Palette.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)
            Spacer()
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(found) { result in
                        Button { open(result) } label: { row(result) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func row(_ result: SearchResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(result.day.label)
                .font(.brand(13))
                .foregroundStyle(Palette.secondary)
            HStack(spacing: 10) {
                KindIcon(kind: result.item.kind, size: 16)
                Text(result.item.value)
                    .font(.brand(18))
                    .foregroundStyle(Palette.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.secondary)
            }
            Rectangle().fill(Palette.line).frame(height: 1)
        }
        .padding(.top, 18)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.day.label), \(result.item.kind.label) \(result.item.value)")
    }

    private func open(_ result: SearchResult) {
        focused = false
        app.searchHighlight = result.item.id
        app.openDay(result.day)
        app.isSearching = false
    }

    /// Closing search returns to the view and date that were open before it.
    private func close() {
        focused = false
        app.isSearching = false
        app.searchHighlight = nil
        app.searchQuery = ""
        if let (level, day) = app.searchReturn {
            app.select(day, haptic: false)
            app.setLevel(level)
        }
        app.searchReturn = nil
    }
}
