//
//  OnboardingView.swift
//  Becoming
//
//  Created by admin56 on 25/02/26.
//


import SwiftUI

// MARK: - OnboardingView
// 3 screens. Poetic. Slow. Apple HIG compliant.
// — Progress dots at top
// — Staggered element entry per page
// — Keyboard-aware on page 3
// — Swipe to advance (pages 1 & 2)

struct OnboardingView: View {

    @EnvironmentObject var store: JarStore
    let onComplete: () -> Void

    @State private var page:     Int = 0
    @State private var isAnimating = false

    // Per-element animation states — reset on each page transition
    @State private var el1Opacity: Double = 0  // jar / header
    @State private var el1Offset:  Double = 16
    @State private var el2Opacity: Double = 0  // headline
    @State private var el2Offset:  Double = 16
    @State private var el3Opacity: Double = 0  // body text / input
    @State private var el3Offset:  Double = 12
    @State private var el4Opacity: Double = 0  // button

    @State private var jarName: String = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Progress dots ──
                progressDots
                    .padding(.top, topSafeArea + 20)
                    .padding(.bottom, 0)

                // ── Page content ──
                ZStack {
                    switch page {
                    case 0: pageOne
                    case 1: pageTwo
                    case 2: pageThree
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { staggerIn() }
        // Swipe to advance on pages 1 & 2
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { val in
                    guard !isAnimating, page < 2 else { return }
                    if val.translation.width < -40 { advance() }
                }
        )
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i == page
                          ? Color(.label).opacity(0.55)
                          : Color(.label).opacity(0.14))
                    .frame(width: i == page ? 20 : 7, height: 7)
                    .animation(.easeInOut(duration: 0.35), value: page)
            }
        }
        .padding(.vertical, 24)
    }

    // MARK: - Page 1 — This is a jar.

    private var pageOne: some View {
        VStack(spacing: 0) {
            Spacer()

            // Jar
            SplashJarView(paperCount: 0)
                .frame(width: 190, height: 210)
                .opacity(el1Opacity)
                .offset(y: el1Offset)

            Spacer().frame(height: 44)

            // Headline
            Text("This is a jar.")
                .font(.custom("Georgia", size: 28))
                .foregroundStyle(Color(.label).opacity(0.88))
                .multilineTextAlignment(.center)
                .opacity(el2Opacity)
                .offset(y: el2Offset)

            Spacer().frame(height: 14)

            // Body
            Text("It holds the small moments\nwhen you acted like\nwho you're becoming.")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(Color(.label).opacity(0.44))
                .multilineTextAlignment(.center)
                .lineSpacing(7)
                .opacity(el3Opacity)
                .offset(y: el3Offset)

            Spacer()

            // Button
            primaryButton(label: "Continue") { advance() }
                .opacity(el4Opacity)
                .padding(.horizontal, 32)
                .padding(.bottom, bottomSafeArea + 16)
        }
    }

    // MARK: - Page 2 — Every choice leaves a trace.

    private var pageTwo: some View {
        VStack(spacing: 0) {
            Spacer()

            // Jar with papers
            SplashJarView(paperCount: 3)
                .frame(width: 190, height: 210)
                .opacity(el1Opacity)
                .offset(y: el1Offset)

            Spacer().frame(height: 44)

            // Headline
            Text("Every choice\nleaves a trace.")
                .font(.custom("Georgia", size: 28))
                .foregroundStyle(Color(.label).opacity(0.88))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .opacity(el2Opacity)
                .offset(y: el2Offset)

            Spacer().frame(height: 14)

            // Body
            Text("When you act like the person\nyou're becoming - write it down.\nPlace it inside.")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(Color(.label).opacity(0.44))
                .multilineTextAlignment(.center)
                .lineSpacing(7)
                .opacity(el3Opacity)
                .offset(y: el3Offset)

            Spacer()

            // Button
            primaryButton(label: "I understand") { advance() }
                .opacity(el4Opacity)
                .padding(.horizontal, 32)
                .padding(.bottom, bottomSafeArea + 16)
        }
    }

    // MARK: - Page 3 — Name your jar.

    private var pageThree: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 32)

                // BECOMING label
                Text("BECOMING")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(4.5)
                    .foregroundStyle(Color(.label).opacity(0.35))
                    .opacity(el1Opacity)

                Spacer().frame(height: 20)

                // Headline
                Text("Who are you\nbecoming?")
                    .font(.custom("Georgia", size: 32))
                    .foregroundStyle(Color(.label).opacity(0.90))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(el2Opacity)
                    .offset(y: el2Offset)

                Spacer().frame(height: 56)

                // Input block
                VStack(alignment: .leading, spacing: 0) {
                    Text("I am becoming…")
                        .font(.system(size: 13, weight: .light).italic())
                        .foregroundStyle(Color(.label).opacity(0.36))
                        .padding(.horizontal, 32)

                    Spacer().frame(height: 12)

                    TextField("someone who…", text: $jarName)
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(Color(.label).opacity(0.88))
                        .padding(.horizontal, 32)
                        .focused($nameFieldFocused)
                        .submitLabel(.done)
                        .autocorrectionDisabled()
                        .onSubmit { completeOnboarding() }
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                nameFieldFocused = true
                            }
                        }

                    Spacer().frame(height: 14)

                    Rectangle()
                        .fill(Color(.label).opacity(isNameValid ? 0.20 : 0.10))
                        .frame(height: 0.5)
                        .padding(.horizontal, 32)
                        .animation(.easeOut(duration: 0.2), value: isNameValid)
                }
                .opacity(el3Opacity)

                Spacer().frame(height: 52)

                // Begin button
                beginButton
                    .opacity(el4Opacity)
                    .padding(.horizontal, 32)
                    .padding(.bottom, bottomSafeArea + 16)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollDisabled(true)
    }

    // MARK: - Buttons

    private func primaryButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color(.label).opacity(0.82))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    Capsule()
                        .fill(Color(red: 0.926, green: 0.912, blue: 0.895))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color(.label).opacity(0.06), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var beginButton: some View {
        Button(action: completeOnboarding) {
            Text("Begin")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(
                    isNameValid
                    ? Color(.label).opacity(0.85)
                    : Color(.label).opacity(0.22)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    Capsule()
                        .fill(
                            Color(red: 0.926, green: 0.912, blue: 0.895)
                                .opacity(isNameValid ? 1.0 : 0.45)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    Color(.label).opacity(isNameValid ? 0.06 : 0.03),
                                    lineWidth: 0.5
                                )
                        )
                )
                .animation(.easeOut(duration: 0.22), value: isNameValid)
        }
        .disabled(!isNameValid)
        .buttonStyle(.plain)
    }

    // MARK: - Navigation

    private var isNameValid: Bool {
        jarName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    private func advance() {
        guard !isAnimating else { return }
        staggerOut {
            page += 1
            staggerIn()
        }
    }

    private func completeOnboarding() {
        guard isNameValid else { return }
        let name = jarName.trimmingCharacters(in: .whitespacesAndNewlines)
        if store.state.jars.isEmpty {
            store.addJar(name: name)
        } else {
            store.updateJarName(name, at: 0)
            store.switchJar(to: 0)
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        staggerOut { onComplete() }
    }

    // MARK: - Stagger Animations
    // Each element flies in with a 60ms offset — feels alive, not robotic

    private func staggerIn() {
        resetElements()
        isAnimating = true

        let dur = 0.50
        let ease = Animation.easeOut(duration: dur)

        withAnimation(ease.delay(0.05)) {
            el1Opacity = 1; el1Offset = 0
        }
        withAnimation(ease.delay(0.14)) {
            el2Opacity = 1; el2Offset = 0
        }
        withAnimation(ease.delay(0.22)) {
            el3Opacity = 1; el3Offset = 0
        }
        withAnimation(ease.delay(0.28)) {
            el4Opacity = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            isAnimating = false
        }
    }

    private func staggerOut(then action: @escaping () -> Void) {
        isAnimating = true
        withAnimation(.easeIn(duration: 0.28)) {
            el1Opacity = 0; el2Opacity = 0
            el3Opacity = 0; el4Opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            action()
        }
    }

    private func resetElements() {
        el1Opacity = 0; el1Offset = 16
        el2Opacity = 0; el2Offset = 16
        el3Opacity = 0; el3Offset = 12
        el4Opacity = 0
    }

    // MARK: - Safe Area

    private var topSafeArea: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 44
    }

    private var bottomSafeArea: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 34
    }
}
