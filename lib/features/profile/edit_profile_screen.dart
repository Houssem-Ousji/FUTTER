import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/app_user.dart';
import '../../services/user_repository.dart';
import '../../widgets/common.dart';

class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le profil')),
      body: AsyncValueWidget(
        value: user,
        data: (me) => me == null
            ? const EmptyState(icon: Icons.person_off_outlined, message: 'Profil introuvable.')
            : _EditProfileForm(user: me),
      ),
    );
  }
}

class _EditProfileForm extends ConsumerStatefulWidget {
  const _EditProfileForm({required this.user});

  final AppUser user;

  @override
  ConsumerState<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<_EditProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.displayName);
  late final _university = TextEditingController(text: widget.user.university);
  late final _field = TextEditingController(text: widget.user.fieldOfStudy);
  late final _bio = TextEditingController(text: widget.user.bio);
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _university, _field, _bio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await guard(
      () => ref.read(userRepositoryProvider).updateProfile(
            widget.user.id,
            displayName: _name.text.trim(),
            university: _university.text.trim(),
            fieldOfStudy: _field.text.trim(),
            bio: _bio.text.trim(),
          ),
      success: 'Profil mis à jour',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) popOrHome(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        padding: Gaps.screenPadding,
        children: [
          Center(child: UserAvatar(name: widget.user.displayName, radius: 40)),
          Gaps.lg,
          Text('Identité', style: theme.textTheme.titleMedium),
          Gaps.sm,
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nom complet',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) => validateRequired(v, minLength: 2),
          ),
          Gaps.lg,
          Text('Parcours', style: theme.textTheme.titleMedium),
          Gaps.sm,
          TextFormField(
            controller: _university,
            decoration: const InputDecoration(
              labelText: 'Établissement',
              prefixIcon: Icon(Icons.account_balance_outlined),
            ),
          ),
          Gaps.md,
          TextFormField(
            controller: _field,
            decoration: const InputDecoration(
              labelText: 'Filière / discipline',
              prefixIcon: Icon(Icons.school_outlined),
            ),
          ),
          Gaps.lg,
          Text('À propos', style: theme.textTheme.titleMedium),
          Gaps.sm,
          TextFormField(
            controller: _bio,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Présentation',
              alignLabelWithHint: true,
            ),
          ),
          Gaps.sm,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: theme.colorScheme.outline),
              Gaps.sm,
              Expanded(
                child: Text(
                  'Les publications existantes conservent le nom affiché au moment de leur création.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            ],
          ),
          Gaps.lg,
          LoadingButton(label: 'Enregistrer', loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
