const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

String formatShortDate(DateTime d) =>
    '${_months[d.month - 1].substring(0, 3)} ${d.day}, ${d.year}';

String formatRemaining(Duration r) {
  if (r.isNegative || r == Duration.zero) return 'Ready to open';
  if (r.inDays >= 1) {
    return 'Opens in ${r.inDays} ${r.inDays == 1 ? 'day' : 'days'}';
  }
  if (r.inHours >= 1) return 'Opens in ${r.inHours} h';
  return 'Opens in ${r.inMinutes} min';
}
