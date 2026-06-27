import _DeviceActivity_SwiftUI
import DeviceActivity
import SwiftUI

@main
struct TimeWastedReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport(context: .dailyActivity, timeframe: .day) { configuration in
            ReportTimeFrameView(configuration: configuration, timeframe: .day)
        }
        TotalActivityReport(context: .weeklyActivity, timeframe: .week) { configuration in
            ReportTimeFrameView(configuration: configuration, timeframe: .week)
        }
        TotalActivityReport(context: .monthlyActivity, timeframe: .month) { configuration in
            ReportTimeFrameView(configuration: configuration, timeframe: .month)
        }
        TotalActivityReport(context: .yearlyActivity, timeframe: .year) { configuration in
            ReportTimeFrameView(configuration: configuration, timeframe: .year)
        }
    }
}

extension DeviceActivityReport.Context {
    static let dailyActivity = Self(rawValue: "dailyActivity")
    static let weeklyActivity = Self(rawValue: "weeklyActivity")
    static let monthlyActivity = Self(rawValue: "monthlyActivity")
    static let yearlyActivity = Self(rawValue: "yearlyActivity")
}
