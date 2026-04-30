import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadPdf(List<int> bytes, String fileName) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes);

  // Using shareXFiles for better platform compatibility
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'application/pdf', name: fileName)],
    subject: 'SumQuiz: $fileName',
    text: 'Check out this study material generated with SumQuiz!',
  );
}
