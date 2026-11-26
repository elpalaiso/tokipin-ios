import SwiftUI

/// Pre-launch policy drafts, copied from the homepage (privacy.html, terms.html).
struct PolicyDocument {
    let title: String
    let lead: String
    let sections: [(String, String)]

    static let privacy = PolicyDocument(
        title: "개인정보 처리방침",
        lead: "Tokipin은 회원가입 없이 사용하는 iOS·Android 기록 앱이에요. 기록과 작성 중인 초안은 기기의 앱 저장공간에 보관해요.",
        sections: [
            ("어떤 정보를 저장하나요?", "직접 입력한 단어, 이모지, 장소, 시간과 기록 날짜, 입력 순서를 저장해요. 이 정보와 작성 중인 초안은 오프라인에서 기록을 이어 쓰고, 날짜별로 찾고 수정하는 데 사용해요."),
            ("장소와 캘린더에 접근하나요?", "장소는 직접 입력해요. Tokipin은 기기의 위치나 캘린더에 대한 접근 권한을 요청하지 않아요. 앱의 달력에는 내가 남긴 기록이 표시돼요."),
            ("기록을 어떻게 보관하고 지우나요?", "달력이나 검색에서 기록을 확인하고 항목 하나 또는 하루 전체를 지울 수 있어요. 직접 지우거나 기기에서 앱 데이터를 삭제할 때까지 기록을 보관해요. 앱 데이터를 삭제하면 그 기기의 기록과 초안이 함께 지워져요."),
            ("내보낸 파일과 기기 백업", "설정에서 저장한 기록을 JSON 파일로 내보낼 수 있어요. 내보낸 파일은 앱에서 기록을 지운 뒤에도 남으니, 저장한 위치에서 직접 관리해 주세요. Tokipin은 계정 동기화를 제공하지 않아요. 기기 백업·복원에 기록이 포함되는지는 운영체제와 앱의 백업 설정에 따라 달라져요."),
            ("운영자 및 개인정보 문의", "운영자 정보, 문의처와 시행일은 정식 출시 때 안내할 예정이에요.")
        ]
    )

    static let terms = PolicyDocument(
        title: "이용약관",
        lead: "이 약관은 iOS·Android용 Tokipin 앱에서 개인 기록을 작성하고 열어볼 때 적용되는 이용 기준이에요.",
        sections: [
            ("앱 이용", "회원가입 없이 단어, 이모지, 장소, 시간을 원하는 순서로 남길 수 있어요. 연간, 월간, 기록한 날, 일간 보기에서 다시 열거나 검색하고, 직접 수정·삭제할 수 있어요."),
            ("기록에 대한 권리", "직접 만든 기록에 대한 권리는 작성자에게 있어요. 다른 사람의 글이나 개인정보가 담긴 기록을 외부에 공유할 때에는 그 사람의 권리와 사생활을 존중해 주세요."),
            ("기기를 바꾸거나 앱 데이터를 지울 때", "Tokipin은 계정으로 기록을 동기화하지 않아요. 기기를 바꾸거나 앱 데이터를 지우기 전에 보관하고 싶은 기록은 설정에서 JSON 파일로 내보내 주세요."),
            ("운영자 및 이용 문의", "운영자 정보, 문의처와 시행일은 정식 출시 때 안내할 예정이에요.")
        ]
    )
}

struct PolicyView: View {
    let document: PolicyDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                CircleIconButton(accessibilityLabel: "뒤로", action: { dismiss() }) {
                    Image("IconBack").renderingMode(.template).resizable().scaledToFit()
                }
                Text(document.title)
                    .font(.brand(20, .medium))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 62)
            Rectangle().fill(Palette.line).frame(height: 1).padding(.horizontal, 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("출시 전 초안 · iOS·Android 앱 기준")
                        .font(.brand(13))
                        .foregroundStyle(Palette.focus)
                    Text(document.lead)
                        .font(.brand(17, .medium))
                    ForEach(document.sections, id: \.0) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.0).font(.brand(17, .medium)).accessibilityAddTraits(.isHeader)
                            Text(section.1).font(.brand(15)).foregroundStyle(Palette.secondary).lineSpacing(4)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
        .foregroundStyle(Palette.primary)
        .background(Color(hex: 0x2E3832).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}
