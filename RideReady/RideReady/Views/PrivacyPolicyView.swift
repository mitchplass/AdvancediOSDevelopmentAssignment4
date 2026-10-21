import SwiftUI

/// The privacy policy a reviewer, and a rider, can read without leaving the app.
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                section(
                    "RideReady stays on this iPhone",
                    "RideReady does not have an account, and it does not upload your bike, your checks, or your rides. There is no tracking and no advertising."
                )
                section(
                    "What is stored on this iPhone",
                    """
                    The motorcycle profile (name, final drive, tyre pressures, and chain slack), an optional bike photo, pre-ride check results, ride and break times, ride journal entries (title, note, and an optional photo), lap timer tracks, sessions, and lap times, your break-reminder interval, and your light or dark appearance.

                    A short status snapshot is saved in an App Group so the RideReady widget on the Home Screen can show whether you are ride ready. That snapshot stays on this iPhone too.
                    """
                )
                section(
                    "What is not collected",
                    "RideReady does not collect your name, email, contacts, location, or anything that identifies you. Nothing is sold or shared. The photos you attach are not sent anywhere."
                )
                section(
                    "Notifications",
                    "Break reminders are local notifications. RideReady explains why before iOS asks, and the ride timer still works if you say no. If notifications are off, the Ride tab tells you how to turn them on in Settings."
                )
                section(
                    "Photos",
                    "Bike and journal photos use the system photo picker. RideReady does not ask for camera or photo-library access. Each picture is resized and stored with your bike or ride, on this iPhone only. You can remove the bike photo from the bike profile."
                )
                section(
                    "Erasing your data",
                    "Appearance, then Erase ride data, deletes the bike, photo, checks, rides, journal, lap times, streak, and reminder settings. Your appearance choice is left as you set it. Deleting the app also removes everything RideReady stored."
                )
                section(
                    "Children",
                    "RideReady is a tool for riders. It is not directed at children under 13."
                )
                section(
                    "Contact",
                    "Questions about privacy go to \(RideReadySupport.email)."
                )
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Privacy policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

enum RideReadySupport {
    static let email = "mitchellplass@gmail.com"
}
