import SwiftUI

@main
struct MyAppApp: App {
    @State private var showsSplash = true

    init() {
        BackstageFonts.register()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                if showsSplash {
                    SplashView { showsSplash = false }
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

/// Animated splash that picks up exactly where the static launch screen (LaunchBackground +
/// LaunchLogo, see Info.plist) leaves off: the icon's gradient eases in under the logo, the logo
/// settles, then lifts towards you as the app fades through.
struct SplashView: View {
    let finished: () -> Void
    @State private var settled = false
    @State private var leaving = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color("LaunchBackground")
            // The app icon's gradient: dark at the top, lighter grey at the bottom (brand artwork colours).
            LinearGradient(colors: [Color(hex: 0x29292C), Color(hex: 0x5D5D5D)], startPoint: .top, endPoint: .bottom)
                .opacity(settled ? 1 : 0)

            Image("LaunchLogo")
                .scaleEffect(leaving ? 1.12 : (settled ? 1.0 : 0.96))
                .opacity(leaving ? 0 : 1)
                .shadow(color: .white.opacity(settled ? 0.18 : 0), radius: 24)
                .accessibilityLabel("district stores")
        }
        .ignoresSafeArea()
        .opacity(leaving ? 0 : 1)
        .task {
            if reduceMotion {
                try? await Task.sleep(for: .seconds(0.6))
                withAnimation(.easeOut(duration: 0.25)) { leaving = true }
            } else {
                withAnimation(.easeOut(duration: 0.5)) { settled = true }
                try? await Task.sleep(for: .seconds(1.0))
                withAnimation(.easeIn(duration: 0.35)) { leaving = true }
            }
            try? await Task.sleep(for: .seconds(0.35))
            finished()
        }
    }
}
