import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../features/onboarding/onboarding_service.dart';
import '../l10n/app_localizations.dart';
import '../services/firestore_sync_service.dart';
import '../services/notification_preferences.dart';
import '../services/saved_stars_service.dart';
import '../utils/star_visibility.dart';

/// Star registration info from the celestial registry API
class StarRegistryInfo {
  final String name;
  final String registrationDate;
  final String registrationNumber;
  final String register;

  StarRegistryInfo({
    required this.name,
    required this.registrationDate,
    required this.registrationNumber,
    required this.register,
  });

  factory StarRegistryInfo.fromJson(Map<String, dynamic> json) {
    return StarRegistryInfo(
      name: json['name'] as String? ?? 'Unknown',
      registrationDate: json['registration_date'] as String? ?? 'Unknown',
      registrationNumber: json['registration_number'] as String? ?? '',
      register: json['register'] as String? ?? '',
    );
  }
}

/// Star model data from the celestial registry API
class StarModelData {
  final String identifier;
  final String shortName;
  final String spectralType;
  final double declination;
  final double rightAscension;
  final String j2000Dec;
  final String j2000Ra;
  final double? parallax;
  final double? bMagnitude;
  final double? vMagnitude;
  final String objectType;
  final bool isDoubleOrMultiple;

  StarModelData({
    required this.identifier,
    required this.shortName,
    required this.spectralType,
    required this.declination,
    required this.rightAscension,
    required this.j2000Dec,
    required this.j2000Ra,
    this.parallax,
    this.bMagnitude,
    this.vMagnitude,
    required this.objectType,
    required this.isDoubleOrMultiple,
  });

  factory StarModelData.fromJson(Map<String, dynamic> json, {
    String? identifier,
    String? shortName,
    String? objectType,
  }) {
    // Handle case-insensitive field names (API may send Vmag or vmag)
    double? getNum(String key) {
      final value = json[key] ?? json[key.toLowerCase()] ?? json[key[0].toUpperCase() + key.substring(1)];
      return (value as num?)?.toDouble();
    }

    return StarModelData(
      identifier: identifier ?? json['identifier'] as String? ?? '',
      shortName: shortName ?? json['short_name'] as String? ?? '',
      spectralType: json['spect_t'] as String? ?? json['Spect_t'] as String? ?? '',
      declination: getNum('de') ?? 0.0,
      rightAscension: getNum('ra') ?? 0.0,
      j2000Dec: json['j2000dec'] as String? ?? '',
      j2000Ra: json['j2000ra'] as String? ?? '',
      parallax: getNum('plx'),
      bMagnitude: getNum('Bmag') ?? getNum('bmag'),
      vMagnitude: getNum('Vmag') ?? getNum('vmag'),
      objectType: objectType ?? json['otype'] as String? ?? '',
      isDoubleOrMultiple: json['isDoubleOrMultipleStar'] == '1',
    );
  }

  /// Calculate distance in light years from parallax (in milliarcseconds)
  double? get distanceLightYears {
    if (parallax == null || parallax! <= 0) return null;
    // Distance in parsecs = 1000 / parallax (mas)
    // 1 parsec = 3.26156 light years
    return (1000 / parallax!) * 3.26156;
  }

  /// Get the search identifier formatted with space (e.g., "HIP14778" -> "HIP 14778")
  String get searchIdentifier {
    final match = RegExp(r'^([A-Za-z]+)(\d.*)$').firstMatch(identifier);
    if (match != null) {
      return '${match.group(1)} ${match.group(2)}';
    }
    return identifier;
  }
}

/// Complete star info combining registry and model data
class StarInfo {
  final bool found;
  final String model;
  final String shortName;
  final StarModelData? modelData;
  final StarRegistryInfo? registryInfo;
  final bool isRegistered;
  final String? removalReason; // If star was removed from registry, this contains the reason

  StarInfo({
    required this.found,
    required this.model,
    required this.shortName,
    this.modelData,
    this.registryInfo,
    this.isRegistered = false,
    this.removalReason,
  });

