import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/app_drawer.dart';

/// Shared scaffold + AsyncValue states for Project Management list screens.
/// Centralises the drawer/hamburger plumbing, pull-to-refresh, and the
/// loading / error / empty visuals so each list screen only contributes its
/// own row builder.
class ProjectListShell extends StatelessWidget {
  final String title;
  final IconData emptyIcon;
  final String emptyMessage;
  final bool isLoading;
  final Object? error;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Future<void> Function() onRefresh;
  final Widget? floatingActionButton;
  final Widget? subtitle;
  final Widget? header;

  const ProjectListShell({
    super.key,
    required this.title,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.isLoading,
    required this.error,
    required this.itemCount,
    required this.itemBuilder,
    required this.onRefresh,
    this.floatingActionButton,
    this.subtitle,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        // Builder gives the IconButton a context that's a *descendant* of this
        // Scaffold, so Scaffold.of() can find the local drawer. Without it,
        // the build-method context is above the Scaffold and Scaffold.of()
        // returns null.
        leading: Builder(
          builder: (innerContext) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Open menu',
            onPressed: () => Scaffold.of(innerContext).openDrawer(),
          ),
        ),
        title: Text(title),
        bottom: subtitle == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.md,
                    0,
                    AppDimensions.md,
                    AppDimensions.sm,
                  ),
                  alignment: Alignment.centerLeft,
                  child: DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                    ),
                    child: subtitle!,
                  ),
                ),
              ),
      ),
      floatingActionButton: floatingActionButton,
      body: Column(
        children: [
          ?header,
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: _body(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (isLoading && itemCount == 0) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && itemCount == 0) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.lg),
        children: [
          _ErrorPanel(message: error.toString()),
        ],
      );
    }
    if (itemCount == 0) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.lg),
        children: [
          _EmptyPanel(icon: emptyIcon, message: emptyMessage),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.sm),
      itemBuilder: itemBuilder,
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String message;
  const _ErrorPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.error, size: 18),
              SizedBox(width: AppDimensions.xs),
              Text(
                'Could not load',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.xs),
          const Text(
            'Pull down to retry.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyPanel({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.xl),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.textMuted),
          const SizedBox(height: AppDimensions.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
