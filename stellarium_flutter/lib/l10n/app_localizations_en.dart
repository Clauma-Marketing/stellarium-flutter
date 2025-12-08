// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Night Sky Guide';

  @override
  String get menu => 'Menu';

  @override
  String get myStars => 'My Stars';

  @override
  String get myStarsSubtitle => 'Saved locations and favorites';

  @override
  String get timeLocation => 'Time & Location';

  @override
  String get timeLocationSubtitle => 'Set observation time and place';

  @override
  String get visualEffects => 'Visual Effects';

  @override
  String get visualEffectsSubtitle => 'Sky display, objects, and grids';

  @override
  String get settings => 'Settings';

  @override
  String get settingsSubtitle => 'App preferences';

  @override
  String get location => 'LOCATION';

  @override
  String get time => 'TIME';

  @override
  String get searchCityAddress => 'Search city, address...';

  @override
  String get useMyLocation => 'Use My Location';

  @override
  String get detecting => 'Detecting...';

  @override
  String get unknownLocation => 'Unknown location';

  @override
  String get setToNow => 'Set to Now';

  @override
  String get applyChanges => 'Apply Changes';

  @override
  String get setTime => 'Set Time';

  @override
  String get now => 'Now';

  @override
  String get cancel => 'Cancel';

  @override
  String get apply => 'Apply';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get savedToMyStars => 'Saved to My Stars';

  @override
  String get removedFromMyStars => 'Removed from My Stars';

  @override
  String get pointAtStar => 'Point at Star';

  @override
  String get removeFromMyStars => 'Remove from My Stars';

  @override
  String get saveToMyStars => 'Save to My Stars';

  @override
  String get noSavedStarsYet => 'No saved stars yet';

  @override
  String get tapStarIconHint =>
      'Tap the star icon on any star\'s info sheet to save it here';

  @override
  String starRemoved(String name) {
    return '$name removed';
  }

  @override
  String get registration => 'REGISTRATION';

  @override
  String get registeredTo => 'Registered to';

  @override
  String get registrationDate => 'Date';

  @override
  String get registrationNumber => 'Registration #';

  @override
  String get registry => 'Registry';

  @override
  String get properties => 'PROPERTIES';

  @override
  String get coordinates => 'COORDINATES';

  @override
  String get scientificName => 'Scientific Name';

  @override
  String get magnitude => 'Magnitude';

  @override
  String get spectralType => 'Spectral Type';

  @override
  String get distance => 'Distance';

  @override
  String get parallax => 'Parallax';

  @override
  String get objectType => 'Object Type';

  @override
  String get doubleMultipleStar => 'Double/Multiple Star';

  @override
  String get rightAscension => 'Right Ascension';

  @override
  String get declination => 'Declination';

  @override
  String get skyDisplay => 'Sky Display';

  @override
  String get celestialObjects => 'Celestial Objects';

  @override
  String get gridLines => 'Grids & Lines';

  @override
  String get displayOptions => 'Display Options';

  @override
  String get constellationLines => 'Constellation Lines';

  @override
  String get constellationLinesDesc =>
      'Show lines connecting stars in constellations';

  @override
  String get constellationNames => 'Constellation Names';

  @override
  String get constellationNamesDesc => 'Show constellation name labels';

  @override
  String get constellationArt => 'Constellation Art';

  @override
  String get constellationArtDesc =>
      'Show artistic constellation illustrations';

  @override
  String get atmosphere => 'Atmosphere';

  @override
  String get atmosphereDesc => 'Show atmospheric effects and sky glow';

  @override
  String get landscape => 'Landscape';

  @override
  String get landscapeDesc => 'Show ground/horizon landscape';

  @override
  String get landscapeFog => 'Landscape Fog';

  @override
  String get landscapeFogDesc => 'Show fog effect on landscape';

  @override
  String get milkyWay => 'Milky Way';

  @override
  String get milkyWayDesc => 'Show the Milky Way galaxy';

  @override
  String get dssBackground => 'DSS Background';

  @override
  String get dssBackgroundDesc => 'Show Digital Sky Survey background images';

  @override
  String get stars => 'Stars';

  @override
  String get starsDesc => 'Show stars in the sky';

  @override
  String get planets => 'Planets';

  @override
  String get planetsDesc => 'Show planets and solar system bodies';

  @override
  String get deepSkyObjects => 'Deep Sky Objects';

  @override
  String get deepSkyObjectsDesc => 'Show nebulae, galaxies, and star clusters';

  @override
  String get satellites => 'Satellites';

  @override
  String get satellitesDesc => 'Show artificial satellites';

  @override
  String get azimuthalGrid => 'Azimuthal Grid';

  @override
  String get azimuthalGridDesc => 'Show altitude/azimuth coordinate grid';

  @override
  String get equatorialGrid => 'Equatorial Grid';

  @override
  String get equatorialGridDesc => 'Show right ascension/declination grid';

  @override
  String get equatorialJ2000Grid => 'Equatorial J2000 Grid';

  @override
  String get equatorialJ2000GridDesc =>
      'Show J2000 epoch equatorial coordinates';

  @override
  String get meridianLine => 'Meridian Line';

  @override
  String get meridianLineDesc =>
      'Show the meridian (north-south through zenith)';

  @override
  String get eclipticLine => 'Ecliptic Line';

  @override
  String get eclipticLineDesc => 'Show the ecliptic (sun\'s apparent path)';

  @override
  String get nightMode => 'Night Mode';

  @override
  String get nightModeDesc => 'Red-shift display to preserve night vision';

  @override
  String get loadingSkyView => 'Loading sky view...';

  @override
  String get failedToLoadSkyView => 'Failed to load sky view';

  @override
  String get locationPermissionDenied => 'Location permission denied';

  @override
  String get locationPermissionPermanentlyDenied =>
      'Location permission permanently denied. Please enable in Settings.';

  @override
  String errorGettingLocation(String error) {
    return 'Error getting location: $error';
  }

  @override
  String registrationNotFound(String number) {
    return 'Registration number \"$number\" not found';
  }

  @override
  String errorSearching(String error) {
    return 'Error searching: $error';
  }

  @override
  String get recentSearch => 'Recent search';

  @override
  String get search => 'Search';

  @override
  String get language => 'Language';

  @override
  String get languageSubtitle => 'Choose app language';

  @override
  String get english => 'English';

  @override
  String get german => 'German';

  @override
  String get chinese => 'Chinese (Simplified)';

  @override
  String get systemDefault => 'System Default';

  @override
  String get subscription => 'Subscription';

  @override
  String get subscriptionSubtitle => 'Manage your subscription';

  @override
  String get currentPlan => 'Current Plan';

  @override
  String get freePlan => 'Free';

  @override
  String get premiumPlan => 'Premium';

  @override
  String get proPlan => 'Pro';

  @override
  String get subscriptionActive => 'Active';

  @override
  String get subscriptionExpired => 'Expired';

  @override
  String expiresOn(String date) {
    return 'Expires on $date';
  }

  @override
  String get restorePurchases => 'Restore Purchases';

  @override
  String get restoringPurchases => 'Restoring...';

  @override
  String get purchasesRestored => 'Purchases restored successfully';

  @override
  String get noPurchasesToRestore => 'No purchases to restore';

  @override
  String restoreError(String error) {
    return 'Error restoring purchases: $error';
  }

  @override
  String get manageSubscription => 'Manage Subscription';

  @override
  String get upgradeToPremium => 'Upgrade to Premium';

  @override
  String get tapToChangeLocation => 'Tap to change location';

  @override
  String get currentLocation => 'Current Location';

  @override
  String get checkingStarRegistry => 'Checking star registry...';

  @override
  String get starNotYetNamed => 'This star is not yet named';

  @override
  String get giveUniqueNameHint =>
      'Give it a unique name that will be visible in the sky';

  @override
  String get nameThisStar => 'Name this Star';

  @override
  String get viewStarIn3D => 'View Star in 3D';

  @override
  String get catalogId => 'Catalog ID';

  @override
  String get atmosphereButton => 'Atmosphere';

  @override
  String get movementButton => 'Movement';

  @override
  String get searchPlaceholder => 'Search for a star or object...';

  @override
  String get onboardingExploreUniverse =>
      'Explore the universe from your pocket';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingSkipForNow => 'Skip for now';

  @override
  String get onboardingMaybeLater => 'Maybe Later';

  @override
  String get onboardingRequesting => 'Requesting...';

  @override
  String get locationAccessTitle => 'Location Access';

  @override
  String get locationAccessSubtitle =>
      'Allow location access to see the sky exactly as it appears from your location';

  @override
  String get locationAccuratePositions => 'Accurate Star Positions';

  @override
  String get locationAccuratePositionsDesc =>
      'See stars as they appear from your exact location';

  @override
  String get locationCompassNav => 'Compass Navigation';

  @override
  String get locationCompassNavDesc =>
      'Point your phone to find stars in the sky';

  @override
  String get locationRiseSetTimes => 'Rise & Set Times';

  @override
  String get locationRiseSetTimesDesc =>
      'Know when celestial objects are visible at your location';

  @override
  String get locationPrivacyNotice =>
      'Your location is only used locally and never shared.';

  @override
  String get locationConfirmedTitle => 'Location Confirmed';

  @override
  String get locationConfirmedSubtitle =>
      'Your sky view will be customized for your location';

  @override
  String get locationOpenSettings => 'Open Settings';

  @override
  String get locationGettingLocation => 'Getting Location...';

  @override
  String get locationServicesDisabled =>
      'Location services are disabled. Please enable them in settings.';

  @override
  String get locationFailedBrowser =>
      'Failed to get location. Please allow location access in your browser.';

  @override
  String get notificationTitle => 'Stay Updated';

  @override
  String get notificationSubtitle =>
      'Get notified about celestial events and optimal viewing conditions';

  @override
  String get notificationMoonPhase => 'Moon Phase Alerts';

  @override
  String get notificationMoonPhaseDesc => 'Know the best nights for stargazing';

  @override
  String get notificationCelestialEvents => 'Celestial Events';

  @override
  String get notificationCelestialEventsDesc =>
      'Never miss meteor showers and eclipses';

  @override
  String get notificationVisibility => 'Visibility Alerts';

  @override
  String get notificationVisibilityDesc =>
      'Get notified when planets are best visible';

  @override
  String get notificationPrivacyNotice =>
      'You can change notification settings anytime in the app.';

  @override
  String get attTitle => 'Privacy & Tracking';

  @override
  String get attSubtitle =>
      'Allow tracking to help us improve your experience and show you relevant content';

  @override
  String get attImproveApp => 'Improve the App';

  @override
  String get attImproveAppDesc =>
      'Help us understand how you use the app to make it better';

  @override
  String get attRelevantContent => 'Relevant Content';

  @override
  String get attRelevantContentDesc =>
      'See recommendations tailored to your interests';

  @override
  String get attPrivacyMatters => 'Your Privacy Matters';

  @override
  String get attPrivacyMattersDesc =>
      'We never sell your personal data to third parties';

  @override
  String get attPrivacyNotice =>
      'You can change this setting anytime in iOS Settings > Privacy > Tracking.';

  @override
  String get starRegTitle => 'Find Your Star';

  @override
  String get starRegSubtitle =>
      'Enter your star registration number to locate your named star in the sky';

  @override
  String get starRegFindButton => 'Find My Star';

  @override
  String get starRegNoStarYet => 'I didn\'t name a star yet';

  @override
  String get starRegNameAStar => 'Name a Star';

  @override
  String get starRegEnterNumber => 'Please enter a registration number';

  @override
  String get starRegInvalidFormat => 'Invalid format. Use: XXXX-XXXXX-XXXXXXXX';

  @override
  String get starRegNotFound =>
      'Star not found. Please check your registration number.';

  @override
  String get starRegSearchFailed => 'Failed to search. Please try again.';
}