  factory StarInfo.fromApiResponse(Map<String, dynamic> json) {
    final info = json['info'] as Map<String, dynamic>?;
    final modelData = json['model_data'] as Map<String, dynamic>?;
    final hasRegistry = info != null && info['resolved'] == true;

    // Check if there's a message (e.g., "refund" means star was removed)
    final message = json['message'] as String?;
    final wasFoundExplicit = json['found'] as bool?;

    // If found is explicitly false and there's a message, star was removed
    if (wasFoundExplicit == false && message != null) {
      debugPrint('StarInfo.fromApiResponse: Star removed from registry. Reason: $message');
      return StarInfo(
        found: false,
        model: 'star',
        shortName: '',
        removalReason: message,
      );
    }

    // Determine if star was found - either explicit 'found' field or presence of model_data/match
    final wasFound = wasFoundExplicit ??
        (modelData != null || json['match'] != null || json['short_name'] != null);

    // Extract identifier - try root 'match', then model_data 'identifier'
    String identifier = json['match'] as String? ?? '';
    if (identifier.isEmpty && modelData != null) {
      identifier = modelData['identifier'] as String? ?? '';
    }
    // Also try to find HIP from names array if identifier is still empty
    if (identifier.isEmpty) {
      final names = (json['names'] as List<dynamic>?)?.cast<String>() ?? [];
      for (final name in names) {
        if (name.startsWith('HIP')) {
          identifier = name;
          break;
        }
      }
    }

    final shortName = json['short_name'] as String? ?? '';
    final types = (json['types'] as List<dynamic>?)?.cast<String>() ?? [];
    final objectType = types.isNotEmpty ? types.first : '';

    debugPrint('StarInfo.fromApiResponse: identifier=$identifier, shortName=$shortName, hasRegistry=$hasRegistry');

    return StarInfo(
      found: wasFound,
      model: json['model'] as String? ?? 'star',
      shortName: shortName,
      modelData: modelData != null
          ? StarModelData.fromJson(
              modelData,
              identifier: identifier,
              shortName: shortName,
              objectType: objectType,
            )
          : null,
      registryInfo: hasRegistry ? StarRegistryInfo.fromJson(info) : null,
      isRegistered: hasRegistry,
    );
  }

  /// Create from basic star data (when selecting from sky view)
  /// [names] is a list of identifiers like ["NAME Vega", "* alf Lyr", "HIP 91262", "HD 172167"]
  factory StarInfo.fromBasicData({
    required String name,
    double? ra,
    double? dec,
    double? magnitude,
    String? spectralType,
    List<String>? names,
  }) {
    // Extract catalog ID (HIP/HD) from names list if available
    String catalogId = '';
    if (names != null) {
      for (final n in names) {
        if (n.startsWith('HIP ') || n.startsWith('HIP')) {
          catalogId = n.replaceAll(' ', ''); // Normalize to HIP91262
          break;
        }
      }
      if (catalogId.isEmpty) {
        for (final n in names) {
          if (n.startsWith('HD ') || n.startsWith('HD')) {
            catalogId = n.replaceAll(' ', '');
            break;
          }
        }
      }
    }

    return StarInfo(
      found: true,
      model: 'star',
      shortName: name,
      modelData: StarModelData(
        identifier: catalogId, // Use HIP/HD as identifier, not the display name
        shortName: name,
        spectralType: spectralType ?? '',
        declination: dec ?? 0,
        rightAscension: ra ?? 0,
        j2000Dec: dec != null ? _formatDec(dec) : '',
        j2000Ra: ra != null ? _formatRa(ra) : '',
        vMagnitude: magnitude,
        objectType: 'Star',
        isDoubleOrMultiple: false,
      ),
      isRegistered: false,
    );
  }

  static String _formatRa(double ra) {
    // Convert RA from degrees to hours, minutes, seconds
    final hours = ra / 15.0;
    final h = hours.floor();
    final m = ((hours - h) * 60).floor();
    final s = ((hours - h) * 60 - m) * 60;
    return '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m ${s.toStringAsFixed(1)}s';
  }

  static String _formatDec(double dec) {
    // Convert Dec from degrees to degrees, arcminutes, arcseconds
    final sign = dec >= 0 ? '+' : '-';
    final absDec = dec.abs();
    final d = absDec.floor();
    final m = ((absDec - d) * 60).floor();
    final s = ((absDec - d) * 60 - m) * 60;
    return '$sign${d.toString().padLeft(2, '0')}° ${m.toString().padLeft(2, '0')}\' ${s.toStringAsFixed(1)}"';
  }
}

/// Service for fetching star information
class StarRegistryService {
  static const String _baseUrl = 'https://registry-api.celestial-register.com/';

  /// Check if query looks like a registration number
  static bool isRegistrationNumber(String query) {
    // Registration numbers are in format like "3100-14778-5153771"
    final regExp = RegExp(r'^\d{4}-\d{4,5}-\d{6,7}$');
    return regExp.hasMatch(query.trim());
  }

