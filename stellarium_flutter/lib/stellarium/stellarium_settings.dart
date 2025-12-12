/// Settings for the Stellarium engine display options.
///
/// These settings control the visibility of various celestial
/// and UI elements in the sky view.
class StellariumSettings {
  // Sky Display
  bool constellationsLines;
  bool constellationsLabels;
  bool constellationsArt;
  bool atmosphere;
  bool landscape;
  bool landscapeFog;
  bool milkyWay;
  bool dss; // Digital Sky Survey background

  // Celestial Objects
  bool stars;
  bool planets;
  bool dsos; // Deep Sky Objects (nebulae, galaxies, clusters)
  bool satellites;

  // Grid Lines
  bool gridAzimuthal;
  bool gridEquatorial;
  bool gridEquatorialJ2000;
  bool lineMeridian;
  bool lineEcliptic;

  // UI Options
  bool nightMode;

  StellariumSettings({
    // Sky Display defaults
    this.constellationsLines = true,
    this.constellationsLabels = true,
    this.constellationsArt = true,
    this.atmosphere = false,
    this.landscape = true,
    this.landscapeFog = false,
    this.milkyWay = true,
    this.dss = true,
    // Celestial Objects defaults
    this.stars = true,
    this.planets = true,
    this.dsos = true,
    this.satellites = false,
    // Grid Lines defaults
    this.gridAzimuthal = false,
    this.gridEquatorial = false,
    this.gridEquatorialJ2000 = false,
    this.lineMeridian = false,
    this.lineEcliptic = false,
    // UI defaults
    this.nightMode = false,
  });

  /// Create a copy of this settings object
  StellariumSettings copyWith({
    bool? constellationsLines,
    bool? constellationsLabels,
    bool? constellationsArt,
    bool? atmosphere,
    bool? landscape,
    bool? landscapeFog,
    bool? milkyWay,
    bool? dss,
    bool? stars,
    bool? planets,
    bool? dsos,
    bool? satellites,
    bool? gridAzimuthal,
    bool? gridEquatorial,
    bool? gridEquatorialJ2000,
    bool? lineMeridian,
    bool? lineEcliptic,
    bool? nightMode,
  }) {
    return StellariumSettings(
      constellationsLines: constellationsLines ?? this.constellationsLines,
      constellationsLabels: constellationsLabels ?? this.constellationsLabels,
      constellationsArt: constellationsArt ?? this.constellationsArt,
      atmosphere: atmosphere ?? this.atmosphere,
      landscape: landscape ?? this.landscape,
      landscapeFog: landscapeFog ?? this.landscapeFog,
      milkyWay: milkyWay ?? this.milkyWay,
      dss: dss ?? this.dss,
      stars: stars ?? this.stars,
      planets: planets ?? this.planets,
      dsos: dsos ?? this.dsos,
      satellites: satellites ?? this.satellites,
      gridAzimuthal: gridAzimuthal ?? this.gridAzimuthal,
      gridEquatorial: gridEquatorial ?? this.gridEquatorial,
      gridEquatorialJ2000: gridEquatorialJ2000 ?? this.gridEquatorialJ2000,
      lineMeridian: lineMeridian ?? this.lineMeridian,
      lineEcliptic: lineEcliptic ?? this.lineEcliptic,
      nightMode: nightMode ?? this.nightMode,
    );
  }

  /// Convert to a map for serialization
  Map<String, bool> toMap() {
    return {
      'constellationsLines': constellationsLines,
      'constellationsLabels': constellationsLabels,
      'constellationsArt': constellationsArt,
      'atmosphere': atmosphere,
      'landscape': landscape,
      'landscapeFog': landscapeFog,
      'milkyWay': milkyWay,
      'dss': dss,
      'stars': stars,
      'planets': planets,
      'dsos': dsos,
      'satellites': satellites,
      'gridAzimuthal': gridAzimuthal,
      'gridEquatorial': gridEquatorial,
      'gridEquatorialJ2000': gridEquatorialJ2000,
      'lineMeridian': lineMeridian,
      'lineEcliptic': lineEcliptic,
      'nightMode': nightMode,
    };
  }

  /// Create from a map
  factory StellariumSettings.fromMap(Map<String, bool> map) {
    return StellariumSettings(
      constellationsLines: map['constellationsLines'] ?? true,
      constellationsLabels: map['constellationsLabels'] ?? true,
      constellationsArt: map['constellationsArt'] ?? true,
      atmosphere: map['atmosphere'] ?? false,
      landscape: map['landscape'] ?? false,
      landscapeFog: map['landscapeFog'] ?? false,
      milkyWay: map['milkyWay'] ?? true,
      dss: map['dss'] ?? true,
      stars: map['stars'] ?? true,
      planets: map['planets'] ?? true,
      dsos: map['dsos'] ?? true,
      satellites: map['satellites'] ?? false,
      gridAzimuthal: map['gridAzimuthal'] ?? false,
      gridEquatorial: map['gridEquatorial'] ?? false,
      gridEquatorialJ2000: map['gridEquatorialJ2000'] ?? false,
      lineMeridian: map['lineMeridian'] ?? false,
      lineEcliptic: map['lineEcliptic'] ?? false,
      nightMode: map['nightMode'] ?? false,
    );
  }
}

