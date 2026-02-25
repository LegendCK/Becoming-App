//
//  JarStore.swift
//  Becoming
//
//  Created by admin56 on 25/02/26.
//


//
//  JarStore.swift
//  BecomingTest
//
//  Created by admin56 on 22/02/26.
//


import Foundation
import Combine

// MARK: - JarStore

final class JarStore: ObservableObject {

    @Published var state: AppState

    private let persistenceKey = "becoming_app_state"

    // MARK: Init

    init() {
        if let data = UserDefaults.standard.data(forKey: persistenceKey),
           let decoded = try? JSONDecoder().decode(AppState.self, from: data) {
            self.state = decoded
        } else {
            var fresh = AppState()
            // First launch — create a default jar so the screen is never empty
            fresh.jars.append(Jar(name: "someone who shows up"))
            self.state = fresh
        }
    }

    // MARK: Persistence

    func save() {
        guard let encoded = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(encoded, forKey: persistenceKey)
    }

    // MARK: Computed

    var activeJar: Jar? {
        state.activeJar
    }

    var activeJarBinding: Jar {
        get { state.jars[state.activeJarIndex] }
        set { state.jars[state.activeJarIndex] = newValue }
    }

    // MARK: Paper Actions

    func addPaper(text: String) {
        guard !state.jars.isEmpty else { return }
        let paper = Paper(text: text)
        state.jars[state.activeJarIndex].papers.append(paper)
        save()
    }

    func deletePaper(id: UUID) {
        guard !state.jars.isEmpty else { return }
        state.jars[state.activeJarIndex].papers.removeAll { $0.id == id }
        save()
    }

    // MARK: Jar Actions

    func addJar(name: String) {
        guard state.jars.count < 3 else { return }
        let jar = Jar(name: name)
        state.jars.append(jar)
        state.activeJarIndex = state.jars.count - 1
        save()
    }

    func switchJar(to index: Int) {
        guard state.jars.indices.contains(index) else { return }
        state.activeJarIndex = index
        save()
    }

    func updateJarName(_ name: String, at index: Int) {
        guard state.jars.indices.contains(index) else { return }
        state.jars[index].name = name
        save()
    }

    func deleteJar(at index: Int) {
        guard state.jars.indices.contains(index), state.jars.count > 1 else { return }
        state.jars.remove(at: index)
        state.activeJarIndex = max(0, min(state.activeJarIndex, state.jars.count - 1))
        save()
    }
}