  /// Search for a star by registration number
  static Future<StarInfo?> searchByRegistrationNumber(String registrationNumber) async {
    try {
      final url = Uri.parse('$_baseUrl?RN=${Uri.encodeComponent(registrationNumber.trim())}');
      final response = await http.get(url, headers: {
        'User-Agent': 'StellariumFlutter/1.0',
      });

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return StarInfo.fromApiResponse(json);
      }
      return null;
    } catch (e) {
      debugPrint('Star registry search error: $e');
      return null;
    }
  }

  /// Search for a star by name (e.g., "HIP 14778", "Polaris")
  /// Pass [validIdentifiers] to validate the result matches the expected star
  static Future<StarInfo?> searchByName(String name, {List<String>? validIdentifiers}) async {
    try {
      // Clean up the name - remove Stellarium prefixes like "NAME ", "* ", etc.
      String cleanName = name.trim();
      if (cleanName.startsWith('NAME ')) {
        cleanName = cleanName.substring(5);
      } else if (cleanName.startsWith('* ')) {
        cleanName = cleanName.substring(2);
      }

      // Remove spaces from catalog identifiers (API expects HIP746 not HIP 746)
      if (cleanName.startsWith('HIP ') || cleanName.startsWith('HD ') ||
          cleanName.startsWith('HR ') || cleanName.startsWith('SAO ') ||
          cleanName.startsWith('TYC ') || cleanName.startsWith('BD ') ||
          cleanName.startsWith('FK ') || cleanName.startsWith('GJ ')) {
        cleanName = cleanName.replaceAll(' ', '');
      }

      final url = Uri.parse('${_baseUrl}search?name=${Uri.encodeComponent(cleanName)}');
      debugPrint('Star registry API call: $url');
      final response = await http.get(url, headers: {
        'User-Agent': 'StellariumFlutter/1.0',
      });

      debugPrint('Star registry API response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('Star registry API response: $decoded');
        // API may return an array of results or a single object
        Map<String, dynamic>? json;
        if (decoded is List && decoded.isNotEmpty) {
          json = decoded[0] as Map<String, dynamic>;
          debugPrint('Star registry API first result: $json');
        } else if (decoded is Map<String, dynamic>) {
          json = decoded;
        }

        if (json != null) {
          // Validate the result matches the expected star if identifiers provided
          if (validIdentifiers != null && validIdentifiers.isNotEmpty) {
            final resultNames = (json['names'] as List<dynamic>?)?.cast<String>() ?? [];
            final resultMatch = json['match'] as String?;
            final resultShortName = json['short_name'] as String?;

            // Normalize for comparison (lowercase, no spaces)
            String normalize(String s) => s.toLowerCase().replaceAll(' ', '');
            final normalizedValid = validIdentifiers.map(normalize).toSet();

            // Check if any result identifier matches any valid identifier
            bool isValidMatch = false;
            for (final resultName in resultNames) {
              if (normalizedValid.contains(normalize(resultName))) {
                isValidMatch = true;
                break;
              }
            }
            if (!isValidMatch && resultMatch != null) {
              isValidMatch = normalizedValid.contains(normalize(resultMatch));
            }
            if (!isValidMatch && resultShortName != null) {
              isValidMatch = normalizedValid.contains(normalize(resultShortName));
            }

            if (!isValidMatch) {
              debugPrint('Star registry result rejected - no matching identifier. Result names: $resultNames, Expected: $validIdentifiers');
              return null;
            }
          }

          return StarInfo.fromApiResponse(json);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Star registry search by name error: $e');
      return null;
    }
  }
}

/// Tooltip data for quick stats
class _TooltipData {
  final String id;
  final String title;
  final String content;

  _TooltipData({required this.id, required this.title, required this.content});
}

/// Skeleton shimmer effect widget
class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = 6,
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white.withValues(alpha: 0.05),
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.05),
              ],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bottom sheet to display star information
class StarInfoBottomSheet extends StatefulWidget {
  final StarInfo starInfo;
  final Future<StarInfo?>? registryFuture;
  final VoidCallback? onPointAt;
  final VoidCallback? onClose;
  final VoidCallback? onNameStar;
  final void Function(String effectiveName)? onViewIn3D;
  final void Function(bool enabled)? onToggleStarTrack;
  final bool starTrackEnabled;

  const StarInfoBottomSheet({
    super.key,
    required this.starInfo,
    this.registryFuture,
    this.onPointAt,
    this.onClose,
    this.onNameStar,
    this.onViewIn3D,
    this.onToggleStarTrack,
    this.starTrackEnabled = false,
  });

  @override
  State<StarInfoBottomSheet> createState() => _StarInfoBottomSheetState();
}

class _StarInfoBottomSheetState extends State<StarInfoBottomSheet> {
  String? _feedbackMessage;
  bool _isLoadingRegistry = false;
  StarInfo? _registryInfo;
  bool _notificationsEnabled = false;
  VisibilityInfo? _visibilityInfo;
  bool _isLoadingVisibility = false;
  _TooltipData? _activeTooltip;

  /// Translates the visibility status text based on the status enum
  String _getTranslatedStatusText(BuildContext context, VisibilityInfo visibility) {
    final l10n = AppLocalizations.of(context)!;
    switch (visibility.status) {
      case VisibilityStatus.neverVisible:
        return l10n.visibilityStatusNeverVisible;
      case VisibilityStatus.visibleNow:
        return l10n.visibilityStatusVisibleNow;
      case VisibilityStatus.waitForDark:
        return l10n.visibilityStatusWaitForDark;
      case VisibilityStatus.belowHorizon:
        return l10n.visibilityStatusBelowHorizon;
      case VisibilityStatus.visibleLater:
        // For visibleLater, we need to determine if it's tonight, tomorrow, or days away
        if (visibility.startTime != null) {
          final now = DateTime.now();
          final diff = visibility.startTime!.difference(now);
          final timeStr = visibility.startTimeStr ?? '';
          if (visibility.startTime!.day == now.day) {
            return l10n.visibilityStatusTonight(timeStr);
          } else if (diff.inHours < 24) {
            return l10n.visibilityStatusTomorrow(timeStr);
          } else {
            return l10n.visibilityStatusInDays(diff.inDays, diff.inHours % 24);
          }
        }
        return visibility.statusText; // Fallback to original
    }
  }

