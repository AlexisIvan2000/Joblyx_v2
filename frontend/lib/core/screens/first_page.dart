import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/authentication/data/auth_service.dart';
import 'package:frontend/features/authentication/data/auth_storage.dart';
import 'package:url_launcher/url_launcher.dart';

const _linkedInClientId = String.fromEnvironment(
  'LINKEDIN_CLIENT_ID',
  defaultValue: '78ph11ioe6bh13',
);
const _linkedInRedirectUri = 'https://api.joblyx.com/auth/linkedin/callback';
final _linkedInAuthUrl =
    'https://www.linkedin.com/oauth/v2/authorization'
    '?response_type=code'
    '&client_id=$_linkedInClientId'
    '&redirect_uri=${Uri.encodeComponent(_linkedInRedirectUri)}'
    '&scope=openid%20profile%20email';

class FirstPage extends StatefulWidget {
  const FirstPage({super.key});

  @override
  State<FirstPage> createState() => _FirstPageState();
}

class _FirstPageState extends State<FirstPage> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;
  bool _isLoading = false;
  bool _linkHandled = false;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    // Écouter les liens entrants quand l'app est déjà ouverte
    _linkSub = _appLinks.uriLinkStream.listen(_handleDeepLink);
    // Vérifier si l'app a été ouverte via un deep link (cold start ou resume)
    _checkInitialLink();
  }

  Future<void> _checkInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      // Ne traiter que si c'est un vrai callback LinkedIn frais
      // (pas un intent recyclé après logout)
      if (uri != null && !_linkHandled) {
        final hasTokens = await AuthStorage().hasTokens();
        if (!hasTokens) _handleDeepLink(uri);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.scheme != 'joblyx' || uri.host != 'auth') return;
    if (_linkHandled) return;
    _linkHandled = true;

    final error = uri.queryParameters['error'];
    if (error != null) {
      if (mounted) {
        AppSnackbar.error(context, 'LinkedIn authentication failed');
      }
      setState(() => _isLoading = false);
      return;
    }

    final accessToken = uri.queryParameters['access_token'];
    final refreshToken = uri.queryParameters['refresh_token'];
    if (accessToken == null || refreshToken == null) return;

    await AuthService().saveLinkedInTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    if (mounted) context.go('/');
  }

  void _launchLinkedIn() {
    _linkHandled = false;
    setState(() => _isLoading = true);
    launchUrl(
      Uri.parse(_linkedInAuthUrl),
      mode: LaunchMode.externalApplication,
    );
  }

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
            style: theme.textTheme.headlineLarge?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
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
                  onPressed: () => context.push('/login'),
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
                  onPressed: _isLoading ? null : _launchLinkedIn,
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