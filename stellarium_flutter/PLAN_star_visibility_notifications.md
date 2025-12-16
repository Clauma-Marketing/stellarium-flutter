# Star Visibility Notification Feature - Implementation Plan

## Overview
Send users a push notification when their saved stars become visible above the horizon. The notification should be sent once per day when the star rises, considering both the star's position and darkness conditions (astronomical twilight).

## Architecture Decision

### Option A: Local Notifications with Background Tasks (Recommended)
- Use `flutter_local_notifications` for scheduling notifications
- Use `workmanager` for periodic background calculations
- All calculations done on-device
- Works offline, no server dependency
- Battery-efficient with daily/hourly checks

### Option B: Server-Side Push via Firebase Cloud Functions
- Server calculates visibility for all users
- Sends push via FCM/Klaviyo
- Requires backend infrastructure
- More complex, but can be more reliable

**Recommendation: Option A** - Local notifications are simpler, work offline, and don't require server infrastructure.

---

## Implementation Steps

### Phase 1: Core Infrastructure

#### 1.1 Add Dependencies
```yaml
# pubspec.yaml
dependencies:
  flutter_local_notifications: ^18.0.1
  workmanager: ^0.5.2
  timezone: ^0.9.4
```

#### 1.2 Create Star Visibility Calculator
**File:** `lib/utils/star_visibility.dart`

```dart
class StarVisibility {
  /// Calculate when a star rises above the horizon for a given location and date
  /// Returns DateTime of rise time, or null if star doesn't rise (circumpolar below)
  static DateTime? getStarRiseTime({
    required double starRa,      // Right ascension in degrees
    required double starDec,     // Declination in degrees
    required double latitude,    // Observer latitude in degrees
    required double longitude,   // Observer longitude in degrees
    required DateTime date,
  });

  /// Calculate when a star sets below the horizon
  static DateTime? getStarSetTime({...});

  /// Check if star is currently above horizon
  static bool isAboveHorizon({
    required double starRa,
    required double starDec,
    required double latitude,
    required double longitude,
    required DateTime dateTime,
  });

  /// Check if star is visible (above horizon AND dark enough)
  static bool isVisible({
    required double starRa,
    required double starDec,
    required double latitude,
    required double longitude,
    required DateTime dateTime,
  });

  /// Get the best viewing window for tonight
  /// Returns (start, end) DateTime pair when star is visible in darkness
  static (DateTime?, DateTime?) getTonightViewingWindow({
    required double starRa,
    required double starDec,
    required double latitude,
    required double longitude,
    required DateTime date,
  });
}
```

**Algorithm:**
1. Convert RA/Dec to Hour Angle using Local Sidereal Time
2. Calculate altitude using: `sin(alt) = sin(lat)*sin(dec) + cos(lat)*cos(dec)*cos(HA)`
3. Find when altitude crosses 0° (horizon)
4. Cross-reference with astronomical twilight times from `SunTimes`

#### 1.3 Create Notification Service
**File:** `lib/services/star_notification_service.dart`

```dart
class StarNotificationService {
  static final instance = StarNotificationService._();

  /// Initialize the notification system
  Future<void> initialize();

  /// Schedule notifications for all saved stars
  Future<void> scheduleAllStarNotifications();

  /// Schedule notification for a single star
  Future<void> scheduleStarNotification(SavedStar star);

  /// Cancel notification for a star
  Future<void> cancelStarNotification(String starId);

  /// Cancel all star notifications
  Future<void> cancelAllNotifications();

  /// Handle notification tap (navigate to star)
  void onNotificationTap(String starId);
}
```

---

### Phase 2: Background Task System

#### 2.1 Configure WorkManager
**File:** `lib/services/background_service.dart`

```dart
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'calculateStarVisibility':
        await _calculateAndScheduleNotifications();
        return true;
      default:
        return false;
    }
  });
}

class BackgroundService {
  /// Register periodic background task (runs every 6-12 hours)
  static Future<void> registerPeriodicTask();

  /// Run immediate calculation
  static Future<void> runImmediateCalculation();
}
```

#### 2.2 Background Calculation Flow
1. Load saved stars from SharedPreferences
2. Get user location from OnboardingService
3. For each star with RA/Dec coordinates:
   - Calculate tonight's viewing window
   - If star will be visible, schedule local notification
4. Store last calculation time to avoid duplicates

---

### Phase 3: Notification Preferences

#### 3.1 Add User Settings
**File:** `lib/services/notification_preferences.dart`

