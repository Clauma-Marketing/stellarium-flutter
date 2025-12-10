import 'dart:math' as math;
import 'sun_times.dart';

/// Calculates star rise/set times and visibility for a given location.
/// Uses spherical astronomy algorithms to determine when celestial objects
/// cross the horizon.
class StarVisibility {
  static const double _deg2rad = math.pi / 180.0;
  static const double _rad2deg = 180.0 / math.pi;

  /// Horizon altitude threshold (slightly below 0 to account for refraction)
  static const double _horizonAltitude = -0.5667; // degrees

  /// Calculate Local Sidereal Time (LST) in degrees
  /// LST is the right ascension currently on the meridian
  static double _getLocalSiderealTime(DateTime utcTime, double longitudeDeg) {
    // Julian Date
    final jd = _dateToJulianDate(utcTime);

    // Julian centuries from J2000.0
    final t = (jd - 2451545.0) / 36525.0;

    // Greenwich Mean Sidereal Time in degrees
    double gmst = 280.46061837 +
        360.98564736629 * (jd - 2451545.0) +
        0.000387933 * t * t -
        t * t * t / 38710000.0;

    // Normalize to 0-360
    gmst = gmst % 360.0;
    if (gmst < 0) gmst += 360.0;

    // Local Sidereal Time
    double lst = gmst + longitudeDeg;
    lst = lst % 360.0;
    if (lst < 0) lst += 360.0;

    return lst;
  }

  /// Convert DateTime to Julian Date
  static double _dateToJulianDate(DateTime dt) {
    final utc = dt.toUtc();
    final year = utc.year;
    final month = utc.month;
    final day = utc.day +
        utc.hour / 24.0 +
        utc.minute / 1440.0 +
        utc.second / 86400.0 +
        utc.millisecond / 86400000.0;

    final a = (14 - month) ~/ 12;
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;

    return day +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045;
  }

  /// Calculate the altitude of a star at a given time
  /// Returns altitude in degrees
  static double getStarAltitude({
    required double starRaDeg,
    required double starDecDeg,
    required double latitudeDeg,
    required double longitudeDeg,
    required DateTime dateTime,
  }) {
    final lst = _getLocalSiderealTime(dateTime.toUtc(), longitudeDeg);

    // Hour angle in degrees
    double ha = lst - starRaDeg;
    // Normalize to -180 to +180
    while (ha > 180) {
      ha -= 360;
    }
    while (ha < -180) {
      ha += 360;
    }

    final haRad = ha * _deg2rad;
    final decRad = starDecDeg * _deg2rad;
    final latRad = latitudeDeg * _deg2rad;

    // Calculate altitude using spherical trigonometry
    final sinAlt = math.sin(latRad) * math.sin(decRad) +
        math.cos(latRad) * math.cos(decRad) * math.cos(haRad);

    return math.asin(sinAlt.clamp(-1.0, 1.0)) * _rad2deg;
  }

  /// Calculate the azimuth of a star at a given time
  /// Returns azimuth in degrees (0 = North, 90 = East)
  static double getStarAzimuth({
    required double starRaDeg,
    required double starDecDeg,
    required double latitudeDeg,
    required double longitudeDeg,
    required DateTime dateTime,
  }) {
    final lst = _getLocalSiderealTime(dateTime.toUtc(), longitudeDeg);

    double ha = lst - starRaDeg;
    while (ha > 180) {
      ha -= 360;
    }
    while (ha < -180) {
      ha += 360;
    }

    final haRad = ha * _deg2rad;
    final decRad = starDecDeg * _deg2rad;
    final latRad = latitudeDeg * _deg2rad;

    final sinAlt = math.sin(latRad) * math.sin(decRad) +
        math.cos(latRad) * math.cos(decRad) * math.cos(haRad);
    final alt = math.asin(sinAlt.clamp(-1.0, 1.0));

    final cosAz =
        (math.sin(decRad) - math.sin(latRad) * math.sin(alt)) /
        (math.cos(latRad) * math.cos(alt));

    double az = math.acos(cosAz.clamp(-1.0, 1.0)) * _rad2deg;

    // Adjust for quadrant
    if (math.sin(haRad) > 0) {
      az = 360 - az;
    }

    return az;
  }

