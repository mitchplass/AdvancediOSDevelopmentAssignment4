import SwiftUI

/// Screens pushed from the Bike tab.
enum BikeRoute: Hashable {
    case bikeProfile
    case checklist
}

struct BikeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: BikeViewModel
    @Binding private var path: [BikeRoute]
    @State private var showingError = false

    private let store: RideReadyStoring

    init(store: RideReadyStoring, path: Binding<[BikeRoute]>) {
        self.store = store
        _path = path
        _viewModel = StateObject(wrappedValue: BikeViewModel(store: store))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    BikePhotoView(data: viewModel.motorcyclePhoto, height: 180)
                    specCard
                    statusCard
                    recentChecksSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                startButton
            }
            .navigationTitle("Bike")
            .navigationDestination(for: BikeRoute.self) { route in
                switch route {
                case .bikeProfile:
                    BikeProfileView(store: store, path: $path)
                case .checklist:
                    ChecklistView(store: store, path: $path)
                }
            }
            .onAppear { viewModel.reload() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { viewModel.reload() }
            }
            .onChange(of: path) { _, newPath in
                if newPath.isEmpty {
                    viewModel.reload()
                }
            }
            .alert("Can't start this check", isPresented: $showingError, actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                Text(viewModel.riderError ?? "")
            })
        }
    }

    private var specCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.motorcycleName)
                    .font(.title3.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Button(viewModel.editButtonTitle) {
                    path.append(.bikeProfile)
                }
                .font(.body.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("\(viewModel.editButtonTitle) bike profile")
            }
            ForEach(viewModel.specLines, id: \.self) { line in
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
        .padding(.bottom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var statusCard: some View {
        let tint = viewModel.isRideReady ? Color.green : Color.accentColor
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: viewModel.isRideReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.rideReadyTitle)
                        .font(.headline)
                    Text(viewModel.rideReadyDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider()
            ViewThatFits(in: .horizontal) {
                HStack {
                    lastCheck
                    Spacer(minLength: 8)
                    streak
                }
                VStack(alignment: .leading, spacing: 8) {
                    lastCheck
                    streak
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.6), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var lastCheck: some View {
        Text(viewModel.lastCheckText)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var streak: some View {
        Label(viewModel.streakText, systemImage: "flame.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
    }

    private var recentChecksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent checks")
                .font(.headline)
            if viewModel.recentChecks.isEmpty {
                Text("Checks you log will show up here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.recentChecks) { check in
                        RecentCheckRow(check: check)
                        if check.id != viewModel.recentChecks.last?.id {
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var startButton: some View {
        Button {
            if viewModel.startOrContinueCheck() {
                path.append(.checklist)
            } else {
                showingError = viewModel.riderError != nil
            }
        } label: {
            Text(viewModel.startButtonTitle)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

private struct RecentCheckRow: View {
    let check: BikeViewModel.RecentCheck

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                date
                Spacer(minLength: 8)
                result
            }
            VStack(alignment: .leading, spacing: 4) {
                date
                result
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var date: some View {
        Text(check.dateText)
            .font(.subheadline)
    }

    private var result: some View {
        Label {
            Text(check.resultText)
        } icon: {
            Image(systemName: check.isRideReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(check.isRideReady ? Color.green : Color.accentColor)
        }
        .font(.subheadline)
    }
}

#Preview {
    @Previewable @State var path: [BikeRoute] = []
    let store = UserDefaultsRideReadyStore()
    if store.motorcycle() == nil {
        store.save(.yamahaMT07())
    }
    return BikeView(store: store, path: $path)
}
