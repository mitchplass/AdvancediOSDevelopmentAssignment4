import SwiftUI

struct TracksView: View {
    @EnvironmentObject private var dataStore: DataStore
    @State private var showingAddTrack = false
    @State private var trackPendingDelete: Track?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if dataStore.tracks.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        ForEach(dataStore.tracks) { track in
                            NavigationLink(value: track) {
                                TrackRow(track: track)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete track", role: .destructive) {
                                    trackPendingDelete = track
                                }
                            }
                            if track.id != dataStore.tracks.last?.id {
                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }
                    .groupedCard()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Tracks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddTrack = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add track")
            }
        }
        .sheet(isPresented: $showingAddTrack) {
            AddEditTrackView()
                .environmentObject(dataStore)
        }
        .confirmationDialog(
            "Delete this track?",
            isPresented: Binding(
                get: { trackPendingDelete != nil },
                set: { if !$0 { trackPendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: trackPendingDelete
        ) { track in
            Button("Delete track", role: .destructive) {
                dataStore.deleteTrack(track)
            }
        } message: { _ in
            Text("Sessions you've already saved stay in your lap history.")
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Add a track before you time a session there.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Add a track") {
                showingAddTrack = true
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
        }
        .padding()
        .groupedCard()
    }
}

private struct TrackRow: View {
    @EnvironmentObject private var dataStore: DataStore
    let track: Track

    private var personalBest: Lap? {
        dataStore.personalBest(atTrack: track.id)
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if let personalBest {
                Text(personalBest.time.formattedTime)
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
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows this track")
    }

    private var subtitle: String? {
        if !track.location.isEmpty { return track.location }
        if personalBest == nil { return "No laps yet" }
        return nil
    }
}

#Preview {
    NavigationStack {
        TracksView()
    }
    .environmentObject(DataStore(rideReadyStore: UserDefaultsRideReadyStore()))
}
