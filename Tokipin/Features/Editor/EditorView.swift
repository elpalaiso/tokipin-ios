import SwiftUI

/// 기록 입력: items stack in the order written; four kind tools stay above the keyboard.
struct EditorView: View {
    @Environment(SampleTour.self) private var tour: SampleTour?
    @State private var choseTool = false
    @State private var committedTrialItem = false
    @State private var hasSoftwareKeyboard = false
    @State private var trialField: ComposerField.InputField?
    @Environment(RecordStore.self) private var store
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(UsageAnalytics.self) private var usage

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
    /// Date picker from the centre date.
    @State private var picking = false
    @State private var keyboardBeforePicking = false
    /// Opened with the pencil: the saved day as a whole is being edited.
    @State private var wholeDay: Bool
    private let focusItem: UUID?
    private let allowsKeyboard: Bool

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


    init(day: DayKey, focusItem: UUID?, startsWithKeyboard: Bool = true, allowsKeyboard: Bool = true) {
        self.allowsKeyboard = allowsKeyboard
        self.focusItem = focusItem
        _keyboardWanted = State(initialValue: startsWithKeyboard)
        _wholeDay = State(initialValue: !startsWithKeyboard)
        _model = State(initialValue: EditorModel(day: day, items: [], draft: nil))
    }

