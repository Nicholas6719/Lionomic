import Foundation
import Observation

/// Drives the three-stage onboarding flow: welcome → profile → account.
/// Builds drafts; view shows a review sheet before each commit.
/// onFinished() is called after the account is confirmed — flips firstLaunchComplete.
@Observable
@MainActor
final class OnboardingViewModel {

    enum Stage { case welcome, profile, account }

    var stage: Stage = .welcome
    var showingProfileReview = false
    var showingAccountReview = false
    var errorMessage: String?

    var draftProfile = DraftProfile()
    var draftAccount = DraftAccount()

    var onFinished: () -> Void = {}

    func advanceFromWelcome()    { stage = .profile }
    func requestProfileReview()  { showingProfileReview = true }
    func requestAccountReview()  { showingAccountReview = true }
}
