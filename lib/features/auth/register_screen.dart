import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/app_user.dart';
import '../../services/auth_repository.dart';
import '../../widgets/common.dart';
import 'auth_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _university = TextEditingController();
  final _field = TextEditingController();
  UserRole _role = UserRole.student;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm, _university, _field]) {
      c.dispose();
    }
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
    String? error;
    try {
      await ref.read(authRepositoryProvider).register(
            displayName: _name.text.trim(),
            email: _email.text,
            password: _password.text,
            role: _role,
            university: _university.text.trim(),
            fieldOfStudy: _field.text.trim(),
          );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final passwordToggle = IconButton(
      tooltip: _obscure ? 'Afficher les mots de passe' : 'Masquer les mots de passe',
      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      onPressed: () => setState(() => _obscure = !_obscure),
    );
    return AuthShell(
      appBar: AppBar(
        title: const Text('Créer un compte'),
        leading: BackButton(onPressed: () => context.go('/login')),
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthHeader(
                subtitle: 'Rejoignez la communauté EduShare',
                compact: true,
              ),
              Gaps.lg,
              AuthErrorBanner(message: _error, onDismiss: _clearError),
              Semantics(
                header: true,
                child: Text('Je suis :', style: theme.textTheme.titleMedium),
              ),
              Gaps.sm,
              SegmentedButton<UserRole>(
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(0, 48)),
                ),
                segments: [
                  for (final role in UserRole.selfAssignable)
                    ButtonSegment(value: role, label: Text(role.label)),
                ],
                selected: {_role},
                onSelectionChanged:
                    _loading ? null : (s) => setState(() => _role = s.first),
              ),
              Gaps.lg,
              TextFormField(
                controller: _name,
                autofocus: true,
                readOnly: _loading,
                textCapitalization: TextCapitalization.words,
                keyboardType: TextInputType.name,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clearError(),
                decoration: const InputDecoration(
                  labelText: 'Nom complet',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => validateRequired(v, minLength: 2),
              ),
              Gaps.md,
              TextFormField(
                controller: _email,
                readOnly: _loading,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
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
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  _clearError();
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: 'Mot de passe (8 caractères min.)',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: passwordToggle,
                ),
                validator: validatePassword,
              ),
              PasswordStrengthMeter(password: _password.text),
              Gaps.md,
              TextFormField(
                controller: _confirm,
                readOnly: _loading,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clearError(),
                decoration: const InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                ),
                validator: (v) =>
                    v == _password.text ? null : 'Les mots de passe ne correspondent pas',
              ),
              Gaps.md,
              TextFormField(
                controller: _university,
                readOnly: _loading,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.organizationName],
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clearError(),
                decoration: const InputDecoration(
                  labelText: 'Établissement',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
                validator: validateRequired,
              ),
              Gaps.md,
              TextFormField(
                controller: _field,
                readOnly: _loading,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onChanged: (_) => _clearError(),
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.menu_book_outlined),
                  labelText: _role == UserRole.teacher
                      ? 'Discipline enseignée'
                      : "Filière / domaine d'études",
                ),
              ),
              Gaps.lg,
              LoadingButton(label: "S'inscrire", loading: _loading, onPressed: _submit),
              Gaps.sm,
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: _loading ? null : () => context.go('/login'),
                child: const Text('Déjà un compte ? Se connecter'),
              ),
              Gaps.sm,
              Text(
                'Les comptes administrateur et partenaire universitaire sont attribués '
                'par un administrateur de la plateforme.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
