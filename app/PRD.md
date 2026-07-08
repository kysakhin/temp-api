# BondScanner — Product Requirements Document (Flutter)

> **Date:** 2026-07-08
> **Author:** Reverse-engineered from codebase v1.0.0+1
> **Status:** Handoff document — describes current implementation

---

## 1. Executive Summary

BondScanner is a mobile-first Flutter application that lets retail investors browse a catalog of bonds, search by ISIN or name, and organize bonds into personal wishlists. Users can sort the catalog by yield, tenure, rating, or minimum investment; reorder and pin bonds within wishlists; and tag bonds with colors for visual grouping. The app deep-links into a companion native "BondScanner" mobile app (with app store fallback) when viewing individual bond details.

The frontend is a single Flutter codebase targeting Android and iOS, backed by a Go/Gin REST API with PostgreSQL persistence.

---

## 2. User Personas

| Persona | Description | Key Actions |
|---------|-------------|-------------|
| **Retail Bond Investor** | Individual exploring fixed-income investments | Browse catalog, search by ISIN, compare yields |
| **Portfolio Curator** | Investor maintaining watchlists of bonds | Create/manage wishlists, reorder, pin, color-tag |
| **Mobile-First User** | Prefers app over desktop for quick checks | Tap to deep-link into BondScanner native app |

---

## 3. Screen Map & Navigation

```
RootTabs (IndexedStack)
├── Tab 0: BondsScreen       — Catalog browser (default)
├── Tab 1: SearchScreen      — Bond search
└── Tab 2: WishlistsScreen   — Wishlist management
```

### 3.1 Bottom Navigation Bar

Custom "liquid glass" nav bar (BlurEffect + translucent white container). Three tabs with animated icons — selected icon gets a slight upward float and increased size (26 → 28). Colors: navy-deep when active, muted gray when inactive.

---

## 4. Feature Deep-Dive

### 4.1 Bonds Catalog Screen (`BondsScreen`)

**Purpose:** Browse the full bond catalog with sort controls and multi-select for batch operations.

**States:**
- **Loading:** Centered `CircularProgressIndicator`
- **Error:** Centered red error text
- **Empty:** Empty list (pull-to-refresh enabled)
- **Populated:** Scrollable list of `BondTile` widgets, pull-to-refresh, bottom padding 120px

**Features:**
- **Sort dialog:** Sort by Yield (default), Min. Investment, Tenure, Rating, ISIN. Selection highlighted with checkmark. Triggered by tapping the sort label.
- **Sort direction toggle:** Ascending/descending arrow icon button. Default: descending (except for default sort).
- **Multi-select mode:** Triggered by long-pressing a bond. Top bar turns navy-deep with close button, count badge, and "add to wishlist" action (playlist_add icon). Selected items show radio-button / check-circle toggle.
- **Bond action sheet (long-press):** `BondActionSheet` with options:
  - Open in BondScanner app
  - Select multiple
  - Add to wishlist
- **Add to wishlist flow:** Opens `showAddToWishlistSheet` — lists available wishlists with capacity (X/10). Skips full wishlists. Shows checkmark if bond already in wishlist. Concurrent `Future.wait` for batch adds.
- **Deep link:** Single tap opens bond in native app via `bondscanner://bond/{ISIN}` scheme. Falls back to Play Store / App Store.

**Sort options (controlled by `BondsProvider`):**
| Sort By | Query Param | Direction |
|---------|-------------|-----------|
| Yield | `bondYield` | desc (default) |
| Min. Investment | `minInvestment` | desc |
| Tenure | `tenure` | desc |
| Rating | `rating` | desc |
| ISIN | `isin` | desc |

### 4.2 Search Screen (`SearchScreen`)

**Purpose:** Fuzzy-search bonds by ISIN or bond name with instant results.

**States:**
- **Idle (empty query):** "Type an ISIN or bond name to search" centered text
- **Loading:** Centered `CircularProgressIndicator`
- **No results:** "No bonds found matching your search."
- **Results:** Scrollable list of `BondTile` widgets

