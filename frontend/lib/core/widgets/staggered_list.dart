import 'package:flutter/material.dart';

/// Wraps children with staggered fade+slide-up animations.
/// Each child appears with a delay after the previous one.
class StaggeredList extends StatefulWidget {
  final List<Widget> children;
  final Duration itemDelay;
  final Duration itemDuration;
  final double slideOffset;

  const StaggeredList({
    super.key,
    required this.children,
    this.itemDelay = const Duration(milliseconds: 60),
    this.itemDuration = const Duration(milliseconds: 400),
    this.slideOffset = 30.0,
  });

  @override
  State<StaggeredList> createState() => _StaggeredListState();
}

class _StaggeredListState extends State<StaggeredList>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _fadeAnimations = [];
  final List<Animation<Offset>> _slideAnimations = [];
  int _generation = 0; // Empêche les Future.delayed orphelins

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _generation++;
    final currentGen = _generation;

    for (int i = 0; i < widget.children.length; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: widget.itemDuration,
      );

      _controllers.add(controller);
      _fadeAnimations.add(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      );
      _slideAnimations.add(
        Tween<Offset>(
          begin: Offset(0, widget.slideOffset),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic)),
      );

      Future.delayed(widget.itemDelay * i, () {
        // Vérifier que le widget est toujours monté ET que la génération n'a pas changé
        if (mounted && _generation == currentGen) controller.forward();
      });
    }
  }

  @override
  void didUpdateWidget(covariant StaggeredList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      _disposeControllers();
      _setupAnimations();
    }
  }

  void _disposeControllers() {
    for (final c in _controllers) {
      c.dispose();
    }
    _controllers.clear();
    _fadeAnimations.clear();
    _slideAnimations.clear();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.children.length, (i) {
        if (i >= _controllers.length) return widget.children[i];
        return AnimatedBuilder(
          animation: _controllers[i],
          builder: (context, child) {
            return Transform.translate(
              offset: _slideAnimations[i].value,
              child: Opacity(
                opacity: _fadeAnimations[i].value,
                child: child,
              ),
            );
          },
          child: widget.children[i],
        );
      }),
    );
  }
}

/// Animate a single widget with fade + slide when it first appears.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double slideOffset;
  final Axis axis;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 400),
    this.slideOffset = 24.0,
    this.axis = Axis.vertical,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: widget.axis == Axis.vertical
          ? Offset(0, widget.slideOffset)
          : Offset(widget.slideOffset, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: _slide.value,
          child: Opacity(opacity: _fade.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}
