import SwiftUI
import WidgetKit

struct PreRideEntry: TimelineEntry {
    let date: Date
    let snapshot: RideReadyWidgetSnapshot?
    let appearance: WidgetAppearancePreference

    init(date: Date, snapshot: RideReadyWidgetSnapshot?,
         appearance: WidgetAppearancePreference = .system) {
        self.date = date
        self.snapshot = snapshot
        self.appearance = appearance
    }
}

struct PreRideTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PreRideEntry {
        PreRideEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (PreRideEntry) -> Void) {
        completion(PreRideEntry(
            date: .now,
            snapshot: context.isPreview ? .sample : WidgetSnapshotFile().read(),
            appearance: WidgetAppearancePreference.read(from: WidgetAppearancePreference.groupDefaults())
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PreRideEntry>) -> Void) {
        let now = Date()
        let nextDay = RideReadyWidgetSnapshot.nextDay(after: now)
        let snapshot = WidgetSnapshotFile().read()
        let appearance = WidgetAppearancePreference.read(from: WidgetAppearancePreference.groupDefaults())
        let entries = [
            PreRideEntry(date: now, snapshot: snapshot, appearance: appearance),
            PreRideEntry(date: nextDay, snapshot: snapshot, appearance: appearance)
        ]
        // App writes request an explicit timeline reload when data or appearance changes.
        let reload = snapshot == nil ? now.addingTimeInterval(15 * 60) : nextDay
        completion(Timeline(entries: entries, policy: .after(reload)))
    }
}

