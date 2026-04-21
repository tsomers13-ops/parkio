# Disney Ride Tracker

A native iOS app built in Swift / SwiftUI / SwiftData for tracking rides across Walt Disney World, Disneyland, and Disney California Adventure.

## Features

- Full ride catalog for all three parks, organized by land.
- Tap any ride to log a date (defaults to today) using a graphical date picker.
- Rides support multiple logged dates (repeat visits).
- Ride / unride toggle with a checkmark and per-date delete.
- Persistence via **SwiftData** (local on-device store).
- Per-park stats: rides ridden, total ride-ons, completion percentage, with a progress bar.
- Three view modes via a segmented control: **By Land**, **History** (chronological), and **Unridden**.
- Search bar filters by ride name.
- Tab bar with one tab per park; each park has its own accent color
  (Disney blue for WDW, red for Disneyland, gold for California Adventure).
- Light and dark mode supported.
- Universal (iPhone and iPad).

## Project layout

```
DisneyRideTracker/
├── DisneyRideTracker.xcodeproj
└── DisneyRideTracker/
    ├── DisneyRideTrackerApp.swift     # @main, SwiftData ModelContainer, seeding
    ├── Models/
    │   ├── Park.swift                 # Park enum + lands + accent colors
    │   ├── Ride.swift                 # @Model Ride
    │   ├── RideLog.swift              # @Model RideLog (one logged date)
    │   └── RideSeeder.swift           # First-launch seeding of all rides
    ├── Views/
    │   ├── ContentView.swift          # Root TabView (one tab per park)
    │   ├── ParkView.swift             # Per-park list + search + segmented modes
    │   ├── StatsHeaderView.swift      # Ridden/total, ride-ons, completion %
    │   └── RideDetailView.swift       # Sheet: date picker, logged dates, delete
    ├── Assets.xcassets/
    └── Preview Content/
```

## Requirements

- Xcode 15.3 or later (the project uses `objectVersion = 77` file-system-synchronized groups).
- iOS 17 or later on the deployment target.
- No third-party dependencies. Pure Swift / SwiftUI / SwiftData.

## How to build

1. Open `DisneyRideTracker.xcodeproj` in Xcode.
2. Select the **DisneyRideTracker** scheme.
3. Plug in your iPhone (or pick any iOS 17+ simulator).
4. In **Signing & Capabilities**, set your Apple ID / Team.
   - The bundle identifier is `com.yourname.disneyRideTracker`. Change it to something unique for your team if Xcode complains.
5. Press **⌘R** to build and run.

On first launch the app seeds the SwiftData store with the full ride list. On subsequent launches any newly added rides (e.g. if you edit `RideSeeder.swift`) are inserted without duplicating the ones you already logged.

## Notes on data model

- `Ride` has a stable `id` derived from `"<park>|<land>|<name>"` so the seeder can
  safely re-run and upsert new rides without touching your logs.
- `RideLog` has a `ride` relationship and `date`; `Ride.logs` is the inverse with
  `deleteRule: .cascade` so deleting a ride also removes its logs.
- A few attractions appear in more than one land (e.g. Spider-Man: WEB SLINGERS
  appears in both Hollywood Land and Avengers Campus). The seeder gives each one
  its own record so per-land stats stay correct; the name suffixes (e.g. "(AC)")
  only distinguish IDs internally — the display name shown in the UI comes from
  the `name` field and can be edited freely.

## Tabs

The app has one tab per park (six in total):

1. **MK** — Magic Kingdom
2. **EPCOT** — EPCOT
3. **DHS** — Disney's Hollywood Studios
4. **AK** — Disney's Animal Kingdom
5. **Disneyland** — Disneyland Park
6. **DCA** — Disney California Adventure

> On iPhone portrait iOS automatically collapses a six-tab `TabView` into five visible tabs plus a **More** tab (with the overflow inside). On iPad / iPhone landscape all six are shown.

## Accent colors

| Park | Color | Hex |
| ---- | ----- | --- |
| Magic Kingdom | Cinderella pink | `#F05CA6` |
| EPCOT | Spaceship Earth blue | `#1C59BA` |
| Hollywood Studios | Hollywood crimson | `#A61F30` |
| Animal Kingdom | Tree of Life green | `#3E8F42` |
| Disneyland | Disneyland red | `#D1222E` |
| Disney California Adventure | California gold | `#D9A921` |