**Features:**
- **Auto-focus:** Search bar gains focus when screen is navigated to.
- **Debounced search:** 500ms debounce via `Timer`. Empty query clears results and reloads the catalog into `BondsProvider.bonds`.
- **Display metric toggle:** Toggle between showing "Interest" (yield) or "Min. Investment" on each bond tile. Synchronized with `BondsProvider.displayMetric`. Visual toggle with sync_alt icon and underlined label.
- **Long-press action sheet:** Same as BondsScreen (Open app, Add to wishlist). No multi-select mode in search.
- **Single tap:** Deep link to BondScanner native app.

### 4.3 Wishlists Screen (`WishlistsScreen`)

**Purpose:** Create, rename, delete, and manage wishlists — the core organizational feature.

**States:**
- **Loading:** Centered `CircularProgressIndicator`
- **Error:** Centered error icon + message + "Try Again" button
- **Empty (no wishlists):** Bookmark icon + "No wishlists yet" + "Create wishlist" FilledButton
- **Populated:** Horizontal tab strip + sort row + bond list

**Features:**

**Wishlist CRUD:**
- **Create:** FAB (+) in app bar. Name prompt dialog (max 50 chars). Validates max 5 wishlists. Checks duplicate name (409 conflict from backend).
- **Rename:** Three-dot menu > "Rename List" — name prompt dialog pre-filled.
- **Delete:** Three-dot menu > "Delete List" — confirmation dialog. Auto-switches to first remaining wishlist. If last wishlist, shows empty state.

**Wishlist Tabs:**
Horizontal scrollable pill-style tabs. Active tab: navy-deep background, white text. Inactive: transparent background, navy-deep text, gray border. Max-width 160px with ellipsis overflow. Tapping animates scroll to center tab.

**Wishlist Sort Options (per-wishlist, persisted in memory only):**
| Sort | Secondary Order |
|------|----------------|
| Manual Order | `position ASC` |
| Added Recently | `created_at DESC` |
| Color | `color ASC NULLS LAST, position ASC` |
| Yield | `bond_yield DESC NULLS LAST, position ASC` |
| Min. Investment | `min_investment ASC NULLS LAST, position ASC` |
| Tenure | `tenure ASC, position ASC` |
| Rating | Custom rating order (AAA→D) ASC |

Pinned bonds always float to the top regardless of sort mode.

**Bond-level operations:**
- **Drag reorder:** `ReorderableListView` with drag handle — only available in "Manual Order" sort mode and when not in multi-select.
- **Tap:** Deep link to BondScanner app.
- **Long-press:** Enters multi-select mode.
- **Multi-select mode:** Navy-deep top bar with close, palette (color-tag), and delete buttons. Batch delete with confirmation. Batch color-tag via `ColorPickerSheet`.
- **Action sheet (long-press in wishlist context):** Open app, Pin/Unpin, Set tag color, Remove from wishlist.

**Stale data detection:** Widget watches for discrepancy between `Wishlist.bondCount` and cached `_details.bonds.length`. When bonds are added from the catalog screen, auto-reloads details.

### 4.4 UI Components

#### BondTile (`widgets/bond_tile.dart`)

Reusable row component for displaying a bond across all three screens.

**Layout (left-to-right):**
1. Checkbox/radio (multi-select mode only)
2. Color tag bar (4×40px rounded rect, colored by `bond.color`)
3. Logo thumbnail (38×38px rounded network image with initials fallback)
4. Bond info column:
   - Bond name (bold, 15px) + optional pin icon (gold, 14px) if pinned
   - Subtitle: `ISIN • Rating` in muted gray (12.5px)
5. Trailing metric column (right-aligned):
   - Yield (green, bold, 15px) or Min. Investment (navy-deep, comma-formatted)
   - Tenure label (12.5px muted) — e.g. "3Y 6M" or "12M" or "5Y"
6. Drag handle (reorder mode only, `ReorderableDragStartListener`)

**Trailing metric switching:**
- `sortBy == 'minInvestment'` → min investment formatted with commas
- Otherwise → yield with `%` suffix, trailing `.0` trimmed

#### BondActionSheet (`widgets/bond_action_sheet.dart`)

Modal bottom sheet for bond operations. Context-aware:
- **Outside wishlist:** Open in app, Select multiple, Add to wishlist
- **Inside wishlist:** Open in app, Pin/Unpin, Set tag color, Remove from wishlist

