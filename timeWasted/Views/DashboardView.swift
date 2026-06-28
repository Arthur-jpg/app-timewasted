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
    @State private var showingPreferences = false
    @State private var reportEndDate = Date.now
    @State private var userPreferences = SharedDefaults.loadUserPreferences()
    @State private var userPreferencesRevision = SharedDefaults.userPreferencesRevision

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
                            tabContent(for: frame)
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
                        showingPreferences = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingPicker = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showingPicker) {
                appPickerSheet
            }
            .sheet(isPresented: $showingPreferences, onDismiss: refreshUserPreferences) {
                ActivityPreferencesView()
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

    @ViewBuilder
    private func tabContent(for frame: TimeFrame) -> some View {
        if hasSelection {
            if frame == selectedTab {
                activityReport(for: frame)
            } else {
                Color.clear
            }
        } else {
            TimeFrameView(timeframe: frame, summary: manager.summary, preferences: userPreferences)
        }
    }

    private func activityReport(for timeframe: TimeFrame) -> some View {
        DeviceActivityReport(
            timeframe.reportContext,
            filter: DeviceActivityFilter(
                segment: timeframe.reportSegment(endingAt: reportEndDate),
                devices: .init([.iPhone]),
                applications: manager.activitySelection.applicationTokens,
                categories: manager.activitySelection.categoryTokens,
                webDomains: manager.activitySelection.webDomainTokens
            )
        )
        .id("preferences-\(userPreferencesRevision)-\(timeframe.rawValue)-\(reportEndDate.timeIntervalSinceReferenceDate)")
    }

    private func refreshUserPreferences() {
        userPreferences = SharedDefaults.loadUserPreferences()
        userPreferencesRevision = SharedDefaults.userPreferencesRevision
        reportEndDate = .now
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

    func reportSegment(endingAt endDate: Date) -> DeviceActivityFilter.SegmentInterval {
        let interval = reportInterval(endingAt: endDate)

        // A yearly query split into daily segments can be truncated by the
        // Screen Time report service to its most recent window. Weekly
        // segments keep the full year in a much smaller result set, while the
        // summed application durations remain unchanged.
        switch self {
        case .year:
            return .weekly(during: interval)
        case .day, .week, .month:
            return .daily(during: interval)
        }
    }
}
