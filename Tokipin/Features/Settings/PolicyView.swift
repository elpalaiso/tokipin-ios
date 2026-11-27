import SwiftUI

struct PolicyDocument {
    let title: String
    let blocks: [Block]

    enum Block {
        case status(String)
        case lead(String)
        case heading(String)
        case paragraph(String)
        case link(String, URL)
    }
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
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(document.blocks.indices, id: \.self) { index in
                        switch document.blocks[index] {
                        case let .status(text):
                            Text(text).font(.brand(13)).foregroundStyle(Palette.focus)
                        case let .lead(text):
                            Text(text).font(.brand(17, .medium))
                        case let .heading(text):
                            Text(text).font(.brand(17, .medium))
                                .padding(.top, 12)
                                .accessibilityAddTraits(.isHeader)
                        case let .paragraph(text):
                            Text(text).font(.brand(15)).foregroundStyle(Palette.secondary).lineSpacing(4)
                        case let .link(text, url):
                            Link(destination: url) { Text(text).underline() }
                                .font(.brand(15))
                                .foregroundStyle(Palette.focus)
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
