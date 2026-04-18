import SwiftUI

/// Root container for the onboarding flow.
/// Shown in RootView when firstLaunchComplete == false.
struct OnboardingView: View {

    @Environment(AppEnvironment.self) private var env
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        @Bindable var bindableVM = viewModel

        NavigationStack {
            Group {
                switch viewModel.stage {
                case .welcome: OnboardingWelcomeView(viewModel: viewModel)
                case .profile: OnboardingProfileView(viewModel: viewModel)
                case .account: OnboardingAccountView(viewModel: viewModel)
                }
            }
            .animation(.easeInOut, value: viewModel.stage)
        }
        .onAppear {
            viewModel.onFinished = {
                try? env.preferencesRepository.markFirstLaunchComplete()
            }
        }
        .alert("Something went wrong", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
    }
}
