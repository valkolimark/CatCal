import SwiftUI
import UIKit

enum AppTab: String, Hashable, CaseIterable, Identifiable {
    case today
    case tasks
    case buddy
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .tasks: "Tasks"
        case .buddy: "Buddy"
        case .profile: "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "calendar"
        case .tasks: "checkmark.circle"
        case .buddy: "pawprint.fill"
        case .profile: "person"
        }
    }
}

/// The floating glass tab bar. Replaces the system bar so the cat can sit
/// *behind* it and the selected tab can carry a solid pill — neither of which
/// the standard bar allows.
struct FloatingTabBar: View {
    @Binding var selection: AppTab

    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    guard tab != selection else { return }
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                        selection = tab
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    item(for: tab)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(6)
        .catCalGlassCard(cornerRadius: 30)
        .padding(.horizontal, CatCalSpacing.lg)
    }

    private func item(for tab: AppTab) -> some View {
        let isSelected = selection == tab

        return VStack(spacing: 3) {
            Image(systemName: tab.systemImage)
                .font(.system(size: 21, weight: isSelected ? .semibold : .regular))
            Text(tab.title)
                .font(CatCalFont.caption(11))
        }
        .foregroundStyle(isSelected ? CatCalColor.brandPrimary : CatCalColor.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(CatCalColor.surface.opacity(0.85))
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                    .matchedGeometryEffect(id: "selectedTab", in: pillNamespace)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    @Previewable @State var selection: AppTab = .today

    return ZStack(alignment: .bottom) {
        CatCalBackground()
        FloatingTabBar(selection: $selection)
    }
}
