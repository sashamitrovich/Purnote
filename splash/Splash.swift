//
//  Splash.swift
//  purenote
//
//  Created by Saša Mitrović on 20.10.20.
//

import SwiftUI

struct Splash: View {
    @Binding var shownSplashScreen: Bool
    var iCloudAvailable: Bool
    var tryAgain: () -> Void
    var continueWithoutICloud: () -> Void

    @ViewBuilder
    var body: some View {
        VStack(alignment: .center) {

            SplashSummary()

            if iCloudAvailable {
                Button {
                    shownSplashScreen.toggle()
                } label: {
                    Text("Next").primaryAction()
                }
                .padding()
            }
            else {
                noICloud
            }
        }
    }

    /// iCloud Drive being unavailable is not the user's fault and often not
    /// something they can fix on the spot, so this offers a way past it as
    /// well as a way to fix it. The app is plain files in a directory, and a
    /// directory does not have to be an iCloud one.
    private var noICloud: some View {
        VStack(alignment: .center, spacing: 16) {
            HStack(alignment: .center) {
                Image(systemName: "exclamationmark.icloud")
                    .font(.title)
                    .foregroundColor(Color(UIColor.systemOrange))
                    .accessibility(hidden: true)
                Text("Purnote can't reach iCloud Drive")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 260)

            Text("Turn on iCloud Drive and give Purnote access to it, or keep your notes on this iPhone for now.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: 300)

            Button(action: tryAgain) {
                Text("Try Again").primaryAction()
            }

            Button("Open Settings") {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }
            .font(.body.weight(.medium))

            Button("Continue without iCloud", action: continueWithoutICloud)
                .font(.body.weight(.medium))
                .padding(.top, 4)
        }
        .padding()
    }
}

private extension Text {
    func primaryAction() -> some View {
        self.font(.title3)
            .fontWeight(.semibold)
            .foregroundColor(Color.white)
            .multilineTextAlignment(.center)
            .padding(.vertical, 10.0).padding(.horizontal, 40.0)
            .background(Color(UIColor.systemOrange))
            .cornerRadius(10)
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
