//
//  MenuBarLabel.swift
//  Total Trash
//
//  Created by Steven Motie on 10/30/26.
//

import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var engine: JunkFileEngine

    private var isCleaning: Bool {
        engine.isCleaning || engine.currentVolumeName != nil
    }

    private var symbolName: String {
        // Keep the menu-bar identity consistent while cleaning and when idle.
        return "trash.circle.fill"
    }

    private var statusDescription: String {
        if isCleaning {
            return "TotalTrash is cleaning files"
        }

        return "TotalTrash is ready"
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbolName)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconColor)

            if isCleaning {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.75)
                    .frame(width: 10, height: 10)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(statusDescription)
        .help(statusDescription)
    }

    private var iconColor: Color {
        if isCleaning {
            return .blue
        }

        return .primary
    }
}
