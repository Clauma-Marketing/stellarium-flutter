// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Star Guide: Carte du Ciel Nocturne';

  @override
  String get menu => 'Menu';

  @override
  String get myStars => 'Mes Etoiles';

  @override
  String get myStarsSubtitle => 'Emplacements sauvegardés et favoris';

  @override
  String get timeLocation => 'Heure & Lieu';

  @override
  String get timeLocationSubtitle =>
      'Définir l\'heure et le lieu d\'observation';

  @override
  String get visualEffects => 'Effets Visuels';

  @override
  String get visualEffectsSubtitle => 'Affichage du ciel, objets et grilles';

  @override
  String get settings => 'Paramètres';

  @override
  String get settingsSubtitle => 'Préférences de l\'application';

  @override
  String get location => 'LIEU';

  @override
  String get time => 'HEURE';

  @override
  String get searchCityAddress => 'Rechercher une ville, adresse...';

  @override
  String get useMyLocation => 'Utiliser ma position';

  @override
  String get detecting => 'Détection...';

  @override
  String get unknownLocation => 'Lieu inconnu';

  @override
  String get setToNow => 'Définir à maintenant';

  @override
  String get applyChanges => 'Appliquer les modifications';

  @override
  String get setTime => 'Définir l\'heure';

  @override
  String get now => 'Maintenant';

  @override
  String get cancel => 'Annuler';

  @override
  String get apply => 'Appliquer';

  @override
  String get back => 'Retour';

  @override
  String get save => 'Enregistrer';

  @override
  String get saved => 'Enregistré';

  @override
  String get savedToMyStars => 'Ajouté à Mes Etoiles';

  @override
  String get removedFromMyStars => 'Retiré de Mes Etoiles';

  @override
  String get pointAtStar => 'Localiser';

  @override
  String get removeFromMyStars => 'Retirer de Mes Etoiles';

  @override
  String get saveToMyStars => 'Ajouter à Mes Etoiles';

  @override
  String get noSavedStarsYet => 'Aucune étoile sauvegardée';

  @override
  String get tapStarIconHint =>
      'Appuyez sur l\'icône étoile sur la fiche d\'info d\'une étoile pour la sauvegarder ici';

  @override
  String starRemoved(String name) {
    return '$name retiré';
  }

  @override
  String get registration => 'ENREGISTREMENT';

  @override
  String get registeredTo => 'Enregistré au nom de';

  @override
  String get registrationDate => 'Date';

  @override
  String get registrationNumber => 'N° d\'enregistrement';

  @override
  String get registry => 'Registre';

  @override
  String get properties => 'PROPRIÉTÉS';

  @override
  String get coordinates => 'COORDONNÉES';

  @override
  String get scientificName => 'Nom scientifique';

  @override
  String get magnitude => 'Magnitude';

  @override
  String get spectralType => 'Type spectral';

  @override
  String get distance => 'Distance';

  @override
  String get parallax => 'Parallaxe';

  @override
  String get objectType => 'Type d\'objet';

  @override
  String get doubleMultipleStar => 'Etoile double/multiple';

  @override
  String get rightAscension => 'Ascension droite';

  @override
  String get declination => 'Déclinaison';

  @override
  String get skyDisplay => 'Affichage du ciel';

  @override
  String get celestialObjects => 'Objets célestes';

  @override
  String get gridLines => 'Grilles & Lignes';

  @override
  String get displayOptions => 'Options d\'affichage';

  @override
  String get constellationLines => 'Lignes des constellations';

  @override
  String get constellationLinesDesc =>
      'Afficher les lignes reliant les étoiles des constellations';

  @override
  String get constellationNames => 'Noms des constellations';

  @override
  String get constellationNamesDesc => 'Afficher les noms des constellations';

  @override
  String get constellationArt => 'Art des constellations';

  @override
  String get constellationArtDesc =>
      'Afficher les illustrations artistiques des constellations';

  @override
  String get atmosphere => 'Atmosphère';

  @override
  String get atmosphereDesc =>
      'Afficher les effets atmosphériques et la lueur du ciel';

  @override
  String get landscape => 'Paysage';

  @override
  String get landscapeDesc => 'Afficher le paysage sol/horizon';

  @override
  String get landscapeFog => 'Brouillard du paysage';

  @override
  String get landscapeFogDesc =>
      'Afficher l\'effet de brouillard sur le paysage';

  @override
  String get milkyWay => 'Voie Lactée';

  @override
  String get milkyWayDesc => 'Afficher la Voie Lactée';

  @override
  String get dssBackground => 'Fond DSS';

  @override
  String get dssBackgroundDesc =>
      'Afficher les images de fond du Digital Sky Survey';

  @override
  String get stars => 'Etoiles';

  @override
  String get starsDesc => 'Afficher les étoiles dans le ciel';

  @override
  String get planets => 'Planètes';

  @override
  String get planetsDesc => 'Afficher les planètes et corps du système solaire';

  @override
  String get deepSkyObjects => 'Objets du ciel profond';

  @override
  String get deepSkyObjectsDesc =>
      'Afficher nébuleuses, galaxies et amas d\'étoiles';

  @override
  String get satellites => 'Satellites';

  @override
  String get satellitesDesc => 'Afficher les satellites artificiels';

  @override
  String get azimuthalGrid => 'Grille azimutale';

  @override
  String get azimuthalGridDesc =>
      'Afficher la grille de coordonnées altitude/azimut';

  @override
  String get equatorialGrid => 'Grille équatoriale';

  @override
  String get equatorialGridDesc =>
      'Afficher la grille ascension droite/déclinaison';

  @override
  String get equatorialJ2000Grid => 'Grille équatoriale J2000';

  @override
  String get equatorialJ2000GridDesc =>
      'Afficher les coordonnées équatoriales époque J2000';

  @override
  String get meridianLine => 'Ligne méridienne';

  @override
  String get meridianLineDesc =>
      'Afficher le méridien (nord-sud par le zénith)';

  @override
  String get eclipticLine => 'Ligne de l\'écliptique';

  @override
  String get eclipticLineDesc =>
      'Afficher l\'écliptique (trajectoire apparente du soleil)';

  @override
  String get nightMode => 'Mode nuit';

  @override
  String get nightModeDesc =>
      'Affichage rouge pour préserver la vision nocturne';

  @override
  String get loadingSkyView => 'Chargement de la vue du ciel...';

  @override
  String get failedToLoadSkyView => 'Échec du chargement de la vue du ciel';

  @override
  String get locationPermissionDenied => 'Permission de localisation refusée';

  @override
  String get locationPermissionPermanentlyDenied =>
      'Permission de localisation refusée définitivement. Veuillez l\'activer dans les Réglages.';

  @override
  String errorGettingLocation(String error) {
    return 'Erreur lors de la localisation : $error';
  }

  @override
  String registrationNotFound(String number) {
    return 'Numéro d\'enregistrement \"$number\" non trouvé';
  }

  @override
  String errorSearching(String error) {
    return 'Erreur de recherche : $error';
  }

  @override
  String get recentSearch => 'Recherche récente';

  @override
  String get search => 'Rechercher';

  @override
  String get language => 'Langue';

  @override
  String get languageSubtitle => 'Choisir la langue de l\'application';

  @override
  String get english => 'Anglais';

  @override
  String get german => 'Allemand';

  @override
  String get chinese => 'Chinois (Simplifié)';

  @override
  String get systemDefault => 'Par défaut du système';

  @override
  String get subscription => 'Abonnement';

  @override
  String get subscriptionSubtitle => 'Gérer votre abonnement';

  @override
  String get currentPlan => 'Forfait actuel';

  @override
  String get freePlan => 'Gratuit';

  @override
  String get premiumPlan => 'Premium';

  @override
  String get proPlan => 'Pro';

  @override
  String get subscriptionActive => 'Actif';

  @override
  String get subscriptionExpired => 'Expiré';

  @override
  String expiresOn(String date) {
    return 'Expire le $date';
  }

  @override
  String get restorePurchases => 'Restaurer les achats';

  @override
  String get restoringPurchases => 'Restauration...';

  @override
  String get purchasesRestored => 'Achats restaurés avec succès';

  @override
  String get noPurchasesToRestore => 'Aucun achat à restaurer';

  @override
  String restoreError(String error) {
    return 'Erreur lors de la restauration : $error';
  }

  @override
  String get subscriptionLoading => 'Chargement des options d\'abonnement...';

  @override
  String get subscriptionRequiredMessage =>
      'Un abonnement ou un enregistrement d\'étoile valide est requis pour continuer à utiliser l\'application.';

  @override
  String get subscriptionSubscribeButton => 'S\'abonner maintenant';

  @override
  String get manageSubscription => 'Gérer l\'abonnement';

  @override
  String get upgradeToPremium => 'Passer à Premium';

  @override
  String get tapToChangeLocation => 'Appuyez pour changer le lieu';

  @override
  String get currentLocation => 'Position actuelle';

  @override
  String get checkingStarRegistry => 'Vérification du registre des étoiles...';

  @override
  String get starNotYetNamed => 'Cette étoile n\'a pas encore de nom';

  @override
  String get giveUniqueNameHint =>
      'Donnez-lui un nom unique qui sera visible dans le ciel';

  @override
  String get nameThisStar => 'Nommer cette étoile';

  @override
  String get viewStarIn3D => 'Vue 3D';

  @override
  String get catalogId => 'ID catalogue';

  @override
  String get atmosphereButton => 'Atmosphère';

  @override
  String get movementButton => 'Mouvement';

  @override
  String get searchPlaceholder => 'Rechercher une étoile ou un objet...';

  @override
  String get welcomeTitle => 'Découvrez le Cosmos';

  @override
  String get onboardingExploreUniverse =>
      'Explorez le ciel nocturne, suivez les événements célestes et trouvez votre étoile nommée parmi des millions d\'autres.';

  @override
  String get onboardingGetStarted => 'Commencer';

  @override
  String get onboardingContinue => 'Continuer';

  @override
  String get onboardingSkip => 'Passer';

  @override
  String get onboardingSkipForNow => 'Passer pour l\'instant';

  @override
  String get onboardingMaybeLater => 'Peut-être plus tard';

  @override
  String get onboardingRequesting => 'Demande en cours...';

  @override
  String get locationAccessTitle => 'Autoriser la localisation ?';

  @override
  String get locationAccessSubtitle =>
      'Voyez le ciel nocturne tel qu\'il apparaît depuis votre position. Nous utilisons votre position pour des positions d\'étoiles précises.';

  @override
  String get locationAllowAccess => 'Continuer';

  @override
  String get locationAccuratePositions => 'Positions précises des étoiles';

  @override
  String get locationAccuratePositionsDesc =>
      'Voyez les étoiles telles qu\'elles apparaissent depuis votre position exacte';

  @override
  String get locationCompassNav => 'Navigation par boussole';

  @override
  String get locationCompassNavDesc =>
      'Pointez votre téléphone pour trouver les étoiles dans le ciel';

  @override
  String get locationRiseSetTimes => 'Heures de lever & coucher';

  @override
  String get locationRiseSetTimesDesc =>
      'Sachez quand les objets célestes sont visibles à votre position';

  @override
  String get locationPrivacyNotice =>
      'Votre position n\'est utilisée que localement et n\'est jamais partagée.';

  @override
  String get locationConfirmedTitle => 'Position confirmée';

  @override
  String get locationConfirmedSubtitle =>
      'Votre vue du ciel sera personnalisée pour votre position';

  @override
  String get locationOpenSettings => 'Ouvrir les réglages';

  @override
  String get locationGettingLocation => 'Obtention de la position...';

  @override
  String get locationServicesDisabled =>
      'Les services de localisation sont désactivés. Veuillez les activer dans les réglages.';

  @override
  String get locationFailedBrowser =>
      'Échec de l\'obtention de la position. Veuillez autoriser l\'accès à la localisation dans votre navigateur.';

  @override
  String get notificationTitle => 'Activer les notifications ?';

  @override
  String get notificationSubtitle =>
      'Ne manquez jamais les pluies de météores et les meilleures nuits pour observer les étoiles. Nous vous enverrons des alertes à temps avant qu\'elles ne se produisent.';

  @override
  String get notificationAllowNotifications => 'Continuer';

  @override
  String get notificationMoonPhase => 'Alertes phases lunaires';

  @override
  String get notificationMoonPhaseDesc =>
      'Connaître les meilleures nuits pour observer les étoiles';

  @override
  String get notificationCelestialEvents => 'Événements célestes';

  @override
  String get notificationCelestialEventsDesc =>
      'Ne manquez jamais les pluies de météores et les éclipses';

  @override
  String get notificationVisibility => 'Alertes de visibilité';

  @override
  String get notificationVisibilityDesc =>
      'Soyez notifié quand les planètes sont les mieux visibles';

  @override
  String get notificationPrivacyNotice =>
      'Vous pouvez modifier les paramètres de notification à tout moment dans l\'application.';

  @override
  String get attTitle => 'Autoriser le suivi ?';

  @override
  String get attSubtitle =>
      'Aidez-nous à améliorer votre voyage cosmique. Nous utilisons les données pour personnaliser les insights et suggérer des événements pertinents.';

  @override
  String get attAllowTracking => 'Continuer';

  @override
  String get attDontTrack => 'Demander à l\'app de ne pas suivre';

  @override
  String get attImproveApp => 'Améliorer l\'application';

  @override
  String get attImproveAppDesc =>
      'Aidez-nous à comprendre comment vous utilisez l\'application pour l\'améliorer';

  @override
  String get attRelevantContent => 'Contenu pertinent';

  @override
  String get attRelevantContentDesc =>
      'Voir des recommandations adaptées à vos intérêts';

  @override
  String get attPrivacyMatters => 'Votre vie privée compte';

  @override
  String get attPrivacyMattersDesc =>
      'Nous ne vendons jamais vos données personnelles à des tiers';

  @override
  String get attPrivacyNotice =>
      'Vous pouvez modifier ce paramètre à tout moment dans Réglages iOS > Confidentialité > Suivi.';

  @override
  String get starRegTitle => 'Trouvez votre étoile';

  @override
  String get starRegSubtitle =>
      'Entrez votre numéro d\'enregistrement pour localiser votre étoile nommée dans le ciel';

  @override
  String get starRegFindButton => 'Trouver mon étoile';

  @override
  String get starRegNoStarYet => 'Je n\'ai pas encore nommé d\'étoile';

  @override
  String get starRegNameAStar => 'Nommer une étoile';

  @override
  String get starRegEnterNumber =>
      'Veuillez entrer un numéro d\'enregistrement';

  @override
  String get starRegInvalidFormat =>
      'Format invalide. Utilisez : XXXX-XXXXX-XXXXXXXX';

  @override
  String get starRegNotFound =>
      'Etoile non trouvée. Veuillez vérifier votre numéro d\'enregistrement.';

  @override
  String get starRegSearchFailed =>
      'Échec de la recherche. Veuillez réessayer.';

  @override
  String starRegRemoved(String reason) {
    return '$reason';
  }

  @override
  String get scanCertificate => 'Scanner le certificat';

  @override
  String get scanningCertificate => 'Scan du certificat...';

  @override
  String get pointCameraAtCertificate =>
      'Pointez la caméra vers votre certificat';

  @override
  String get registrationNumberWillBeDetected =>
      'Le numéro d\'enregistrement sera détecté automatiquement';

  @override
  String get registrationNumberFound => 'Numéro trouvé';

  @override
  String get searchForThisNumber => 'Rechercher ce numéro d\'enregistrement ?';

  @override
  String get scanAgain => 'Scanner à nouveau';

  @override
  String get searchStar => 'Rechercher l\'étoile';

  @override
  String get enterManually => 'Saisir manuellement';

  @override
  String get enterRegistrationNumber => 'Entrer le numéro d\'enregistrement';

  @override
  String get registrationNumberHint => 'ex. 1234-56789-1234567';

  @override
  String get noRegistrationNumberFound =>
      'Aucun numéro d\'enregistrement trouvé. Réessayez ou saisissez manuellement.';

  @override
  String get couldNotCaptureImage =>
      'Impossible de capturer l\'image. Veuillez réessayer.';

  @override
  String get showStarPath => 'Afficher trajectoire 24h';

  @override
  String get hideStarPath => 'Masquer trajectoire 24h';

  @override
  String get loaderQuote1 => 'Votre fenêtre personnelle sur le cosmos';

  @override
  String get loaderQuote2 =>
      'Chaque étoile porte un nom qui attend d\'être donné';

  @override
  String get loaderQuote3 => 'Le ciel au-dessus de vous, cartographié et prêt';

  @override
  String get loaderQuote4 => 'Un nom gravé dans la lumière, à jamais vôtre';

  @override
  String get loaderQuote5 => 'Des millions d\'étoiles — une vous appartient';

  @override
  String get loaderQuote6 => 'Là où la lumière ancienne rencontre votre regard';

  @override
  String get loaderQuote7 => 'L\'univers se souvient de chaque nom';

  @override
  String get loaderQuote8 =>
      'Levez les yeux. Trouvez votre place parmi les étoiles.';

  @override
  String get loaderStatus1 => 'Localisation de vos coordonnées';

  @override
  String get loaderStatus2 => 'Cartographie de la sphère céleste';

  @override
  String get loaderStatus3 => 'Repérage des constellations visibles';

  @override
  String get loaderStatus4 => 'Calcul des positions des étoiles';

  @override
  String get loaderStatus5 => 'Préparation de votre ciel nocturne';

  @override
  String get visibilityCalculating => 'Calcul de la visibilité...';

  @override
  String get visibilityVisibleNow => 'Visible maintenant';

  @override
  String get visibilityTonight => 'Ce soir';

  @override
  String get visibilityVisible => 'visible';

  @override
  String get visibilitySince => 'DEPUIS';

  @override
  String get visibilityFrom => 'DE';

  @override
  String get visibilityUntil => 'JUSQU\'À';

  @override
  String get notificationAlertTitle => 'Alerte de visibilité';

  @override
  String get notificationAlertSubtitle =>
      'Être notifié quand l\'étoile se lève';

  @override
  String get visibilityStatusNeverVisible => 'Jamais visible';

  @override
  String get visibilityStatusVisibleNow => 'Visible maintenant';

  @override
  String get visibilityStatusWaitForDark => 'Attendre la nuit';

  @override
  String get visibilityStatusBelowHorizon => 'Sous l\'horizon';

  @override
  String get visibilityNow => 'Maintenant';

  @override
  String visibilityStatusTonight(String time) {
    return 'Ce soir $time';
  }

  @override
  String visibilityStatusTomorrow(String time) {
    return 'Demain $time';
  }

  @override
  String visibilityStatusInDays(int days, int hours) {
    return '${days}j ${hours}h';
  }

  @override
  String get legal => 'Mentions légales';

  @override
  String get legalSubtitle =>
      'Conditions d\'utilisation & Politique de confidentialité';

  @override
  String get termsOfUse => 'Conditions d\'utilisation';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get ok => 'OK';

  @override
  String get scannerNotAvailable => 'Scanner non disponible';

  @override
  String get scannerNotAvailableOnWeb =>
      'Le scanner de certificat nécessite une caméra et n\'est disponible que sur l\'application mobile. Veuillez saisir votre numéro d\'enregistrement manuellement.';

  @override
  String get skyPreviewTitle => 'Le ciel nocturne au-dessus de vous';

  @override
  String skyPreviewTitleWithLocation(String locationName) {
    return 'Le ciel nocturne au-dessus de $locationName';
  }

  @override
  String get calculateNightSky => 'Calculer le ciel nocturne';

  @override
  String get skyPreviewCalculating => 'Calcul de votre ciel nocturne';

  @override
  String skyPreviewCalculatingWithLocation(String locationName) {
    return 'Calcul du ciel nocturne au-dessus de $locationName';
  }

  @override
  String get skyPreviewHint => 'Touchez une étoile pour la découvrir';

  @override
  String get skyPreviewContinue => 'Continuer';

  @override
  String get signInTitle => 'Connexion';

  @override
  String get signInSubtitle => 'Sauvegardez vos étoiles sur tous vos appareils';

  @override
  String get signInCreateAccount => 'Créer un compte';

  @override
  String get signInWelcomeBack => 'Bon retour';

  @override
  String get signInWithGoogle => 'Continuer avec Google';

  @override
  String get signInWithApple => 'Continuer avec Apple';

  @override
  String get signInWithEmail => 'Continuer avec e-mail';

  @override
  String get signInOr => 'ou';

  @override
  String get signInEmail => 'E-mail';

  @override
  String get signInPassword => 'Mot de passe';

  @override
  String get signInForgotPassword => 'Mot de passe oublié ?';

  @override
  String get signInSignIn => 'Se connecter';

  @override
  String get signInAlreadyHaveAccount => 'Déjà un compte ?';

  @override
  String get signInNoAccount => 'Pas de compte ?';

  @override
  String get signInBackToOptions => 'Toutes les options';

  @override
  String get signInSkip => 'Continuer sans compte';
}
