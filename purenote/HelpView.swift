//
//  HelpView.swift
//  purenote
//

import SwiftUI

/// A lean, basic help screen: what Purnote is, the handful of things it can
/// do, and the running version/build.
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "Version \(version) (Build \(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    intro
                    Divider()
                    featureList
                    Divider()
                    Text(versionText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(20)
            }
            .background(Color.purnotePaper)
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your notes, as plain Markdown files.")
                .font(.system(size: 21, weight: .semibold, design: .serif))
            Text("Every note is a regular .md file in iCloud Drive. Nothing is locked in — open, edit and back up your notes with anything.")
                .foregroundColor(.secondary)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            feature(icon: "folder", text: "Organize notes in folders")
            feature(icon: "number", text: "Filter with #tags and Smart Folders")
            feature(icon: "square.and.arrow.up", text: "Share text or links in from any app")
            feature(icon: "photo", text: "Add images, tables and checklists")
            feature(icon: "hand.draw", text: "Drag a note onto a folder to move it")
        }
    }

    private func feature(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .accent()
                .frame(width: 26)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}

#Preview {
    HelpView()
}
