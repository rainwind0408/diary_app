import 'package:flutter/material.dart';
import '../../../data/models/placed_audio.dart';
import 'placeable_audio.dart';

class AudioLayer extends StatefulWidget {
  final List<PlacedAudio> audios;
  final ValueChanged<List<PlacedAudio>> onAudiosChanged;
  final VoidCallback onInteractionStart;
  final VoidCallback onInteractionEnd;

  const AudioLayer({
    super.key,
    required this.audios,
    required this.onAudiosChanged,
    required this.onInteractionStart,
    required this.onInteractionEnd,
  });

  @override
  State<AudioLayer> createState() => _AudioLayerState();
}

class _AudioLayerState extends State<AudioLayer> {
  int _selectedIndex = -1;

  void _updateAudio(int index, PlacedAudio updated) {
    final list = List<PlacedAudio>.from(widget.audios);
    list[index] = updated;
    widget.onAudiosChanged(list);
  }

  void _removeAudio(int index) {
    final list = List<PlacedAudio>.from(widget.audios);
    list.removeAt(index);
    setState(() => _selectedIndex = -1);
    widget.onAudiosChanged(list);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Tap empty area to deselect
        if (_selectedIndex != -1)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() => _selectedIndex = -1);
              },
            ),
          ),
        // Render each audio
        ...widget.audios.asMap().entries.map((entry) {
          final index = entry.key;
          final audio = entry.value;
          return PlaceableAudio(
            key: ValueKey('${audio.path}_$index'),
            placedAudio: audio,
            isSelected: index == _selectedIndex,
            onTap: () {
              setState(() {
                _selectedIndex = (index == _selectedIndex) ? -1 : index;
              });
            },
            onDelete: () => _removeAudio(index),
            onUpdate: (updated) => _updateAudio(index, updated),
            onInteractionStart: widget.onInteractionStart,
            onInteractionEnd: widget.onInteractionEnd,
          );
        }),
      ],
    );
  }
}
