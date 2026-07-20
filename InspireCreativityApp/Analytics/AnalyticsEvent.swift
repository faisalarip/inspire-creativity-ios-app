//
//  AnalyticsEvent.swift
//  InspireCreativityApp
//
//  Typed analytics events. `name`/`parameters` map to GA4 (snake_case, ≤40-char
//  names, ≤100-char string values, no reserved ga_/firebase_/google_ prefix).
//  NEVER carries PII — search logs term length, not the query.
//

import Foundation

/// Journey context snapshotted at purchase time. Non-PII, all bucketed.
struct PurchaseContext: Equatable {
    let hitProLock: Bool
    let animationsViewedBucket: String
    let timeToPurchaseBucket: String
    let signedIn: Bool
}

enum AnalyticsEvent: Equatable {
    case animationView(id: String, category: String, isPro: Bool)
    case codeCopied(id: String)
    case favoriteToggled(id: String, on: Bool)
    case search(termLength: Int)
    case categorySelected(String)
    case paywallViewed(source: String, animationId: String?)
    case purchaseCompleted(productID: String, source: String, context: PurchaseContext)
    case signIn(method: String)
    case auroraPromoTap
    case codeUnlockAttempt(result: String, animationID: String, category: String, isPro: Bool)
    case purchaseInitiated(productID: String, source: String)
    case purchaseCancelled(productID: String, source: String, reason: String)
    case purchaseFailed(productID: String, source: String, reason: String)
    case paywallDismissed(source: String, secondsBucket: String)
    case restoreCompleted(source: String)
    case notificationPermission(granted: Bool)
    case restoreFailed(source: String, reason: String)
    case pricingUnavailable(source: String)
    case meterCopyUsed(animationId: String, remaining: Int)
    case meterExhausted(animationId: String)
    case onboardingCompleted(categoriesCount: Int)
    /// GA4's manual campaign attribution event — source/medium/campaign
    /// exactly as GA4 expects, so acquisition reports pick them up.
    case campaignDetails(source: String, medium: String, campaign: String)

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
        case .codeUnlockAttempt:  return "code_unlock_attempt"
        case .purchaseInitiated:  return "purchase_initiated"
        case .purchaseCancelled:  return "purchase_cancelled"
        case .purchaseFailed:     return "purchase_failed"
        case .paywallDismissed:   return "paywall_dismissed"
        case .restoreCompleted:   return "restore_completed"
        case .notificationPermission: return "notification_permission"
        case .restoreFailed:      return "restore_failed"
        case .pricingUnavailable: return "pricing_unavailable"
        case .meterCopyUsed:      return "meter_copy_used"
        case .meterExhausted:     return "meter_exhausted"
        case .onboardingCompleted: return "onboarding_completed"
        case .campaignDetails:     return "campaign_details"
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
        case let .paywallViewed(source, animationId):
            var params: [String: Any] = ["source": source]
            if let animationId { params["animation_id"] = animationId }
            return params
        case let .purchaseCompleted(productID, source, context):
            return ["product_id": productID, "source": source,
                    "hit_pro_lock": context.hitProLock,
                    "animations_viewed_bucket": context.animationsViewedBucket,
                    "time_to_purchase_bucket": context.timeToPurchaseBucket,
                    "signed_in": context.signedIn]
        case let .signIn(method):
            return ["method": method]
        case .auroraPromoTap:
            return [:]
        case let .codeUnlockAttempt(result, id, category, isPro):
            return ["result": result, "animation_id": id, "category": category, "is_pro": isPro]
        case let .purchaseInitiated(productID, source):
            return ["product_id": productID, "source": source]
        case let .purchaseCancelled(productID, source, reason):
            return ["product_id": productID, "source": source, "reason": reason]
        case let .purchaseFailed(productID, source, reason):
            return ["product_id": productID, "source": source, "reason": reason]
        case let .paywallDismissed(source, secondsBucket):
            return ["source": source, "seconds_bucket": secondsBucket]
        case let .restoreCompleted(source):
            return ["source": source]
        case let .notificationPermission(granted):
            return ["granted": granted]
        case let .restoreFailed(source, reason):
            return ["source": source, "reason": reason]
        case let .pricingUnavailable(source):
            return ["source": source]
        case let .meterCopyUsed(animationId, remaining):
            return ["animation_id": animationId, "remaining": remaining]
        case let .meterExhausted(animationId):
            return ["animation_id": animationId]
        case let .onboardingCompleted(categoriesCount):
            return ["categories_count": categoriesCount]
        case let .campaignDetails(source, medium, campaign):
            return ["source": source, "medium": medium, "campaign": campaign]
        }
    }
}
