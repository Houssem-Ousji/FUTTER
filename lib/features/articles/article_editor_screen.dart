import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/article.dart';
import '../../services/article_repository.dart';
import '../../widgets/common.dart';

/// Création (articleId null) ou modification d'une publication.
class ArticleEditorScreen extends ConsumerStatefulWidget {
  const ArticleEditorScreen({super.key, this.articleId});

  final String? articleId;

  @override
  ConsumerState<ArticleEditorScreen> createState() =>
      _ArticleEditorScreenState();
}

class _ArticleEditorScreenState extends ConsumerState<ArticleEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _tags = TextEditingController();
  final _link = TextEditingController();
  ArticleCategory _category = ArticleCategory.article;
  bool _loading = false;
  bool _saving = false;

  /// Vrai dès que l'utilisateur a modifié un champ (confirmation avant de quitter).
  bool _dirty = false;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _confirmLeave() async {
    final leave = await confirmDialog(
      context,
      title: 'Quitter sans enregistrer ?',
      message: 'Votre saisie sera perdue.',
      confirmLabel: 'Quitter',
    );
    if (!leave || !mounted) return;
    setState(() => _dirty = false);
    popOrHome(context);
  }

  bool get _isEditing => widget.articleId != null;

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
      final article = await ref
          .read(articleRepositoryProvider)
          .getArticle(widget.articleId!);
      if (article == null) throw StateError("Cette publication n'existe plus.");
      _title.text = article.title;
      _content.text = article.content;
      _tags.text = article.tags.join(', ');
      _link.text = article.attachmentUrl;
      _category = article.category;
    });
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [_title, _content, _tags, _link]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null) {
      showMessage('Profil en cours de chargement, réessayez dans un instant.');
      return;
    }
    final draft = ArticleDraft(
      title: _title.text.trim(),
      content: _content.text.trim(),
      category: _category,
      tags: _tags.text
          .split(',')
          .map((t) => t.trim().replaceAll('#', ''))
          .where((t) => t.isNotEmpty)
          .toSet()
          .take(10)
          .toList(),
      attachmentUrl: _link.text.trim(),
    );

    setState(() => _saving = true);
    final repo = ref.read(articleRepositoryProvider);
    String? newId;
    final ok = await guard(
      () async {
        if (_isEditing) {
          await repo.update(widget.articleId!, draft);
        } else {
          newId = await repo.create(me, draft);
        }
      },
      success: _isEditing ? 'Publication mise à jour' : 'Publication en ligne',
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _dirty = false;
    });
    if (!ok) return;
    if (newId != null) {
      context.pushReplacement('/article/$newId');
    } else {
      popOrHome(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing ? 'Modifier la publication' : 'Nouvelle publication',
          ),
        ),
        body: _loading
            ? const SkeletonList(count: 4, itemHeight: 64)
            : Form(
                key: _formKey,
                onChanged: _markDirty,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      padding: Gaps.screenPadding,
                      children: [
                        DropdownButtonFormField<ArticleCategory>(
                          initialValue: _category,
                          decoration: const InputDecoration(
                            labelText: 'Type de contenu',
                          ),
                          items: [
                            for (final c in ArticleCategory.values)
                              DropdownMenuItem(value: c, child: Text(c.label)),
                          ],
                          onChanged: (c) =>
                              setState(() => _category = c ?? _category),
                        ),
                        Gaps.md,
                        TextFormField(
                          controller: _title,
                          maxLength: 200,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(labelText: 'Titre'),
                          validator: (v) => validateRequired(v, minLength: 3),
                        ),
                        Gaps.sm,
                        TextFormField(
                          controller: _content,
                          minLines: 10,
                          maxLines: null,
                          maxLength: 50000,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Contenu',
                            alignLabelWithHint: true,
                          ),
                          validator: validateRequired,
                        ),
                        Gaps.sm,
                        TextFormField(
                          controller: _tags,
                          decoration: const InputDecoration(
                            labelText: 'Mots-clés (séparés par des virgules)',
                            hintText: 'algorithmique, examen, L2',
                          ),
                        ),
                        Gaps.md,
                        TextFormField(
                          controller: _link,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'Lien vers un document (facultatif)',
                            hintText: 'https://…',
                          ),
                          validator: validateOptionalUrl,
                        ),
                        Gaps.lg,
                        LoadingButton(
                          label: _isEditing ? 'Enregistrer' : 'Publier',
                          loading: _saving,
                          onPressed: _save,
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
