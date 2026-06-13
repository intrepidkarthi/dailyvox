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

            VStack(spacing: 32) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: horizontalSizeClass == .regular ? 80 : 64))
                    .foregroundColor(.accentColor)

                Text("DailyVox is Locked")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("Only you can unlock and see your entries.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: unlock) {
                    HStack {
                        Image(systemName: lockManager.biometricsAvailable ? biometryIcon : "key.fill")
                        Text("Unlock with \(lockManager.biometryTypeName)")
                    }
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: 320)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                if authFailed {
                    Text("Authentication failed. Please try again.")
                        .font(.caption)
                        .foregroundColor(Color(red: 0.769, green: 0.451, blue: 0.420))
                }
            }
            .frame(maxWidth: 500)
            .padding()
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
