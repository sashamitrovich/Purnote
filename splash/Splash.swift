//
//  Splash.swift
//  purenote
//
//  Created by Saša Mitrović on 20.10.20.
//
//  The two first-run screens of the 1.5 design (direction B, screens 01 and
//  02): a ribbon hanging from the top edge, the words set on the page's grid
//  (a 20 pt gutter, a margin column, the text from 56 pt), one primary button.
//  What the buttons do is unchanged from 1.4: the welcome's button flips
//  `shownSplashScreen`; without iCloud the choices are Try Again, Open Settings
//  and Continue without iCloud.
//

import SwiftUI

/// A bookmark hanging from the top edge, with a notch at the bottom.
struct HangingRibbon: Shape {
    var notch: CGFloat = 16

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - notch))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct Splash: View {
    @Binding var shownSplashScreen: Bool
    var iCloudAvailable: Bool
    var tryAgain: () -> Void
    var continueWithoutICloud: () -> Void

    /// Width of the margin column plus the gap, so the text starts at 56 pt.
    private let textIndent: CGFloat = 36

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.pn.page.ignoresSafeArea()

            HangingRibbon()
                .fill(Color.pn.ribbon)
                .frame(width: 16, height: 236)
                .padding(.leading, 28)
                .ignoresSafeArea(edges: .top)
                .accessibilityHidden(true)

            if iCloudAvailable {
                welcome
            } else {
                noICloud
            }
        }
    }

    // MARK: - 01 Welcome

    private var welcome: some View {
        page {
            kicker
            headline("Notes that stay yours, as plain files.")

            VStack(alignment: .leading, spacing: 22) {
                promise(1, "Real files",
                        "Every note is a .md file in iCloud Drive. Open it in Files, on your Mac, anywhere.")
                promise(2, "Formatting, no syntax",
                        "The bar above the keyboard writes the Markdown for you.")
                promise(3, "Nothing to sign up for",
                        "No account, no tracking, no ads.")
            }
            .padding(.top, 8)
        } buttons: {
            Button {
                shownSplashScreen.toggle()
            } label: {
                primaryLabel("Start writing")
            }
            .accessibilityIdentifier("splash.start")

            Text("Saved in \(NotesLocation(kind: .iCloud).path)")
                .font(PurnoteType.Twin.meta())
                .foregroundColor(Color.pn.ink2)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .accessibilityIdentifier("splash.location")
        }
    }

    private func promise(_ number: Int, _ title: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(number)")
                .font(PurnoteType.Twin.body())
                .foregroundColor(Color.pn.ink3)
                .frame(width: textIndent - 8, alignment: .trailing)
                .padding(.trailing, 8)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PurnoteType.Twin.h3())
                    .foregroundColor(Color.pn.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(text)
                    .font(PurnoteType.Twin.ui())
                    .lineSpacing(3)
                    .foregroundColor(Color.pn.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 02 No iCloud

    /// iCloud Drive being unavailable is not the user's fault and often not
    /// something they can fix on the spot, so this offers a way past it as
    /// well as a way to fix it. The app is plain files in a directory, and a
    /// directory does not have to be an iCloud one.
    private var noICloud: some View {
        let icloud = NotesLocation(kind: .iCloud)
        let device = NotesLocation(kind: .device, deviceName: NotesLocation.currentDeviceName)

        return page {
            kicker
            headline("Purnote can't reach iCloud Drive.", long: true)

            VStack(alignment: .leading, spacing: 14) {
                Text("Purnote keeps your notes as files in iCloud Drive, so they reach your Mac and other devices.")
                Text("Turn on iCloud Drive and give Purnote access in Settings, or keep your notes on this \(device.deviceName) only.")
            }
            .font(PurnoteType.Twin.body())
            .lineSpacing(3)
            .foregroundColor(Color.pn.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, textIndent)
            .padding(.top, 4)

            VStack(spacing: 0) {
                destination(icloud, symbol: "icloud")
                destination(device, symbol: "folder")
            }
            .padding(.top, 12)
        } buttons: {
            Button {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            } label: {
                primaryLabel("Open Settings")
            }
            .accessibilityIdentifier("splash.openSettings")

            Button(action: continueWithoutICloud) {
                Text("Continue without iCloud")
                    .font(PurnoteType.Twin.ui(weight: .semibold))
                    .foregroundColor(Color.pn.ink)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.pn.fill, in: Capsule())
            }
            .accessibilityIdentifier("splash.continue")

            Button(action: tryAgain) {
                Text("Try Again")
                    .font(PurnoteType.Twin.ui(weight: .semibold))
                    .foregroundColor(Color.pn.ribbonText)
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .accessibilityIdentifier("splash.tryAgain")
        }
    }

    /// One place the notes could live, as a path with what it means under it.
    private func destination(_ location: NotesLocation, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Image(systemName: symbol)
                .font(PurnoteType.Twin.ui())
                .foregroundColor(Color.pn.ink2)
                .frame(width: textIndent - 8, alignment: .trailing)
                .padding(.trailing, 8)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(location.path)
                    .font(PurnoteType.Twin.ui())
                    .foregroundColor(Color.pn.ink)
                Text(location.detail)
                    .font(PurnoteType.Twin.meta())
                    .foregroundColor(Color.pn.ink2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.pn.rule).frame(height: 0.5)
                .padding(.leading, textIndent)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Shared pieces

    private var kicker: some View {
        Text("PURNOTE")
            .font(PurnoteType.Twin.caps())
            .tracking(PurnoteType.capsTracking)
            .foregroundColor(Color.pn.ink2)
            .padding(.leading, textIndent)
            .accessibilityHidden(true)
    }

    private func headline(_ text: String, long: Bool = false) -> some View {
        Text(text)
            .font(PurnoteType.Twin.masthead(long: long))
            .tracking(PurnoteType.mastheadTracking)
            .foregroundColor(Color.pn.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, textIndent)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("splash.headline")
    }

    private func primaryLabel(_ title: String) -> some View {
        Text(title)
            .font(PurnoteType.Twin.ui(weight: .semibold))
            .foregroundColor(Color.pn.page)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.pn.ribbon, in: Capsule())
    }

    /// The words sit at the bottom of the free space, under the ribbon, and
    /// scroll when the text size makes them taller than the screen. The buttons
    /// stay at the bottom edge.
    private func page<Content: View, Buttons: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder buttons: () -> Buttons
    ) -> some View {
        let body = content()
        return VStack(spacing: 0) {
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Spacer(minLength: 96)
                        body
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                    .frame(minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            VStack(spacing: 10) {
                buttons()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }
}

struct Splash_Previews: PreviewProvider {
    static var previews: some View {
        Splash(shownSplashScreen: .constant(false), iCloudAvailable: true,
               tryAgain: {}, continueWithoutICloud: {})
        Splash(shownSplashScreen: .constant(false), iCloudAvailable: false,
               tryAgain: {}, continueWithoutICloud: {})
    }
}
