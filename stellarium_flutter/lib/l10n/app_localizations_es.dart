// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Star Guide: Mapa del Cielo Nocturno';

  @override
  String get menu => 'Menú';

  @override
  String get myStars => 'Mis Estrellas';

  @override
  String get myStarsSubtitle => 'Ubicaciones guardadas y favoritos';

  @override
  String get timeLocation => 'Hora y Ubicación';

  @override
  String get timeLocationSubtitle => 'Configurar hora y lugar de observación';

  @override
  String get visualEffects => 'Efectos Visuales';

  @override
  String get visualEffectsSubtitle =>
      'Visualización del cielo, objetos y cuadrículas';

  @override
  String get settings => 'Configuración';

  @override
  String get settingsSubtitle => 'Preferencias de la aplicación';

  @override
  String get location => 'UBICACIÓN';

  @override
  String get time => 'HORA';

  @override
  String get searchCityAddress => 'Buscar ciudad, dirección...';

  @override
  String get useMyLocation => 'Usar mi ubicación';

  @override
  String get detecting => 'Detectando...';

  @override
  String get unknownLocation => 'Ubicación desconocida';

  @override
  String get setToNow => 'Establecer a ahora';

  @override
  String get applyChanges => 'Aplicar cambios';

  @override
  String get setTime => 'Establecer hora';

  @override
  String get now => 'Ahora';

  @override
  String get cancel => 'Cancelar';

  @override
  String get apply => 'Aplicar';

  @override
  String get back => 'Atrás';

  @override
  String get save => 'Guardar';

  @override
  String get saved => 'Guardado';

  @override
  String get savedToMyStars => 'Agregado a Mis Estrellas';

  @override
  String get removedFromMyStars => 'Eliminado de Mis Estrellas';

  @override
  String get pointAtStar => 'Localizar';

  @override
  String get removeFromMyStars => 'Eliminar de Mis Estrellas';

  @override
  String get saveToMyStars => 'Agregar a Mis Estrellas';

  @override
  String get noSavedStarsYet => 'Aún no hay estrellas guardadas';

  @override
  String get tapStarIconHint =>
      'Toca el icono de estrella en la ficha de información de cualquier estrella para guardarla aquí';

  @override
  String starRemoved(String name) {
    return '$name eliminado';
  }

  @override
  String get registration => 'REGISTRO';

  @override
  String get registeredTo => 'Registrado a nombre de';

  @override
  String get registrationDate => 'Fecha';

  @override
  String get registrationNumber => 'N° de registro';

  @override
  String get registry => 'Registro';

  @override
  String get properties => 'PROPIEDADES';

  @override
  String get coordinates => 'COORDENADAS';

  @override
  String get scientificName => 'Nombre científico';

  @override
  String get magnitude => 'Magnitud';

  @override
  String get spectralType => 'Tipo espectral';

  @override
  String get distance => 'Distancia';

  @override
  String get parallax => 'Paralaje';

  @override
  String get objectType => 'Tipo de objeto';

  @override
  String get doubleMultipleStar => 'Estrella doble/múltiple';

  @override
  String get rightAscension => 'Ascensión recta';

  @override
  String get declination => 'Declinación';

  @override
  String get skyDisplay => 'Visualización del cielo';

  @override
  String get celestialObjects => 'Objetos celestes';

  @override
  String get gridLines => 'Cuadrículas y líneas';

  @override
  String get displayOptions => 'Opciones de visualización';

  @override
  String get constellationLines => 'Líneas de constelaciones';

  @override
  String get constellationLinesDesc =>
      'Mostrar líneas que conectan estrellas en constelaciones';

  @override
  String get constellationNames => 'Nombres de constelaciones';

  @override
  String get constellationNamesDesc =>
      'Mostrar etiquetas de nombres de constelaciones';

  @override
  String get constellationArt => 'Arte de constelaciones';

  @override
  String get constellationArtDesc =>
      'Mostrar ilustraciones artísticas de constelaciones';

  @override
  String get atmosphere => 'Atmósfera';

  @override
  String get atmosphereDesc =>
      'Mostrar efectos atmosféricos y resplandor del cielo';

  @override
  String get landscape => 'Paisaje';

  @override
  String get landscapeDesc => 'Mostrar paisaje del suelo/horizonte';

  @override
  String get landscapeFog => 'Niebla del paisaje';

  @override
  String get landscapeFogDesc => 'Mostrar efecto de niebla en el paisaje';

  @override
  String get milkyWay => 'Vía Láctea';

  @override
  String get milkyWayDesc => 'Mostrar la Vía Láctea';

  @override
  String get dssBackground => 'Fondo DSS';

  @override
  String get dssBackgroundDesc =>
      'Mostrar imágenes de fondo del Digital Sky Survey';

  @override
  String get stars => 'Estrellas';

  @override
  String get starsDesc => 'Mostrar estrellas en el cielo';

  @override
  String get planets => 'Planetas';

  @override
  String get planetsDesc => 'Mostrar planetas y cuerpos del sistema solar';

  @override
  String get deepSkyObjects => 'Objetos del cielo profundo';

  @override
  String get deepSkyObjectsDesc =>
      'Mostrar nebulosas, galaxias y cúmulos estelares';

  @override
  String get satellites => 'Satélites';

  @override
  String get satellitesDesc => 'Mostrar satélites artificiales';

  @override
  String get azimuthalGrid => 'Cuadrícula azimutal';

  @override
  String get azimuthalGridDesc =>
      'Mostrar cuadrícula de coordenadas altitud/azimut';

  @override
  String get equatorialGrid => 'Cuadrícula ecuatorial';

  @override
  String get equatorialGridDesc =>
      'Mostrar cuadrícula de ascensión recta/declinación';

  @override
  String get equatorialJ2000Grid => 'Cuadrícula ecuatorial J2000';

  @override
  String get equatorialJ2000GridDesc =>
      'Mostrar coordenadas ecuatoriales época J2000';

  @override
  String get meridianLine => 'Línea meridiana';

  @override
  String get meridianLineDesc =>
      'Mostrar el meridiano (norte-sur por el cenit)';

  @override
  String get eclipticLine => 'Línea de la eclíptica';

  @override
  String get eclipticLineDesc =>
      'Mostrar la eclíptica (trayectoria aparente del sol)';

  @override
  String get nightMode => 'Modo nocturno';

  @override
  String get nightModeDesc =>
      'Pantalla en rojo para preservar la visión nocturna';

  @override
  String get loadingSkyView => 'Cargando vista del cielo...';

  @override
  String get failedToLoadSkyView => 'Error al cargar la vista del cielo';

  @override
  String get locationPermissionDenied => 'Permiso de ubicación denegado';

  @override
  String get locationPermissionPermanentlyDenied =>
      'Permiso de ubicación denegado permanentemente. Por favor, actívalo en Configuración.';

  @override
  String errorGettingLocation(String error) {
    return 'Error al obtener la ubicación: $error';
  }

  @override
  String registrationNotFound(String number) {
    return 'Número de registro \"$number\" no encontrado';
  }

  @override
  String errorSearching(String error) {
    return 'Error de búsqueda: $error';
  }

  @override
  String get recentSearch => 'Búsqueda reciente';

  @override
  String get search => 'Buscar';

  @override
  String get language => 'Idioma';

  @override
  String get languageSubtitle => 'Elegir idioma de la aplicación';

  @override
  String get english => 'Inglés';

  @override
  String get german => 'Alemán';

  @override
  String get chinese => 'Chino (Simplificado)';

  @override
  String get systemDefault => 'Predeterminado del sistema';

  @override
  String get subscription => 'Suscripción';

  @override
  String get subscriptionSubtitle => 'Gestionar tu suscripción';

  @override
  String get currentPlan => 'Plan actual';

  @override
  String get freePlan => 'Gratuito';

  @override
  String get premiumPlan => 'Premium';

  @override
  String get proPlan => 'Pro';

  @override
  String get subscriptionActive => 'Activo';

  @override
  String get subscriptionExpired => 'Expirado';

  @override
  String expiresOn(String date) {
    return 'Expira el $date';
  }

  @override
  String get restorePurchases => 'Restaurar compras';

  @override
  String get restoringPurchases => 'Restaurando...';

  @override
  String get purchasesRestored => 'Compras restauradas exitosamente';

  @override
  String get noPurchasesToRestore => 'No hay compras para restaurar';

  @override
  String restoreError(String error) {
    return 'Error al restaurar: $error';
  }

  @override
  String get subscriptionLoading => 'Cargando opciones de suscripción...';

  @override
  String get subscriptionRequiredMessage =>
      'Se requiere una suscripción o un registro de estrella válido para continuar usando la aplicación.';

  @override
  String get subscriptionSubscribeButton => 'Suscribirse ahora';

  @override
  String get manageSubscription => 'Gestionar suscripción';

  @override
  String get upgradeToPremium => 'Actualizar a Premium';

  @override
  String get tapToChangeLocation => 'Toca para cambiar la ubicación';

  @override
  String get currentLocation => 'Ubicación actual';

  @override
  String get checkingStarRegistry => 'Verificando el registro de estrellas...';

  @override
  String get starNotYetNamed => 'Esta estrella aún no tiene nombre';

  @override
  String get giveUniqueNameHint =>
      'Dale un nombre único que será visible en el cielo';

  @override
  String get nameThisStar => 'Nombrar esta estrella';

  @override
  String get viewStarIn3D => 'Vista 3D';

  @override
  String get catalogId => 'ID de catálogo';

  @override
  String get atmosphereButton => 'Atmósfera';

  @override
  String get movementButton => 'Movimiento';

  @override
  String get searchPlaceholder => 'Buscar una estrella u objeto...';

  @override
  String get welcomeTitle => 'Descubre el Cosmos';

  @override
  String get onboardingExploreUniverse =>
      'Explora el cielo nocturno, sigue eventos celestes y encuentra tu estrella nombrada entre millones de otras.';

  @override
  String get onboardingGetStarted => 'Comenzar';

  @override
  String get onboardingContinue => 'Continuar';

  @override
  String get onboardingSkip => 'Omitir';

  @override
  String get onboardingSkipForNow => 'Omitir por ahora';

  @override
  String get onboardingMaybeLater => 'Quizás más tarde';

  @override
  String get onboardingRequesting => 'Solicitando...';

  @override
  String get locationAccessTitle => '¿Permitir ubicación?';

  @override
  String get locationAccessSubtitle =>
      'Ve el cielo nocturno exactamente como aparece desde tu ubicación. Usamos tu posición para posiciones precisas de estrellas.';

  @override
  String get locationAllowAccess => 'Continuar';

  @override
  String get locationAccuratePositions => 'Posiciones precisas de estrellas';

  @override
  String get locationAccuratePositionsDesc =>
      'Ve las estrellas como aparecen desde tu ubicación exacta';

  @override
  String get locationCompassNav => 'Navegación por brújula';

  @override
  String get locationCompassNavDesc =>
      'Apunta tu teléfono para encontrar estrellas en el cielo';

  @override
  String get locationRiseSetTimes => 'Horas de salida y puesta';

  @override
  String get locationRiseSetTimesDesc =>
      'Sabe cuándo los objetos celestes son visibles en tu ubicación';

  @override
  String get locationPrivacyNotice =>
      'Tu ubicación solo se usa localmente y nunca se comparte.';

  @override
  String get locationConfirmedTitle => 'Ubicación confirmada';

  @override
  String get locationConfirmedSubtitle =>
      'Tu vista del cielo se personalizará para tu ubicación';

  @override
  String get locationOpenSettings => 'Abrir configuración';

  @override
  String get locationGettingLocation => 'Obteniendo ubicación...';

  @override
  String get locationServicesDisabled =>
      'Los servicios de ubicación están desactivados. Por favor, actívalos en configuración.';

  @override
  String get locationFailedBrowser =>
      'Error al obtener la ubicación. Por favor, permite el acceso a la ubicación en tu navegador.';

  @override
  String get notificationTitle => '¿Activar notificaciones?';

  @override
  String get notificationSubtitle =>
      'Nunca te pierdas lluvias de meteoros y las mejores noches para observar estrellas. Te enviaremos alertas oportunas antes de que ocurran.';

  @override
  String get notificationAllowNotifications => 'Continuar';

  @override
  String get notificationMoonPhase => 'Alertas de fases lunares';

  @override
  String get notificationMoonPhaseDesc =>
      'Conoce las mejores noches para observar estrellas';

  @override
  String get notificationCelestialEvents => 'Eventos celestes';

  @override
  String get notificationCelestialEventsDesc =>
      'Nunca te pierdas lluvias de meteoros y eclipses';

  @override
  String get notificationVisibility => 'Alertas de visibilidad';

  @override
  String get notificationVisibilityDesc =>
      'Recibe notificaciones cuando los planetas sean más visibles';

  @override
  String get notificationPrivacyNotice =>
      'Puedes cambiar la configuración de notificaciones en cualquier momento en la aplicación.';

  @override
  String get attTitle => '¿Permitir seguimiento?';

  @override
  String get attSubtitle =>
      'Ayúdanos a mejorar tu viaje cósmico. Usamos datos para personalizar información y sugerir eventos relevantes.';

  @override
  String get attAllowTracking => 'Continuar';

  @override
  String get attDontTrack => 'Pedir a la app que no rastree';

  @override
  String get attImproveApp => 'Mejorar la aplicación';

  @override
  String get attImproveAppDesc =>
      'Ayúdanos a entender cómo usas la aplicación para mejorarla';

  @override
  String get attRelevantContent => 'Contenido relevante';

  @override
  String get attRelevantContentDesc =>
      'Ve recomendaciones adaptadas a tus intereses';

  @override
  String get attPrivacyMatters => 'Tu privacidad importa';

  @override
  String get attPrivacyMattersDesc =>
      'Nunca vendemos tus datos personales a terceros';

  @override
  String get attPrivacyNotice =>
      'Puedes cambiar esta configuración en cualquier momento en Configuración iOS > Privacidad > Seguimiento.';

  @override
  String get starRegTitle => 'Encuentra tu estrella';

  @override
  String get starRegSubtitle =>
      'Ingresa tu número de registro para localizar tu estrella nombrada en el cielo';

  @override
  String get starRegFindButton => 'Encontrar mi estrella';

  @override
  String get starRegNoStarYet => 'Aún no he nombrado una estrella';

  @override
  String get starRegNameAStar => 'Nombrar una estrella';

  @override
  String get starRegEnterNumber => 'Por favor, ingresa un número de registro';

  @override
  String get starRegInvalidFormat =>
      'Formato inválido. Usa: XXXX-XXXXX-XXXXXXXX';

  @override
  String get starRegNotFound =>
      'Estrella no encontrada. Por favor, verifica tu número de registro.';

  @override
  String get starRegSearchFailed =>
      'Error en la búsqueda. Por favor, intenta de nuevo.';

  @override
  String starRegRemoved(String reason) {
    return '$reason';
  }

  @override
  String get scanCertificate => 'Escanear certificado';

  @override
  String get scanningCertificate => 'Escaneando certificado...';

  @override
  String get pointCameraAtCertificate =>
      'Apunta la cámara hacia tu certificado';

  @override
  String get registrationNumberWillBeDetected =>
      'El número de registro se detectará automáticamente';

  @override
  String get registrationNumberFound => 'Número encontrado';

  @override
  String get searchForThisNumber => '¿Buscar este número de registro?';

  @override
  String get scanAgain => 'Escanear de nuevo';

  @override
  String get searchStar => 'Buscar estrella';

  @override
  String get enterManually => 'Ingresar manualmente';

  @override
  String get enterRegistrationNumber => 'Ingresar número de registro';

  @override
  String get registrationNumberHint => 'ej. 1234-56789-1234567';

  @override
  String get noRegistrationNumberFound =>
      'No se encontró número de registro. Intenta de nuevo o ingresa manualmente.';

  @override
  String get couldNotCaptureImage =>
      'No se pudo capturar la imagen. Por favor, intenta de nuevo.';

  @override
  String get showStarPath => 'Mostrar trayectoria 24h';

  @override
  String get hideStarPath => 'Ocultar trayectoria 24h';

  @override
  String get loaderQuote1 => 'Tu ventana personal al cosmos';

  @override
  String get loaderQuote2 => 'Cada estrella lleva un nombre esperando ser dado';

  @override
  String get loaderQuote3 => 'El cielo sobre ti, mapeado y esperando';

  @override
  String get loaderQuote4 => 'Un nombre grabado en luz, para siempre tuyo';

  @override
  String get loaderQuote5 => 'Millones de estrellas — una te pertenece';

  @override
  String get loaderQuote6 => 'Donde la luz antigua encuentra tu mirada';

  @override
  String get loaderQuote7 => 'El universo recuerda cada nombre';

  @override
  String get loaderQuote8 =>
      'Mira hacia arriba. Encuentra tu lugar entre las estrellas.';

  @override
  String get loaderStatus1 => 'Localizando tus coordenadas';

  @override
  String get loaderStatus2 => 'Mapeando la esfera celeste';

  @override
  String get loaderStatus3 => 'Trazando constelaciones visibles';

  @override
  String get loaderStatus4 => 'Calculando posiciones de estrellas';

  @override
  String get loaderStatus5 => 'Preparando tu cielo nocturno';

  @override
  String get visibilityCalculating => 'Calculando visibilidad...';

  @override
  String get visibilityVisibleNow => 'Visible ahora';

  @override
  String get visibilityTonight => 'Esta noche';

  @override
  String get visibilityVisible => 'visible';

  @override
  String get visibilitySince => 'DESDE';

  @override
  String get visibilityFrom => 'DESDE';

  @override
  String get visibilityUntil => 'HASTA';

  @override
  String get notificationAlertTitle => 'Alerta de visibilidad';

  @override
  String get notificationAlertSubtitle =>
      'Recibir notificación cuando la estrella salga';

  @override
  String get visibilityStatusNeverVisible => 'Nunca visible';

  @override
  String get visibilityStatusVisibleNow => 'Visible ahora';

  @override
  String get visibilityStatusWaitForDark => 'Esperar a que oscurezca';

  @override
  String get visibilityStatusBelowHorizon => 'Bajo el horizonte';

  @override
  String get visibilityNow => 'Ahora';

  @override
  String visibilityStatusTonight(String time) {
    return 'Esta noche $time';
  }

  @override
  String visibilityStatusTomorrow(String time) {
    return 'Mañana $time';
  }

  @override
  String visibilityStatusInDays(int days, int hours) {
    return '${days}d ${hours}h';
  }

  @override
  String get legal => 'Legal';

  @override
  String get legalSubtitle => 'Términos de uso y Política de privacidad';

  @override
  String get termsOfUse => 'Términos de uso';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get ok => 'OK';

  @override
  String get scannerNotAvailable => 'Escáner no disponible';

  @override
  String get scannerNotAvailableOnWeb =>
      'El escáner de certificados requiere una cámara y solo está disponible en la aplicación móvil. Por favor, ingresa tu número de registro manualmente.';

  @override
  String get skyPreviewTitle => 'El cielo nocturno sobre ti';

  @override
  String skyPreviewTitleWithLocation(String locationName) {
    return 'El cielo nocturno sobre $locationName';
  }

  @override
  String get calculateNightSky => 'Calcular cielo nocturno';

  @override
  String get skyPreviewCalculating => 'Calculando tu cielo nocturno';

  @override
  String skyPreviewCalculatingWithLocation(String locationName) {
    return 'Calculando el cielo nocturno sobre $locationName';
  }

  @override
  String get skyPreviewHint => 'Toca una estrella para descubrirla';

  @override
  String get skyPreviewContinue => 'Continuar';

  @override
  String get signInTitle => 'Iniciar sesión';

  @override
  String get signInSubtitle => 'Guarda tus estrellas en todos tus dispositivos';

  @override
  String get signInCreateAccount => 'Crear cuenta';

  @override
  String get signInWelcomeBack => 'Bienvenido de nuevo';

  @override
  String get signInWithGoogle => 'Continuar con Google';

  @override
  String get signInWithApple => 'Continuar con Apple';

  @override
  String get signInWithEmail => 'Continuar con correo';

  @override
  String get signInOr => 'o';

  @override
  String get signInEmail => 'Correo electrónico';

  @override
  String get signInPassword => 'Contraseña';

  @override
  String get signInForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get signInSignIn => 'Iniciar sesión';

  @override
  String get signInAlreadyHaveAccount => '¿Ya tienes una cuenta?';

  @override
  String get signInNoAccount => '¿No tienes cuenta?';

  @override
  String get signInBackToOptions => 'Todas las opciones';

  @override
  String get signInEmailOptIn =>
      'Mantenme informado con consejos de observación, novedades y ofertas especiales';

  @override
  String get signInSkip => 'Continuar sin cuenta';
}
