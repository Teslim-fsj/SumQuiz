import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sumquiz/utils/version_comparator.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UpdateState {
  upToDate,
  optional,
  mandatory,
}

class VersionUpdateService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  UpdateState _updateState = UpdateState.upToDate;
  UpdateState get updateState => _updateState;

  bool _isChecking = true;
  bool get isChecking => _isChecking;

  String? _currentVersion;
  String? get currentVersion => _currentVersion;

  String? _latestVersion;
  String? get latestVersion => _latestVersion;

  String? _minSupportedVersion;
  String? get minSupportedVersion => _minSupportedVersion;

  int _dynamicContentVersion = 0;
  
  // Track if we've already shown the optional update dialog during this session
  bool _hasShownOptionalUpdateNudge = false;
  bool get hasShownOptionalUpdateNudge => _hasShownOptionalUpdateNudge;

  void markOptionalUpdateNudgeShown() {
    _hasShownOptionalUpdateNudge = true;
    notifyListeners();
  }

  Future<void> checkForUpdates() async {
    _isChecking = true;
    notifyListeners();

    try {
      // 1. Get current app version
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;

      // 2. Fetch config from Firestore
      final docSnapshot = await _firestore.collection('system').doc('app_config').get();
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        _latestVersion = data['latest_version'] as String?;
        _minSupportedVersion = data['min_supported_version'] as String?;
        final updateType = data['update_type'] as String? ?? 'optional';
        final newDynamicContentVersion = data['dynamic_content_version'] as int? ?? 0;

        if (_currentVersion != null && _minSupportedVersion != null && _latestVersion != null) {
          // Check for mandatory update
          if (VersionComparator.compare(_currentVersion!, _minSupportedVersion!) < 0) {
            _updateState = UpdateState.mandatory;
          } 
          // Check for optional update
          else if (VersionComparator.compare(_currentVersion!, _latestVersion!) < 0) {
            if (updateType == 'mandatory') {
               // The latest version is marked as mandatory for all.
               _updateState = UpdateState.mandatory;
            } else {
               _updateState = UpdateState.optional;
            }
          } 
          // Up to date
          else {
            _updateState = UpdateState.upToDate;
          }
        }

        // 3. Handle dynamic content fetching
        await _checkAndFetchDynamicContent(newDynamicContentVersion);
      }
    } catch (e) {
      debugPrint('Failed to check for updates: $e');
      // On failure, assume up-to-date to avoid blocking user due to network issue
      _updateState = UpdateState.upToDate;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<void> _checkAndFetchDynamicContent(int newVersion) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int currentDynamicVersion = prefs.getInt('dynamic_content_version') ?? 0;

      if (newVersion > currentDynamicVersion) {
        debugPrint('New dynamic content available (v$newVersion). Fetching...');
        // TODO: Implement actual fetch logic for templates/weights here.
        // E.g., await DynamicContentRepository.fetchBundles(newVersion);
        
        await prefs.setInt('dynamic_content_version', newVersion);
        _dynamicContentVersion = newVersion;
      }
    } catch (e) {
      debugPrint('Failed to fetch dynamic content: $e');
    }
  }
}
