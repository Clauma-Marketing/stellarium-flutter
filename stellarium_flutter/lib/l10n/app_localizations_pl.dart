// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'Star Registration Planetarium';

  @override
  String get menu => 'Menu';

  @override
  String get myStars => 'Moje gwiazdy';

  @override
  String get myStarsSubtitle => 'Zapisane miejsca i ulubione';

  @override
  String get timeLocation => 'Czas i lokalizacja';

  @override
  String get timeLocationSubtitle => 'Ustaw czas i miejsce obserwacji';

  @override
  String get visualEffects => 'Efekty wizualne';

  @override
  String get visualEffectsSubtitle => 'Wygląd nieba, obiekty i siatki';

  @override
  String get settings => 'Ustawienia';

  @override
  String get settingsSubtitle => 'Preferencje aplikacji';

  @override
  String get location => 'LOKALIZACJA';

  @override
  String get time => 'CZAS';

  @override
  String get searchCityAddress => 'Szukaj miasta, adresu...';

  @override
  String get useMyLocation => 'Użyj mojej lokalizacji';

  @override
  String get detecting => 'Wykrywanie...';

  @override
  String get unknownLocation => 'Nieznana lokalizacja';

  @override
  String get setToNow => 'Ustaw na teraz';

  @override
  String get applyChanges => 'Zastosuj zmiany';

  @override
  String get setTime => 'Ustaw czas';

  @override
  String get now => 'Teraz';

  @override
  String get cancel => 'Anuluj';

  @override
  String get apply => 'Zastosuj';

  @override
  String get back => 'Wstecz';

  @override
  String get save => 'Zapisz';

  @override
  String get saved => 'Zapisano';

  @override
  String get savedToMyStars => 'Dodano do Moich gwiazd';

  @override
  String get removedFromMyStars => 'Usunięto z Moich gwiazd';

  @override
  String get pointAtStar => 'Wskaż gwiazdę';

  @override
  String get removeFromMyStars => 'Usuń z Moich gwiazd';

  @override
  String get saveToMyStars => 'Dodaj do Moich gwiazd';

  @override
  String get noSavedStarsYet => 'Brak zapisanych gwiazd';

  @override
  String get tapStarIconHint =>
      'Dotknij ikony gwiazdy na karcie informacyjnej dowolnej gwiazdy, aby ją tutaj zapisać';

  @override
  String starRemoved(String name) {
    return 'Usunięto $name';
  }

  @override
  String get registration => 'REJESTRACJA';

  @override
  String get registeredTo => 'Zarejestrowana dla';

  @override
  String get registrationDate => 'Data';

  @override
  String get registrationNumber => 'Nr rejestracji';

  @override
  String get registry => 'Rejestr';

  @override
  String get properties => 'WŁAŚCIWOŚCI';

  @override
  String get coordinates => 'WSPÓŁRZĘDNE';

  @override
  String get scientificName => 'Nazwa naukowa';

  @override
  String get magnitude => 'Jasność';

  @override
  String get spectralType => 'Typ widmowy';

  @override
  String get distance => 'Odległość';

  @override
  String get parallax => 'Paralaksa';

  @override
  String get objectType => 'Typ obiektu';

  @override
  String get doubleMultipleStar => 'Gwiazda podwójna/wielokrotna';

  @override
  String get rightAscension => 'Rektascensja';

  @override
  String get declination => 'Deklinacja';

  @override
  String get skyDisplay => 'Wygląd nieba';

  @override
  String get celestialObjects => 'Obiekty niebieskie';

  @override
  String get gridLines => 'Siatki i linie';

  @override
  String get displayOptions => 'Opcje wyświetlania';

  @override
  String get constellationLines => 'Linie gwiazdozbiorów';

  @override
  String get constellationLinesDesc =>
      'Pokaż linie łączące gwiazdy w gwiazdozbiorach';

  @override
  String get constellationNames => 'Nazwy gwiazdozbiorów';

  @override
  String get constellationNamesDesc =>
      'Pokaż etykiety z nazwami gwiazdozbiorów';

  @override
  String get constellationArt => 'Rysunki gwiazdozbiorów';

  @override
  String get constellationArtDesc =>
      'Pokaż artystyczne ilustracje gwiazdozbiorów';

  @override
  String get atmosphere => 'Atmosfera';

  @override
  String get atmosphereDesc => 'Pokaż efekty atmosferyczne i poświatę nieba';

  @override
  String get landscape => 'Krajobraz';

  @override
  String get landscapeDesc => 'Pokaż grunt i linię horyzontu';

  @override
  String get landscapeFog => 'Mgła nad krajobrazem';

  @override
  String get landscapeFogDesc => 'Pokaż efekt mgły nad krajobrazem';

  @override
  String get milkyWay => 'Droga Mleczna';

  @override
  String get milkyWayDesc => 'Pokaż galaktykę Drogi Mlecznej';

  @override
  String get dssBackground => 'Tło DSS';

  @override
  String get dssBackgroundDesc =>
      'Pokaż zdjęcia tła z przeglądu Digital Sky Survey';

  @override
  String get stars => 'Gwiazdy';

  @override
  String get starsDesc => 'Pokaż gwiazdy na niebie';

  @override
  String get planets => 'Planety';

  @override
  String get planetsDesc => 'Pokaż planety i ciała Układu Słonecznego';

  @override
  String get deepSkyObjects => 'Obiekty głębokiego nieba';

  @override
  String get deepSkyObjectsDesc => 'Pokaż mgławice, galaktyki i gromady gwiazd';

  @override
  String get satellites => 'Satelity';

  @override
  String get satellitesDesc => 'Pokaż sztuczne satelity';

  @override
  String get azimuthalGrid => 'Siatka azymutalna';

  @override
  String get azimuthalGridDesc => 'Pokaż siatkę współrzędnych wysokość/azymut';

  @override
  String get equatorialGrid => 'Siatka równikowa';

  @override
  String get equatorialGridDesc => 'Pokaż siatkę rektascensji i deklinacji';

  @override
  String get equatorialJ2000Grid => 'Siatka równikowa J2000';

  @override
  String get equatorialJ2000GridDesc =>
      'Pokaż współrzędne równikowe epoki J2000';

  @override
  String get meridianLine => 'Linia południka';

  @override
  String get meridianLineDesc =>
      'Pokaż południk (linia północ–południe przez zenit)';

  @override
  String get eclipticLine => 'Linia ekliptyki';

  @override
  String get eclipticLineDesc => 'Pokaż ekliptykę (pozorną drogę Słońca)';

  @override
  String get nightMode => 'Tryb nocny';

  @override
  String get nightModeDesc => 'Czerwony filtr ekranu chroniący widzenie nocne';

  @override
  String get loadingSkyView => 'Ładowanie widoku nieba...';

  @override
  String get failedToLoadSkyView => 'Nie udało się załadować widoku nieba';

  @override
  String get locationPermissionDenied => 'Odmówiono dostępu do lokalizacji';

  @override
  String get locationPermissionPermanentlyDenied =>
      'Dostęp do lokalizacji został trwale odrzucony. Włącz go w Ustawieniach.';

  @override
  String errorGettingLocation(String error) {
    return 'Błąd pobierania lokalizacji: $error';
  }

  @override
  String registrationNotFound(String number) {
    return 'Nie znaleziono numeru rejestracji \"$number\"';
  }

  @override
  String errorSearching(String error) {
    return 'Błąd wyszukiwania: $error';
  }

  @override
  String get recentSearch => 'Ostatnie wyszukiwanie';

  @override
  String get search => 'Szukaj';

  @override
  String get language => 'Język';

  @override
  String get languageSubtitle => 'Wybierz język aplikacji';

  @override
  String get english => 'Angielski';

  @override
  String get german => 'Niemiecki';

  @override
  String get chinese => 'Chiński (uproszczony)';

  @override
  String get systemDefault => 'Domyślny systemowy';

  @override
  String get subscription => 'Subskrypcja';

  @override
  String get subscriptionSubtitle => 'Zarządzaj subskrypcją';

  @override
  String get currentPlan => 'Bieżący plan';

  @override
  String get freePlan => 'Darmowy';

  @override
  String get premiumPlan => 'Premium';

  @override
  String get proPlan => 'Pro';

  @override
  String get subscriptionActive => 'Aktywna';

  @override
  String get subscriptionExpired => 'Wygasła';

  @override
  String expiresOn(String date) {
    return 'Wygasa $date';
  }

  @override
  String get restorePurchases => 'Przywróć zakupy';

  @override
  String get restoringPurchases => 'Przywracanie...';

  @override
  String get purchasesRestored => 'Zakupy zostały przywrócone';

  @override
  String get noPurchasesToRestore => 'Brak zakupów do przywrócenia';

  @override
  String restoreError(String error) {
    return 'Błąd przywracania zakupów: $error';
  }

  @override
  String get subscriptionLoading => 'Ładowanie opcji subskrypcji...';

  @override
  String get subscriptionRequiredMessage =>
      'Aby dalej korzystać z aplikacji, potrzebna jest subskrypcja lub ważna rejestracja gwiazdy.';

  @override
  String get subscriptionSubscribeButton => 'Subskrybuj teraz';

  @override
  String gateWarningMessage(int seconds) {
    return 'Twój darmowy podgląd nieba kończy się za $seconds s';
  }

  @override
  String get gateWarningCta => 'Zobacz plany';

  @override
  String get manageSubscription => 'Zarządzaj subskrypcją';

  @override
  String get upgradeToPremium => 'Przejdź na Premium';

  @override
  String get tapToChangeLocation => 'Dotknij, aby zmienić lokalizację';

  @override
  String get currentLocation => 'Bieżąca lokalizacja';

  @override
  String get checkingStarRegistry => 'Sprawdzanie rejestru gwiazd...';

  @override
  String get starNotYetNamed => 'Ta gwiazda nie ma jeszcze nazwy';

  @override
  String get giveUniqueNameHint =>
      'Nadaj jej wyjątkową nazwę, która będzie widoczna na niebie';

  @override
  String get nameThisStar => 'Nazwij tę gwiazdę';

  @override
  String get viewStarIn3D => 'Widok 3D';

  @override
  String get catalogId => 'ID katalogowe';

  @override
  String get atmosphereButton => 'Atmosfera';

  @override
  String get movementButton => 'Ruch';

  @override
  String get searchPlaceholder => 'Szukaj gwiazdy lub obiektu...';

  @override
  String get welcomeTitle => 'Odkryj kosmos';

  @override
  String get onboardingExploreUniverse =>
      'Odkrywaj nocne niebo, śledź zjawiska astronomiczne i znajdź swoją nazwaną gwiazdę wśród milionów innych.';

  @override
  String get onboardingGetStarted => 'Rozpocznij';

  @override
  String get onboardingContinue => 'Dalej';

  @override
  String get onboardingSkip => 'Pomiń';

  @override
  String get onboardingSkipForNow => 'Pomiń na razie';

  @override
  String get onboardingMaybeLater => 'Może później';

  @override
  String get onboardingRequesting => 'Wysyłanie prośby...';

  @override
  String get locationAccessTitle => 'Zezwolić na lokalizację?';

  @override
  String get locationAccessSubtitle =>
      'Zobacz nocne niebo dokładnie tak, jak wygląda z Twojego miejsca. Używamy Twojej pozycji, aby precyzyjnie wyznaczać położenie gwiazd.';

  @override
  String get locationAllowAccess => 'Dalej';

  @override
  String get locationAccuratePositions => 'Dokładne pozycje gwiazd';

  @override
  String get locationAccuratePositionsDesc =>
      'Zobacz gwiazdy tak, jak wyglądają dokładnie z Twojej lokalizacji';

  @override
  String get locationCompassNav => 'Nawigacja kompasem';

  @override
  String get locationCompassNavDesc =>
      'Skieruj telefon w niebo, aby odnaleźć gwiazdy';

  @override
  String get locationRiseSetTimes => 'Wschody i zachody';

  @override
  String get locationRiseSetTimesDesc =>
      'Dowiedz się, kiedy obiekty niebieskie są widoczne w Twojej okolicy';

  @override
  String get locationPrivacyNotice =>
      'Twoja lokalizacja jest używana wyłącznie lokalnie i nigdy nie jest udostępniana.';

  @override
  String get locationConfirmedTitle => 'Lokalizacja potwierdzona';

  @override
  String get locationConfirmedSubtitle =>
      'Widok nieba zostanie dopasowany do Twojej lokalizacji';

  @override
  String get locationOpenSettings => 'Otwórz ustawienia';

  @override
  String get locationGettingLocation => 'Pobieranie lokalizacji...';

  @override
  String get locationServicesDisabled =>
      'Usługi lokalizacji są wyłączone. Włącz je w ustawieniach.';

  @override
  String get locationFailedBrowser =>
      'Nie udało się pobrać lokalizacji. Zezwól na dostęp do lokalizacji w przeglądarce.';

  @override
  String get notificationTitle => 'Włączyć powiadomienia?';

  @override
  String get notificationSubtitle =>
      'Nie przegap rojów meteorów ani najlepszych nocy do obserwacji gwiazd. Wyślemy Ci powiadomienie w samą porę.';

  @override
  String get notificationAllowNotifications => 'Dalej';

  @override
  String get notificationMoonPhase => 'Fazy Księżyca';

  @override
  String get notificationMoonPhaseDesc =>
      'Poznaj najlepsze noce do obserwacji gwiazd';

  @override
  String get notificationCelestialEvents => 'Zjawiska astronomiczne';

  @override
  String get notificationCelestialEventsDesc =>
      'Nie przegap rojów meteorów i zaćmień';

  @override
  String get notificationVisibility => 'Alerty widoczności';

  @override
  String get notificationVisibilityDesc =>
      'Otrzymuj powiadomienia, gdy planety są najlepiej widoczne';

  @override
  String get notificationPrivacyNotice =>
      'Ustawienia powiadomień możesz zmienić w każdej chwili w aplikacji.';

  @override
  String get consentTitle => 'Prywatność i dane';

  @override
  String get consentMessage =>
      'Aby ulepszać aplikację i mierzyć skuteczność naszych reklam, my i nasi partnerzy (np. Google) chcielibyśmy zbierać dane o użytkowaniu i zapisywać identyfikatory na Twoim urządzeniu na potrzeby analityki, pomiaru reklam i reklam spersonalizowanych. Swój wybór możesz zmienić w każdej chwili w ustawieniach aplikacji.';

  @override
  String get consentAccept => 'Zaakceptuj wszystko';

  @override
  String get consentDecline => 'Kontynuuj bez akceptacji';

  @override
  String get consentSettingsTitle => 'Analityka i reklamy spersonalizowane';

  @override
  String get consentSettingsSubtitle =>
      'Zezwól na zbieranie danych o użytkowaniu na potrzeby analityki i pomiaru reklam';

  @override
  String get attTitle => 'Zezwolić na śledzenie?';

  @override
  String get attSubtitle =>
      'Pomóż nam ulepszyć Twoją kosmiczną podróż. Używamy danych, aby personalizować treści i podpowiadać interesujące zjawiska.';

  @override
  String get attAllowTracking => 'Dalej';

  @override
  String get attDontTrack => 'Poproś aplikację, aby nie śledziła';

  @override
  String get attImproveApp => 'Ulepszanie aplikacji';

  @override
  String get attImproveAppDesc =>
      'Pomóż nam zrozumieć, jak korzystasz z aplikacji, abyśmy mogli ją ulepszać';

  @override
  String get attRelevantContent => 'Trafne treści';

  @override
  String get attRelevantContentDesc =>
      'Otrzymuj rekomendacje dopasowane do Twoich zainteresowań';

  @override
  String get attPrivacyMatters => 'Twoja prywatność jest ważna';

  @override
  String get attPrivacyMattersDesc =>
      'Nigdy nie sprzedajemy Twoich danych osobowych podmiotom trzecim';

  @override
  String get attPrivacyNotice =>
      'To ustawienie możesz zmienić w każdej chwili w Ustawieniach iOS > Prywatność > Śledzenie.';

  @override
  String get starRegTitle => 'Znajdź swoją gwiazdę';

  @override
  String get starRegSubtitle =>
      'Wpisz numer rejestracji gwiazdy, aby odnaleźć swoją nazwaną gwiazdę na niebie';

  @override
  String get starRegFindButton => 'Znajdź moją gwiazdę';

  @override
  String get starRegNoStarYet => 'Nie nazwałem/-am jeszcze gwiazdy';

  @override
  String get starRegNameAStar => 'Nazwij gwiazdę';

  @override
  String get starRegQuestionTitle => 'Twoje osobiste planetarium';

  @override
  String get starRegQuestionSubtitle => 'Jak chcesz zacząć?';

  @override
  String get starRegExploreCardTitle => 'Odkrywaj nocne niebo';

  @override
  String get starRegExploreCardBody =>
      'Odkrywaj gwiazdy, planety i gwiazdozbiory nad Tobą — na żywo, gdziekolwiek jesteś.';

  @override
  String get starRegHaveStarCardTitle => 'Znajdź swoją nazwaną gwiazdę';

  @override
  String get starRegHaveStarCardBody =>
      'Masz rejestrację gwiazdy — na przykład otrzymaną w prezencie? Odnajdź swoją osobistą gwiazdę na niebie.';

  @override
  String get starRegStartExploring => 'Zacznij odkrywać';

  @override
  String get starRegHaveStar => 'Mam nazwaną gwiazdę';

  @override
  String get starRegEnterNumber => 'Wpisz numer rejestracji';

  @override
  String get starRegInvalidFormat =>
      'Nieprawidłowy format. Użyj: XXXX-XXXXX-XXXXXXXX';

  @override
  String get starRegNotFound =>
      'Nie znaleziono gwiazdy. Sprawdź swój numer rejestracji.';

  @override
  String get starRegSearchFailed =>
      'Wyszukiwanie nie powiodło się. Spróbuj ponownie.';

  @override
  String starRegRemoved(String reason) {
    return '$reason';
  }

  @override
  String get scanCertificate => 'Skanuj certyfikat';

  @override
  String get scanningCertificate => 'Skanowanie certyfikatu...';

  @override
  String get pointCameraAtCertificate => 'Skieruj aparat na swój certyfikat';

  @override
  String get registrationNumberWillBeDetected =>
      'Numer rejestracji zostanie wykryty automatycznie';

  @override
  String get registrationNumberFound => 'Znaleziono numer';

  @override
  String get searchForThisNumber => 'Wyszukać ten numer rejestracji?';

  @override
  String get scanAgain => 'Skanuj ponownie';

  @override
  String get searchStar => 'Szukaj gwiazdy';

  @override
  String get enterManually => 'Wpisz ręcznie';

  @override
  String get enterRegistrationNumber => 'Wpisz numer rejestracji';

  @override
  String get registrationNumberHint => 'np. 1234-56789-1234567';

  @override
  String get noRegistrationNumberFound =>
      'Nie znaleziono numeru rejestracji. Spróbuj ponownie lub wpisz go ręcznie.';

  @override
  String get couldNotCaptureImage =>
      'Nie udało się zrobić zdjęcia. Spróbuj ponownie.';

  @override
  String get showStarPath => 'Pokaż trasę 24 h';

  @override
  String get hideStarPath => 'Ukryj trasę 24 h';

  @override
  String get loaderQuote1 => 'Twoje osobiste okno na kosmos';

  @override
  String get loaderQuote2 => 'Każda gwiazda czeka na swoje imię';

  @override
  String get loaderQuote3 => 'Niebo nad Tobą — zmapowane i gotowe';

  @override
  String get loaderQuote4 => 'Imię zapisane światłem, na zawsze Twoje';

  @override
  String get loaderQuote5 => 'Miliony gwiazd — jedna należy do Ciebie';

  @override
  String get loaderQuote6 => 'Tam, gdzie pradawne światło spotyka Twój wzrok';

  @override
  String get loaderQuote7 => 'Wszechświat pamięta każde imię';

  @override
  String get loaderQuote8 =>
      'Spójrz w górę. Znajdź swoje miejsce wśród gwiazd.';

  @override
  String get loaderStatus1 => 'Ustalanie Twoich współrzędnych';

  @override
  String get loaderStatus2 => 'Mapowanie sfery niebieskiej';

  @override
  String get loaderStatus3 => 'Wyznaczanie widocznych gwiazdozbiorów';

  @override
  String get loaderStatus4 => 'Obliczanie pozycji gwiazd';

  @override
  String get loaderStatus5 => 'Przygotowywanie Twojego nocnego nieba';

  @override
  String get visibilityCalculating => 'Obliczanie widoczności...';

  @override
  String get visibilityVisibleNow => 'Widoczna teraz';

  @override
  String get visibilityTonight => 'Dziś w nocy';

  @override
  String get visibilityVisible => 'widoczna';

  @override
  String get visibilitySince => 'OD';

  @override
  String get visibilityFrom => 'OD';

  @override
  String get visibilityUntil => 'DO';

  @override
  String get notificationAlertTitle => 'Alert widoczności';

  @override
  String get notificationAlertSubtitle =>
      'Otrzymaj powiadomienie, gdy gwiazda wzejdzie';

  @override
  String get visibilityStatusNeverVisible => 'Nigdy niewidoczna';

  @override
  String get visibilityStatusVisibleNow => 'Widoczna teraz';

  @override
  String get visibilityStatusWaitForDark => 'Poczekaj na zmrok';

  @override
  String get visibilityStatusBelowHorizon => 'Pod horyzontem';

  @override
  String get visibilityNow => 'Teraz';

  @override
  String visibilityStatusTonight(String time) {
    return 'Dziś w nocy $time';
  }

  @override
  String visibilityStatusTomorrow(String time) {
    return 'Jutro $time';
  }

  @override
  String visibilityStatusInDays(int days, int hours) {
    return '$days d $hours godz.';
  }

  @override
  String get legal => 'Informacje prawne';

  @override
  String get legalSubtitle => 'Warunki korzystania i polityka prywatności';

  @override
  String get termsOfUse => 'Warunki korzystania';

  @override
  String get privacyPolicy => 'Polityka prywatności';

  @override
  String get ok => 'OK';

  @override
  String get scannerNotAvailable => 'Skaner niedostępny';

  @override
  String get scannerNotAvailableOnWeb =>
      'Skaner certyfikatów wymaga aparatu i jest dostępny tylko w aplikacji mobilnej. Wpisz numer rejestracji ręcznie.';

  @override
  String get skyPreviewTitle => 'Nocne niebo nad Tobą';

  @override
  String skyPreviewTitleWithLocation(String locationName) {
    return 'Nocne niebo nad: $locationName';
  }

  @override
  String get calculateNightSky => 'Oblicz nocne niebo';

  @override
  String get skyPreviewCalculating => 'Obliczanie Twojego nocnego nieba';

  @override
  String skyPreviewCalculatingWithLocation(String locationName) {
    return 'Obliczanie nocnego nieba nad: $locationName';
  }

  @override
  String get skyPreviewHint => 'Dotknij gwiazdy, aby ją poznać';

  @override
  String get skyPreviewContinue => 'Dalej';

  @override
  String get signInTitle => 'Zaloguj się';

  @override
  String get signInSubtitle =>
      'Zapisuj swoje gwiazdy na wszystkich urządzeniach';

  @override
  String get signInCreateAccount => 'Utwórz konto';

  @override
  String get signInWelcomeBack => 'Witaj ponownie';

  @override
  String get signInWithGoogle => 'Kontynuuj z Google';

  @override
  String get signInWithApple => 'Kontynuuj z Apple';

  @override
  String get signInWithEmail => 'Kontynuuj z e-mailem';

  @override
  String get signInOr => 'lub';

  @override
  String get signInEmail => 'E-mail';

  @override
  String get signInPassword => 'Hasło';

  @override
  String get signInForgotPassword => 'Nie pamiętasz hasła?';

  @override
  String get signInSignIn => 'Zaloguj się';

  @override
  String get signInAlreadyHaveAccount => 'Masz już konto?';

  @override
  String get signInNoAccount => 'Nie masz konta?';

  @override
  String get signInBackToOptions => 'Wszystkie opcje logowania';

  @override
  String get signInEmailOptIn =>
      'Chcę otrzymywać wskazówki do obserwacji gwiazd, informacje o nowościach i oferty specjalne';

  @override
  String get signInSkip => 'Kontynuuj bez konta';

  @override
  String get starRemovedFromRegistryTitle => 'Gwiazda usunięta z rejestru';

  @override
  String starRemovedFromRegistryMessage(String name) {
    return '„$name” nie jest już wpisana do rejestru gwiazd, dlatego jej zarejestrowana nazwa nie jest już wyświetlana na niebie.';
  }

  @override
  String get starRemovedFromRegistryHint =>
      'Możesz zachować gwiazdę w Moich gwiazdach lub przesunąć ją, aby usunąć.';

  @override
  String get starRemovedFromRegistryBadge => 'Usunięta z rejestru';

  @override
  String starRemovalReason(String reason) {
    return 'Powód: $reason';
  }
}
