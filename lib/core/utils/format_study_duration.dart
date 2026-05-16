/// O‘zbekcha o‘qish vaqti (soniya → matn).
String formatStudyDurationUz(int totalSeconds) {
  final sec = totalSeconds < 0 ? 0 : totalSeconds;
  if (sec < 60) {
    return '$sec sekund';
  }
  if (sec < 3600) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m minut $s sekund';
  }
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  return '$h soat $m minut';
}
