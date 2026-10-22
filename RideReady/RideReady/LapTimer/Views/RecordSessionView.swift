import SwiftUI
import UIKit

/// Times laps with the clock, or saves lap times the rider already has.
struct RecordSessionView: View {
    @EnvironmentObject private var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedTimePart: TimePart?

    private let onShowBike: () -> Void

    @State private var mode: RecordMode = .timeLaps
    @State private var selectedTrackID: UUID?
    @State private var date = Date()
    @State private var weather: WeatherCondition = .dry
    @State private var notes = ""
    @State private var clock = LapSessionClock()
    @State private var typedLaps: [Lap] = []
    @State private var minutesText = ""
    @State private var secondsText = ""
    @State private var millisecondsText = ""
    @State private var showingAddTrack = false
    @State private var knownTrackIDs: Set<UUID> = []
    @State private var confirmingFinish = false
    @State private var confirmingDiscard = false
    @State private var errorMessage: String?

    private enum Timing {
        /// Ignores a double tap that would log a lap shorter than a third of a second.
        static let minimumLap: TimeInterval = 0.3
    }

    private enum TimePart: Hashable {
        case minutes, seconds, milliseconds
    }

    private enum RecordMode: String, CaseIterable, Identifiable {
        case timeLaps
        case enterTimes

        var id: String { rawValue }

        var title: String {
            switch self {
            case .timeLaps: "Time laps"
            case .enterTimes: "Enter times"
            }
        }

        var detail: String {
            switch self {
            case .timeLaps:
                "Start the clock, then tap Lap each time you cross the line."
            case .enterTimes:
                "Add lap times you already have, one at a time."
            }
        }
    }

    init(preferredTrackID: UUID? = nil, onShowBike: @escaping () -> Void = {}) {
        self.onShowBike = onShowBike
        _selectedTrackID = State(initialValue: preferredTrackID)
    }

    private var hasBike: Bool { dataStore.vehicles.first != nil }

    private var canUseTrack: Bool {
        hasBike && selectedTrackID != nil
    }

    private var typedDuration: TimeInterval? {
        LapTimeEntry.duration(minutes: minutesText, seconds: secondsText, milliseconds: millisecondsText)
    }

    private var hasWorkInProgress: Bool {
        clock.isRunning || !typedLaps.isEmpty
    }

    private var openLapIsLongEnough: Bool {
        clock.currentLapDuration(at: Date()) >= Timing.minimumLap
    }

