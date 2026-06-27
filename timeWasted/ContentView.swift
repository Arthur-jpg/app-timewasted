import SwiftUI

struct ContentView: View {
    @StateObject private var manager = ScreenTimeManager.shared
    @AppStorage("isOnboarded") private var isOnboarded = false

    var body: some View {
        if isOnboarded {
            DashboardView(manager: manager)
        } else {
            OnboardingView(manager: manager, isOnboarded: $isOnboarded)
        }
    }
}

#Preview {
    ContentView()
}
