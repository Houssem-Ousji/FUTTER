final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidEmail(String value) => _emailRegex.hasMatch(value.trim());

String? validateEmail(String? value) =>
    value == null || !isValidEmail(value) ? 'Adresse e-mail invalide' : null;

String? validatePassword(String? value) =>
    (value ?? '').length < 8 ? 'Au moins 8 caractères' : null;

String? validateRequired(String? value, {int minLength = 1}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Champ obligatoire';
  if (text.length < minLength) return 'Au moins $minLength caractères';
  return null;
}

String? validateOptionalUrl(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  final ok = uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  return ok ? null : 'Lien invalide (doit commencer par http:// ou https://)';
}

String? validateOptionalEmail(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty || isValidEmail(text) ? null : 'Adresse e-mail invalide';
}
