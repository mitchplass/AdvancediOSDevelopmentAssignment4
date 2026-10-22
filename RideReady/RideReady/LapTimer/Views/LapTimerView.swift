import SwiftUI

/// Lap times for the bike in the Bike tab.
struct LapTimerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var dataStore: DataStore
    private let onShowBike: () -> Void
    @State private var showingSession = false

    init(store: RideReadyStoring, onShowBike: @escaping () -> Void = {}) {
        self.onShowBike = onShowBike
        _dataStore = StateObject(wrappedValue: DataStore(rideReadyStore: store))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if dataStore.vehicles.isEmpty {
                        BikeRequiredNotice(onShowBike: onShowBike)
                    }
                    personalBestCard
                    sessionsSection
                    tracksLink
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Lap Timer")
            .navigationDestination(for: LapTimerDestination.self) { _ in
                TracksView()
            }
            .navigationDestination(for: Track.self) { track in
                TrackDetailView(track: track, onShowBike: onShowBike)
            }
            .navigationDestination(for: Session.self) { session in
                LapStatisticsView(session: session)
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
                    .accessibilityHint("Times laps, or lets you enter times you already have")
                }
            }
            .sheet(isPresented: $showingSession) {
                RecordSessionView(onShowBike: {
                    showingSession = false
                    onShowBike()
                })
                .environmentObject(dataStore)
            }
            .onAppear { dataStore.loadAll() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { dataStore.loadAll() }
            }
        }
        .environmentObject(dataStore)
    }
}

private extension LapTimerView {
    var personalBestCard: some View {
        HighlightCard {
            if let best = dataStore.overallPersonalBest {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Personal best")
                        .font(.headline)
                    Text(best.lap.time.formattedTime)
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(bestSubtitle(best))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No lap times yet")
                        .font(.headline)
                    Text("Time a session at the track, or enter times you already have.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    func bestSubtitle(_ best: (session: Session, lap: Lap)) -> String {
        let track = dataStore.track(for: best.session.trackID)?.name ?? "Deleted track"
        let day = best.session.date.formatted(date: .abbreviated, time: .omitted)
        return "\(track) · \(day)"
    }

    var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sessions")
                .font(.headline)
            if dataStore.sessions.isEmpty {
                Text("Sessions you time will show up here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
                    .groupedCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(dataStore.sessions) { session in
                        NavigationLink(value: session) {
                            SessionRow(session: session)
                        }
                        .buttonStyle(.plain)
                        if session.id != dataStore.sessions.last?.id {
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
                .groupedCard()
            }
        }
    }

    var tracksLink: some View {
        NavigationLink(value: LapTimerDestination.tracks) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tracks")
                        .font(.subheadline)
                    Text(tracksSubtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .groupedCard()
        .accessibilityHint("Shows your tracks")
    }

    var tracksSubtitle: String {
        switch dataStore.tracks.count {
        case 0:
            "Add the circuits you ride"
        case 1:
            "1 track"
        default:
            "\(dataStore.tracks.count) tracks"
        }
    }
}

#Preview {
    let store = UserDefaultsRideReadyStore()
    if store.motorcycle() == nil {
        store.save(.yamahaMT07())
    }
    return LapTimerView(store: store)
}
