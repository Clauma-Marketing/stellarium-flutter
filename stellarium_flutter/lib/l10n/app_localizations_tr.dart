// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Star Registration Planetarium';

  @override
  String get menu => 'Menü';

  @override
  String get myStars => 'Yıldızlarım';

  @override
  String get myStarsSubtitle => 'Kayıtlı konumlar ve favoriler';

  @override
  String get timeLocation => 'Zaman ve Konum';

  @override
  String get timeLocationSubtitle => 'Gözlem zamanını ve yerini ayarla';

  @override
  String get visualEffects => 'Görsel Efektler';

  @override
  String get visualEffectsSubtitle => 'Gökyüzü görünümü, nesneler ve ızgaralar';

  @override
  String get settings => 'Ayarlar';

  @override
  String get settingsSubtitle => 'Uygulama tercihleri';

  @override
  String get location => 'KONUM';

  @override
  String get time => 'ZAMAN';

  @override
  String get searchCityAddress => 'Şehir, adres ara...';

  @override
  String get useMyLocation => 'Konumumu Kullan';

  @override
  String get detecting => 'Algılanıyor...';

  @override
  String get unknownLocation => 'Bilinmeyen konum';

  @override
  String get setToNow => 'Şimdiye Ayarla';

  @override
  String get applyChanges => 'Değişiklikleri Uygula';

  @override
  String get setTime => 'Zamanı Ayarla';

  @override
  String get now => 'Şimdi';

  @override
  String get cancel => 'İptal';

  @override
  String get apply => 'Uygula';

  @override
  String get back => 'Geri';

  @override
  String get save => 'Kaydet';

  @override
  String get saved => 'Kaydedildi';

  @override
  String get savedToMyStars => 'Yıldızlarım\'a kaydedildi';

  @override
  String get removedFromMyStars => 'Yıldızlarım\'dan kaldırıldı';

  @override
  String get pointAtStar => 'Yıldızı Göster';

  @override
  String get removeFromMyStars => 'Yıldızlarım\'dan Kaldır';

  @override
  String get saveToMyStars => 'Yıldızlarım\'a Kaydet';

  @override
  String get noSavedStarsYet => 'Henüz kayıtlı yıldız yok';

  @override
  String get tapStarIconHint =>
      'Bir yıldızın bilgi kartındaki yıldız simgesine dokunarak onu buraya kaydedebilirsin';

  @override
  String starRemoved(String name) {
    return '$name kaldırıldı';
  }

  @override
  String get registration => 'KAYIT';

  @override
  String get registeredTo => 'Adına kayıtlı';

  @override
  String get registrationDate => 'Tarih';

  @override
  String get registrationNumber => 'Kayıt No';

  @override
  String get registry => 'Sicil';

  @override
  String get properties => 'ÖZELLİKLER';

  @override
  String get coordinates => 'KOORDİNATLAR';

  @override
  String get scientificName => 'Bilimsel Ad';

  @override
  String get magnitude => 'Kadir (Parlaklık)';

  @override
  String get spectralType => 'Tayf Türü';

  @override
  String get distance => 'Uzaklık';

  @override
  String get parallax => 'Paralaks';

  @override
  String get objectType => 'Nesne Türü';

  @override
  String get doubleMultipleStar => 'Çift/Çoklu Yıldız';

  @override
  String get rightAscension => 'Sağ Açıklık';

  @override
  String get declination => 'Dik Açıklık';

  @override
  String get skyDisplay => 'Gökyüzü Görünümü';

  @override
  String get celestialObjects => 'Gök Cisimleri';

  @override
  String get gridLines => 'Izgaralar ve Çizgiler';

  @override
  String get displayOptions => 'Görünüm Seçenekleri';

  @override
  String get constellationLines => 'Takımyıldız Çizgileri';

  @override
  String get constellationLinesDesc =>
      'Takımyıldızlardaki yıldızları birleştiren çizgileri göster';

  @override
  String get constellationNames => 'Takımyıldız Adları';

  @override
  String get constellationNamesDesc => 'Takımyıldız ad etiketlerini göster';

  @override
  String get constellationArt => 'Takımyıldız Çizimleri';

  @override
  String get constellationArtDesc =>
      'Sanatsal takımyıldız illüstrasyonlarını göster';

  @override
  String get atmosphere => 'Atmosfer';

  @override
  String get atmosphereDesc => 'Atmosfer efektlerini ve gök ışımasını göster';

  @override
  String get landscape => 'Manzara';

  @override
  String get landscapeDesc => 'Zemin/ufuk manzarasını göster';

  @override
  String get landscapeFog => 'Manzara Sisi';

  @override
  String get landscapeFogDesc => 'Manzarada sis efektini göster';

  @override
  String get milkyWay => 'Samanyolu';

  @override
  String get milkyWayDesc => 'Samanyolu galaksisini göster';

  @override
  String get dssBackground => 'DSS Arka Planı';

  @override
  String get dssBackgroundDesc =>
      'Digital Sky Survey arka plan görüntülerini göster';

  @override
  String get stars => 'Yıldızlar';

  @override
  String get starsDesc => 'Gökyüzündeki yıldızları göster';

  @override
  String get planets => 'Gezegenler';

  @override
  String get planetsDesc => 'Gezegenleri ve Güneş Sistemi cisimlerini göster';

  @override
  String get deepSkyObjects => 'Derin Gökyüzü Cisimleri';

  @override
  String get deepSkyObjectsDesc =>
      'Bulutsuları, galaksileri ve yıldız kümelerini göster';

  @override
  String get satellites => 'Uydular';

  @override
  String get satellitesDesc => 'Yapay uyduları göster';

  @override
  String get azimuthalGrid => 'Azimut Izgarası';

  @override
  String get azimuthalGridDesc =>
      'Yükseklik/azimut koordinat ızgarasını göster';

  @override
  String get equatorialGrid => 'Ekvatoral Izgara';

  @override
  String get equatorialGridDesc => 'Sağ açıklık/dik açıklık ızgarasını göster';

  @override
  String get equatorialJ2000Grid => 'Ekvatoral J2000 Izgarası';

  @override
  String get equatorialJ2000GridDesc =>
      'J2000 dönemi ekvatoral koordinatlarını göster';

  @override
  String get meridianLine => 'Meridyen Çizgisi';

  @override
  String get meridianLineDesc =>
      'Meridyeni göster (başucundan geçen kuzey-güney çizgisi)';

  @override
  String get eclipticLine => 'Ekliptik Çizgisi';

  @override
  String get eclipticLineDesc => 'Ekliptiği göster (Güneş\'in görünür yolu)';

  @override
  String get nightMode => 'Gece Modu';

  @override
  String get nightModeDesc =>
      'Gece görüşünü korumak için ekranı kırmızı tonlara kaydır';

  @override
  String get loadingSkyView => 'Gökyüzü görünümü yükleniyor...';

  @override
  String get failedToLoadSkyView => 'Gökyüzü görünümü yüklenemedi';

  @override
  String get locationPermissionDenied => 'Konum izni reddedildi';

  @override
  String get locationPermissionPermanentlyDenied =>
      'Konum izni kalıcı olarak reddedildi. Lütfen Ayarlar\'dan etkinleştir.';

  @override
  String errorGettingLocation(String error) {
    return 'Konum alınırken hata oluştu: $error';
  }

  @override
  String registrationNotFound(String number) {
    return '\"$number\" numaralı kayıt bulunamadı';
  }

  @override
  String errorSearching(String error) {
    return 'Arama sırasında hata oluştu: $error';
  }

  @override
  String get recentSearch => 'Son arama';

  @override
  String get search => 'Ara';

  @override
  String get language => 'Dil';

  @override
  String get languageSubtitle => 'Uygulama dilini seç';

  @override
  String get english => 'İngilizce';

  @override
  String get german => 'Almanca';

  @override
  String get chinese => 'Çince (Basitleştirilmiş)';

  @override
  String get systemDefault => 'Sistem Varsayılanı';

  @override
  String get subscription => 'Abonelik';

  @override
  String get subscriptionSubtitle => 'Aboneliğini yönet';

  @override
  String get currentPlan => 'Mevcut Plan';

  @override
  String get freePlan => 'Ücretsiz';

  @override
  String get premiumPlan => 'Premium';

  @override
  String get proPlan => 'Pro';

  @override
  String get subscriptionActive => 'Aktif';

  @override
  String get subscriptionExpired => 'Süresi Doldu';

  @override
  String expiresOn(String date) {
    return '$date tarihinde sona eriyor';
  }

  @override
  String get restorePurchases => 'Satın Alımları Geri Yükle';

  @override
  String get restoringPurchases => 'Geri yükleniyor...';

  @override
  String get purchasesRestored => 'Satın alımlar başarıyla geri yüklendi';

  @override
  String get noPurchasesToRestore => 'Geri yüklenecek satın alım yok';

  @override
  String restoreError(String error) {
    return 'Satın alımlar geri yüklenirken hata oluştu: $error';
  }

  @override
  String get subscriptionLoading => 'Abonelik seçenekleri yükleniyor...';

  @override
  String get subscriptionRequiredMessage =>
      'Uygulamayı kullanmaya devam etmek için abonelik veya geçerli bir yıldız kaydı gerekiyor.';

  @override
  String get subscriptionSubscribeButton => 'Şimdi Abone Ol';

  @override
  String gateWarningMessage(int seconds) {
    return 'Ücretsiz gökyüzü ön izlemen $seconds sn sonra bitiyor';
  }

  @override
  String get gateWarningCta => 'Planları gör';

  @override
  String get manageSubscription => 'Aboneliği Yönet';

  @override
  String get upgradeToPremium => 'Premium\'a Yükselt';

  @override
  String get tapToChangeLocation => 'Konumu değiştirmek için dokun';

  @override
  String get currentLocation => 'Mevcut Konum';

  @override
  String get checkingStarRegistry => 'Yıldız sicili kontrol ediliyor...';

  @override
  String get starNotYetNamed => 'Bu yıldız henüz adlandırılmamış';

  @override
  String get giveUniqueNameHint => 'Ona gökyüzünde görünecek eşsiz bir ad ver';

  @override
  String get nameThisStar => 'Bu Yıldızı Adlandır';

  @override
  String get viewStarIn3D => '3B Görünüm';

  @override
  String get catalogId => 'Katalog No';

  @override
  String get atmosphereButton => 'Atmosfer';

  @override
  String get movementButton => 'Hareket';

  @override
  String get searchPlaceholder => 'Bir yıldız veya nesne ara...';

  @override
  String get welcomeTitle => 'Evreni Keşfet';

  @override
  String get onboardingExploreUniverse =>
      'Gece gökyüzünü keşfet, gök olaylarını takip et ve milyonlarca yıldız arasından adını taşıyan yıldızı bul.';

  @override
  String get onboardingGetStarted => 'Başla';

  @override
  String get onboardingContinue => 'Devam Et';

  @override
  String get onboardingSkip => 'Atla';

  @override
  String get onboardingSkipForNow => 'Şimdilik atla';

  @override
  String get onboardingMaybeLater => 'Belki Daha Sonra';

  @override
  String get onboardingRequesting => 'İsteniyor...';

  @override
  String get locationAccessTitle => 'Konuma İzin Verilsin mi?';

  @override
  String get locationAccessSubtitle =>
      'Gece gökyüzünü tam olarak bulunduğun yerden göründüğü gibi gör. Konumunu, yıldız konumlarını doğru göstermek için kullanıyoruz.';

  @override
  String get locationAllowAccess => 'Devam Et';

  @override
  String get locationAccuratePositions => 'Doğru Yıldız Konumları';

  @override
  String get locationAccuratePositionsDesc =>
      'Yıldızları tam bulunduğun yerden göründükleri gibi gör';

  @override
  String get locationCompassNav => 'Pusula Navigasyonu';

  @override
  String get locationCompassNavDesc =>
      'Gökyüzündeki yıldızları bulmak için telefonunu doğrult';

  @override
  String get locationRiseSetTimes => 'Doğuş ve Batış Zamanları';

  @override
  String get locationRiseSetTimesDesc =>
      'Gök cisimlerinin bulunduğun yerden ne zaman görülebileceğini öğren';

  @override
  String get locationPrivacyNotice =>
      'Konumun yalnızca cihazında kullanılır ve asla paylaşılmaz.';

  @override
  String get locationConfirmedTitle => 'Konum Onaylandı';

  @override
  String get locationConfirmedSubtitle =>
      'Gökyüzü görünümün konumuna göre özelleştirilecek';

  @override
  String get locationOpenSettings => 'Ayarları Aç';

  @override
  String get locationGettingLocation => 'Konum Alınıyor...';

  @override
  String get locationServicesDisabled =>
      'Konum servisleri kapalı. Lütfen ayarlardan etkinleştir.';

  @override
  String get locationFailedBrowser =>
      'Konum alınamadı. Lütfen tarayıcında konum erişimine izin ver.';

  @override
  String get notificationTitle => 'Bildirimler Açılsın mı?';

  @override
  String get notificationSubtitle =>
      'Meteor yağmurlarını ve yıldız gözlemi için en iyi geceleri kaçırma. Sana önceden zamanında uyarılar göndereceğiz.';

  @override
  String get notificationAllowNotifications => 'Devam Et';

  @override
  String get notificationMoonPhase => 'Ay Evresi Uyarıları';

  @override
  String get notificationMoonPhaseDesc =>
      'Yıldız gözlemi için en iyi geceleri öğren';

  @override
  String get notificationCelestialEvents => 'Gök Olayları';

  @override
  String get notificationCelestialEventsDesc =>
      'Meteor yağmurlarını ve tutulmaları asla kaçırma';

  @override
  String get notificationVisibility => 'Görünürlük Uyarıları';

  @override
  String get notificationVisibilityDesc =>
      'Gezegenler en iyi göründüğünde bildirim al';

  @override
  String get notificationPrivacyNotice =>
      'Bildirim ayarlarını istediğin zaman uygulamadan değiştirebilirsin.';

  @override
  String get consentTitle => 'Gizlilik ve Veriler';

  @override
  String get consentMessage =>
      'Uygulamayı geliştirmek ve reklamlarımızı ölçmek için biz ve iş ortaklarımız (ör. Google), analiz, reklam ölçümü ve kişiselleştirilmiş reklamlar amacıyla kullanım verileri toplamak ve cihazında tanımlayıcılar saklamak istiyoruz. Seçimini istediğin zaman uygulama ayarlarından değiştirebilirsin.';

  @override
  String get consentAccept => 'Tümünü Kabul Et';

  @override
  String get consentDecline => 'Kabul Etmeden Devam Et';

  @override
  String get consentSettingsTitle => 'Analiz ve Kişiselleştirilmiş Reklamlar';

  @override
  String get consentSettingsSubtitle =>
      'Analiz ve reklam ölçümü için kullanım verisi toplanmasına izin ver';

  @override
  String get attTitle => 'Takibe İzin Verilsin mi?';

  @override
  String get attSubtitle =>
      'Kozmik yolculuğunu iyileştirmemize yardım et. Verileri, sana özel içgörüler sunmak ve ilgini çekebilecek etkinlikleri önermek için kullanıyoruz.';

  @override
  String get attAllowTracking => 'Devam Et';

  @override
  String get attDontTrack => 'Uygulamadan Takip Etmemesini İste';

  @override
  String get attImproveApp => 'Uygulamayı Geliştir';

  @override
  String get attImproveAppDesc =>
      'Uygulamayı nasıl kullandığını anlamamıza yardım et, böylece onu daha iyi hale getirelim';

  @override
  String get attRelevantContent => 'Sana Uygun İçerik';

  @override
  String get attRelevantContentDesc =>
      'İlgi alanlarına göre uyarlanmış öneriler gör';

  @override
  String get attPrivacyMatters => 'Gizliliğin Önemli';

  @override
  String get attPrivacyMattersDesc =>
      'Kişisel verilerini asla üçüncü taraflara satmıyoruz';

  @override
  String get attPrivacyNotice =>
      'Bu ayarı istediğin zaman iOS Ayarlar > Gizlilik > Takip bölümünden değiştirebilirsin.';

  @override
  String get starRegTitle => 'Yıldızını Bul';

  @override
  String get starRegSubtitle =>
      'Adını taşıyan yıldızı gökyüzünde bulmak için yıldız kayıt numaranı gir';

  @override
  String get starRegFindButton => 'Yıldızımı Bul';

  @override
  String get starRegNoStarYet => 'Henüz bir yıldız adlandırmadım';

  @override
  String get starRegNameAStar => 'Bir Yıldız Adlandır';

  @override
  String get starRegQuestionTitle => 'Kişisel Planetaryumun';

  @override
  String get starRegQuestionSubtitle => 'Nasıl başlamak istersin?';

  @override
  String get starRegExploreCardTitle => 'Gece Gökyüzünü Keşfet';

  @override
  String get starRegExploreCardBody =>
      'Üzerindeki yıldızları, gezegenleri ve takımyıldızları keşfet — nerede olursan ol, canlı olarak.';

  @override
  String get starRegHaveStarCardTitle => 'Adlandırılmış Yıldızını Bul';

  @override
  String get starRegHaveStarCardBody =>
      'Örneğin hediye olarak bir yıldız kaydı mı aldın? Kişisel yıldızını gökyüzünde bul.';

  @override
  String get starRegStartExploring => 'Keşfe Başla';

  @override
  String get starRegHaveStar => 'Adlandırılmış bir yıldızım var';

  @override
  String get starRegEnterNumber => 'Lütfen bir kayıt numarası gir';

  @override
  String get starRegInvalidFormat =>
      'Geçersiz biçim. Şu biçimi kullan: XXXX-XXXXX-XXXXXXXX';

  @override
  String get starRegNotFound =>
      'Yıldız bulunamadı. Lütfen kayıt numaranı kontrol et.';

  @override
  String get starRegSearchFailed => 'Arama başarısız oldu. Lütfen tekrar dene.';

  @override
  String starRegRemoved(String reason) {
    return '$reason';
  }

  @override
  String get scanCertificate => 'Sertifikayı Tara';

  @override
  String get scanningCertificate => 'Sertifika taranıyor...';

  @override
  String get pointCameraAtCertificate => 'Kamerayı sertifikana doğrult';

  @override
  String get registrationNumberWillBeDetected =>
      'Kayıt numarası otomatik olarak algılanacak';

  @override
  String get registrationNumberFound => 'Numara Bulundu';

  @override
  String get searchForThisNumber => 'Bu kayıt numarası aransın mı?';

  @override
  String get scanAgain => 'Tekrar Tara';

  @override
  String get searchStar => 'Yıldızı Ara';

  @override
  String get enterManually => 'Elle gir';

  @override
  String get enterRegistrationNumber => 'Kayıt Numarasını Gir';

  @override
  String get registrationNumberHint => 'ör. 1234-56789-1234567';

  @override
  String get noRegistrationNumberFound =>
      'Kayıt numarası bulunamadı. Tekrar dene veya elle gir.';

  @override
  String get couldNotCaptureImage => 'Görüntü alınamadı. Lütfen tekrar dene.';

  @override
  String get showStarPath => '24 Saatlik Yolu Göster';

  @override
  String get hideStarPath => '24 Saatlik Yolu Gizle';

  @override
  String get loaderQuote1 => 'Evrene açılan kişisel penceren';

  @override
  String get loaderQuote2 => 'Her yıldız, verilmeyi bekleyen bir ad taşır';

  @override
  String get loaderQuote3 =>
      'Üzerindeki gökyüzü, haritalanmış ve seni bekliyor';

  @override
  String get loaderQuote4 => 'Işığa kazınmış bir ad, sonsuza dek senin';

  @override
  String get loaderQuote5 => 'Milyonlarca yıldız — biri sana ait';

  @override
  String get loaderQuote6 => 'Kadim ışığın bakışlarınla buluştuğu yer';

  @override
  String get loaderQuote7 => 'Evren her adı hatırlar';

  @override
  String get loaderQuote8 => 'Yukarı bak. Yıldızlar arasındaki yerini bul.';

  @override
  String get loaderStatus1 => 'Koordinatların belirleniyor';

  @override
  String get loaderStatus2 => 'Gök küresi haritalanıyor';

  @override
  String get loaderStatus3 => 'Görünür takımyıldızlar çiziliyor';

  @override
  String get loaderStatus4 => 'Yıldız konumları hesaplanıyor';

  @override
  String get loaderStatus5 => 'Gece gökyüzün hazırlanıyor';

  @override
  String get visibilityCalculating => 'Görünürlük hesaplanıyor...';

  @override
  String get visibilityVisibleNow => 'Şu An Görünür';

  @override
  String get visibilityTonight => 'Bu Gece';

  @override
  String get visibilityVisible => 'görünür';

  @override
  String get visibilitySince => 'BAŞLADI';

  @override
  String get visibilityFrom => 'BAŞLANGIÇ';

  @override
  String get visibilityUntil => 'BİTİŞ';

  @override
  String get notificationAlertTitle => 'Görünürlük Uyarısı';

  @override
  String get notificationAlertSubtitle => 'Yıldız doğduğunda bildirim al';

  @override
  String get visibilityStatusNeverVisible => 'Hiç görünmez';

  @override
  String get visibilityStatusVisibleNow => 'Şu an görünür';

  @override
  String get visibilityStatusWaitForDark => 'Havanın kararmasını bekle';

  @override
  String get visibilityStatusBelowHorizon => 'Ufkun altında';

  @override
  String get visibilityNow => 'Şimdi';

  @override
  String visibilityStatusTonight(String time) {
    return 'Bu gece $time';
  }

  @override
  String visibilityStatusTomorrow(String time) {
    return 'Yarın $time';
  }

  @override
  String visibilityStatusInDays(int days, int hours) {
    return '${days}g ${hours}s';
  }

  @override
  String get legal => 'Yasal';

  @override
  String get legalSubtitle => 'Kullanım Koşulları ve Gizlilik Politikası';

  @override
  String get termsOfUse => 'Kullanım Koşulları';

  @override
  String get privacyPolicy => 'Gizlilik Politikası';

  @override
  String get ok => 'Tamam';

  @override
  String get scannerNotAvailable => 'Tarayıcı Kullanılamıyor';

  @override
  String get scannerNotAvailableOnWeb =>
      'Sertifika tarayıcısı kamera gerektirir ve yalnızca mobil uygulamada kullanılabilir. Lütfen kayıt numaranı elle gir.';

  @override
  String get skyPreviewTitle => 'Üzerindeki Gece Gökyüzü';

  @override
  String skyPreviewTitleWithLocation(String locationName) {
    return '$locationName Üzerindeki Gece Gökyüzü';
  }

  @override
  String get calculateNightSky => 'Gece Gökyüzünü Hesapla';

  @override
  String get skyPreviewCalculating => 'Gece Gökyüzün Hesaplanıyor';

  @override
  String skyPreviewCalculatingWithLocation(String locationName) {
    return '$locationName üzerindeki gece gökyüzü hesaplanıyor';
  }

  @override
  String get skyPreviewHint => 'Keşfetmek için bir yıldıza dokun';

  @override
  String get skyPreviewContinue => 'Devam Et';

  @override
  String get signInTitle => 'Giriş Yap';

  @override
  String get signInSubtitle => 'Yıldızlarını tüm cihazlarında sakla';

  @override
  String get signInCreateAccount => 'Hesap Oluştur';

  @override
  String get signInWelcomeBack => 'Tekrar Hoş Geldin';

  @override
  String get signInWithGoogle => 'Google ile devam et';

  @override
  String get signInWithApple => 'Apple ile devam et';

  @override
  String get signInWithEmail => 'E-posta ile devam et';

  @override
  String get signInOr => 'veya';

  @override
  String get signInEmail => 'E-posta';

  @override
  String get signInPassword => 'Şifre';

  @override
  String get signInForgotPassword => 'Şifreni mi unuttun?';

  @override
  String get signInSignIn => 'Giriş Yap';

  @override
  String get signInAlreadyHaveAccount => 'Zaten hesabın var mı?';

  @override
  String get signInNoAccount => 'Hesabın yok mu?';

  @override
  String get signInBackToOptions => 'Tüm giriş seçenekleri';

  @override
  String get signInEmailOptIn =>
      'Yıldız gözlemi ipuçları, yeni özellikler ve özel tekliflerden beni haberdar et';

  @override
  String get signInSkip => 'Hesap olmadan devam et';

  @override
  String get starRemovedFromRegistryTitle => 'Yıldız kayıttan kaldırıldı';

  @override
  String starRemovedFromRegistryMessage(String name) {
    return '\"$name\" artık yıldız kaydında yer almıyor, bu nedenle kayıtlı adı gökyüzünde gösterilmiyor.';
  }

  @override
  String get starRemovedFromRegistryHint =>
      'Yıldızı Yıldızlarım listesinde tutabilir veya silmek için kaydırabilirsiniz.';

  @override
  String get starRemovedFromRegistryBadge => 'Kayıttan kaldırıldı';

  @override
  String starRemovalReason(String reason) {
    return 'Neden: $reason';
  }
}
