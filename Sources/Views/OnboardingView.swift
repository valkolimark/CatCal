import SwiftUI

private struct OnboardingStep {
    let icon: String
    let title: String
    let message: String
    /// The cat itself carries the first step; the rest lean on a symbol.
    let showsCat: Bool
}

private let onboardingSteps: [OnboardingStep] = [
    OnboardingStep(
        icon: "cat.fill",
        title: "Meet your companion",
        message: "A cat who grows as you get things done.",
        showsCat: true
    ),
    OnboardingStep(
        icon: "calendar",
        title: "Connect your calendars",
        message: "See Google, Outlook, and iCloud events in one unified view.",
        showsCat: false
    ),
    OnboardingStep(
        icon: "sparkles",
        title: "Level up together",
        message: "Earn XP for every task and watch your cat grow.",
        showsCat: false
    )
]

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var step = 0
    private let calendarSource = EventKitCalendarSource()

    var body: some View {
        ZStack {
            CatCalBackground()

            VStack(spacing: CatCalSpacing.lg) {
                TabView(selection: $step) {
                    ForEach(Array(onboardingSteps.enumerated()), id: \.offset) { index, step in
                        OnboardingStepView(step: step)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))

                Button(action: advance) {
                    Text(step == onboardingSteps.count - 1 ? "Get Started" : "Next")
                        .font(CatCalFont.headline(18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(CatCalColor.brandPrimary, in: Capsule())
                        .shadow(color: CatCalColor.brandPrimary.opacity(0.3), radius: 12, y: 6)
                }
                .padding(.horizontal, CatCalSpacing.xl)
                .padding(.bottom, CatCalSpacing.xl)
            }
        }
    }

    private func advance() {
        if step < onboardingSteps.count - 1 {
            withAnimation {
                step += 1
            }
        } else {
            Task {
                _ = await calendarSource.requestAccess()
                onComplete()
            }
        }
    }
}

private struct OnboardingStepView: View {
    let step: OnboardingStep

    var body: some View {
        VStack(spacing: CatCalSpacing.lg) {
            Spacer()

            if step.showsCat {
                CatBuddyImage(height: 220)
            } else {
                Image(systemName: step.icon)
                    .font(.system(size: 64))
                    .foregroundStyle(CatCalColor.brandPrimary)
                    .frame(width: 140, height: 140)
                    .catCalGlassCard(cornerRadius: 44)
            }

            VStack(spacing: CatCalSpacing.sm) {
                Text(step.title)
                    .font(CatCalFont.largeTitle(30))
                    .foregroundStyle(CatCalColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text(step.message)
                    .font(CatCalFont.body(17))
                    .foregroundStyle(CatCalColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, CatCalSpacing.lg)
            }

            Spacer()
        }
        .padding(.horizontal, CatCalSpacing.lg)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
