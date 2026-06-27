import SwiftUI
import FamilyControls
import DeviceActivity
import _DeviceActivity_SwiftUI
import OSLog

extension DeviceActivityReport.Context {
    static let dailyActivity = Self(rawValue: "dailyActivity")
    static let weeklyActivity = Self(rawValue: "weeklyActivity")
    static let monthlyActivity = Self(rawValue: "monthlyActivity")
    static let yearlyActivity = Self(rawValue: "yearlyActivity")
}

struct DashboardView: View {
    @ObservedObject var manager: ScreenTimeManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: TimeFrame = .day
    @State private var showingPicker = false
    @State private var showDebug = false
    @State private var reportEndDate = Date.now

    private var hasSelection: Bool {
        !manager.activitySelection.applicationTokens.isEmpty
            || !manager.activitySelection.categoryTokens.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    if !hasSelection {
                        noSelectionBanner
                    }

                    tabSelector
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    TabView(selection: $selectedTab) {
                        ForEach(TimeFrame.allCases) { frame in
                            Group {
                                if hasSelection {
                                    if frame == selectedTab {
                                        activityReport(for: frame)
                                    } else {
                                        Color.clear
                                    }
                                } else {
                                    TimeFrameView(timeframe: frame, summary: manager.summary)
                                }
                            }
                                .tag(frame)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: selectedTab)
                }

            }
            .navigationTitle("Time Wasted")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingPicker = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showDebug = true
                    } label: {
                        Image(systemName: "ant.circle")
                    }
                }
            }
            .sheet(isPresented: $showingPicker) {
                appPickerSheet
            }
            .sheet(isPresented: $showDebug) {
                debugSheet
            }
            .onAppear {
                manager.refreshSummary()
                reportEndDate = .now
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    reportEndDate = .now
                }
            }
            .task(id: hasSelection) {
                guard hasSelection else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    guard !Task.isCancelled else { return }
                    reportEndDate = .now
                }
            }
        }
    }

    private var noSelectionBanner: some View {
        Button {
            showingPicker = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "hand.tap.fill")
                    .font(.title3)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Selecione os apps para monitorar")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("Toque aqui para começar a rastrear seu tempo")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.accentColor)
        }
        .buttonStyle(.plain)
    }

    private func activityReport(for timeframe: TimeFrame) -> some View {
        DeviceActivityReport(
            timeframe.reportContext,
            filter: DeviceActivityFilter(
                segment: .daily(during: timeframe.reportInterval(endingAt: reportEndDate)),
                devices: .init([.iPhone]),
                applications: manager.activitySelection.applicationTokens,
                categories: manager.activitySelection.categoryTokens,
                webDomains: manager.activitySelection.webDomainTokens
            )
        )
        .id("\(timeframe.rawValue)-\(Int(reportEndDate.timeIntervalSince1970 / 60))")
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(TimeFrame.allCases) { frame in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = frame
                        reportEndDate = .now
                    }
                } label: {
                    Text(frame.rawValue)
                        .font(.subheadline)
                        .fontWeight(selectedTab == frame ? .semibold : .regular)
                        .foregroundStyle(selectedTab == frame ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedTab == frame ? Color(.systemBackground) : .clear)
                                .shadow(color: .black.opacity(selectedTab == frame ? 0.08 : 0), radius: 4, y: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGroupedBackground))
        )
    }

    private var debugSheet: some View {
        let ud = SharedDefaults.container
        let containerOk = ud != nil
        let rawDaily = SharedDefaults.loadDailySeconds()
        let extensionInit = ud?.object(forKey: SharedDefaults.Keys.debugExtensionInit) as? Date
        let monitorStart = ud?.object(forKey: SharedDefaults.Keys.debugMonitorLastStart) as? Date
        let lastThreshold = ud?.string(forKey: SharedDefaults.Keys.debugMonitorLastThreshold)
        let lastThresholdTime = ud?.object(forKey: SharedDefaults.Keys.debugMonitorLastThresholdTime) as? Date
        let containerAccessible = ud?.bool(forKey: SharedDefaults.Keys.debugContainerAccessible) ?? false
        let systemAuthStatus = AuthorizationCenter.shared.authorizationStatus
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"

        let authLabel: String = {
            switch systemAuthStatus {
            case .notDetermined: return "⚠️ não autorizado"
            case .approved: return "✅ aprovado"
            case .denied: return "❌ negado"
            @unknown default: return "desconhecido"
            }
        }()

        return NavigationStack {
            List {
                Section("Autorização") {
                    row("Screen Time (sistema)", authLabel)
                    if systemAuthStatus != .approved {
                        Button("Autorizar agora") {
                            Task { await manager.requestAuthorization() }
                        }
                        .foregroundStyle(.blue)
                    }
                }
                Section("App Group") {
                    row("Container acessível (app)", containerOk ? "✅ sim" : "❌ nil")
                    row("Container acessível (extension)", containerAccessible ? "✅ sim" : "❌ nunca gravou")
                }
                Section("Monitor Extension") {
                    row("Extension init", extensionInit.map { "✅ \(fmt.string(from: $0))" } ?? "❌ processo nunca foi lançado")
                    row("intervalDidStart", monitorStart.map { "✅ \(fmt.string(from: $0))" } ?? "❌ nunca disparou")
                    row("Último threshold", lastThreshold ?? "❌ nunca disparou")
                    row("Horário do threshold", lastThresholdTime.map { fmt.string(from: $0) } ?? "—")
                }
                Section("Dados") {
                    row("Raw daily seconds", String(format: "%.0fs (%.1f min)", rawDaily, rawDaily / 60))
                    row("isSampleData", manager.summary.isSampleData ? "sim (sem dados reais)" : "não (dados reais)")
                    row("Last updated", fmt.string(from: manager.summary.lastUpdated))
                }
                Section("Ações") {
                    Button("Forçar refreshSummary") { manager.refreshSummary() }
                    Button("Limpar dados de debug", role: .destructive) {
                        ud?.removeObject(forKey: SharedDefaults.Keys.debugExtensionInit)
                        ud?.removeObject(forKey: SharedDefaults.Keys.debugMonitorLastStart)
                        ud?.removeObject(forKey: SharedDefaults.Keys.debugMonitorLastThreshold)
                        ud?.removeObject(forKey: SharedDefaults.Keys.debugMonitorLastThresholdTime)
                    }
                }
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { showDebug = false }
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.monospaced()).multilineTextAlignment(.trailing)
        }
    }

    private var appPickerSheet: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $manager.activitySelection)
                .navigationTitle("Selecionar Apps")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Salvar") {
                            manager.saveSelection()
                            showingPicker = false
                        }
                        .fontWeight(.semibold)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") {
                            showingPicker = false
                        }
                    }
                }
        }
    }
}

private extension TimeFrame {
    var reportContext: DeviceActivityReport.Context {
        switch self {
        case .day: .dailyActivity
        case .week: .weeklyActivity
        case .month: .monthlyActivity
        case .year: .yearlyActivity
        }
    }

    func reportInterval(endingAt endDate: Date) -> DateInterval {
        let calendar = Calendar.current
        let component: Calendar.Component = switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
        guard let period = calendar.dateInterval(of: component, for: endDate) else {
            return DateInterval(start: calendar.startOfDay(for: endDate), end: endDate)
        }
        return DateInterval(start: period.start, end: min(endDate, period.end))
    }
}
