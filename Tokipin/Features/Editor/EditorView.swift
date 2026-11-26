import SwiftUI

/// 기록 입력: items stack in the order written; four kind tools stay above the keyboard.
struct EditorView: View {
    @Environment(RecordStore.self) private var store
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var model: EditorModel
    @State private var time = Date()
    @State private var keyboardWanted = true
    @State private var undoID: UUID?
    private let focusItem: UUID?

    /// Quick picks from the web demo, shown with the emoji tool. (Not in Figma — kept for parity with the homepage trial.)
    private let quickEmoji = ["🍊", "🧣", "🎧", "☕", "🌿", "📷", "🌙"]

    init(day: DayKey, focusItem: UUID?) {
        self.focusItem = focusItem
        _model = State(initialValue: EditorModel(day: day, items: [], draft: nil))
    }

    var body: some View {
        ZStack {
            BrandBackground()
            VStack(spacing: 0) {
                header
                canvas
                bottomControls
            }
        }
        .onAppear(perform: setUp)
        .onChange(of: model.draft) { _, draft in
            store.updateDraft(model.changed || !model.raw.isEmpty ? draft : nil)
        }
        .onChange(of: time) { _, value in
            if model.kind == .time { model.raw = Self.timeFormatter.string(from: value) }
        }
        .animation(.easeOut(duration: 0.18), value: model.selection != nil)
        .animation(.easeOut(duration: 0.18), value: undoID)
    }

    private func setUp() {
        let existing = store.items(on: model.day)
        let draft = store.draft?.day == model.day ? store.draft : nil
        model = EditorModel(day: model.day, items: existing, draft: draft)
        if let focusItem, let item = model.items.first(where: { $0.id == focusItem }) {
            model.edit(item)
            syncTimePicker()
        }
        store.markEditorOpened()
    }

    // MARK: Header

