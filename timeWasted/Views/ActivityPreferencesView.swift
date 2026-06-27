import SwiftUI
import WidgetKit
import UserNotifications

struct ActivityPreferencesView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var preferences: UserPreferences = SharedDefaults.loadUserPreferences()
    @State private var showingAddCustom = false
    @State private var activityToEdit: Activity? = nil
    @State private var notificationStatus = ""

    private func isSelected(_ activity: Activity) -> Bool {
        preferences.selectedActivityIDs.contains(activity.id)
    }

    private func toggle(_ activity: Activity) {
        if isSelected(activity) {
            preferences.selectedActivityIDs.removeAll { $0 == activity.id }
        } else {
            preferences.selectedActivityIDs.append(activity.id)
        }
    }

    private var selectedActivities: [Activity] {
        let builtIn = ActivityDatabase.all.filter { preferences.selectedActivityIDs.contains($0.id) }
        return builtIn + preferences.customActivities.map { $0.toActivity() }
    }

    private func ruleBinding<Value>(
        for activityID: String,
        _ keyPath: WritableKeyPath<ActivityNotificationRule, Value>
    ) -> Binding<Value> {
        Binding(
            get: { preferences.notificationRule(for: activityID)[keyPath: keyPath] },
            set: { newValue in
                var rule = preferences.notificationRule(for: activityID)
                rule[keyPath: keyPath] = newValue
                preferences.setNotificationRule(rule)
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                headerSection

                notificationSection

                customActivitiesSection

                builtInSection
            }
            .navigationTitle("Personalizar")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: refreshNotificationStatus)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        SharedDefaults.saveUserPreferences(preferences)
                        WidgetCenter.shared.reloadTimelines(ofKind: "TimeWastedWidget")
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingAddCustom) {
                CustomActivityFormView { newActivity in
                    preferences.customActivities.append(newActivity)
                }
            }
            .sheet(item: $activityToEdit) { activity in
                CustomActivityFormView(prefilledFrom: activity) { newActivity in
                    // Remove from selectedIDs if it was toggled on, save as custom instead
                    preferences.selectedActivityIDs.removeAll { $0 == activity.id }
                    preferences.customActivities.append(newActivity)
                }
            }
        }
    }

    private var headerSection: some View {
        Section {
            if preferences.hasAnyPreferences {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Comparações personalizadas ativas")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button(role: .destructive) {
                    preferences.selectedActivityIDs = []
                    preferences.customActivities = []
                    preferences.metricNotificationsEnabled = false
                    preferences.notificationRules = []
                } label: {
                    Label("Resetar para padrão (sem comparações)", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                }
            } else {
                Label("Selecione atividades abaixo para começar", systemImage: "hand.point.down")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var notificationSection: some View {
        Section {
            Toggle("Notificações de metas", isOn: $preferences.metricNotificationsEnabled)
                .onChange(of: preferences.metricNotificationsEnabled) { _, enabled in
                    guard enabled else { return }
                    Task {
                        _ = try? await UNUserNotificationCenter.current().requestAuthorization(
                            options: [.alert, .sound, .badge]
                        )
                    }
                }

            Button {
                sendTestNotification()
            } label: {
                Label("Enviar notificação de teste", systemImage: "bell.badge")
            }

            if !notificationStatus.isEmpty {
                Text(notificationStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if preferences.metricNotificationsEnabled {
                if selectedActivities.isEmpty {
                    Text("Selecione pelo menos uma atividade para configurar metas.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(selectedActivities) { activity in
                        DisclosureGroup {
                            Toggle(
                                "Notificar esta atividade",
                                isOn: ruleBinding(for: activity.id, \.isEnabled)
                            )
                            Stepper(
                                "Diário: **\(preferences.notificationRule(for: activity.id).dailyTarget)×**",
                                value: ruleBinding(for: activity.id, \.dailyTarget),
                                in: 1...999
                            )
                            Stepper(
                                "Semanal: **\(preferences.notificationRule(for: activity.id).weeklyTarget)×**",
                                value: ruleBinding(for: activity.id, \.weeklyTarget),
                                in: 1...999
                            )
                            Stepper(
                                "Mensal: **\(preferences.notificationRule(for: activity.id).monthlyTarget)×**",
                                value: ruleBinding(for: activity.id, \.monthlyTarget),
                                in: 1...999
                            )
                        } label: {
                            HStack(spacing: 10) {
                                Text(activity.emoji)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(activity.name)
                                        .font(.subheadline.weight(.medium))
                                    Text("\(formatTime(activity.durationMinutes * 60)) por unidade")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Metas")
        } footer: {
            Text("Cada alerta é enviado uma única vez por atividade e período. Semana e mês usam os dados acumulados desde que o monitoramento começou.")
        }
    }

    private func refreshNotificationStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationStatus = switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: "Notificações autorizadas neste aparelho."
            case .denied: "Notificações bloqueadas nos Ajustes do iOS."
            case .notDetermined: "A permissão de notificações ainda não foi solicitada."
            @unknown default: "Não foi possível determinar a permissão de notificações."
            }
        }
    }

    private func sendTestNotification() {
        Task {
            do {
                let center = UNUserNotificationCenter.current()
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                guard granted else {
                    notificationStatus = "O iOS não autorizou notificações."
                    return
                }

                let content = UNMutableNotificationContent()
                content.title = "🔔 Notificação funcionando"
                content.body = "O Time Wasted poderá avisar quando você atingir suas metas."
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "metric-notification-test-\(UUID().uuidString)",
                    content: content,
                    trigger: trigger
                )
                try await center.add(request)
                notificationStatus = "Teste agendado. Ele deve aparecer em cerca de 1 segundo."
            } catch {
                notificationStatus = "Falha no teste: \(error.localizedDescription)"
            }
        }
    }

    private var customActivitiesSection: some View {
        Section {
            ForEach(preferences.customActivities) { activity in
                HStack(spacing: 12) {
                    Text(activity.emoji)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.name)
                            .font(.subheadline).fontWeight(.medium)
                        Text(formatTime(activity.durationMinutes * 60))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(activity.category.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(activity.category.color.opacity(0.15)))
                        .foregroundStyle(activity.category.color)
                }
            }
            .onDelete { indexSet in
                preferences.customActivities.remove(atOffsets: indexSet)
            }

            Button {
                showingAddCustom = true
            } label: {
                Label("Adicionar atividade personalizada", systemImage: "plus.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }
        } header: {
            Text("Minhas atividades")
        } footer: {
            Text("Crie atividades com sua própria duração — ou toque em ✏️ para personalizar uma do banco abaixo.")
        }
    }

    @ViewBuilder
    private var builtInSection: some View {
        ForEach(Array(ActivityCategory.allCases), id: \.self) { category in
            let activities = ActivityDatabase.all.filter { $0.category == category }
            Section(category.rawValue) {
                ForEach(activities) { activity in
                    activityRow(activity)
                }
            }
        }
    }

    private func activityRow(_ activity: Activity) -> some View {
        HStack(spacing: 12) {
            Text(activity.emoji)
                .font(.title3)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Text(formatTime(activity.durationMinutes * 60))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                activityToEdit = activity
            } label: {
                Image(systemName: "pencil.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button {
                toggle(activity)
            } label: {
                let selected = isSelected(activity)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
    }
}
