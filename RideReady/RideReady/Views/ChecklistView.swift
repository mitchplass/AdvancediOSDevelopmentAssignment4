import SwiftUI

struct ChecklistView: View {
    @StateObject private var viewModel: ChecklistViewModel
    @Binding var path: [BikeRoute]
    @State private var showingError = false

    init(store: RideReadyStoring, path: Binding<[BikeRoute]>) {
        _viewModel = StateObject(wrappedValue: ChecklistViewModel(store: store))
        _path = path
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: viewModel.progress)
                        .tint(Color.accentColor)
                    Text(viewModel.progressText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)

                ForEach(viewModel.rows) { row in
                    ChecklistItemCard(
                        row: row,
                        isExpanded: viewModel.isExpanded(row.item),
                        onToggleGuidance: {
                            withAnimation(.snappy) {
                                viewModel.toggleGuidance(for: row.item)
                            }
                        },
                        onAnswer: { result in
                            withAnimation(.snappy) {
                                viewModel.record(result, for: row.item)
                            }
                            showingError = viewModel.riderError != nil
                        }
                    )
                }
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            footer
        }
        .navigationTitle("Pre-ride check")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: viewModel.answerCount)
        .alert("Can't record this check", isPresented: $showingError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(viewModel.riderError ?? "")
        })
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if viewModel.isComplete {
                Label {
                    Text(viewModel.summaryTitle)
                } icon: {
                    Image(systemName: viewModel.hasIssue ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(viewModel.hasIssue ? Color.accentColor : Color.green)
                }
                .font(.headline)
                Text(viewModel.summaryDetail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(viewModel.remainingText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if viewModel.isComplete {
                Button {
                    viewModel.logCheck()
                    if viewModel.didLog {
                        path.removeAll()
                    } else {
                        showingError = viewModel.riderError != nil
                    }
                } label: {
                    Text(viewModel.logButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                // Holds the space until every item has an answer. VoiceOver reads the remaining count above.
                Text(viewModel.logButtonTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

/// One check item: title and status, guidance that opens and closes, and the
/// OK / Issue answer buttons.
private struct ChecklistItemCard: View {
    let row: ChecklistViewModel.Row
    let isExpanded: Bool
    let onToggleGuidance: () -> Void
    let onAnswer: (InspectionResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onToggleGuidance) {
                HStack(spacing: 12) {
                    statusIcon
                    Text(row.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(row.title), \(statusDescription)")
            .accessibilityHint(isExpanded ? "Hides the guidance" : "Shows the guidance")

            if isExpanded {
                Text(row.guidance)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }

            HStack(spacing: 12) {
                answerButton("OK", systemImage: "checkmark.circle", result: .ok, tint: .green)
                answerButton("Issue", systemImage: "exclamationmark.triangle", result: .needsAttention, tint: .accentColor)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(row.result == .needsAttention ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch row.result {
        case .ok:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.green)
        case .needsAttention:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.accentColor)
        case nil:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        }
    }

    private var statusDescription: String {
        switch row.result {
        case .ok: return "OK"
        case .needsAttention: return "needs attention"
        case nil: return "not checked"
        }
    }

    private func answerButton(
        _ title: String,
        systemImage: String,
        result: InspectionResult,
        tint: Color
    ) -> some View {
        let isSelected = row.result == result
        return Button {
            onAnswer(result)
        } label: {
            Label {
                Text(title)
                    .fontWeight(isSelected ? .semibold : .regular)
            } icon: {
                Image(systemName: isSelected ? "\(systemImage).fill" : systemImage)
                    .foregroundStyle(tint)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                isSelected ? tint.opacity(0.18) : Color(uiColor: .tertiarySystemFill),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? tint : Color.clear, lineWidth: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(row.title) \(title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
