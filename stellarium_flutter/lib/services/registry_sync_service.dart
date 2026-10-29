import 'package:flutter/foundation.dart';

import '../widgets/star_info_sheet.dart';
import 'saved_stars_service.dart';

/// Outcome of a registry refresh of the saved stars
class RegistrySyncResult {
  /// Stars whose registered name changed (already holding the new name)
  final List<SavedStar> renamed;

  /// Stars that were registered before and are no longer in the registry
  final List<SavedStar> newlyRemoved;

  /// Previously removed stars that the registry lists again
  final List<SavedStar> reinstated;

  const RegistrySyncResult({
    this.renamed = const [],
    this.newlyRemoved = const [],
    this.reinstated = const [],
  });

  bool get hasChanges =>
      renamed.isNotEmpty || newlyRemoved.isNotEmpty || reinstated.isNotEmpty;
}

/// Re-checks every saved registered star against the registry so that
/// name changes and removals (e.g. refunds) made after the star was saved
/// reach the app. SavedStarsService notifies its listeners on each update,
/// which also re-syncs the stars to Firestore for push notifications.
class RegistrySyncService {
  static RegistrySyncService? _instance;

  RegistrySyncService._();

  static RegistrySyncService get instance {
    _instance ??= RegistrySyncService._();
    return _instance!;
  }

  Future<RegistrySyncResult>? _inFlight;

  /// Refresh all saved stars that have a registration number.
  /// Concurrent calls share the same run.
  Future<RegistrySyncResult> refreshSavedStars() {
    return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
  }

  Future<RegistrySyncResult> _refresh() async {
    final service = SavedStarsService.instance;
    await service.load();

    final renamed = <SavedStar>[];
    final newlyRemoved = <SavedStar>[];
    final reinstated = <SavedStar>[];

    final registered = service.savedStars
        .where((s) =>
            s.registrationNumber != null && s.registrationNumber!.isNotEmpty)
        .toList();

    for (final saved in registered) {
      final result =
          await StarRegistryService.searchByRegistrationNumber(
              saved.registrationNumber!);

      // null means the request failed (offline, server error) - never treat
      // that as a removal, just try again next time.
      if (result == null) continue;

      if (!result.found) {
        final flagged = await service.markRemovedFromRegistry(
          saved.id,
          reason: result.removalReason,
        );
        if (flagged) {
          final updated = service.findById(saved.id);
          if (updated != null) newlyRemoved.add(updated);
        }
        continue;
      }

      final registryName = result.registryInfo?.name;
      if (!result.isRegistered || registryName == null || registryName.isEmpty) {
        continue;
      }

      final nameChanged = registryName != saved.displayName;
      final wasRemoved = saved.removedFromRegistry;
      if (!nameChanged && !wasRemoved) continue;

      final updated = saved.copyWith(
        displayName: registryName,
        removedFromRegistry: false,
      );
      await service.updateStar(updated);
      if (nameChanged) renamed.add(updated);
      if (wasRemoved) reinstated.add(updated);
    }

    debugPrint('RegistrySyncService: checked ${registered.length} stars, '
        '${renamed.length} renamed, ${newlyRemoved.length} removed, '
        '${reinstated.length} reinstated');

    return RegistrySyncResult(
      renamed: renamed,
      newlyRemoved: newlyRemoved,
      reinstated: reinstated,
    );
  }
}
