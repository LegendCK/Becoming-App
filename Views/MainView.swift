//
//  MainView.swift
//  Becoming
//
//  Created by admin56 on 25/02/26.
//


import SwiftUI
import SpriteKit
import Combine

// MARK: - MainView

struct MainView: View {

    @EnvironmentObject var store: JarStore

    @State private var showWrite:       Bool   = false
    @State private var showReflections: Bool   = false
    @State private var isDropping:      Bool   = false
    @State private var pendingPaper:    Paper? = nil
    @State private var jarGlobalFrame:  CGRect = .zero
    @State private var lastActiveIndex: Int    = 0
    @State private var jarOpacity:      Double = 0    // fade-in on appear
    @State private var showNoted:       Bool   = false // "Noted." feedback

    @StateObject private var sceneHolder = JarSceneHolder()

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground().ignoresSafeArea()

                VStack(spacing: 0) {
                    identityHeader
                        .padding(.horizontal, 28)
                        .padding(.top, 12)

                    Spacer().frame(height: 6)

                    jarArea
                        .opacity(jarOpacity)

                    Spacer().frame(height: 48)

                    addButton
                        .padding(.horizontal, 28)
                        .padding(.bottom, 36)
                }

                // "Noted." confirmation
                if showNoted {
                    VStack {
                        Spacer()
                        Text("Noted.")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(Color(.label).opacity(0.38))
                            .transition(.opacity)
                        Spacer().frame(height: 108)
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)  // announced via UIAccessibility.post below
                }

                PaperDropOverlay(isDropping: $isDropping, jarFrame: jarGlobalFrame) {
                    if let paper = pendingPaper {
                        sceneHolder.scene.dropPaper(paper)
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
                        pendingPaper = nil
                        showNotedFeedback()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    JarSwitcherButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showReflections = true
                    } label: {
                        Image(systemName: "book.closed")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(Color(.label).opacity(0.55))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reflections")
                    .accessibilityHint("Opens your saved notes")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showWrite) {
                WriteView(isPresented: $showWrite) { text in
                    handleNewPaper(text: text)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .sheetCornerRadius(28)
                .sheetBackground()
            }
            .sheet(isPresented: $showReflections) {
                ReflectionsView()
            }
            .onReceive(store.$state) { newState in
                lastActiveIndex = newState.activeJarIndex
                // Use newState directly — store.state may still hold the old value at this point
                // because @Published fires in willSet, before the property is updated on the object.
                let idx     = newState.activeJarIndex
                let papers  = newState.jars.indices.contains(idx) ? newState.jars[idx].papers : []
                sceneHolder.scene.load(papers: papers)
            }
            .onAppear {
                // Subtle 0.4s fade-in on open — stillness > animation
                withAnimation(.easeOut(duration: 0.4)) {
                    jarOpacity = 1
                }
            }
        }
    }

    // MARK: - Identity Header

    private var identityHeader: some View {
        VStack(spacing: 2) {
            Text("BECOMING")
                .font(.system(size: 12, weight: .medium))
                .tracking(2.2)   // wider whisper spacing
                .foregroundStyle(Color(.label).opacity(0.38))
                .accessibilityHidden(true)   // decorative — jar name below is the real label

            Text(store.activeJar?.name ?? "")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Color(red: 0.110, green: 0.110, blue: 0.118).opacity(0.92))
                .multilineTextAlignment(.center)
                .lineSpacing(4)        // ~1.13 line height at 30pt
                .lineLimit(2)
                .animation(.easeOut(duration: 0.3), value: store.state.activeJarIndex)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Jar Area

    private var jarArea: some View {
        GeometryReader { geo in
            ZStack {
                // 2-3% warm radial glow — creates focus, warmth, premium depth
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.98, green: 0.94, blue: 0.86).opacity(0.055),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: min(geo.size.width, geo.size.height) * 0.58
                )

                SpriteView(
                    scene: configuredScene(size: geo.size),
                    options: [.allowsTransparency]
                )
                .background(.clear)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel({
                    let count = store.activeJar?.papers.count ?? 0
                    let name  = store.activeJar?.name ?? "jar"
                    return count == 0
                        ? "\(name) jar, empty"
                        : "\(name) jar, containing \(count) \(count == 1 ? "paper" : "papers")."
                }())
                .onAppear {
                    DispatchQueue.main.async {
                        jarGlobalFrame = geo.frame(in: .global)
                        reloadScene()
                    }
                }
                .background(
                    GeometryReader { inner in
                        Color.clear.preference(
                            key: JarFrameKey.self,
                            value: inner.frame(in: .global)
                        )
                    }
                )
            }
        }
        .onPreferenceChange(JarFrameKey.self) { jarGlobalFrame = $0 }
        .frame(maxWidth: .infinity)
        .frame(height: 370)
    }

    // MARK: - Add Button
    // Rests on surface — no shadow, 3% darker fill, 1px border at 6%

    private var addButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showWrite = true
        } label: {
            Text("Add a note")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color(.label).opacity(0.82))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .padding(.horizontal, 10)  // slightly narrower — invitation energy
                .background(
                    Capsule()
                        .fill(Color(red: 0.926, green: 0.912, blue: 0.895))  // softer fill
                        .overlay(
                            Capsule()
                                .strokeBorder(Color(.label).opacity(0.05), lineWidth: 0.5)  // hairline
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a note")
        .accessibilityHint("Opens a writing space to record a moment")
    }

    // MARK: - Scene

    private func configuredScene(size: CGSize) -> JarScene {
        let scene = sceneHolder.scene
        if scene.size != size {
            scene.size = size
            // Re-sync paper positions now that the scene has the correct size.
            // onReceive may have called load() before the size was established,
            // leaving chits placed at wrong coordinates.
            DispatchQueue.main.async { reloadScene() }
        }
        return scene
    }

    private func reloadScene() {
        sceneHolder.scene.load(papers: store.activeJar?.papers ?? [])
    }

    private func reloadScene(with papers: [Paper]) {
        sceneHolder.scene.load(papers: papers)
    }

    // MARK: - Note Flow

    private func handleNewPaper(text: String) {
        store.addPaper(text: text)
        guard let paper = store.activeJar?.papers.last else { return }
        // Reserve before onReceive fires so syncPaperNodes skips this ID.
        // This prevents the static floor-node from appearing then vanishing
        // when the animated drop starts 0.25 s later.
        sceneHolder.scene.reserveForDrop(id: paper.id)
        pendingPaper = paper
        // Spec: 0.25s pause after sheet dismiss before drop
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isDropping = true
        }
    }

    private func showNotedFeedback() {
        withAnimation(.easeOut(duration: 0.3)) { showNoted = true }
        UIAccessibility.post(notification: .announcement, argument: "Noted")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.5)) { showNoted = false }
        }
    }

}
// MARK: - Helpers removed (safeAreaTop no longer needed)

