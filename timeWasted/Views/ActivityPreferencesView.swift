import SwiftUI
import WidgetKit

struct ActivityPreferencesView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var preferences: UserPreferences = SharedDefaults.loadUserPreferences()
    @State private var showingAddCustom = false
    @State private var activityToEdit: Activity? = nil

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

    var body: some View {
        NavigationStack {
            List {
                headerSection

                customActivitiesSection

                builtInSection
            }
            .navigationTitle("Personalizar")
            .navigationBarTitleDisplayMode(.inline)
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
