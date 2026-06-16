import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/platform_caps_repository.dart';
import 'data/reel_counter_service.dart';
import 'domain/entities/reel_count.dart';

/// Singleton bridge to the native ReelCounterPlugin.
final reelCounterServiceProvider = Provider<ReelCounterService>((ref) {
  return createReelCounterService();
});

/// `true` when the user has enabled the AccessibilityService in Settings.
///
/// Invalidate this provider on `AppLifecycleState.resumed` so the dashboard
/// re-checks after the user returns from system settings.
final reelCounterAccessibilityEnabledProvider =
    FutureProvider<bool>((ref) async {
  return ref.watch(reelCounterServiceProvider).isAccessibilityEnabled();
});

/// Live stream of today's reel-count snapshot. Yields the current value
/// immediately on subscribe.
final reelCountStreamProvider = StreamProvider<ReelCountSnapshot>((ref) {
  return ref.watch(reelCounterServiceProvider).stream;
});

/// One-shot read of today's counter (for non-reactive call-sites).
final reelCountTodayProvider = FutureProvider<ReelCountSnapshot>((ref) {
  return ref.watch(reelCounterServiceProvider).getSnapshot();
});

/// Last 7 days of counters (oldest first), used by the Stats screen.
final reelCountHistoryProvider =
    FutureProvider.family<List<ReelCountDay>, int>((ref, days) {
  return ref.watch(reelCounterServiceProvider).getHistory(days: days);
});

// ---- Overlay HUD ---------------------------------------------------------

/// `true` when the user has granted "Display over other apps".
final overlayPermissionProvider = FutureProvider<bool>((ref) {
  return ref.watch(reelCounterServiceProvider).canDrawOverlays();
});

/// `true` when ScrollIQ is exempt from battery optimisations.
final batteryExemptProvider = FutureProvider<bool>((ref) {
  return ref.watch(reelCounterServiceProvider).isBatteryOptimizationIgnored();
});

/// Aggregate state for the HUD bubble — combines permission + running flags
/// so the dashboard can render a single "Floating counter" toggle.
class OverlayState {
  const OverlayState({required this.canDraw, required this.running});
  final bool canDraw;
  final bool running;

  OverlayState copyWith({bool? canDraw, bool? running}) =>
      OverlayState(canDraw: canDraw ?? this.canDraw, running: running ?? this.running);

  static const OverlayState initial = OverlayState(canDraw: false, running: false);
}

/// View-model that manages overlay lifecycle and exposes [OverlayState].
class OverlayController extends StateNotifier<OverlayState> {
  OverlayController(this._service) : super(OverlayState.initial) {
    _refresh();
  }

  final ReelCounterService _service;

  Future<void> _refresh() async {
    final canDraw = await _service.canDrawOverlays();
    final running = canDraw ? await _service.isOverlayRunning() : false;
    if (!mounted) return;
    state = state.copyWith(canDraw: canDraw, running: running);
  }

  /// Re-reads permission + running state. Call on `AppLifecycleState.resumed`
  /// after sending the user to system Settings.
  Future<void> refresh() => _refresh();

  /// Opens the overlay-permission settings page.
  Future<void> requestPermission() async {
    await _service.openOverlaySettings();
  }

  /// Starts the bubble. Returns `true` if the service launched; `false` means
  /// permission is still missing (the caller should call [requestPermission]).
  Future<bool> start() async {
    final ok = await _service.startOverlay();
    if (ok && mounted) state = state.copyWith(running: true);
    if (!ok) {
      // Stay defensive: maybe the user revoked permission while we were idle.
      await _refresh();
    }
    return ok;
  }

  /// Stops the bubble.
  Future<void> stop() async {
    await _service.stopOverlay();
    if (mounted) state = state.copyWith(running: false);
  }

  /// Convenience toggle used by the dashboard switch.
  Future<void> toggle() async {
    if (state.running) {
      await stop();
    } else {
      await start();
    }
  }

  @visibleForTesting
  void debugSet(OverlayState next) => state = next;
}

final overlayControllerProvider =
    StateNotifierProvider<OverlayController, OverlayState>((ref) {
  return OverlayController(ref.watch(reelCounterServiceProvider));
});

// ---- Platform Caps -------------------------------------------------------

final platformCapsRepoProvider = Provider<PlatformCapsRepository>((ref) {
  return PlatformCapsRepository();
});

final platformCapsProvider = FutureProvider<List<PlatformCap>>((ref) {
  return ref.watch(platformCapsRepoProvider).loadAll();
});
