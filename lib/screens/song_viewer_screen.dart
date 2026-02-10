import 'package:flutter/material.dart';
import 'dart:convert';
import '../main.dart';
import '../models/song.dart';
import '../models/chord_models.dart';
import '../services/music_service.dart';
import '../services/supabase_service.dart';
    // Safety check for empty lines or weird positions
import '../widgets/drag_drop_chord_editor.dart';
import '../widgets/lyric_line_with_chords.dart';
import '../widgets/background_wrapper.dart';

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
  double _fontSize = 16.0;
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
    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/images/mac.jpg', height: 28, width: 28, fit: BoxFit.cover),
              ),
              const SizedBox(width: 8),
              Flexible(child: Text(
                _song?.title ?? 'Carregando...',
                overflow: TextOverflow.ellipsis,
              )),
            ],
          ),
        actions: [
          IconButton(
            icon: Icon(
              CifrasApp.of(context)?.isDarkMode == true
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () => CifrasApp.of(context)?.toggleTheme(),
            tooltip: 'Alternar tema',
          ),
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
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[900]
                            : Colors.grey[100],
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Transposition controls
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Tom:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            width: 300,
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey.shade800
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade600
                                    : Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.remove_circle_outline, size: 20,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                  onPressed: () => setState(() => _transposeValue--),
                                  tooltip: 'Diminuir tom (-1)',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      '${_transposeValue > 0 ? '+' : ''}$_transposeValue',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _transposeValue == 0 
                                            ? (Theme.of(context).brightness == Brightness.dark
                                                ? Colors.grey.shade300
                                                : Colors.grey.shade800)
                                            : Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.add_circle_outline, size: 20,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                  onPressed: () => setState(() => _transposeValue++),
                                  tooltip: 'Aumentar tom (+1)',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                Container(
                                  height: 20,
                                  width: 1,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade300,
                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                                TextButton.icon(
                                  onPressed: _transposeValue == 0 ? null : () => setState(() => _transposeValue = 0),
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Resetar', style: TextStyle(fontSize: 13)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red.shade400,
                                    disabledForegroundColor: Colors.grey.shade300,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Font size controls
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            width: 200,
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey.shade800
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade600
                                    : Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.text_decrease, size: 18,
                                    color: _fontSize <= 10
                                        ? Colors.grey.shade400
                                        : (Theme.of(context).brightness == Brightness.dark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade700),
                                  ),
                                  onPressed: _fontSize <= 10
                                      ? null
                                      : () => setState(() => _fontSize -= 2),
                                  tooltip: 'Diminuir fonte',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      'Aa ${_fontSize.toInt()}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.text_increase, size: 18,
                                    color: _fontSize >= 28
                                        ? Colors.grey.shade400
                                        : (Theme.of(context).brightness == Brightness.dark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade700),
                                  ),
                                  onPressed: _fontSize >= 28
                                      ? null
                                      : () => setState(() => _fontSize += 2),
                                  tooltip: 'Aumentar fonte',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
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
      ),
    );
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
        final viewportWidth = constraints.maxWidth;
        final needsHorizontalScroll = maxLineWidth > viewportWidth;
        // Horizontal padding for centering when content is narrower than viewport
        final horizontalPadding = needsHorizontalScroll
            ? 0.0
            : (viewportWidth - maxLineWidth) / 2;

        Widget content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(lines.length, (index) {
            final line = lines[index];
            final chordLine = displayChords.firstWhere(
              (l) => l.lineIndex == index,
              orElse: () => ChordLine(lineIndex: index, chords: []),
            );
            
            return LyricLineWithChords(
              lineIndex: index,
              lyricText: line,
              chordLine: chordLine,
              readOnly: true,
              layoutWidth: maxLineWidth,
              fontSize: _fontSize,
            );
          }),
        );

        if (needsHorizontalScroll) {
          // Content is wider than viewport: allow horizontal scroll
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: maxLineWidth,
              child: content,
            ),
          );
        } else {
          // Content fits: center it with padding
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: content,
          );
        }
      },
    );
  }

  double _calculateMaxLineWidth(List<String> lines, BuildContext context) {
    double maxWidth = 0.0;
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: _fontSize,
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
