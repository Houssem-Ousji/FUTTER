import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../services/auth_repository.dart';
import '../../widgets/common.dart';
import 'auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    // En cas de succès, le routeur redirige automatiquement vers l'accueil.
    String? error;
    try {
      await ref.read(authRepositoryProvider).signIn(_email.text, _password.text);
    } on FirebaseAuthException catch (e) {
      error = authErrorMessage(e);
    } catch (e) {
      error = 'Erreur : $e';
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (!isValidEmail(email)) {
      setState(() => _error =
          'Saisissez votre adresse e-mail pour recevoir le lien de réinitialisation.');
      return;
    }
    setState(() => _error = null);
    await guard(
      () => ref.read(authRepositoryProvider).sendPasswordReset(email),
      success: 'Lien de réinitialisation envoyé à $email',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AuthShell(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthHeader(subtitle: 'Partagez et développez vos connaissances'),
              Gaps.xl,
              Semantics(
                header: true,
                child: Text('Connexion', style: theme.textTheme.titleLarge),
              ),
              Gaps.md,
              AuthErrorBanner(message: _error, onDismiss: _clearError),
              TextFormField(
                controller: _email,
                autofocus: true,
                readOnly: _loading,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username, AutofillHints.email],
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clearError(),
                decoration: const InputDecoration(
                  labelText: 'Adresse e-mail',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: validateEmail,
              ),
              Gaps.md,
              TextFormField(
                controller: _password,
                readOnly: _loading,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onChanged: (_) => _clearError(),
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                    icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: validateRequired,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: _loading ? null : _resetPassword,
                  child: const Text('Mot de passe oublié ?'),
                ),
              ),
              Gaps.sm,
              LoadingButton(label: 'Se connecter', loading: _loading, onPressed: _submit),
              Gaps.lg,
              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'ou',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                const Expanded(child: Divider()),
              ]),
              Gaps.md,
              OutlinedButton(
                onPressed: _loading ? null : () => context.go('/register'),
                child: const Text("Pas encore de compte ? S'inscrire"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
