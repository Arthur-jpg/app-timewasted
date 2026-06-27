import SwiftUI
import FamilyControls

struct OnboardingView: View {
    @ObservedObject var manager: ScreenTimeManager
    @Binding var isOnboarded: Bool

    @State private var step: Step = .welcome
    @State private var showingPicker = false

    enum Step { case welcome, pickApps }

    var body: some View {
        switch step {
        case .welcome:
            welcomeView
        case .pickApps:
            pickAppsView
        }
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Text("⏱️")
                    .font(.system(size: 80))

                Text("Time Wasted")
                    .font(.system(size: 36, weight: .bold, design: .rounded))

                Text("Veja quanto tempo você passa nas redes sociais — e o que poderia estar fazendo no lugar.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Spacer()

            VStack(spacing: 16) {
                featureRow(icon: "chart.bar.fill", color: .blue, title: "Tempo Real", description: "Integrado com o Screen Time do iOS")
                featureRow(icon: "figure.run", color: .green, title: "Alternativas", description: "Traduz tempo perdido em atividades reais")
                featureRow(icon: "rectangle.stack.fill", color: .purple, title: "Widget", description: "Lembrete na tela inicial do seu iPhone")
            }
            .padding(.horizontal, 20)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task {
                        await manager.requestAuthorization()
                        withAnimation {
                            step = .pickApps
                        }
                    }
                } label: {
                    Label("Autorizar Screen Time", systemImage: "clock.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    withAnimation {
                        manager.enableSampleData()
                        isOnboarded = true
                    }
                } label: {
                    Text("Ver com dados de exemplo")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Pick Apps

    private var pickAppsView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Quais apps você quer monitorar?")
                    .font(.title2).fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Selecione as redes sociais e apps que mais consomem seu tempo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 16)

            FamilyActivityPicker(selection: $manager.activitySelection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 12) {
                let hasSelection = !manager.activitySelection.applicationTokens.isEmpty
                    || !manager.activitySelection.categoryTokens.isEmpty

                Button {
                    manager.saveSelection()
                    withAnimation { isOnboarded = true }
                } label: {
                    Text(hasSelection ? "Começar" : "Selecione pelo menos 1 app")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(hasSelection ? Color.accentColor : Color.secondary.opacity(0.3))
                        .foregroundStyle(hasSelection ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!hasSelection)

                Button {
                    withAnimation { isOnboarded = true }
                } label: {
                    Text("Pular por enquanto")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .animation(.easeInOut, value: manager.activitySelection.applicationTokens.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Helpers

    private func featureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}
