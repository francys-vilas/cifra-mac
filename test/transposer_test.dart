import 'package:flutter_test/flutter_test.dart';
import 'package:cifras/utils/chord_transposer.dart';

void main() {
  group('ChordTransposer Tests', () {
    test('Transpose simple chords', () {
      expect(ChordTransposer.transposeChord('C', 1), 'C#');
      expect(ChordTransposer.transposeChord('E', 1), 'F');
      expect(ChordTransposer.transposeChord('B', 1), 'C');
      expect(ChordTransposer.transposeChord('G', -1), 'F#');
    });

    test('Transpose minor and seventh chords', () {
      expect(ChordTransposer.transposeChord('Am', 2), 'Bm');
      expect(ChordTransposer.transposeChord('D7', 1), 'D#7');
      expect(ChordTransposer.transposeChord('F#m7', -1), 'Fm7');
    });

    test('Transpose lyrics with tags', () {
      const lyrics = 'No [c]C[/c] eu sou feliz, no [c]G[/c] eu canto.';
      final transposed = ChordTransposer.transposeLyrics(lyrics, 1);
      expect(transposed, 'No [c]C#[/c] eu sou feliz, no [c]G#[/c] eu canto.');
    });

    test('Transpose lyrics with bracket format', () {
      const lyrics = 'No [C] eu sou feliz, no [G] eu canto.';
      final transposed = ChordTransposer.transposeLyrics(lyrics, 1);
      expect(transposed, 'No [C#] eu sou feliz, no [G#] eu canto.');
    });
  });
}
