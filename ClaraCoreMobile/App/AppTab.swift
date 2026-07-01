import SwiftUI

enum AppTab: Hashable {
    case importer
    case archive
    case memoria
    case continuity
    case settings

    var title: String {
        switch self {
        case .importer:
            "导入"
        case .archive:
            "原文"
        case .memoria:
            "记忆"
        case .continuity:
            "共同线"
        case .settings:
            "设置"
        }
    }

    @ViewBuilder
    var label: some View {
        switch self {
        case .importer:
            Label(title, systemImage: "square.and.arrow.down")
        case .archive:
            Label(title, systemImage: "archivebox")
        case .memoria:
            Label(title, systemImage: "square.stack")
        case .continuity:
            Label(title, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
        case .settings:
            Label(title, systemImage: "slider.horizontal.3")
        }
    }
}
