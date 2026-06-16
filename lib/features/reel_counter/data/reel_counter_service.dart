import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/entities/reel_count.dart';

/// Bridges the native ReelCounterPlugin (`com.scrolliq/reel_counter` +
/// `com.scrolliq/reel_counter/stream`) to Dart.
///
/// Use [stream] for live updates while the user is scrolling and
/// [getSnapshot] for one-shot reads (e.g. when the dashboard first opens).
abstract class ReelCounterService {
  // ---- Counter & permissions ----

  /// True when the AccessibilityService is enabled in system Settings.
  Future<bool> isAccessibilityEnabled();

  /// Opens the system Accessibility settings page so the user can toggle the
  /// service on. Returns immediately; you must observe
  /// [isAccessibilityEnabled] afterwards (e.g. on `AppLifecycleState.resumed`).
  Future<void> openAccessibilitySettings();

  /// One-shot read of today's counter.
  Future<ReelCountSnapshot> getSnapshot();

  /// Returns the last [days] days of counters, oldest first.
  Future<List<ReelCountDay>> getHistory({int days = 7});

  /// Resets today's counter to zero. Useful for tests / settings page.
  Future<void> reset();

  /// Hot stream of snapshots. Emits the current snapshot once on subscribe,
  /// then on every store mutation.
  Stream<ReelCountSnapshot> get stream;

  // ---- Overlay HUD ----

  /// Whether the user has granted "Display over other apps" permission.
  Future<bool> canDrawOverlays();

  /// Deeplinks to the system "Display over other apps" settings page filtered
  /// to ScrollIQ.
  Future<void> openOverlaySettings();

  /// Whether the overlay foreground service is currently running.
  Future<bool> isOverlayRunning();

  /// Starts the overlay HUD bubble. Returns `false` if the overlay permission
  /// is missing — caller should route the user to [openOverlaySettings] first.
  Future<bool> startOverlay();

  /// Stops the overlay foreground service and removes the bubble.
  Future<void> stopOverlay();

  /// Whether ScrollIQ is exempt from battery optimisations. We need this so
  /// the AccessibilityService isn't culled by Doze on locked screens.
  Future<bool> isBatteryOptimizationIgnored();

  /// Deeplinks to the per-app battery-exemption prompt (or the generic list
  /// on OEMs that block direct deeplinks).
  Future<void> openBatterySettings();
}

/// Stub used on platforms without a native implementation (iOS, web, desktop).
class NoopReelCounterService implements ReelCounterService {
  @override
  Future<bool> isAccessibilityEnabled() async => false;

  @override
  Future<void> openAccessibilitySettings() async {}

  @override
  Future<ReelCountSnapshot> getSnapshot() async => ReelCountSnapshot.empty;

  @override
  Future<List<ReelCountDay>> getHistory({int days = 7}) async => const [];

  @override
  Future<void> reset() async {}

  @override
  Stream<ReelCountSnapshot> get stream =>
      Stream<ReelCountSnapshot>.value(ReelCountSnapshot.empty);

  @override
  Future<bool> canDrawOverlays() async => false;

  @override
  Future<void> openOverlaySettings() async {}

  @override
  Future<bool> isOverlayRunning() async => false;

  @override
  Future<bool> startOverlay() async => false;

  @override
  Future<void> stopOverlay() async {}

  @override
  Future<bool> isBatteryOptimizationIgnored() async => true;

  @override
  Future<void> openBatterySettings() async {}
}

/// Android implementation backed by MethodChannel + EventChannel.
class AndroidReelCounterService implements ReelCounterService {
  static const _method = MethodChannel('com.scrolliq/reel_counter');
  static const _events = EventChannel('com.scrolliq/reel_counter/stream');

  Stream<ReelCountSnapshot>? _broadcast;

  @override
  Future<bool> isAccessibilityEnabled() async {
    final ok = await _method.invokeMethod<bool>('isAccessibilityEnabled');
    return ok ?? false;
  }

  @override
  Future<void> openAccessibilitySettings() async {
    await _method.invokeMethod<void>('openAccessibilitySettings');
  }

  @override
  Future<ReelCountSnapshot> getSnapshot() async {
    final raw = await _method.invokeMethod<Map<dynamic, dynamic>>('getSnapshot');
    if (raw == null) return ReelCountSnapshot.empty;
    return ReelCountSnapshot.fromMap(raw);
  }

  @override
  Future<List<ReelCountDay>> getHistory({int days = 7}) async {
    final raw = await _method
        .invokeMethod<List<dynamic>>('getHistory', <String, dynamic>{'days': days});
    if (raw == null) return const [];
    return raw
        .cast<Map<dynamic, dynamic>>()
        .map(ReelCountDay.fromMap)
        .toList(growable: false);
  }

  @override
  Future<void> reset() async {
    await _method.invokeMethod<void>('reset');
  }

  @override
  Stream<ReelCountSnapshot> get stream {
    return _broadcast ??= _events
        .receiveBroadcastStream()
        .map<ReelCountSnapshot>((dynamic raw) {
          if (raw is Map) {
            return ReelCountSnapshot.fromMap(raw);
          }
          return ReelCountSnapshot.empty;
        })
        .asBroadcastStream();
  }

  @override
  Future<bool> canDrawOverlays() async {
    final ok = await _method.invokeMethod<bool>('canDrawOverlays');
    return ok ?? false;
  }

  @override
  Future<void> openOverlaySettings() async {
    await _method.invokeMethod<void>('openOverlaySettings');
  }

  @override
  Future<bool> isOverlayRunning() async {
    final ok = await _method.invokeMethod<bool>('isOverlayRunning');
    return ok ?? false;
  }

  @override
  Future<bool> startOverlay() async {
    final ok = await _method.invokeMethod<bool>('startOverlay');
    return ok ?? false;
  }

  @override
  Future<void> stopOverlay() async {
    await _method.invokeMethod<void>('stopOverlay');
  }

  @override
  Future<bool> isBatteryOptimizationIgnored() async {
    final ok = await _method.invokeMethod<bool>('isBatteryOptimizationIgnored');
    return ok ?? true;
  }

  @override
  Future<void> openBatterySettings() async {
    await _method.invokeMethod<void>('openBatterySettings');
  }
}

/// Returns the right implementation per platform.
ReelCounterService createReelCounterService() {
  if (Platform.isAndroid) return AndroidReelCounterService();
  return NoopReelCounterService();
}
