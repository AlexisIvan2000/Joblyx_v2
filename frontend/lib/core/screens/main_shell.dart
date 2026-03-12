import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';

/// Shell avec bottom navigation pour les 4 onglets principaux.
class MainShell extends StatefulWidget {
  final int currentIndex;
  final Widget child;

  const MainShell({
    super.key,
    required this.currentIndex,
    required this.child,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  static const _routes = ['/dashboard', '/roadmap', '/applications', '/profile'];

  late final AnimationController _controller;
  Animation<Offset>? _inAnimation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _isAnimating = false);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      final goingRight = widget.currentIndex > oldWidget.currentIndex;

      _inAnimation = Tween<Offset>(
        begin: Offset(goingRight ? 1.0 : -1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

      _isAnimating = true;
      _controller.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    final Widget body;
    if (_isAnimating && _inAnimation != null) {
      body = SlideTransition(position: _inAnimation!, child: widget.child);
    } else {
      body = widget.child;
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
        ),
        child: NavigationBar(
          selectedIndex: widget.currentIndex,
          onDestinationSelected: (i) {
            if (i != widget.currentIndex) {
              context.go(_routes[i]);
            }
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          height: 64.h,
          indicatorColor: cs.primary.withValues(alpha: 0.1),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: cs.primary),
              label: t.t('nav.home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route_rounded, color: cs.primary),
              label: t.t('nav.roadmap'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.work_outline_rounded),
              selectedIcon: Icon(Icons.work_rounded, color: cs.primary),
              label: t.t('nav.applications'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded, color: cs.primary),
              label: t.t('nav.profile'),
            ),
          ],
        ),
      ),
    );
  }
}
