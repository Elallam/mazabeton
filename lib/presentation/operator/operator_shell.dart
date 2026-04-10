import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers.dart';

class OperatorShell extends ConsumerWidget {
  final Widget child;
  const OperatorShell({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/operator/quantity')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _selectedIndex(context);
    final commercial = ref.watch(currentCommercialProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // const Icon(Icons.construction_rounded, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            const Text('MAZABETON'),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.operatorColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.operatorColor.withOpacity(0.4)),
            ),
            child: Text(
              commercial?.firstname.toUpperCase() ?? 'OPÉRATEUR',
              style: const TextStyle(
                color: AppColors.operatorColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        backgroundColor: AppColors.primaryLight,
        indicatorColor: AppColors.operatorColor.withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppColors.operatorColor),
            label: 'Tableau de bord',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: AppColors.operatorColor),
            label: 'Quantité',
          ),
        ],
        onDestinationSelected: (i) {
          switch (i) {
            case 0: context.go('/operator'); break;
            case 1: context.go('/operator/quantity'); break;
          }
        },
      ),
    );
  }
}
