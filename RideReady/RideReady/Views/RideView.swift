import SwiftUI
import UIKit

struct RideView: View {
    @StateObject private var viewModel: RideViewModel
    @ObservedObject private var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var showingError = false
    @State private var confirmingEnd = false

    init(store: RideReadyStoring, scheduler: NotificationScheduling, router: AppRouter) {
        _viewModel = StateObject(wrappedValue: RideViewModel(store: store, scheduler: scheduler))
        _router = ObservedObject(wrappedValue: router)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                actions
            }
            .navigationTitle("Ride")
            .sensoryFeedback(.impact, trigger: viewModel.phase)
            .task { await viewModel.refreshReminders() }
            .onAppear { viewModel.reload() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    viewModel.reload()
                    Task { await viewModel.refreshReminders() }
                }
            }
            .onChange(of: router.rideChangeCount) { _, _ in
                viewModel.reload()
            }
            .onChange(of: viewModel.riderError) { _, error in
                showingError = error != nil
            }
            .alert("Something went wrong", isPresented: $showingError, actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                Text(viewModel.riderError ?? "")
            })
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .ready:
            bikeCheckCard
            breakReminderCard
            if viewModel.remindersBlocked {
                notificationsOffCard
            }
            recentRidesSection
        case .riding:
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let snapshot = viewModel.ridingSnapshot(at: context.date)
                VStack(alignment: .leading, spacing: 16) {
                    ridingCard(snapshot)
                    if viewModel.remindersBlocked {
                        notificationsOffCard
                    }
                    infoCard(rows: [
                        ("Started", viewModel.startedText),
                        ("Breaks", viewModel.breaksText),
                        ("Break reminder", viewModel.reminderText),
                    ])
                }
            }
        case .onBreak:
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let snapshot = viewModel.breakSnapshot(at: context.date)
                VStack(alignment: .leading, spacing: 16) {
                    breakCard(snapshot)
                    infoCard(rows: [
                        ("Started", viewModel.startedText),
                        ("Riding so far", snapshot.ridingSoFarText),
                        ("Breaks", viewModel.breaksText),
                    ])
                }
            }
        case .finished(let summary):
            summaryCard(summary)
            recentRidesSection
        }
    }

    // MARK: - Ready

    private var bikeCheckCard: some View {
        let check = viewModel.bikeCheck
        let tint: Color = check.kind == .rideReady ? .green : .accentColor
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: check.kind == .rideReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(check.title)
                    .font(.headline)
                Text(check.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if check.kind != .rideReady {
                    Button("Go to the Bike tab") {
                        router.selectedTab = .bike
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.6), lineWidth: 1)
        )
    }

    private var breakReminderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(
                get: { viewModel.settings.isEnabled },
                set: { viewModel.setRemindersEnabled($0) }
            )) {
                Text("Break reminder")
                    .font(.headline)
            }
            if viewModel.settings.isEnabled {
                Stepper(
                    value: Binding(
                        get: { viewModel.settings.intervalMinutes },
                        set: { viewModel.setIntervalMinutes($0) }
                    ),
                    in: viewModel.intervalRange,
                    step: viewModel.intervalStep
                ) {
                    HStack {
                        Text("Remind me every")
                        Spacer(minLength: 8)
                        Text(viewModel.intervalText)
                            .fontWeight(.semibold)
                    }
                }
            }
            Text("Plan a break at least every two hours, even if you don't feel tired.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var notificationsOffCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notifications are off", systemImage: "bell.slash")
                .font(.headline)
            Text("Break reminders can't reach you until you turn on notifications for RideReady in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    openURL(url)
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Riding and breaks

    private func ridingCard(_ snapshot: RideViewModel.RidingSnapshot) -> some View {
        statusCard(
            badge: "Riding",
            badgeTint: .accentColor,
            value: snapshot.ridingText,
            caption: "riding since your last break",
            progress: snapshot.progress,
            progressTint: .accentColor,
            title: snapshot.dueTitle,
            detail: snapshot.dueDetail
        )
    }

    private func breakCard(_ snapshot: RideViewModel.BreakSnapshot) -> some View {
        statusCard(
            badge: "On a break",
            badgeTint: .blue,
            value: snapshot.restedText,
            caption: "resting so far",
            progress: snapshot.progress,
            progressTint: .blue,
            title: snapshot.title,
            detail: snapshot.detail
        )
    }

    private func statusCard(
        badge: String,
        badgeTint: Color,
        value: String,
        caption: String,
        progress: Double?,
        progressTint: Color,
        title: String,
        detail: String
    ) -> some View {
        VStack(spacing: 12) {
            Label(badge, systemImage: "circle.fill")
                .labelStyle(BadgeLabelStyle())
                .font(.caption.weight(.semibold))
                .foregroundStyle(badgeTint)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(badgeTint.opacity(0.14), in: Capsule())
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let progress {
                ProgressView(value: progress)
                    .tint(progressTint)
            }
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private func infoCard(rows: [(String, String)]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack {
                    Text(row.0)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(row.1)
                }
                .font(.subheadline)
                .padding(.horizontal)
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
                if index < rows.count - 1 {
                    Divider()
                        .padding(.leading)
                }
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Recent rides

    private var recentRidesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent rides")
                .font(.headline)
            if viewModel.recentRides.isEmpty {
                Text("Your rides will show up here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.recentRides) { ride in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ride.dateText)
                                .font(.subheadline)
                            Text(ride.detailText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        if ride.id != viewModel.recentRides.last?.id {
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Finished

    private func summaryCard(_ summary: RideViewModel.RideSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text("Ride finished")
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
            }
            .font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 16) {
                GridRow {
                    summaryValue("Total", summary.totalText)
                    summaryValue("Riding", summary.ridingText)
                }
                GridRow {
                    summaryValue("Breaks", summary.breaksText)
                    summaryValue("Longest stint", summary.longestStintText)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func summaryValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 10) {
            switch viewModel.phase {
            case .ready:
                primaryButton("Start ride") { await viewModel.startRide() }
            case .riding:
                primaryButton("Take a break") { await viewModel.takeBreak() }
                endRideButton
            case .onBreak:
                primaryButton("Back on the road") { await viewModel.backOnTheRoad() }
                endRideButton
            case .finished:
                primaryButton("Done") { viewModel.dismissSummary() }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func primaryButton(_ title: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var endRideButton: some View {
        Button {
            confirmingEnd = true
        } label: {
            Text("End ride")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(.primary)
        // Attached to the button so iOS anchors the confirmation to it.
        .confirmationDialog("End this ride?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("End ride", role: .destructive) {
                Task { await viewModel.endRide() }
            }
        }
    }
}

/// A small dot before the badge text.
private struct BadgeLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
                .font(.system(size: 7))
                .accessibilityHidden(true)
            configuration.title
        }
    }
}
