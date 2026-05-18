import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GameMechanicsScreen extends StatefulWidget {
  const GameMechanicsScreen({super.key});

  @override
  State<GameMechanicsScreen> createState() => _GameMechanicsScreenState();
}

class _GameMechanicsScreenState extends State<GameMechanicsScreen>
    {
  late final Future<String> _mechanicsMarkdown;

  @override
  void initState() {
    super.initState();
    _mechanicsMarkdown =
        rootBundle.loadString('assets/data/battle_game_mechanics.md');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050810),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1A2E),
        elevation: 1,
        centerTitle: true,
        title: const Text(
          'Battle Mechanics',
          style: TextStyle(
            fontFamily: 'LilitaOne',
            fontSize: 24,
            color: Color(0xFFEAFBFF),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<String>(
        future: _mechanicsMarkdown,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4AC4D9)),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Failed to load battle mechanics markdown.',
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final markdown = snapshot.data ?? '';
          return _MarkdownLite(content: markdown);
        },
      ),
    );
  }
}

class _MarkdownLite extends StatelessWidget {
  final String content;
  const _MarkdownLite({required this.content});

  @override
  Widget build(BuildContext context) {
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final widgets = <Widget>[];

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 10));
        continue;
      }

      if (trimmed == '---') {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(color: Color(0xFF1E3A5F), height: 1),
        ));
        continue;
      }

      if (trimmed.startsWith('### ')) {
        widgets.add(_lineText(
          trimmed.substring(4),
          fontFamily: 'LilitaOne',
          fontSize: 18,
          color: const Color(0xFFBEEFFF),
          top: 10,
          bottom: 6,
        ));
        continue;
      }

      if (trimmed.startsWith('## ')) {
        widgets.add(_lineText(
          trimmed.substring(3),
          fontFamily: 'LilitaOne',
          fontSize: 21,
          color: const Color(0xFFEAFBFF),
          top: 12,
          bottom: 7,
        ));
        continue;
      }

      if (trimmed.startsWith('# ')) {
        widgets.add(_lineText(
          trimmed.substring(2),
          fontFamily: 'LilitaOne',
          fontSize: 24,
          color: const Color(0xFFEAFBFF),
          top: 6,
          bottom: 8,
        ));
        continue;
      }

      final isBullet = trimmed.startsWith('* ') || trimmed.startsWith('- ');
      if (isBullet) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 3, bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '• ',
                style: TextStyle(
                  color: Color(0xFF4AC4D9),
                  fontFamily: 'Fredoka',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Expanded(
                child: Text(
                  trimmed.substring(2),
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ));
        continue;
      }

      widgets.add(_lineText(
        trimmed,
        fontFamily: 'Fredoka',
        fontSize: 14,
        color: Colors.white70,
        top: 2,
        bottom: 2,
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1923),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E3A5F), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widgets,
        ),
      ),
    );
  }

  Widget _lineText(
    String text, {
    required String fontFamily,
    required double fontSize,
    required Color color,
    required double top,
    required double bottom,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: bottom),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          color: color,
          height: 1.45,
        ),
      ),
    );
  }
}