    var body: some View {
        NavigationStack {
            Group {
                if clock.isRunning {
                    timingScreen
                } else {
                    setupForm
                        .safeAreaInset(edge: .bottom) {
                            if hasBike {
                                setupActions
                            }
                        }
                }
            }
            .navigationTitle(screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedTimePart = nil }
                }
            }
            .confirmationDialog("Finish this session?", isPresented: $confirmingFinish, titleVisibility: .visible) {
                if openLapIsLongEnough {
                    Button("Save the lap you're on") { saveTimed(keepOpenLap: true) }
                }
                if !clock.laps.isEmpty {
                    Button(openLapIsLongEnough ? "Discard this lap and save" : "Save session") {
                        saveTimed(keepOpenLap: false)
                    }
                }
                Button("Keep timing", role: .cancel) {}
            } message: {
                Text(finishMessage)
            }
            .confirmationDialog("Discard this session?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Discard session", role: .destructive) { dismiss() }
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("The laps in this session won't be saved.")
            }
            .alert(
                "Couldn't save this session",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .interactiveDismissDisabled(hasWorkInProgress)
            .onAppear(perform: prepareTrackSelection)
            .onChange(of: mode) { _, _ in
                focusedTimePart = nil
            }
            .onChange(of: clock.isRunning) { _, running in
                UIApplication.shared.isIdleTimerDisabled = running
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .sheet(isPresented: $showingAddTrack, onDismiss: selectTrackAddedWhileSheetWasOpen) {
                AddEditTrackView()
                    .environmentObject(dataStore)
            }
        }
    }

    private var screenTitle: String {
        if clock.isRunning { return "Timing" }
        return mode == .timeLaps ? "Time a session" : "Enter times"
    }

    private var finishMessage: String {
        if clock.laps.isEmpty && !openLapIsLongEnough {
            return "Mark a lap before finishing. Tap Lap when you cross the line."
        }
        if openLapIsLongEnough && !clock.laps.isEmpty {
            return "You can save the lap you're on, or keep only the laps you've already marked."
        }
        if openLapIsLongEnough {
            return "This saves the lap you're on and ends the session."
        }
        return "This saves the laps you've marked and ends the session."
    }

    private var setupForm: some View {
        Form {
            if !hasBike {
                Section {
                    Text("Set up your bike in the Bike tab before timing a session.")
                        .foregroundStyle(.secondary)
                    Button("Go to the Bike tab") {
                        dismiss()
                        onShowBike()
                    }
                    .frame(minHeight: 44)
                }
            } else {
                Section {
                    Picker("How to record", selection: $mode) {
                        ForEach(RecordMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityLabel("How to record")
                    Text(mode.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let bike = dataStore.vehicles.first {
                    Section {
                        LabeledContent("Bike", value: bike.name)
                    }
                }

                trackSection
                weatherSection

                if mode == .enterTimes {
                    Section("Date") {
                        DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                    }
                    lapEntrySection
                }

                Section("Notes") {
                    TextField("Setup, tyres, or anything you want to remember", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var trackSection: some View {
        Section("Track") {
            if dataStore.tracks.isEmpty {
                Text("Add the circuit you're riding.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Track", selection: $selectedTrackID) {
                    Text("Select a track").tag(nil as UUID?)
                    ForEach(dataStore.tracks) { track in
                        Text(track.name).tag(track.id as UUID?)
                    }
                }
            }
            Button("Add a track", action: beginAddTrack)
                .frame(minHeight: 44)
        }
    }

    private var weatherSection: some View {
        Section("Weather") {
            Picker("Weather", selection: $weather) {
                ForEach(WeatherCondition.allCases) { condition in
                    Text(condition.rawValue).tag(condition)
                }
            }
        }
    }

    private var lapEntrySection: some View {
        Section("Lap times") {
            if typedLaps.isEmpty {
                Text("Add each lap you already have.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(typedLaps) { lap in
                    HStack {
                        Text("Lap \(lap.lapNumber)")
                        Spacer(minLength: 8)
                        Text(lap.time.formattedTime)
                            .monospacedDigit()
                            .foregroundStyle(isFastestTyped(lap) ? Color.accentColor : Color.primary)
                    }
                    .accessibilityElement(children: .combine)
                }
                .onDelete(perform: deleteTypedLaps)
            }

            HStack(alignment: .top, spacing: 12) {
                timeField("Minutes", text: $minutesText, part: .minutes, limit: 3)
                timeField("Seconds", text: $secondsText, part: .seconds, limit: 2)
                timeField("Milliseconds", text: $millisecondsText, part: .milliseconds, limit: 3)
            }
            .padding(.vertical, 4)

            Text(typedDuration?.formattedTime ?? "0:00.000")
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(typedDuration == nil ? Color.secondary : Color.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityLabel("Lap time to add")
                .accessibilityValue(typedDuration?.formattedTime ?? "None")

            Text("Seconds are 0 to 59. This is the lap you'll add.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Add lap", action: addTypedLap)
                .disabled(typedDuration == nil)
                .frame(minHeight: 44)
        }
    }

    private func timeField(_ title: String, text: Binding<String>, part: TimePart, limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title3.monospacedDigit())
                .focused($focusedTimePart, equals: part)
                .frame(minHeight: 44)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel(title)
                .onChange(of: text.wrappedValue) { _, newValue in
                    let cleaned = String(newValue.filter(\.isNumber).prefix(limit))
                    if cleaned != newValue {
                        text.wrappedValue = cleaned
                    }
                }
        }
    }

    private var setupActions: some View {
        BottomActionBar {
            switch mode {
            case .timeLaps:
                Button(action: startTiming) {
                    Text("Start timing")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canUseTrack)
            case .enterTimes:
                Button(action: saveEntered) {
                    Text("Save session")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canUseTrack || typedLaps.isEmpty)
            }
        }
    }

    private var timingScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TimelineView(.periodic(from: .now, by: 0.05)) { context in
                    timerCard(at: context.date)
                }
                completedLaps
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                Button(action: markCurrentLap) {
                    Text("Lap")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityHint("Saves this lap and starts the next")
                Button {
                    confirmingFinish = true
                } label: {
                    Text("Finish session")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.primary)
            }
        }
        .sensoryFeedback(.impact, trigger: clock.laps.count)
    }

    private func timerCard(at date: Date) -> some View {
        let elapsed = clock.currentLapDuration(at: date)
        let sessionTime = clock.laps.reduce(0) { $0 + $1.time } + elapsed
        return VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 7))
                    .accessibilityHidden(true)
                Text("Timing")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color.accentColor.opacity(0.14), in: Capsule())

            VStack(spacing: 4) {
                Text(elapsed.formattedTime)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("lap \(clock.laps.count + 1)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Text(trackName)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("\(weather.rawValue) · Session \(sessionTime.formattedTime)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityLabel("Lap \(clock.laps.count + 1)")
        .accessibilityValue("\(Int(elapsed)) seconds")
    }

    private var completedLaps: some View {
        VStack(alignment: .leading, spacing: 8) {
            if clock.laps.isEmpty {
                Text("Tap Lap each time you cross the start line.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
                    .groupedCard()
            } else {
                Text("Laps")
                    .font(.headline)
                VStack(spacing: 0) {
                    let ordered = clock.laps.sorted { $0.lapNumber > $1.lapNumber }
                    ForEach(ordered) { lap in
                        timedLapRow(lap)
                        if lap.id != ordered.last?.id {
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
                .groupedCard()
                Button("Undo last lap") {
                    clock.undoLastLap()
                }
                .frame(minHeight: 44)
            }
        }
    }

    private func timedLapRow(_ lap: Lap) -> some View {
        let isFastest = clock.laps.count > 1 && clock.laps.min(by: { $0.time < $1.time })?.id == lap.id
        return HStack {
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
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isFastest ? "Lap \(lap.lapNumber), fastest" : "Lap \(lap.lapNumber)")
    }

    private var trackName: String {
        guard let selectedTrackID, let track = dataStore.track(for: selectedTrackID) else {
            return "Track"
        }
        return track.name
    }

    private func prepareTrackSelection() {
        dataStore.reloadVehicles()
        if let selectedTrackID, dataStore.track(for: selectedTrackID) != nil {
            return
        }
        selectedTrackID = dataStore.tracks.first?.id
    }

    private func beginAddTrack() {
        knownTrackIDs = Set(dataStore.tracks.map(\.id))
        showingAddTrack = true
    }

    private func selectTrackAddedWhileSheetWasOpen() {
        if let added = dataStore.tracks.first(where: { !knownTrackIDs.contains($0.id) }) {
            selectedTrackID = added.id
        }
    }

    private func startTiming() {
        guard canUseTrack else { return }
        focusedTimePart = nil
        clock.start(at: Date())
    }

    private func markCurrentLap() {
        let now = Date()
        guard clock.currentLapDuration(at: now) >= Timing.minimumLap else { return }
        clock.markLap(at: now)
    }

    private func cancel() {
        if hasWorkInProgress {
            confirmingDiscard = true
        } else {
            dismiss()
        }
    }

    private func isFastestTyped(_ lap: Lap) -> Bool {
        typedLaps.min(by: { $0.time < $1.time })?.id == lap.id
    }

    private func addTypedLap() {
        guard let time = typedDuration else { return }
        typedLaps.append(Lap(lapNumber: typedLaps.count + 1, time: time))
        minutesText = ""
        secondsText = ""
        millisecondsText = ""
    }

    private func deleteTypedLaps(at offsets: IndexSet) {
        typedLaps.remove(atOffsets: offsets)
        for index in typedLaps.indices {
            typedLaps[index].lapNumber = index + 1
        }
    }

    private func saveEntered() {
        guard canUseTrack else { return }
        do {
            try persist(laps: typedLaps, date: date)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveTimed(keepOpenLap: Bool) {
        let now = Date()
        let keep = keepOpenLap && clock.currentLapDuration(at: now) >= Timing.minimumLap
        let laps = clock.lapsForSaving(at: now, keepOpenLap: keep)
        guard !laps.isEmpty else {
            errorMessage = "Add at least one lap before saving."
            return
        }
        do {
            try persist(laps: laps, date: now)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persist(laps: [Lap], date: Date) throws {
        guard let vehicleID = dataStore.vehicles.first?.id else {
            throw TrackDaySessionError.vehicleNotRegistered(vehicleID: UUID())
        }
        guard let trackID = selectedTrackID else {
            throw TrackDaySessionError.trackNotRegistered(trackID: UUID())
        }
        try dataStore.recordSession(
            vehicleID: vehicleID,
            trackID: trackID,
            date: date,
            weather: weather,
            trackCondition: "",
            setupNotes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            laps: laps
        )
    }
}

#Preview {
    RecordSessionView()
        .environmentObject(DataStore(rideReadyStore: UserDefaultsRideReadyStore()))
}
