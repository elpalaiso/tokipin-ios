import SwiftUI

/// 기록 입력: items stack in the order written; four kind tools stay above the keyboard.
struct EditorView: View {
    @Environment(RecordStore.self) private var store
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var model: EditorModel
    @State private var time = Date()
    @State private var syncingPicker = false
    @State private var keyboardWanted = true
    @State private var undoID: UUID?
    /// Row being lifted by a long press (reorder or, if released in place, the 삭제 menu).
    @State private var drag: RowDrag?
    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var menuID: UUID?
    @State private var finished = false
    private let focusItem: UUID?

    struct RowDrag: Equatable {
        let id: UUID
        /// Row centre when it was lifted; the finger's row centre is this plus the translation.
        let originMidY: CGFloat
        var translation: CGFloat = 0
        /// Distance the row's layout slot has travelled through swaps during this drag.
        var shift: CGFloat = 0
        var moved = false
        var offset: CGFloat { translation - shift }
    }


    init(day: DayKey, focusItem: UUID?, startsWithKeyboard: Bool = true) {
        self.focusItem = focusItem
        _keyboardWanted = State(initialValue: startsWithKeyboard)
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
            // After ✓ the saved record is the truth; a late model change must not resurrect the draft.
            guard !finished else { return }
            let matchesSaved = model.raw.isEmpty && model.items == store.items(on: model.day)
            store.updateDraft(model.changed && !matchesSaved || !model.raw.isEmpty ? draft : nil, for: model.day)
        }
        .onChange(of: time) { _, value in
            // Only an explicit wheel change stages a time; opening the tool adds nothing.
            if model.kind == .time, !syncingPicker { model.raw = TimeRules.canonical(from: value) }
        }
        .animation(.easeOut(duration: 0.18), value: model.selection != nil)
        .animation(.easeOut(duration: 0.18), value: undoID)
    }

    private func setUp() {
        let existing = store.items(on: model.day)
        let draft = store.draft(for: model.day)
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
                            // Tap: edit. Long-press and release in place: 삭제 menu.
                            // Long-press and drag up/down: reorder, across every kind.
                            itemText(item, position: index)
                                .onTapGesture { model.edit(item); syncTimePicker(); keyboardWanted = true }
                                .gesture(liftGesture(item.id))
                                .popover(isPresented: Binding(get: { menuID == item.id }, set: { if !$0 { menuID = nil } }),
                                         attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                                    Button(role: .destructive) {
                                        menuID = nil
                                        delete([item.id])
                                    } label: {
                                        Label("삭제", systemImage: "trash")
                                            .font(.brand(17))
                                            .frame(minWidth: 160, alignment: .leading)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 14)
                                    }
                                    .presentationCompactAdaptation(.popover)
                                }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityHint("두 번 탭해 수정해요.")
                                .accessibilityAction(named: "위로 이동") { model.move(item.id, by: -1) }
                                .accessibilityAction(named: "아래로 이동") { model.move(item.id, by: 1) }
                                .accessibilityAction(named: "삭제") { delete([item.id]) }
                        }
                    }
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rowFrames[item.id] = $0 }
                    .background {
                        if drag?.id == item.id {
                            RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0x3E4B43)).padding(.horizontal, -14)
                                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                        }
                    }
                    .scaleEffect(drag?.id == item.id ? 1.02 : 1)
                    .offset(y: drag?.id == item.id ? drag!.offset : 0)
                    .zIndex(drag?.id == item.id ? 1 : 0)
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
            .scrollDisabled(drag != nil)
            .onChange(of: model.items.count) { _, _ in
                withAnimation { proxy.scrollTo("composer", anchor: .bottom) }
            }
        }
    }

    /// Long press lifts the row; the drag that follows reorders it, one neighbour at a time.
    /// UIKit's recognizer coexists with the List's swipe-to-delete and scrolling.
    private func liftGesture(_ id: UUID) -> LiftGesture {
        LiftGesture(
            onBegan: {
                guard model.selection == nil else { return }
                withAnimation(.easeOut(duration: 0.15)) { drag = RowDrag(id: id, originMidY: rowFrames[id]?.midY ?? 0) }
            },
            onChanged: { follow(id, translation: $0) },
            onEnded: endDrag)
    }

    private func follow(_ id: UUID, translation: CGFloat) {
        guard var current = drag, current.id == id,
              let index = model.items.firstIndex(where: { $0.id == id }),
              let frame = rowFrames[id] else { return }
        current.translation = translation
        if abs(translation) > 10 { current.moved = true }
        let centre = current.originMidY + translation
        if index + 1 < model.items.count, let below = rowFrames[model.items[index + 1].id], centre > below.midY {
            current.shift += below.maxY - frame.maxY
            withAnimation(.easeOut(duration: 0.15)) { model.move(id, by: 1) }
        } else if index > 0, let above = rowFrames[model.items[index - 1].id], centre < above.midY {
            current.shift -= frame.minY - above.minY
            withAnimation(.easeOut(duration: 0.15)) { model.move(id, by: -1) }
        }
        drag = current
    }

    private func endDrag() {
        guard let current = drag else { return }
        if !current.moved { menuID = current.id }
        withAnimation(.easeOut(duration: 0.15)) { drag = nil }
    }

    private func fontSize(for kind: ItemKind, position: Int) -> CGFloat {
        if kind == .emoji { return position == 0 ? 40 : 30 }
        return position == 0 ? 34 : 23
    }

    private func itemText(_ item: RecordItem, position: Int) -> some View {
        Text(item.displayValue)
            .font(.brand(fontSize(for: item.kind, position: position), position == 0 ? .medium : .regular, relativeTo: .title1))
            .foregroundStyle(Palette.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .accessibilityLabel("\(item.kind.label) \(item.displayValue)")
    }

    private func selectableRow(_ item: RecordItem, selected: Bool) -> some View {
        Button { model.toggleSelection(item.id) } label: {
            HStack(spacing: 14) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selected ? Palette.secondary : Palette.secondary.opacity(0.7))
                Text(item.displayValue)
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
            (model.raw.isEmpty ? Text("시간") : Text(verbatim: TimeRules.display(model.raw)))
                .font(.brand(size, .medium))
                .foregroundStyle(model.raw.isEmpty ? Palette.secondary.opacity(0.5) : Palette.primary)
                .padding(.vertical, 4)
                .accessibilityLabel(model.raw.isEmpty ? Text("시간 입력, 아래 선택기에서 골라요") : Text("시간 \(TimeRules.display(model.raw))"))
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

    /// Native wheel in the device's 12/24-hour style. Scrolling it only stages a value;
    /// + confirms one time fragment, ✓ saves the day, 취소 keeps everything as it was.
    private var timePanel: some View {
        VStack(spacing: 4) {
            HStack {
                Button("취소") {
                    model.cancelPending()
                    syncTimePicker()
                }
                .font(.brand(15))
                .foregroundStyle(Palette.secondary)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(model.raw.isEmpty && model.editingID == nil)
                Spacer()
                Button {
                    model.raw = TimeRules.canonical(from: time)
                    commitField()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Palette.onFocus)
                        .frame(width: 44, height: 44)
                        .background(Palette.focus, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.editingID == nil ? Text("시간 추가") : Text("시간 수정"))
            }
            .padding(.horizontal, 20)
            DatePicker("시간", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 170)
                .clipped()
        }
    }

    // MARK: Actions

    private func syncTimePicker() {
        guard model.kind == .time, let (hour, minute) = TimeRules.components(model.raw) else { return }
        syncingPicker = true
        time = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        DispatchQueue.main.async { syncingPicker = false }
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
        finished = true
        guard let items = model.itemsForSaving() else { finished = false; return }
        let existing = store.items(on: model.day)
        if items == existing {
            store.updateDraft(nil, for: model.day)
            leave(to: existing.isEmpty ? nil : model.day)
            return
        }
        do {
            try store.save(day: model.day, items: items)
            model.saveFailed = false
            store.updateDraft(nil, for: model.day)
            // The last item gone: 일간 shows the same day's empty screen.
            leave(to: items.isEmpty && app.level != .day ? nil : model.day)
        } catch {
            finished = false
            model.saveFailed = true
        }
    }

    /// Back keeps the draft; + on the home screen continues it.
    private func close() {
        // Nothing to keep if the items match what is saved and nothing is being typed.
        if model.raw.isEmpty && model.items == store.items(on: model.day) { store.updateDraft(nil, for: model.day) }
        leave(to: nil)
    }

    private func leave(to day: DayKey?) {
        keyboardWanted = false
        if let day {
            app.navigate(to: day, level: app.level == .day ? .day : .records, haptic: false)
            app.focusedMonth = day.monthKey
            app.requestReveal(day)
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

/// Long press (0.4 s) that keeps reporting the finger's vertical travel until it lifts.
struct LiftGesture: UIGestureRecognizerRepresentable {
    let onBegan: () -> Void
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    final class Coordinator { var startY: CGFloat = 0 }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.4
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        let y = recognizer.location(in: nil).y
        switch recognizer.state {
        case .began:
            context.coordinator.startY = y
            onBegan()
        case .changed:
            onChanged(y - context.coordinator.startY)
        case .ended, .cancelled, .failed:
            onEnded()
        default:
            break
        }
    }
}
