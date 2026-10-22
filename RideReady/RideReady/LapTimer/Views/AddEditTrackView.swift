import SwiftUI

struct AddEditTrackView: View {
    @EnvironmentObject private var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var lengthFocused: Bool

    var trackToEdit: Track?

    @State private var name: String
    @State private var location: String
    @State private var lengthText: String
    @State private var notes: String
    @State private var errorMessage: String?

    init(trackToEdit: Track? = nil) {
        self.trackToEdit = trackToEdit
        _name = State(initialValue: trackToEdit?.name ?? "")
        _location = State(initialValue: trackToEdit?.location ?? "")
        _lengthText = State(initialValue: trackToEdit?.lengthMeters.map { String(format: "%g", $0) } ?? "")
        _notes = State(initialValue: trackToEdit?.notes ?? "")
    }

    private var isEditing: Bool { trackToEdit != nil }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedLength: Double? {
        let trimmed = lengthText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed)
    }

    private var lengthIsValid: Bool {
        let trimmed = lengthText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        guard let parsedLength else { return false }
        return parsedLength > 0
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && lengthIsValid
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Location", text: $location)
                    TextField("Length in metres", text: $lengthText)
                        .keyboardType(.decimalPad)
                        .focused($lengthFocused)
                } footer: {
                    Text(lengthIsValid
                         ? "Leave the length blank if you don't know it."
                         : "Enter a length in metres, or leave it blank.")
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Edit track" : "Add track")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { lengthFocused = false }
                }
            }
            .alert(
                "Couldn't save this track",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        guard canSave else { return }
        let location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = trackToEdit {
            if dataStore.tracks.contains(where: {
                $0.id != existing.id && $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
            }) {
                errorMessage = "You already have a track named \"\(trimmedName)\". Use that one, or choose a different name."
                return
            }
            var updated = existing
            updated.name = trimmedName
            updated.location = location
            updated.lengthMeters = parsedLength
            updated.notes = notes
            dataStore.updateTrack(updated)
            dismiss()
        } else {
            do {
                try dataStore.registerTrack(
                    name: trimmedName,
                    location: location,
                    lengthMeters: parsedLength,
                    notes: notes
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    AddEditTrackView()
        .environmentObject(DataStore(rideReadyStore: UserDefaultsRideReadyStore()))
}
