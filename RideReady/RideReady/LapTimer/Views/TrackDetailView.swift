import SwiftUI

struct TrackDetailView: View {
    @EnvironmentObject private var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss
    let track: Track
    var onShowBike: () -> Void

    @State private var showingEdit = false
    @State private var showingSession = false
    @State private var confirmingDelete = false

    private var current: Track {
        dataStore.track(for: track.id) ?? track
    }

    private var trackSessions: [Session] {
        dataStore.sessionsForTrack(track.id)
    }

    private var bestLap: Lap? {
        trackSessions.compactMap(\.fastestLap).min { $0.time < $1.time }
    }

    private var bestSession: Session? {
        guard let bestLap else { return nil }
        return trackSessions.first { session in
            session.laps.contains { $0.id == bestLap.id }
        }
    }

    private var hasDetails: Bool {
        !current.location.isEmpty || current.lengthMeters != nil || !current.notes.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if dataStore.vehicles.isEmpty {
                    BikeRequiredNotice(onShowBike: onShowBike)
                }
                bestCard
                if hasDetails {
                    details
                }
                sessions
                deleteButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(current.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEdit = true }
            }
        }
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                Button {
                    showingSession = true
                } label: {
                    Text("Time a session")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(dataStore.vehicles.isEmpty)
            }
        }
        .sheet(isPresented: $showingEdit) {
            AddEditTrackView(trackToEdit: current)
                .environmentObject(dataStore)
        }
        .sheet(isPresented: $showingSession) {
            RecordSessionView(preferredTrackID: current.id, onShowBike: {
                showingSession = false
                onShowBike()
            })
            .environmentObject(dataStore)
        }
        .confirmationDialog("Delete this track?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete track", role: .destructive) {
                dataStore.deleteTrack(current)
                dismiss()
            }
        } message: {
            Text("Sessions you've already saved stay in your lap history.")
        }
    }

    private var bestCard: some View {
        HighlightCard {
            VStack(alignment: .leading, spacing: 4) {
                Text("Personal best")
                    .font(.headline)
                if let bestLap {
                    Text(bestLap.time.formattedTime)
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    if let bestSession {
                        Text(bestDetail(bestSession))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text("No laps at this track yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func bestDetail(_ session: Session) -> String {
        let day = session.date.formatted(date: .abbreviated, time: .omitted)
        guard let vehicle = dataStore.vehicle(for: session.vehicleID) else { return day }
        return "\(vehicle.name) · \(day)"
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.headline)
            VStack(spacing: 0) {
                if !current.location.isEmpty {
                    detailRow("Location", current.location)
                }
                if let length = current.formattedLength {
                    if !current.location.isEmpty {
                        Divider().padding(.leading)
                    }
                    detailRow("Length", length)
                }
                if !current.notes.isEmpty {
                    if !current.location.isEmpty || current.formattedLength != nil {
                        Divider().padding(.leading)
                    }
                    Text(current.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                }
            }
            .groupedCard()
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.horizontal)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var sessions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sessions")
                .font(.headline)
            if trackSessions.isEmpty {
                Text("No sessions at this track yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
                    .groupedCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(trackSessions) { session in
                        NavigationLink(value: session) {
                            SessionRow(session: session, showsTrack: false)
                        }
                        .buttonStyle(.plain)
                        if session.id != trackSessions.last?.id {
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
                .groupedCard()
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            confirmingDelete = true
        } label: {
            Text("Delete track")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .groupedCard()
    }
}

#Preview {
    NavigationStack {
        TrackDetailView(track: Track(name: "Eastern Creek", location: "Sydney, NSW"), onShowBike: {})
    }
    .environmentObject(DataStore(rideReadyStore: UserDefaultsRideReadyStore()))
}
