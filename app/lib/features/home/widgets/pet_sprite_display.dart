import 'package:flutter/material.dart';
import '../models/pet_model.dart';
import '../../pets/services/gene_decoder.dart';

/// Simple pet sprite display - shows visual composition based on DNA
/// Uses emoji-based representation for MVP (can be upgraded to spine assets later)
class PetSpriteDisplay extends StatelessWidget {
  final PetModel pet;
  final double size;

  const PetSpriteDisplay({
    super.key,
    required this.pet,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final genes = GeneDecoder.decode(pet.dna);

      return Column(
        children: [
          // ── Body visualization ────────────────────────────────────────
          _PetBodyComposition(
            genes: genes,
            size: size,
          ),
          const SizedBox(height: 24),

          // ── Part indicators ───────────────────────────────────────────
          _PartsIndicator(genes: genes),
          const SizedBox(height: 16),

          // ── Color preview ─────────────────────────────────────────────
          _ColorPreview(genes: genes),
        ],
      );
    } catch (e) {
      // Fallback if DNA is invalid
      return Column(
        children: [
          Text(
            pet.attributes.element,
            style: TextStyle(fontSize: size * 0.8),
          ),
          const SizedBox(height: 12),
          Text(
            'Invalid DNA',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      );
    }
  }
}

/// Body composition visualization
class _PetBodyComposition extends StatelessWidget {
  final DecodedGenes genes;
  final double size;

  const _PetBodyComposition({
    required this.genes,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final bodyEmoji = _getClassEmoji(genes.bodyClass.toString());
    final hornEmoji = _getClassEmoji(genes.hornClass.toString());
    final backEmoji = _getClassEmoji(genes.backClass.toString());
    final tailEmoji = _getClassEmoji(genes.tailClass.toString());
    final mouthEmoji = _getClassEmoji(genes.mouthClass.toString());

    return Stack(
      alignment: Alignment.center,
      children: [
        // Main body
        Text(
          bodyEmoji,
          style: TextStyle(fontSize: size),
        ),

        // Parts positioned around body
        Positioned(
          top: -8,
          child: Text(hornEmoji, style: TextStyle(fontSize: size * 0.35)),
        ),
        Positioned(
          right: -8,
          top: 0,
          child: Text(backEmoji, style: TextStyle(fontSize: size * 0.35)),
        ),
        Positioned(
          bottom: -8,
          child: Text(tailEmoji, style: TextStyle(fontSize: size * 0.35)),
        ),
        Positioned(
          left: -8,
          bottom: 8,
          child: Text(mouthEmoji, style: TextStyle(fontSize: size * 0.35)),
        ),
      ],
    );
  }

  String _getClassEmoji(String creatureClass) {
    return switch (creatureClass) {
      'plant' => '🌿',
      'aquatic' => '🐠',
      'beast' => '🦁',
      'reptile' => '🐍',
      'bird' => '🦅',
      'bug' => '🐝',
      _ => '❓',
    };
  }
}

/// Shows which parts are equipped and their classes
class _PartsIndicator extends StatelessWidget {
  final DecodedGenes genes;

  const _PartsIndicator({required this.genes});

  @override
  Widget build(BuildContext context) {
    final parts = [
      ('Horn', genes.hornClass),
      ('Back', genes.backClass),
      ('Tail', genes.tailClass),
      ('Mouth', genes.mouthClass),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: parts.map((part) {
        final classStr = part.$2.toString();
        final emoji = _getClassEmoji(classStr);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _getClassColor(classStr).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _getClassColor(classStr),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                part.$1,
                style: TextStyle(
                  color: _getClassColor(classStr),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _getClassEmoji(String creatureClass) {
    final className = creatureClass.split('.').last.toLowerCase();
    return switch (className) {
      'plant' => '🌿',
      'aquatic' => '🐠',
      'beast' => '🦁',
      'reptile' => '🐍',
      'bird' => '🦅',
      'bug' => '🐝',
      _ => '❓',
    };
  }

  Color _getClassColor(String creatureClass) {
    final className = creatureClass.split('.').last.toLowerCase();
    return switch (className) {
      'plant' => Colors.green,
      'aquatic' => Colors.blue,
      'beast' => Colors.orange,
      'reptile' => Colors.lime,
      'bird' => Colors.pink,
      'bug' => Colors.red,
      _ => Colors.grey,
    };
  }
}

/// Color preview from DNA
class _ColorPreview extends StatelessWidget {
  final DecodedGenes genes;

  const _ColorPreview({required this.genes});

  @override
  Widget build(BuildContext context) {
    try {
      // Parse hex color
      final colorHex = genes.color.replaceFirst('#', '');
      final color = Color(int.parse('ff$colorHex', radix: 16));

      return Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Color: ${genes.color}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } catch (e) {
      return const Text('Invalid color');
    }
  }
}
