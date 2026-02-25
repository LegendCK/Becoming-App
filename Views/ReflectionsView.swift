//
//  ReflectionsView.swift
//  Becoming
//
//  Created by admin56 on 25/02/26.
//


import SwiftUI

// MARK: - ReflectionsView

struct ReflectionsView: View {

    @EnvironmentObject var store: JarStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground().ignoresSafeArea()

                if papers.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(papers) { paper in
                            PaperCardView(paper: paper) {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    store.deletePaper(id: paper.id)
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(
                                EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20)
                            )
                        }
                        // Bottom padding row
                        Color.clear
                            .frame(height: 20)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(store.activeJar?.name ?? "your papers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var papers: [Paper] {
        (store.activeJar?.papers ?? []).reversed()
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("No papers yet")
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Your first will mean the most")
                .font(.system(size: 13, weight: .light).italic())
                .foregroundStyle(Color.secondary.opacity(0.4))
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - PaperCardView

struct PaperCardView: View {

    let paper: Paper
    let onDelete: () -> Void

    @State private var expanded          = false
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Date
            HStack(spacing: 4) {
                Text("·").foregroundStyle(.quaternary)
                Text(paper.date.formatted(date: .abbreviated, time: .omitted).lowercased())
                    .tracking(0.4)
                Text("·").foregroundStyle(.quaternary)
            }
            .font(.system(size: 10, weight: .light))
            .foregroundStyle(.tertiary)

            // Reflection text
            Text(paper.text)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(.primary.opacity(0.88))
                .lineSpacing(4)
                .lineLimit(expanded ? nil : 3)
                .animation(.easeInOut(duration: 0.28), value: expanded)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        // ── Background as overlay, not modifier, so swipeActions still work ──
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor { trait in
                    trait.userInterfaceStyle == .dark
                        ? UIColor(red: 0.18, green: 0.15, blue: 0.12, alpha: 1)
                        : UIColor(red: 1.00, green: 0.985, blue: 0.965, alpha: 1)
                }))
                .shadow(color: .black.opacity(0.055), radius: 8, y: 3)
                .shadow(color: .black.opacity(0.03),  radius: 2, y: 1)
        )
        .contentShape(Rectangle())   // full-width tap — Rectangle not RoundedRectangle
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.28)) { expanded.toggle() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            let dateStr = paper.date.formatted(date: .abbreviated, time: .omitted)
            return "\(dateStr). \(paper.text)"
        }())
        .accessibilityHint(expanded ? "Tap to collapse" : "Tap to expand")
        .accessibilityAddTraits(.isButton)
        // swipeActions works on List rows — keep it here, not on background
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                showDeleteConfirm = true
            } label: {
                Label("Release", systemImage: "leaf")
            }
            .tint(Color(red: 0.50, green: 0.40, blue: 0.30))
            .accessibilityLabel("Release paper")
            .accessibilityHint("Permanently removes this reflection")
        }
        .confirmationDialog(
            "Release this paper?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Release", role: .destructive) { onDelete() }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("This reflection will be gone")
        }
    }
}

// MARK: - Preview

#Preview {
    ReflectionsView().environmentObject(JarStore())
}
