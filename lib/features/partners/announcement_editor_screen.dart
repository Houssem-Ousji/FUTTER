import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/partner.dart';
import '../../services/partner_repository.dart';
import '../../widgets/common.dart';

/// Publication d'une annonce, d'un événement ou d'une opportunité au nom
/// d'une université partenaire (administrateur ou représentant partenaire).
class AnnouncementEditorScreen extends ConsumerStatefulWidget {
  const AnnouncementEditorScreen({super.key, required this.partnerId});

  final String partnerId;

  @override
  ConsumerState<AnnouncementEditorScreen> createState() => _AnnouncementEditorScreenState();
}

class _AnnouncementEditorScreenState extends ConsumerState<AnnouncementEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _link = TextEditingController();
  AnnouncementType _type = AnnouncementType.announcement;
  DateTime? _date;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _description, _link]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save(Partner partner) async {
    if (!_formKey.currentState!.validate()) return;
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null) return;
    setState(() => _saving = true);
    final ok = await guard(
      () => ref.read(partnerRepositoryProvider).createAnnouncement(
            partner: partner,
            author: me,
            type: _type,
            title: _title.text.trim(),
            description: _description.text.trim(),
            eventDate: _date,
            link: _link.text.trim(),
          ),
      success: 'Annonce publiée',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) popOrHome(context);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final partnerAsync = ref.watch(partnerProvider(widget.partnerId));
    final dateLabel =
        _type == AnnouncementType.opportunity ? 'Date limite' : "Date de l'événement";

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle annonce')),
      body: AsyncValueWidget(
        value: partnerAsync,
        data: (partner) {
          if (partner == null) {
            return const EmptyState(
              icon: Icons.account_balance_outlined,
              message: 'Université introuvable.',
            );
          }
          if (me == null || !me.canPublishFor(partner.id)) {
            return const EmptyState(
              icon: Icons.lock_outline,
              message: 'Seuls les représentants de cette université et les '
                  'administrateurs peuvent publier ici.',
            );
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: Gaps.screenPadding,
              children: [
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                      child: const Icon(Icons.account_balance),
                    ),
                    title: Text('Au nom de : ${partner.name}',
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                ),
                Gaps.md,
                SegmentedButton<AnnouncementType>(
                  segments: [
                    for (final t in AnnouncementType.values)
                      ButtonSegment(value: t, label: Text(t.label)),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _title,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Titre'),
                  validator: (v) => validateRequired(v, minLength: 3),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _description,
                  minLines: 6,
                  maxLines: null,
                  maxLength: 5000,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                  ),
                  validator: validateRequired,
                ),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text(_date == null ? '$dateLabel (facultatif)' : '$dateLabel : ${formatDate(_date!)}'),
                  trailing: _date == null
                      ? null
                      : IconButton(
                          tooltip: 'Retirer la date',
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _date = null),
                        ),
                  onTap: _pickDate,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _link,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: "Lien d'information ou de candidature (facultatif)",
                  ),
                  validator: validateOptionalUrl,
                ),
                const SizedBox(height: 24),
                LoadingButton(
                  label: 'Publier',
                  loading: _saving,
                  onPressed: () => _save(partner),
                ),
                const SizedBox(height: 8),
                Text(
                  'Une notification push est envoyée à tous les membres.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
