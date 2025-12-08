import 'dart:math' as math;

/// Calculates sunrise, sunset, and twilight times for a given location and date.
/// Based on NOAA solar calculator algorithms.
class SunTimes {
  /// Sun angles for different events (in degrees)
  static const double sunriseAngle = -0.833; // Accounts for refraction and sun size
  static const double civilTwilightAngle = -6.0;
  static const double nauticalTwilightAngle = -12.0;
  static const double astronomicalTwilightAngle = -18.0;

  final double latitude; // in degrees
  final double longitude; // in degrees
  final DateTime date;

  late final double _julianDay;
  late final double _julianCentury;
  late final double _solarNoonLST;
  late final double _sunDeclinationRad;
  late final double _eqOfTime;

  SunTimes({
    required this.latitude,
    required this.longitude,
    required this.date,
  }) {
    _calculate();
  }

  void _calculate() {
    // Julian Day
    final year = date.year;
    final month = date.month;
    final day = date.day;

    final a = (14 - month) ~/ 12;
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;

    _julianDay = day +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045 +
        0.5; // Noon

    // Julian Century
    _julianCentury = (_julianDay - 2451545.0) / 36525.0;

    // Geometric Mean Longitude of Sun (degrees)
    final geomMeanLongSun =
        (280.46646 + _julianCentury * (36000.76983 + 0.0003032 * _julianCentury)) % 360;

    // Geometric Mean Anomaly of Sun (degrees)
    final geomMeanAnomalySun =
        357.52911 + _julianCentury * (35999.05029 - 0.0001537 * _julianCentury);

    // Eccentricity of Earth's Orbit
    final eccentEarthOrbit =
        0.016708634 - _julianCentury * (0.000042037 + 0.0000001267 * _julianCentury);

    // Sun Equation of Center
    final sunEqOfCtr = math.sin(_toRadians(geomMeanAnomalySun)) *
            (1.914602 - _julianCentury * (0.004817 + 0.000014 * _julianCentury)) +
        math.sin(_toRadians(2 * geomMeanAnomalySun)) *
            (0.019993 - 0.000101 * _julianCentury) +
        math.sin(_toRadians(3 * geomMeanAnomalySun)) * 0.000289;

    // Sun True Longitude (degrees)
    final sunTrueLong = geomMeanLongSun + sunEqOfCtr;

    // Sun Apparent Longitude (degrees)
    final sunAppLong = sunTrueLong -
        0.00569 -
        0.00478 * math.sin(_toRadians(125.04 - 1934.136 * _julianCentury));

    // Mean Obliquity of Ecliptic (degrees)
    final meanObliqEcliptic = 23 +
        (26 +
                ((21.448 -
                        _julianCentury *
                            (46.8150 +
                                _julianCentury *
                                    (0.00059 - _julianCentury * 0.001813)))) /
                    60) /
            60;

    // Obliquity Correction (degrees)
    final obliqCorr = meanObliqEcliptic +
        0.00256 * math.cos(_toRadians(125.04 - 1934.136 * _julianCentury));

    // Sun Declination (radians)
    _sunDeclinationRad = math.asin(
        math.sin(_toRadians(obliqCorr)) * math.sin(_toRadians(sunAppLong)));

    // Var Y
    final varY = math.tan(_toRadians(obliqCorr / 2)) *
        math.tan(_toRadians(obliqCorr / 2));

    // Equation of Time (minutes)
    _eqOfTime = 4 *
        _toDegrees(varY * math.sin(2 * _toRadians(geomMeanLongSun)) -
            2 * eccentEarthOrbit * math.sin(_toRadians(geomMeanAnomalySun)) +
            4 *
                eccentEarthOrbit *
                varY *
                math.sin(_toRadians(geomMeanAnomalySun)) *
                math.cos(2 * _toRadians(geomMeanLongSun)) -
            0.5 * varY * varY * math.sin(4 * _toRadians(geomMeanLongSun)) -
            1.25 *
                eccentEarthOrbit *
                eccentEarthOrbit *
                math.sin(2 * _toRadians(geomMeanAnomalySun)));

    // Solar Noon (LST - Local Solar Time in minutes from midnight)
    _solarNoonLST = 720 - 4 * longitude - _eqOfTime;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
  double _toDegrees(double radians) => radians * 180 / math.pi;

  /// Calculate the time of a solar event for a given sun angle.
  /// Returns minutes from midnight (local solar time), or null if the event doesn't occur.
  double? _getSunEventTime(double sunAngleDegs, bool isSunrise) {
    final latRad = _toRadians(latitude);

    // Hour Angle (degrees)
    final cosHourAngle = (math.cos(_toRadians(90.833 + sunAngleDegs + 0.833)) -
            math.sin(latRad) * math.sin(_sunDeclinationRad)) /
        (math.cos(latRad) * math.cos(_sunDeclinationRad));

    // Check if sun event occurs (polar day/night)
    if (cosHourAngle > 1 || cosHourAngle < -1) {
      return null;
    }

    final hourAngle = _toDegrees(math.acos(cosHourAngle));
    final sunEventLST =
        isSunrise ? _solarNoonLST - hourAngle * 4 : _solarNoonLST + hourAngle * 4;

    return sunEventLST;
  }

  /// Convert Local Solar Time (minutes from midnight) to DateTime
  DateTime? _lstToDateTime(double? lst) {
    if (lst == null) return null;

    // Adjust for timezone offset to get local time
    final tzOffsetMinutes = date.timeZoneOffset.inMinutes;
    final localMinutes = lst + tzOffsetMinutes;

    // Handle day overflow/underflow
    var adjustedMinutes = localMinutes;
    var dayOffset = 0;
    if (adjustedMinutes < 0) {
      adjustedMinutes += 1440;
      dayOffset = -1;
    } else if (adjustedMinutes >= 1440) {
      adjustedMinutes -= 1440;
      dayOffset = 1;
    }

    final hours = adjustedMinutes ~/ 60;
    final minutes = (adjustedMinutes % 60).toInt();
    final seconds = ((adjustedMinutes % 1) * 60).toInt();

    return DateTime(
      date.year,
      date.month,
      date.day + dayOffset,
      hours.clamp(0, 23),
      minutes.clamp(0, 59),
      seconds.clamp(0, 59),
    );
  }

  /// Get sunrise time (null if no sunrise, e.g., polar night)
  DateTime? get sunrise => _lstToDateTime(_getSunEventTime(sunriseAngle, true));

  /// Get sunset time (null if no sunset, e.g., polar day)
  DateTime? get sunset => _lstToDateTime(_getSunEventTime(sunriseAngle, false));

  /// Get civil twilight start (morning)
  DateTime? get civilTwilightStart =>
      _lstToDateTime(_getSunEventTime(civilTwilightAngle, true));

  /// Get civil twilight end (evening)
  DateTime? get civilTwilightEnd =>
      _lstToDateTime(_getSunEventTime(civilTwilightAngle, false));

  /// Get nautical twilight start (morning)
  DateTime? get nauticalTwilightStart =>
      _lstToDateTime(_getSunEventTime(nauticalTwilightAngle, true));

  /// Get nautical twilight end (evening)
  DateTime? get nauticalTwilightEnd =>
      _lstToDateTime(_getSunEventTime(nauticalTwilightAngle, false));

  /// Get astronomical twilight start (morning)
  DateTime? get astronomicalTwilightStart =>
      _lstToDateTime(_getSunEventTime(astronomicalTwilightAngle, true));

  /// Get astronomical twilight end (evening)
  DateTime? get astronomicalTwilightEnd =>
      _lstToDateTime(_getSunEventTime(astronomicalTwilightAngle, false));

  /// Get solar noon time
  DateTime get solarNoon => _lstToDateTime(_solarNoonLST)!;

  /// Check if it's polar day (sun never sets)
  bool get isPolarDay {
    final cosHA = (math.cos(_toRadians(90.833)) -
            math.sin(_toRadians(latitude)) * math.sin(_sunDeclinationRad)) /
        (math.cos(_toRadians(latitude)) * math.cos(_sunDeclinationRad));
    return cosHA < -1;
  }

  /// Check if it's polar night (sun never rises)
  bool get isPolarNight {
    final cosHA = (math.cos(_toRadians(90.833)) -
            math.sin(_toRadians(latitude)) * math.sin(_sunDeclinationRad)) /
        (math.cos(_toRadians(latitude)) * math.cos(_sunDeclinationRad));
    return cosHA > 1;
  }

  /// Get normalized time (0.0 - 1.0) for a DateTime within the day
  static double normalizeTime(DateTime time) {
    return (time.hour * 60 + time.minute + time.second / 60) / 1440;
  }

  /// Get all sun events as normalized times (0.0-1.0 representing the day)
  /// Returns a map with event names and their normalized times
  Map<String, double> getNormalizedTimes() {
    final result = <String, double>{};

    if (astronomicalTwilightStart != null) {
      result['astronomicalTwilightStart'] =
          normalizeTime(astronomicalTwilightStart!);
    }
    if (nauticalTwilightStart != null) {
      result['nauticalTwilightStart'] = normalizeTime(nauticalTwilightStart!);
    }
    if (civilTwilightStart != null) {
      result['civilTwilightStart'] = normalizeTime(civilTwilightStart!);
    }
    if (sunrise != null) {
      result['sunrise'] = normalizeTime(sunrise!);
    }
    result['solarNoon'] = normalizeTime(solarNoon);
    if (sunset != null) {
      result['sunset'] = normalizeTime(sunset!);
    }
    if (civilTwilightEnd != null) {
      result['civilTwilightEnd'] = normalizeTime(civilTwilightEnd!);
    }
    if (nauticalTwilightEnd != null) {
      result['nauticalTwilightEnd'] = normalizeTime(nauticalTwilightEnd!);
    }
    if (astronomicalTwilightEnd != null) {
      result['astronomicalTwilightEnd'] = normalizeTime(astronomicalTwilightEnd!);
    }

    return result;
  }
}