/// Enum for setting categories in the UI
enum SettingsCategory {
  skyDisplay('Sky Display'),
  celestialObjects('Celestial Objects'),
  gridLines('Grids & Lines'),
  uiOptions('Display Options');

  final String label;
  const SettingsCategory(this.label);
}

/// Metadata for a single setting
class SettingMetadata {
  final String key;
  final String label;
  final String description;
  final SettingsCategory category;
  final IconType icon;

  const SettingMetadata({
    required this.key,
    required this.label,
    required this.description,
    required this.category,
    required this.icon,
  });
}

/// Icon types for settings (to avoid Flutter dependency in model)
enum IconType {
  constellation,
  label,
  image,
  cloud,
  landscape,
  foggy,
  galaxy,
  photo,
  star,
  planet,
  nebula,
  satellite,
  gridAzimuthal,
  gridEquatorial,
  meridian,
  ecliptic,
  nightMode,
}

/// All available settings with their metadata
const List<SettingMetadata> allSettingsMetadata = [
  // Sky Display
  SettingMetadata(
    key: 'constellationsLines',
    label: 'Constellation Lines',
    description: 'Show lines connecting stars in constellations',
    category: SettingsCategory.skyDisplay,
    icon: IconType.constellation,
  ),
  SettingMetadata(
    key: 'constellationsLabels',
    label: 'Constellation Names',
    description: 'Show constellation name labels',
    category: SettingsCategory.skyDisplay,
    icon: IconType.label,
  ),
  SettingMetadata(
    key: 'constellationsArt',
    label: 'Constellation Art',
    description: 'Show artistic constellation illustrations',
    category: SettingsCategory.skyDisplay,
    icon: IconType.image,
  ),
  SettingMetadata(
    key: 'atmosphere',
    label: 'Atmosphere',
    description: 'Show atmospheric effects and sky glow',
    category: SettingsCategory.skyDisplay,
    icon: IconType.cloud,
  ),
  SettingMetadata(
    key: 'landscape',
    label: 'Landscape',
    description: 'Show ground/horizon landscape',
    category: SettingsCategory.skyDisplay,
    icon: IconType.landscape,
  ),
  SettingMetadata(
    key: 'landscapeFog',
    label: 'Landscape Fog',
    description: 'Show fog effect on landscape',
    category: SettingsCategory.skyDisplay,
    icon: IconType.foggy,
  ),
  SettingMetadata(
    key: 'milkyWay',
    label: 'Milky Way',
    description: 'Show the Milky Way galaxy',
    category: SettingsCategory.skyDisplay,
    icon: IconType.galaxy,
  ),
  SettingMetadata(
    key: 'dss',
    label: 'DSS Background',
    description: 'Show Digital Sky Survey background images',
    category: SettingsCategory.skyDisplay,
    icon: IconType.photo,
  ),
  // Celestial Objects
  SettingMetadata(
    key: 'stars',
    label: 'Stars',
    description: 'Show stars in the sky',
    category: SettingsCategory.celestialObjects,
    icon: IconType.star,
  ),
  SettingMetadata(
    key: 'planets',
    label: 'Planets',
    description: 'Show planets and solar system bodies',
    category: SettingsCategory.celestialObjects,
    icon: IconType.planet,
  ),
  SettingMetadata(
    key: 'dsos',
    label: 'Deep Sky Objects',
    description: 'Show nebulae, galaxies, and star clusters',
    category: SettingsCategory.celestialObjects,
    icon: IconType.nebula,
  ),
  SettingMetadata(
    key: 'satellites',
    label: 'Satellites',
    description: 'Show artificial satellites',
    category: SettingsCategory.celestialObjects,
    icon: IconType.satellite,
  ),
  // Grid Lines
  SettingMetadata(
    key: 'gridAzimuthal',
    label: 'Azimuthal Grid',
    description: 'Show altitude/azimuth coordinate grid',
    category: SettingsCategory.gridLines,
    icon: IconType.gridAzimuthal,
  ),
  SettingMetadata(
    key: 'gridEquatorial',
    label: 'Equatorial Grid',
    description: 'Show right ascension/declination grid',
    category: SettingsCategory.gridLines,
    icon: IconType.gridEquatorial,
  ),
  SettingMetadata(
    key: 'gridEquatorialJ2000',
    label: 'Equatorial J2000 Grid',
    description: 'Show J2000 epoch equatorial coordinates',
    category: SettingsCategory.gridLines,
    icon: IconType.gridEquatorial,
  ),
  SettingMetadata(
    key: 'lineMeridian',
    label: 'Meridian Line',
    description: 'Show the meridian (north-south through zenith)',
    category: SettingsCategory.gridLines,
    icon: IconType.meridian,
  ),
  SettingMetadata(
    key: 'lineEcliptic',
    label: 'Ecliptic Line',
    description: 'Show the ecliptic (sun\'s apparent path)',
    category: SettingsCategory.gridLines,
    icon: IconType.ecliptic,
  ),
  // UI Options
  SettingMetadata(
    key: 'nightMode',
    label: 'Night Mode',
    description: 'Red-shift display to preserve night vision',
    category: SettingsCategory.uiOptions,
    icon: IconType.nightMode,
  ),
];