  @override
  void initState() {
    super.initState();
    SavedStarsService.instance.addListener(_onServiceChanged);
    // Ensure service is loaded
    SavedStarsService.instance.load();
    // Start loading registry data if future is provided
    _loadRegistryData();
    // Load notification preference and visibility info
    _loadNotificationPreference();
    _loadVisibilityInfo();
  }

  Future<void> _loadNotificationPreference() async {
    final starId = _getStarId();
    // Only load saved preference if star is saved, otherwise default to false
    if (_isSaved) {
      final enabled = await NotificationPreferences.getStarNotificationEnabled(starId);
      if (mounted) {
        setState(() {
          _notificationsEnabled = enabled;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _notificationsEnabled = false;
        });
      }
    }
  }

  Future<void> _loadVisibilityInfo() async {
    // Use effective star info (registry data if available, otherwise basic)
    final modelData = _effectiveStarInfo.modelData;
    if (modelData == null || (modelData.rightAscension == 0 && modelData.declination == 0)) {
      return;
    }

    setState(() {
      _isLoadingVisibility = true;
    });

    try {
      final location = await OnboardingService.getUserLocation();
      if (location.latitude == null || location.longitude == null) {
        if (mounted) {
          setState(() {
            _isLoadingVisibility = false;
          });
        }
        return;
      }

      // Use the shared visibility info helper for consistent calculations
      final visibility = StarVisibility.getVisibilityInfo(
        starRaDeg: modelData.rightAscension,
        starDecDeg: modelData.declination,
        latitudeDeg: location.latitude!,
        longitudeDeg: location.longitude!,
      );

      if (mounted) {
        setState(() {
          _isLoadingVisibility = false;
          _visibilityInfo = visibility;
        });
      }
    } catch (e) {
      debugPrint('Error loading visibility info: $e');
      if (mounted) {
        setState(() {
          _isLoadingVisibility = false;
        });
      }
    }
  }

