import PhotosUI
import SwiftUI

struct BikeProfileView: View {
    @StateObject private var viewModel: BikeProfileViewModel
    @Binding var path: [BikeRoute]
    @State private var showingError = false
    @State private var pickerItem: PhotosPickerItem?
    @FocusState private var nameIsFocused: Bool

    init(store: RideReadyStoring, path: Binding<[BikeRoute]>) {
        _viewModel = StateObject(wrappedValue: BikeProfileViewModel(store: store))
        _path = path
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        BikePhotoView(data: viewModel.photoData, height: 180)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(viewModel.photoData == nil ? "Add a bike photo" : "Change bike photo")
                    .accessibilityHint("Opens the photo picker")
                    .onChange(of: pickerItem) { _, item in
                        Task {
                            guard let item,
                                  let data = try? await item.loadTransferable(type: Data.self) else {
                                return
                            }
                            viewModel.setPhoto(from: data)
                        }
                    }

                    if viewModel.photoData != nil {
                        Button("Remove bike photo", role: .destructive) {
                            viewModel.removePhoto()
                            pickerItem = nil
                        }
                        .font(.subheadline)
                        .frame(minHeight: 44)
                    } else {
                        Text("Tap the photo to add a picture of your bike.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Text("Bike name")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("Yamaha MT-07", text: $viewModel.name)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($nameIsFocused)
                        .onSubmit { nameIsFocused = false }
                        .accessibilityLabel("Bike name")

                    Text("Final drive")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("Final drive", selection: $viewModel.finalDrive) {
                        ForEach(FinalDrive.allCases, id: \.self) { drive in
                            Text(drive.title).tag(drive)
                        }
                    }
                    .pickerStyle(.segmented)

                    specCard(
                        title: "Front tyre",
                        value: $viewModel.frontTyrePressurePSI,
                        range: viewModel.tyrePressureRange,
                        unit: "psi"
                    )
                    specCard(
                        title: "Rear tyre",
                        value: $viewModel.rearTyrePressurePSI,
                        range: viewModel.tyrePressureRange,
                        unit: "psi"
                    )

                    if viewModel.finalDrive == .chain {
                        specCard(
                            title: "Chain slack min",
                            value: $viewModel.chainSlackMinMillimetres,
                            range: viewModel.chainSlackRange,
                            unit: "mm"
                        )
                        specCard(
                            title: "Chain slack max",
                            value: $viewModel.chainSlackMaxMillimetres,
                            range: viewModel.chainSlackRange,
                            unit: "mm"
                        )
                        Text("The chain check will ask you to look for this slack so you know how tight it should feel.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Text("The next walk-around will use this bike's checks, tyre pressures, and chain spec.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollDismissesKeyboard(.interactively)

            Button("Save bike") {
                viewModel.save()
                if viewModel.didSave {
                    path.removeLast()
                } else {
                    showingError = viewModel.riderError != nil
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .navigationTitle("Bike profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { nameIsFocused = false }
            }
        }
        .alert("Can't save this bike", isPresented: $showingError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(viewModel.riderError ?? "")
        })
    }

    private func specCard(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        unit: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Stepper("\(value.wrappedValue) \(unit)", value: value, in: range)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(uiColor: .separator), lineWidth: 1)
        )
    }
}