Also contains `showAddToWishlistSheet` — shares capacity info (X/10) and disables full/already-added wishlists.

#### ColorPickerSheet (`widgets/color_picker_sheet.dart`)

Modal bottom sheet with 7 circular color chips + "Clear color" option. Returns hex string (e.g. `#D1483A`) or `null` for clear.

**Palette:** Red (#D1483A), Orange (#E08A2C), Yellow (#D4B72E), Green (#1B9E5A), Blue (#2E8CD4), Purple (#7A4FD1), Gray (#8A93A6).

---

## 5. State Management (Provider)

### 5.1 BondsProvider (`services/bonds_provider.dart`)

| Property | Type | Purpose |
|----------|------|---------|
| `bonds` | `List<Bond>` | Full catalog list |
| `loading` | `bool` | Loading indicator (catalog) |
| `error` | `String?` | Error message |
| `searchResults` | `List<Bond>` | Independent search result list |
| `searchLoading` | `bool` | Loading indicator (search) |
| `searchQuery` | `String` | Current search term |
| `sortBy` | `String` | Current sort field |
| `sortOrder` | `String` | `asc` / `desc` |

Key behaviors:
- `search()` debounces at 500ms, clears results when query is empty
- `loadInitial()` loads catalog (or search results if query non-empty)
- `applyColor()` optimistically updates local bond objects without API call (color update is persisted only via wishlist context)
- `displayMetric` getter returns `minInvestment` when sorted by min investment (or override set), otherwise `bondYield`
- `setDisplayMetric()` is a purely visual toggle used by SearchScreen (no backend call)

### 5.2 WishlistProvider (`services/wishlist_provider.dart`)

| Property | Type | Purpose |
|----------|------|---------|
| `wishlists` | `List<Wishlist>` | All wishlists |
| `loading` | `bool` | Loading indicator |
| `error` | `String?` | Error message |

Key behaviors:
- `sorted` getter returns wishlists ordered by `createdAt DESC`
- In-memory sort preferences per wishlist ID (`_sortPrefs`, `_sortOrderPrefs`) — not persisted to backend
- CRUD methods: `create`, `rename`, `remove` with local state updates

### 5.3 Provider Tree (in `main.dart`)

```
MultiProvider
├── Provider<ApiService> (singleton)
├── ChangeNotifierProvider<BondsProvider>
└── ChangeNotifierProvider<WishlistProvider>
```

---

## 6. API Layer

### 6.1 ApiService (`services/api_service.dart`)

HTTP client wrapping all REST endpoints. Base URL configured via `constants.dart` (currently `http://192.168.0.105:8080/api/v1`).

**Methods:**

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `getBonds(sortBy, sortOrder)` | `GET /bond` | List all bonds |
| `searchBonds(query)` | `GET /bond/search?q=` | Fuzzy search |
| `getWishlists()` | `GET /wishlist` | List all wishlists |
| `getWishlist(id, sortBy, sortOrder)` | `GET /wishlist/:id` | Get with bonds |
| `createWishlist(name)` | `POST /wishlist` | Create wishlist |
| `renameWishlist(id, name)` | `PATCH /wishlist/:id` | Rename |
| `deleteWishlist(id)` | `DELETE /wishlist/:id` | Delete |
| `addBond(wishlistId, isin)` | `POST /wishlist/:id/bond` | Add bond |
| `removeBond(wishlistId, isin)` | `DELETE /wishlist/:id/bond/:isin` | Remove bond |
| `updateWishlistBondColor(id, isin, color)` | `PATCH /.../bond/:isin/color` | Set color |
| `setBondPinned(id, isin, pinned)` | `PATCH /.../bond/:isin/pin` | Pin toggle |
| `reorderBonds(id, isinOrder)` | `PATCH /.../reorder` | Bulk reorder |

### 6.2 Error Handling

- Custom `ApiException` class wrapping backend error messages
- `_check()` validates status code (200-299) and parses error body for `message` field
- Fallback: generic "Request failed ({statusCode})"

---

## 7. Data Models

### 7.1 Bond (`models/bond.dart`)

| Field | Type | Source |
|-------|------|--------|
| `isin` | `String` (required) | API |
| `bondName` | `String` (required) | API |
| `rating` | `String?` | API |
| `bondYield` | `double?` | API (parsed from string) |
| `minInvestment` | `int?` | API (parsed from string) |
| `payoutFrequency` | `String?` | API |
| `logoUrl` | `String?` | API |
| `detailUrl` | `String?` | API |
| `tenure` | `double` (required) | API (parsed from string) |
| `maturityDate` | `String?` | API |
| `color` | `String?` | Wishlist context only |
| `isPinned` | `bool` | Wishlist context only |
| `position` | `int` | Wishlist context only |

Derived: `tenureLabel` → human-readable "3Y 6M" format.

### 7.2 Wishlist (`models/wishlist.dart`)

| Field | Type |
|-------|------|
| `id` | `String` (UUID) |
| `name` | `String` |
| `bondCount` | `int` |
| `createdAt` | `String` (RFC3339) |
| `updatedAt` | `String` (RFC3339) |

`WishlistDetails` extends `Wishlist` with `bonds: List<Bond>`.

---

## 8. Business Rules (Frontend-Enforced)

| Rule | Value | Enforced In |
|------|-------|-------------|
| Max wishlists | 5 | `WishlistsScreen._create()` |
| Max bonds per wishlist | 10 | `showAddToWishlistSheet` (capacity check) |
| Wishlist name max length | 50 chars | `_promptName()` dialog |
| Unique wishlist names | Checked by backend (409) | Error handling in `_create()` / `_rename()` |
| Sort preferences | Per-wishlist, in-memory only | `WishlistProvider._sortPrefs` |
| Search debounce | 500ms | `BondsProvider._debounce` |

---

## 9. Deep Link Integration

**Custom scheme:** `bondscanner://bond/{ISIN}`

**Flow** (`utils/deep_link.dart`):
1. Attempt to launch `bondscanner://bond/{ISIN}`
2. If scheme not handled → platform-specific app store link
3. Optional `webFallback` parameter (uses bond's `detailUrl` from API)

**Constants:**
- Play Store: `https://play.google.com/store/apps/details?id=com.bondscanner.app`
- App Store: `https://apps.apple.com/app/bondscanner/id0000000000`

---

## 10. UI Constants & Design System

### Color Palette (`utils/constants.dart`)

| Token | Hex | Usage |
|-------|-----|-------|
| `bg` | `#F7F8FA` | Screen backgrounds |
| `surface` | `#FFFFFF` | Card backgrounds |
| `navy` | `#0E2A47` | Seed color, primary |
| `navyDeep` | `#081B2E` | Text, active tabs, app bars |
| `gold` | `#C79A3E` | Pin icon |
| `green` | `#1B9E5A` | Yield text, success snackbar |
| `red` | `#D1483A` | Errors, delete actions |
| `muted` | `#8A93A6` | Secondary text, inactive tabs |
| `divider` | `#E7EAEF` | List dividers |
| `chipBg` | `#EFF2F6` | Logo fallback background |

### Typography

- Global: `GoogleFonts.interTextTheme()`
- Headings: Weight 800, size 24px, letter-spacing -0.5
- Bond name: Weight 600, size 15px
- Metrics: Weight 700, size 15px
- Subtitles: Weight 500, size 12.5px

---

## 11. Known Gaps & Future Considerations

1. **No pagination** — catalog is loaded entirely in memory. Will not scale beyond a few thousand bonds.
2. **Minimal test coverage** — only default Flutter smoke test exists. No widget or unit tests for business logic.
3. **No authentication** — single-user app. No multi-tenant support.
4. **In-memory sort preferences** — wishlist sort settings are lost on app restart.
5. **No local caching** — every screen load fetches from API. No offline support.
6. **Search in-memory** — backend fetches all bonds and applies custom fuzzy match in Go. Same scalability concern as #1.
7. **Hardcoded API URL** — `192.168.0.105:8080` is a local dev address. No environment configuration.
8. **App Store URLs** — BondScanner store links use placeholder IDs.
9. **No error retry logic** — network failures surface as snackbars but offer no retry (except wishlist initial load).
10. **Deep link scheme** — `bondscanner://` is custom. No universal link / app link fallback on iOS.