  /// Check if a star is currently above the horizon
  static bool isAboveHorizon({
    required double starRaDeg,
    required double starDecDeg,
    required double latitudeDeg,
    required double longitudeDeg,
    required DateTime dateTime,
  }) {
    final altitude = getStarAltitude(
      starRaDeg: starRaDeg,
      starDecDeg: starDecDeg,
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg,
      dateTime: dateTime,
    );
    return altitude > _horizonAltitude;
  }

  /// Check if it's dark enough to see stars (astronomical twilight)
  static bool isDarkEnough({
    required double latitudeDeg,
    required double longitudeDeg,
    required DateTime dateTime,
  }) {
    final sunTimes = SunTimes(
      latitude: latitudeDeg,
      longitude: longitudeDeg,
      date: dateTime,
    );

    // Check if we're in astronomical twilight or darker
    final astroStart = sunTimes.astronomicalTwilightEnd;
    final astroEnd = sunTimes.astronomicalTwilightStart;

    if (astroStart == null || astroEnd == null) {
      // Polar day/night - check sun position directly
      return sunTimes.isPolarNight;
    }

    final time = dateTime;

    // Night is between astronomical twilight end (evening) and start (morning)
    if (astroStart.isBefore(astroEnd)) {
      // Normal case: night spans midnight
      return time.isAfter(astroStart) || time.isBefore(astroEnd);
    } else {
      // Summer near poles: night is a short period
      return time.isAfter(astroStart) && time.isBefore(astroEnd);
    }
  }

  /// Check if a star is visible (above horizon AND dark enough)
  static bool isVisible({
    required double starRaDeg,
    required double starDecDeg,
    required double latitudeDeg,
    required double longitudeDeg,
    required DateTime dateTime,
  }) {
    return isAboveHorizon(
          starRaDeg: starRaDeg,
          starDecDeg: starDecDeg,
          latitudeDeg: latitudeDeg,
          longitudeDeg: longitudeDeg,
          dateTime: dateTime,
        ) &&
        isDarkEnough(
          latitudeDeg: latitudeDeg,
          longitudeDeg: longitudeDeg,
          dateTime: dateTime,
        );
  }

  /// Calculate the hour angle when a star crosses a given altitude
  /// Returns hour angle in hours, or null if star never reaches that altitude
  static double? _getHourAngleForAltitude(
    double altitudeDeg,
    double starDecDeg,
    double latitudeDeg,
  ) {
    final altRad = altitudeDeg * _deg2rad;
    final decRad = starDecDeg * _deg2rad;
    final latRad = latitudeDeg * _deg2rad;

    final cosH = (math.sin(altRad) - math.sin(latRad) * math.sin(decRad)) /
        (math.cos(latRad) * math.cos(decRad));

    // Check if star reaches this altitude
    if (cosH > 1.0) {
      // Star never rises above this altitude (always too low)
      return null;
    }
    if (cosH < -1.0) {
      // Star is always above this altitude (circumpolar)
      return null;
    }

    // Hour angle in degrees, convert to hours
    return math.acos(cosH) * _rad2deg / 15.0;
  }

  /// Check if a star is circumpolar (never sets) at given latitude
  static bool isCircumpolar({
    required double starDecDeg,
    required double latitudeDeg,
  }) {
    // Star is circumpolar if its declination is high enough
    // that it never dips below the horizon
    final minAlt = starDecDeg + latitudeDeg - 90;
    return minAlt > _horizonAltitude;
  }

  /// Check if a star never rises at given latitude
  static bool neverRises({
    required double starDecDeg,
    required double latitudeDeg,
  }) {
    // Star never rises if its maximum altitude is below horizon
    final maxAlt = 90 - (latitudeDeg - starDecDeg).abs();
    return maxAlt < _horizonAltitude;
  }

