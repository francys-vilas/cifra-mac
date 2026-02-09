import 'package:cifras/utils/chord_transposer.dart';

class ChordPosition {
  final int position; // Posição do caractere na linha
  final String chord; // Nome do acorde (ex: "G", "Am7")
  
  ChordPosition({required this.position, required this.chord});
  
  Map<String, dynamic> toJson() => {'position': position, 'chord': chord};
  Map<String, dynamic> toMap() => toJson();
  
  factory ChordPosition.fromJson(Map<String, dynamic> json) => 
    ChordPosition(position: json['position'] as int, chord: json['chord'] as String);

  factory ChordPosition.fromMap(Map<String, dynamic> map) => ChordPosition.fromJson(map);
}

class ChordLine {
  final int lineIndex; // Índice da linha de letra
  final List<ChordPosition> chords;
  
  ChordLine({required this.lineIndex, required this.chords});
  
  Map<String, dynamic> toJson() => {
    'lineIndex': lineIndex,
    'chords': chords.map((c) => c.toJson()).toList()
  };
  Map<String, dynamic> toMap() => toJson();
  
  factory ChordLine.fromJson(Map<String, dynamic> json) => ChordLine(
    lineIndex: json['lineIndex'] as int,
    chords: (json['chords'] as List).map((c) => ChordPosition.fromJson(c as Map<String, dynamic>)).toList()
  );

  factory ChordLine.fromMap(Map<String, dynamic> map) => ChordLine.fromJson(map);
}

class ChordDataParser {
  // Converte de "[G]texto [D]outro" para formato estruturado
  static List<ChordLine> parseInlineChords(String text) {
    final lines = text.split('\n');
    final List<ChordLine> chordLines = [];
    
    // Regex para capturar [Acorde] e o resto do texto
    // Captura [c]Acorde[/c] ou [Acorde]
    final regex = RegExp(r'\[c\](.*?)\[/c\]|\[(.*?)\]');
    
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      List<ChordPosition> chords = [];
      int currentLength = 0;
      int lastMatchEnd = 0;
      
      for (final match in regex.allMatches(line)) {
        // Texto antes do acorde
        String textBefore = line.substring(lastMatchEnd, match.start);
        currentLength += textBefore.length;
        
        // O acorde
        String chord = match.group(1) ?? match.group(2) ?? '';
        
        // Adiciona posição do acorde (baseada no texto limpo até agora)
        chords.add(ChordPosition(position: currentLength, chord: chord));
        
        lastMatchEnd = match.end;
      }
      
      if (chords.isNotEmpty) {
        chordLines.add(ChordLine(lineIndex: i, chords: chords));
      }
    }
    
    return chordLines;
  }
  
  // Converte formato estruturado para inline "[G]texto"
  // Esta função é complexa porque precisa reconstruir a string original
  // inserindo os acordes nas posições corretas.
  // ATENÇÃO: Se as posições não baterem com o texto atual (ex: texto mudou),
  // tenta aproximar ou anexa.
  static String toInlineFormat(String lyrics, List<ChordLine> chordLines) {
    final lines = lyrics.split('\n');
    final buffer = StringBuffer();
    
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      
      // Encontrar a linha de acordes correspondente
      final chordLineData = chordLines.firstWhere(
        (cl) => cl.lineIndex == i, 
        orElse: () => ChordLine(lineIndex: i, chords: [])
      );
      
      // Ordenar acordes por posição
      final sortedChords = List<ChordPosition>.from(chordLineData.chords)
        ..sort((a, b) => a.position.compareTo(b.position));
      
      if (sortedChords.isEmpty) {
        buffer.writeln(line);
        continue;
      }
      
      int currentTextPos = 0;
      
      for (final chordPos in sortedChords) {
        // Se a posição for além do tamanho da linha, append no final
        int safePos = chordPos.position;
        if (safePos > line.length) safePos = line.length;
        if (safePos < currentTextPos) safePos = currentTextPos;
        
        // Adiciona texto até a posição do acorde
        buffer.write(line.substring(currentTextPos, safePos));
        
        // Adiciona o acorde no formato inline
        buffer.write('[${chordPos.chord}]');
        
        currentTextPos = safePos;
      }
      
      // Resto da linha
      if (currentTextPos < line.length) {
        buffer.write(line.substring(currentTextPos));
      }
      
      if (i < lines.length - 1) {
        buffer.writeln();
      }
    }
    
    return buffer.toString();
  }
  
  // Aplica transposição nas cifras estruturadas
  static List<ChordLine> transposeChordLines(
    List<ChordLine> chordLines, 
    int semitones
  ) {
    if (semitones == 0) return chordLines;
    
    return chordLines.map((line) {
      return ChordLine(
        lineIndex: line.lineIndex,
        chords: line.chords.map((c) {
          return ChordPosition(
            position: c.position,
            chord: ChordTransposer.transposeChord(c.chord, semitones)
          );
        }).toList()
      );
    }).toList();
  }
}
