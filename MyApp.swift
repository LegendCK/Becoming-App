import SwiftUI

@main
struct MyApp: App {
    @StateObject private var store = JarStore()

        // Splash shows every launch — only onboarding is gated
        @State private var phase: AppPhase = {
            let seenOnboarding = UserDefaults.standard.bool(forKey: "seen_onboarding")
            // Always start with splash; it transitions to onboarding or main
            return .splash(goToOnboarding: !seenOnboarding)
        }()

        var body: some Scene {
            WindowGroup {
                ZStack {
                    switch phase {

                    case .splash(let goToOnboarding):
                        SplashView {
                            withAnimation(.easeInOut(duration: 0.50)) {
                                phase = goToOnboarding ? .onboarding : .main
                            }
                        }
                        .transition(.opacity)

                    case .onboarding:
                        OnboardingView {
                            UserDefaults.standard.set(true, forKey: "seen_onboarding")
                            withAnimation(.easeInOut(duration: 0.55)) {
                                phase = .main
                            }
                        }
                        .environmentObject(store)
                        .transition(.opacity)

                    case .main:
                        MainView()
                            .environmentObject(store)
                            .transition(.opacity)
                    }
                }
                .preferredColorScheme(nil)
                .tint(.primary)
            }
        }
    }

    private enum AppPhase {
        case splash(goToOnboarding: Bool)
        case onboarding
        case main
    }
