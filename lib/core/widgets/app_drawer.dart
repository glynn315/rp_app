import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'app_logo.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final currentLocation = GoRouterState.of(context).matchedLocation;

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DrawerHeader(name: user?.name, role: user?.position),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
                children: [
                  _DrawerTile(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home,
                    label: 'Dashboard',
                    selected: currentLocation == '/home',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go('/home');
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.add_a_photo_outlined,
                    selectedIcon: Icons.add_a_photo,
                    label: 'Log Progress',
                    selected: currentLocation == '/log-progress',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go('/log-progress');
                    },
                  ),
                  _DrawerAccordion(
                    title: 'Project Management',
                    icon: Icons.work_outline,
                    selectedIcon: Icons.work,
                    initiallyExpanded:
                        currentLocation.startsWith('/projects/'),
                    children: [
                      _DrawerTile(
                        icon: Icons.receipt_long_outlined,
                        selectedIcon: Icons.receipt_long,
                        label: 'Bill of Quantities',
                        selected:
                            currentLocation.startsWith('/projects/boq'),
                        nested: true,
                        onTap: () {
                          Navigator.of(context).pop();
                          context.go('/projects/boq');
                        },
                      ),
                      _DrawerTile(
                        icon: Icons.engineering_outlined,
                        selectedIcon: Icons.engineering,
                        label: 'Work in Progress',
                        selected:
                            currentLocation.startsWith('/projects/wip'),
                        nested: true,
                        onTap: () {
                          Navigator.of(context).pop();
                          context.go('/projects/wip');
                        },
                      ),
                      _DrawerTile(
                        icon: Icons.payments_outlined,
                        selectedIcon: Icons.payments,
                        label: 'LMC Payout',
                        selected: currentLocation
                            .startsWith('/projects/lmc-payout'),
                        nested: true,
                        onTap: () {
                          Navigator.of(context).pop();
                          context.go('/projects/lmc-payout');
                        },
                      ),
                      _DrawerTile(
                        icon: Icons.fact_check_outlined,
                        selectedIcon: Icons.fact_check,
                        label: 'Mandays Matching',
                        selected: currentLocation
                            .startsWith('/projects/mandays-matching'),
                        nested: true,
                        onTap: () {
                          Navigator.of(context).pop();
                          context.go('/projects/mandays-matching');
                        },
                      ),
                    ],
                  ),
                  const Divider(height: AppDimensions.lg, color: AppColors.neutral100),
                  _DrawerTile(
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    label: 'Profile',
                    selected: currentLocation == '/profile',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go('/profile');
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.neutral100),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text(
                'Sign out',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                await ref.read(authProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  final String? name;
  final String? role;

  const _DrawerHeader({this.name, this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.md,
        AppDimensions.md,
        AppDimensions.lg,
      ),
      decoration: const BoxDecoration(color: AppColors.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                height: 48,
                child: Center(child: AppLogo(size: 32, gap: 6)),
              ),
              const SizedBox(width: AppDimensions.sm),
              const Expanded(
                child: Text(
                  'RPV Workforce',
                  style: TextStyle(
                    color: AppColors.textOnPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Text(
            name ?? 'Employee',
            style: const TextStyle(
              color: AppColors.textOnPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (role != null && role!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              role!,
              style: TextStyle(
                color: AppColors.textOnPrimary.withValues(alpha: 0.75),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DrawerAccordion extends StatelessWidget {
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _DrawerAccordion({
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding:
            const EdgeInsets.symmetric(horizontal: AppDimensions.md),
        childrenPadding: EdgeInsets.zero,
        leading: Icon(
          initiallyExpanded ? selectedIcon : icon,
          color: initiallyExpanded
              ? AppColors.primary
              : AppColors.textSecondary,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight:
                initiallyExpanded ? FontWeight.w700 : FontWeight.w600,
            color: initiallyExpanded
                ? AppColors.primary
                : AppColors.textPrimary,
          ),
        ),
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.textSecondary,
        children: children,
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool nested;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.nested = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        selected ? selectedIcon : icon,
        color: selected ? AppColors.primary : AppColors.textSecondary,
        size: nested ? 20 : 24,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: nested ? 13 : 14,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      selected: selected,
      selectedTileColor: AppColors.surfaceVariant.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      contentPadding: EdgeInsets.fromLTRB(
        nested ? AppDimensions.xl : AppDimensions.md,
        0,
        AppDimensions.md,
        0,
      ),
      onTap: onTap,
    );
  }
}
