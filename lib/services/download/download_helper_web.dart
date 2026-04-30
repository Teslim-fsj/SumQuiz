import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> downloadPdf(List<int> bytes, String fileName) async {
  try {
    final xFile = XFile.fromData(
      Uint8List.fromList(bytes),
      name: fileName,
      mimeType: 'application/pdf',
    );
    await Share.shareXFiles([xFile], text: 'Check out this exam from SumQuiz!');
  } catch (e) {
    // Fallback for browsers that don't support Web Share API for files
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    // ignore: unused_local_variable
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
