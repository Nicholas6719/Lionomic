import Foundation
import SwiftData

/// Glue between `MarketDataService`'s quote-updated hook and the alert
/// persistence + notification surfaces. Pure orchestration — the actual
/// crossing logic lives in `AlertChecker`, and side effects go through
/// `AlertRepository` / `NotificationService` as usual.
///
/// All methods run on MainActor because the repositories and notification
/// service are MainActor-bound.
@MainActor
enum AlertFiringCoordinator {

    /// Invoked after `MarketDataService` successfully upserts a new quote
    /// for `symbol`. Reads the user's prefs, enumerates every Holding /
    /// WatchlistItem carrying a threshold on this symbol, fires any
    /// alerts whose threshold was crossed, and suppresses duplicates
    /// (same symbol + kind + same calendar day).
    static func handleQuoteUpdate(
        symbol: String,
        previousPrice: Decimal?,
        newPrice: Decimal,
        modelContainer: ModelContainer,
        preferencesRepository: PreferencesRepository,
        alertRepository: AlertRepository,
        notificationService: NotificationService
    ) async {
        let prefs = preferencesRepository.currentPreferences
        let priceOn = prefs?.priceAlertsEnabled == true
        let watchOn = prefs?.watchlistAlertsEnabled == true
        guard priceOn || watchOn else { return }

        let context = modelContainer.mainContext

        // Holdings path
        if priceOn {
            let holdings = (try? context.fetch(
                FetchDescriptor<Holding>(
                    predicate: #Predicate<Holding> { $0.symbol == symbol }
                )
            )) ?? []
            for holding in holdings {
                guard holding.alertAbovePrice != nil || holding.alertBelowPrice != nil else {
                    continue
                }
                if let direction = AlertChecker.checkCrossing(
                    previousPrice: previousPrice,
                    newPrice: newPrice,
                    alertAbove: holding.alertAbovePrice,
                    alertBelow: holding.alertBelowPrice
                ) {
                    await fire(
                        kind: .priceAlert,
                        symbol: symbol,
                        direction: direction,
                        newPrice: newPrice,
                        alertRepository: alertRepository,
                        notificationService: notificationService
                    )
                }
            }
        }

        // Watchlist path
        if watchOn {
            let items = (try? context.fetch(
                FetchDescriptor<WatchlistItem>(
                    predicate: #Predicate<WatchlistItem> { $0.symbol == symbol }
                )
            )) ?? []
            for item in items {
                guard item.alertAbovePrice != nil || item.alertBelowPrice != nil else {
                    continue
                }
                if let direction = AlertChecker.checkCrossing(
                    previousPrice: previousPrice,
                    newPrice: newPrice,
                    alertAbove: item.alertAbovePrice,
                    alertBelow: item.alertBelowPrice
                ) {
                    await fire(
                        kind: .watchlistAlert,
                        symbol: symbol,
                        direction: direction,
                        newPrice: newPrice,
                        alertRepository: alertRepository,
                        notificationService: notificationService
                    )
                }
            }
        }
    }

    /// Persist the AlertEvent + schedule the notification, with
    /// same-day same-kind same-symbol dedupe. One fired event per
    /// (symbol, kind, calendar-day) — matching the M9 holding-risk
    /// pattern in spirit but keyed to local-midnight rather than a
    /// rolling 24h window.
    private static func fire(
        kind: AlertKind,
        symbol: String,
        direction: AlertChecker.Direction,
        newPrice: Decimal,
        alertRepository: AlertRepository,
        notificationService: NotificationService
    ) async {
        if let already = try? alertRepository.hasEventToday(kind: kind, symbol: symbol),
           already {
            return
        }

        let priceString = MoneyFormatter.string(from: newPrice)
        let directionWord = direction == .above ? "above" : "below"
        let title: String = {
            switch kind {
            case .priceAlert:     return "Price alert: \(symbol)"
            case .watchlistAlert: return "Watchlist alert: \(symbol)"
            case .holdingRisk, .recommendationChange:
                // Not produced by this coordinator, but keep exhaustive.
                return "\(symbol)"
            }
        }()
        let body = "\(symbol) crossed your \(directionWord) alert at \(priceString)"

        let event = AlertEvent(
            kind: kind,
            symbol: symbol,
            title: title,
            body: body
        )
        do {
            try alertRepository.add(event)
        } catch {
            // Swallow — if persistence fails we still attempt the
            // notification so the user isn't left without feedback.
        }

        // Stable identifier so a rapid re-fire replaces rather than stacks.
        let identifier = "malerts2.\(kind.rawValue).\(symbol).\(direction.rawValue)"
        await notificationService.send(title: title, body: body, identifier: identifier)
    }
}
