import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class AiToolsScreen extends StatelessWidget {
  const AiToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('AI Tools',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
              centerTitle: true,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24.0),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                // Determine the number of columns based on the available width.
                final crossAxisCount =
                    (constraints.crossAxisExtent / 350).floor().clamp(1, 2);

                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 20.0,
                    mainAxisSpacing: 20.0,
                    childAspectRatio:
                        1.2, // Adjust this ratio to fit your card content
                  ),
                  delegate: SliverChildListDelegate(
                    AnimationConfiguration.toStaggeredList(
                      duration: const Duration(milliseconds: 375),
                      childAnimationBuilder: (widget) => SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          child: widget,
                        ),
                      ),
                      children: [
                        _buildFeatureCard(
                          context,
                          theme: theme,
                          icon: Icons.flash_on,
                          title: 'Generate Summary',
                          subtitle:
                              'Summarize any text, article, or document instantly.',
                          onTap: () => context.push('/summary'),
                        ),
                        _buildFeatureCard(
                          context,
                          theme: theme,
                          icon: Icons.filter_none,
                          title: 'Flashcards',
                          subtitle:
                              'Create flashcards from any content to aid your learning.',
                          onTap: () => context.push('/flashcards'),
                        ),
                        _buildFeatureCard(
                          context,
                          theme: theme,
                          icon: Icons.question_answer,
                          title: 'Generate Quiz',
                          subtitle:
                              'Create a quiz from any content to test your knowledge.',
                          onTap: () => context.push('/quiz'),
                        ),
                        _buildProFeatureCard(
                          context,
                          theme: theme,
                          icon: Icons.picture_as_pdf,
                          title: 'Quiz from PDF & Images',
                          subtitle:
                              'Upgrade to Pro to unlock generation from documents and photos.',
                          onTap: () => context.push('/subscription'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context,
      {required ThemeData theme,
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 8),
              Expanded(
                child: Text(subtitle, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProFeatureCard(BuildContext context,
      {required ThemeData theme,
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return Card(
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.tertiary.withOpacity(0.2),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icon, size: 40, color: theme.colorScheme.tertiary),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('PRO',
                        style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onTertiary)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: Text(subtitle, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
