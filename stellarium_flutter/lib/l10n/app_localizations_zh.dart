// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Night Sky Guide';

  @override
  String get menu => '菜单';

  @override
  String get myStars => '我的星星';

  @override
  String get myStarsSubtitle => '已保存的位置和收藏';

  @override
  String get timeLocation => '时间与位置';

  @override
  String get timeLocationSubtitle => '设置观测时间和地点';

  @override
  String get visualEffects => '视觉效果';

  @override
  String get visualEffectsSubtitle => '天空显示、天体和网格';

  @override
  String get settings => '设置';

  @override
  String get settingsSubtitle => '应用偏好设置';

  @override
  String get location => '位置';

  @override
  String get time => '时间';

  @override
  String get searchCityAddress => '搜索城市、地址...';

  @override
  String get useMyLocation => '使用我的位置';

  @override
  String get detecting => '检测中...';

  @override
  String get unknownLocation => '未知位置';

  @override
  String get setToNow => '设为当前时间';

  @override
  String get applyChanges => '应用更改';

  @override
  String get setTime => '设置时间';

  @override
  String get now => '现在';

  @override
  String get cancel => '取消';

  @override
  String get apply => '应用';

  @override
  String get save => '保存';

  @override
  String get saved => '已保存';

  @override
  String get savedToMyStars => '已保存到我的星星';

  @override
  String get removedFromMyStars => '已从我的星星中移除';

  @override
  String get pointAtStar => '指向星星';

  @override
  String get removeFromMyStars => '从我的星星中移除';

  @override
  String get saveToMyStars => '保存到我的星星';

  @override
  String get noSavedStarsYet => '暂无保存的星星';

  @override
  String get tapStarIconHint => '点击任意星星信息页上的星星图标，即可保存到这里';

  @override
  String starRemoved(String name) {
    return '$name 已移除';
  }

  @override
  String get registration => '注册信息';

  @override
  String get registeredTo => '注册给';

  @override
  String get registrationDate => '日期';

  @override
  String get registrationNumber => '注册号';

  @override
  String get registry => '注册机构';

  @override
  String get properties => '属性';

  @override
  String get coordinates => '坐标';

  @override
  String get scientificName => '科学名称';

  @override
  String get magnitude => '星等';

  @override
  String get spectralType => '光谱类型';

  @override
  String get distance => '距离';

  @override
  String get parallax => '视差';

  @override
  String get objectType => '天体类型';

  @override
  String get doubleMultipleStar => '双星/聚星';

  @override
  String get rightAscension => '赤经';

  @override
  String get declination => '赤纬';

  @override
  String get skyDisplay => '天空显示';

  @override
  String get celestialObjects => '天体';

  @override
  String get gridLines => '网格与线条';

  @override
  String get displayOptions => '显示选项';

  @override
  String get constellationLines => '星座连线';

  @override
  String get constellationLinesDesc => '显示连接星座中恒星的线条';

  @override
  String get constellationNames => '星座名称';

  @override
  String get constellationNamesDesc => '显示星座名称标签';

  @override
  String get constellationArt => '星座图案';

  @override
  String get constellationArtDesc => '显示星座艺术插图';

  @override
  String get atmosphere => '大气层';

  @override
  String get atmosphereDesc => '显示大气效果和天空辉光';

  @override
  String get landscape => '地景';

  @override
  String get landscapeDesc => '显示地面/地平线景观';

  @override
  String get landscapeFog => '地景雾';

  @override
  String get landscapeFogDesc => '在地景上显示雾效果';

  @override
  String get milkyWay => '银河';

  @override
  String get milkyWayDesc => '显示银河系';

  @override
  String get dssBackground => 'DSS背景';

  @override
  String get dssBackgroundDesc => '显示数字巡天背景图像';

  @override
  String get stars => '恒星';

  @override
  String get starsDesc => '显示天空中的恒星';

  @override
  String get planets => '行星';

  @override
  String get planetsDesc => '显示行星和太阳系天体';

  @override
  String get deepSkyObjects => '深空天体';

  @override
  String get deepSkyObjectsDesc => '显示星云、星系和星团';

  @override
  String get satellites => '卫星';

  @override
  String get satellitesDesc => '显示人造卫星';

  @override
  String get azimuthalGrid => '地平坐标网格';

  @override
  String get azimuthalGridDesc => '显示高度/方位角坐标网格';

  @override
  String get equatorialGrid => '赤道坐标网格';

  @override
  String get equatorialGridDesc => '显示赤经/赤纬网格';

  @override
  String get equatorialJ2000Grid => 'J2000赤道坐标网格';

  @override
  String get equatorialJ2000GridDesc => '显示J2000历元赤道坐标';

  @override
  String get meridianLine => '子午线';

  @override
  String get meridianLineDesc => '显示子午线（穿过天顶的南北线）';

  @override
  String get eclipticLine => '黄道线';

  @override
  String get eclipticLineDesc => '显示黄道（太阳视运动路径）';

  @override
  String get nightMode => '夜间模式';

  @override
  String get nightModeDesc => '红色显示以保护夜视能力';

  @override
  String get loadingSkyView => '正在加载天空视图...';

  @override
  String get failedToLoadSkyView => '加载天空视图失败';

  @override
  String get locationPermissionDenied => '位置权限被拒绝';

  @override
  String get locationPermissionPermanentlyDenied => '位置权限已被永久拒绝。请在设置中启用。';

  @override
  String errorGettingLocation(String error) {
    return '获取位置时出错：$error';
  }

  @override
  String registrationNotFound(String number) {
    return '未找到注册号 \"$number\"';
  }

  @override
  String errorSearching(String error) {
    return '搜索时出错：$error';
  }

  @override
  String get recentSearch => '最近搜索';

  @override
  String get search => '搜索';

  @override
  String get language => '语言';

  @override
  String get languageSubtitle => '选择应用语言';

  @override
  String get english => '英语';

  @override
  String get german => '德语';

  @override
  String get chinese => '中文（简体）';

  @override
  String get systemDefault => '系统默认';

  @override
  String get subscription => '订阅';

  @override
  String get subscriptionSubtitle => '管理您的订阅';

  @override
  String get currentPlan => '当前方案';

  @override
  String get freePlan => '免费版';

  @override
  String get premiumPlan => '高级版';

  @override
  String get proPlan => '专业版';

  @override
  String get subscriptionActive => '已激活';

  @override
  String get subscriptionExpired => '已过期';

  @override
  String expiresOn(String date) {
    return '到期时间：$date';
  }

  @override
  String get restorePurchases => '恢复购买';

  @override
  String get restoringPurchases => '正在恢复...';

  @override
  String get purchasesRestored => '购买已成功恢复';

  @override
  String get noPurchasesToRestore => '没有可恢复的购买';

  @override
  String restoreError(String error) {
    return '恢复购买时出错：$error';
  }

  @override
  String get manageSubscription => '管理订阅';

  @override
  String get upgradeToPremium => '升级到高级版';

  @override
  String get tapToChangeLocation => '点击更改位置';

  @override
  String get currentLocation => '当前位置';

  @override
  String get checkingStarRegistry => '正在查询星星注册信息...';

  @override
  String get starNotYetNamed => '这颗星星尚未命名';

  @override
  String get giveUniqueNameHint => '给它起一个独特的名字，将在天空中显示';

  @override
  String get nameThisStar => '为这颗星星命名';

  @override
  String get viewStarIn3D => '3D查看星星';

  @override
  String get catalogId => '目录编号';

  @override
  String get atmosphereButton => '大气层';

  @override
  String get movementButton => '移动';

  @override
  String get searchPlaceholder => '搜索星星或天体...';

  @override
  String get onboardingExploreUniverse => '在口袋里探索宇宙';

  @override
  String get onboardingGetStarted => '开始使用';

  @override
  String get onboardingContinue => '继续';

  @override
  String get onboardingSkip => '跳过';

  @override
  String get onboardingSkipForNow => '暂时跳过';

  @override
  String get onboardingMaybeLater => '以后再说';

  @override
  String get onboardingRequesting => '请求中...';

  @override
  String get locationAccessTitle => '位置访问';

  @override
  String get locationAccessSubtitle => '允许访问位置，以便准确显示您所在位置的天空';

  @override
  String get locationAccuratePositions => '精确的星星位置';

  @override
  String get locationAccuratePositionsDesc => '查看从您确切位置看到的星星';

  @override
  String get locationCompassNav => '指南针导航';

  @override
  String get locationCompassNavDesc => '将手机对准天空中的星星';

  @override
  String get locationRiseSetTimes => '升起和落下时间';

  @override
  String get locationRiseSetTimesDesc => '了解天体在您位置的可见时间';

  @override
  String get locationPrivacyNotice => '您的位置仅在本地使用，绝不会被分享。';

  @override
  String get locationConfirmedTitle => '位置已确认';

  @override
  String get locationConfirmedSubtitle => '您的天空视图将根据您的位置进行定制';

  @override
  String get locationOpenSettings => '打开设置';

  @override
  String get locationGettingLocation => '正在获取位置...';

  @override
  String get locationServicesDisabled => '位置服务已禁用。请在设置中启用。';

  @override
  String get locationFailedBrowser => '获取位置失败。请在浏览器中允许位置访问。';

  @override
  String get notificationTitle => '保持更新';

  @override
  String get notificationSubtitle => '获取天文事件和最佳观测条件的通知';

  @override
  String get notificationMoonPhase => '月相提醒';

  @override
  String get notificationMoonPhaseDesc => '了解最佳观星夜晚';

  @override
  String get notificationCelestialEvents => '天文事件';

  @override
  String get notificationCelestialEventsDesc => '不错过流星雨和日食月食';

  @override
  String get notificationVisibility => '可见性提醒';

  @override
  String get notificationVisibilityDesc => '当行星最佳可见时获得通知';

  @override
  String get notificationPrivacyNotice => '您可以随时在应用中更改通知设置。';

  @override
  String get attTitle => '隐私与追踪';

  @override
  String get attSubtitle => '允许追踪以帮助我们改善您的体验并向您展示相关内容';

  @override
  String get attImproveApp => '改进应用';

  @override
  String get attImproveAppDesc => '帮助我们了解您如何使用应用以便改进';

  @override
  String get attRelevantContent => '相关内容';

  @override
  String get attRelevantContentDesc => '查看根据您的兴趣定制的推荐';

  @override
  String get attPrivacyMatters => '您的隐私很重要';

  @override
  String get attPrivacyMattersDesc => '我们绝不会将您的个人数据出售给第三方';

  @override
  String get attPrivacyNotice => '您可以随时在iOS设置 > 隐私 > 追踪中更改此设置。';

  @override
  String get starRegTitle => '找到您的星星';

  @override
  String get starRegSubtitle => '输入您的星星注册号码，在天空中找到您命名的星星';

  @override
  String get starRegFindButton => '找到我的星星';

  @override
  String get starRegNoStarYet => '我还没有命名星星';

  @override
  String get starRegNameAStar => '命名一颗星星';

  @override
  String get starRegEnterNumber => '请输入注册号码';

  @override
  String get starRegInvalidFormat => '格式无效。请使用：XXXX-XXXXX-XXXXXXXX';

  @override
  String get starRegNotFound => '未找到星星。请检查您的注册号码。';

  @override
  String get starRegSearchFailed => '搜索失败。请重试。';

  @override
  String starRegRemoved(String reason) {
    return '该星星已从注册表中移除。原因：$reason';
  }

  @override
  String get scanCertificate => '扫描证书';

  @override
  String get scanningCertificate => '正在扫描证书...';

  @override
  String get pointCameraAtCertificate => '将相机对准您的证书';

  @override
  String get registrationNumberWillBeDetected => '注册号码将自动识别';

  @override
  String get registrationNumberFound => '找到号码';

  @override
  String get searchForThisNumber => '搜索此注册号码？';

  @override
  String get scanAgain => '重新扫描';

  @override
  String get searchStar => '搜索星星';

  @override
  String get enterManually => '手动输入';

  @override
  String get enterRegistrationNumber => '输入注册号码';

  @override
  String get registrationNumberHint => '例如 1234-56789-1234567';

  @override
  String get noRegistrationNumberFound => '未找到注册号码。请重试或手动输入。';

  @override
  String get couldNotCaptureImage => '无法拍摄图像。请重试。';
}
