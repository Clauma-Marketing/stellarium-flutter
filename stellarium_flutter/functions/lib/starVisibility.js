"use strict";
/**
 * Star Visibility Calculator
 * Port of the Dart StarVisibility class to TypeScript for Cloud Functions
 * Updated to match the in-app Dart implementation exactly
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.getStarAltitude = getStarAltitude;
exports.getStarAzimuth = getStarAzimuth;
exports.getDirectionName = getDirectionName;
exports.isCircumpolar = isCircumpolar;
exports.neverRises = neverRises;
exports.isAboveHorizon = isAboveHorizon;
exports.isDarkEnough = isDarkEnough;
exports.isVisible = isVisible;
exports.getStarRiseTime = getStarRiseTime;
exports.getStarSetTime = getStarSetTime;
exports.getTonightViewingWindow = getTonightViewingWindow;
exports.getNextVisibilityStart = getNextVisibilityStart;
exports.getVisibilityEnd = getVisibilityEnd;
exports.formatTime = formatTime;
exports.formatTimeLocal = formatTimeLocal;
exports.formatTimeWithDayOffset = formatTimeWithDayOffset;
exports.formatTimeWithDayOffsetLocal = formatTimeWithDayOffsetLocal;
exports.formatViewingWindow = formatViewingWindow;
exports.formatViewingWindowLocal = formatViewingWindowLocal;
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
 * Sun angles for different events (in degrees)
 */
const SUN_ANGLES = {
    sunrise: -0.833, // Accounts for refraction and sun size
    civilTwilight: -6.0,
    nauticalTwilight: -12.0,
    astronomicalTwilight: -18.0,
};
/**
 * SunTimes class - calculates sunrise, sunset, and twilight times
 * Based on NOAA solar calculator algorithms
 */
