/**
 * Star Visibility Calculator
 * Port of the Dart StarVisibility class to TypeScript for Cloud Functions
 */

const DEG_TO_RAD = Math.PI / 180;
const RAD_TO_DEG = 180 / Math.PI;

/**
 * Minimum altitude for practical star observation (in degrees).
 * Set to 10 degrees above horizon to account for:
 * - Atmospheric extinction (stars dim significantly near horizon)
 * - Typical obstructions (trees, buildings)
 * - Better viewing conditions
 */
const MIN_OBSERVATION_ALTITUDE = 10.0;

/**
 * Calculate Julian Date from a JavaScript Date
 */
function getJulianDate(date: Date): number {
  const time = date.getTime();
  return time / 86400000 + 2440587.5;
}

/**
 * Calculate Local Sidereal Time in degrees
 */
function getLocalSiderealTime(date: Date, longitudeDeg: number): number {
  const jd = getJulianDate(date);
  const T = (jd - 2451545.0) / 36525.0;

  // Greenwich Mean Sidereal Time in degrees
  let gmst =
    280.46061837 +
    360.98564736629 * (jd - 2451545.0) +
    0.000387933 * T * T -
    (T * T * T) / 38710000;

  // Normalize to 0-360
  gmst = ((gmst % 360) + 360) % 360;

  // Convert to Local Sidereal Time
  let lst = gmst + longitudeDeg;
  lst = ((lst % 360) + 360) % 360;

  return lst;
}

/**
 * Calculate star altitude at a given time
 */
export function getStarAltitude(
  starRaDeg: number,
  starDecDeg: number,
  latitudeDeg: number,
  longitudeDeg: number,
  date: Date
): number {
  const lst = getLocalSiderealTime(date, longitudeDeg);

  // Hour angle
  let ha = lst - starRaDeg;
  while (ha > 180) ha -= 360;
  while (ha < -180) ha += 360;

  const haRad = ha * DEG_TO_RAD;
  const decRad = starDecDeg * DEG_TO_RAD;
  const latRad = latitudeDeg * DEG_TO_RAD;

  // Calculate altitude using spherical trigonometry
  const sinAlt =
    Math.sin(latRad) * Math.sin(decRad) +
    Math.cos(latRad) * Math.cos(decRad) * Math.cos(haRad);

  return Math.asin(Math.max(-1, Math.min(1, sinAlt))) * RAD_TO_DEG;
}

/**
 * Calculate star azimuth at a given time
 */
export function getStarAzimuth(
  starRaDeg: number,
  starDecDeg: number,
  latitudeDeg: number,
  longitudeDeg: number,
  date: Date
): number {
  const lst = getLocalSiderealTime(date, longitudeDeg);

  let ha = lst - starRaDeg;
  while (ha > 180) ha -= 360;
  while (ha < -180) ha += 360;

  const haRad = ha * DEG_TO_RAD;
  const decRad = starDecDeg * DEG_TO_RAD;
  const latRad = latitudeDeg * DEG_TO_RAD;

  const sinAz = -Math.cos(decRad) * Math.sin(haRad);
  const cosAz =
    Math.sin(decRad) * Math.cos(latRad) -
    Math.cos(decRad) * Math.cos(haRad) * Math.sin(latRad);

  let az = Math.atan2(sinAz, cosAz) * RAD_TO_DEG;
  az = ((az % 360) + 360) % 360;

  return az;
}

/**
 * Get direction name from azimuth
 */
export function getDirectionName(azimuthDeg: number): string {
  const directions = [
    "north",
    "northeast",
    "east",
    "southeast",
    "south",
    "southwest",
    "west",
    "northwest",
  ];
  const index = Math.round(azimuthDeg / 45) % 8;
  return directions[index];
}

/**
 * Check if star is above minimum observation altitude
 */
export function isAboveHorizon(
  starRaDeg: number,
  starDecDeg: number,
  latitudeDeg: number,
  longitudeDeg: number,
  date: Date
): boolean {
  const altitude = getStarAltitude(
    starRaDeg,
    starDecDeg,
    latitudeDeg,
    longitudeDeg,
    date
  );
  return altitude > MIN_OBSERVATION_ALTITUDE;
}

/**
 * Calculate sun altitude (simplified)
 */
function getSunAltitude(
  latitudeDeg: number,
  longitudeDeg: number,
  date: Date
): number {
  const jd = getJulianDate(date);
  const n = jd - 2451545.0;

  // Mean longitude of the Sun
  const L = (280.46 + 0.9856474 * n) % 360;
  // Mean anomaly of the Sun
  const g = ((357.528 + 0.9856003 * n) % 360) * DEG_TO_RAD;

  // Ecliptic longitude
  const lambda =
    (L + 1.915 * Math.sin(g) + 0.02 * Math.sin(2 * g)) * DEG_TO_RAD;

  // Obliquity of the ecliptic
  const epsilon = 23.439 * DEG_TO_RAD;

  // Sun's right ascension and declination
  const sunRa =
    Math.atan2(Math.cos(epsilon) * Math.sin(lambda), Math.cos(lambda)) *
    RAD_TO_DEG;
  const sunDec = Math.asin(Math.sin(epsilon) * Math.sin(lambda)) * RAD_TO_DEG;

  return getStarAltitude(sunRa, sunDec, latitudeDeg, longitudeDeg, date);
}

/**
 * Check if it's dark enough for stargazing (astronomical twilight)
 * Sun must be below -18 degrees
 */
export function isDarkEnough(
  latitudeDeg: number,
  longitudeDeg: number,
  date: Date
): boolean {
  const sunAlt = getSunAltitude(latitudeDeg, longitudeDeg, date);
  return sunAlt < -18;
}

/**
 * Check if star is visible (above horizon AND dark enough)
 */
