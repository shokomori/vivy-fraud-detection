# UI/UX Update Plan - Progress Tracker

## Status
- ✅ `pubspec.yaml` - Already has `google_fonts`
- ✅ `domain/analysis_models.dart` - Updated (displayLabel fix, HistoryEntry fields)
- ✅ `result_card.dart` - Updated (badgeIcon, GCash Payment Receipt header, 48x48 icon, 34px score)
- ✅ `main.dart` - Updated (onDone, _clearResult, _deleteHistoryEntry, _clearAllHistory, explanation in HistoryEntry)

### Remaining Files to Update:
- ❌ **`home_screen.dart`** - Needs _TapScale, _HowToUseSheet (390x490), gradient UploadCard, white border+shadow SummaryCard, pill icons, MiniActionCard border, QrCard border+shadow, TipsCard emoji+rotation, SummaryStats lastScanColor, _buildLastScanTextSpans
- ❌ **`analyze_screen.dart`** - Needs _BackButton widget, _TapScale, _DashedBorderPainter, 350x300 upload box, 3 chips, animated scanning, _AnimatedProgressBar, _AnimatedLoadingBars, onDone param, updated recommendations, remove Copy Raw Score CSV button
- ❌ **`history_screen.dart`** - Needs to be StatefulWidget, _TapScale, _BackButton, delete button in AppBar, tappable items to VerificationDetailScreen, fade+slide transition, color-coded entries, _formatShort
- ❌ **`splash_screen.dart`** - Needs to be StatefulWidget with animations, logo glow, elastic bounce, ViVy wordmark, GCASH subtitle, breathing 3-dot loader
- ❌ **`guidelines_screen.dart`** - Needs simplified SVGs, updated text, "Tap to Start →", PlusJakartaSans font family references
- ❌ **`learn_more_screen.dart`** - Needs _TapScale, _StepEntrance animation, _HelpDeskStep inline contacts with Wrap+dot, updated contact colors, LayoutBuilder centering
- ❌ **`messenger_qr_screen.dart`** - Needs _AnimatedTapScale, _DashedBorderPainter, HOW IT WORKS section, Watch Video button, YouTube player, pro tip, Hero animation, updated colors
- ❌ **`help_desks_contacts_screen.dart`** - Needs inline Wrap+dot separator, updated colors (GCash=teal, BSP=blue, PNP=red, DTI=orange), GCash only 1 line

