class VersionComparator {
  /// Compares two semantic versions.
  /// Returns 0 if v1 == v2
  /// Returns 1 if v1 > v2
  /// Returns -1 if v1 < v2
  static int compare(String v1, String v2) {
    List<int> parts1 = _parseVersion(v1);
    List<int> parts2 = _parseVersion(v2);

    int maxLength =
        parts1.length > parts2.length ? parts1.length : parts2.length;

    for (int i = 0; i < maxLength; i++) {
      int p1 = i < parts1.length ? parts1[i] : 0;
      int p2 = i < parts2.length ? parts2[i] : 0;

      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }

    return 0;
  }

  static List<int> _parseVersion(String version) {
    // Remove any build numbers (e.g., "1.0.34+196" -> "1.0.34")
    String cleanVersion = version.split('+')[0];

    // Remove any pre-release tags (e.g., "1.0.0-alpha" -> "1.0.0")
    cleanVersion = cleanVersion.split('-')[0];

    return cleanVersion
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }
}
