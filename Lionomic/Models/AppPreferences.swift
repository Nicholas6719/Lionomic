import Foundation
import SwiftData

@Model
final class AppPreferences {
    var morningBriefHour: Int
    var morningBriefMinute: Int
    var quoteRefreshCadenceMinutes: Int
    var biometricsEnabled: Bool
    var contextualHelpEnabled: Bool
    var firstLaunchComplete: Bool
    var priceAlertsEnabled: Bool
    var watchlistAlertsEnabled: Bool
    var holdingRiskAlertsEnabled: Bool
    var recommendationChangeAlertsEnabled: Bool
    var updatedAt: Date

    init(
        morningBriefHour: Int = 7,
        morningBriefMinute: Int = 15,
        quoteRefreshCadenceMinutes: Int = 5,
        biometricsEnabled: Bool = true,
        contextualHelpEnabled: Bool = true,
        firstLaunchComplete: Bool = false,
        priceAlertsEnabled: Bool = false,
        watchlistAlertsEnabled: Bool = false,
        holdingRiskAlertsEnabled: Bool = false,
        recommendationChangeAlertsEnabled: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.morningBriefHour = morningBriefHour
        self.morningBriefMinute = morningBriefMinute
        self.quoteRefreshCadenceMinutes = quoteRefreshCadenceMinutes
        self.biometricsEnabled = biometricsEnabled
        self.contextualHelpEnabled = contextualHelpEnabled
        self.firstLaunchComplete = firstLaunchComplete
        self.priceAlertsEnabled = priceAlertsEnabled
        self.watchlistAlertsEnabled = watchlistAlertsEnabled
        self.holdingRiskAlertsEnabled = holdingRiskAlertsEnabled
        self.recommendationChangeAlertsEnabled = recommendationChangeAlertsEnabled
        self.updatedAt = updatedAt
    }
}
