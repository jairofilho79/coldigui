/// Formata posição de áudio como `m:ss`.
String formatAudioFlagTime(Duration d) {
  final totalSeconds = d.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String audioFlagTooltipLabel(String label, Duration position) {
  final time = formatAudioFlagTime(position);
  if (label.trim().isEmpty) return time;
  return '$label ($time)';
}
