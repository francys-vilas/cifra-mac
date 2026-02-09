class ChordTransposer {
  static const List<String> _notesSharp = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];
  static const List<String> _notesFlat = [
    'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'
  ];

  static String transposeChord(String chord, int semitones) {
    // Regex to separate the note from the rest of the chord (m, 7, sus4, etc.)
    final regex = RegExp(r'^([A-G][#b]?)(.*)$');
    final match = regex.firstMatch(chord);

    if (match == null) return chord;

    String note = match.group(1)!;
    String suffix = match.group(2)!;

    int index = _notesSharp.indexOf(note);
    if (index == -1) {
      index = _notesFlat.indexOf(note);
    }

    if (index == -1) return chord;

    int newIndex = (index + semitones) % 12;
    if (newIndex < 0) newIndex += 12;

    // Defaulting to sharps for simplicity, or we could detect based on input
    return _notesSharp[newIndex] + suffix;
  }

  static String transposeLyrics(String text, int semitones) {
    if (semitones == 0) return text;

    // Matches both [c]Chord[/c] and [Chord] formats
    // Group 1: inner content of [c]...[/c]
    // Group 2: inner content of [...]
    final regex = RegExp(r'\[c\](.*?)\[/c\]|\[([A-G][#b]?[^\]]*?)\]');
    
    return text.replaceAllMapped(regex, (match) {
      final chord = match.group(1) ?? match.group(2)!;
      final transposed = transposeChord(chord, semitones);
      
      // Preserve the original format
      if (match.group(1) != null) {
        return '[c]$transposed[/c]';
      } else {
        return '[$transposed]';
      }
    });
  }
}