export function isVisible(
  starRaDeg: number,
  starDecDeg: number,
  latitudeDeg: number,
  longitudeDeg: number,
  date: Date
): boolean {
  return (
    isAboveHorizon(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, date) &&
    isDarkEnough(latitudeDeg, longitudeDeg, date)
  );
}

/**
 * Get the next time the star becomes visible
 * Searches forward from now in 15-minute increments, up to 48 hours
 */
export function getNextVisibilityStart(
  starRaDeg: number,
  starDecDeg: number,
  latitudeDeg: number,
  longitudeDeg: number,
  fromDate?: Date
): Date | null {
  const now = fromDate || new Date();
  const maxSearchHours = 48;
  const stepMinutes = 15;

  let wasVisible = isVisible(
    starRaDeg,
    starDecDeg,
    latitudeDeg,
    longitudeDeg,
    now
  );

  // If currently visible, we want the NEXT visibility window
  // So we need to find when it becomes not visible, then visible again

  for (let i = 1; i <= (maxSearchHours * 60) / stepMinutes; i++) {
    const checkTime = new Date(now.getTime() + i * stepMinutes * 60 * 1000);
    const nowVisible = isVisible(
      starRaDeg,
      starDecDeg,
      latitudeDeg,
      longitudeDeg,
      checkTime
    );

    if (!wasVisible && nowVisible) {
      // Star just became visible - refine to find exact time
      return refineVisibilityStart(
        starRaDeg,
        starDecDeg,
        latitudeDeg,
        longitudeDeg,
        new Date(checkTime.getTime() - stepMinutes * 60 * 1000),
        checkTime
      );
    }

    wasVisible = nowVisible;
  }

  return null;
}

/**
 * Binary search to find more precise visibility start time
 */
function refineVisibilityStart(
  starRaDeg: number,
  starDecDeg: number,
  latitudeDeg: number,
  longitudeDeg: number,
  notVisibleTime: Date,
  visibleTime: Date
): Date {
  // Binary search for 5 iterations (precision ~30 seconds)
  let low = notVisibleTime.getTime();
  let high = visibleTime.getTime();

  for (let i = 0; i < 5; i++) {
    const mid = (low + high) / 2;
    const midTime = new Date(mid);

    if (
      isVisible(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, midTime)
    ) {
      high = mid;
    } else {
      low = mid;
    }
  }

  return new Date(high);
}

/**
 * Get the viewing window end time (when star sets or dawn begins)
 */
export function getVisibilityEnd(
  starRaDeg: number,
  starDecDeg: number,
  latitudeDeg: number,
  longitudeDeg: number,
  fromDate: Date
): Date | null {
  const maxSearchHours = 24;
  const stepMinutes = 15;

  if (
    !isVisible(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, fromDate)
  ) {
    return null;
  }

  for (let i = 1; i <= (maxSearchHours * 60) / stepMinutes; i++) {
    const checkTime = new Date(fromDate.getTime() + i * stepMinutes * 60 * 1000);
    const stillVisible = isVisible(
      starRaDeg,
      starDecDeg,
      latitudeDeg,
      longitudeDeg,
      checkTime
    );

    if (!stillVisible) {
      return checkTime;
    }
  }

  return null;
}

/**
 * Format time as HH:MM
 */
export function formatTime(date: Date): string {
  const hours = date.getHours().toString().padStart(2, "0");
  const minutes = date.getMinutes().toString().padStart(2, "0");
  return `${hours}:${minutes}`;
}

/**
 * Format time with day offset indicator (e.g., "05:30 (+1)" for next day)
 */
export function formatTimeWithDayOffset(time: Date, referenceDate: Date): string {
  const timeStr = formatTime(time);
  const refDay = new Date(referenceDate.getFullYear(), referenceDate.getMonth(), referenceDate.getDate());
  const timeDay = new Date(time.getFullYear(), time.getMonth(), time.getDate());
  const daysDiff = Math.round((timeDay.getTime() - refDay.getTime()) / (24 * 60 * 60 * 1000));

  if (daysDiff === 0) {
    return timeStr;
  } else if (daysDiff === 1) {
    return `${timeStr} (+1)`;
  } else {
    return `${timeStr} (+${daysDiff})`;
  }
}

/**
 * Get the viewing window for a star (start and end times)
 * Returns { start, end } or null if not visible in the search period
 */
export function getViewingWindow(
  starRaDeg: number,
  starDecDeg: number,
  latitudeDeg: number,
  longitudeDeg: number,
  fromDate?: Date
): { start: Date; end: Date | null } | null {
  const now = fromDate || new Date();

  // First check if currently visible
  if (isVisible(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, now)) {
    // Find when visibility ends
    const end = getVisibilityEnd(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, now);
    return { start: now, end };
  }

  // Find next visibility start
  const start = getNextVisibilityStart(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, now);
  if (!start) {
    return null;
  }

  // Find when that visibility window ends
  // Search forward from just after the start time
  const searchStart = new Date(start.getTime() + 60 * 1000); // 1 minute after start
  const end = getVisibilityEnd(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, searchStart);

  return { start, end };
}

/**
 * Format the viewing window as a string (e.g., "18:30 - 05:30 (+1)")
 */
export function formatViewingWindow(
  starRaDeg: number,
  starDecDeg: number,
  latitudeDeg: number,
  longitudeDeg: number,
  fromDate?: Date
): string | null {
  const window = getViewingWindow(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, fromDate);
  if (!window) {
    return null;
  }

  const now = fromDate || new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  const startStr = formatTimeWithDayOffset(window.start, today);
  if (!window.end) {
    return startStr;
  }

  const endStr = formatTimeWithDayOffset(window.end, today);
  return `${startStr} - ${endStr}`;
}
