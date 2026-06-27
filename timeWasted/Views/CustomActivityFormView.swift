import SwiftUI

struct CustomActivityFormView: View {
    @Environment(\.dismiss) private var dismiss

    var onSave: (CustomUserActivity) -> Void

    @State private var emoji: String
    @State private var name: String
    @State private var hours: Int
    @State private var minutes: Int
    @State private var category: ActivityCategory

    private let minuteOptions = [0, 15, 30, 45]

    init(prefilledFrom activity: Activity? = nil, onSave: @escaping (CustomUserActivity) -> Void) {
        self.onSave = onSave
        if let a = activity {
            _emoji = State(initialValue: a.emoji)
            _name = State(initialValue: a.name)
            let total = Int(a.durationMinutes)
            _hours = State(initialValue: total / 60)
            let rawMin = total % 60
            let rounded = [0, 15, 30, 45].min(by: { abs($0 - rawMin) < abs($1 - rawMin) }) ?? 0
            _minutes = State(initialValue: rounded)
            _category = State(initialValue: a.category)
        } else {
            _emoji = State(initialValue: "⭐")
            _name = State(initialValue: "")
            _hours = State(initialValue: 1)
            _minutes = State(initialValue: 0)
            _category = State(initialValue: .lifestyle)
        }
    }

    private var durationMinutes: Double {
        Double(hours) * 60 + Double(minutes)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && durationMinutes > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identificação") {
                    HStack(spacing: 16) {
                        TextField("", text: $emoji)
                            .font(.system(size: 40))
                            .multilineTextAlignment(.center)
                            .frame(width: 60, height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGroupedBackground))
                            )
                            .onChange(of: emoji) { _, new in
                                let trimmed = new.trimmingCharacters(in: .whitespaces)
                                if !trimmed.isEmpty {
                                    emoji = String(trimmed.prefix(2))
                                }
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Nome da atividade", text: $name)
                                .font(.headline)
                            Text("Ex: Estrada Rio-BH, Ler Harry Potter...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Duração") {
                    HStack {
                        Text("Horas")
                        Spacer()
                        TextField("0", value: $hours, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("h")
                            .foregroundStyle(.secondary)
                    }
                    .onChange(of: hours) { _, newValue in
                        if newValue < 0 { hours = 0 }
                    }
                    Picker("Minutos", selection: $minutes) {
                        ForEach(minuteOptions, id: \.self) { min in
                            Text("\(min) min").tag(min)
                        }
                    }
                    .pickerStyle(.segmented)

                    if durationMinutes > 0 {
                        Text("Total: \(formatTime(durationMinutes * 60))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Categoria") {
                    Picker("Categoria", selection: $category) {
                        ForEach(ActivityCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Atividade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        let activity = CustomUserActivity(
                            id: UUID(),
                            name: name.trimmingCharacters(in: .whitespaces),
                            emoji: emoji,
                            durationMinutes: durationMinutes,
                            category: category
                        )
                        onSave(activity)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }
}
