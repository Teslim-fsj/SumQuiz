import 'dart:developer' as developer;
import 'package:cloud_functions/cloud_functions.dart';

/// Service to sync device time with server time
/// Prevents users from manipulating device time to extend expired subscriptions
class TimeSyncService {
  static Duration _timeOffset = Duration.zero;
  static DateTime? _lastSync;
  static bool _isSyncing = false;

  /// Synchronizes local time with server time
  /// Should be called on app startup and periodically (every 24h)
  static Future<void> syncWithServer() async {
    if (_isSyncing) return; // Prevent concurrent syncs

    _isSyncing = true;
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('getServerTime');
      final result = await callable.call();

      final serverTime = DateTime.parse(result.data['serverTime']);
      final localTime = DateTime.now();

      _timeOffset = serverTime.difference(localTime);
      _lastSync = localTime;

      developer.log(
        'Time synced with server. Offset: ${_timeOffset.inSeconds}s',
        name: 'TimeSyncService',
      );
    } catch (e) {
      developer.log(
        'Time sync failed, using local time',
        name: 'TimeSyncService',
        error: e,
      );
      // Fallback to local time if server unreachable
      _timeOffset = Duration.zero;
    } finally {
      _isSyncing = false;
    }
  }

  /// Returns current time adjusted for server offset
  /// Automatically triggers re-sync if last sync was > 24 hours ago
  static DateTime get now {
    // Re-sync if last sync was > 24 hours ago
    if (_lastSync == null ||
        DateTime.now().difference(_lastSync!) > const Duration(hours: 24)) {
      // Trigger background sync (don't await to avoid blocking)
      syncWithServer();
    }

    return DateTime.now().add(_timeOffset);
  }

  /// Returns the current time offset from server
  static Duration get offset => _timeOffset;

  /// Returns when the last sync occurred
  static DateTime? get lastSyncTime => _lastSync;

  /// Checks if time is recently synced (< 24 hours old)
  static bool get isSynced {
    if (_lastSync == null) return false;
    return DateTime.now().difference(_lastSync!) < const Duration(hours: 24);
  }
}
