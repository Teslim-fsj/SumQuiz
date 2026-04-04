import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
      backgroundColor: const Color(0xFFFFFFFF),
      body: Row(
        children: [
          // SIDEBAR (Simplified for Study Pack Flow)
          _buildSidebar(context),
          
          // MAIN CONTENT
          Expanded(
            child: Column(
              children: [
                _buildWebHeader(context, provider),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _buildPhaseContent(context, provider, user),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
     return Container(
       width: 280,
       color: const Color(0xFFFBFBFF),
       padding: const EdgeInsets.all(32),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(
             children: [
               Container(
                 width: 32,
                 height: 32,
                 decoration: BoxDecoration(
                   color: const Color(0xFF3300FF),
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
               ),
               const SizedBox(width: 12),
               Text(
                 'SumQuiz',
                 style: GoogleFonts.outfit(
                   fontSize: 22,
                   fontWeight: FontWeight.w900,
                   color: const Color(0xFF3300FF),
                 ),
               ),
             ],
           ),
           const SizedBox(height: 60),
           _SidebarItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
           _SidebarItem(icon: Icons.library_books_rounded, label: 'Library'),
           _SidebarItem(icon: Icons.style_rounded, label: 'Study Sets'),
           _SidebarItem(icon: Icons.quiz_rounded, label: 'Quizzes'),
           _SidebarItem(icon: Icons.analytics_rounded, label: 'Analytics'),
           const Spacer(),
           _SidebarItem(icon: Icons.settings_rounded, label: 'Settings'),
           _SidebarItem(icon: Icons.help_outline_rounded, label: 'Help'),
           const SizedBox(height: 24),
           Container(
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               color: Colors.white,
               borderRadius: BorderRadius.circular(16),
               boxShadow: [
                 BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10),
               ],
             ),
             child: Row(
               children: [
                 const CircleAvatar(
                   radius: 20,
                   backgroundImage: AssetImage('assets/images/avatar_placeholder.png'),
                 ),
                 const SizedBox(width: 12),
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       'Alex Rivera',
                       style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                     ),
                     Text(
                       'Premium Member',
                       style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF999999)),
                     ),
                   ],
                 ),
               ],
             ),
           ),
         ],
       ),
     );
  }

  Widget _buildWebHeader(BuildContext context, CreateContentProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
           const SizedBox(width: 12),
           const Spacer(),
           Container(
             width: 400,
             height: 48,
             decoration: BoxDecoration(
               color: const Color(0xFFF0F2FF),
               borderRadius: BorderRadius.circular(24),
             ),
             padding: const EdgeInsets.symmetric(horizontal: 20),
             child: Row(
               children: [
                 const Icon(Icons.search_rounded, color: Color(0xFF999999), size: 20),
                 const SizedBox(width: 12),
                 Expanded(
                   child: TextField(
                     decoration: InputDecoration(
                       hintText: 'Search knowledge...',
                       hintStyle: GoogleFonts.outfit(color: const Color(0xFF999999), fontSize: 14),
                       border: InputBorder.none,
                       isDense: true,
                     ),
                   ),
                 ),
               ],
             ),
           ),
           const SizedBox(width: 24),
           const Icon(Icons.notifications_none_rounded, color: Color(0xFF1A1A1A)),
           const SizedBox(width: 24),
           const Icon(Icons.account_circle_outlined, color: Color(0xFF1A1A1A)),
        ],
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
          onScanPage: () => _showInputDialog(context, provider, 'Images / Snap', 'This feature is coming soon!', isLink: false),
          onListenAndLearn: () => _pickFile(context, provider, user, ['mp3', 'wav', 'm4a'], 'audio'),
        );
      case CreationPhase.config:
        return WebConfiguration(
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

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SidebarItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF666666), size: 24),
          const SizedBox(width: 16),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }
}
