import SwiftUI

private struct OnboardingStep {
    let icon: String
    let title: String
    let message: String
}

private let onboardingSteps: [OnboardingStep] = [
    OnboardingStep(
        icon: "cat.fill",
        title: "Meet your companion",
        message: "A cat who grows as you get things done."
    ),
    OnboardingStep(
        icon: "calendar",
        title: "Connect your calendars",
        message: "See Google, Outlook, and iCloud events in one unified view."
    ),
    OnboardingStep(
        icon: "sparkles",
        title: "Level up together",
        message: "Earn XP for every task and watch your cat grow."
    )
]

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var step = 0
    private let calendarSource = EventKitCalendarSource()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [CatCalColor.brandPrimary, CatCalColor.brandSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: CatCalSpacing.lg) {
                TabView(selection: $step) {
                    ForEach(Array(onboardingSteps.enumerated()), id: \.offset) { index, step in
                        OnboardingStepView(step: step)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button(action: advance) {
                    Text(step == onboardingSteps.count - 1 ? "Get Started" : "Next")
                        .font(CatCalFont.headline())
                        .foregroundStyle(CatCalColor.brandPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CatCalSpacing.sm)
                        .background(.white, in: Capsule())
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
        VStack(spacing: CatCalSpacing.md) {
            Image(systemName: step.icon)
                .font(.system(size: 64))
                .foregroundStyle(.white)

            Text(step.title)
                .font(CatCalFont.title(26))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(step.message)
                .font(CatCalFont.body())
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, CatCalSpacing.xl)
        }
        .padding(.horizontal, CatCalSpacing.lg)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
