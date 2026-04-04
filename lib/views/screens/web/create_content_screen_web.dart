import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../models/user_model.dart';
import '../../../providers/create_content_provider.dart';
import '../../widgets/create_content/creation_progress_indicator.dart';
import '../../widgets/create_content/creation_success_view.dart';
import '../../widgets/create_content/web_source_selection.dart';
import '../../widgets/create_content/web_configuration.dart';
import '../../widgets/upgrade_dialog.dart';

class CreateContentScreenWeb extends StatefulWidget {
  const CreateContentScreenWeb({super.key});

  @override
  State<CreateContentScreenWeb> createState() => _CreateContentScreenWebState();
}

class _CreateContentScreenWebState extends State<CreateContentScreenWeb> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CreateContentProvider>(context);
    final user = Provider.of<UserModel?>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFF),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _buildPhaseContent(context, provider, user),
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseContent(BuildContext context, CreateContentProvider provider, UserModel? user) {
    switch (provider.phase) {
      case CreationPhase.source:
        return WebSourceSelection(
          key: ValueKey(provider.phase),
          onTranslate: (t) {},
          onUploadFiles: () => _pickFile(context, provider, user, ['pdf', 'doc', 'docx', 'txt'], 'pdf'),
          onWriteNow: () => _showInputDialog(context, provider, 'Text / Quick Topic', 'Type a topic or paste text...', isTopic: true),
          onImportUrl: () => _showInputDialog(context, provider, 'YouTube / Web Link', 'Paste URL here...', isLink: true),
          onScanPage: () => _pickFile(context, provider, user, ['jpg', 'jpeg', 'png'], 'image'),
          onListenAndLearn: () => _pickFile(context, provider, user, ['mp3', 'wav', 'm4a'], 'audio'),
        );
      case CreationPhase.config:
        return WebConfiguration(
          key: ValueKey(provider.phase),
          provider: provider,
          onGenerate: () {
            if (user != null) provider.startGeneration(user.uid);
          },
        );
      case CreationPhase.processing:
        return CreationProgressIndicator(message: provider.progressMessage);
      case CreationPhase.success:
        return CreationSuccessView(
          title: provider.fileName ?? (provider.textContent.length > 30 ? '${provider.textContent.substring(0, 30)}...' : provider.textContent),
          onViewPack: () {
            context.pushNamed('results-view', pathParameters: {'folderId': provider.generatedFolderId});
            provider.reset();
          },
          onReset: provider.reset,
        );
      case CreationPhase.error:
        return _buildErrorView(context, provider);
    }
  }

  Future<void> _pickFile(BuildContext context, CreateContentProvider provider, UserModel? user, List<String> extensions, String type) async {
    if (user != null && !user.isPro && type != 'pdf') {
       showDialog(context: context, builder: (_) => UpgradeDialog(featureName: '$type Uploads'));
       return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      provider.setSource(type, fileName: file.name, bytes: file.bytes, mime: _getMimeType(file.name));
    }
  }

  void _showInputDialog(BuildContext context, CreateContentProvider provider, String title, String hint, {bool isTopic = false, bool isLink = false}) {
    _textController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: _textController,
            autofocus: true,
            maxLines: isLink || isTopic ? 1 : 10,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.outfit(color: Colors.grey),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final text = _textController.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(context);
                provider.setSource(isTopic ? 'topic' : (isLink ? 'link' : 'text'), text: text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3300FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  String _getMimeType(String name) {
    final ext = name.split('.').last.toLowerCase();
    const map = {
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'txt': 'text/plain',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'mp3': 'audio/mpeg',
      'mp4': 'video/mp4',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  Widget _buildErrorView(BuildContext context, CreateContentProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 600,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: colorScheme.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 60),
          const SizedBox(height: 32),
          Text('Extraction Failed', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
          const SizedBox(height: 16),
          Text(provider.errorMessage, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(onPressed: provider.reset, child: const Text('Choose Different Source')),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: provider.backToConfig,
                style: ElevatedButton.styleFrom(backgroundColor: colorScheme.onSurface, foregroundColor: colorScheme.surface),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
