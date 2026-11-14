import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Enveloppe commune des écrans de connexion / d'inscription : dégradé discret,
/// carte de formulaire sur grand écran, apparition en fondu.
class AuthShell extends StatelessWidget {
  const AuthShell({super.key, required this.child, this.appBar});

  final Widget child;
  final PreferredSizeWidget? appBar;

  static const _wideBreakpoint = 720.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final animate = !MediaQuery.disableAnimationsOf(context);

    Widget content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: wide ? 480 : 420),
      child: child,
    );
    if (wide) {
      content = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Card(
          margin: EdgeInsets.zero,
          color: scheme.surfaceContainerLow,
          child: Padding(padding: const EdgeInsets.all(32), child: child),
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      extendBodyBehindAppBar: false,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.primaryContainer.withValues(alpha: 0.55), scheme.surface],
            stops: const [0, 0.6],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: animate ? 0 : 1, end: 1),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo + nom + accroche. Le [Hero] adoucit le passage connexion <-> inscription.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.subtitle, this.compact = false});

  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final iconSize = compact ? 32.0 : 48.0;
    return Semantics(
      header: true,
      label: 'EduShare. $subtitle',
      child: ExcludeSemantics(
        child: Column(
          children: [
            Hero(
              tag: 'auth-logo',
              child: Container(
                padding: EdgeInsets.all(compact ? 12 : 16),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radius * 2),
                ),
                child: Icon(Icons.school, size: iconSize, color: scheme.onPrimaryContainer),
              ),
            ),
            Gaps.md,
            Text(
              'EduShare',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            Gaps.xs,
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bandeau d'erreur dans le formulaire (annoncé par les lecteurs d'écran).
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message, required this.onDismiss});

  final String? message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Semantics(
                liveRegion: true,
                container: true,
                label: 'Erreur : $message',
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4, right: 4),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: scheme.onErrorContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(message!, style: TextStyle(color: scheme.onErrorContainer)),
                        ),
                        IconButton(
                          tooltip: "Fermer le message d'erreur",
                          icon: Icon(Icons.close, color: scheme.onErrorContainer),
                          onPressed: onDismiss,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Indicateur de robustesse d'un mot de passe (indicatif, ne bloque rien).
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  /// Score de 0 (vide) à 4 (excellent).
  static int score(String p) {
    if (p.isEmpty) return 0;
    var points = 0;
    if (p.length >= 8) points++;
    if (p.length >= 12) points++;
    if (RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p)) points++;
    if (RegExp(r'\d').hasMatch(p)) points++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) points++;
    if (p.length < 8) return 1;
    return points.clamp(1, 4);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = score(password);
    const labels = ['', 'Faible', 'Moyen', 'Bon', 'Excellent'];
    final colors = [
      scheme.outlineVariant,
      scheme.error,
      scheme.tertiary,
      scheme.primary,
      scheme.primary,
    ];
    final hint = password.isEmpty
        ? 'Utilisez 8 caractères minimum, avec majuscules, chiffres et symboles.'
        : 'Robustesse du mot de passe : ${labels[s]}';
    return Semantics(
      liveRegion: true,
      label: hint,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var i = 1; i <= 4; i++) ...[
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= s ? colors[s] : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (i < 4) const SizedBox(width: 4),
                  ],
                ],
              ),
              Gaps.xs,
              Text(
                password.isEmpty ? hint : 'Robustesse : ${labels[s]}',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