```dart
class NotificationPreferences {
  /// Enable/disable star visibility notifications
  static Future<void> setStarNotificationsEnabled(bool enabled);
  static Future<bool> getStarNotificationsEnabled();

  /// Set preferred notification time (e.g., 30 min before visible)
  static Future<void> setNotificationLeadTime(Duration leadTime);

  /// Set quiet hours (don't notify between these times)
  static Future<void> setQuietHours(TimeOfDay start, TimeOfDay end);

  /// Per-star notification enable/disable
  static Future<void> setStarNotificationEnabled(String starId, bool enabled);
}
```

#### 3.2 Update SavedStar Model
Add notification preference field:
```dart
class SavedStar {
  // ... existing fields
  final bool notificationsEnabled; // Default: true
}
```

---

### Phase 4: UI Integration

#### 4.1 Settings Panel Addition
Add toggle in Settings for "Star Visibility Notifications"

#### 4.2 Star Info Sheet Addition
Add toggle per-star: "Notify when visible"

#### 4.3 My Stars List Enhancement
Show next visibility time for each star:
- "Visible tonight at 21:34"
- "Currently visible"
- "Not visible tonight"

---

### Phase 5: Platform Configuration

#### 5.1 Android Configuration
```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>

<!-- WorkManager initialization -->
<provider
    android:name="androidx.startup.InitializationProvider"
    ...
/>
```

#### 5.2 iOS Configuration
```swift
// AppDelegate.swift
// Request notification permissions
// Configure background fetch
```

---

## Data Flow

```
User saves star
       ↓
SavedStarsService.saveStar()
       ↓
StarNotificationService.scheduleStarNotification()
       ↓
Calculate rise time for today/tomorrow
       ↓
Schedule local notification at (rise_time - lead_time)
       ↓
[Background: WorkManager runs every 6-12 hours]
       ↓
Recalculate and reschedule all notifications
       ↓
User receives notification → Taps → App opens → Points at star
```

---

## Notification Content

**Title:** "🌟 {Star Name} is rising!"

**Body:** "Your star is now visible in the {direction} sky. Best viewing until {set_time}."

**Example:**
- Title: "🌟 Polaris is rising!"
- Body: "Your star is now visible in the northern sky. Best viewing until 05:23."

**Action on tap:** Open app and point at the star

---

## Edge Cases to Handle

1. **Circumpolar stars** (never set at user's latitude)
   - Notify at astronomical twilight start instead

2. **Stars that never rise** (always below horizon)
   - Don't schedule notification, show "Not visible from your location"

3. **Location changes**
   - Recalculate when location permission updates
   - Recalculate when user manually changes location

4. **Time zone changes**
   - Use UTC internally, convert for display

5. **Multiple stars rising at same time**
   - Group into single notification: "3 of your stars are now visible"

6. **App not opened for days**
   - WorkManager handles this, recalculates on next run

---

## Files to Create/Modify

### New Files:
1. `lib/utils/star_visibility.dart` - Visibility calculations
2. `lib/services/star_notification_service.dart` - Notification scheduling
3. `lib/services/background_service.dart` - WorkManager setup
4. `lib/services/notification_preferences.dart` - User preferences

### Modified Files:
1. `pubspec.yaml` - Add dependencies
2. `lib/main.dart` - Initialize services
3. `lib/services/saved_stars_service.dart` - Add notification field
4. `lib/widgets/star_info_sheet.dart` - Add notification toggle
5. `lib/widgets/settings_panel.dart` - Add notification settings
6. `lib/screens/my_stars_screen.dart` - Show visibility times
7. `android/app/src/main/AndroidManifest.xml` - Permissions
8. `ios/Runner/AppDelegate.swift` - iOS notification setup

---

## Testing Checklist

- [ ] Star rises and notification fires at correct time
- [ ] Notification tap opens app and points at star
- [ ] Background task runs when app is closed
- [ ] Notifications respect quiet hours
- [ ] Per-star notification toggle works
- [ ] Global notification toggle works
- [ ] Circumpolar stars handled correctly
- [ ] Location change triggers recalculation
- [ ] Multiple stars grouped in notification
- [ ] Works after device reboot
- [ ] Battery usage is acceptable

---

## Estimated Effort

| Phase | Description | Estimate |
|-------|-------------|----------|
| 1 | Core Infrastructure | Medium |
| 2 | Background Tasks | Medium |
| 3 | Preferences | Small |
| 4 | UI Integration | Small |
| 5 | Platform Config | Small |
| - | Testing & Polish | Medium |

---

## Dependencies Summary

```yaml
flutter_local_notifications: ^18.0.1  # Local notification scheduling
workmanager: ^0.5.2                   # Background task execution
timezone: ^0.9.4                      # Timezone-aware scheduling
```