class SunTimes {
    constructor(latitude, longitude, date) {
        this.julianDay = 0;
        this.julianCentury = 0;
        this.solarNoonLST = 0;
        this.sunDeclinationRad = 0;
        this.eqOfTime = 0;
        this.latitude = latitude;
        this.longitude = longitude;
        this.date = date;
        this.calculate();
    }
    toRadians(degrees) {
        return degrees * Math.PI / 180;
    }
    toDegrees(radians) {
        return radians * 180 / Math.PI;
    }
    calculate() {
        const year = this.date.getUTCFullYear();
        const month = this.date.getUTCMonth() + 1;
        const day = this.date.getUTCDate();
        const a = Math.floor((14 - month) / 12);
        const y = year + 4800 - a;
        const m = month + 12 * a - 3;
        this.julianDay = day +
            Math.floor((153 * m + 2) / 5) +
            365 * y +
            Math.floor(y / 4) -
            Math.floor(y / 100) +
            Math.floor(y / 400) -
            32045 +
            0.5; // Noon
        this.julianCentury = (this.julianDay - 2451545.0) / 36525.0;
        // Geometric Mean Longitude of Sun (degrees)
        const geomMeanLongSun = (280.46646 + this.julianCentury * (36000.76983 + 0.0003032 * this.julianCentury)) % 360;
        // Geometric Mean Anomaly of Sun (degrees)
        const geomMeanAnomalySun = 357.52911 + this.julianCentury * (35999.05029 - 0.0001537 * this.julianCentury);
        // Eccentricity of Earth's Orbit
        const eccentEarthOrbit = 0.016708634 - this.julianCentury * (0.000042037 + 0.0000001267 * this.julianCentury);
        // Sun Equation of Center
        const sunEqOfCtr = Math.sin(this.toRadians(geomMeanAnomalySun)) *
            (1.914602 - this.julianCentury * (0.004817 + 0.000014 * this.julianCentury)) +
            Math.sin(this.toRadians(2 * geomMeanAnomalySun)) *
                (0.019993 - 0.000101 * this.julianCentury) +
            Math.sin(this.toRadians(3 * geomMeanAnomalySun)) * 0.000289;
        // Sun True Longitude (degrees)
        const sunTrueLong = geomMeanLongSun + sunEqOfCtr;
        // Sun Apparent Longitude (degrees)
        const sunAppLong = sunTrueLong -
            0.00569 -
            0.00478 * Math.sin(this.toRadians(125.04 - 1934.136 * this.julianCentury));
        // Mean Obliquity of Ecliptic (degrees)
        const meanObliqEcliptic = 23 +
            (26 +
                ((21.448 -
                    this.julianCentury *
                        (46.815 +
                            this.julianCentury *
                                (0.00059 - this.julianCentury * 0.001813))) /
                    60)) /
                60;
        // Obliquity Correction (degrees)
        const obliqCorr = meanObliqEcliptic +
            0.00256 * Math.cos(this.toRadians(125.04 - 1934.136 * this.julianCentury));
        // Sun Declination (radians)
        this.sunDeclinationRad = Math.asin(Math.sin(this.toRadians(obliqCorr)) * Math.sin(this.toRadians(sunAppLong)));
        // Var Y
        const varY = Math.tan(this.toRadians(obliqCorr / 2)) *
            Math.tan(this.toRadians(obliqCorr / 2));
        // Equation of Time (minutes)
        this.eqOfTime = 4 *
            this.toDegrees(varY * Math.sin(2 * this.toRadians(geomMeanLongSun)) -
                2 * eccentEarthOrbit * Math.sin(this.toRadians(geomMeanAnomalySun)) +
                4 * eccentEarthOrbit * varY *
                    Math.sin(this.toRadians(geomMeanAnomalySun)) *
                    Math.cos(2 * this.toRadians(geomMeanLongSun)) -
                0.5 * varY * varY * Math.sin(4 * this.toRadians(geomMeanLongSun)) -
                1.25 * eccentEarthOrbit * eccentEarthOrbit *
                    Math.sin(2 * this.toRadians(geomMeanAnomalySun)));
        // Solar Noon (LST - Local Solar Time in minutes from midnight)
        this.solarNoonLST = 720 - 4 * this.longitude - this.eqOfTime;
    }
    /**
     * Calculate the time of a solar event for a given sun angle.
     * Returns minutes from midnight (local solar time), or null if the event doesn't occur.
     */
    getSunEventTime(sunAngleDegs, isSunrise) {
        const latRad = this.toRadians(this.latitude);
        // Zenith angle = 90 - sun altitude
        const zenithAngle = 90.0 - sunAngleDegs;
        // Hour Angle calculation
        const cosHourAngle = (Math.cos(this.toRadians(zenithAngle)) -
            Math.sin(latRad) * Math.sin(this.sunDeclinationRad)) /
            (Math.cos(latRad) * Math.cos(this.sunDeclinationRad));
        // Check if sun event occurs (polar day/night)
        if (cosHourAngle > 1 || cosHourAngle < -1) {
            return null;
        }
        const hourAngle = this.toDegrees(Math.acos(cosHourAngle));
        const sunEventLST = isSunrise
            ? this.solarNoonLST - hourAngle * 4
            : this.solarNoonLST + hourAngle * 4;
        return sunEventLST;
    }
    /**
     * Convert Local Solar Time (minutes from midnight) to Date
     */
    lstToDate(lst, tzOffsetMinutes) {
        if (lst === null)
            return null;
        // Adjust for timezone offset to get local time
        const localMinutes = lst + tzOffsetMinutes;
        // Handle day overflow/underflow
        let adjustedMinutes = localMinutes;
        let dayOffset = 0;
        if (adjustedMinutes < 0) {
            adjustedMinutes += 1440;
            dayOffset = -1;
        }
        else if (adjustedMinutes >= 1440) {
            adjustedMinutes -= 1440;
            dayOffset = 1;
        }
        const hours = Math.floor(adjustedMinutes / 60);
        const minutes = Math.floor(adjustedMinutes % 60);
        const seconds = Math.floor((adjustedMinutes % 1) * 60);
        const result = new Date(this.date);
        result.setUTCDate(result.getUTCDate() + dayOffset);
        result.setUTCHours(Math.max(0, Math.min(23, hours)), Math.max(0, Math.min(59, minutes)), Math.max(0, Math.min(59, seconds)), 0);
        return result;
    }
    /**
     * Get astronomical twilight end (evening) - when it gets dark enough for stars
     */
    getAstronomicalTwilightEnd(tzOffsetMinutes = 0) {
        return this.lstToDate(this.getSunEventTime(SUN_ANGLES.astronomicalTwilight, false), tzOffsetMinutes);
    }
    /**
     * Get astronomical twilight start (morning) - when it starts getting light
     */
    getAstronomicalTwilightStart(tzOffsetMinutes = 0) {
        return this.lstToDate(this.getSunEventTime(SUN_ANGLES.astronomicalTwilight, true), tzOffsetMinutes);
    }
    /**
     * Check if it's polar day (sun never sets)
     */
    isPolarDay() {
        const cosHA = (Math.cos(this.toRadians(90.833)) -
            Math.sin(this.toRadians(this.latitude)) * Math.sin(this.sunDeclinationRad)) /
            (Math.cos(this.toRadians(this.latitude)) * Math.cos(this.sunDeclinationRad));
        return cosHA < -1;
    }
    /**
     * Check if it's polar night (sun never rises)
     */
    isPolarNight() {
        const cosHA = (Math.cos(this.toRadians(90.833)) -
            Math.sin(this.toRadians(this.latitude)) * Math.sin(this.sunDeclinationRad)) /
            (Math.cos(this.toRadians(this.latitude)) * Math.cos(this.sunDeclinationRad));
        return cosHA > 1;
    }
}
/**
 * Convert DateTime to Julian Date
 */
