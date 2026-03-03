import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';

class FirstPage extends StatelessWidget {
  const FirstPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Center(
          child: Text(
            'Joblyx',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/images/first_page_icon.svg',
                width: 280.w,
                height: 280.h,
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: FilledButton.icon(
                  onPressed: () {}, 
                  label: Text(
                    t.t("first_page.continue_with_email"),
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface),
                  ),
                  icon: SvgPicture.asset(
                    'assets/images/email_icon.svg',
                    width: 28.w,
                    height: 28.h,
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: OutlinedButton.icon(
                  onPressed: () {}, 
                  label: Text(
                    t.t("first_page.continue_with_linkedin"),
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface),
                  ),
                  icon: SvgPicture.asset(
                    'assets/images/linkedin_logo.svg',
                    width: 26.w,
                    height: 26.h,
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Text.rich(
                        TextSpan(
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 12.sp,
                          ),
                          children: [
                            TextSpan(
                                text: t.t('first_page.legal_prefix')),
                            TextSpan(
                              text: t.t('first_page.terms_of_use'),
                              style: TextStyle(
                                color: cs.primary,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.bold,
                                decorationColor: cs.primary,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => launchUrl(
                                      Uri.parse(
                                          'https://joblyx.com/conditions-utilisation'),
                                      mode: LaunchMode.externalApplication,
                                    ),
                            ),
                            TextSpan(
                                text: t.t('first_page.legal_separator')),
                            TextSpan(
                              text: t.t('first_page.privacy_policy'),
                              style: TextStyle(
                                color: cs.primary,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.bold,
                                decorationColor: cs.primary,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => launchUrl(
                                      Uri.parse(
                                          'https://joblyx.com/politiques-confidentialit%C3%A9'),
                                      mode: LaunchMode.externalApplication,
                                    ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
          
            ],
          ),
        ),
      ),
      
    );
  }
}