struct PreRideWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var systemColorScheme
    let entry: PreRideEntry

    private var chosenScheme: ColorScheme {
        switch entry.appearance {
        case .system: return systemColorScheme
        case .light: return .light
        case .dark: return .dark
        }
    }

    private var dark: Bool { chosenScheme == .dark }

    // Matches the App's AccentColor.colorset, including its dark appearance.
    private var accent: Color {
        dark ? Color(red: 1.000, green: 0.580, blue: 0.310)
             : Color(red: 0.831, green: 0.392, blue: 0.165)
    }

    private var surface: Color {
        dark ? Color(red: 0.172, green: 0.172, blue: 0.184)
             : Color.white
    }

    private var widgetBackground: Color {
        dark ? Color(red: 0.110, green: 0.110, blue: 0.118)
             : Color(red: 0.949, green: 0.949, blue: 0.969)
    }

    private var primaryText: Color { dark ? .white : .black }
    private var secondaryText: Color { dark ? Color.white.opacity(0.72) : Color.black.opacity(0.62) }

    private var status: RideReadyWidgetSnapshot.Status? {
        entry.snapshot?.status(at: entry.date)
    }

    private var title: String {
        switch status {
        case .setup: return "Set up your bike"
        case .notChecked: return "Check before riding"
        case .inProgress: return "Check in progress"
        case .needsAttention: return "Needs attention"
        case .checked: return "Checks passed today"
        case nil: return "Open RideReady"
        }
    }

    private var lastCheck: String {
        WidgetLastCheckText.string(for: entry.snapshot?.lastCompletedAt, relativeTo: entry.date)
    }

    private var detail: String {
        guard let snapshot = entry.snapshot else { return "Open the app to sync." }
        if !snapshot.flaggedItems.isEmpty {
            return "Flagged: \(snapshot.flaggedItems.joined(separator: ", "))"
        }
        if snapshot.hasActiveInspection {
            return "\(snapshot.checkedItems) of \(snapshot.requiredItems) recorded"
        }
        switch status {
        case .checked: return "Review before your next ride."
        case .needsAttention: return "Review the last check in the app."
        case .setup: return "Add your motorcycle."
        default: return "No passed check for today."
        }
    }

    private var shortDetail: String {
        let flagged = entry.snapshot?.flaggedItems ?? []
        guard let first = flagged.first else { return detail }
        return flagged.count == 1 ? "Flagged: \(first)" : "Flagged: \(first) +\(flagged.count - 1)"
    }

    private var symbol: String {
        switch status {
        case .checked: return "checkmark.circle.fill"
        case .needsAttention: return "exclamationmark.triangle.fill"
        case .inProgress: return "list.clipboard.fill"
        default: return "list.clipboard"
        }
    }

    private var statusTint: Color {
        switch status {
        case .checked: return dark ? Color(red: 0.34, green: 0.86, blue: 0.52) : .green
        case .needsAttention: return accent
        default: return accent
        }
    }

    private var opensHistory: Bool {
        status == .checked || (status == .needsAttention && entry.snapshot?.hasActiveInspection != true)
    }

    private var action: String {
        if opensHistory { return "View checks" }
        switch status {
        case nil: return "Open app"
        case .setup: return "Set up bike"
        default: return entry.snapshot?.hasActiveInspection == true ? "Continue check" : "Start check"
        }
    }

    private var bikeName: String { entry.snapshot?.motorcycleName ?? "RideReady" }

    var body: some View {
        Group {
            if family == .systemMedium { mediumContent }
            else { smallContent }
        }
        .foregroundStyle(primaryText)
        // App appearance is separate from the iPhone home screen's setting.
        .environment(\.colorScheme, chosenScheme)
        .widgetURL(status == nil || opensHistory
            ? RideReadyWidgetConfiguration.homeURL
            : RideReadyWidgetConfiguration.checkURL)
        .containerBackground(for: .widget) { widgetBackground }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("RideReady. \(bikeName). \(title). Last check: \(lastCheck). \(detail)")
        .accessibilityHint(action)
    }

    private var brandHeader: some View {
        HStack(spacing: 5) {
            Image(systemName: "motorcycle")
                .foregroundStyle(accent)
            Text("RIDE READY")
                .foregroundStyle(accent)
                .tracking(0.5)
            Spacer(minLength: 0)
            Image(systemName: symbol)
                .foregroundStyle(statusTint)
        }
        .font(.caption2.weight(.bold))
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.78)
            Text(shortDetail)
                .font(.caption2)
                .foregroundStyle(secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(statusTint.opacity(dark ? 0.18 : 0.10),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusTint.opacity(0.42), lineWidth: 1)
        }
    }

    private var actionLabel: some View {
        HStack(spacing: 4) {
            Text(action)
            Image(systemName: "arrow.up.right")
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(accent)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            brandHeader
            Text(bikeName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .privacySensitive()
            statusCard
            Spacer(minLength: 0)
            actionLabel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var mediumContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            brandHeader
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(bikeName)
                        .font(.headline)
                        .lineLimit(1)
                        .privacySensitive()
                    statusCard
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 7) {
                    Text("Last check")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(secondaryText)
                    Text(lastCheck)
                        .font(.caption.weight(.medium))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    actionLabel
                }
                .padding(11)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(surface, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@main
struct RideReadyPreRideWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: RideReadyWidgetConfiguration.kind,
            provider: PreRideTimelineProvider()
        ) { entry in
            PreRideWidgetView(entry: entry)
        }
        .configurationDisplayName("Pre-ride check")
        .description("Your bike, last inspection time, and items needing attention.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    RideReadyPreRideWidget()
} timeline: {
    PreRideEntry(date: .now, snapshot: .sample, appearance: .light)
    PreRideEntry(date: .now, snapshot: .sample, appearance: .dark)
    PreRideEntry(date: .now, snapshot: RideReadyWidgetSnapshot(motorcycleName: "Yamaha MT-07"))
}

#Preview(as: .systemMedium) {
    RideReadyPreRideWidget()
} timeline: {
    PreRideEntry(date: .now, snapshot: .sample, appearance: .light)
    PreRideEntry(date: .now, snapshot: RideReadyWidgetSnapshot(
        motorcycleName: "Yamaha MT-07", needsAttention: true,
        lastCompletedAt: Date().addingTimeInterval(-3600), flaggedItems: ["Tyres", "Chain"]
    ), appearance: .dark)
}
