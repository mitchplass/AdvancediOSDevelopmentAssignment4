import SwiftUI

struct SessionRow: View {
    @EnvironmentObject private var dataStore: DataStore
    let session: Session
    var showsTrack = true

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let fastest = session.fastestLap {
                Text(fastest.time.formattedTime)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(session.eventSummary(vehicleName: vehicleName, trackName: trackName))
        .accessibilityHint("Shows this session")
    }

    private var title: String {
        if showsTrack { return trackName }
        return session.date.formatted(date: .abbreviated, time: .omitted)
    }

    private var subtitle: String {
        let laps = session.lapCount == 1 ? "1 lap" : "\(session.lapCount) laps"
        if showsTrack {
            let day = session.date.formatted(date: .abbreviated, time: .omitted)
            return "\(laps) · \(day)"
        }
        return laps
    }

    private var trackName: String {
        dataStore.track(for: session.trackID)?.name ?? "Deleted track"
    }

    private var vehicleName: String {
        dataStore.vehicle(for: session.vehicleID)?.name ?? "Bike"
    }
}