    @ViewBuilder
    private var header: some View {
        if let selection = model.selection {
            HStack {
                Button("취소") { model.selection = nil }
                    .font(.brand(16))
                    .foregroundStyle(Palette.primary)
                    .frame(minWidth: 44, minHeight: 44)
                Spacer()
                Text("\(selection.count)개 선택")
                    .font(.brand(16, .medium))
                    .foregroundStyle(Palette.primary)
                Spacer()
                CircleIconButton(accessibilityLabel: "선택한 항목 삭제", action: deleteSelected) {
                    Image(systemName: "trash").resizable().scaledToFit().padding(2)
                }
                .disabled(selection.isEmpty)
                .opacity(selection.isEmpty ? 0.4 : 1)
            }
            .padding(.horizontal, 16)
            .frame(height: 62)
        } else {
            ZStack {
                Text(model.day.spacedLabel)
                    .font(.brand(15))
                    .foregroundStyle(Palette.primary)
                HStack(spacing: 6) {
                    CircleIconButton(accessibilityLabel: "홈으로, 초안 보관", action: close) {
                        Image("IconBack").renderingMode(.template).resizable().scaledToFit()
                    }
                    Spacer()
                    if !model.items.isEmpty {
                        CircleIconButton(accessibilityLabel: "항목 선택", action: { model.beginSelection(); keyboardWanted = false }) {
                            Image(systemName: "ellipsis").resizable().scaledToFit().padding(.horizontal, 1)
                        }
                    }
                    CircleIconButton(accessibilityLabel: "기록 저장", action: finish) {
                        Image("IconCheck").renderingMode(.template).resizable().scaledToFit()
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 62)
        }
    }

    // MARK: Canvas

    /// A List so rows get the native swipe-to-delete (Figma: "입력 줄을 밀면 삭제 버튼").
    private var canvas: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                    Group {
                        if item.id == model.editingID && model.selection == nil {
                            composer(position: index)
                        } else if let selection = model.selection {
                            selectableRow(item, selected: selection.contains(item.id))
                        } else {
                            itemText(item, position: index)
                                .onTapGesture { model.edit(item); syncTimePicker(); keyboardWanted = true }
                                .onLongPressGesture(minimumDuration: 0.45) {
                                    Haptics.selection()
                                    model.beginSelection(with: item.id)
                                    keyboardWanted = false
                                }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityHint("두 번 탭해 수정해요.")
                                .accessibilityAction(named: "삭제") { delete([item.id]) }
                        }
                    }
                    .id(item.id == model.editingID ? "composer" : item.id.uuidString)
                    .canvasRow()
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if model.selection == nil && item.id != model.editingID {
                            Button(role: .destructive) { delete([item.id]) } label: {
                                Label("삭제", systemImage: "trash")
                            }
                            .tint(Palette.danger)
                        }
                    }
                }
                if model.editingID == nil && model.selection == nil {
                    composer(position: model.items.count)
                        .id("composer")
                        .canvasRow()
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.never)
            .contentMargins(.top, 20, for: .scrollContent)
            .environment(\.defaultMinListRowHeight, 10)
            .onChange(of: model.items.count) { _, _ in
                withAnimation { proxy.scrollTo("composer", anchor: .bottom) }
            }
        }
    }

    private func fontSize(for kind: ItemKind, position: Int) -> CGFloat {
        if kind == .emoji { return position == 0 ? 40 : 30 }
        return position == 0 ? 34 : 23
    }

    private func itemText(_ item: RecordItem, position: Int) -> some View {
        Text(item.value)
            .font(.brand(fontSize(for: item.kind, position: position), position == 0 ? .medium : .regular, relativeTo: .title1))
            .foregroundStyle(Palette.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .accessibilityLabel("\(item.kind.label) \(item.value)")
    }

    private func selectableRow(_ item: RecordItem, selected: Bool) -> some View {
        Button { model.toggleSelection(item.id) } label: {
            HStack(spacing: 14) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selected ? Palette.secondary : Palette.secondary.opacity(0.7))
                Text(item.value)
                    .font(.brand(item.kind == .emoji ? 24 : 21))
                    .foregroundStyle(Palette.primary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 54)
            .background(selected ? Color(hex: 0x3E4B43) : .clear, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -14)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func composer(position: Int) -> some View {
        let size = fontSize(for: model.kind, position: position)
        if model.kind == .time {
            (model.raw.isEmpty ? Text("시간") : Text(verbatim: model.raw))
                .font(.brand(size, .medium))
                .foregroundStyle(model.raw.isEmpty ? Palette.secondary.opacity(0.5) : Palette.primary)
                .padding(.vertical, 4)
                .accessibilityLabel(model.raw.isEmpty ? Text("시간 입력, 아래 선택기에서 골라요") : Text("시간 \(model.raw)"))
        } else {
            ComposerField(
                text: $model.raw,
                placeholder: model.kind.label,
                font: BrandFont.uiFont(size, position == 0 ? .medium : .regular, relativeTo: .title1),
                preferEmoji: model.kind == .emoji,
                isFocused: keyboardWanted && model.selection == nil,
                accessibilityLabel: String(localized: "\(model.kind.label) 입력"),
                onReturn: commitField
            )
            .frame(height: size * 1.5)
        }
    }

    // MARK: Bottom controls

    private var bottomControls: some View {
        VStack(spacing: 10) {
            if undoID != nil {
                UndoToast(message: String(localized: "항목을 삭제했어요.")) {
                    model.undoDelete()
                    undoID = nil
                }
            }
            if model.saveFailed {
                HStack {
                    Text("저장하지 못했어요.\n입력은 이 화면에 남아 있어요.\n저장 공간을 확인해 주세요.")
                        .font(.brand(13))
                        .foregroundStyle(Palette.primary)
                    Spacer()
                    Button("다시 시도", action: finish)
                        .font(.brand(15, .medium))
                        .foregroundStyle(Palette.focus)
                        .frame(minHeight: 44)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassCard(cornerRadius: 16, fill: Color(hex: 0x2F3A33).opacity(0.95))
                .padding(.horizontal, 16)
            } else if let notice = model.notice {
                Text(notice)
                    .font(.brand(13))
                    .foregroundStyle(Palette.focus)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 26)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            if model.kind == .emoji && model.selection == nil {
                HStack(spacing: 4) {
                    ForEach(quickEmoji, id: \.self) { emoji in
                        Button {
                            model.raw = emoji
                            commitField()
                        } label: {
                            Text(emoji).font(.system(size: 24)).frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .accessibilityLabel("\(emoji) 추가")
                    }
                }
                .padding(.horizontal, 20)
            }
            toolbar
            if model.kind == .time && model.selection == nil {
                timePanel
            }
        }
        .padding(.bottom, 8)
    }

    private var toolbar: some View {
        HStack(spacing: 0) {
            ForEach(ItemKind.allCases) { kind in
                let active = model.kind == kind
                Button { switchKind(kind) } label: {
                    Group {
                        if kind == .word {
                            Text("Aa").font(.brand(17, .medium))
                        } else {
                            Image(kind.iconName).renderingMode(.template).resizable().scaledToFit().frame(width: 22, height: 22)
                        }
                    }
                    .foregroundStyle(active ? Palette.onFocus : Palette.primary)
                    .frame(width: 54, height: 44)
                    .background(active ? Palette.focus : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(kind.label)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 56)
        .background(Color.white.opacity(0.04), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
        .padding(.horizontal, 16)
        .opacity(model.selection == nil ? 1 : 0.55)
        .disabled(model.selection != nil)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("입력 종류")
    }

    private var timePanel: some View {
        VStack(spacing: 0) {
            DatePicker("시간", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "en_GB")) // 24-hour wheel, matches HH:mm items
                .frame(height: 170)
                .clipped()
            Button {
                model.raw = Self.timeFormatter.string(from: time)
                commitField()
            } label: {
                (model.editingID == nil ? Text("시간 추가") : Text("시간 수정"))
                    .font(.brand(15, .medium))
                    .foregroundStyle(Palette.onFocus)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Palette.focus, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }
    }

    // MARK: Actions

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private func syncTimePicker() {
        if model.kind == .time, let date = Self.timeFormatter.date(from: model.raw) {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            time = Calendar.current.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: Date()) ?? Date()
        }
    }

    private func switchKind(_ kind: ItemKind) {
        model.setKind(kind)
        guard model.kind == kind else { return }
        keyboardWanted = kind != .time
        if kind == .time { syncTimePicker() }
    }

    private func commitField() {
        let wasEditing = model.editingID != nil
        guard model.commitRaw() else { return }
        if model.kind == .time { keyboardWanted = false }
        UIAccessibility.post(notification: .announcement, argument: wasEditing ? String(localized: "항목을 수정했어요.") : String(localized: "항목을 추가했어요."))
    }

    private func delete(_ ids: Set<UUID>) {
        model.delete(ids: ids)
        showUndo()
    }

    private func deleteSelected() {
        model.deleteSelected()
        keyboardWanted = true
        showUndo()
    }

    private func showUndo() {
        let id = UUID()
        undoID = id
        Task {
            try? await Task.sleep(for: .seconds(8))
            if undoID == id { undoID = nil }
        }
    }

    /// ✓ saves everything, including the value still being typed, then returns to the day card.
    private func finish() {
        guard let items = model.itemsForSaving() else { return }
        let existing = store.items(on: model.day)
        if items == existing {
            store.updateDraft(nil)
            leave(to: existing.isEmpty ? nil : model.day)
            return
        }
        do {
            try store.save(day: model.day, items: items)
            model.saveFailed = false
            store.updateDraft(nil)
            Haptics.selection()
            leave(to: items.isEmpty ? nil : model.day)
        } catch {
            model.saveFailed = true
        }
    }

    /// Back keeps the draft; + on the home screen continues it.
    private func close() {
        // Nothing to keep if the items match what is saved and nothing is being typed.
        if model.raw.isEmpty && model.items == store.items(on: model.day) { store.updateDraft(nil) }
        leave(to: nil)
    }

    private func leave(to day: DayKey?) {
        keyboardWanted = false
        if let day {
            app.select(day, haptic: false)
            app.focusedMonth = day.monthKey
            if app.level != .day { app.setLevel(.records) }
        }
        app.editorDay = nil
        dismiss()
    }
}

private extension View {
    func canvasRow() -> some View {
        listRowInsets(EdgeInsets(top: 4, leading: 26, bottom: 4, trailing: 26))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
