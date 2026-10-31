# MedPlant – presentation polish (30 Oct 2026)

A copy of the code from before these changes is in
`medplant_project/_backup_before_polish/`.

## Run it
```
flutter clean
flutter pub get
flutter run
```
ML server on a real phone: `localhost` means the phone itself. Either run
`adb reverse tcp:8000 tcp:8000` (USB), or pass your laptop's Wi-Fi IP:
`flutter run --dart-define=ML_BASE_URL=http://192.168.x.x:8000`

## What changed
- **Edge-to-edge layout**: the bottom nav floats just above the phone's own
  navigation bar, and content stays clear of the status bar.
- **Back button**: on a tab it goes to Home; on Home it asks
  "Press back again to exit". Secondary pages return to the previous screen.
- **Consistent secondary pages** (`widgets/secondary_scaffold.dart`): green
  app bar with a back arrow, used for Add Report, Plant Detail, Report
  Review, About, Contact, Contact Messages and "Page not found".
- **All secondary links use `push`** instead of `go`, so Back works.
- **New Profile screen**:
  - initials avatar
  - live stats
  - recent submissions with status
  - editable account details
  - password reset
  - researcher tools
  - logout with confirmation
  - guest view
- **Logout** now signs out of Firebase. Before, it only cleared the role, so
  the session came back on restart.
- **Session restore** waits for Firebase, so the web version stays logged in
  after a refresh.
- **Navigation state** no longer changes during a build. That used to throw
  "setState during build" and reset the active tab.
- **Responsive grids** (`widgets/responsive_wrap_grid.dart`) for species,
  reports and capabilities. The old ones overflowed horizontally.
- **Dashboard**: stat cards no longer overflow on small phones, the header
  wraps, and bottom sheets stay above the keyboard and nav bar.
- **Contact Us** saves to the Firestore collection `contact_messages`, and
  Contact Messages shows them live with read/unread.
- **Plant cards** open the Plant Detail page.
- **Login and Register**:
  - back button
  - "Continue as guest"
  - show/hide password
  - email validation
  - correct keyboards
  - returns to the page that asked you to log in
- **Health Monitor**: pull-to-refresh can't corrupt the list while an
  analysis is still running.
- **Android**: added the `INTERNET` permission (release APKs had no network)
  and `usesCleartextTraffic`, because the ML server uses http.

## Firestore rules to check
- `contact_messages`: anyone can create; researchers can read and update.
- `users/{uid}`: the owner can update `username`, `contact`, `province` and
  `country`. The Edit Profile sheet needs this.
