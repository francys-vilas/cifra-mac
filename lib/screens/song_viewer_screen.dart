import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/song.dart';
import '../models/chord_models.dart';
import '../services/music_service.dart';
import '../services/supabase_service.dart';
    // Safety check for empty lines or weird positions
import '../widgets/drag_drop_chord_editor.dart';
import '../widgets/lyric_line_with_chords.dart';

class SongViewerScreen extends StatefulWidget {
  final String artist;
  final String title;
  final bool isTest;
  final Song? existingSong; // Pass full object if already loaded (e.g. from DB)

  const SongViewerScreen({
    super.key,
    required this.artist,
    required this.title,
    this.isTest = false,
    this.existingSong,
  });

  @override
  State<SongViewerScreen> createState() => _SongViewerScreenState();
}

class _SongViewerScreenState extends State<SongViewerScreen> {
  final MusicService _musicService = MusicService();
  final SupabaseService _supabaseService = SupabaseService();
  Song? _song;
  int _transposeValue = 0;
  bool _isLoading = true;
  bool _isEditing = false;
  late TextEditingController _textController;
  
  // State for structured chords
  List<ChordLine> _chordLines = [];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    if (widget.existingSong != null) {
      _song = widget.existingSong;
      _textController.text = _song!.lyrics ?? '';
      _isEditing = false;
      _isLoading = false;
      
      // Load chords if present
      if (_song!.chordData != null) {
        // Parse structured data
        // We'll need to parse this JSON string back to List<ChordLine>
        // For now, let's assume strict structure or use parser
        // We need to implement ChordDataParser.fromJson or similar if not exists
        // Actually, let's defer parsing to _buildLyricsView or a helper
        // But for Editing, we need _chordLines.
        // Let's implement a simple parser here or update ChordDataParser
        _loadChordData(_song!.chordData!);
      } else if (_song!.chords != null) {
         // Legacy inline chords
         _chordLines = ChordDataParser.parseInlineChords(_song!.chords!);
      }
    } else {
      _loadSong();
    }
  }

  void _loadChordData(String jsonString) {
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      _chordLines = list.map((item) => ChordLine.fromMap(item)).toList();
    } catch (e) {
      debugPrint('Error parsing chord data: $e');
      _chordLines = [];
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _loadSong() async {
    if (widget.isTest) {
      // Mock song for testing
      setState(() {
        _song = Song(
          id: 'test_1',
          title: 'Exemplo de Cifra',
          artist: 'Teste',
          lyrics: '''
Numa folha qualquer
Eu desenho um sol amarelo
E com cinco ou seis retas
É fácil fazer um castelo...
''',
          chordData: jsonEncode({
            'lineIndex': 0,
            'chords': [
              {'position': 0, 'chord': 'G'},
              {'position': 10, 'chord': 'D'}
            ]
          }), // Simplified mock data
        );
        _textController.text = _song!.lyrics ?? '';
        
        // Mock parsing for test
        if (_song!.chordData != null) {
          // Just for test, ideally parse full JSON list
           _chordLines = ChordDataParser.parseInlineChords('''
[G]       [D]
Numa folha qualquer
      [Em]         [C]
Eu desenho um sol amarelo
[G]         [D]
E com cinco ou seis retas
    [Em]       [C]
É fácil fazer um castelo...
''');
           // Override lyrics for test to match standard format
           _textController.text = '''
Numa folha qualquer
Eu desenho um sol amarelo
E com cinco ou seis retas
É fácil fazer um castelo...
''';
        }
        
        _isLoading = false;
      });
      return;
    }

    final song = await _musicService.getSongDetails(widget.artist, widget.title);
    
    setState(() {
      _song = song;
      if (song != null) {
        _textController.text = song.lyrics ?? '';
        
        // Initialize structured chords
        if (song.chordData != null && song.chordData!.isNotEmpty) {
          try {
            final List<dynamic> decoded = jsonDecode(song.chordData!);
            _chordLines = decoded.map((json) => ChordLine.fromJson(json)).toList();
          } catch (e) {
            print('Error parsing chordData: $e');
            _chordLines = [];
          }
        } else if (song.lyrics != null && song.lyrics!.contains('[')) {
          // Fallback: parse inline chords if no structured data
          _chordLines = ChordDataParser.parseInlineChords(song.lyrics!);
          
          // Clean up lyrics in controller (remove inline chords for clean display/editing)
          // Actually, we should keep the original text with inline chords if we revert?
          // For now, let's keep _textController as just clean text for the new editor
          // But wait, parseInlineChords extracts chords but we need clean lyrics for the editor rows
        }
      }
      _isLoading = false;
    });
  }

  void _saveEdits() async {
    if (_song != null) {
      // Serialize chord lines to JSON
      final chordDataJson = jsonEncode(
        _chordLines.map((l) => l.toJson()).toList()
      );
      
      _song = Song(
        id: _song!.id,
        title: _song!.title,
        artist: _song!.artist,
        lyrics: _textController.text,
        url: _song!.url,
        chordData: chordDataJson,
        chords: _song!.chords,
      );

      // Auto-save to Supabase
      try {
        await _supabaseService.saveSong(_song!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Salvo automaticamente!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao salvar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_song?.title ?? 'Carregando...'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _saveEdits();
              } else {
                setState(() => _isEditing = true);
              }
            },
            tooltip: _isEditing ? 'Salvar' : 'Editar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _song == null
              ? const Center(child: Text('Música não encontrada.'))
              : _isEditing 
                ? DragDropChordEditor(
                    lyrics: _textController.text, // Must be clean text
                    chordLines: _chordLines,
                    onChordsChanged: (newLines) {
                      setState(() => _chordLines = newLines);
                    },
                  )
                : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      color: Colors.grey[200],
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () => setState(() => _transposeValue--),
                          ),
                          Text(
                            'Tom: ${_transposeValue > 0 ? '+' : ''}$_transposeValue',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => setState(() => _transposeValue++),
                          ),
                          const SizedBox(width: 16),
                          TextButton(
                            onPressed: () => setState(() => _transposeValue = 0),
                            child: const Text('Resetar'),
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: _buildLyricsView(),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  void _onChordAdded(int lineIndex, int position, Map<String, dynamic> data) {
    setState(() {
      // Find or create the chord line
      var line = _chordLines.firstWhere(
        (l) => l.lineIndex == lineIndex,
        orElse: () {
          final newLine = ChordLine(lineIndex: lineIndex, chords: []);
          _chordLines.add(newLine);
          return newLine;
        },
      );

      // Remove existing chord at same position if any
      line.chords.removeWhere((c) => c.position == position);

      // Add new chord
      line.chords.add(ChordPosition(
        position: position,
        chord: data['chord'] ?? '?',
      ));
    });
  }

  void _onChordRemoved(int lineIndex, int position) {
    setState(() {
      final line = _chordLines.firstWhere(
        (l) => l.lineIndex == lineIndex,
        orElse: () => ChordLine(lineIndex: lineIndex, chords: []),
      );
      
      line.chords.removeWhere((c) => c.position == position);
    });
  }

  Widget _buildLyricsView() {

    // Visualization mode using the new structured data
    
    // Apply transposition
    final displayChords = _transposeValue != 0
        ? ChordDataParser.transposeChordLines(_chordLines, _transposeValue)
        : _chordLines;

    final lines = _textController.text.split('\n');
    final maxLineWidth = _calculateMaxLineWidth(lines, context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lines.length,
            itemBuilder: (context, index) {
              final line = lines[index];
              final chordLine = displayChords.firstWhere(
                (l) => l.lineIndex == index,
                orElse: () => ChordLine(lineIndex: index, chords: []),
              );
              
              return LyricLineWithChords(
                lineIndex: index,
                lyricText: line,
                chordLine: chordLine,
                onChordAdded: _isEditing ? _onChordAdded : null,
                onChordRemoved: _isEditing ? _onChordRemoved : null,
                readOnly: !_isEditing,
                layoutWidth: maxLineWidth,
              );
            },
          ),
        );
      },
    );
  }

  double _calculateMaxLineWidth(List<String> lines, BuildContext context) {
    double maxWidth = 0.0;
    const style = TextStyle(
      fontFamily: 'monospace',
      fontSize: 16,
      height: 1.0,
    );
    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (var line in lines) {
      textPainter.text = TextSpan(text: line.trimRight(), style: style);
      textPainter.layout();
      if (textPainter.width > maxWidth) {
        maxWidth = textPainter.width;
      }
    }
    
    // Add a small buffer for safety
    return maxWidth + 20.0;
  }
} // End of class
