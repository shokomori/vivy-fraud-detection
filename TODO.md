# Implementation Plan — 4 Fixes for vivy_app/

## ✅ Item 3: Delete Facebook Messenger QR feature (DONE)
- [x] Verified: `messenger_qr_screen.dart` doesn't exist on disk
- [x] Verified: No `qr`, `facebook`, or `messenger` references in any `.dart` file
- [x] Verified: No `video_player` dependency in pubspec.yaml
- [x] Deleted orphaned `qr.svg` and `facebook.svg` assets (unused)

## ⬜ Item 1: History live-refresh (ValueNotifier)
- [x] **main.dart** (`_ReceiptCheckPageState`):
  - [x] Replace `List<HistoryEntry> _historyEntries` with `ValueNotifier<List<HistoryEntry>> _historyNotifier`
  - [x] Update `_loadHistory()`, `_recordHistory()`, `_deleteHistoryEntry()`, `_clearAllHistory()` to mutate notifier
  - [x] Pass `_historyNotifier.value` to `HomeScreen` and `HistoryScreen` instead of plain list
- [ ] **home_screen.dart** (`HomeScreen`):
  - Change param `entries` → `ValueNotifier<List<HistoryEntry>>`
  - Wrap content in `ValueListenableBuilder`
- [ ] **history_screen.dart** (`HistoryScreen`):
  - Change param `entries` → `ValueNotifier<List<HistoryEntry>>`
  - Replace local `_entries` copy with `ValueListenableBuilder`
  - Remove `didUpdateWidget` override
  - Update delete/clear handlers to mutate notifier

## ⬜ Item 2: 'How to Use ViVy' modal button padding
- [ ] **home_screen.dart** (`_HowToUseSheetState.build`):
  - Change hardcoded bottom button area padding to use `MediaQuery.of(context).padding.bottom`

## ⬜ Item 4: Home screen redesign (3 elements)
- [ ] **home_screen.dart** (`_SummaryCard` / `_SummaryPill`):
  - Add `scan.svg` icon to Scans pill (first stat pill currently has no SVG)
- [ ] **home_screen.dart** (`_MiniActionCard`):
  - Add trailing chevron (right arrow) to History and Learn More cards

