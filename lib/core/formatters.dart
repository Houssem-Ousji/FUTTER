import 'package:intl/intl.dart';

String formatDate(DateTime date) => DateFormat('d MMM yyyy', 'fr_FR').format(date);

String formatDateTime(DateTime date) =>
    DateFormat("d MMM yyyy 'à' HH:mm", 'fr_FR').format(date);

String formatMonth(DateTime date) => DateFormat('MMM', 'fr_FR').format(date);

String timeAgo(DateTime date, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(date);
  if (diff.inMinutes < 1) return "à l'instant";
  if (diff.inHours < 1) return 'il y a ${diff.inMinutes} min';
  if (diff.inDays < 1) return 'il y a ${diff.inHours} h';
  if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
  return formatDate(date);
}
