//
//  WriteView.swift
//  Becoming
//
//  Created by admin56 on 25/02/26.
//


import SwiftUI

// MARK: - WriteView

struct WriteView: View {

    @Binding var isPresented: Bool
    let onConfirm: (String) -> Void

    @State private var text:   String = ""
    @State private var prompt: String = ""
    @FocusState private var focused: Bool

    private let prompts = [
        "What small thing felt like you today?",
        "Where did you show up as who you're becoming?",
        "What quiet choice did you make today?",
        "What felt aligned, even if small?",
        "What did you do that future you will recognize?",
        "What moment today felt like enough?"
    ]

    private var canPlace: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Drag handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .accessibilityHidden(true)

            Spacer().frame(height: 40)

            // Prompt — serif italic, generous size
            Text(prompt)
                .font(.system(size: 18, weight: .light).italic())
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .padding(.horizontal, 28)
                .accessibilityLabel(prompt)

            Spacer().frame(height: 28)

            // Text input
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("write something small…")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(Color.secondary.opacity(0.4))
                        .padding(.horizontal, 28)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
                }

                TextEditor(text: $text)
                    .font(.system(size: 16, weight: .light))
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
                    .padding(.horizontal, 22)
                    .focused($focused)
                    .frame(minHeight: 130, maxHeight: 260)
                    .accessibilityLabel("Your reflection")
                    .accessibilityHint("Write a small moment when you acted like who you’re becoming")
            }

            Spacer()

            // Divider
            Rectangle()
                .fill(Color.secondary.opacity(0.10))
                .frame(height: 0.5)
                .padding(.horizontal, 28)

            // Place button — pill style
            Button {
                guard canPlace else { return }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                onConfirm(text.trimmingCharacters(in: .whitespacesAndNewlines))
                isPresented = false
            } label: {
                Text("Place it")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(canPlace ? Color.primary : Color.secondary.opacity(0.35))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .animation(.easeInOut(duration: 0.18), value: canPlace)
            }
            .disabled(!canPlace)
            .accessibilityLabel("Place it")
            .accessibilityHint("Drops your note into the jar")

            Spacer().frame(height: 12)
        }
        .background(AppBackground().ignoresSafeArea())
        .onAppear {
            prompt  = prompts.randomElement() ?? prompts[0]
            focused = true
            text    = ""
        }
    }
}

// MARK: - Preview

#Preview {
    WriteView(isPresented: .constant(true)) { _ in }
}
