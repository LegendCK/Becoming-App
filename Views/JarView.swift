//
//  JarView.swift
//  Becoming
//
//  Created by admin56 on 25/02/26.
//


import SwiftUI
import SpriteKit
import Combine

// MARK: - JarView

struct JarView: View {

    let papers: [Paper]
    let onDropComplete: (() -> Void)?

    @StateObject private var sceneHolder = JarSceneHolder()

    init(papers: [Paper], onDropComplete: (() -> Void)? = nil) {
        self.papers = papers
        self.onDropComplete = onDropComplete
    }

    var body: some View {
        SpriteView(
            scene: sceneHolder.scene,
            options: [.allowsTransparency]
        )
        .background(.clear)
        // iOS 16-safe: compare by count+ids rather than onChange two-arg
        .onReceive(Just(papers.map(\.id))) { ids in
            sceneHolder.scene.load(papers: papers)
        }
        .onAppear {
            sceneHolder.scene.load(papers: papers)
        }
    }

    func dropPaper(_ paper: Paper) {
        sceneHolder.scene.dropPaper(paper)
    }
}

// MARK: - JarSceneHolder

final class JarSceneHolder: ObservableObject {
    let scene: JarScene

    init() {
        let s = JarScene()
        s.scaleMode       = .resizeFill
        s.backgroundColor = .clear
        self.scene = s
    }
}

// MARK: - Preview

#Preview {
    JarView(papers: [
        Paper(text: "Took the long way home."),
        Paper(text: "Said no out of self-respect."),
        Paper(text: "Made tea slowly."),
        Paper(text: "Sat with the silence."),
        Paper(text: "Wrote this down.")
    ])
    .frame(width: 260, height: 340)
    .background(Color(.systemBackground))
}
