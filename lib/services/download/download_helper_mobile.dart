import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadPdf(List<int> bytes, String fileName) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes);

  await Share.shareXFiles([XFile(file.path)],
      text: 'Here is my study guide created with SumQuiz!');
}
