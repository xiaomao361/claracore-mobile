import SwiftUI
import UIKit

enum ClaraDesign {
    static let paper = Color(hex: 0xF7F5EF)
    static let surface = Color(hex: 0xFFFFFF)
    static let surfaceMuted = Color(hex: 0xEFECE4)
    static let ink = Color(hex: 0x24231F)
    static let inkMuted = Color(hex: 0x6F6A60)
    static let hairline = Color(hex: 0xDDD8CC)
    static let memory = Color(hex: 0x2F7D68)
    static let continuity = Color(hex: 0x3F6E9A)
    static let reflection = Color(hex: 0x8A6D3B)
    static let review = Color(hex: 0xB46A2A)
    static let danger = Color(hex: 0xB94A48)

    static let cardRadius: CGFloat = 8
    static let buttonRadius: CGFloat = 8
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

struct ClaraCard<Content: View>: View {
    var accent: Color?
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 0) {
            if let accent {
                RoundedRectangle(cornerRadius: 3)
                    .fill(accent)
                    .frame(width: 5)
                    .padding(.vertical, 12)
            }

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .background(ClaraDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: ClaraDesign.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ClaraDesign.cardRadius, style: .continuous)
                .stroke(ClaraDesign.hairline, lineWidth: 1)
        )
    }
}

struct ClaraSectionLabel: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(ClaraDesign.inkMuted)
            .textCase(nil)
    }
}

struct ClaraStatusPill: View {
    var title: String
    var color: Color
    var systemImage: String?

    var body: some View {
        Label {
            Text(title)
        } icon: {
            if let systemImage {
                Image(systemName: systemImage)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: ClaraDesign.buttonRadius, style: .continuous))
    }
}

struct ClaraEmptyState: View {
    var title: String
    var message: String
    var systemImage: String
    var accent: Color

    var body: some View {
        ClaraCard(accent: accent) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(accent)

                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ClaraDesign.ink)

                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(ClaraDesign.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

enum ClaraActionStatusTone: Equatable {
    case success
    case info
    case error

    var color: Color {
        switch self {
        case .success:
            return ClaraDesign.memory
        case .info:
            return ClaraDesign.continuity
        case .error:
            return ClaraDesign.danger
        }
    }

    var systemImage: String {
        switch self {
        case .success:
            return "checkmark.circle"
        case .info:
            return "info.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }
}

struct ClaraActionStatus: View {
    var message: String
    var tone: ClaraActionStatusTone = .info

    var body: some View {
        ClaraCard(accent: tone.color) {
            Label {
                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(tone == .error ? tone.color : ClaraDesign.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: tone.systemImage)
                    .foregroundStyle(tone.color)
            }
        }
    }
}

struct ClaraPrimaryButtonStyle: ButtonStyle {
    var color: Color = ClaraDesign.memory

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: ClaraDesign.buttonRadius, style: .continuous))
    }
}

struct ClaraSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(ClaraDesign.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(configuration.isPressed ? ClaraDesign.surfaceMuted.opacity(0.7) : ClaraDesign.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: ClaraDesign.buttonRadius, style: .continuous))
    }
}

struct ClaraCompactButtonStyle: ButtonStyle {
    var color: Color = ClaraDesign.inkMuted

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(configuration.isPressed ? 0.18 : 0.10))
            .clipShape(RoundedRectangle(cornerRadius: ClaraDesign.buttonRadius, style: .continuous))
    }
}

extension View {
    func claraScreenBackground() -> some View {
        background(ClaraDesign.paper.ignoresSafeArea())
    }

    func claraNavigationStyle() -> some View {
        tint(ClaraDesign.memory)
            .foregroundStyle(ClaraDesign.ink)
    }

    func claraKeyboardDismissable() -> some View {
        scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                    }
                }
            }
    }
}
