import SwiftUI

struct LockScreenView: View {
    @ObservedObject private var lockManager = AppLockManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// The subtree's theme. This screen sits over `WarmBackground`, which is
    /// navy at night — so its text has to follow the same thing the background
    /// does rather than assuming daylight.
    @Environment(\.dvTheme) private var theme
    /// Shown only after a REAL failure, and cleared the moment another attempt
    /// starts. It used to latch: the screen auto-prompts on appear, dismissing
    /// that prompt counted as a failure, and the message then sat there for the
    /// rest of the session under a button that had never actually rejected
    /// anyone.
    @State private var authFailed = false

    var body: some View {
        ZStack {
            // Theme-matched background — warm ivory, light, or dark per the active theme
            // (was a hardcoded ivory gradient that clashed with Light/Dark themes).
            WarmBackground()
                .ignoresSafeArea()

            VStack(spacing: DS.Space.xl) {
                // The badge, the title and the subtitle were pinned to DAY
                // tokens — `sage` and `ink` — on top of a `WarmBackground` that
                // is navy at night. The result was near-black-green text on
                // navy: the words "DailyVox is locked" were invisible on the one
                // screen that has to explain itself, and the only readable thing
                // was the failure message.
                ZStack {
                    Circle()
                        .fill(theme.accentColor.opacity(theme.isNight ? 0.16 : 0.12))
                        .frame(width: horizontalSizeClass == .regular ? 132 : 112,
                               height: horizontalSizeClass == .regular ? 132 : 112)
                    Image(systemName: "lock.shield.fill")
                        .font(.dv(size: horizontalSizeClass == .regular ? 56 : 46, weight: .semibold))
                        .foregroundColor(theme.accentColor)
                }

                VStack(spacing: DS.Space.xs) {
                    Text("DailyVox is locked")
                        .font(.dsTitle)
                        .foregroundColor(theme.textColor)

                    Text("Only you can unlock and see your entries.")
                        .font(.dsBody)
                        .foregroundColor(theme.secondaryTextColor)
                        .multilineTextAlignment(.center)
                }

                Button(action: unlock) {
                    HStack(spacing: 8) {
                        Image(systemName: lockManager.biometricsAvailable ? biometryIcon : "key.fill")
                        Text("Unlock with \(lockManager.biometryTypeName)")
                    }
                }
                .buttonStyle(.dsPrimary)
                .frame(maxWidth: 300)
                .padding(.top, DS.Space.xs)

                if authFailed {
                    Text("That didn't match. Try again.")
                        .font(.dsCaption)
                        .foregroundColor(DS.Palette.coral)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: 500)
            .padding(DS.Space.xl)
        }
        .onAppear {
            // Auto-prompt on appear
            unlock()
        }
    }

    private var biometryIcon: String {
        switch lockManager.biometryTypeName {
        case "Face ID": return "faceid"
        case "Touch ID": return "touchid"
        case "Optic ID": return "opticid"
        default: return "key.fill"
        }
    }

    private func unlock() {
        // Cleared on every attempt, so the message can never outlive the thing
        // it is describing.
        withAnimation(.easeOut(duration: 0.2)) { authFailed = false }
        lockManager.authenticate { outcome in
            withAnimation(.easeOut(duration: 0.2)) {
                // Cancelling is not failing. The screen just waits.
                authFailed = (outcome == .failed)
            }
        }
    }
}