  /// Calculate when a star rises above the horizon for a given date
  /// Returns the DateTime of rise, or null if star doesn't rise
  static DateTime? getStarRiseTime({
    required double starRaDeg,
    required double starDecDeg,
    required double latitudeDeg,
    required double longitudeDeg,
    required DateTime date,
  }) {
    // Check if star ever rises
    if (neverRises(starDecDeg: starDecDeg, latitudeDeg: latitudeDeg)) {
      return null;
    }

    // If circumpolar, return null (star is always up)
    if (isCircumpolar(starDecDeg: starDecDeg, latitudeDeg: latitudeDeg)) {
      return null;
    }

    final hourAngle =
        _getHourAngleForAltitude(_horizonAltitude, starDecDeg, latitudeDeg);
    if (hourAngle == null) return null;

    // Rise happens at negative hour angle (before transit)

    // Find the transit time (when star crosses meridian)
    final transitTime = _getTransitTime(
      starRaDeg: starRaDeg,
      longitudeDeg: longitudeDeg,
      date: date,
    );

    // Rise time is transit time minus hour angle (in hours)
    final riseTime = transitTime.subtract(Duration(
      minutes: (hourAngle * 60).round(),
    ));

    // Make sure we return a time on the requested date
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    if (riseTime.isBefore(startOfDay)) {
      // Try next day's rise
      return getStarRiseTime(
        starRaDeg: starRaDeg,
        starDecDeg: starDecDeg,
        latitudeDeg: latitudeDeg,
        longitudeDeg: longitudeDeg,
        date: date.add(const Duration(days: 1)),
      );
    }

    if (riseTime.isAfter(endOfDay)) {
      return null; // Rise is on next day
    }

    return riseTime;
  }

  /// Calculate when a star sets below the horizon for a given date
  static DateTime? getStarSetTime({
    required double starRaDeg,
    required double starDecDeg,
    required double latitudeDeg,
    required double longitudeDeg,
    required DateTime date,
  }) {
    if (neverRises(starDecDeg: starDecDeg, latitudeDeg: latitudeDeg)) {
      return null;
    }

    if (isCircumpolar(starDecDeg: starDecDeg, latitudeDeg: latitudeDeg)) {
      return null;
    }

    final hourAngle =
        _getHourAngleForAltitude(_horizonAltitude, starDecDeg, latitudeDeg);
    if (hourAngle == null) return null;

    final transitTime = _getTransitTime(
      starRaDeg: starRaDeg,
      longitudeDeg: longitudeDeg,
      date: date,
    );

    // Set time is transit time plus hour angle
    final setTime = transitTime.add(Duration(
      minutes: (hourAngle * 60).round(),
    ));

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    if (setTime.isBefore(startOfDay) || setTime.isAfter(endOfDay)) {
      return null;
    }

    return setTime;
  }

  /// Get the transit time (when star crosses the meridian) for a given date
  static DateTime _getTransitTime({
    required double starRaDeg,
    required double longitudeDeg,
    required DateTime date,
  }) {
    // Start at noon UTC on the given date
    final noon = DateTime.utc(date.year, date.month, date.day, 12, 0, 0);

    // LST at noon
    final lstAtNoon = _getLocalSiderealTime(noon, longitudeDeg);

    // How many degrees until the star transits?
    double degreesToTransit = starRaDeg - lstAtNoon;
    while (degreesToTransit < -180) {
      degreesToTransit += 360;
    }
    while (degreesToTransit > 180) {
      degreesToTransit -= 360;
    }

    // Convert degrees to time (360 degrees = 24 hours = 1440 minutes)
    // But sidereal day is ~23h 56m, so 360 deg = 1436.07 minutes sidereal
    final minutesToTransit = degreesToTransit * (1436.07 / 360.0);

    return noon.add(Duration(minutes: minutesToTransit.round())).toLocal();
  }

