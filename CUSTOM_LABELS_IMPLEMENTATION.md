# Custom Star Labels Implementation

## Overview

This document describes the implementation of custom star labels in the Stellarium Flutter app. Custom labels allow users to see their registered star names displayed in gold in the night sky view.

## Architecture

There are **two label systems**:

### 1. Selection Custom Label (Temporary)
- A **global** label that applies to whatever star is currently selected
- Used only temporarily during registration number searches
- Always cleared when:
  - User selects a star by tapping
  - User searches for a regular star name
  - Star info sheet closes
- Stored in: `core->selection_custom_label` (C engine)

### 2. Persistent Labels (Permanent)
- Labels tied to **specific stars by their HIP number**
- Shown automatically without needing to select the star
- Persist across app restarts (loaded from SavedStarsService on engine ready)
- Stored in: `core->persistent_labels` linked list (C engine)

## Key Files Modified

### Stellarium Web Engine (C)

**`src/core.h`**
- Added `persistent_label_t` struct with `identifier` and `label` fields
- Added `persistent_labels` linked list to `core_t` struct
- Declared functions: `core_add_persistent_label()`, `core_remove_persistent_label()`, `core_get_persistent_label()`, `core_clear_persistent_labels()`

**`src/core.c`**
- Implemented persistent label functions with identifier normalization (removes spaces, uppercases for comparison)
- Uses `EMSCRIPTEN_KEEPALIVE` for JS access

**`src/modules/stars.c`** - `star_render_name()`
- Checks for selection custom label first (for selected star only)
- Then checks for persistent label by HIP number
- Renders custom labels in **gold color** with bold text
- Persistent labels show even when star is not selected

### JavaScript API (`src/js/pre.js`)

```javascript
Module['addPersistentLabel'](identifier, label)
Module['removePersistentLabel'](identifier)
Module['getPersistentLabel'](identifier)
Module['clearPersistentLabels']()
Module['setSelectionCustomLabel'](label)
Module['getSelectionCustomLabel']()
```

### Flutter Assets (`assets/stellarium/stellarium.html`)

Added `stellariumAPI` methods:
- `addPersistentLabel(identifier, label)`
- `removePersistentLabel(identifier)`
- `clearPersistentLabels()`
- `setCustomLabel(label)` - for selection custom label
- `clearCustomLabel()`

### Flutter WebView (`lib/widgets/stellarium_webview.dart`)

Added methods:
- `addPersistentLabel(String identifier, String label)`
- `removePersistentLabel(String identifier)`
- `clearPersistentLabels()`

### Flutter Home Screen (`lib/screens/home_screen.dart`)

**`_onEngineReady()`**
- Calls `_loadPersistentLabels()` to load all saved stars with custom names

**`_loadPersistentLabels()`**
- Iterates through `SavedStarsService.instance.savedStars`
- For each star where `displayName != scientificName`, adds a persistent label

**`_searchRegistrationNumber()`**
- Sets temporary selection custom label
- Auto-saves star to SavedStarsService
- Adds persistent label for the star

**`_onObjectSelected()`**
- Always clears selection custom label (persistent labels handle saved stars)

**`_showStarInfo()`**
- Always clears selection custom label when sheet closes

**`_searchAndPoint()`**
- Clears selection custom label for regular searches

## Data Flow

### When searching by registration number:
1. API returns star info with registered name
2. `setCustomLabel(registeredName)` - temporary selection label
3. Star saved to `SavedStarsService` with `displayName=registeredName`, `scientificName=HIP number`
4. `addPersistentLabel(hipNumber, registeredName)` - permanent label
5. Star info sheet opens
6. Sheet closes → selection label cleared, persistent label remains

### When app starts:
1. Engine becomes ready
2. `_loadPersistentLabels()` iterates saved stars
3. For each saved star with custom name, `addPersistentLabel()` is called
4. Labels appear in gold above stars immediately (no selection needed)

### When tapping a star:
1. `_onObjectSelected()` is called
2. Selection custom label is cleared
3. If star has a persistent label, it shows automatically via the engine

## Building

To rebuild the engine after changes:
```bash
cd stellarium-web-engine
make js
cp build/stellarium-web-engine.js ../stellarium_flutter/assets/stellarium/
cp build/stellarium-web-engine.wasm ../stellarium_flutter/assets/stellarium/
```

## Important Notes

- Persistent labels are identified by normalized HIP number (e.g., "HIP 14778" and "HIP14778" both match)
- Gold color for custom labels: `rgba(255, 214, 0, 1)` or `{1.0, 0.84, 0.0, 1.0}`
- Selection custom label takes priority over persistent label for the selected star
- Persistent labels show with high priority (`-s->vmag + 10`) to ensure visibility
