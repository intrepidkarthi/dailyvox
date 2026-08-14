import SwiftUI

struct LockScreenView: View {
    @ObservedObject private var lockManager = AppLockManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var authFailed = false

    var body: some View {
        ZStack {
            // Theme-matched background — warm ivory, light, or dark per the active theme
            // (was a hardcoded ivory gradient that clashed with Light/Dark themes).
            WarmBackground()
                .ignoresSafeArea()

            VStack(spacing: DS.Space.xl) {
                // Sage badge — warm + on-brand in every theme (no more dark-mode blue)
                ZStack {
                    Circle()
                        .fill(DS.Palette.sage.opacity(0.12))
                        .frame(width: horizontalSizeClass == .regular ? 132 : 112,
                               height: horizontalSizeClass == .regular ? 132 : 112)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: horizontalSizeClass == .regular ? 56 : 46, weight: .semibold))
                        .foregroundColor(DS.Palette.sage)
                }

                VStack(spacing: DS.Space.xs) {
                    Text("DailyVox is locked")
                        .font(.dsTitle)
                        .foregroundColor(DS.Palette.ink)

                    Text("Only you can unlock and see your entries.")
                        .font(.dsBody)
                        .foregroundColor(DS.Palette.inkSoft)
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
                    Text("Authentication failed. Please try again.")
                        .font(.dsCaption)
                        .foregroundColor(DS.Palette.coral)
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
        lockManager.authenticate { success in
            authFailed = !success
        }
    }
}
