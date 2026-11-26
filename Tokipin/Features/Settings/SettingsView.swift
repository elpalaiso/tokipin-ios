import SwiftUI
import UniformTypeIdentifiers

/// 설정 sheet: touch feedback, JSON export, storage note, policies.
struct SettingsView: View {
    @Environment(RecordStore.self) private var store
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
                            Text("터치 피드백").font(.brand(16, .medium))
                        }
                        .tint(Palette.focus)
                        .frame(minHeight: 56)
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
            if case .success = result { exportMessage = "기록을 내보냈어요." }
        }
    }

    private func linkRow(_ title: String) -> some View {
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
            exportMessage = "내보내지 못했어요. 다시 시도해 주세요."
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
