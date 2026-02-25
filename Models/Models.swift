//
//  Paper.swift
//  Becoming
//
//  Created by admin56 on 25/02/26.
//


import Foundation

// MARK: - Paper

struct Paper: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let date: Date
    let rotation: Double    // degrees, -12 to 12
    let xOffset: Double     // points, -20 to 20

    init(text: String) {
        self.id = UUID()
        self.text = text
        self.date = Date()
        self.rotation = Double.random(in: -12...12)
        self.xOffset = Double.random(in: -20...20)
    }
}

// MARK: - Jar

struct Jar: Codable, Identifiable {
    let id: UUID
    var name: String
    let createdAt: Date
    var papers: [Paper]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.papers = []
    }
}

// MARK: - AppState

struct AppState: Codable {
    var jars: [Jar]
    var activeJarIndex: Int

    init() {
        self.jars = []
        self.activeJarIndex = 0
    }

    var activeJar: Jar? {
        guard !jars.isEmpty, jars.indices.contains(activeJarIndex) else { return nil }
        return jars[activeJarIndex]
    }
}