function dateToJulianDate(date) {
    const utc = date;
    const year = utc.getUTCFullYear();
    const month = utc.getUTCMonth() + 1;
    const day = utc.getUTCDate() +
        utc.getUTCHours() / 24.0 +
        utc.getUTCMinutes() / 1440.0 +
        utc.getUTCSeconds() / 86400.0 +
        utc.getUTCMilliseconds() / 86400000.0;
    const a = Math.floor((14 - month) / 12);
    const y = year + 4800 - a;
    const m = month + 12 * a - 3;
    return day +
        Math.floor((153 * m + 2) / 5) +
        365 * y +
        Math.floor(y / 4) -
        Math.floor(y / 100) +
        Math.floor(y / 400) -
        32045;
}
/**
 * Calculate Local Sidereal Time in degrees
 */
function getLocalSiderealTime(date, longitudeDeg) {
    const jd = dateToJulianDate(date);
    const T = (jd - 2451545.0) / 36525.0;
    // Greenwich Mean Sidereal Time in degrees
    let gmst = 280.46061837 +
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
function getStarAltitude(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, date) {
    const lst = getLocalSiderealTime(date, longitudeDeg);
    // Hour angle
    let ha = lst - starRaDeg;
    while (ha > 180)
        ha -= 360;
    while (ha < -180)
        ha += 360;
    const haRad = ha * DEG_TO_RAD;
    const decRad = starDecDeg * DEG_TO_RAD;
    const latRad = latitudeDeg * DEG_TO_RAD;
    // Calculate altitude using spherical trigonometry
    const sinAlt = Math.sin(latRad) * Math.sin(decRad) +
        Math.cos(latRad) * Math.cos(decRad) * Math.cos(haRad);
    return Math.asin(Math.max(-1, Math.min(1, sinAlt))) * RAD_TO_DEG;
}
/**
 * Calculate star azimuth at a given time
 */
function getStarAzimuth(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, date) {
    const lst = getLocalSiderealTime(date, longitudeDeg);
    let ha = lst - starRaDeg;
    while (ha > 180)
        ha -= 360;
    while (ha < -180)
        ha += 360;
    const haRad = ha * DEG_TO_RAD;
    const decRad = starDecDeg * DEG_TO_RAD;
    const latRad = latitudeDeg * DEG_TO_RAD;
    // Calculate altitude first
    const sinAlt = Math.sin(latRad) * Math.sin(decRad) +
        Math.cos(latRad) * Math.cos(decRad) * Math.cos(haRad);
    const alt = Math.asin(Math.max(-1, Math.min(1, sinAlt)));
    const cosAz = (Math.sin(decRad) - Math.sin(latRad) * Math.sin(alt)) /
        (Math.cos(latRad) * Math.cos(alt));
    let az = Math.acos(Math.max(-1, Math.min(1, cosAz))) * RAD_TO_DEG;
    // Adjust for quadrant
    if (Math.sin(haRad) > 0) {
        az = 360 - az;
    }
    return az;
}
/**
 * Get direction name from azimuth (matching Dart implementation)
 */
function getDirectionName(azimuthDeg) {
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
    const index = Math.floor(((azimuthDeg + 22.5) % 360) / 45);
    return directions[index];
}
/**
 * Check if a star is circumpolar (never sets) at given latitude
 */
function isCircumpolar(starDecDeg, latitudeDeg) {
    if (latitudeDeg >= 0) {
        // Northern hemisphere observer
        const minAlt = starDecDeg - (90 - latitudeDeg);
        return minAlt > MIN_OBSERVATION_ALTITUDE;
    }
    else {
        // Southern hemisphere observer
        const minAlt = -starDecDeg - (90 + latitudeDeg);
        return minAlt > MIN_OBSERVATION_ALTITUDE;
    }
}
/**
 * Check if a star never rises at given latitude
 */
function neverRises(starDecDeg, latitudeDeg) {
    if (latitudeDeg >= 0) {
        // Northern hemisphere - stars too far south never rise
        return starDecDeg < (latitudeDeg - 90 + MIN_OBSERVATION_ALTITUDE);
    }
    else {
        // Southern hemisphere - stars too far north never rise
        return starDecDeg > (latitudeDeg + 90 - MIN_OBSERVATION_ALTITUDE);
    }
}
/**
 * Check if star is above minimum observation altitude
 */
function isAboveHorizon(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, date) {
    const altitude = getStarAltitude(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, date);
    return altitude > MIN_OBSERVATION_ALTITUDE;
}
/**
 * Check if it's dark enough to see stars (astronomical twilight)
 * Uses the full NOAA algorithm via SunTimes class
 */
function isDarkEnough(latitudeDeg, longitudeDeg, date) {
    const sunTimes = new SunTimes(latitudeDeg, longitudeDeg, date);
    // Check if we're in astronomical twilight or darker
    const astroStart = sunTimes.getAstronomicalTwilightEnd(); // Evening - when it gets dark
    const astroEnd = sunTimes.getAstronomicalTwilightStart(); // Morning - when it gets light
    if (astroStart === null || astroEnd === null) {
        // Polar day/night - check directly
        return sunTimes.isPolarNight();
    }
    // Night is between astronomical twilight end (evening) and start (morning)
    if (astroStart.getTime() < astroEnd.getTime()) {
        // Normal case: night spans midnight
        return date.getTime() > astroStart.getTime() || date.getTime() < astroEnd.getTime();
    }
    else {
        // Summer near poles: night is a short period
        return date.getTime() > astroStart.getTime() && date.getTime() < astroEnd.getTime();
    }
}
/**
 * Check if star is visible (above horizon AND dark enough)
 */
function isVisible(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, date) {
    return (isAboveHorizon(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, date) &&
        isDarkEnough(latitudeDeg, longitudeDeg, date));
}
/**
 * Calculate the hour angle when a star crosses a given altitude
 * Returns hour angle in hours, or null if star never reaches that altitude
 */
function getHourAngleForAltitude(altitudeDeg, starDecDeg, latitudeDeg) {
    const altRad = altitudeDeg * DEG_TO_RAD;
    const decRad = starDecDeg * DEG_TO_RAD;
    const latRad = latitudeDeg * DEG_TO_RAD;
    const cosH = (Math.sin(altRad) - Math.sin(latRad) * Math.sin(decRad)) /
        (Math.cos(latRad) * Math.cos(decRad));
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
    return Math.acos(cosH) * RAD_TO_DEG / 15.0;
}
/**
 * Get the transit time (when star crosses the meridian) for a given date
 * Returns time in UTC
 */
function getTransitTime(starRaDeg, longitudeDeg, date) {
    // Convert star RA from degrees to hours
    const starRAHours = starRaDeg / 15.0;
    // Get Greenwich Mean Sidereal Time at 0h UT on the date
    const midnight = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
    const jd0 = dateToJulianDate(midnight);
    const t = (jd0 - 2451545.0) / 36525.0;
    // GMST at 0h UT in hours (IAU 1982 formula)
    let gmst0h = 6.697374558 +
        2400.051336 * t +
        0.000025862 * t * t;
    gmst0h = ((gmst0h % 24) + 24) % 24;
    // Local Sidereal Time at 0h UT
    const lst0h = gmst0h + longitudeDeg / 15.0;
    // Hour angle at 0h UT (how far star is from meridian)
    let hourAngle = starRAHours - lst0h;
    // Normalize to find the time until transit (0 to 24 hours)
    while (hourAngle < 0) {
        hourAngle += 24;
    }
    while (hourAngle >= 24) {
        hourAngle -= 24;
    }
    // Convert sidereal hours to solar hours
    const solarHours = hourAngle * 0.9972696;
    // Return UTC time
    const result = new Date(midnight);
    result.setUTCMinutes(result.getUTCMinutes() + Math.round(solarHours * 60));
    return result;
}
/**
 * Calculate when a star rises above the horizon for a given date
 * Returns the DateTime of rise, or null if star doesn't rise/set
 */
function getStarRiseTime(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, date) {
    // Check if star ever rises
    if (neverRises(starDecDeg, latitudeDeg)) {
        return null;
    }
    // If circumpolar, return null (star is always up)
    if (isCircumpolar(starDecDeg, latitudeDeg)) {
        return null;
    }
    const hourAngle = getHourAngleForAltitude(MIN_OBSERVATION_ALTITUDE, starDecDeg, latitudeDeg);
    if (hourAngle === null)
        return null;
    // Find the transit time
    const transitTime = getTransitTime(starRaDeg, longitudeDeg, date);
    // Rise time is transit time minus hour angle (in hours)
    const riseTime = new Date(transitTime);
    riseTime.setUTCMinutes(riseTime.getUTCMinutes() - Math.round(hourAngle * 60));
    return riseTime;
}
/**
 * Calculate when a star sets below the horizon for a given date
 * Returns the DateTime of set, or null if star doesn't set
 */
function getStarSetTime(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, date) {
    if (neverRises(starDecDeg, latitudeDeg)) {
        return null;
    }
    if (isCircumpolar(starDecDeg, latitudeDeg)) {
        return null;
    }
    const hourAngle = getHourAngleForAltitude(MIN_OBSERVATION_ALTITUDE, starDecDeg, latitudeDeg);
    if (hourAngle === null)
        return null;
    // Get transit time
    const transitTime = getTransitTime(starRaDeg, longitudeDeg, date);
    // Set time is transit time plus hour angle
    const setTime = new Date(transitTime);
    setTime.setUTCMinutes(setTime.getUTCMinutes() + Math.round(hourAngle * 60));
    return setTime;
}
/**
 * Get the viewing window for tonight when star is both visible and dark
 * Returns { start, end } or null if not visible tonight
 */
function getTonightViewingWindow(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, date) {
    const sunTimes = new SunTimes(latitudeDeg, longitudeDeg, date);
    // Get darkness window (astronomical twilight)
    const darkStart = sunTimes.getAstronomicalTwilightEnd();
    const darkEnd = sunTimes.getAstronomicalTwilightStart();
    if (darkStart === null || darkEnd === null) {
        // No astronomical darkness (polar summer)
        return null;
    }
    // For tonight, darkness is from this evening's twilight end
    // to tomorrow morning's twilight start
    const tomorrow = new Date(date);
    tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
    const tomorrowSunTimes = new SunTimes(latitudeDeg, longitudeDeg, tomorrow);
    const morningTwilightStart = tomorrowSunTimes.getAstronomicalTwilightStart();
    let windowStart = null;
    let windowEnd = null;
    // Check if star is circumpolar
    if (isCircumpolar(starDecDeg, latitudeDeg)) {
        // Star is always up, so window is just the dark period
        windowStart = darkStart;
        windowEnd = morningTwilightStart !== null && morningTwilightStart !== void 0 ? morningTwilightStart : darkEnd;
    }
    else if (neverRises(starDecDeg, latitudeDeg)) {
        // Star never rises
        return null;
    }
    else {
        // Get rise and set times
        const riseTime = getStarRiseTime(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, date);
        const setTime = getStarSetTime(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, date);
        // Also check tomorrow for rise
        const tomorrowRise = getStarRiseTime(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, tomorrow);
        // Check if star sets before darkness even starts
        if (setTime !== null && setTime.getTime() < darkStart.getTime()) {
            // Star has already set before it gets dark - check if it rises again tonight
            if (tomorrowRise !== null && tomorrowRise.getTime() > darkStart.getTime()) {
                // Star rises during the night
                windowStart = tomorrowRise;
                windowEnd = morningTwilightStart !== null && morningTwilightStart !== void 0 ? morningTwilightStart : darkEnd;
            }
            else {
                // Star doesn't rise during the dark period
                return null;
            }
        }
        else {
            // Normal case: star is up during some part of the night
            if (riseTime !== null && riseTime.getTime() > darkStart.getTime()) {
                windowStart = riseTime;
            }
            else {
                // Star already up at darkness start, or rises before
                windowStart = darkStart;
            }
            const endBound = morningTwilightStart !== null && morningTwilightStart !== void 0 ? morningTwilightStart : darkEnd;
            if (setTime !== null && setTime.getTime() < endBound.getTime()) {
                windowEnd = setTime;
            }
            else {
                windowEnd = endBound;
            }
        }
        // Validate window
        if (windowStart && windowEnd && windowEnd.getTime() < windowStart.getTime()) {
            return null;
        }
    }
    if (windowStart === null) {
        return null;
    }
    return { start: windowStart, end: windowEnd };
}
/**
 * Get the next time the star becomes visible
 * Uses analytical calculation matching the Dart implementation
 */
function getNextVisibilityStart(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, fromDate) {
    const now = fromDate || new Date();
    const today = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
    // Check today and the next few days
    for (let dayOffset = 0; dayOffset < 3; dayOffset++) {
        const checkDate = new Date(today);
        checkDate.setUTCDate(checkDate.getUTCDate() + dayOffset);
        const window = getTonightViewingWindow(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, checkDate);
        if (window !== null && window.start.getTime() > now.getTime()) {
            return window.start;
        }
    }
    return null;
}
/**
 * Get the viewing window end time (when star sets or dawn begins)
 */
function getVisibilityEnd(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, fromDate) {
    var _a;
    if (!isVisible(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, fromDate)) {
        return null;
    }
    // Get the current viewing window
    const today = new Date(Date.UTC(fromDate.getUTCFullYear(), fromDate.getUTCMonth(), fromDate.getUTCDate()));
    // Try today first
    let window = getTonightViewingWindow(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, today);
    // If currently visible but no window for today, check yesterday (we might be in last night's window)
    if (window === null || window.start.getTime() > fromDate.getTime()) {
        const yesterday = new Date(today);
        yesterday.setUTCDate(yesterday.getUTCDate() - 1);
        window = getTonightViewingWindow(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, yesterday);
    }
    return (_a = window === null || window === void 0 ? void 0 : window.end) !== null && _a !== void 0 ? _a : null;
}
/**
 * Format time as HH:MM (UTC)
 */
function formatTime(date) {
    const hours = date.getUTCHours().toString().padStart(2, "0");
    const minutes = date.getUTCMinutes().toString().padStart(2, "0");
    return `${hours}:${minutes}`;
}
/**
 * Format time as HH:MM in user's local timezone
 * @param date The date to format (in UTC)
 * @param timezoneOffsetMinutes The user's timezone offset in minutes (e.g., 60 for UTC+1)
 */
function formatTimeLocal(date, timezoneOffsetMinutes) {
    // Create a new date adjusted for the user's timezone
    const localTime = new Date(date.getTime() + timezoneOffsetMinutes * 60 * 1000);
    const hours = localTime.getUTCHours().toString().padStart(2, "0");
    const minutes = localTime.getUTCMinutes().toString().padStart(2, "0");
    return `${hours}:${minutes}`;
}
/**
 * Format time with day offset indicator (e.g., "05:30 (+1)" for next day)
 */
function formatTimeWithDayOffset(time, referenceDate) {
    const timeStr = formatTime(time);
    const refDay = new Date(Date.UTC(referenceDate.getUTCFullYear(), referenceDate.getUTCMonth(), referenceDate.getUTCDate()));
    const timeDay = new Date(Date.UTC(time.getUTCFullYear(), time.getUTCMonth(), time.getUTCDate()));
    const daysDiff = Math.round((timeDay.getTime() - refDay.getTime()) / (24 * 60 * 60 * 1000));
    if (daysDiff === 0) {
        return timeStr;
    }
    else if (daysDiff === 1) {
        return `${timeStr} (+1)`;
    }
    else {
        return `${timeStr} (+${daysDiff})`;
    }
}
/**
 * Format time with day offset indicator in user's local timezone
 * @param time The time to format (in UTC)
 * @param referenceDate The reference date for calculating day offset (in UTC)
 * @param timezoneOffsetMinutes The user's timezone offset in minutes
 */
function formatTimeWithDayOffsetLocal(time, referenceDate, timezoneOffsetMinutes) {
    // Convert both times to user's local timezone
    const localTime = new Date(time.getTime() + timezoneOffsetMinutes * 60 * 1000);
    const localRef = new Date(referenceDate.getTime() + timezoneOffsetMinutes * 60 * 1000);
    const timeStr = formatTimeLocal(time, timezoneOffsetMinutes);
    const refDay = new Date(Date.UTC(localRef.getUTCFullYear(), localRef.getUTCMonth(), localRef.getUTCDate()));
    const timeDay = new Date(Date.UTC(localTime.getUTCFullYear(), localTime.getUTCMonth(), localTime.getUTCDate()));
    const daysDiff = Math.round((timeDay.getTime() - refDay.getTime()) / (24 * 60 * 60 * 1000));
    if (daysDiff === 0) {
        return timeStr;
    }
    else if (daysDiff === 1) {
        return `${timeStr} (+1)`;
    }
    else {
        return `${timeStr} (+${daysDiff})`;
    }
}
/**
 * Format the viewing window as a string (e.g., "18:30 - 05:30 (+1)") in UTC
 */
function formatViewingWindow(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, fromDate) {
    const now = fromDate || new Date();
    const today = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
    // Check if currently visible
    if (isVisible(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, now)) {
        const endTime = getVisibilityEnd(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, now);
        const startStr = "Now";
        if (endTime) {
            const endStr = formatTimeWithDayOffset(endTime, today);
            return `${startStr} - ${endStr}`;
        }
        return startStr;
    }
    // Find next visibility window
    const window = getTonightViewingWindow(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, today);
    if (!window) {
        // Try tomorrow
        const tomorrow = new Date(today);
        tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
        const tomorrowWindow = getTonightViewingWindow(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, tomorrow);
        if (!tomorrowWindow) {
            return null;
        }
        const startStr = formatTimeWithDayOffset(tomorrowWindow.start, today);
        if (tomorrowWindow.end) {
            const endStr = formatTimeWithDayOffset(tomorrowWindow.end, today);
            return `${startStr} - ${endStr}`;
        }
        return startStr;
    }
    const startStr = formatTimeWithDayOffset(window.start, today);
    if (window.end) {
        const endStr = formatTimeWithDayOffset(window.end, today);
        return `${startStr} - ${endStr}`;
    }
    return startStr;
}
/**
 * Format the viewing window as a string in user's local timezone
 * @param timezoneOffsetMinutes The user's timezone offset in minutes (e.g., 60 for UTC+1)
 */
function formatViewingWindowLocal(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, timezoneOffsetMinutes, fromDate) {
    const now = fromDate || new Date();
    const today = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
    // Check if currently visible
    if (isVisible(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, now)) {
        const endTime = getVisibilityEnd(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, now);
        const startStr = "Now";
        if (endTime) {
            const endStr = formatTimeWithDayOffsetLocal(endTime, today, timezoneOffsetMinutes);
            return `${startStr} - ${endStr}`;
        }
        return startStr;
    }
    // Find next visibility window
    const window = getTonightViewingWindow(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, today);
    if (!window) {
        // Try tomorrow
        const tomorrow = new Date(today);
        tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
        const tomorrowWindow = getTonightViewingWindow(starRaDeg, starDecDeg, latitudeDeg, longitudeDeg, tomorrow);
        if (!tomorrowWindow) {
            return null;
        }
        const startStr = formatTimeWithDayOffsetLocal(tomorrowWindow.start, today, timezoneOffsetMinutes);
        if (tomorrowWindow.end) {
            const endStr = formatTimeWithDayOffsetLocal(tomorrowWindow.end, today, timezoneOffsetMinutes);
            return `${startStr} - ${endStr}`;
        }
        return startStr;
    }
    const startStr = formatTimeWithDayOffsetLocal(window.start, today, timezoneOffsetMinutes);
    if (window.end) {
        const endStr = formatTimeWithDayOffsetLocal(window.end, today, timezoneOffsetMinutes);
        return `${startStr} - ${endStr}`;
    }
    return startStr;
}
//# sourceMappingURL=starVisibility.js.map