//
//  AnalyticsUserProperty.swift
//  InspireCreativityApp
//
//  Typed GA4 user properties. Names ≤24 chars, values ≤36 chars, snake_case,
//  never PII. Mirrors the AnalyticsEvent pattern.
//

import Foundation

enum AnalyticsUserProperty: Equatable {
    case isPro(Bool)
    case signedIn(Bool)
    case platform(String)
    case engagementLevel(String)
    case animationsViewedBucket(String)

    var name: String {
        switch self {
        case .isPro:                  return "is_pro"
        case .signedIn:               return "signed_in"
        case .platform:               return "platform"
        case .engagementLevel:        return "engagement_level"
        case .animationsViewedBucket: return "animations_viewed_bucket"
        }
    }

    var value: String? {
        switch self {
        case let .isPro(on):                 return on ? "true" : "false"
        case let .signedIn(on):              return on ? "true" : "false"
        case let .platform(p):               return p
        case let .engagementLevel(l):        return l
        case let .animationsViewedBucket(b): return b
        }
    }
}
