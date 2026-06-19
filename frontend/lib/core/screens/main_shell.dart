import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/tutorial/tutorial_keys.dart';

class MainShell extends StatefulWidget {
  final int currentIndex;
  final Widget child;

  const MainShell({super.key, required this.currentIndex, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  static const _routes = [
    '/dashboard',
    '/roadmap',
    '/applications',
    '/assistant',
    '/profile',
  ];

  late final AnimationController _controller;
  Animation<Offset>? _inAnimation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
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

      _inAnimation =
          Tween<Offset>(
            begin: Offset(goingRight ? 1.0 : -1.0, 0.0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          );

      _isAnimating = true;
      _controller.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    final keys = TutorialKeys.instance;

    final Widget body;
    if (_isAnimating && _inAnimation != null) {
      body = SlideTransition(position: _inAnimation!, child: widget.child);
    } else {
      body = widget.child;
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 16.h),
          child: Container(
            height: 60.h,
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(30.r),
              border: Border.all(color: cs.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(
                  cs,
                  0,
                  Icons.home_outlined,
                  Icons.home_rounded,
                  t.t('nav.home'),
                  keys.navHome,
                ),
                _navItem(
                  cs,
                  1,
                  Icons.route_outlined,
                  Icons.route_rounded,
                  t.t('nav.roadmap'),
                  keys.navRoadmap,
                ),
                _navItem(
                  cs,
                  2,
                  Icons.work_outline_rounded,
                  Icons.work_rounded,
                  t.t('nav.applications'),
                  keys.navApplications,
                ),
                _navItem(
                  cs,
                  3,
                  Icons.auto_awesome_outlined,
                  Icons.auto_awesome_rounded,
                  t.t('nav.assistant'),
                  keys.navAssistant,
                ),
                _navItem(
                  cs,
                  4,
                  Icons.person_outline_rounded,
                  Icons.person_rounded,
                  t.t('nav.profile'),
                  keys.navProfile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    ColorScheme cs,
    int index,
    IconData icon,
    IconData selectedIcon,
    String label,
    Key tutorialKey,
  ) {
    final selected = widget.currentIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (index != widget.currentIndex) {
          context.go(_routes[index]);
        }
      },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              KeyedSubtree(
                key: tutorialKey,
                child: Icon(
                  selected ? selectedIcon : icon,
                  size: 20.sp,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              if (selected) ...[
                SizedBox(width: 8.w),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
