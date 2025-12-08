import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// A search suggestion item
class SearchSuggestion {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final String value;

  const SearchSuggestion({
    required this.title,
    this.subtitle,
    this.icon = Icons.star,
    this.iconColor = Colors.amber,
    required this.value,
  });
}

/// A main action button for the bottom bar
class MainButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const MainButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 32,
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}

/// The main buttons row with Atmosphere, Gyroscope
class MainButtonsRow extends StatelessWidget {
  final bool atmosphereEnabled;
  final bool gyroscopeEnabled;
  final bool gyroscopeAvailable;
  final VoidCallback onAtmosphereTap;
  final VoidCallback onGyroscopeTap;

  const MainButtonsRow({
    super.key,
    required this.atmosphereEnabled,
    required this.gyroscopeEnabled,
    required this.gyroscopeAvailable,
    required this.onAtmosphereTap,
    required this.onGyroscopeTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        MainButton(
          icon: Icons.wb_sunny_outlined,
          label: l10n.atmosphereButton,
          isActive: atmosphereEnabled,
          onTap: onAtmosphereTap,
        ),
        MainButton(
          icon: Icons.screen_rotation,
          label: l10n.movementButton,
          isActive: gyroscopeEnabled,
          onTap: gyroscopeAvailable ? onGyroscopeTap : () {},
        ),
      ],
    );
  }
}

/// Search bar widget with suggestions
class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onTap;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback onHamburgerTap;
  final List<SearchSuggestion> suggestions;
  final ValueChanged<SearchSuggestion>? onSuggestionTap;
  final bool isSearching;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.onTap,
    required this.onSubmitted,
    this.onChanged,
    required this.onHamburgerTap,
    this.suggestions = const [],
    this.onSuggestionTap,
    this.isSearching = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Suggestions list (above search bar)
        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a2e),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onSuggestionTap?.call(suggestion),
                    borderRadius: BorderRadius.vertical(
                      top: index == 0 ? const Radius.circular(12) : Radius.zero,
                      bottom: index == suggestions.length - 1
                          ? const Radius.circular(12)
                          : Radius.zero,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            suggestion.icon,
                            color: suggestion.iconColor,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  suggestion.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (suggestion.subtitle != null)
                                  Text(
                                    suggestion.subtitle!,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.north_east,
                            color: Colors.white38,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        // Search bar row
        Row(
          children: [
            // Search field
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.search,
                        color: Colors.grey,
                        size: 24,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)?.searchPlaceholder ?? 'Search for a star or object...',
                          hintStyle: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onTap: onTap,
                        onChanged: onChanged,
                        onSubmitted: onSubmitted,
                      ),
                    ),
                    if (isSearching)
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.grey),
                          ),
                        ),
                      )
                    else if (controller.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                          onPressed: () {
                            controller.clear();
                            onChanged?.call('');
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Hamburger menu button
            GestureDetector(
              onTap: onHamburgerTap,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.menu,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The complete bottom bar with buttons and search
class BottomBar extends StatelessWidget {
  final bool atmosphereEnabled;
  final bool gyroscopeEnabled;
  final bool gyroscopeAvailable;
  final TextEditingController searchController;
  final VoidCallback onAtmosphereTap;
  final VoidCallback onGyroscopeTap;
  final VoidCallback onSearchTap;
  final ValueChanged<String> onSearchSubmitted;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback onHamburgerTap;
  final List<SearchSuggestion> searchSuggestions;
  final ValueChanged<SearchSuggestion>? onSuggestionTap;
  final bool isSearching;

  const BottomBar({
    super.key,
    required this.atmosphereEnabled,
    required this.gyroscopeEnabled,
    required this.gyroscopeAvailable,
    required this.searchController,
    required this.onAtmosphereTap,
    required this.onGyroscopeTap,
    required this.onSearchTap,
    required this.onSearchSubmitted,
    this.onSearchChanged,
    required this.onHamburgerTap,
    this.searchSuggestions = const [],
    this.onSuggestionTap,
    this.isSearching = false,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // No Listener wrapper needed - event blocking is handled at HomeScreen level
    // via _isPositionOnUI() check before forwarding to SkyView.
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.7),
            Colors.black.withValues(alpha: 0.9),
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: 16 + bottomPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main buttons row
            MainButtonsRow(
              atmosphereEnabled: atmosphereEnabled,
              gyroscopeEnabled: gyroscopeEnabled,
              gyroscopeAvailable: gyroscopeAvailable,
              onAtmosphereTap: onAtmosphereTap,
              onGyroscopeTap: onGyroscopeTap,
            ),
            const SizedBox(height: 16),
            // Search bar with hamburger
            SearchBarWidget(
              controller: searchController,
              onTap: onSearchTap,
              onSubmitted: onSearchSubmitted,
              onChanged: onSearchChanged,
              onHamburgerTap: onHamburgerTap,
              suggestions: searchSuggestions,
              onSuggestionTap: onSuggestionTap,
              isSearching: isSearching,
            ),
          ],
        ),
      ),
    );
  }
}
