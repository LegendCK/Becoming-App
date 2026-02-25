//
//  AppBackground.swift
//  Becoming
//
//  Created by admin56 on 25/02/26.
//


import SwiftUI

// MARK: - AppBackground
// Spec: Warm neutral #F6F4F1 (light) / deep warm brown (dark)
// No pure white. No pure black.

struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        // Flat warm neutral — spec #F6F4F1
        scheme == .dark
            ? Color(red: 0.098, green: 0.082, blue: 0.067)  // deep warm brown
            : Color(red: 0.965, green: 0.957, blue: 0.945)  // #F6F4F1
    }
}

// MARK: - UIColor paper tones (SpriteKit)
// Spec: soft warm beige #EDE6D8 range

extension UIColor {
    static let paperBase = UIColor(red: 0.929, green: 0.902, blue: 0.847, alpha: 1) // #EDE6D8
    static let paperMid  = UIColor(red: 0.941, green: 0.918, blue: 0.871, alpha: 1)
    static let paperDeep = UIColor(red: 0.918, green: 0.890, blue: 0.835, alpha: 1)

    static func paper(for index: Int) -> UIColor {
        [paperBase, paperMid, paperDeep, paperMid, paperBase][index % 5]
    }
}

// MARK: - Color paper tones (SwiftUI)

extension Color {
    static let paperBase = Color(red: 0.929, green: 0.902, blue: 0.847)
    static let paperMid  = Color(red: 0.941, green: 0.918, blue: 0.871)
    static let paperDeep = Color(red: 0.918, green: 0.890, blue: 0.835)
}

// MARK: - View Helpers

extension View {
    @ViewBuilder
    func sheetCornerRadius(_ radius: CGFloat) -> some View {
        if #available(iOS 16.4, *) {
            self.presentationCornerRadius(radius)
        } else {
            self
        }
    }

    @ViewBuilder
    func sheetBackground() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(.regularMaterial)
        } else {
            self.background(.regularMaterial)
        }
    }
}
