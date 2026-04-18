import SwiftUI

struct OnboardingWelcomeView: View {

    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tint)

            VStack(spacing: 12) {
                Text("Welcome to Lionomic")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Your private, local-first investing guide.\nAll your data stays on this device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button("Get Started") {
                viewModel.advanceFromWelcome()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 32)
        .navigationBarHidden(true)
    }
}
