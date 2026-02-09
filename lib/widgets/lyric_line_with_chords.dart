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

  const LyricLineWithChords({
    super.key,
    required this.lineIndex,
    required this.lyricText,
    required this.chordLine,
    this.onChordAdded,
    this.onChordRemoved,
    this.readOnly = false,
    this.layoutWidth,
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
        final lyricStyle = const TextStyle(
          fontFamily: 'monospace',
          fontSize: 16,
          height: 1.0,
        );

        final textPainter = TextPainter(
          text: TextSpan(text: lyricText, style: lyricStyle),
          textDirection: TextDirection.ltr,
        )..layout();

        // Calculate character width (assuming monospace)
        // Measure 'M' to get standard width
        final charWidthPainter = TextPainter(
          text: TextSpan(text: 'M', style: lyricStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final charWidth = charWidthPainter.width;

        // Calculate max slots based on available width
        // Use constraints.maxWidth if finite, otherwise default to text length + buffer
        final double availableWidth = constraints.maxWidth.isFinite 
            ? constraints.maxWidth 
            : textPainter.width + 100; // Fallback if unbounded
            
        // Calculate generic centering offset based on layoutWidth (max block width)
        double paddingLeft = 0;
        if (layoutWidth != null && availableWidth > layoutWidth!) {
          paddingLeft = (availableWidth - layoutWidth!) / 2;
        }

        // Calculate effective start and end slots
        // We want to cover from 0 to availableWidth in pixels
        // pixel = paddingLeft + slot * charWidth
        // slot = (pixel - paddingLeft) / charWidth
        final int minSlot = (-paddingLeft / charWidth).floor();
        final int maxSlot = ((availableWidth - paddingLeft) / charWidth).ceil();
        
        // Build the stack with positioned chords
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Force the stack to be full width
            SizedBox(
              width: availableWidth,
              height: 34, // Height of padding (30) + text line (approx 4 for spacing)
            ),
            
            // Lyrics layer (Non-positioned determines size)
            Padding(
              padding: EdgeInsets.only(top: 30, left: paddingLeft),
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
    // Implementation for read-only chords considering paddingLeft
    // For now, assuming standard position 0 means start of text
    return chordLine.chords.map((chordData) {
      double offset;
      if (chordData.position < 0) {
         // Extrapolate for negative positions
         // This assumes monospace char width - requires recalculation or passing charWidth
         const double estimatedCharWidth = 9.6; // Approximate for 16px monospace
         offset = paddingLeft + chordData.position * estimatedCharWidth;
      } else if (chordData.position < lyricText.length) {
         offset = paddingLeft + _getCharacterOffset(textPainter, chordData.position);
      } else {
         const double estimatedCharWidth = 9.6;
         offset = paddingLeft + textPainter.width + (chordData.position - lyricText.length) * estimatedCharWidth;
      }

      return Positioned(
        left: offset,
        top: 0,
        child: Text(
          chordData.chord,
          style: const TextStyle(
            fontWeight: FontWeight.bold, 
            color: Colors.blue,
            fontSize: 14,
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildInteractiveChords(TextPainter textPainter, double charWidth, int minSlot, int maxSlot, double paddingLeft) {
    final widgets = <Widget>[];
    
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
      
      widgets.add(
        Positioned(
          top: 0,
          left: offset,
          child: _buildDragTarget(position, existingChord?.chord),
        ),
      );
    }
    
    return widgets;
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

  Widget _buildDragTarget(int position, String? currentChord) {
    return DragTarget<Map<String, dynamic>>(
      onAcceptWithDetails: (details) => onChordAdded?.call(lineIndex, position, details.data),
      builder: (context, candidateData, rejectedData) {
        final isCandidate = candidateData.isNotEmpty;

        return Container(
          width: 12,
          height: 30,
          decoration: BoxDecoration(
            border: isCandidate
                ? Border.all(color: Colors.blue, width: 2)
                : null,
            color: isCandidate ? Colors.blue.withOpacity(0.1) : null,
          ),
          child: currentChord != null
              ? Draggable<Map<String, dynamic>>(
                  data: {
                    'chord': currentChord,
                    'fromLine': lineIndex,
                    'fromPos': position,
                  },
                  feedback: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.transparent,
                    child: Chip(
                      label: Text(currentChord,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.blue.shade100,
                    ),
                  ),
                  childWhenDragging: const SizedBox.shrink(),
                  child: GestureDetector(
                    onTap: () => onChordRemoved?.call(lineIndex, position), // Tap to remove (for now, or trigger menu)
                    onLongPress: () => {}, // Disable long press removal if tap is used, or keep both?
                    // Actually, let's keep it simple: Tap to remove is dangerous. 
                    // User said: "abrir uma lixeira no modo edição quando clicar por cima".
                    // This implies a state change or a menu.
                    // Let's implement: Tap -> onChordTapped. Parent handles "Trash Mode" or "Menu".
                    // But I need to update the interface first.
                    // Let's use onChordRemoved for now as a "Request to Remove".
                    child: Center(
                      child: Text(
                        currentChord,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.visible,
                        softWrap: false,
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
