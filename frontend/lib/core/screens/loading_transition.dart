import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoadingTransition extends StatefulWidget {
  const LoadingTransition({super.key});

  @override
  State<LoadingTransition> createState() => _LoadingTransitionState();
}

class _LoadingTransitionState  extends State<LoadingTransition>{
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/images/processing.svg',
                width: 280.w,
                height: 280.h,             
              ),
              SizedBox(height: 20.h),
              Text(
                t.t('loading.loading'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          )
        ),
      ),
    );
  }


}