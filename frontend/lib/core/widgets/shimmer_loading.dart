import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Shimmer effect widget — wraps any child with a sweeping gradient animation.
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
    final highlightColor =
        isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Simple skeleton placeholder box with rounded corners.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Dashboard skeleton — mimics the real dashboard layout.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            SkeletonBox(width: 80.w, height: 14.h),
            SizedBox(height: 6.h),
            SkeletonBox(width: 160.w, height: 28.h),
            SizedBox(height: 20.h),
            // Progress card
            SkeletonBox(width: double.infinity, height: 120.h, borderRadius: 20),
            SizedBox(height: 20.h),
            // Stat cards row
            Row(
              children: [
                Expanded(child: SkeletonBox(width: double.infinity, height: 90.h, borderRadius: 14)),
                SizedBox(width: 10.w),
                Expanded(child: SkeletonBox(width: double.infinity, height: 90.h, borderRadius: 14)),
                SizedBox(width: 10.w),
                Expanded(child: SkeletonBox(width: double.infinity, height: 90.h, borderRadius: 14)),
              ],
            ),
            SizedBox(height: 24.h),
            // Section header
            SkeletonBox(width: 140.w, height: 18.h),
            SizedBox(height: 12.h),
            // Phase card
            SkeletonBox(width: double.infinity, height: 140.h, borderRadius: 16),
            SizedBox(height: 24.h),
            // Section header
            SkeletonBox(width: 180.w, height: 18.h),
            SizedBox(height: 12.h),
            // Application tiles
            SkeletonBox(width: double.infinity, height: 60.h, borderRadius: 14),
            SizedBox(height: 8.h),
            SkeletonBox(width: double.infinity, height: 60.h, borderRadius: 14),
            SizedBox(height: 8.h),
            SkeletonBox(width: double.infinity, height: 60.h, borderRadius: 14),
          ],
        ),
      ),
    );
  }
}

/// Applications list skeleton.
class ApplicationsSkeleton extends StatelessWidget {
  const ApplicationsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            SkeletonBox(width: 180.w, height: 24.h),
            SizedBox(height: 16.h),
            // Filter chips
            Row(
              children: [
                SkeletonBox(width: 60.w, height: 32.h, borderRadius: 20),
                SizedBox(width: 6.w),
                SkeletonBox(width: 70.w, height: 32.h, borderRadius: 20),
                SizedBox(width: 6.w),
                SkeletonBox(width: 80.w, height: 32.h, borderRadius: 20),
                SizedBox(width: 6.w),
                SkeletonBox(width: 65.w, height: 32.h, borderRadius: 20),
              ],
            ),
            SizedBox(height: 16.h),
            // Cards
            for (int i = 0; i < 5; i++) ...[
              SkeletonBox(width: double.infinity, height: 72.h, borderRadius: 14),
              SizedBox(height: 8.h),
            ],
          ],
        ),
      ),
    );
  }
}

/// Profile skeleton.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            SkeletonBox(width: 100.w, height: 24.h),
            SizedBox(height: 24.h),
            // Avatar
            Center(
              child: Column(
                children: [
                  SkeletonBox(width: 96.w, height: 96.w, borderRadius: 48),
                  SizedBox(height: 14.h),
                  SkeletonBox(width: 140.w, height: 22.h),
                  SizedBox(height: 6.h),
                  SkeletonBox(width: 180.w, height: 14.h),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            // Stats
            SkeletonBox(width: double.infinity, height: 56.h, borderRadius: 14),
            SizedBox(height: 24.h),
            // Menu items
            for (int i = 0; i < 6; i++) ...[
              SkeletonBox(width: double.infinity, height: 68.h, borderRadius: 14),
              SizedBox(height: 4.h),
            ],
          ],
        ),
      ),
    );
  }
}

/// Roadmap skeleton.
class RoadmapSkeleton extends StatelessWidget {
  const RoadmapSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chips
            Row(
              children: [
                SkeletonBox(width: 90.w, height: 32.h, borderRadius: 16),
                SizedBox(width: 8.w),
                SkeletonBox(width: 110.w, height: 32.h, borderRadius: 16),
              ],
            ),
            SizedBox(height: 16.h),
            // Phase cards
            for (int i = 0; i < 3; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      SkeletonBox(width: 24.w, height: 24.w, borderRadius: 12),
                      SizedBox(height: 4.h),
                      SkeletonBox(width: 2.w, height: 100.h, borderRadius: 1),
                    ],
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: SkeletonBox(
                      width: double.infinity,
                      height: 120.h,
                      borderRadius: 14,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
            ],
          ],
        ),
      ),
    );
  }
}
