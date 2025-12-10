import 'dart:math' as math;
import 'sun_times.dart';

/// Calculates star rise/set times and visibility for a given location.
/// Uses spherical astronomy algorithms to determine when celestial objects
/// cross the horizon.
class StarVisibility {
  static const double _deg2rad = math.pi / 180.0;
  static const double _rad2deg = 180.0 / math.pi;

  /// Minimum altitude for practical star observation.
  /// Set to 10 degrees above horizon to account for:
  /// - Atmospheric extinction (stars dim significantly near horizon)
  /// - Typical obstructions (trees, buildings)
  /// - Better viewing conditions
  static const double _horizonAltitude = 10.0; // degrees

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
    // A star is circumpolar if its minimum altitude is above the horizon.
    // Minimum altitude occurs when the star is at lower culmination.
    //
    // For Northern Hemisphere (lat > 0):
    //   Star with positive dec is circumpolar if dec > (90 - lat)
    //   Minimum altitude = dec - (90 - lat) = dec + lat - 90
    //
    // For Southern Hemisphere (lat < 0):
    //   Star with negative dec is circumpolar if dec < -(90 + lat) = lat - 90
    //   Minimum altitude = -dec - (90 + lat) = -(dec + lat + 90)
    //
    // General formula: min altitude = |lat| + |dec| - 90 (when same sign)
    // or equivalently: circumpolar when |dec| > 90 - |lat| (same hemisphere)

