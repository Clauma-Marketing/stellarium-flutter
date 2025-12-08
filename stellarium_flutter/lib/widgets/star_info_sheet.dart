import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../l10n/app_localizations.dart';
import '../services/saved_stars_service.dart';

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

  StarInfo({
    required this.found,
    required this.model,
    required this.shortName,
    this.modelData,
    this.registryInfo,
    this.isRegistered = false,
  });

  factory StarInfo.fromApiResponse(Map<String, dynamic> json) {
    final info = json['info'] as Map<String, dynamic>?;
    final modelData = json['model_data'] as Map<String, dynamic>?;
    final hasRegistry = info != null && info['resolved'] == true;

    // Determine if star was found - either explicit 'found' field or presence of model_data/match
    final wasFound = json['found'] as bool? ??
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

/// Bottom sheet to display star information
class StarInfoBottomSheet extends StatefulWidget {
  final StarInfo starInfo;
  final Future<StarInfo?>? registryFuture;
  final VoidCallback? onPointAt;
  final VoidCallback? onClose;
  final VoidCallback? onNameStar;
  final VoidCallback? onViewIn3D;

  const StarInfoBottomSheet({
    super.key,
    required this.starInfo,
    this.registryFuture,
    this.onPointAt,
    this.onClose,
    this.onNameStar,
    this.onViewIn3D,
  });

  @override
  State<StarInfoBottomSheet> createState() => _StarInfoBottomSheetState();
}

class _StarInfoBottomSheetState extends State<StarInfoBottomSheet> {
  String? _feedbackMessage;
  bool _isLoadingRegistry = false;
  StarInfo? _registryInfo;

  @override
  void initState() {
    super.initState();
    SavedStarsService.instance.addListener(_onServiceChanged);
    // Ensure service is loaded
    SavedStarsService.instance.load();
    // Start loading registry data if future is provided
    _loadRegistryData();
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

  @override
  Widget build(BuildContext context) {
    final starInfo = _effectiveStarInfo;
    final modelData = starInfo.modelData;
    final registryInfo = starInfo.registryInfo;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1a1a2e),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show registered name if available, otherwise scientific name
                      Text(
                        starInfo.isRegistered && starInfo.registryInfo != null
                            ? starInfo.registryInfo!.name
                            : (modelData?.shortName ?? starInfo.shortName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Show scientific identifier below
                      if (modelData?.identifier != null && modelData!.identifier.isNotEmpty)
                        Text(
                          modelData.identifier,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Loading indicator for registry data
                  if (_isLoadingRegistry) ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.amber,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              AppLocalizations.of(context)!.checkingStarRegistry,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Registration info (if registered)
                  if (starInfo.isRegistered && registryInfo != null) ...[
                    _buildSectionTitle(AppLocalizations.of(context)!.registration, Icons.verified, Colors.green),
                    const SizedBox(height: 12),
                    _buildRegistrationCard(context, registryInfo),
                    const SizedBox(height: 20),
                  ],

                  // "Name this star" button (if not registered and not loading)
                  if (!starInfo.isRegistered && !_isLoadingRegistry && widget.onNameStar != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.withValues(alpha: 0.15),
                            Colors.orange.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: Colors.amber,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.starNotYetNamed,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(context)!.giveUniqueNameHint,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: widget.onNameStar,
                            icon: const Icon(Icons.edit, size: 18),
                            label: Text(AppLocalizations.of(context)!.nameThisStar),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Star properties
                  if (modelData != null) ...[
                    _buildSectionTitle(AppLocalizations.of(context)!.properties, Icons.info_outline, Colors.blue),
                    const SizedBox(height: 12),
                    _buildPropertiesGrid(context, modelData),
                    const SizedBox(height: 20),

                    // Coordinates
                    _buildSectionTitle(AppLocalizations.of(context)!.coordinates, Icons.explore, Colors.purple),
                    const SizedBox(height: 12),
                    _buildCoordinatesCard(context, modelData),
                  ],

                  // View in 3D button
                  if (widget.onViewIn3D != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: widget.onViewIn3D,
                        icon: const Icon(Icons.view_in_ar, size: 20),
                        label: Text(AppLocalizations.of(context)!.viewStarIn3D),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purple.shade200,
                          side: BorderSide(color: Colors.purple.shade300.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Action buttons
                  const SizedBox(height: 24),

                  // Feedback message
                  if (_feedbackMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _feedbackMessage!,
                        style: TextStyle(
                          color: _isSaved ? Colors.green : Colors.orange,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  Row(
                    children: [
                      // Save button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _toggleSave,
                          icon: Icon(
                            _isSaved ? Icons.star : Icons.star_border,
                            color: _isSaved ? Colors.amber : Colors.white70,
                          ),
                          label: Text(_isSaved ? AppLocalizations.of(context)!.saved : AppLocalizations.of(context)!.save),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _isSaved ? Colors.amber : Colors.white70,
                            side: BorderSide(
                              color: _isSaved ? Colors.amber : Colors.white30,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      // Point at button
                      if (widget.onPointAt != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: widget.onPointAt,
                            icon: const Icon(Icons.gps_fixed),
                            label: Text(AppLocalizations.of(context)!.pointAtStar),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
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

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationCard(BuildContext context, StarRegistryInfo info) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.person, l10n.registeredTo, info.name),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.calendar_today, l10n.registrationDate, info.registrationDate),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.tag, l10n.registrationNumber, info.registrationNumber),
          if (info.register.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.language, l10n.registry, info.register),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPropertiesGrid(BuildContext context, StarModelData data) {
    final l10n = AppLocalizations.of(context)!;
    final properties = <MapEntry<String, String>>[];

    // Add catalog ID (HIP/HD number) as separate field
    if (data.identifier.isNotEmpty) {
      properties.add(MapEntry(l10n.catalogId, _formatIdentifier(data.identifier)));
    }
    if (data.vMagnitude != null) {
      properties.add(MapEntry(l10n.magnitude, data.vMagnitude!.toStringAsFixed(2)));
    }
    if (data.spectralType.isNotEmpty) {
      properties.add(MapEntry(l10n.spectralType, data.spectralType));
    }
    if (data.distanceLightYears != null) {
      properties.add(MapEntry(l10n.distance, '${data.distanceLightYears!.toStringAsFixed(1)} ly'));
    }
    if (data.parallax != null) {
      properties.add(MapEntry(l10n.parallax, '${data.parallax!.toStringAsFixed(2)} mas'));
    }
    if (data.isDoubleOrMultiple) {
      properties.add(MapEntry(l10n.objectType, l10n.doubleMultipleStar));
    }
    if (data.objectType.isNotEmpty && !data.objectType.contains(',')) {
      properties.add(MapEntry(l10n.objectType, data.objectType));
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: properties.map((entry) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCoordinatesCard(BuildContext context, StarModelData data) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.rightAscension,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.j2000Ra.isNotEmpty ? data.j2000Ra : '${data.rightAscension.toStringAsFixed(4)}°',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.declination,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.j2000Dec.isNotEmpty ? data.j2000Dec : '${data.declination.toStringAsFixed(4)}°',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
  VoidCallback? onViewIn3D,
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
