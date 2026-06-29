import SwiftUI
import UIKit

struct ImporterFeatureView: View {
    let inboxStore: InboxStore
    let deepSeekImporter: DeepSeekShareImporter

    @State private var input = ""
    @State private var statusMessage: String?
    @State private var isImporting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("导入对话")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(ClaraDesign.ink)
                    Text("粘贴 DeepSeek 分享链接，或临时保存一段手动文本。")
                        .font(.system(size: 15))
                        .foregroundStyle(ClaraDesign.inkMuted)
                }

                ClaraSectionLabel(title: "来源")

                ClaraCard(accent: isDeepSeekURL ? ClaraDesign.memory : nil) {
                    VStack(alignment: .leading, spacing: 14) {
                TextEditor(text: $input)
                    .frame(minHeight: 160)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(ClaraDesign.ink)

                HStack {
                    Button {
                        importInput()
                    } label: {
                        Label("导入", systemImage: "square.and.arrow.down")
                    }
                    .disabled(trimmedInput.isEmpty || isImporting)
                    .buttonStyle(ClaraPrimaryButtonStyle(color: ClaraDesign.memory))

                    Button {
                        pasteFromClipboard()
                    } label: {
                        Label("粘贴", systemImage: "doc.on.clipboard")
                    }
                    .disabled(isImporting)
                    .buttonStyle(ClaraSecondaryButtonStyle())
                }
            }
                }

                ClaraSectionLabel(title: "识别")

                ClaraCard {
                    VStack(spacing: 14) {
                        HStack {
                            Text("DeepSeek 分享链接")
                                .foregroundStyle(ClaraDesign.ink)
                            Spacer()
                            ClaraStatusPill(
                                title: isDeepSeekURL ? "已识别" : "未识别",
                                color: isDeepSeekURL ? ClaraDesign.memory : ClaraDesign.inkMuted,
                                systemImage: isDeepSeekURL ? "checkmark" : nil
                            )
                        }

                        Divider()
                            .background(ClaraDesign.hairline)

                        HStack {
                            Text("兜底方式")
                                .foregroundStyle(ClaraDesign.ink)
                            Spacer()
                            Text("手动文本")
                                .foregroundStyle(ClaraDesign.inkMuted)
                        }
                    }
                }

            if let statusMessage {
                    ClaraCard(accent: statusMessage.hasPrefix("已导入") ? ClaraDesign.memory : ClaraDesign.danger) {
                        Text(statusMessage)
                            .font(.system(size: 15))
                            .foregroundStyle(statusMessage.hasPrefix("已导入") ? ClaraDesign.memory : ClaraDesign.danger)
                    }
                }
            }
            .padding(20)
        }
        .claraScreenBackground()
        .overlay {
            if isImporting {
                ProgressView()
                    .tint(ClaraDesign.memory)
            }
        }
    }

    private var trimmedInput: String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var inputURL: URL? {
        URL(string: trimmedInput)
    }

    private var isDeepSeekURL: Bool {
        guard let inputURL else { return false }
        return DeepSeekShareImporter.canImport(url: inputURL)
    }

    private func pasteFromClipboard() {
        input = UIPasteboard.general.string ?? ""
    }

    private func importInput() {
        let value = trimmedInput
        guard !value.isEmpty else { return }

        isImporting = true
        statusMessage = nil

        Task {
            do {
                let item: InboxItem
                if let url = URL(string: value), DeepSeekShareImporter.canImport(url: url) {
                    let conversation = try await deepSeekImporter.importConversation(from: url)
                    item = try inboxStore.enqueue(conversation.rawCapture())
                } else {
                    item = try inboxStore.enqueue(RawCapture(source: .manual, rawContent: value))
                }

                await MainActor.run {
                    input = ""
                    statusMessage = "已导入收件箱：\(item.id.prefix(8))"
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }
}

#Preview {
    ImporterFeatureView(
        inboxStore: try! InboxStore(database: AppDatabase(path: ":memory:")),
        deepSeekImporter: DeepSeekShareImporter()
    )
}