    if (latitudeDeg >= 0) {
      // Northern hemisphere observer
      // Star is circumpolar if declination is high enough (positive)
      // min altitude when star is at lower culmination (north of zenith for circumpolar)
      final minAlt = starDecDeg - (90 - latitudeDeg);
      return minAlt > _horizonAltitude;
    } else {
      // Southern hemisphere observer
      // Star is circumpolar if declination is low enough (negative)
      // min altitude when star is at lower culmination (south of zenith for circumpolar)
      final minAlt = -starDecDeg - (90 + latitudeDeg);
      return minAlt > _horizonAltitude;
    }
  }

  /// Check if a star never rises at given latitude
  static bool neverRises({
    required double starDecDeg,
    required double latitudeDeg,
  }) {
    // A star never rises if its maximum altitude is below the horizon.
    // Maximum altitude = 90 - |lat - dec|
    //
    // For Northern Hemisphere (lat > 0):
    //   Stars with very negative declination never rise
    //   Never rises if dec < lat - 90
    //
    // For Southern Hemisphere (lat < 0):
    //   Stars with very positive declination never rise
    //   Never rises if dec > lat + 90

    if (latitudeDeg >= 0) {
      // Northern hemisphere - stars too far south never rise
      return starDecDeg < (latitudeDeg - 90 + _horizonAltitude);
    } else {
      // Southern hemisphere - stars too far north never rise
      return starDecDeg > (latitudeDeg + 90 - _horizonAltitude);
    }
  }

  /// Calculate when a star rises above the horizon for a given date
  /// Returns the DateTime of rise in local time, or null if star doesn't rise/set
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

    // Find the transit time (when star crosses meridian) - returns UTC
    final transitTimeUtc = _getTransitTime(
      starRaDeg: starRaDeg,
      longitudeDeg: longitudeDeg,
      date: date,
    );

    // Rise time is transit time minus hour angle (in hours)
    // Hour angle is in hours, so multiply by 60 for minutes
    final riseTimeUtc = transitTimeUtc.subtract(Duration(
      minutes: (hourAngle * 60).round(),
    ));

    // Convert to local time
    return riseTimeUtc.toLocal();
  }

  /// Calculate when a star sets below the horizon for a given date
  /// Returns the DateTime of set in local time, or null if star doesn't set
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

    // Get transit time in UTC
    final transitTimeUtc = _getTransitTime(
      starRaDeg: starRaDeg,
      longitudeDeg: longitudeDeg,
      date: date,
    );

    // Set time is transit time plus hour angle
    final setTimeUtc = transitTimeUtc.add(Duration(
      minutes: (hourAngle * 60).round(),
    ));

    // Convert to local time
    return setTimeUtc.toLocal();
  }

  /// Get the transit time (when star crosses the meridian) for a given date
  /// Returns time in UTC for consistent calculations
  static DateTime _getTransitTime({
    required double starRaDeg,
    required double longitudeDeg,
    required DateTime date,
  }) {
    // Calculate transit time using the standard formula
    // Transit occurs when Local Sidereal Time equals the star's Right Ascension

    // Convert star RA from degrees to hours
    final starRAHours = starRaDeg / 15.0;

    // Get Greenwich Mean Sidereal Time at 0h UT on the date
    final jd0 = _dateToJulianDate(DateTime.utc(date.year, date.month, date.day));
    final t = (jd0 - 2451545.0) / 36525.0;

    // GMST at 0h UT in hours (IAU 1982 formula)
    double gmst0h = 6.697374558 +
        2400.051336 * t +
        0.000025862 * t * t;
    gmst0h = gmst0h % 24;
    if (gmst0h < 0) gmst0h += 24;

    // Local Sidereal Time at 0h UT
    final lst0h = gmst0h + longitudeDeg / 15.0;

    // Hour angle at 0h UT (how far star is from meridian)
    double hourAngle = starRAHours - lst0h;

    // Normalize to find the time until transit (0 to 24 hours)
    while (hourAngle < 0) {
      hourAngle += 24;
    }
    while (hourAngle >= 24) {
      hourAngle -= 24;
    }

    // Convert sidereal hours to solar hours
    // Sidereal day = 23h 56m 4.091s = 23.9344696 hours
    // So 1 sidereal hour = 23.9344696/24 = 0.9972696 solar hours
    final solarHours = hourAngle * 0.9972696;

    // Return UTC time
    return DateTime.utc(date.year, date.month, date.day)
        .add(Duration(minutes: (solarHours * 60).round()));
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

      // Check if star sets before darkness even starts
      if (setTime != null && setTime.isBefore(darkStart)) {
        // Star has already set before it gets dark - check if it rises again tonight
        if (tomorrowRise != null && tomorrowRise.isAfter(darkStart)) {
          // Star rises during the night
          windowStart = tomorrowRise;
          windowEnd = morningTwilightStart ?? darkEnd;
        } else {
          // Star doesn't rise during the dark period
          return (null, null);
        }
      } else {
        // Normal case: star is up during some part of the night
        if (riseTime != null && riseTime.isAfter(darkStart)) {
          windowStart = riseTime;
        } else {
          // Star already up at darkness start, or rises before
          windowStart = darkStart;
        }

        if (setTime != null && setTime.isBefore(morningTwilightStart ?? darkEnd)) {
          windowEnd = setTime;
        } else {
          windowEnd = morningTwilightStart ?? darkEnd;
        }
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
      final (windowStart, _) = getTonightViewingWindow(
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

  /// Get the time when the star becomes non-visible and the reason why.
  /// Returns (endTime, reason) where reason is 'dawn', 'setting', or null if currently not visible.
  static (DateTime?, String?) getVisibilityEnd({
    required double starRaDeg,
    required double starDecDeg,
    required double latitudeDeg,
    required double longitudeDeg,
    DateTime? fromTime,
  }) {
    final now = fromTime ?? DateTime.now();

    // First check if the star is currently visible
    if (!isVisible(
      starRaDeg: starRaDeg,
      starDecDeg: starDecDeg,
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg,
      dateTime: now,
    )) {
      return (null, null);
    }

    // Get sun times for today and tomorrow
    final today = DateTime(now.year, now.month, now.day);
    final sunTimes = SunTimes(
      latitude: latitudeDeg,
      longitude: longitudeDeg,
      date: today,
    );
    final tomorrowSunTimes = SunTimes(
      latitude: latitudeDeg,
      longitude: longitudeDeg,
      date: today.add(const Duration(days: 1)),
    );

    // Get dawn time (astronomical twilight start)
    // If it's after midnight, use today's twilight start; otherwise tomorrow's
    DateTime? dawnTime;
    if (now.hour < 12) {
      // After midnight - dawn is today
      dawnTime = sunTimes.astronomicalTwilightStart;
    } else {
      // Before midnight - dawn is tomorrow
      dawnTime = tomorrowSunTimes.astronomicalTwilightStart;
    }

    // Get star set time
    DateTime? setTime;
    if (isCircumpolar(starDecDeg: starDecDeg, latitudeDeg: latitudeDeg)) {
      // Star never sets
      setTime = null;
    } else if (neverRises(starDecDeg: starDecDeg, latitudeDeg: latitudeDeg)) {
      // Star never rises - shouldn't happen if currently visible
      return (null, null);
    } else {
      // Get set time for today
      setTime = getStarSetTime(
        starRaDeg: starRaDeg,
        starDecDeg: starDecDeg,
        latitudeDeg: latitudeDeg,
        longitudeDeg: longitudeDeg,
        date: today,
      );

      // If set time is in the past, check tomorrow
      if (setTime != null && setTime.isBefore(now)) {
        setTime = getStarSetTime(
          starRaDeg: starRaDeg,
          starDecDeg: starDecDeg,
          latitudeDeg: latitudeDeg,
          longitudeDeg: longitudeDeg,
          date: today.add(const Duration(days: 1)),
        );
      }
    }

    // Determine which comes first: dawn or star setting
    if (setTime == null && dawnTime == null) {
      // Polar night with circumpolar star - visible indefinitely
      return (null, null);
    } else if (setTime == null) {
      // Circumpolar star - only dawn ends visibility
      return (dawnTime, 'dawn');
    } else if (dawnTime == null) {
      // No dawn (polar day shouldn't happen if visible) - only setting ends visibility
      return (setTime, 'setting');
    } else {
      // Both could end visibility - return the earlier one
      if (setTime.isBefore(dawnTime)) {
        return (setTime, 'setting');
      } else {
        return (dawnTime, 'dawn');
      }
    }
  }

  /// Get a human-readable description of when visibility ends
  static String? getVisibilityEndDescription({
    required double starRaDeg,
    required double starDecDeg,
    required double latitudeDeg,
    required double longitudeDeg,
    DateTime? fromTime,
  }) {
    final (endTime, reason) = getVisibilityEnd(
      starRaDeg: starRaDeg,
      starDecDeg: starDecDeg,
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg,
      fromTime: fromTime,
    );

    if (endTime == null) {
      return null;
    }

    final timeStr =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

    if (reason == 'dawn') {
      return 'Visible until $timeStr (dawn)';
    } else if (reason == 'setting') {
      return 'Visible until $timeStr (sets)';
    } else {
      return 'Visible until $timeStr';
    }
  }

  /// Format a time with day offset notation (e.g., "23:30", "05:30 (+1)")
  static String formatTimeWithDayOffset(DateTime time, DateTime referenceDate) {
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final refDay = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
    final timeDay = DateTime(time.year, time.month, time.day);
    final daysDiff = timeDay.difference(refDay).inDays;

    if (daysDiff == 0) {
      return timeStr;
    } else if (daysDiff == 1) {
      return '$timeStr (+1)';
    } else {
      return '$timeStr (+$daysDiff)';
    }
  }

  /// Get visibility info for display purposes.
  /// Returns a VisibilityInfo object with all the information needed for display.
  ///
  /// This is the single source of truth for visibility calculations used by both
  /// the star info sheet and the saved stars list.
  static VisibilityInfo getVisibilityInfo({
    required double starRaDeg,
    required double starDecDeg,
    required double latitudeDeg,
    required double longitudeDeg,
    DateTime? dateTime,
  }) {
    final now = dateTime ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check if star never rises at this location
    if (neverRises(starDecDeg: starDecDeg, latitudeDeg: latitudeDeg)) {
      return VisibilityInfo(
        isCurrentlyVisible: false,
        status: VisibilityStatus.neverVisible,
        statusText: 'Never visible',
      );
    }

    // Check if currently visible
    final currentlyVisible = isVisible(
      starRaDeg: starRaDeg,
      starDecDeg: starDecDeg,
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg,
      dateTime: now,
    );

    if (currentlyVisible) {
      // Get the end time for current visibility
      final (endTime, _) = getVisibilityEnd(
        starRaDeg: starRaDeg,
        starDecDeg: starDecDeg,
        latitudeDeg: latitudeDeg,
        longitudeDeg: longitudeDeg,
        fromTime: now,
      );

      String? endTimeStr;
      if (endTime != null) {
        endTimeStr = formatTimeWithDayOffset(endTime, today);
      }

      return VisibilityInfo(
        isCurrentlyVisible: true,
        status: VisibilityStatus.visibleNow,
        statusText: 'Visible now',
        startTime: now,
        startTimeStr: 'Now',
        endTime: endTime,
        endTimeStr: endTimeStr,
      );
    }

    // Not currently visible - check why and find next visibility
    final isAbove = isAboveHorizon(
      starRaDeg: starRaDeg,
      starDecDeg: starDecDeg,
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg,
      dateTime: now,
    );

    final isCircumpolarStar = isCircumpolar(
      starDecDeg: starDecDeg,
      latitudeDeg: latitudeDeg,
    );

    // Try today first, then tomorrow
    var (windowStart, windowEnd) = getTonightViewingWindow(
      starRaDeg: starRaDeg,
      starDecDeg: starDecDeg,
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg,
      date: today,
    );

    // If no window today or window already passed, try tomorrow
    if (windowStart == null || windowStart.isBefore(now)) {
      final tomorrow = today.add(const Duration(days: 1));
      final (tomorrowStart, tomorrowEnd) = getTonightViewingWindow(
        starRaDeg: starRaDeg,
        starDecDeg: starDecDeg,
        latitudeDeg: latitudeDeg,
        longitudeDeg: longitudeDeg,
        date: tomorrow,
      );
      if (tomorrowStart != null && tomorrowStart.isAfter(now)) {
        windowStart = tomorrowStart;
        windowEnd = tomorrowEnd;
      }
    }

    if (windowStart != null && windowStart.isAfter(now)) {
      // Found next visibility window
      final startTimeStr = formatTimeWithDayOffset(windowStart, today);
      String? endTimeStr;
      if (windowEnd != null) {
        endTimeStr = formatTimeWithDayOffset(windowEnd, today);
      }

      // Determine status text based on when visibility starts
      final diff = windowStart.difference(now);
      String statusText;
      if (windowStart.day == now.day) {
        statusText = 'Tonight $startTimeStr';
      } else if (diff.inHours < 24) {
        statusText = 'Tomorrow $startTimeStr';
      } else {
        statusText = '${diff.inDays}d ${diff.inHours % 24}h';
      }

      return VisibilityInfo(
        isCurrentlyVisible: false,
        status: VisibilityStatus.visibleLater,
        statusText: statusText,
        startTime: windowStart,
        startTimeStr: startTimeStr,
        endTime: windowEnd,
        endTimeStr: endTimeStr,
      );
    }

    // No visibility window found
    if (isCircumpolarStar) {
      // Circumpolar star - always above horizon, just need dark
      return VisibilityInfo(
        isCurrentlyVisible: false,
        status: VisibilityStatus.waitForDark,
        statusText: 'Wait for dark',
      );
    } else if (isAbove) {
      return VisibilityInfo(
        isCurrentlyVisible: false,
        status: VisibilityStatus.waitForDark,
        statusText: 'Wait for dark',
      );
    } else {
      return VisibilityInfo(
        isCurrentlyVisible: false,
        status: VisibilityStatus.belowHorizon,
        statusText: 'Below horizon',
      );
    }
  }
}

/// Enum representing the visibility status of a star
enum VisibilityStatus {
  visibleNow,
  visibleLater,
  waitForDark,
  belowHorizon,
  neverVisible,
}

/// Class containing visibility information for display
class VisibilityInfo {
  final bool isCurrentlyVisible;
  final VisibilityStatus status;
  final String statusText;
  final DateTime? startTime;
  final String? startTimeStr;
  final DateTime? endTime;
  final String? endTimeStr;

  const VisibilityInfo({
    required this.isCurrentlyVisible,
    required this.status,
    required this.statusText,
    this.startTime,
    this.startTimeStr,
    this.endTime,
    this.endTimeStr,
  });

  /// Returns a formatted string like "18:30 - 05:30 (+1)" or just the status text
  String get formattedWindow {
    if (startTimeStr != null && endTimeStr != null) {
      return '$startTimeStr - $endTimeStr';
    } else if (startTimeStr != null) {
      return startTimeStr!;
    }
    return statusText;
  }
}
