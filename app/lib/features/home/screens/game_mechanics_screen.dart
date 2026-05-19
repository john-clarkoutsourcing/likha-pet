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

// ── Inline token types ────────────────────────────────────────────────────────

enum _TokenType { normal, bold, italic, code }

class _InlineToken {
  final _TokenType type;
  final String text;
  const _InlineToken(this.type, this.text);
}

// Converts a LaTeX math snippet (content between $ delimiters) into plain,
// human-readable text by substituting common commands and stripping the rest.
String _latexToText(String latex) {
  var t = latex;
  // \text{ ... } → just the inner text
  t = t.replaceAllMapped(RegExp(r'\\text\{([^}]*)\}'), (m) => m[1]!);
  // Common symbols
  t = t.replaceAll(r'\times', '×');
  t = t.replaceAll(r'\cdot', '·');
  t = t.replaceAll(r'\leq', '≤');
  t = t.replaceAll(r'\geq', '≥');
  t = t.replaceAll(r'\neq', '≠');
  t = t.replaceAll(r'\approx', '≈');
  t = t.replaceAll(r'\pm', '±');
  t = t.replaceAll(r'\div', '÷');
  t = t.replaceAll(r'\sum', 'Σ');
  // Remove any remaining backslash-commands (e.g. \max, \min)
  t = t.replaceAll(RegExp(r'\\[a-zA-Z]+'), '');
  // Collapse extra whitespace
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t;
}

// Parses a line into bold (**text**), italic (*text*), code (`text`), math
// ($...$), and plain runs.
List<_InlineToken> _parseInline(String raw) {
  final tokens = <_InlineToken>[];
  var i = 0;
  final buf = StringBuffer();

  void flush() {
    if (buf.isNotEmpty) {
      tokens.add(_InlineToken(_TokenType.normal, buf.toString()));
      buf.clear();
    }
  }

  while (i < raw.length) {
    // Bold: **text**
    if (i + 1 < raw.length && raw[i] == '*' && raw[i + 1] == '*') {
      flush();
      final end = raw.indexOf('**', i + 2);
      if (end != -1) {
        tokens.add(_InlineToken(_TokenType.bold, raw.substring(i + 2, end)));
        i = end + 2;
        continue;
      }
    }
    // Italic: *text*  (single star, not doubled)
    if (raw[i] == '*') {
      flush();
      final end = raw.indexOf('*', i + 1);
      if (end != -1) {
        tokens.add(_InlineToken(_TokenType.italic, raw.substring(i + 1, end)));
        i = end + 1;
        continue;
      }
    }
    // Code: `text`
    if (raw[i] == '`') {
      flush();
      final end = raw.indexOf('`', i + 1);
      if (end != -1) {
        tokens.add(_InlineToken(_TokenType.code, raw.substring(i + 1, end)));
        i = end + 1;
        continue;
      }
    }
    // Inline math: $text$ → convert to readable plain text
    if (raw[i] == r'$') {
      flush();
      final end = raw.indexOf(r'$', i + 1);
      if (end != -1) {
        final readable = _latexToText(raw.substring(i + 1, end));
        if (readable.isNotEmpty) {
          tokens.add(_InlineToken(_TokenType.normal, readable));
        }
        i = end + 1;
        continue;
      }
    }
    // Also strip lone backslash
    if (raw[i] == r'\') {
      i++;
      continue;
    }
    buf.write(raw[i]);
    i++;
  }
  flush();
  return tokens;
}

// ── Widget ────────────────────────────────────────────────────────────────────

class _MarkdownLite extends StatelessWidget {
  final String content;
  const _MarkdownLite({required this.content});

  // Build an inline-formatted RichText widget from a raw text string.
  Widget _richLine(
    String raw, {
    required double baseFontSize,
    required Color baseColor,
    required String baseFontFamily,
    double lineHeight = 1.5,
    double top = 2,
    double bottom = 2,
  }) {
    final tokens = _parseInline(raw);
    final spans = tokens.map((t) {
      switch (t.type) {
        case _TokenType.bold:
          return TextSpan(
            text: t.text,
            style: TextStyle(
              fontFamily: baseFontFamily,
              fontSize: baseFontSize,
              color: const Color(0xFFEAFBFF),
              fontWeight: FontWeight.w700,
              height: lineHeight,
            ),
          );
        case _TokenType.italic:
          return TextSpan(
            text: t.text,
            style: TextStyle(
              fontFamily: baseFontFamily,
              fontSize: baseFontSize,
              color: const Color(0xFFAAE8F5),
              fontStyle: FontStyle.italic,
              height: lineHeight,
            ),
          );
        case _TokenType.code:
          return TextSpan(
            text: ' ${t.text} ',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: baseFontSize - 1,
              color: const Color(0xFF4AC4D9),
              backgroundColor: const Color(0xFF0A1A2E),
              height: lineHeight,
            ),
          );
        case _TokenType.normal:
          return TextSpan(
            text: t.text,
            style: TextStyle(
              fontFamily: baseFontFamily,
              fontSize: baseFontSize,
              color: baseColor,
              height: lineHeight,
            ),
          );
      }
    }).toList();

    return Padding(
      padding: EdgeInsets.only(top: top, bottom: bottom),
      child: RichText(text: TextSpan(children: spans)),
    );
  }

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
        widgets.add(_richLine(
          trimmed.substring(4),
          baseFontSize: 17,
          baseColor: const Color(0xFFBEEFFF),
          baseFontFamily: 'LilitaOne',
          top: 10,
          bottom: 4,
        ));
        continue;
      }

      if (trimmed.startsWith('## ')) {
        widgets.add(_richLine(
          trimmed.substring(3),
          baseFontSize: 20,
          baseColor: const Color(0xFFEAFBFF),
          baseFontFamily: 'LilitaOne',
          top: 14,
          bottom: 6,
        ));
        continue;
      }

      if (trimmed.startsWith('# ')) {
        widgets.add(_richLine(
          trimmed.substring(2),
          baseFontSize: 24,
          baseColor: const Color(0xFFEAFBFF),
          baseFontFamily: 'LilitaOne',
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
                '•  ',
                style: TextStyle(
                  color: Color(0xFF4AC4D9),
                  fontFamily: 'Fredoka',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Expanded(
                child: _richLine(
                  trimmed.substring(2),
                  baseFontSize: 14,
                  baseColor: Colors.white70,
                  baseFontFamily: 'Fredoka',
                  top: 0,
                  bottom: 0,
                ),
              ),
            ],
          ),
        ));
        continue;
      }

      // Skip lines that are purely block-level LaTeX math ($$...$$) or table separators.
      if (trimmed.startsWith(r'$$') ||
          RegExp(r'^[\|\-\s]+$').hasMatch(trimmed)) {
        continue;
      }

      // Table row — strip pipe chars and render as indented text.
      if (trimmed.startsWith('|')) {
        final cells = trimmed
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .join('   ');
        widgets.add(_richLine(
          cells,
          baseFontSize: 13,
          baseColor: Colors.white54,
          baseFontFamily: 'Fredoka',
          top: 1,
          bottom: 1,
        ));
        continue;
      }

      widgets.add(_richLine(
        trimmed,
        baseFontSize: 14,
        baseColor: Colors.white70,
        baseFontFamily: 'Fredoka',
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
}
