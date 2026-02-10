import 'package:cifras/models/chord_models.dart';
import 'package:flutter/material.dart';

class LyricLineWithChords extends StatelessWidget {
  final int lineIndex;
  final String lyricText;
  final ChordLine chordLine;
  final Function(int lineIndex, int position, Map<String, dynamic> data)? onChordAdded;
  final Function(int lineIndex, int position)? onChordRemoved;
  final bool readOnly;
  final double? layoutWidth;
  final double fontSize;

  const LyricLineWithChords({
    super.key,
    required this.lineIndex,
    required this.lyricText,
    required this.chordLine,
    this.onChordAdded,
    this.onChordRemoved,
    this.readOnly = false,
    this.layoutWidth,
    this.fontSize = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCombinedView(context),
        if (!readOnly) const Divider()  else const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildCombinedView(BuildContext context) {
    // Use LayoutBuilder to get measurement info
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate character positions using TextPainter
        final lyricStyle = TextStyle(
          fontFamily: 'monospace',
          fontSize: fontSize,
          height: 1.0,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
        );

        final textPainter = TextPainter(
          text: TextSpan(text: lyricText, style: lyricStyle),
          textDirection: TextDirection.ltr,
        )..layout();

        // Calculate character width (assuming monospace)
        final charWidthPainter = TextPainter(
          text: TextSpan(text: 'M', style: lyricStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final charWidth = charWidthPainter.width;

        final double availableWidth = constraints.maxWidth.isFinite 
            ? constraints.maxWidth 
            : textPainter.width + 100;
            
        double paddingLeft = 0;
        if (layoutWidth != null && availableWidth > layoutWidth!) {
          paddingLeft = (availableWidth - layoutWidth!) / 2;
        }

        final int minSlot = (-paddingLeft / charWidth).floor();
        final int maxSlot = ((availableWidth - paddingLeft) / charWidth).ceil();

        // Dynamic heights based on fontSize
        final double baseChordHeight = fontSize * 1.5;
        // In edit mode (!readOnly), drag targets are 32.0 height. 
        // Ensure minimal height to prevent overlap with text.
        final double chordAreaHeight = !readOnly && baseChordHeight < 36.0 
            ? 36.0 
            : baseChordHeight;

        final double topPadding = chordAreaHeight + 4;
        final double totalHeight = topPadding + fontSize + 8;
        
        return Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: availableWidth,
              height: totalHeight,
            ),
            
            Padding(
              padding: EdgeInsets.only(top: topPadding, left: paddingLeft),
              child: Text(
                lyricText,
                style: lyricStyle,
                softWrap: false, 
              ),
            ),

            // Chords layer
            if (readOnly)
              ..._buildReadOnlyChords(textPainter, paddingLeft)
            else
              ..._buildInteractiveChords(textPainter, charWidth, minSlot, maxSlot, paddingLeft),
          ],
        );
      },
    );
  }

  List<Widget> _buildReadOnlyChords(TextPainter textPainter, double paddingLeft) {
    final chordFontSize = fontSize * 0.875; // Slightly smaller than lyrics
    final estimatedCharWidth = fontSize * 0.6; // Approximate monospace width
    return chordLine.chords.map((chordData) {
      double offset;
      if (chordData.position < 0) {
         offset = paddingLeft + chordData.position * estimatedCharWidth;
      } else if (chordData.position < lyricText.length) {
         offset = paddingLeft + _getCharacterOffset(textPainter, chordData.position);
      } else {
         offset = paddingLeft + textPainter.width + (chordData.position - lyricText.length) * estimatedCharWidth;
      }

      return Positioned(
        left: offset,
        top: 0,
        child: Text(
          chordData.chord,
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            color: Colors.blue,
            fontSize: chordFontSize,
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildInteractiveChords(TextPainter textPainter, double charWidth, int minSlot, int maxSlot, double paddingLeft) {
    final emptyTargets = <Widget>[];
    final chordWidgets = <Widget>[];
    
    // Iterate from minSlot to maxSlot to cover entire screen width
    for (int position = minSlot; position < maxSlot; position++) {
      // Calculate offset: uses text layout for existing chars, and fixed width for beyond
      final double offset;
      if (position < 0) {
         offset = paddingLeft + position * charWidth;
      } else if (position < lyricText.length) {
         offset = paddingLeft + _getCharacterOffset(textPainter, position);
      } else {
         // Continue from where text ends
         offset = paddingLeft + textPainter.width + (position - lyricText.length) * charWidth;
      }

      final existingChord = chordLine.chords
          .where((c) => c.position == position)
          .firstOrNull;
      
      if (existingChord != null) {
        // Chord widgets rendered LAST (on top) with full 32px size
        chordWidgets.add(
          Positioned(
            top: 0,
            left: offset,
            child: _buildDragTarget(position, existingChord.chord, charWidth),
          ),
        );
      } else {
        // Empty drop targets rendered FIRST (below) with charWidth size
        emptyTargets.add(
          Positioned(
            top: 0,
            left: offset,
            child: _buildDragTarget(position, null, charWidth),
          ),
        );
      }
    }
    
    // Empty targets first (bottom layer), then chord widgets on top
    return [...emptyTargets, ...chordWidgets];
  }

  double _getCharacterOffset(TextPainter textPainter, int position) {
    if (position == 0) return 0.0;
    if (position >= lyricText.length) {
      return textPainter.width;
    }
    
    // Get the offset of the character at this position
    final offset = textPainter.getOffsetForCaret(
      TextPosition(offset: position),
      Rect.zero,
    );
    
    return offset.dx;
  }

  Widget _buildDragTarget(int position, String? currentChord, double charWidth) {
    // Chord targets get large size (32px), empty targets use charWidth to avoid overlap
    const double chordTargetSize = 32.0;
    final double targetWidth = currentChord != null ? chordTargetSize : charWidth;
    final double targetHeight = currentChord != null ? chordTargetSize : 24.0;

    return DragTarget<Map<String, dynamic>>(
      onAcceptWithDetails: (details) => onChordAdded?.call(lineIndex, position, details.data),
      builder: (context, candidateData, rejectedData) {
        final isCandidate = candidateData.isNotEmpty;

        return Container(
          width: targetWidth,
          height: targetHeight,
          decoration: BoxDecoration(
            border: isCandidate
                ? Border.all(color: Colors.blue, width: 3)
                : (currentChord != null 
                    ? Border.all(color: Colors.blue.shade200, width: 1)
                    : null),
            color: isCandidate 
                ? Colors.blue.withOpacity(0.2)
                : (currentChord != null
                    ? Colors.blue.withOpacity(0.05)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(4),
          ),
          child: currentChord != null
              ? GestureDetector(
                  onTap: () {
                    onChordRemoved?.call(lineIndex, position);
                  },
                  child: Draggable<Map<String, dynamic>>(
                    data: {
                      'chord': currentChord,
                      'fromLine': lineIndex,
                      'fromPos': position,
                    },
                    dragAnchorStrategy: pointerDragAnchorStrategy,
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
                        currentChord,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18, // Large feedback text
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  childWhenDragging: Container(
                    width: chordTargetSize,
                    height: chordTargetSize,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Container(
                    width: chordTargetSize,
                    height: chordTargetSize,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: IgnorePointer(
                      child: Text(
                        currentChord,
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.visible,
                        softWrap: false,
                      ),
                    ),
                  ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
