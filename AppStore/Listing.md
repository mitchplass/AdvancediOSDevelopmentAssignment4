# RideReady App Store listing

Everything App Store Connect asks for to submit version 1.0, ready to paste. Character counts are against Apple's limits.

## App information

| Field | Value |
|---|---|
| Name (25/30) | RideReady: Pre-Ride Check |
| Subtitle (28/30) | Motorcycle checks and breaks |
| Bundle ID | com.iosdev.RideReady |
| SKU | rideready-ios |
| Primary category | Utilities |
| Secondary category | Sports |
| Content rights | Does not contain, show, or access third-party content |
| Age rating | 4+ (answer None or No to every question in the age rating questionnaire) |
| Price | Free, no In-App Purchases |
| Copyright | 2026 followed by the developer account holder's legal name |

The store name adds "Pre-Ride Check" because another developer already publishes an app called "Ride Ready". The Home Screen name stays RideReady (`CFBundleDisplayName`).

## URLs

| Field | Value |
|---|---|
| Privacy Policy URL | https://github.com/mitchplass/AdvancediOSDevelopmentAssignment4/blob/main/AppStore/PRIVACY.md |
| Support URL | https://github.com/mitchplass/AdvancediOSDevelopmentAssignment4/blob/main/AppStore/SUPPORT.md |
| Marketing URL | Leave empty |

Both pages resolve once this branch is merged into `main`.

## App privacy

| Question | Answer |
|---|---|
| Do you or your third-party partners collect data from this app? | No, "Data Not Collected" |
| Tracking | No |

RideReady stores data on the device only and sends nothing off it, so under Apple's definition nothing is collected.

## Export compliance

`ITSAppUsesNonExemptEncryption` is `NO` in the app's Info.plist, so App Store Connect does not ask the encryption questions for each build.

## Promotional text (156/170)

```text
Walk round your bike before every ride. RideReady checks it against your own tyre pressures and chain slack, then reminds you to take a break on long rides.
```

## Description (1301/4000)

```text
RideReady is a pre-ride check for motorcyclists. Set up your bike once, walk round it before you leave, and know you are ride ready.

PRE-RIDE CHECK
• Tyres, checked against your own front and rear pressures
• Chain slack on chain bikes, or the shaft or belt on everything else
• Lights, fluids, and riding gear
• Mark each item OK or Issue, and RideReady tells you whether the bike is ready to ride
• A streak counts the days in a row you logged a check

RIDES AND BREAKS
• Start a ride and see how long you have been riding since your last break
• Get a break reminder every 30 minutes up to every 4 hours
• Start a break, or ask again in 30 minutes, straight from the notification
• Keep a ride journal with a title, a note, and a photo

TRACK DAYS
• Register the circuits you ride
• Record sessions with the weather, track condition, setup notes, and lap times
• See your fastest lap, average lap, consistency, and change from your previous best, with a chart of every lap

HOME SCREEN WIDGET
• See your bike, when you last checked it, and anything that needs attention without opening the app

PRIVATE BY DESIGN
• No account, no tracking, and no ads
• Everything stays on your device
• Erase all ride data from the app at any time

RideReady works in light and dark appearance on iPhone and iPad.
```

## Keywords (98/100)

```text
motorbike,checklist,inspection,walkaround,tyre,tire,pressure,chain,maintenance,lap timer,track day
```

## Screenshots

Upload in this order. Each is a portrait PNG with no alpha channel, taken from the app running on the iOS 27 simulator.

| # | Shows | iPhone 6.3" (1206 × 2622) | iPad 13" (2064 × 2752) |
|---|---|---|---|
| 1 | Bike tab after a passed check, with the streak | [01](Screenshots/iPhone-6.3/01-bike-ride-ready.png) | [01](Screenshots/iPad-13/01-bike-ride-ready.png) |
| 2 | Pre-ride check part-way through | [02](Screenshots/iPhone-6.3/02-pre-ride-check.png) | [02](Screenshots/iPad-13/02-pre-ride-check.png) |
| 3 | Ride in progress with the next break due | [03](Screenshots/iPhone-6.3/03-ride.png) | [03](Screenshots/iPad-13/03-ride.png) |
| 4 | Lap timer session statistics | [04](Screenshots/iPhone-6.3/04-lap-timer.png) | [04](Screenshots/iPad-13/04-lap-timer.png) |
| 5 | Privacy, support, and erase data | [05](Screenshots/iPhone-6.3/05-privacy.png) | [05](Screenshots/iPad-13/05-privacy.png) |

Apple requires the iPhone 6.3" (Dynamic Island, medium display) set and, because RideReady runs on iPad, the iPad 13" set. App Store Connect scales them for smaller devices.

## App Review information

| Field | Value |
|---|---|
| Sign-in required | No |
| Contact | Mitchell Plass, mitchellplass@gmail.com |
| Phone | Required by App Store Connect; enter Mitchell's number when submitting. It is not shown on the store. |

Notes:

```text
RideReady has no account and no server. Everything stays on the device, so no sign-in or demo account is needed.

1. Bike tab: tap Start pre-ride check, mark each item OK or Issue, then log the check.
2. Ride tab: tap Allow notifications, set Remind me every to 30 min, then tap Start ride. A break reminder arrives 30 minutes later with Start break and Remind me in 30 min actions.
3. Lap Timer tab: open Tracks and use the Register Track button to add a circuit, then tap the stopwatch to record a session with lap times such as 1:42.318.
4. Home Screen: add the small or medium Pre-ride check widget.
5. Appearance tab: Privacy policy, the support email, and Erase ride data.
```
