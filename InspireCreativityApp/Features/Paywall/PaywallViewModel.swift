//
//  PaywallViewModel.swift
//  InspireCreativityApp
//

import Foundation

@MainActor
final class PaywallViewModel: ObservableObject {

    enum Plan: String, CaseIterable, Identifiable {
        case monthly, yearly, lifetime
        var id: String { rawValue }
        var title: String {
            switch self {
            case .monthly: "Monthly"
            case .yearly: "Yearly"
            case .lifetime: "Lifetime"
            }
        }
        var price: String {
            switch self {
            case .monthly: "$9.99"
            case .yearly: "$59.99"
            case .lifetime: "$149"
            }
        }
        var subtitle: String {
            switch self {
            case .monthly: "per month, billed monthly"
            case .yearly: "$4.99/mo · save 50%"
            case .lifetime: "one-time payment · all future packs"
            }
        }
        var badge: String? {
            self == .yearly ? "Best value" : nil
        }
    }

    @Published var plan: Plan = .yearly

    let features: [Feature] = [
        .init(title: "All 30 animations unlocked", subtitle: "Including pro packs · ~$200 value"),
        .init(title: "New animation every Friday", subtitle: "Hand-picked by working iOS devs"),
        .init(title: "Live parameter tweaking", subtitle: "Change duration, easing in-app — copy the tuned code"),
        .init(title: "Export to .swift file", subtitle: "Open directly in Xcode with a tap"),
        .init(title: "Source files & MIT license", subtitle: "Use in commercial apps royalty-free")
    ]

    struct Feature: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let subtitle: String
    }

    private let purchases: PurchaseRepositoryProtocol

    init(purchases: PurchaseRepositoryProtocol) {
        self.purchases = purchases
    }

    func subscribe() {
        purchases.subscribePro()
    }
}
