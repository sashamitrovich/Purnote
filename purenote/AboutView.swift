//
//  AboutView.swift
//  purenote
//
//  About Purnote (1.5 design, screen 26). It replaces the Help sheet: the app's
//  icon, name and version, where the notes are, what the app does with your
//  data, and the short list of things it can do that Help used to hold.
//  Colours come only from `Color.pn`; type only from PurnoteType.
//

import SwiftUI
import UIKit

struct AboutView: View {
    let location: NotesLocation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                section("Where your notes are") { whereNotesAre }
                section("Privacy") { privacy }
                section("What you can do") { features }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.pn.page)
        .navigationTitle("About Purnote")
        .navigationBarTitleDisplayMode(.inline)
        // the page names itself; the bar keeps only the back button
        .toolbar {
            ToolbarItem(placement: .principal) { Text("").accessibilityHidden(true) }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let icon = Self.appIcon {
                Image(uiImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14.4, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14.4, style: .continuous)
                        .strokeBorder(Color.pn.rule, lineWidth: 0.5))
                    .accessibilityHidden(true)
            }
            Text("Purnote")
                .font(PurnoteType.Twin.masthead())
                .tracking(PurnoteType.mastheadTracking)
                .foregroundColor(Color.pn.ink)
                .accessibilityAddTraits(.isHeader)
            Text(AppVersion.current)
                .font(PurnoteType.Twin.ui())
                .foregroundColor(Color.pn.ink2)
                .accessibilityIdentifier("about.version")
        }
        .padding(.top, 8)
        .padding(.bottom, 28)
    }

    /// The icon the app is installed with, read from the bundle's icon list.
    /// Nil when the bundle has none (the header then shows no icon).
    private static var appIcon: UIImage? {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let name = files.last else { return nil }
        return UIImage(named: name)
    }

    // MARK: - Sections

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(title.uppercased())
                    .font(PurnoteType.Twin.caps())
                    .tracking(PurnoteType.capsTracking)
                    .foregroundColor(Color.pn.ink2)
                    .accessibilityAddTraits(.isHeader)
                Rectangle().fill(Color.pn.rule).frame(height: 0.5)
            }
            content()
        }
        .padding(.bottom, 32)
    }

    private var whereNotesAre: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: location.kind == .iCloud ? "icloud" : "folder")
                    .font(PurnoteType.Twin.ui())
                    .foregroundColor(Color.pn.ink2)
                    .frame(width: 28, alignment: .leading)
                    .accessibilityHidden(true)
                Text(location.path)
                    .font(PurnoteType.Twin.h2())
                    .foregroundColor(Color.pn.ink)
                    .accessibilityIdentifier("about.location")
            }
            Text("Plain .md files you can open, copy or back up with anything.")
                .font(PurnoteType.Twin.ui())
                .foregroundColor(Color.pn.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 36)
        }
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("No account, no tracking, no ads.")
                .foregroundColor(Color.pn.ink)
            Text(location.privacyDestination)
                .foregroundColor(Color.pn.ink2)
        }
        .font(PurnoteType.Twin.body())
        .lineSpacing(5)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.leading, 36)
        .accessibilityElement(children: .combine)
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 14) {
            feature(icon: "folder", text: "Organize notes in folders")
            feature(icon: "number", text: "Filter with #tags and Smart Folders")
            feature(icon: "square.and.arrow.up", text: "Share text or links in from any app")
            feature(icon: "photo", text: "Add images, tables and checklists")
            feature(icon: "hand.draw", text: "Drag a note onto a folder to move it")
        }
    }

    private func feature(icon: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .font(PurnoteType.Twin.meta())
                .foregroundColor(Color.pn.ink3)
                .frame(width: 28, alignment: .leading)
                .accessibilityHidden(true)
            Text(text)
                .font(PurnoteType.Twin.body())
                .foregroundColor(Color.pn.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        AboutView(location: NotesLocation(kind: .iCloud))
    }
}
