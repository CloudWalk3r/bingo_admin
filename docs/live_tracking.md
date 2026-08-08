# Live Tracking

Shared real-time driver location feature between:

- **Mobile** (`E:\Projects\BinGo`) – drivers publish GPS while On Duty.
- **Admin** (`E:\Projects\bingo_admin`) – shows a live map of all drivers currently sharing.

Both apps target the same Firebase project (`bingo-cef6d`) and use its
**Realtime Database** for live positions.

---

## Firebase Realtime Database schema

Path: `Driver_Live_Location/{safeEmail}`

`safeEmail` is derived from the driver's email via
`email.trim().replaceAll('.', '_')` (see `AppTheme.safeEmail` in the mobile app).

```json
"Driver_Live_Location": {
  "driver_one_gmail_com": {
    "Driver_Email": "driver.one@gmail.com",
    "Driver_Name":  "Driver One",
    "Lat":          6.0531,
    "Lng":          80.5302,
    "Accuracy":     6.4,
    "Heading":      142.0,
    "Speed":        3.8,
    "Status":       "Online",           // "Online" | "Offline"
    "Started_At":   1711111111111,      // ms epoch (server timestamp)
    "Updated_At":   1711111113456       // ms epoch (server timestamp)
  }
}
```

### Lifecycle

1. Driver opens the mobile app → `Dri_Home.dart` → taps the duty pill.
2. `DriverLocationService.start()`:
   - Checks location permission + GPS enabled.
   - Writes an initial snapshot and registers an `onDisconnect` handler
     that marks the driver `Offline` if the app/network dies.
   - Subscribes to `Geolocator.getPositionStream` with
     `accuracy: high, distanceFilter: 25` and writes each update.
3. Driver taps pill again (or logs out) → `DriverLocationService.stop()`
   cancels the stream and writes `Status: Offline`.
4. Admin's `LiveTrackingScreen` listens to `Driver_Live_Location` and
   renders markers. "Stale" (>60s since last update) drivers are dimmed.

---

## Recommended Realtime Database security rules

Add or merge these into your RTDB rules. Adjust the admin gate once a
dedicated auth module exists in the admin web app.

```json
{
  "rules": {
    "Driver_Live_Location": {
      ".read": "auth != null",
      "$safeEmail": {
        ".write": "auth != null && auth.token.email != null && auth.token.email.replace('.', '_') == $safeEmail",
        ".validate": "newData.hasChildren(['Lat','Lng','Status','Updated_At'])",
        "Lat":        { ".validate": "newData.isNumber() && newData.val() >= -90  && newData.val() <= 90" },
        "Lng":        { ".validate": "newData.isNumber() && newData.val() >= -180 && newData.val() <= 180" },
        "Accuracy":   { ".validate": "newData.isNumber()" },
        "Heading":    { ".validate": "newData.isNumber()" },
        "Speed":      { ".validate": "newData.isNumber()" },
        "Status":     { ".validate": "newData.isString()" },
        "Driver_Name":{ ".validate": "newData.isString()" },
        "Driver_Email":{".validate": "newData.isString()" },
        "Started_At": { ".validate": "newData.isNumber()" },
        "Updated_At": { ".validate": "newData.isNumber()" },
        "$other":     { ".validate": false }
      }
    }
  }
}
```

> Note: the current admin app has no auth layer, so `".read": "auth != null"`
> will block it until admin auth is added. For local development you can
> temporarily loosen the read rule to `true` — do **not** ship that to prod.

---

## Platform permissions (mobile)

- **Android** (`android/app/src/main/AndroidManifest.xml`):
  - `android.permission.INTERNET`
  - `android.permission.ACCESS_FINE_LOCATION`
  - `android.permission.ACCESS_COARSE_LOCATION`
- **iOS** (`ios/Runner/Info.plist`):
  - `NSLocationWhenInUseUsageDescription`
  - `NSLocationAlwaysAndWhenInUseUsageDescription`

Background tracking is intentionally **not** enabled in v1 — the service
only publishes while the app is in the foreground, keeping battery and
permission complexity low.

---

## Extending later

- Persist a per-shift polyline (write each point to a capped list for a
  "today's trail" view in admin).
- Add a dedicated admin auth module and tighten RTDB read rule to
  `auth.token.admin == true` via custom claims.
- Switch to a background foreground-service so tracking survives the
  driver switching apps (requires `flutter_background_service` or
  `geolocator` with `foregroundService` on Android).