  /// Get the viewing window for tonight when star is both visible and dark
  /// Returns (start, end) times, or (null, null) if not visible tonight
  static (DateTime?, DateTime?) getTonightViewingWindow({
    required double starRaDeg,
    required double starDecDeg,
    required double latitudeDeg,
    required double longitudeDeg,
    required DateTime date,
  }) {
    final sunTimes = SunTimes(
      latitude: latitudeDeg,
      longitude: longitudeDeg,
      date: date,
    );

    // Get darkness window (astronomical twilight)
    final darkStart = sunTimes.astronomicalTwilightEnd;
    final darkEnd = sunTimes.astronomicalTwilightStart;

    if (darkStart == null || darkEnd == null) {
      // No astronomical darkness (polar summer)
      return (null, null);
    }

    // For tonight, darkness is from this evening's twilight end
    // to tomorrow morning's twilight start
    final tomorrowSunTimes = SunTimes(
      latitude: latitudeDeg,
      longitude: longitudeDeg,
      date: date.add(const Duration(days: 1)),
    );
    final morningTwilightStart = tomorrowSunTimes.astronomicalTwilightStart;

    DateTime? windowStart;
    DateTime? windowEnd;

    // Check if star is circumpolar
    if (isCircumpolar(starDecDeg: starDecDeg, latitudeDeg: latitudeDeg)) {
      // Star is always up, so window is just the dark period
      windowStart = darkStart;
      windowEnd = morningTwilightStart ?? darkEnd;
    } else if (neverRises(starDecDeg: starDecDeg, latitudeDeg: latitudeDeg)) {
      // Star never rises
      return (null, null);
    } else {
      // Get rise and set times
      final riseTime = getStarRiseTime(
        starRaDeg: starRaDeg,
        starDecDeg: starDecDeg,
        latitudeDeg: latitudeDeg,
        longitudeDeg: longitudeDeg,
        date: date,
      );

      final setTime = getStarSetTime(
        starRaDeg: starRaDeg,
        starDecDeg: starDecDeg,
        latitudeDeg: latitudeDeg,
        longitudeDeg: longitudeDeg,
        date: date,
      );

      // Also check tomorrow for rise/set
      final tomorrowRise = getStarRiseTime(
        starRaDeg: starRaDeg,
        starDecDeg: starDecDeg,
        latitudeDeg: latitudeDeg,
        longitudeDeg: longitudeDeg,
        date: date.add(const Duration(days: 1)),
      );

      // Determine visibility window
      // Window start is the later of: darkness start, star rise
      // Window end is the earlier of: dawn, star set

      if (riseTime != null && riseTime.isAfter(darkStart)) {
        windowStart = riseTime;
      } else {
        // Star already up at darkness start, or rises before
        windowStart = darkStart;
      }

      if (setTime != null && setTime.isBefore(morningTwilightStart ?? darkEnd)) {
        windowEnd = setTime;
      } else if (tomorrowRise != null &&
          tomorrowRise.isBefore(morningTwilightStart ?? darkEnd)) {
        // Star sets and rises again before dawn
        windowEnd = morningTwilightStart ?? darkEnd;
      } else {
        windowEnd = morningTwilightStart ?? darkEnd;
      }

      // Validate window
      if (windowEnd.isBefore(windowStart)) {
        return (null, null);
      }
    }

    return (windowStart, windowEnd);
  }

  /// Get azimuth direction as a human-readable string
  static String getDirectionName(double azimuthDeg) {
    final directions = [
      'north',
      'northeast',
      'east',
      'southeast',
      'south',
      'southwest',
      'west',
      'northwest',
    ];
    final index = ((azimuthDeg + 22.5) % 360 / 45).floor();
    return directions[index];
  }

  /// Get the next time when star becomes visible (rises into dark sky)
  /// This is what we use for scheduling notifications
  static DateTime? getNextVisibilityStart({
    required double starRaDeg,
    required double starDecDeg,
    required double latitudeDeg,
    required double longitudeDeg,
    DateTime? fromTime,
  }) {
    final now = fromTime ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check today and the next few days
    for (int dayOffset = 0; dayOffset < 3; dayOffset++) {
      final checkDate = today.add(Duration(days: dayOffset));
      final (windowStart, windowEnd) = getTonightViewingWindow(
        starRaDeg: starRaDeg,
        starDecDeg: starDecDeg,
        latitudeDeg: latitudeDeg,
        longitudeDeg: longitudeDeg,
        date: checkDate,
      );

      if (windowStart != null && windowStart.isAfter(now)) {
        return windowStart;
      }
    }

    return null;
  }
}
