import SwiftUI
import UniformTypeIdentifiers

/// 설정 sheet: touch feedback, JSON export, storage note, policies.
struct SettingsView: View {
    @Environment(RecordStore.self) private var store
    @Environment(UsageAnalytics.self) private var usage
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Haptics.enabledKey) private var hapticsEnabled = true
    @State private var exportDocument: RecordsDocument?
    @State private var exportMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("설정").font(.brand(24, .semibold))
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .medium))
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("닫기")
                    }
                    .padding(.top, 18)

                    VStack(spacing: 0) {
                        Toggle(isOn: $hapticsEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("진동").font(.brand(16, .medium))
                                Text("날짜를 넘기거나 보기를 바꿀 때 가볍게 진동해요.")
                                    .font(.brand(13))
                                    .foregroundStyle(Palette.secondary)
                            }
                        }
                        .tint(Palette.focus)
                        .frame(minHeight: 66)
                        Rectangle().fill(Palette.line).frame(height: 1)
                        Toggle(isOn: Binding(get: { usage.isEnabled }, set: { usage.setEnabled($0) })) {
                            Text("앱 사용 통계 공유").font(.brand(17, .medium))
                        }
                        .tint(Palette.focus)
                        .disabled(!usage.isAvailable)
                        .padding(.top, 10)
                        Text("앱 실행과 저장 횟수 같은 사용 통계를 참고해 불편한 점을 살피고 기능을 개선해요. 작성한 기록 내용과 검색어는 보내지 않아요.")
                            .font(.brand(13)).foregroundStyle(Palette.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.trailing, 60)
                            .padding(.vertical, 8)
                        Rectangle().fill(Palette.line).frame(height: 1)
                        Button(action: export) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("기록 내보내기").font(.brand(16, .medium))
                                    Text("저장한 기록을 JSON 파일로 내려받아요.")
                                        .font(.brand(13))
                                        .foregroundStyle(Palette.secondary)
                                }
                                Spacer()
                                Image(systemName: "square.and.arrow.down").font(.system(size: 18))
                            }
                            .frame(minHeight: 66)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if let exportMessage {
                            Text(exportMessage)
                                .font(.brand(13))
                                .foregroundStyle(Palette.focus)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 10)
                        }
                        Rectangle().fill(Palette.line).frame(height: 1)
                        // Available with or without records; back returns to this sheet as it was.
                        NavigationLink { FeedbackView() } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "bubble.left").font(.system(size: 16))
                                Text("Tokipin에 한마디").font(.brand(16, .medium))
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 14))
                            }
                            .foregroundStyle(Palette.primary)
                            .frame(minHeight: 56)
                            .contentShape(Rectangle())
                        }
                    }
                    .padding(.horizontal, 18)
                    .glassCard(cornerRadius: 18, fill: Color.white.opacity(0.05))

                    Text("저장 및 개인정보")
                        .font(.brand(15, .medium))
                        .padding(.top, 8)
                    Text("기록과 초안은 이 기기에 저장돼요. 앱 데이터를 지우면 함께 삭제돼요. 위치와 캘린더에 접근하지 않아요.")
                        .font(.brand(14))
                        .foregroundStyle(Palette.secondary)

                    VStack(spacing: 0) {
                        NavigationLink { PolicyView(document: .privacy) } label: { linkRow("개인정보 처리방침") }
                        Rectangle().fill(Palette.line).frame(height: 1)
                        NavigationLink { PolicyView(document: .terms) } label: { linkRow("이용약관") }
                    }
                    .padding(.horizontal, 18)
                    .glassCard(cornerRadius: 18, fill: Color.white.opacity(0.05))
#if DEBUG
                    DebugSampleSection()
#endif
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .foregroundStyle(Palette.primary)
            .toolbar(.hidden, for: .navigationBar)
        }
        .fileExporter(
            isPresented: Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
            document: exportDocument,
            contentType: .json,
            defaultFilename: "tokipin-\(DayKey.today.string)"
        ) { result in
            if case .success = result { exportMessage = String(localized: "기록을 내보냈어요.") }
        }
    }

    private func linkRow(_ title: LocalizedStringKey) -> some View {
        HStack {
            Text(title).font(.brand(16, .medium))
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 14))
        }
        .foregroundStyle(Palette.primary)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private func export() {
        do {
            exportDocument = RecordsDocument(data: try store.exportData())
            exportMessage = nil
        } catch {
            exportMessage = String(localized: "내보내지 못했어요. 다시 시도해 주세요.")
        }
    }
}

struct RecordsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#if DEBUG
/// Debug builds only: load the homepage's sample records (same generator as the web trial) or clear everything.
struct DebugSampleSection: View {
    @Environment(RecordStore.self) private var store
    @State private var message: String?
    @State private var confirmingRangeSamples = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: "개발용 테스트 데이터")
                .font(.brand(15, .medium))
                .padding(.top, 8)
            VStack(spacing: 0) {
                Button { load() } label: { row("예시 기록 넣기", detail: "기존 기록을 지우고 홈페이지 체험과 같은 3년치 기록을 넣어요.") }
                Rectangle().fill(Palette.line).frame(height: 1)
                Button { load(years: 10) } label: {
                    row("대용량 예시 넣기 (10년)", detail: "같은 생성 규칙으로 10년치를 넣어 속도를 확인해요. 기존 기록을 교체해요.")
                }
                Rectangle().fill(Palette.line).frame(height: 1)
                Button { confirmingRangeSamples = true } label: {
                    row("달력 범위 예시 넣기", detail: "2026.11.26 기준의 빈 달과 빈 해를 확인해요. 기존 기록과 초안을 교체해요.")
                }
                Rectangle().fill(Palette.line).frame(height: 1)
                Button(role: .destructive) { clear() } label: { row("모든 기록 지우기", detail: "빈 홈 화면을 확인할 때 써요.") }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .glassCard(cornerRadius: 18, fill: Color.white.opacity(0.05))
            if let message {
                Text(verbatim: message).font(.brand(13)).foregroundStyle(Palette.focus)
            }
        }
        .alert(Text(verbatim: "달력 범위 예시로 교체할까요?"), isPresented: $confirmingRangeSamples) {
            Button(role: .cancel) {} label: { Text(verbatim: "취소") }
            Button(role: .destructive) { loadRangeSamples() } label: { Text(verbatim: "교체") }
        } message: {
            Text(verbatim: "이 기기의 기존 기록과 초안을 교체해요.")
        }
    }

    private func row(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: title).font(.brand(16, .medium))
            Text(verbatim: detail).font(.brand(13)).foregroundStyle(Palette.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func load(years: Int = 3) {
        do {
            let archive = SampleGenerator.archive(years: years)
            try store.replaceAll(with: archive)
            message = "예시 기록 \(archive.days.count)일치를 넣었어요."
        } catch {
            message = "예시 기록을 넣지 못했어요: \(error.localizedDescription)"
        }
    }

    private func clear() {
        do {
            try store.replaceAll(with: RecordArchive(days: []))
            message = "모든 기록을 지웠어요."
        } catch {
            message = "지우지 못했어요: \(error.localizedDescription)"
        }
    }

    private func loadRangeSamples() {
        do {
            guard let url = Bundle.main.url(forResource: "calendar-range-records", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let archive = try JSONDecoder.tokipin.decode(RecordArchive.self, from: Data(contentsOf: url))
            try store.replaceAll(with: archive)
            message = "달력 범위 예시 \(archive.days.count)일치를 넣었어요."
        } catch {
            message = "달력 범위 예시를 넣지 못했어요: \(error.localizedDescription)"
        }
    }
}
#endif
