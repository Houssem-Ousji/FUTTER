import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/partner.dart';
import '../../services/partner_repository.dart';
import '../../widgets/common.dart';

/// Référencement d'une université partenaire (administrateurs uniquement).
class PartnerEditorScreen extends ConsumerStatefulWidget {
  const PartnerEditorScreen({super.key, this.partnerId});

  final String? partnerId;

  @override
  ConsumerState<PartnerEditorScreen> createState() => _PartnerEditorScreenState();
}

class _PartnerEditorScreenState extends ConsumerState<PartnerEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController();
  final _website = TextEditingController();
  final _email = TextEditingController();
  final _description = TextEditingController();
  bool _loading = false;
  bool _saving = false;

  bool get _isEditing => widget.partnerId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    await guard(() async {
      final p = await ref.read(partnerRepositoryProvider).getPartner(widget.partnerId!);
      if (p == null) throw StateError("Cette université n'existe plus.");
      _name.text = p.name;
      _city.text = p.city;
      _country.text = p.country;
      _website.text = p.website;
      _email.text = p.contactEmail;
      _description.text = p.description;
    });
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [_name, _city, _country, _website, _email, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final partner = Partner(
      id: widget.partnerId ?? '',
      name: _name.text.trim(),
      city: _city.text.trim(),
      country: _country.text.trim(),
      website: _website.text.trim(),
      contactEmail: _email.text.trim(),
      description: _description.text.trim(),
    );
    setState(() => _saving = true);
    String? id;
    final ok = await guard(
      () async {
        id = await ref.read(partnerRepositoryProvider).savePartner(partner, id: widget.partnerId);
      },
      success: _isEditing ? 'Université mise à jour' : 'Université ajoutée',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    if (_isEditing) {
      popOrHome(context);
    } else {
      context.pushReplacement('/partner/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(currentUserProvider).valueOrNull?.isAdmin ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? "Modifier l'université" : 'Nouvelle université')),
      body: !isAdmin
          ? const EmptyState(icon: Icons.lock_outline, message: 'Réservé aux administrateurs.')
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: Gaps.screenPadding,
                    children: [
                      const _FormSection('Identité'),
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: "Nom de l'université"),
                        validator: (v) => validateRequired(v, minLength: 2),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _city,
                              decoration: const InputDecoration(labelText: 'Ville'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _country,
                              decoration: const InputDecoration(labelText: 'Pays'),
                            ),
                          ),
                        ],
                      ),
                      const _FormSection('Contact'),
                      TextFormField(
                        controller: _website,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(labelText: 'Site web'),
                        validator: validateOptionalUrl,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'E-mail de contact'),
                        validator: validateOptionalEmail,
                      ),
                      const _FormSection('Présentation'),
                      TextFormField(
                        controller: _description,
                        minLines: 4,
                        maxLines: null,
                        maxLength: 3000,
                        decoration: const InputDecoration(
                          labelText: 'Présentation',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      LoadingButton(label: 'Enregistrer', loading: _saving, onPressed: _save),
                    ],
                  ),
                ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