    var body: some View {
        ZStack {
            BrandBackground()
            VStack(spacing: 0) {
                if let tour {
                    TourRail(tour: tour, editor: true, replay: {
                        tour.replay()
                        choseTool = model.kind != .word
                        committedTrialItem = false
                    }, next: nextTrialAction)
                }
                header
                if let tour, tour.guided, trialStep == .save {
                    TourHint(title: "체크 표시를 눌러 저장해요.", editor: true) { tour.panel = .leaveGuide }
                }
                canvas
                bottomControls
            }
        }
        .onAppear(perform: setUp)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            if tour != nil { hasSoftwareKeyboard = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            if tour != nil { hasSoftwareKeyboard = false }
        }
        .onChange(of: allowsKeyboard) { _, allowed in if allowed { store.markEditorOpened() } }
        .sheet(isPresented: $picking, onDismiss: { if !keyboardWanted { keyboardWanted = keyboardBeforePicking } }) {
            EntryDatePicker(current: model.day, today: app.today, onCancel: {
                picking = false
            }, onConfirm: { day in
                picking = false
                changeDay(to: day)
            })
            .presentationDetents([.height(460)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(hex: 0x2E3832))
            .presentationCornerRadius(28)
        }
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
        if allowsKeyboard { store.markEditorOpened() }
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
                Button(action: openPicker) {
                    HStack(spacing: 4) {
                        Text(verbatim: DateHeader.editor(model.day))
                            .font(.brand(15))
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Palette.primary)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: model.day.spokenLabel))
                .accessibilityHint(Text("두 번 탭해 날짜를 바꿔요."))
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
                    .trialHighlight(tour?.guided == true && trialStep == .save, radius: 22)
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
                    // The lifted row's slot change and offset must land in the same frame.
                    .transaction { if drag?.id == item.id && drag?.moved == true { $0.animation = nil } }
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

    /// Rows sit 8pt apart (4pt insets above and below).
    private let rowGap: CGFloat = 8

    /// Follows the finger 1:1. Positions come from row heights (stable) rather than live frames
    /// (stale right after a swap), so the lifted row never jumps; it may pass several rows at once.
    private func follow(_ id: UUID, translation: CGFloat) {
        guard var current = drag, current.id == id,
              let height = rowFrames[id]?.height else { return }
        current.translation = translation
        if abs(translation) > 10 { current.moved = true }
        let centre = current.originMidY + translation
        while let index = model.items.firstIndex(where: { $0.id == id }) {
            // Where this row's slot is now: its lifted position plus the slots it has traded.
            let slotMid = current.originMidY + current.shift
            if index + 1 < model.items.count, let below = rowFrames[model.items[index + 1].id]?.height,
               centre > slotMid + height / 2 + rowGap + below / 2 {
                current.shift += below + rowGap
                move(id, by: 1)
            } else if index > 0, let above = rowFrames[model.items[index - 1].id]?.height,
                      centre < slotMid - height / 2 - rowGap - above / 2 {
                current.shift -= above + rowGap
                move(id, by: -1)
            } else {
                break
            }
        }
        drag = current
    }

    /// Neighbours glide into the freed slot; the lifted row itself is placed without animation
    /// (its offset already follows the finger).
    private func move(_ id: UUID, by step: Int) {
        withAnimation(.easeOut(duration: 0.15)) { model.move(id, by: step) }
    }

    private func endDrag() {
        guard let current = drag else { return }
        if !current.moved { menuID = current.id }
        withAnimation(.easeOut(duration: 0.15)) { drag = nil }
    }

    /// Every item has the same weight (Figma 5-2105 / 211-3000). Only the very first word typed
    /// on an empty day is shown large while it is being written.
    private func isFirstEntry(_ position: Int) -> Bool { position == 0 && model.items.isEmpty }

    private func fontSize(for kind: ItemKind, position: Int) -> CGFloat {
        if kind == .emoji { return isFirstEntry(position) ? 40 : 30 }
        return isFirstEntry(position) ? 34 : 23
    }

    private func itemText(_ item: RecordItem, position: Int) -> some View {
        Text(item.displayValue)
            .font(.brand(fontSize(for: item.kind, position: position), .regular, relativeTo: .title1))
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
                font: BrandFont.uiFont(size, isFirstEntry(position) ? .medium : .regular, relativeTo: .title1),
                preferEmoji: model.kind == .emoji,
                isFocused: keyboardWanted && allowsKeyboard && model.selection == nil,
                accessibilityLabel: model.kind.inputLabel,
                onBeginEditing: { keyboardWanted = true },
                onFocusField: tour == nil ? nil : { trialField = $0 },
                onReturn: commitField
            )
            .frame(height: size * 1.5)
            .trialHighlight(tour?.guided == true && trialStep == .input)
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
            if let tour, tour.guided, trialStep != .save {
                TourHint(title: trialHint, editor: true) { tour.panel = .leaveGuide }
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
                    .trialHighlight(tour?.guided == true && trialStep == .tool && kind == .emoji, radius: 12)
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

    private enum TrialStep { case tool, input, save }

    private var trialStep: TrialStep {
        let raw = ItemValidator.normalize(model.kind, model.raw)
        if committedTrialItem { return .save }
        if model.kind != .time, case .value = raw { return .save }
        return model.kind == .word && !choseTool ? .tool : .input
    }

    private var trialHint: LocalizedStringKey {
        if trialStep == .tool { return "이모지 도구를 눌러요." }
        switch model.kind {
        case .emoji:
            return hasSoftwareKeyboard && trialField?.textInputMode?.primaryLanguage == "emoji"
                ? "아래 자판에서 이모지를 눌러요." : "이모지를 입력해 주세요."
        case .word: return "남기고 싶은 단어를 입력해요."
        case .place: return "기억할 장소를 입력해요."
        case .time: return "시간을 고른 뒤 +를 눌러요."
        }
    }

    private func finishTrialComposition() {
        guard let field = trialField, field.isFirstResponder, field.markedTextRange != nil else { return }
        field.unmarkText()
        model.raw = field.text ?? model.raw
    }

    private func nextTrialAction() {
        guard let tour, tour.guided, tour.panel == nil else { return }
        finishTrialComposition()
        if model.selection != nil { model.selection = nil }
        switch trialStep {
        case .tool:
            switchKind(.emoji)
        case .input:
            if model.raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                switch model.kind {
                case .emoji: model.raw = "🌱"
                case .word: model.raw = SampleGenerator.localizedWords["walk"] ?? "산책"
                case .place: model.raw = SampleGenerator.localizedWords["park"] ?? "공원"
                case .time: model.raw = TimeRules.canonical(from: time)
                }
            }
            commitField()
        case .save:
            finish()
        }
    }

    private func switchKind(_ kind: ItemKind) {
        model.setKind(kind)
        guard model.kind == kind else { return }
        if tour != nil { choseTool = true; committedTrialItem = false }
        keyboardWanted = kind != .time
        if kind == .time { syncTimePicker() }
    }

    private func commitField() {
        let wasEditing = model.editingID != nil
        guard model.commitRaw() else { return }
        if tour != nil { committedTrialItem = !model.items.isEmpty }
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
    private func openPicker() {
        keyboardBeforePicking = keyboardWanted
        keyboardWanted = false
        picking = true
    }

    /// The picker's ✓: moves the editor only. New pieces go to the chosen day; a saved day being
    /// edited keeps its changes there as a draft. Nothing is saved until the editor's ✓.
    private func changeDay(to day: DayKey) {
        guard day != model.day, CalendarRange.canWrite(day, today: app.today) else { return }
        if model.editingID != nil, !model.commitRaw() { return }
        let outcome = EntryDateChange.change(
            current: model.draft, saved: store.items(on: model.day), to: day,
            targetSaved: store.items(on: day), targetDraft: store.draft(for: day), wholeDay: wholeDay)
        store.updateDraft(outcome.sourceDraft, for: model.day)
        if let target = outcome.targetDraft { store.updateDraft(target, for: day) }
        model = EditorModel(day: day, items: store.items(on: day), draft: outcome.targetDraft)
        undoID = nil
        wholeDay = false
        keyboardBeforePicking = true
        keyboardWanted = true
    }

    private func finish() {
        if tour != nil { finishTrialComposition() }
        finished = true
        guard let items = model.itemsForSaving() else { finished = false; return }
        let existing = store.items(on: model.day)
        if items == existing {
            store.updateDraft(nil, for: model.day)
            tour?.didSave(items)
            leave(to: existing.isEmpty ? nil : model.day)
            return
        }
        do {
            try store.save(day: model.day, items: items)
            if !store.isSample, usage.isEnabled, EditorModel.isCountedSave(previous: existing, saved: items) { usage.didSaveRecord() }
            model.saveFailed = false
            store.updateDraft(nil, for: model.day)
            tour?.didSave(items)
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
            app.navigate(to: day, level: tour != nil || app.level == .day ? .day : .records, haptic: false)
            app.focusedMonth = day.monthKey
            app.requestReveal(day)
        }
        app.editorDay = nil
        if tour == nil { dismiss() }
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
