class ExtractionResult {
  final String text;
  final String suggestedTitle;
  final String? sourceUrl;

  ExtractionResult({
    required this.text,
    required this.suggestedTitle,
    this.sourceUrl,
  });

  @override
  String toString() =>
      'ExtractionResult(title: $suggestedTitle, textLength: ${text.length})';
}
