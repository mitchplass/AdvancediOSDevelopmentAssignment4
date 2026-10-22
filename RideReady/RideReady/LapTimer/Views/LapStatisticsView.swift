import Charts
import SwiftUI

struct LapStatisticsView: View {
    @EnvironmentObject private var dataStore: DataStore
    let session: Session

    private var vehicle: Vehicle? {
        dataStore.vehicle(for: session.vehicleID)
    }

    private var track: Track? {
        dataStore.track(for: session.trackID)
    }

    private var previousBest: Lap? {
        dataStore.sessions
            .filter {
                $0.trackID == session.trackID
                    && $0.vehicleID == session.vehicleID
                    && $0.id != session.id
                    && $0.date < session.date
            }
            .compactMap(\.fastestLap)
            .min { $0.time < $1.time }
    }

    private var sortedLaps: [Lap] {
        session.laps.sorted { $0.lapNumber < $1.lapNumber }
    }

    private var lapAxisValues: [Int] {
        let count = sortedLaps.count
        let step = max(1, count / 5)
        var values = Array(stride(from: 1, through: count, by: step))
        if values.last != count {
            values.append(count)
        }
        return values
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                statistics
                if sortedLaps.count > 1 {
                    chart
                }
                if !sortedLaps.isEmpty {
                    laps
                }
                if !session.setupNotes.isEmpty {
                    notes
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        HighlightCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(track?.name ?? "Deleted track")
                    .font(.title3.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text(headerDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let fastest = session.fastestLap {
                    Text(fastest.time.formattedTime)
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .padding(.top, 4)
                    Text("Fastest lap")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var headerDetail: String {
        let day = session.date.formatted(date: .abbreviated, time: .omitted)
        guard let name = vehicle?.name else { return day }
        return "\(name) · \(day)"
    }

    private var statistics: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(Array(statRows.enumerated()), id: \.element.label) { index, row in
                    if index > 0 {
                        Divider()
                            .padding(.leading)
                    }
                    statRow(row)
                }
            }
            .groupedCard()
        }
    }

    private struct StatRowModel: Identifiable {
        var id: String { label }
        let label: String
        let value: String
        var tint: Color = .primary
    }

    private var statRows: [StatRowModel] {
        var rows: [StatRowModel] = []
        if let average = session.averageLapTime {
            rows.append(StatRowModel(label: "Average lap", value: average.formattedTime))
        }
        rows.append(StatRowModel(label: "Laps", value: "\(session.lapCount)"))
        if let consistency = session.consistency {
            rows.append(StatRowModel(label: "Consistency", value: consistency.formattedTime))
        }
        if let previousBest {
            rows.append(StatRowModel(label: "Previous best", value: previousBest.time.formattedTime))
            if let fastest = session.fastestLap {
                let delta = fastest.time - previousBest.time
                rows.append(StatRowModel(label: "Change", value: changeText(delta), tint: changeColor(delta)))
            }
        }
        rows.append(StatRowModel(label: "Weather", value: session.weather.rawValue))
        if !session.trackCondition.isEmpty {
            rows.append(StatRowModel(label: "Conditions", value: session.trackCondition))
        }
        return rows
    }

    private func statRow(_ row: StatRowModel) -> some View {
        HStack {
            Text(row.label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(row.value)
                .foregroundStyle(row.tint)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.horizontal)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lap times")
                .font(.headline)
            Chart(sortedLaps) { lap in
                LineMark(
                    x: .value("Lap", lap.lapNumber),
                    y: .value("Time", lap.time)
                )
                .foregroundStyle(Color.accentColor)
                PointMark(
                    x: .value("Lap", lap.lapNumber),
                    y: .value("Time", lap.time)
                )
                .foregroundStyle(Color.accentColor)
            }
            .chartXScale(domain: 1...sortedLaps.count)
            .chartXAxis {
                AxisMarks(values: lapAxisValues) { value in
                    AxisGridLine().foregroundStyle(Color(uiColor: .separator))
                    AxisValueLabel {
                        if let lap = value.as(Int.self) {
                            Text("\(lap)")
                                .font(.caption)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(Color(uiColor: .separator))
                    AxisValueLabel {
                        if let seconds = value.as(Double.self) {
                            Text(seconds.formattedTime)
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 220)
            .padding()
            .groupedCard()
            .accessibilityHidden(true)
        }
    }

    private var laps: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Laps")
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(Array(sortedLaps.enumerated()), id: \.element.id) { index, lap in
                    if index > 0 {
                        Divider()
                            .padding(.leading)
                    }
                    let isFastest = lap.id == session.fastestLap?.id
                    HStack {
                        Text("Lap \(lap.lapNumber)")
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Text(lap.time.formattedTime)
                            .monospacedDigit()
                            .foregroundStyle(isFastest ? Color.accentColor : Color.primary)
                    }
                    .font(.subheadline)
                    .fontWeight(isFastest ? .semibold : .regular)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(isFastest ? "Lap \(lap.lapNumber), fastest" : "Lap \(lap.lapNumber)")
                }
            }
            .groupedCard()
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
            Text(session.setupNotes)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .padding()
                .groupedCard()
        }
    }

    private func changeText(_ delta: TimeInterval) -> String {
        if abs(delta) < 0.0005 { return "No change" }
        let magnitude = abs(delta).formattedTime
        return delta < 0 ? "-\(magnitude)" : "+\(magnitude)"
    }

    private func changeColor(_ delta: TimeInterval) -> Color {
        if delta < -0.0005 { return .green }
        if delta > 0.0005 { return .red }
        return .secondary
    }
}

#Preview {
    NavigationStack {
        LapStatisticsView(
            session: Session(
                vehicleID: UUID(),
                trackID: UUID(),
                laps: [
                    Lap(lapNumber: 1, time: 95.2),
                    Lap(lapNumber: 2, time: 93.4)
                ]
            )
        )
    }
    .environmentObject(DataStore(rideReadyStore: UserDefaultsRideReadyStore()))
}
