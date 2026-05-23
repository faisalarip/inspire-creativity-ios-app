//
//  FloatingTabBar.swift
//  StaggerApp
//
//  Custom floating tab bar — dark blur, accent for active item.
//

import SwiftUI

struct FloatingTabBar: View {
    @Binding var selected: AppTab

    var body: some View {
        HStack {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22, weight: selected == tab ? .semibold : .regular))
                        Text(tab.title)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(selected == tab ? Theme.Palette.accent : Color.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selected == tab ? .isSelected : [])
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 22)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)
        }
        .frame(maxWidth: .infinity)
    }
}
