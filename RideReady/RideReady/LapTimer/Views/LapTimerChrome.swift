import SwiftUI

enum LapTimerDestination: Hashable {
    case tracks
}

extension View {
    /// The grouped card used on the Bike, Ride, and Appearance tabs.
    func groupedCard() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16)
            )
    }
}

/// The tinted summary card used for ride-ready status on the Bike and Ride tabs.
struct HighlightCard<Content: View>: View {
    var tint: Color = .accentColor
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(tint.opacity(0.6), lineWidth: 1)
            )
    }
}

struct BottomActionBar<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 10) {
            content()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

struct BikeRequiredNotice: View {
    var onShowBike: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Add your bike first")
                    .font(.headline)
                Text("Lap times are saved against the bike in the Bike tab.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Go to the Bike tab", action: onShowBike)
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.accentColor.opacity(0.6), lineWidth: 1)
        )
    }
}
