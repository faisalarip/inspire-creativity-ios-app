//
//  AnalyticsEvent.swift
//  InspireCreativityApp
//
//  Typed analytics events. `name`/`parameters` map to GA4 (snake_case, ≤40-char
//  names, ≤100-char string values, no reserved ga_/firebase_/google_ prefix).
//  NEVER carries PII — search logs term length, not the query.
//

import Foundation

enum AnalyticsEvent: Equatable {
    case animationView(id: String, category: String, isPro: Bool)
    case codeCopied(id: String)
    case favoriteToggled(id: String, on: Bool)
    case search(termLength: Int)
    case categorySelected(String)
    case paywallViewed(source: String)
    case purchaseCompleted(productID: String)
    case signIn(method: String)
    case auroraPromoTap

    var name: String {
        switch self {
        case .animationView:     return "animation_view"
        case .codeCopied:        return "code_copied"
        case .favoriteToggled:   return "favorite_toggled"
        case .search:            return "search"
        case .categorySelected:  return "category_selected"
        case .paywallViewed:     return "paywall_viewed"
        case .purchaseCompleted: return "purchase_completed"
        case .signIn:            return "sign_in"
        case .auroraPromoTap:    return "aurora_promo_tap"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case let .animationView(id, category, isPro):
            return ["animation_id": id, "category": category, "is_pro": isPro]
        case let .codeCopied(id):
            return ["animation_id": id]
        case let .favoriteToggled(id, on):
            return ["animation_id": id, "favorited": on]
        case let .search(termLength):
            return ["term_length": termLength]
        case let .categorySelected(category):
            return ["category": category]
        case let .paywallViewed(source):
            return ["source": source]
        case let .purchaseCompleted(productID):
            return ["product_id": productID]
        case let .signIn(method):
            return ["method": method]
        case .auroraPromoTap:
            return [:]
        }
    }
}
