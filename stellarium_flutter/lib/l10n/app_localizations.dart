import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Night Sky Guide'**
  String get appTitle;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @myStars.
  ///
  /// In en, this message translates to:
  /// **'My Stars'**
  String get myStars;

  /// No description provided for @myStarsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Saved locations and favorites'**
  String get myStarsSubtitle;

  /// No description provided for @timeLocation.
  ///
  /// In en, this message translates to:
  /// **'Time & Location'**
  String get timeLocation;

  /// No description provided for @timeLocationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set observation time and place'**
  String get timeLocationSubtitle;

  /// No description provided for @visualEffects.
  ///
  /// In en, this message translates to:
  /// **'Visual Effects'**
  String get visualEffects;

  /// No description provided for @visualEffectsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sky display, objects, and grids'**
  String get visualEffectsSubtitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App preferences'**
  String get settingsSubtitle;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'LOCATION'**
  String get location;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'TIME'**
  String get time;

  /// No description provided for @searchCityAddress.
  ///
  /// In en, this message translates to:
  /// **'Search city, address...'**
  String get searchCityAddress;

  /// No description provided for @useMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use My Location'**
  String get useMyLocation;

  /// No description provided for @detecting.
  ///
  /// In en, this message translates to:
  /// **'Detecting...'**
  String get detecting;

  /// No description provided for @unknownLocation.
  ///
  /// In en, this message translates to:
  /// **'Unknown location'**
  String get unknownLocation;

  /// No description provided for @setToNow.
  ///
  /// In en, this message translates to:
  /// **'Set to Now'**
  String get setToNow;

  /// No description provided for @applyChanges.
  ///
  /// In en, this message translates to:
  /// **'Apply Changes'**
  String get applyChanges;

  /// No description provided for @setTime.
  ///
  /// In en, this message translates to:
  /// **'Set Time'**
  String get setTime;

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get now;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @savedToMyStars.
  ///
  /// In en, this message translates to:
  /// **'Saved to My Stars'**
  String get savedToMyStars;

  /// No description provided for @removedFromMyStars.
  ///
  /// In en, this message translates to:
  /// **'Removed from My Stars'**
  String get removedFromMyStars;

  /// No description provided for @pointAtStar.
  ///
  /// In en, this message translates to:
  /// **'Point at Star'**
  String get pointAtStar;

  /// No description provided for @removeFromMyStars.
  ///
  /// In en, this message translates to:
  /// **'Remove from My Stars'**
  String get removeFromMyStars;

  /// No description provided for @saveToMyStars.
  ///
  /// In en, this message translates to:
  /// **'Save to My Stars'**
  String get saveToMyStars;

  /// No description provided for @noSavedStarsYet.
  ///
  /// In en, this message translates to:
  /// **'No saved stars yet'**
  String get noSavedStarsYet;

  /// No description provided for @tapStarIconHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the star icon on any star\'s info sheet to save it here'**
  String get tapStarIconHint;

  /// No description provided for @starRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} removed'**
  String starRemoved(String name);

  /// No description provided for @registration.
  ///
  /// In en, this message translates to:
  /// **'REGISTRATION'**
  String get registration;

  /// No description provided for @registeredTo.
  ///
  /// In en, this message translates to:
  /// **'Registered to'**
  String get registeredTo;

  /// No description provided for @registrationDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get registrationDate;

  /// No description provided for @registrationNumber.
  ///
  /// In en, this message translates to:
  /// **'Registration #'**
  String get registrationNumber;

  /// No description provided for @registry.
  ///
  /// In en, this message translates to:
  /// **'Registry'**
  String get registry;

  /// No description provided for @properties.
  ///
  /// In en, this message translates to:
  /// **'PROPERTIES'**
  String get properties;

  /// No description provided for @coordinates.
  ///
  /// In en, this message translates to:
  /// **'COORDINATES'**
  String get coordinates;

  /// No description provided for @scientificName.
  ///
  /// In en, this message translates to:
  /// **'Scientific Name'**
  String get scientificName;

  /// No description provided for @magnitude.
  ///
  /// In en, this message translates to:
  /// **'Magnitude'**
  String get magnitude;

  /// No description provided for @spectralType.
  ///
  /// In en, this message translates to:
  /// **'Spectral Type'**
  String get spectralType;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @parallax.
  ///
  /// In en, this message translates to:
  /// **'Parallax'**
  String get parallax;

  /// No description provided for @objectType.
  ///
  /// In en, this message translates to:
  /// **'Object Type'**
  String get objectType;

  /// No description provided for @doubleMultipleStar.
  ///
  /// In en, this message translates to:
  /// **'Double/Multiple Star'**
  String get doubleMultipleStar;

  /// No description provided for @rightAscension.
  ///
  /// In en, this message translates to:
  /// **'Right Ascension'**
  String get rightAscension;

  /// No description provided for @declination.
  ///
  /// In en, this message translates to:
  /// **'Declination'**
  String get declination;

  /// No description provided for @skyDisplay.
  ///
  /// In en, this message translates to:
  /// **'Sky Display'**
  String get skyDisplay;

  /// No description provided for @celestialObjects.
  ///
  /// In en, this message translates to:
  /// **'Celestial Objects'**
  String get celestialObjects;

  /// No description provided for @gridLines.
  ///
  /// In en, this message translates to:
  /// **'Grids & Lines'**
  String get gridLines;

  /// No description provided for @displayOptions.
  ///
  /// In en, this message translates to:
  /// **'Display Options'**
  String get displayOptions;

  /// No description provided for @constellationLines.
  ///
  /// In en, this message translates to:
  /// **'Constellation Lines'**
  String get constellationLines;

  /// No description provided for @constellationLinesDesc.
  ///
  /// In en, this message translates to:
  /// **'Show lines connecting stars in constellations'**
  String get constellationLinesDesc;

  /// No description provided for @constellationNames.
  ///
  /// In en, this message translates to:
  /// **'Constellation Names'**
  String get constellationNames;

  /// No description provided for @constellationNamesDesc.
  ///
  /// In en, this message translates to:
  /// **'Show constellation name labels'**
  String get constellationNamesDesc;

  /// No description provided for @constellationArt.
  ///
  /// In en, this message translates to:
  /// **'Constellation Art'**
  String get constellationArt;

  /// No description provided for @constellationArtDesc.
  ///
  /// In en, this message translates to:
  /// **'Show artistic constellation illustrations'**
  String get constellationArtDesc;

  /// No description provided for @atmosphere.
  ///
  /// In en, this message translates to:
  /// **'Atmosphere'**
  String get atmosphere;

  /// No description provided for @atmosphereDesc.
  ///
  /// In en, this message translates to:
  /// **'Show atmospheric effects and sky glow'**
  String get atmosphereDesc;

  /// No description provided for @landscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get landscape;

  /// No description provided for @landscapeDesc.
  ///
  /// In en, this message translates to:
  /// **'Show ground/horizon landscape'**
  String get landscapeDesc;

  /// No description provided for @landscapeFog.
  ///
  /// In en, this message translates to:
  /// **'Landscape Fog'**
  String get landscapeFog;

  /// No description provided for @landscapeFogDesc.
  ///
  /// In en, this message translates to:
  /// **'Show fog effect on landscape'**
  String get landscapeFogDesc;

  /// No description provided for @milkyWay.
  ///
  /// In en, this message translates to:
  /// **'Milky Way'**
  String get milkyWay;

  /// No description provided for @milkyWayDesc.
  ///
  /// In en, this message translates to:
  /// **'Show the Milky Way galaxy'**
  String get milkyWayDesc;

  /// No description provided for @dssBackground.
  ///
  /// In en, this message translates to:
  /// **'DSS Background'**
  String get dssBackground;

  /// No description provided for @dssBackgroundDesc.
  ///
  /// In en, this message translates to:
  /// **'Show Digital Sky Survey background images'**
  String get dssBackgroundDesc;

  /// No description provided for @stars.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get stars;

  /// No description provided for @starsDesc.
  ///
  /// In en, this message translates to:
  /// **'Show stars in the sky'**
  String get starsDesc;

  /// No description provided for @planets.
  ///
  /// In en, this message translates to:
  /// **'Planets'**
  String get planets;

  /// No description provided for @planetsDesc.
  ///
  /// In en, this message translates to:
  /// **'Show planets and solar system bodies'**
  String get planetsDesc;

  /// No description provided for @deepSkyObjects.
  ///
  /// In en, this message translates to:
  /// **'Deep Sky Objects'**
  String get deepSkyObjects;

  /// No description provided for @deepSkyObjectsDesc.
  ///
  /// In en, this message translates to:
  /// **'Show nebulae, galaxies, and star clusters'**
  String get deepSkyObjectsDesc;

  /// No description provided for @satellites.
  ///
  /// In en, this message translates to:
  /// **'Satellites'**
  String get satellites;

  /// No description provided for @satellitesDesc.
  ///
  /// In en, this message translates to:
  /// **'Show artificial satellites'**
  String get satellitesDesc;

  /// No description provided for @azimuthalGrid.
  ///
  /// In en, this message translates to:
  /// **'Azimuthal Grid'**
  String get azimuthalGrid;

  /// No description provided for @azimuthalGridDesc.
  ///
  /// In en, this message translates to:
  /// **'Show altitude/azimuth coordinate grid'**
  String get azimuthalGridDesc;

  /// No description provided for @equatorialGrid.
  ///
  /// In en, this message translates to:
  /// **'Equatorial Grid'**
  String get equatorialGrid;

  /// No description provided for @equatorialGridDesc.
  ///
  /// In en, this message translates to:
  /// **'Show right ascension/declination grid'**
  String get equatorialGridDesc;

  /// No description provided for @equatorialJ2000Grid.
  ///
  /// In en, this message translates to:
  /// **'Equatorial J2000 Grid'**
  String get equatorialJ2000Grid;

  /// No description provided for @equatorialJ2000GridDesc.
  ///
  /// In en, this message translates to:
  /// **'Show J2000 epoch equatorial coordinates'**
  String get equatorialJ2000GridDesc;

  /// No description provided for @meridianLine.
  ///
  /// In en, this message translates to:
  /// **'Meridian Line'**
  String get meridianLine;

  /// No description provided for @meridianLineDesc.
  ///
  /// In en, this message translates to:
  /// **'Show the meridian (north-south through zenith)'**
  String get meridianLineDesc;

  /// No description provided for @eclipticLine.
  ///
  /// In en, this message translates to:
  /// **'Ecliptic Line'**
  String get eclipticLine;

  /// No description provided for @eclipticLineDesc.
  ///
  /// In en, this message translates to:
  /// **'Show the ecliptic (sun\'s apparent path)'**
  String get eclipticLineDesc;

  /// No description provided for @nightMode.
  ///
  /// In en, this message translates to:
  /// **'Night Mode'**
  String get nightMode;

  /// No description provided for @nightModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Red-shift display to preserve night vision'**
  String get nightModeDesc;

  /// No description provided for @loadingSkyView.
  ///
  /// In en, this message translates to:
  /// **'Loading sky view...'**
  String get loadingSkyView;

  /// No description provided for @failedToLoadSkyView.
  ///
  /// In en, this message translates to:
  /// **'Failed to load sky view'**
  String get failedToLoadSkyView;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get locationPermissionDenied;

  /// No description provided for @locationPermissionPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission permanently denied. Please enable in Settings.'**
  String get locationPermissionPermanentlyDenied;

  /// No description provided for @errorGettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Error getting location: {error}'**
  String errorGettingLocation(String error);

  /// No description provided for @registrationNotFound.
  ///
  /// In en, this message translates to:
  /// **'Registration number \"{number}\" not found'**
  String registrationNotFound(String number);

  /// No description provided for @errorSearching.
  ///
  /// In en, this message translates to:
  /// **'Error searching: {error}'**
  String errorSearching(String error);

  /// No description provided for @recentSearch.
  ///
  /// In en, this message translates to:
  /// **'Recent search'**
  String get recentSearch;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose app language'**
  String get languageSubtitle;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @german.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get german;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese (Simplified)'**
  String get chinese;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// No description provided for @subscriptionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your subscription'**
  String get subscriptionSubtitle;

  /// No description provided for @currentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current Plan'**
  String get currentPlan;

  /// No description provided for @freePlan.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get freePlan;

  /// No description provided for @premiumPlan.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premiumPlan;

  /// No description provided for @proPlan.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get proPlan;

  /// No description provided for @subscriptionActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get subscriptionActive;

  /// No description provided for @subscriptionExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get subscriptionExpired;

  /// No description provided for @expiresOn.
  ///
  /// In en, this message translates to:
  /// **'Expires on {date}'**
  String expiresOn(String date);

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restorePurchases;

  /// No description provided for @restoringPurchases.
  ///
  /// In en, this message translates to:
  /// **'Restoring...'**
  String get restoringPurchases;

  /// No description provided for @purchasesRestored.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored successfully'**
  String get purchasesRestored;

  /// No description provided for @noPurchasesToRestore.
  ///
  /// In en, this message translates to:
  /// **'No purchases to restore'**
  String get noPurchasesToRestore;

  /// No description provided for @restoreError.
  ///
  /// In en, this message translates to:
  /// **'Error restoring purchases: {error}'**
  String restoreError(String error);

  /// No description provided for @manageSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get manageSubscription;

  /// No description provided for @upgradeToPremium.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium'**
  String get upgradeToPremium;

  /// No description provided for @tapToChangeLocation.
  ///
  /// In en, this message translates to:
  /// **'Tap to change location'**
  String get tapToChangeLocation;

  /// No description provided for @currentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current Location'**
  String get currentLocation;

  /// No description provided for @checkingStarRegistry.
  ///
  /// In en, this message translates to:
  /// **'Checking star registry...'**
  String get checkingStarRegistry;

  /// No description provided for @starNotYetNamed.
  ///
  /// In en, this message translates to:
  /// **'This star is not yet named'**
  String get starNotYetNamed;

  /// No description provided for @giveUniqueNameHint.
  ///
  /// In en, this message translates to:
  /// **'Give it a unique name that will be visible in the sky'**
  String get giveUniqueNameHint;

  /// No description provided for @nameThisStar.
  ///
  /// In en, this message translates to:
  /// **'Name this Star'**
  String get nameThisStar;

  /// No description provided for @viewStarIn3D.
  ///
  /// In en, this message translates to:
  /// **'View Star in 3D'**
  String get viewStarIn3D;

  /// No description provided for @catalogId.
  ///
  /// In en, this message translates to:
  /// **'Catalog ID'**
  String get catalogId;

  /// No description provided for @atmosphereButton.
  ///
  /// In en, this message translates to:
  /// **'Atmosphere'**
  String get atmosphereButton;

  /// No description provided for @movementButton.
  ///
  /// In en, this message translates to:
  /// **'Movement'**
  String get movementButton;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search for a star or object...'**
  String get searchPlaceholder;

  /// No description provided for @onboardingExploreUniverse.
  ///
  /// In en, this message translates to:
  /// **'Explore the universe from your pocket'**
  String get onboardingExploreUniverse;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinue;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingSkipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get onboardingSkipForNow;

  /// No description provided for @onboardingMaybeLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe Later'**
  String get onboardingMaybeLater;

  /// No description provided for @onboardingRequesting.
  ///
  /// In en, this message translates to:
  /// **'Requesting...'**
  String get onboardingRequesting;

  /// No description provided for @locationAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Location Access'**
  String get locationAccessTitle;

  /// No description provided for @locationAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow location access to see the sky exactly as it appears from your location'**
  String get locationAccessSubtitle;

  /// No description provided for @locationAccuratePositions.
  ///
  /// In en, this message translates to:
  /// **'Accurate Star Positions'**
  String get locationAccuratePositions;

  /// No description provided for @locationAccuratePositionsDesc.
  ///
  /// In en, this message translates to:
  /// **'See stars as they appear from your exact location'**
  String get locationAccuratePositionsDesc;

  /// No description provided for @locationCompassNav.
  ///
  /// In en, this message translates to:
  /// **'Compass Navigation'**
  String get locationCompassNav;

  /// No description provided for @locationCompassNavDesc.
  ///
  /// In en, this message translates to:
  /// **'Point your phone to find stars in the sky'**
  String get locationCompassNavDesc;

  /// No description provided for @locationRiseSetTimes.
  ///
  /// In en, this message translates to:
  /// **'Rise & Set Times'**
  String get locationRiseSetTimes;

  /// No description provided for @locationRiseSetTimesDesc.
  ///
  /// In en, this message translates to:
  /// **'Know when celestial objects are visible at your location'**
  String get locationRiseSetTimesDesc;

  /// No description provided for @locationPrivacyNotice.
  ///
  /// In en, this message translates to:
  /// **'Your location is only used locally and never shared.'**
  String get locationPrivacyNotice;

  /// No description provided for @locationConfirmedTitle.
  ///
  /// In en, this message translates to:
  /// **'Location Confirmed'**
  String get locationConfirmedTitle;

  /// No description provided for @locationConfirmedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your sky view will be customized for your location'**
  String get locationConfirmedSubtitle;

  /// No description provided for @locationOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get locationOpenSettings;

  /// No description provided for @locationGettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Getting Location...'**
  String get locationGettingLocation;

  /// No description provided for @locationServicesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled. Please enable them in settings.'**
  String get locationServicesDisabled;

  /// No description provided for @locationFailedBrowser.
  ///
  /// In en, this message translates to:
  /// **'Failed to get location. Please allow location access in your browser.'**
  String get locationFailedBrowser;

  /// No description provided for @notificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Stay Updated'**
  String get notificationTitle;

  /// No description provided for @notificationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get notified about celestial events and optimal viewing conditions'**
  String get notificationSubtitle;

  /// No description provided for @notificationMoonPhase.
  ///
  /// In en, this message translates to:
  /// **'Moon Phase Alerts'**
  String get notificationMoonPhase;

  /// No description provided for @notificationMoonPhaseDesc.
  ///
  /// In en, this message translates to:
  /// **'Know the best nights for stargazing'**
  String get notificationMoonPhaseDesc;

  /// No description provided for @notificationCelestialEvents.
  ///
  /// In en, this message translates to:
  /// **'Celestial Events'**
  String get notificationCelestialEvents;

  /// No description provided for @notificationCelestialEventsDesc.
  ///
  /// In en, this message translates to:
  /// **'Never miss meteor showers and eclipses'**
  String get notificationCelestialEventsDesc;

  /// No description provided for @notificationVisibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility Alerts'**
  String get notificationVisibility;

  /// No description provided for @notificationVisibilityDesc.
  ///
  /// In en, this message translates to:
  /// **'Get notified when planets are best visible'**
  String get notificationVisibilityDesc;

  /// No description provided for @notificationPrivacyNotice.
  ///
  /// In en, this message translates to:
  /// **'You can change notification settings anytime in the app.'**
  String get notificationPrivacyNotice;

  /// No description provided for @attTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Tracking'**
  String get attTitle;

  /// No description provided for @attSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow tracking to help us improve your experience and show you relevant content'**
  String get attSubtitle;

  /// No description provided for @attImproveApp.
  ///
  /// In en, this message translates to:
  /// **'Improve the App'**
  String get attImproveApp;

  /// No description provided for @attImproveAppDesc.
  ///
  /// In en, this message translates to:
  /// **'Help us understand how you use the app to make it better'**
  String get attImproveAppDesc;

  /// No description provided for @attRelevantContent.
  ///
  /// In en, this message translates to:
  /// **'Relevant Content'**
  String get attRelevantContent;

  /// No description provided for @attRelevantContentDesc.
  ///
  /// In en, this message translates to:
  /// **'See recommendations tailored to your interests'**
  String get attRelevantContentDesc;

  /// No description provided for @attPrivacyMatters.
  ///
  /// In en, this message translates to:
  /// **'Your Privacy Matters'**
  String get attPrivacyMatters;

  /// No description provided for @attPrivacyMattersDesc.
  ///
  /// In en, this message translates to:
  /// **'We never sell your personal data to third parties'**
  String get attPrivacyMattersDesc;

  /// No description provided for @attPrivacyNotice.
  ///
  /// In en, this message translates to:
  /// **'You can change this setting anytime in iOS Settings > Privacy > Tracking.'**
  String get attPrivacyNotice;

  /// No description provided for @starRegTitle.
  ///
  /// In en, this message translates to:
  /// **'Find Your Star'**
  String get starRegTitle;

  /// No description provided for @starRegSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your star registration number to locate your named star in the sky'**
  String get starRegSubtitle;

  /// No description provided for @starRegFindButton.
  ///
  /// In en, this message translates to:
  /// **'Find My Star'**
  String get starRegFindButton;

  /// No description provided for @starRegNoStarYet.
  ///
  /// In en, this message translates to:
  /// **'I didn\'t name a star yet'**
  String get starRegNoStarYet;

  /// No description provided for @starRegNameAStar.
  ///
  /// In en, this message translates to:
  /// **'Name a Star'**
  String get starRegNameAStar;

  /// No description provided for @starRegEnterNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a registration number'**
  String get starRegEnterNumber;

  /// No description provided for @starRegInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid format. Use: XXXX-XXXXX-XXXXXXXX'**
  String get starRegInvalidFormat;

  /// No description provided for @starRegNotFound.
  ///
  /// In en, this message translates to:
  /// **'Star not found. Please check your registration number.'**
  String get starRegNotFound;

  /// No description provided for @starRegSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to search. Please try again.'**
  String get starRegSearchFailed;

  /// No description provided for @starRegRemoved.
  ///
  /// In en, this message translates to:
  /// **'The star has been removed from the registry. Reason: {reason}'**
  String starRegRemoved(String reason);

  /// No description provided for @scanCertificate.
  ///
  /// In en, this message translates to:
  /// **'Scan Certificate'**
  String get scanCertificate;

  /// No description provided for @scanningCertificate.
  ///
  /// In en, this message translates to:
  /// **'Scanning certificate...'**
  String get scanningCertificate;

  /// No description provided for @pointCameraAtCertificate.
  ///
  /// In en, this message translates to:
  /// **'Point camera at your certificate'**
  String get pointCameraAtCertificate;

  /// No description provided for @registrationNumberWillBeDetected.
  ///
  /// In en, this message translates to:
  /// **'The registration number will be detected automatically'**
  String get registrationNumberWillBeDetected;

  /// No description provided for @registrationNumberFound.
  ///
  /// In en, this message translates to:
  /// **'Number Found'**
  String get registrationNumberFound;

  /// No description provided for @searchForThisNumber.
  ///
  /// In en, this message translates to:
  /// **'Search for this registration number?'**
  String get searchForThisNumber;

  /// No description provided for @scanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan Again'**
  String get scanAgain;

  /// No description provided for @searchStar.
  ///
  /// In en, this message translates to:
  /// **'Search Star'**
  String get searchStar;

  /// No description provided for @enterManually.
  ///
  /// In en, this message translates to:
  /// **'Enter manually'**
  String get enterManually;

  /// No description provided for @enterRegistrationNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter Registration Number'**
  String get enterRegistrationNumber;

  /// No description provided for @registrationNumberHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 1234-56789-1234567'**
  String get registrationNumberHint;

  /// No description provided for @noRegistrationNumberFound.
  ///
  /// In en, this message translates to:
  /// **'No registration number found. Try again or enter manually.'**
  String get noRegistrationNumberFound;

  /// No description provided for @couldNotCaptureImage.
  ///
  /// In en, this message translates to:
  /// **'Could not capture image. Please try again.'**
  String get couldNotCaptureImage;

  /// No description provided for @showStarPath.
  ///
  /// In en, this message translates to:
  /// **'Show 24h Path'**
  String get showStarPath;

  /// No description provided for @hideStarPath.
  ///
  /// In en, this message translates to:
  /// **'Hide 24h Path'**
  String get hideStarPath;

  /// No description provided for @loaderQuote1.
  ///
  /// In en, this message translates to:
  /// **'Your personal window to the cosmos'**
  String get loaderQuote1;

  /// No description provided for @loaderQuote2.
  ///
  /// In en, this message translates to:
  /// **'Every star holds a name waiting to be given'**
  String get loaderQuote2;

  /// No description provided for @loaderQuote3.
  ///
  /// In en, this message translates to:
  /// **'The sky above you, charted and waiting'**
  String get loaderQuote3;

  /// No description provided for @loaderQuote4.
  ///
  /// In en, this message translates to:
  /// **'A name etched in light, forever yours'**
  String get loaderQuote4;

  /// No description provided for @loaderQuote5.
  ///
  /// In en, this message translates to:
  /// **'Millions of stars — one belongs to you'**
  String get loaderQuote5;

  /// No description provided for @loaderQuote6.
  ///
  /// In en, this message translates to:
  /// **'Where the ancient light meets your gaze'**
  String get loaderQuote6;

  /// No description provided for @loaderQuote7.
  ///
  /// In en, this message translates to:
  /// **'The universe remembers every name'**
  String get loaderQuote7;

  /// No description provided for @loaderQuote8.
  ///
  /// In en, this message translates to:
  /// **'Look up. Find your place among the stars.'**
  String get loaderQuote8;

  /// No description provided for @loaderStatus1.
  ///
  /// In en, this message translates to:
  /// **'Locating your coordinates'**
  String get loaderStatus1;

  /// No description provided for @loaderStatus2.
  ///
  /// In en, this message translates to:
  /// **'Mapping the celestial sphere'**
  String get loaderStatus2;

  /// No description provided for @loaderStatus3.
  ///
  /// In en, this message translates to:
  /// **'Charting visible constellations'**
  String get loaderStatus3;

  /// No description provided for @loaderStatus4.
  ///
  /// In en, this message translates to:
  /// **'Calculating star positions'**
  String get loaderStatus4;

  /// No description provided for @loaderStatus5.
  ///
  /// In en, this message translates to:
  /// **'Preparing your night sky'**
  String get loaderStatus5;

  /// No description provided for @visibilityCalculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating visibility...'**
  String get visibilityCalculating;

  /// No description provided for @visibilityVisibleNow.
  ///
  /// In en, this message translates to:
  /// **'Visible Now'**
  String get visibilityVisibleNow;

  /// No description provided for @visibilityTonight.
  ///
  /// In en, this message translates to:
  /// **'Tonight'**
  String get visibilityTonight;

  /// No description provided for @visibilityVisible.
  ///
  /// In en, this message translates to:
  /// **'visible'**
  String get visibilityVisible;

  /// No description provided for @visibilitySince.
  ///
  /// In en, this message translates to:
  /// **'SINCE'**
  String get visibilitySince;

  /// No description provided for @visibilityFrom.
  ///
  /// In en, this message translates to:
  /// **'FROM'**
  String get visibilityFrom;

  /// No description provided for @visibilityUntil.
  ///
  /// In en, this message translates to:
  /// **'UNTIL'**
  String get visibilityUntil;

  /// No description provided for @notificationAlertTitle.
  ///
  /// In en, this message translates to:
  /// **'Visibility Alert'**
  String get notificationAlertTitle;

  /// No description provided for @notificationAlertSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get notified when star rises'**
  String get notificationAlertSubtitle;

  /// No description provided for @visibilityStatusNeverVisible.
  ///
  /// In en, this message translates to:
  /// **'Never visible'**
  String get visibilityStatusNeverVisible;

  /// No description provided for @visibilityStatusVisibleNow.
  ///
  /// In en, this message translates to:
  /// **'Visible now'**
  String get visibilityStatusVisibleNow;

  /// No description provided for @visibilityStatusWaitForDark.
  ///
  /// In en, this message translates to:
  /// **'Wait for dark'**
  String get visibilityStatusWaitForDark;

  /// No description provided for @visibilityStatusBelowHorizon.
  ///
  /// In en, this message translates to:
  /// **'Below horizon'**
  String get visibilityStatusBelowHorizon;

  /// No description provided for @visibilityNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get visibilityNow;

  /// No description provided for @visibilityStatusTonight.
  ///
  /// In en, this message translates to:
  /// **'Tonight {time}'**
  String visibilityStatusTonight(String time);

  /// No description provided for @visibilityStatusTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow {time}'**
  String visibilityStatusTomorrow(String time);

  /// No description provided for @visibilityStatusInDays.
  ///
  /// In en, this message translates to:
  /// **'{days}d {hours}h'**
  String visibilityStatusInDays(int days, int hours);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
