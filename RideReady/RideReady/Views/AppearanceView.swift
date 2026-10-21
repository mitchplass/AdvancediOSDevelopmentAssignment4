import SwiftUI

struct AppearanceView: View {
    @ObservedObject var settings: AppearanceSettings
    @StateObject private var privacy: PrivacyViewModel
    @State private var confirmingErase = false

    init(settings: AppearanceSettings, store: RideReadyStoring, journal: RideJournalRepository) {
        self.settings = settings
        _privacy = StateObject(wrappedValue: PrivacyViewModel(store: store, journal: journal))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    appearanceCard
                    privacyCard
                    supportCard
                    dataCard
                    Text(privacy.versionText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Appearance")
            .confirmationDialog(
                "Erase ride data?",
                isPresented: $confirmingErase,
                titleVisibility: .visible
            ) {
                Button("Erase ride data", role: .destructive) {
                    privacy.erase()
                }
            } message: {
                Text("This removes the bike, photo, checks, rides, and streak from this iPhone.")
            }
        }
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(.headline)
            Picker("Appearance", selection: $settings.mode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Appearance")
            Text(settings.mode.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Privacy")
                .font(.headline)
            Text("Your bike, checks, rides, and photos stay on this iPhone. RideReady has no account and does not track you.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            NavigationLink {
                PrivacyPolicyView()
            } label: {
                Text("Privacy policy")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .font(.body.weight(.semibold))
        }
        .card()
    }

    private var supportCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Support")
                .font(.headline)
            Text("Questions about a check, a ride, or your data:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Link(RideReadySupport.email, destination: RideReadySupport.mailURL)
                .font(.body.weight(.semibold))
                .frame(minHeight: 44)
            Text("Add the RideReady widget to the Home Screen to see if you are ride ready.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Data on this iPhone")
                .font(.headline)
            if privacy.didErase {
                Text("Ride data was erased from this iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Erase the bike, photo, checks, rides, journal, lap times, and streak. Appearance stays as you set it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Erase ride data", role: .destructive) {
                confirmingErase = true
            }
            .frame(minHeight: 44)
        }
        .card()
    }
}

private extension View {
    func card() -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16)
            )
    }
}

extension RideReadySupport {
    static var mailURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [URLQueryItem(name: "subject", value: "RideReady support")]
        return components.url ?? URL(string: "mailto:\(email)")!
    }
}

#Preview {
    let defaults = UserDefaults(suiteName: "RideReady.AppearancePreview") ?? .standard
    AppearanceView(
        settings: AppearanceSettings(defaults: defaults),
        store: UserDefaultsRideReadyStore(defaults: defaults),
        journal: PreviewJournal()
    )
}

private struct PreviewJournal: RideJournalRepository {
    func entries(forRide rideID: UUID) throws -> [JournalEntry] { [] }
    func save(_ entry: JournalEntry) throws {}
    func eraseAll() throws {}
}
