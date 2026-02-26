import 'package:sumquiz/models/extraction_result.dart';

class ExtractionResultCache {
  static ExtractionResult? _pending;

  static void set(ExtractionResult result) {
    _pending = result;
  }

  static ExtractionResult? consume() {
    final result = _pending;
    _pending = null;
    return result;
  }
}
