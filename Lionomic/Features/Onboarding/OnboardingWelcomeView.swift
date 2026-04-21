import SwiftUI

struct OnboardingWelcomeView: View {

    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.lionomicAccent)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Welcome to Lionomic")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("Your private, local-first investing guide.\nAll your data stays on this device.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                viewModel.advanceFromWelcome()
            } label: {
                Text("Get Started")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                            .fill(Color.lionomicAccent)
                    )
            }
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .navigationBarHidden(true)
    }
}
