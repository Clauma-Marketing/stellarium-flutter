// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Night Sky Guide';

  @override
  String get menu => 'Menü';

  @override
  String get myStars => 'Meine Sterne';

  @override
  String get myStarsSubtitle => 'Gespeicherte Orte und Favoriten';

  @override
  String get timeLocation => 'Zeit & Ort';

  @override
  String get timeLocationSubtitle => 'Beobachtungszeit und -ort einstellen';

  @override
  String get visualEffects => 'Visuelle Effekte';

  @override
  String get visualEffectsSubtitle => 'Himmelsanzeige, Objekte und Gitter';

  @override
  String get settings => 'Einstellungen';

  @override
  String get settingsSubtitle => 'App-Einstellungen';

  @override
  String get location => 'ORT';

  @override
  String get time => 'ZEIT';

  @override
  String get searchCityAddress => 'Stadt, Adresse suchen...';

  @override
  String get useMyLocation => 'Meinen Standort verwenden';

  @override
  String get detecting => 'Wird ermittelt...';

  @override
  String get unknownLocation => 'Unbekannter Ort';

  @override
  String get setToNow => 'Auf Jetzt setzen';

  @override
  String get applyChanges => 'Änderungen übernehmen';

  @override
  String get setTime => 'Zeit einstellen';

  @override
  String get now => 'Jetzt';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get apply => 'Anwenden';

  @override
  String get back => 'Zurück';

  @override
  String get save => 'Speichern';

  @override
  String get saved => 'Gespeichert';

  @override
  String get savedToMyStars => 'Zu Meine Sterne hinzugefügt';

  @override
  String get removedFromMyStars => 'Aus Meine Sterne entfernt';

  @override
  String get pointAtStar => 'Lokalisieren';

  @override
  String get removeFromMyStars => 'Aus Meine Sterne entfernen';

  @override
  String get saveToMyStars => 'Zu Meine Sterne hinzufügen';

  @override
  String get noSavedStarsYet => 'Noch keine Sterne gespeichert';

  @override
  String get tapStarIconHint =>
      'Tippe auf das Stern-Symbol in der Stern-Info, um ihn hier zu speichern';

  @override
  String starRemoved(String name) {
    return '$name entfernt';
  }

  @override
  String get registration => 'REGISTRIERUNG';

  @override
  String get registeredTo => 'Registriert auf';

  @override
  String get registrationDate => 'Datum';

  @override
  String get registrationNumber => 'Registrierungsnr.';

  @override
  String get registry => 'Register';

  @override
  String get properties => 'EIGENSCHAFTEN';

  @override
  String get coordinates => 'KOORDINATEN';

  @override
  String get scientificName => 'Wissenschaftlicher Name';

  @override
  String get magnitude => 'Helligkeit';

  @override
  String get spectralType => 'Spektraltyp';

  @override
  String get distance => 'Entfernung';

  @override
  String get parallax => 'Parallaxe';

  @override
  String get objectType => 'Objekttyp';

  @override
  String get doubleMultipleStar => 'Doppel-/Mehrfachstern';

  @override
  String get rightAscension => 'Rektaszension';

  @override
  String get declination => 'Deklination';

  @override
  String get skyDisplay => 'Himmelsanzeige';

  @override
  String get celestialObjects => 'Himmelsobjekte';

  @override
  String get gridLines => 'Gitter & Linien';

  @override
  String get displayOptions => 'Anzeigeoptionen';

  @override
  String get constellationLines => 'Sternbildlinien';

  @override
  String get constellationLinesDesc =>
      'Linien zwischen Sternen in Sternbildern anzeigen';

  @override
  String get constellationNames => 'Sternbildnamen';

  @override
  String get constellationNamesDesc =>
      'Beschriftungen der Sternbilder anzeigen';

  @override
  String get constellationArt => 'Sternbildkunst';

  @override
  String get constellationArtDesc =>
      'Künstlerische Sternbilddarstellungen anzeigen';

  @override
  String get atmosphere => 'Atmosphäre';

  @override
  String get atmosphereDesc =>
      'Atmosphärische Effekte und Himmelslicht anzeigen';

  @override
  String get landscape => 'Landschaft';

  @override
  String get landscapeDesc => 'Boden/Horizont-Landschaft anzeigen';

  @override
  String get landscapeFog => 'Landschaftsnebel';

  @override
  String get landscapeFogDesc => 'Nebeleffekt auf der Landschaft anzeigen';

  @override
  String get milkyWay => 'Milchstraße';

  @override
  String get milkyWayDesc => 'Die Milchstraße anzeigen';

  @override
  String get dssBackground => 'DSS-Hintergrund';

  @override
  String get dssBackgroundDesc =>
      'Digital Sky Survey Hintergrundbilder anzeigen';

  @override
  String get stars => 'Sterne';

  @override
  String get starsDesc => 'Sterne am Himmel anzeigen';

  @override
  String get planets => 'Planeten';

  @override
  String get planetsDesc => 'Planeten und Sonnensystemkörper anzeigen';

  @override
  String get deepSkyObjects => 'Deep-Sky-Objekte';

  @override
  String get deepSkyObjectsDesc => 'Nebel, Galaxien und Sternhaufen anzeigen';

  @override
  String get satellites => 'Satelliten';

  @override
  String get satellitesDesc => 'Künstliche Satelliten anzeigen';

  @override
  String get azimuthalGrid => 'Azimutales Gitter';

  @override
  String get azimuthalGridDesc => 'Höhen-/Azimut-Koordinatengitter anzeigen';

  @override
  String get equatorialGrid => 'Äquatoriales Gitter';

  @override
  String get equatorialGridDesc =>
      'Rektaszensions-/Deklinationsgitter anzeigen';

  @override
  String get equatorialJ2000Grid => 'Äquatoriales J2000 Gitter';

  @override
  String get equatorialJ2000GridDesc =>
      'J2000-Epoche Äquatorialkoordinaten anzeigen';

  @override
  String get meridianLine => 'Meridianlinie';

  @override
  String get meridianLineDesc => 'Meridian anzeigen (Nord-Süd durch Zenit)';

  @override
  String get eclipticLine => 'Ekliptiklinie';

  @override
  String get eclipticLineDesc => 'Ekliptik anzeigen (scheinbare Sonnenbahn)';

  @override
  String get nightMode => 'Nachtmodus';

  @override
  String get nightModeDesc => 'Rotverschiebung zur Erhaltung der Nachtsicht';

  @override
  String get loadingSkyView => 'Himmelsansicht wird geladen...';

  @override
  String get failedToLoadSkyView =>
      'Himmelsansicht konnte nicht geladen werden';

  @override
  String get locationPermissionDenied => 'Standortberechtigung verweigert';

  @override
  String get locationPermissionPermanentlyDenied =>
      'Standortberechtigung dauerhaft verweigert. Bitte in den Einstellungen aktivieren.';

  @override
  String errorGettingLocation(String error) {
    return 'Fehler beim Abrufen des Standorts: $error';
  }

  @override
  String registrationNotFound(String number) {
    return 'Registrierungsnummer \"$number\" nicht gefunden';
  }

  @override
  String errorSearching(String error) {
    return 'Fehler bei der Suche: $error';
  }

  @override
  String get recentSearch => 'Letzte Suche';

  @override
  String get search => 'Suchen';

  @override
  String get language => 'Sprache';

  @override
  String get languageSubtitle => 'App-Sprache wählen';

  @override
  String get english => 'Englisch';

  @override
  String get german => 'Deutsch';

  @override
  String get chinese => 'Chinesisch (Vereinfacht)';

  @override
  String get systemDefault => 'Systemstandard';

  @override
  String get subscription => 'Abonnement';

  @override
  String get subscriptionSubtitle => 'Abonnement verwalten';

  @override
  String get currentPlan => 'Aktueller Plan';

  @override
  String get freePlan => 'Kostenlos';

  @override
  String get premiumPlan => 'Premium';

  @override
  String get proPlan => 'Pro';

  @override
  String get subscriptionActive => 'Aktiv';

  @override
  String get subscriptionExpired => 'Abgelaufen';

  @override
  String expiresOn(String date) {
    return 'Läuft ab am $date';
  }

  @override
  String get restorePurchases => 'Käufe wiederherstellen';

  @override
  String get restoringPurchases => 'Wird wiederhergestellt...';

  @override
  String get purchasesRestored => 'Käufe erfolgreich wiederhergestellt';

  @override
  String get noPurchasesToRestore => 'Keine Käufe zum Wiederherstellen';

  @override
  String restoreError(String error) {
    return 'Fehler beim Wiederherstellen: $error';
  }

  @override
  String get manageSubscription => 'Abonnement verwalten';

  @override
  String get upgradeToPremium => 'Auf Premium upgraden';

  @override
  String get tapToChangeLocation => 'Tippen zum Ändern';

  @override
  String get currentLocation => 'Aktueller Standort';

  @override
  String get checkingStarRegistry => 'Sternregister wird überprüft...';

  @override
  String get starNotYetNamed => 'Dieser Stern hat noch keinen Namen';

  @override
  String get giveUniqueNameHint =>
      'Gib ihm einen einzigartigen Namen, der am Himmel sichtbar sein wird';

  @override
  String get nameThisStar => 'Stern benennen';

  @override
  String get viewStarIn3D => '3D Ansicht';

  @override
  String get catalogId => 'Katalog-ID';

  @override
  String get atmosphereButton => 'Atmosphäre';

  @override
  String get movementButton => 'Bewegung';

  @override
  String get searchPlaceholder => 'Stern oder Objekt suchen...';

  @override
  String get onboardingExploreUniverse =>
      'Entdecke das Universum aus deiner Tasche';

  @override
  String get onboardingGetStarted => 'Los geht\'s';

  @override
  String get onboardingContinue => 'Weiter';

  @override
  String get onboardingSkip => 'Überspringen';

  @override
  String get onboardingSkipForNow => 'Vorerst überspringen';

  @override
  String get onboardingMaybeLater => 'Vielleicht später';

  @override
  String get onboardingRequesting => 'Anfrage läuft...';

  @override
  String get locationAccessTitle => 'Standortzugriff';

  @override
  String get locationAccessSubtitle =>
      'Erlaube Standortzugriff, um den Himmel genau so zu sehen, wie er von deinem Standort aus erscheint';

  @override
  String get locationAccuratePositions => 'Genaue Sternpositionen';

  @override
  String get locationAccuratePositionsDesc =>
      'Sieh Sterne so, wie sie von deinem genauen Standort aus erscheinen';

  @override
  String get locationCompassNav => 'Kompass-Navigation';

  @override
  String get locationCompassNavDesc =>
      'Richte dein Handy aus, um Sterne am Himmel zu finden';

  @override
  String get locationRiseSetTimes => 'Auf- & Untergangszeiten';

  @override
  String get locationRiseSetTimesDesc =>
      'Erfahre, wann Himmelsobjekte an deinem Standort sichtbar sind';

  @override
  String get locationPrivacyNotice =>
      'Dein Standort wird nur lokal verwendet und niemals weitergegeben.';

  @override
  String get locationConfirmedTitle => 'Standort bestätigt';

  @override
  String get locationConfirmedSubtitle =>
      'Deine Himmelsansicht wird für deinen Standort angepasst';

  @override
  String get locationOpenSettings => 'Einstellungen öffnen';

  @override
  String get locationGettingLocation => 'Standort wird ermittelt...';

  @override
  String get locationServicesDisabled =>
      'Standortdienste sind deaktiviert. Bitte aktiviere sie in den Einstellungen.';

  @override
  String get locationFailedBrowser =>
      'Standortermittlung fehlgeschlagen. Bitte erlaube den Standortzugriff in deinem Browser.';

  @override
  String get notificationTitle => 'Bleib informiert';

  @override
  String get notificationSubtitle =>
      'Erhalte Benachrichtigungen über Himmelsereignisse und optimale Beobachtungsbedingungen';

  @override
  String get notificationMoonPhase => 'Mondphasen-Hinweise';

  @override
  String get notificationMoonPhaseDesc =>
      'Erfahre die besten Nächte für Sternenbeobachtung';

  @override
  String get notificationCelestialEvents => 'Himmelsereignisse';

  @override
  String get notificationCelestialEventsDesc =>
      'Verpasse keine Sternschnuppen und Finsternisse';

  @override
  String get notificationVisibility => 'Sichtbarkeitshinweise';

  @override
  String get notificationVisibilityDesc =>
      'Werde benachrichtigt, wenn Planeten am besten sichtbar sind';

  @override
  String get notificationPrivacyNotice =>
      'Du kannst die Benachrichtigungseinstellungen jederzeit in der App ändern.';

  @override
  String get attTitle => 'Datenschutz & Tracking';

  @override
  String get attSubtitle =>
      'Erlaube Tracking, um uns zu helfen, dein Erlebnis zu verbessern und dir relevante Inhalte zu zeigen';

  @override
  String get attImproveApp => 'App verbessern';

  @override
  String get attImproveAppDesc =>
      'Hilf uns zu verstehen, wie du die App nutzt, um sie zu verbessern';

  @override
  String get attRelevantContent => 'Relevante Inhalte';

  @override
  String get attRelevantContentDesc =>
      'Sieh Empfehlungen, die auf deine Interessen zugeschnitten sind';

  @override
  String get attPrivacyMatters => 'Deine Privatsphäre ist wichtig';

  @override
  String get attPrivacyMattersDesc =>
      'Wir verkaufen deine persönlichen Daten niemals an Dritte';

  @override
  String get attPrivacyNotice =>
      'Du kannst diese Einstellung jederzeit unter iOS-Einstellungen > Datenschutz > Tracking ändern.';

  @override
  String get starRegTitle => 'Finde deinen Stern';

  @override
  String get starRegSubtitle =>
      'Gib deine Stern-Registrierungsnummer ein, um deinen benannten Stern am Himmel zu finden';

  @override
  String get starRegFindButton => 'Meinen Stern finden';

  @override
  String get starRegNoStarYet => 'Ich habe noch keinen Stern benannt';

  @override
  String get starRegNameAStar => 'Stern benennen';

  @override
  String get starRegEnterNumber => 'Bitte gib eine Registrierungsnummer ein';

  @override
  String get starRegInvalidFormat =>
      'Ungültiges Format. Verwende: XXXX-XXXXX-XXXXXXXX';

  @override
  String get starRegNotFound =>
      'Stern nicht gefunden. Bitte überprüfe deine Registrierungsnummer.';

  @override
  String get starRegSearchFailed =>
      'Suche fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String starRegRemoved(String reason) {
    return 'Der Stern wurde aus dem Register entfernt. Grund: $reason';
  }

  @override
  String get scanCertificate => 'Zertifikat scannen';

  @override
  String get scanningCertificate => 'Zertifikat wird gescannt...';

  @override
  String get pointCameraAtCertificate => 'Kamera auf dein Zertifikat richten';

  @override
  String get registrationNumberWillBeDetected =>
      'Die Registrierungsnummer wird automatisch erkannt';

  @override
  String get registrationNumberFound => 'Nummer gefunden';

  @override
  String get searchForThisNumber => 'Nach dieser Registrierungsnummer suchen?';

  @override
  String get scanAgain => 'Erneut scannen';

  @override
  String get searchStar => 'Stern suchen';

  @override
  String get enterManually => 'Manuell eingeben';

  @override
  String get enterRegistrationNumber => 'Registrierungsnummer eingeben';

  @override
  String get registrationNumberHint => 'z.B. 1234-56789-1234567';

  @override
  String get noRegistrationNumberFound =>
      'Keine Registrierungsnummer gefunden. Versuche es erneut oder gib sie manuell ein.';

  @override
  String get couldNotCaptureImage =>
      'Bild konnte nicht aufgenommen werden. Bitte versuche es erneut.';

  @override
  String get showStarPath => '24h-Pfad anzeigen';

  @override
  String get hideStarPath => '24h-Pfad ausblenden';

  @override
  String get loaderQuote1 => 'Dein persönliches Fenster zum Kosmos';

  @override
  String get loaderQuote2 =>
      'Jeder Stern trägt einen Namen, der darauf wartet, vergeben zu werden';

  @override
  String get loaderQuote3 => 'Der Himmel über dir, kartiert und bereit';

  @override
  String get loaderQuote4 => 'Ein Name, in Licht gemeißelt, für immer deiner';

  @override
  String get loaderQuote5 => 'Millionen von Sternen — einer gehört dir';

  @override
  String get loaderQuote6 => 'Wo das uralte Licht auf deinen Blick trifft';

  @override
  String get loaderQuote7 => 'Das Universum erinnert sich an jeden Namen';

  @override
  String get loaderQuote8 =>
      'Schau nach oben. Finde deinen Platz unter den Sternen.';

  @override
  String get loaderStatus1 => 'Ermittle deine Koordinaten';

  @override
  String get loaderStatus2 => 'Kartiere die Himmelskugel';

  @override
  String get loaderStatus3 => 'Erfasse sichtbare Sternbilder';

  @override
  String get loaderStatus4 => 'Berechne Sternpositionen';

  @override
  String get loaderStatus5 => 'Bereite deinen Nachthimmel vor';

  @override
  String get visibilityCalculating => 'Sichtbarkeit wird berechnet...';

  @override
  String get visibilityVisibleNow => 'Jetzt sichtbar';

  @override
  String get visibilityTonight => 'Heute Nacht';

  @override
  String get visibilityVisible => 'sichtbar';

  @override
  String get visibilitySince => 'SEIT';

  @override
  String get visibilityFrom => 'VON';

  @override
  String get visibilityUntil => 'BIS';

  @override
  String get notificationAlertTitle => 'Sichtbarkeits-Alarm';

  @override
  String get notificationAlertSubtitle =>
      'Benachrichtigung wenn der Stern aufgeht';

  @override
  String get visibilityStatusNeverVisible => 'Nie sichtbar';

  @override
  String get visibilityStatusVisibleNow => 'Jetzt sichtbar';

  @override
  String get visibilityStatusWaitForDark => 'Warte auf Dunkelheit';

  @override
  String get visibilityStatusBelowHorizon => 'Unter dem Horizont';

  @override
  String get visibilityNow => 'Jetzt';

  @override
  String visibilityStatusTonight(String time) {
    return 'Heute $time';
  }

  @override
  String visibilityStatusTomorrow(String time) {
    return 'Morgen $time';
  }

  @override
  String visibilityStatusInDays(int days, int hours) {
    return '${days}T ${hours}Std';
  }
}