  Future<void> _toggleNotifications() async {
    final starId = _getStarId();
    final newValue = !_notificationsEnabled;

    setState(() {
      _notificationsEnabled = newValue;
    });

    // If enabling notifications and star is not saved, auto-save it
    if (newValue && !_isSaved) {
      final modelData = widget.starInfo.modelData;
      final registryInfo = widget.starInfo.registryInfo;

      final star = SavedStar(
        id: starId,
        displayName: _cleanStarName(widget.starInfo.isRegistered && registryInfo != null
            ? registryInfo.name
            : (modelData?.shortName ?? widget.starInfo.shortName)),
        scientificName: modelData?.identifier,
        registrationNumber: registryInfo?.registrationNumber,
        ra: modelData?.rightAscension,
        dec: modelData?.declination,
        magnitude: modelData?.vMagnitude,
        notificationsEnabled: true,
      );

      await SavedStarsService.instance.saveStar(star);

      if (mounted) {
        setState(() {
          _feedbackMessage = AppLocalizations.of(context)!.savedToMyStars;
        });

        // Clear feedback message after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _feedbackMessage = null;
            });
          }
        });
      }
    }

    await NotificationPreferences.setStarNotificationEnabled(starId, newValue);

    // Sync to Firestore - Firebase Cloud Functions handles notification scheduling
    await FirestoreSyncService.instance.updateStarNotificationPreference(starId, newValue);
  }

  Future<void> _loadRegistryData() async {
    if (widget.registryFuture != null) {
      setState(() {
        _isLoadingRegistry = true;
      });
      try {
        final result = await widget.registryFuture;
        if (mounted && result != null && result.found) {
          setState(() {
            _registryInfo = result;
            _isLoadingRegistry = false;
          });
          // Recalculate visibility with registry coordinates if initial coords were 0,0
          final initialModelData = widget.starInfo.modelData;
          if (initialModelData == null ||
              (initialModelData.rightAscension == 0 && initialModelData.declination == 0)) {
            _loadVisibilityInfo();
          }
        } else if (mounted) {
          setState(() {
            _isLoadingRegistry = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoadingRegistry = false;
          });
        }
      }
    }
  }

  /// Get the effective star info (registry data if available, otherwise basic)
  StarInfo get _effectiveStarInfo => _registryInfo ?? widget.starInfo;

  @override
  void dispose() {
    SavedStarsService.instance.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) {
      // Reload notification preference when saved state changes
      _loadNotificationPreference();
      setState(() {
        // Trigger rebuild to refresh _isSaved getter
      });
    }
  }

  /// Check if this star is saved - always reads fresh from service
  bool get _isSaved {
    final service = SavedStarsService.instance;
    if (!service.isLoaded) return false;

    final id = _getStarId();
    final scientificName = widget.starInfo.modelData?.identifier;
    final shortName = widget.starInfo.shortName;

    // Check by ID
    if (service.isSaved(id)) return true;

    // Check by scientific name
    if (scientificName != null && scientificName.isNotEmpty) {
      if (service.findByScientificName(scientificName) != null) return true;
    }

    // Check by short name as last resort
    if (service.findByScientificName(shortName) != null) return true;

    return false;
  }

  String _getStarId() {
    // Use scientific identifier as primary ID for consistency
    // This matches the ID used in home_screen.dart when auto-saving
    if (widget.starInfo.modelData?.identifier != null &&
        widget.starInfo.modelData!.identifier.isNotEmpty) {
      return widget.starInfo.modelData!.identifier;
    }
    // Fallback to registration number or short name
    if (widget.starInfo.registryInfo?.registrationNumber != null &&
        widget.starInfo.registryInfo!.registrationNumber.isNotEmpty) {
      return widget.starInfo.registryInfo!.registrationNumber;
    }
    return widget.starInfo.shortName;
  }

  Future<void> _toggleSave() async {
    final modelData = widget.starInfo.modelData;
    final registryInfo = widget.starInfo.registryInfo;

    final star = SavedStar(
      id: _getStarId(),
      displayName: widget.starInfo.isRegistered && registryInfo != null
          ? registryInfo.name
          : (modelData?.shortName ?? widget.starInfo.shortName),
      scientificName: modelData?.identifier,
      registrationNumber: registryInfo?.registrationNumber,
      ra: modelData?.rightAscension,
      dec: modelData?.declination,
      magnitude: modelData?.vMagnitude,
    );

    final service = SavedStarsService.instance;
    final nowSaved = await service.toggleStar(star);

    // Service notifies listeners, which triggers setState
    // Just update the feedback message
    if (mounted) {
      setState(() {
        _feedbackMessage = nowSaved
            ? AppLocalizations.of(context)!.savedToMyStars
            : AppLocalizations.of(context)!.removedFromMyStars;
      });

      // Clear feedback message after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _feedbackMessage = null;
          });
        }
      });
    }
  }

  // Color constants matching the React design
  static const Color _accentCyan = Color(0xFF22D3EE);
  static const Color _accentEmerald = Color(0xFF34D399);
  static const Color _accentPurple = Color(0xFFA78BFA);
  static const Color _goldColor = Color(0xFFFBBF24);
  static const Color _slateBackground = Color(0xFF0F172A);

  void _handleStatTap(String id, String title, String content) {
    setState(() {
      if (_activeTooltip?.id == id) {
        _activeTooltip = null;
      } else {
        _activeTooltip = _TooltipData(id: id, title: title, content: content);
        // Auto-dismiss after 6 seconds
        Future.delayed(const Duration(seconds: 6), () {
          if (mounted && _activeTooltip?.id == id) {
            setState(() {
              _activeTooltip = null;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final starInfo = _effectiveStarInfo;
    final modelData = starInfo.modelData;
    final registryInfo = starInfo.registryInfo;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: _slateBackground.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          left: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          right: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Section (Sticky)
          _buildHeader(context, modelData),

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show skeleton or actual content based on loading state
                  if (_isLoadingRegistry) ...[
                    // Skeleton Quick Stats Row
                    _buildSkeletonQuickStats(),
                    const SizedBox(height: 24),

                    // Skeleton Registration Card (always show when loading)
                    _buildSkeletonRegistrationCard(),
                    const SizedBox(height: 20),

                    // Skeleton Visibility Card
                    _buildSkeletonVisibilityCard(),
                    const SizedBox(height: 20),

                    // Skeleton Notification Toggle
                    _buildSkeletonNotificationToggle(),
                    const SizedBox(height: 20),

                    // Skeleton Coordinates
                    _buildSkeletonCoordinates(),
                    const SizedBox(height: 16),
                  ] else ...[
                    // Quick Stats Row
                    if (modelData != null) ...[
                      _buildQuickStatsRow(context, modelData),
                      const SizedBox(height: 24),
                    ],

                    // Registration info (if registered)
                    if (starInfo.isRegistered && registryInfo != null) ...[
                      _buildRegistrationCardNew(context, registryInfo),
                      const SizedBox(height: 20),
                    ],

                    // "Name this star" button (if not registered and not loading)
                    if (!starInfo.isRegistered && widget.onNameStar != null) ...[
                      _buildNameStarCard(context),
                      const SizedBox(height: 20),
                    ],

                    // Visibility section (show if we have visibility data)
                    if (_visibilityInfo != null || _isLoadingVisibility) ...[
                      _buildVisibilityCardNew(context),
                      const SizedBox(height: 20),
                    ],

                    // Notification Toggle
                    if (modelData != null && (modelData.rightAscension != 0 || modelData.declination != 0)) ...[
                      _buildNotificationToggle(context),
                      const SizedBox(height: 20),
                    ],

                    // Coordinates section (collapsed into a smaller card)
                    if (modelData != null) ...[
                      _buildCoordinatesCardNew(context, modelData),
                      const SizedBox(height: 16),
                    ],
                  ],

                  // Action Buttons Row
                  _buildActionButtons(context),

                  // Feedback message
                  if (_feedbackMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Center(
                        child: Text(
                          _feedbackMessage!,
                          style: TextStyle(
                            color: _isSaved ? _accentEmerald : Colors.orange,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                  // Bottom padding
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, StarModelData? modelData) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 12, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          // Star Icon with glow
          Stack(
            children: [
              // Glow effect
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _goldColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _goldColor.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _goldColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Color(0xFF1E293B),
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Name and Save Button
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: _isLoadingRegistry
                      ? const _SkeletonBox(width: 140, height: 24, borderRadius: 6)
                      : Text(
                          // Use registered name if available, otherwise use scientific name
                          _effectiveStarInfo.isRegistered && _effectiveStarInfo.registryInfo != null
                              ? _effectiveStarInfo.registryInfo!.name
                              : _cleanStarName(widget.starInfo.modelData?.shortName ?? widget.starInfo.shortName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                const SizedBox(width: 12),
                // Save button pill
                GestureDetector(
                  onTap: _toggleSave,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isSaved
                          ? _goldColor.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isSaved
                            ? _goldColor.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isSaved ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: _isSaved ? _goldColor : Colors.white60,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isSaved ? AppLocalizations.of(context)!.saved : AppLocalizations.of(context)!.save,
                          style: TextStyle(
                            color: _isSaved ? _goldColor : Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Close button
          IconButton(
            icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.6)),
            onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(String text) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _goldColor,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsRow(BuildContext context, StarModelData modelData) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // Stats Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Magnitude Badge
              if (modelData.vMagnitude != null)
                _buildStatBadge(
                  id: 'mag',
                  icon: Icons.visibility_outlined,
                  label: l10n.magnitude,
                  value: modelData.vMagnitude!.toStringAsFixed(1),
                  tooltipTitle: l10n.magnitude,
                  tooltipContent: 'Magnitude ${modelData.vMagnitude!.toStringAsFixed(2)} measures how bright the star appears from Earth. Lower numbers are brighter (e.g., Sirius is -1.46).',
                ),

              // HIP/Catalog ID Badge
              if (modelData.identifier.isNotEmpty) ...[
                const SizedBox(width: 10),
                _buildStatBadge(
                  id: 'hip',
                  icon: Icons.tag,
                  label: null,
                  value: _formatIdentifier(modelData.identifier),
                  tooltipTitle: l10n.catalogId,
                  tooltipContent: '${_formatIdentifier(modelData.identifier)} is the identifier for this star in the Hipparcos catalog, a high-precision scientific star catalog.',
                  isMono: true,
                ),
              ],

              // Distance Badge
              if (modelData.distanceLightYears != null) ...[
                const SizedBox(width: 10),
                _buildStatBadge(
                  id: 'dist',
                  icon: Icons.straighten,
                  label: null,
                  value: '${modelData.distanceLightYears!.toStringAsFixed(0)} ly',
                  tooltipTitle: AppLocalizations.of(context)!.distance,
                  tooltipContent: 'The distance from Earth. Light from this star takes ${modelData.distanceLightYears!.toStringAsFixed(0)} years to reach us.',
                ),
              ],

              // Spectral Type Badge
              if (modelData.spectralType.isNotEmpty) ...[
                const SizedBox(width: 10),
                _buildStatBadge(
                  id: 'spect',
                  icon: Icons.thermostat_outlined,
                  label: null,
                  value: modelData.spectralType,
                  tooltipTitle: l10n.spectralType,
                  tooltipContent: 'The spectral type ${modelData.spectralType} indicates the star\'s temperature and chemical composition.',
                  isMono: true,
                ),
              ],
            ],
          ),
        ),

        // Tooltip Overlay
        if (_activeTooltip != null)
          _buildTooltipOverlay(),
      ],
    );
  }

  Widget _buildStatBadge({
    required String id,
    required IconData icon,
    String? label,
    required String value,
    required String tooltipTitle,
    required String tooltipContent,
    bool isMono = false,
  }) {
    final isActive = _activeTooltip?.id == id;

    return GestureDetector(
      onTap: () => _handleStatTap(id, tooltipTitle, tooltipContent),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white54),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: isMono ? 'monospace' : null,
                letterSpacing: isMono ? -0.5 : 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTooltipOverlay() {
    return AnimatedOpacity(
      opacity: _activeTooltip != null ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _accentCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.info_outline, size: 16, color: _accentCyan),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _activeTooltip!.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _activeTooltip!.content,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _activeTooltip = null),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationCardNew(BuildContext context, StarRegistryInfo info) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accentEmerald.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentEmerald.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.star_rounded, size: 12, color: _accentEmerald),
              const SizedBox(width: 8),
              Text(
                l10n.registration.toUpperCase(),
                style: TextStyle(
                  color: _accentEmerald,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Info rows
          _buildInfoRowNew(Icons.person_outline, l10n.registeredTo, info.name),
          const SizedBox(height: 12),
          _buildInfoRowNew(Icons.calendar_today_outlined, l10n.registrationDate, info.registrationDate),
          const SizedBox(height: 12),
          _buildInfoRowNew(Icons.tag, l10n.registrationNumber, info.registrationNumber, isMono: true),
          if (info.register.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRowNew(Icons.language, l10n.registry, info.register, isLink: true),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRowNew(IconData icon, String label, String value, {bool isMono = false, bool isLink = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _slateBackground.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: Colors.white54),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: isLink ? _accentEmerald : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: isMono ? 'monospace' : null,
                  letterSpacing: isMono ? -0.3 : 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNameStarCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _goldColor.withValues(alpha: 0.12),
            Colors.orange.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _goldColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _goldColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.auto_awesome, color: _goldColor, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.starNotYetNamed,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.giveUniqueNameHint,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: widget.onNameStar,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(l10n.nameThisStar),
            style: ElevatedButton.styleFrom(
              backgroundColor: _goldColor,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityCardNew(BuildContext context) {
    if (_isLoadingVisibility) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: _buildLoadingIndicator(AppLocalizations.of(context)!.visibilityCalculating),
      );
    }

    final visibility = _visibilityInfo;
    if (visibility == null) return const SizedBox.shrink();

    final isCurrentlyVisible = visibility.isCurrentlyVisible;

    // Calculate visible duration if we have both times
    String? visibleDuration;
    if (visibility.startTime != null && visibility.endTime != null) {
      final duration = visibility.endTime!.difference(visibility.startTime!);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      if (hours > 0) {
        visibleDuration = '${hours}h ${minutes}m';
      } else {
        visibleDuration = '${minutes}m';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accentCyan.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentCyan.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact header with times inline
          Row(
            children: [
              // Left side: Icon and duration info
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _accentCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.visibility_outlined, size: 16, color: _accentCyan),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCurrentlyVisible
                          ? AppLocalizations.of(context)!.visibilityVisibleNow
                          : AppLocalizations.of(context)!.visibilityTonight,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visibleDuration ?? _getTranslatedStatusText(context, visibility),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (visibleDuration != null)
                          Text(
                            AppLocalizations.of(context)!.visibilityVisible,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Right side: Time display
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Rise time
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isCurrentlyVisible
                            ? AppLocalizations.of(context)!.visibilitySince
                            : AppLocalizations.of(context)!.visibilityFrom,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        visibility.startTimeStr == 'Now'
                            ? AppLocalizations.of(context)!.visibilityNow
                            : (visibility.startTimeStr ?? '--:--'),
                        style: TextStyle(
                          color: _accentEmerald,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  // Divider
                  Container(
                    width: 1,
                    height: 28,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  // Set time
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.visibilityUntil,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        visibility.endTimeStr ?? '--:--',
                        style: const TextStyle(
                          color: Color(0xFFF87171),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Show 24h Sky Path button
          if (widget.onToggleStarTrack != null) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => widget.onToggleStarTrack?.call(!widget.starTrackEnabled),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _slateBackground.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _accentCyan.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.starTrackEnabled ? Icons.visibility_off_outlined : Icons.timeline,
                      size: 14,
                      color: _accentCyan,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.starTrackEnabled
                          ? AppLocalizations.of(context)!.hideStarPath
                          : AppLocalizations.of(context)!.showStarPath,
                      style: TextStyle(
                        color: _accentCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationToggle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _notificationsEnabled
                  ? _accentPurple
                  : _accentPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _notificationsEnabled ? Icons.notifications_active : Icons.notifications_outlined,
              color: _notificationsEnabled ? Colors.white : _accentPurple,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.notificationAlertTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.notificationAlertSubtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _toggleNotifications,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 24,
              decoration: BoxDecoration(
                color: _notificationsEnabled ? _accentPurple : const Color(0xFF334155),
                borderRadius: BorderRadius.circular(12),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: _notificationsEnabled ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinatesCardNew(BuildContext context, StarModelData data) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.rightAscension.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.j2000Ra.isNotEmpty ? data.j2000Ra : '${data.rightAscension.toStringAsFixed(4)}°',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.declination.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.j2000Dec.isNotEmpty ? data.j2000Dec : '${data.declination.toStringAsFixed(4)}°',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        // View in 3D button
        if (widget.onViewIn3D != null) ...[
          Expanded(
            child: _buildActionButton(
              icon: Icons.view_in_ar_outlined,
              label: l10n.viewStarIn3D,
              onTap: () {
                // Pass the effective name (registry name if available)
                final effectiveName = _effectiveStarInfo.isRegistered && _effectiveStarInfo.registryInfo != null
                    ? _effectiveStarInfo.registryInfo!.name
                    : _cleanStarName(widget.starInfo.modelData?.shortName ?? widget.starInfo.shortName);
                widget.onViewIn3D!(effectiveName);
              },
              color: _accentPurple,
            ),
          ),
          const SizedBox(width: 12),
        ],
        // Point at button
        if (widget.onPointAt != null)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _goldColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onPointAt,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.gps_fixed, size: 18, color: Color(0xFF1E293B)),
                        const SizedBox(width: 8),
                        Text(
                          l10n.pointAtStar,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format identifier to add space after prefix (e.g., "HIP14778" -> "HIP 14778")
  String _formatIdentifier(String identifier) {
    // Match patterns like "HIP14778", "HD12345", "TYC1234-5678-1"
    final match = RegExp(r'^([A-Za-z]+)(\d.*)$').firstMatch(identifier);
    if (match != null) {
      return '${match.group(1)} ${match.group(2)}';
    }
    return identifier;
  }

  /// Clean star name by removing Stellarium prefixes like "NAME ", "* ", etc.
  String _cleanStarName(String name) {
    String cleanName = name.trim();
    if (cleanName.startsWith('NAME ')) {
      cleanName = cleanName.substring(5);
    } else if (cleanName.startsWith('* ')) {
      cleanName = cleanName.substring(2);
    }
    return cleanName;
  }

  // ============== SKELETON LOADING WIDGETS ==============

  Widget _buildSkeletonQuickStats() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          _buildSkeletonStatBadge(width: 80),
          const SizedBox(width: 10),
          _buildSkeletonStatBadge(width: 95),
          const SizedBox(width: 10),
          _buildSkeletonStatBadge(width: 70),
          const SizedBox(width: 10),
          _buildSkeletonStatBadge(width: 60),
        ],
      ),
    );
  }

  Widget _buildSkeletonStatBadge({required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const _SkeletonBox(width: 14, height: 14, borderRadius: 4),
          const SizedBox(width: 8),
          Expanded(child: _SkeletonBox(width: width - 34, height: 14)),
        ],
      ),
    );
  }

  Widget _buildSkeletonRegistrationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accentEmerald.withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header skeleton
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              const _SkeletonBox(width: 100, height: 10),
            ],
          ),
          const SizedBox(height: 16),

          // Info rows skeleton
          _buildSkeletonInfoRow(),
          const SizedBox(height: 12),
          _buildSkeletonInfoRow(),
          const SizedBox(height: 12),
          _buildSkeletonInfoRow(width: 140),
          const SizedBox(height: 12),
          _buildSkeletonInfoRow(width: 120),
        ],
      ),
    );
  }

  Widget _buildSkeletonInfoRow({double width = 180}) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: _SkeletonBox(width: 16, height: 16, borderRadius: 4),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SkeletonBox(width: 60, height: 8),
            const SizedBox(height: 4),
            _SkeletonBox(width: width, height: 12),
          ],
        ),
      ],
    );
  }

  Widget _buildSkeletonVisibilityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accentCyan.withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          // Icon skeleton
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: _SkeletonBox(width: 16, height: 16, borderRadius: 4),
            ),
          ),
          const SizedBox(width: 12),
          // Duration info skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonBox(width: 50, height: 10),
                const SizedBox(height: 4),
                const _SkeletonBox(width: 90, height: 14),
              ],
            ),
          ),
          // Time display skeleton
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const _SkeletonBox(width: 30, height: 8),
                  const SizedBox(height: 4),
                  const _SkeletonBox(width: 45, height: 12),
                ],
              ),
              Container(
                width: 1,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.white.withValues(alpha: 0.1),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const _SkeletonBox(width: 30, height: 8),
                  const SizedBox(height: 4),
                  const _SkeletonBox(width: 45, height: 12),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonNotificationToggle() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: _SkeletonBox(width: 20, height: 20, borderRadius: 6),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonBox(width: 100, height: 12),
                const SizedBox(height: 4),
                const _SkeletonBox(width: 150, height: 10),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonCoordinates() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonBox(width: 80, height: 8),
                const SizedBox(height: 6),
                const _SkeletonBox(width: 100, height: 12),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonBox(width: 70, height: 8),
                const SizedBox(height: 6),
                const _SkeletonBox(width: 90, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Show star info bottom sheet
/// Returns a Future that completes when the sheet is dismissed
Future<void> showStarInfoSheet(
  BuildContext context,
  StarInfo starInfo, {
  Future<StarInfo?>? registryFuture,
  VoidCallback? onPointAt,
  VoidCallback? onNameStar,
  void Function(String effectiveName)? onViewIn3D,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) => StarInfoBottomSheet(
        starInfo: starInfo,
        registryFuture: registryFuture,
        onPointAt: onPointAt,
        onNameStar: onNameStar,
        onViewIn3D: onViewIn3D,
      ),
    ),
  );
}