// MARK: - JarSwitcherButton
// Floating — no capsule, no background

struct JarSwitcherButton: View {

    @EnvironmentObject var store: JarStore
    @State private var showNewJarSheet    = false
    @State private var showDeleteConfirm  = false
    @State private var newJarName         = ""
    @FocusState private var nameFocused: Bool

    private var firstWord: String {
        store.activeJar?.name
            .split(separator: " ").first
            .map(String.init) ?? "jar"
    }

    var body: some View {
        Menu {
            ForEach(Array(store.state.jars.enumerated()), id: \.element.id) { index, jar in
                Button {
                    withAnimation(.easeOut(duration: 0.3)) { store.switchJar(to: index) }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label(
                        jar.name,
                        systemImage: store.state.activeJarIndex == index
                            ? "checkmark.circle.fill" : "circle"
                    )
                }
            }
            if store.state.jars.count < 3 {
                Divider()
                Button {
                    newJarName = ""
                    showNewJarSheet = true
                } label: {
                    Label("New jar", systemImage: "plus.circle")
                }
            }
            // Delete is only available when more than one jar exists
            if store.state.jars.count > 1 {
                Divider()
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Release this jar", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "archivebox")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Color(.label).opacity(0.50))
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Switch jar")
        .accessibilityHint("Shows your jars and lets you create or remove one")
        .sheet(isPresented: $showNewJarSheet) { newJarSheet }
        .confirmationDialog(
            "Release this jar?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Release", role: .destructive) {
                withAnimation(.easeOut(duration: 0.3)) {
                    store.deleteJar(at: store.state.activeJarIndex)
                }
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("This jar and all its papers will be gone")
        }
    }

    private var newJarSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .accessibilityHidden(true)

            Spacer().frame(height: 40)

            Text("I am becoming…")
                .font(.system(size: 17, weight: .light).italic())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 28)
                .accessibilityHidden(true)

            Spacer().frame(height: 20)

            TextField("someone who…", text: $newJarName)
                .font(.system(size: 22, weight: .light))
                .padding(.horizontal, 28)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit { createJar() }
                .accessibilityLabel("New jar name")
                .accessibilityHint("Describe who you are becoming, then tap begin")

            Rectangle()
                .fill(Color.secondary.opacity(0.12))
                .frame(height: 0.5)
                .padding(.horizontal, 28)
                .padding(.top, 14)

            Spacer()

            Button(action: createJar) {
                Text("Begin this jar")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(
                        newJarName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.secondary.opacity(0.35) : Color(.label).opacity(0.85)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .disabled(newJarName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Begin this jar")
            .accessibilityHint("Creates your new jar")

            Spacer().frame(height: 12)
        }
        .sheetBackground()
        .presentationDetents([.height(280)])
        .sheetCornerRadius(28)
        .onAppear { nameFocused = true }
    }

    private func createJar() {
        let name = newJarName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        withAnimation { store.addJar(name: name) }
        showNewJarSheet = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Preference Key

private struct JarFrameKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Preview

#Preview {
    MainView().environmentObject(JarStore())
}
