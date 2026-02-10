import 'package:cifras/models/chord_models.dart';
import 'package:cifras/widgets/lyric_line_with_chords.dart';
import 'package:flutter/material.dart';

class DragDropChordEditor extends StatefulWidget {
  final String lyrics;
  final List<ChordLine> chordLines;
  final Function(List<ChordLine>) onChordsChanged;
  
  const DragDropChordEditor({
    super.key,
    required this.lyrics,
    required this.chordLines,
    required this.onChordsChanged,
  });
  
  @override
  State<DragDropChordEditor> createState() => _DragDropChordEditorState();
}

class _DragDropChordEditorState extends State<DragDropChordEditor> {
  late List<ChordLine> _chordLines;
  
  // Custom chord controller
  final TextEditingController _customChordController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    // Create a deep copy manually (simple since it's just data)
    _chordLines = widget.chordLines.map((line) => ChordLine(
      lineIndex: line.lineIndex,
      chords: List.from(line.chords),
    )).toList();
  }
  
  @override
  void dispose() {
    _customChordController.dispose();
    super.dispose();
  }
  
  void _addChord(int lineIndex, int position, Map<String, dynamic> data) {
    setState(() {
      final String chord = data['chord'];
      final int? fromLine = data['fromLine'];
      final int? fromPos = data['fromPos'];

      // If moving from another position, remove it first
      if (fromLine != null && fromPos != null) {
        // Find source line
        final sourceLineIndex = _chordLines.indexWhere((l) => l.lineIndex == fromLine);
        if (sourceLineIndex != -1) {
          _chordLines[sourceLineIndex].chords.removeWhere((c) => c.position == fromPos);
        }
      }

      // Find or create target line
      var lineIndexInList = _chordLines.indexWhere((l) => l.lineIndex == lineIndex);
      
      if (lineIndexInList == -1) {
        _chordLines.add(ChordLine(lineIndex: lineIndex, chords: []));
        lineIndexInList = _chordLines.length - 1;
      }
      
      final line = _chordLines[lineIndexInList];
      
      // Remove existing at target position (replace)
      line.chords.removeWhere((c) => c.position == position);
      
      // Add new
      line.chords.add(ChordPosition(position: position, chord: chord));
      
      widget.onChordsChanged(_chordLines);
    });
  }
  
  void _removeChord(int lineIndex, int position) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Acorde'),
        content: const Text('Deseja remover este acorde?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                final lineIndexInList = _chordLines.indexWhere((l) => l.lineIndex == lineIndex);
                if (lineIndexInList != -1) {
                  _chordLines[lineIndexInList].chords.removeWhere((c) => c.position == position);
                  widget.onChordsChanged(_chordLines);
                }
              });
            },
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final lines = widget.lyrics.split('\n');
    
    return Column(
      children: [
        _buildChordPalette(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lines.length,
            itemBuilder: (context, index) {
              final line = lines[index];
              final chordLine = _chordLines.firstWhere(
                (l) => l.lineIndex == index,
                orElse: () => ChordLine(lineIndex: index, chords: []),
              );
              
              return LyricLineWithChords(
                lineIndex: index,
                lyricText: line,
                chordLine: chordLine,
                onChordAdded: _addChord,
                onChordRemoved: _removeChord,
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildChordPalette() {
    // Categorized lists of chords
    final basicChords = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
    final minors = ['Cm', 'Dm', 'Em', 'Fm', 'Gm', 'Am', 'Bm'];
    final sharpsFlats = ['C#', 'Eb', 'F#', 'Ab', 'Bb'];
    final slashChords = ['G/B', 'D/F#', 'C/E', 'A/C#', 'Em/G'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Arraste os acordes:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChordGroup('Maiores', basicChords),
                const SizedBox(width: 12),
                _buildChordGroup('Menores', minors),
                const SizedBox(width: 12),
                _buildChordGroup('Sustenidos', sharpsFlats),
                const SizedBox(width: 12),
                _buildChordGroup('Baixos', slashChords),
                const SizedBox(width: 16),
                _buildCustomChordInput(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChordGroup(String label, List<String> chords) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: Row(
            children: chords.map((chord) => _buildDraggableChord(chord)).toList(),
          ),
        ),
      ],
    );
  }
  
  
  Widget _buildDraggableChord(String chord) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: Draggable<Map<String, dynamic>>(
        data: {'chord': chord},
        feedback: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(20),
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade500,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              chord,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
        childWhenDragging: Chip(
          label: Text(chord),
          backgroundColor: Colors.grey.shade200,
          labelStyle: TextStyle(color: Colors.grey.shade400),
        ),
        child: Chip(
          label: Text(
            chord,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.grey.shade400, width: 1),
          labelStyle: TextStyle(color: Colors.grey.shade800),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
    );
  }
  
  
  Widget _buildCustomChordInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            'Personalizado',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _customChordController,
                  decoration: InputDecoration(
                    hintText: 'C#m7',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      setState(() {}); 
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Draggable<Map<String, dynamic>>(
                data: {'chord': _customChordController.text.isEmpty ? '?' : _customChordController.text},
                feedback: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade500,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      _customChordController.text.isEmpty ? '?' : _customChordController.text,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                child: Icon(
                  Icons.add_circle_outline,
                  color: Colors.grey.shade700,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
