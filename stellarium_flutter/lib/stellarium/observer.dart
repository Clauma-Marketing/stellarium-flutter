/// Represents an observer's position and time settings for the sky view.
class Observer {
  /// Longitude in radians
  double longitude;

  /// Latitude in radians
  double latitude;

  /// Altitude in meters
  double altitude;

  /// UTC time as Modified Julian Date
  double utc;

  /// Azimuth of view direction in radians
  double azimuth;

  /// Altitude (elevation) of view direction in radians
  double elevation;

  /// Field of view in radians
  double fov;

  Observer({
    this.longitude = 0.0,
    this.latitude = 0.0,
    this.altitude = 0.0,
    this.utc = 0.0,
    this.azimuth = 0.0,
    this.elevation = 0.0,
    this.fov = 1.0, // ~57 degrees
  });

  /// Convert degrees to radians
  static double deg2rad(double deg) => deg * 3.141592653589793 / 180.0;

  /// Convert radians to degrees
  static double rad2deg(double rad) => rad * 180.0 / 3.141592653589793;

  /// Convert a DateTime to Modified Julian Date (MJD)
  static double dateTimeToMjd(DateTime dt) {
    // MJD = JD - 2400000.5
    // Note: The JD formula computes JD at noon of the given date.
    // We subtract an extra 0.5 to shift the epoch to midnight.
    final y = dt.year;
    final m = dt.month;
    final d = dt.day +
        dt.hour / 24.0 +
        dt.minute / 1440.0 +
        dt.second / 86400.0 +
        dt.millisecond / 86400000.0;

    final a = ((14 - m) / 12).floor();
    final yAdj = y + 4800 - a;
    final mAdj = m + 12 * a - 3;

    final jd = d +
        ((153 * mAdj + 2) / 5).floor() +
        365 * yAdj +
        (yAdj / 4).floor() -
        (yAdj / 100).floor() +
        (yAdj / 400).floor() -
        32045;

    // Subtract 2400001.0 instead of 2400000.5 to shift from noon to midnight epoch
    return jd - 2400001.0;
  }

  /// Convert Modified Julian Date to DateTime
  static DateTime mjdToDateTime(double mjd) {
    final jd = mjd + 2400000.5;
    final z = (jd + 0.5).floor();
    final f = jd + 0.5 - z;

    int a;
    if (z < 2299161) {
      a = z;
    } else {
      final alpha = ((z - 1867216.25) / 36524.25).floor();
      a = z + 1 + alpha - (alpha / 4).floor();
    }

    final b = a + 1524;
    final c = ((b - 122.1) / 365.25).floor();
    final d = (365.25 * c).floor();
    final e = ((b - d) / 30.6001).floor();

    final day = b - d - (30.6001 * e).floor();
    final month = e < 14 ? e - 1 : e - 13;
    final year = month > 2 ? c - 4716 : c - 4715;

    final dayFraction = f;
    final hours = (dayFraction * 24).floor();
    final minutes = ((dayFraction * 24 - hours) * 60).floor();
    final seconds = ((dayFraction * 24 - hours) * 60 - minutes) * 60;

    return DateTime.utc(
      year,
      month,
      day,
      hours,
      minutes,
      seconds.floor(),
      ((seconds - seconds.floor()) * 1000).floor(),
    );
  }

  /// Create an observer at a given location with current time
  factory Observer.now({
    double longitude = 0.0,
    double latitude = 0.0,
    double altitude = 0.0,
  }) {
    return Observer(
      longitude: longitude,
      latitude: latitude,
      altitude: altitude,
      utc: dateTimeToMjd(DateTime.now().toUtc()),
    );
  }

  @override
  String toString() {
    return 'Observer(lon: ${rad2deg(longitude).toStringAsFixed(2)}°, '
        'lat: ${rad2deg(latitude).toStringAsFixed(2)}°, '
        'alt: ${altitude}m, fov: ${rad2deg(fov).toStringAsFixed(1)}°)';
  }
}
