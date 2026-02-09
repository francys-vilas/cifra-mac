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
                orElse: () => ChordLine(lineIndex: index, chords: [])
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
      padding: const EdgeInsets.all(8),
      color: Colors.grey[200],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Arraste os acordes:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChordGroup(basicChords, Colors.blue.shade50),
                const SizedBox(width: 8),
                _buildChordGroup(minors, Colors.orange.shade50),
                const SizedBox(width: 8),
                 _buildChordGroup(sharpsFlats, Colors.purple.shade50),
                const SizedBox(width: 8),
                _buildChordGroup(slashChords, Colors.green.shade50),
                const SizedBox(width: 16),
                _buildCustomChordInput(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChordGroup(List<String> chords, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: chords.map((chord) => _buildDraggableChord(chord)).toList(),
      ),
    );
  }
  
  Widget _buildDraggableChord(String chord) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Draggable<Map<String, dynamic>>(
        data: {'chord': chord},
        feedback: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(16),
          child: Chip(
            label: Text(chord, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.blue.shade100,
          ),
        ),
        childWhenDragging: Chip(
          label: Text(chord),
          backgroundColor: Colors.grey.shade300,
        ),
        child: Chip(
          label: Text(chord, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
  
  Widget _buildCustomChordInput() {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: TextField(
            controller: _customChordController,
            decoration: const InputDecoration(
              hintText: 'C#m7',
              isDense: true,
              contentPadding: EdgeInsets.all(8),
              border: OutlineInputBorder(),
            ),
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
            elevation: 4,
            borderRadius: BorderRadius.circular(16),
            child: Chip(
              label: Text(
                _customChordController.text.isEmpty ? '?' : _customChordController.text,
                style: const TextStyle(fontWeight: FontWeight.bold)
              ),
              backgroundColor: Colors.orange.shade100,
            ),
          ),
          child: Chip(
            label: const Text('Custom'),
            backgroundColor: Colors.orange.shade50,
          ),
        ),
      ],
    );
  }
}
