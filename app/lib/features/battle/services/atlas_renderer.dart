import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

// ── AtlasRegion ───────────────────────────────────────────────────────────────

class AtlasRegion {
  final String name;
  final int x, y, width, height;
  final bool rotated;

  const AtlasRegion({
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotated = false,
  });
}

// ── AtlasData ─────────────────────────────────────────────────────────────────
// Parses Spine .atlas text format into a map of region name → AtlasRegion.

class AtlasData {
  final Map<String, AtlasRegion> regions;

  const AtlasData(this.regions);

  static AtlasData parse(String src) {
    final regions = <String, AtlasRegion>{};
    final lines = src.split('\n').map((l) => l.trimRight()).toList();
    int i = 0;

    while (i < lines.length) {
      final line = lines[i].trim();
      // A line with no leading whitespace that isn't a header field = region name
      if (line.isNotEmpty &&
          !line.startsWith('size:') &&
          !line.startsWith('format:') &&
          !line.startsWith('filter:') &&
          !line.startsWith('repeat:') &&
          !line.endsWith('.png') &&
          !line.startsWith('pma:')) {
        final name = line;
        final props = <String, String>{};
        i++;
        while (i < lines.length && lines[i].startsWith(' ')) {
          final kv = lines[i].trim().split(':');
          if (kv.length >= 2) {
            props[kv[0].trim()] = kv.sublist(1).join(':').trim();
          }
          i++;
        }
        final xy   = (props['xy'] ?? '0,0').split(',');
        final size = (props['size'] ?? '0,0').split(',');
        regions[name] = AtlasRegion(
          name:    name,
          x:       int.tryParse(xy[0].trim()) ?? 0,
          y:       int.tryParse(xy.length > 1 ? xy[1].trim() : '0') ?? 0,
          width:   int.tryParse(size[0].trim()) ?? 0,
          height:  int.tryParse(size.length > 1 ? size[1].trim() : '0') ?? 0,
          rotated: (props['rotate'] ?? 'false') == 'true',
        );
      } else {
        i++;
      }
    }
    return AtlasData(regions);
  }

  AtlasRegion? operator [](String name) => regions[name];
}

// ── Bone / attachment data ────────────────────────────────────────────────────

class _Bone {
  final String name;
  final String? parent;
  final double x, y, rotation, scaleX, scaleY;

  const _Bone({
    required this.name,
    this.parent,
    this.x = 0, this.y = 0,
    this.rotation = 0,
    this.scaleX = 1, this.scaleY = 1,
  });
}

class _Attachment {
  final double x, y, rotation, scaleX, scaleY, width, height;
  final String regionName;

  const _Attachment({
    required this.regionName,
    this.x = 0, this.y = 0,
    this.rotation = 0,
    this.scaleX = 1, this.scaleY = 1,
    this.width = 0, this.height = 0,
  });
}

// ── World transform ───────────────────────────────────────────────────────────

class _WorldTransform {
  final double x, y, a, b, c, d; // 2×2 matrix + translation

  const _WorldTransform({
    required this.x, required this.y,
    required this.a, required this.b,
    required this.c, required this.d,
  });

  static const identity = _WorldTransform(x: 0, y: 0, a: 1, b: 0, c: 0, d: 1);

  _WorldTransform applyBone(_Bone bone) {
    final cos = math.cos(bone.rotation * math.pi / 180);
    final sin = math.sin(bone.rotation * math.pi / 180);
    final na = a * cos * bone.scaleX + b * -sin * bone.scaleY;
    final nb = a * sin * bone.scaleX + b *  cos * bone.scaleY;
    final nc = c * cos * bone.scaleX + d * -sin * bone.scaleY;
    final nd = c * sin * bone.scaleX + d *  cos * bone.scaleY;
    final nx = a * bone.x + b * bone.y + x;
    final ny = c * bone.x + d * bone.y + y;
    return _WorldTransform(x: nx, y: ny, a: na, b: nb, c: nc, d: nd);
  }
}

// ── PetAtlasRenderer ──────────────────────────────────────────────────────────
// Assembles and renders a pet from the shared atlas by reading the skeleton's
// setup pose (bone positions + attachment offsets).
//
// Usage:
//   final renderer = await PetAtlasRenderer.load(
//     atlasImagePath: 'assets/spines/mixer/likha-2d-v3-all.png',
//     atlasDataPath:  'assets/spines/mixer/likha-2d-v3-all.atlas',
//     skeletonPath:   'assets/spines/beast/buba.json',
//   );
//   // Then pass renderer to PetAtlasWidget

class PetAtlasRenderer {
  final ui.Image atlasImage;
  final AtlasData atlasData;
  final List<({String slotName, _Attachment att, _WorldTransform world})> drawCalls;

  const PetAtlasRenderer._({
    required this.atlasImage,
    required this.atlasData,
    required this.drawCalls,
  });

  static final Map<String, PetAtlasRenderer> _cache = {};

  static Future<PetAtlasRenderer?> load({
    required String atlasImagePath,
    required String atlasDataPath,
    required String skeletonPath,
    Map<String, String> slotOverrides = const {},
  }) async {
    final cacheKey = '$skeletonPath|${slotOverrides.entries.map((e)=>'${e.key}:${e.value}').join(',')}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    try {
      // Load atlas image
      final imgBytes = await rootBundle.load(atlasImagePath);
      final codec    = await ui.instantiateImageCodec(imgBytes.buffer.asUint8List());
      final frame    = await codec.getNextFrame();
      final atlasImg = frame.image;

      // Load atlas data
      final atlasStr  = await rootBundle.loadString(atlasDataPath);
      final atlasData = AtlasData.parse(atlasStr);

      // Load skeleton
      final skelStr = await rootBundle.loadString(skeletonPath);
      final skelJson = jsonDecode(skelStr) as Map<String, dynamic>;

      final drawCalls = _buildDrawCalls(skelJson, atlasData, slotOverrides);

      final renderer = PetAtlasRenderer._(
        atlasImage: atlasImg,
        atlasData:  atlasData,
        drawCalls:  drawCalls,
      );
      _cache[cacheKey] = renderer;
      return renderer;
    } catch (e) {
      debugPrint('PetAtlasRenderer.load failed: $e');
      return null;
    }
  }

  static List<({String slotName, _Attachment att, _WorldTransform world})>
      _buildDrawCalls(
    Map<String, dynamic> skel,
    AtlasData atlas,
    Map<String, String> overrides,
  ) {
    // Parse bones
    final boneList = (skel['bones'] as List? ?? []).cast<Map<String, dynamic>>();
    final bones    = <String, _Bone>{};
    for (final b in boneList) {
      bones[b['name'] as String] = _Bone(
        name:     b['name'] as String,
        parent:   b['parent'] as String?,
        x:        (b['x'] as num? ?? 0).toDouble(),
        y:        (b['y'] as num? ?? 0).toDouble(),
        rotation: (b['rotation'] as num? ?? 0).toDouble(),
        scaleX:   (b['scaleX'] as num? ?? 1).toDouble(),
        scaleY:   (b['scaleY'] as num? ?? 1).toDouble(),
      );
    }

    // Compute world transforms for all bones (setup pose)
    final worlds = <String, _WorldTransform>{};
    for (final b in boneList) {
      _computeWorld(b['name'] as String, bones, worlds);
    }

    // Parse default skin attachments
    final skins = skel['skins'] as List? ?? [];
    Map<String, dynamic> defaultSkinAtts = {};
    for (final skin in skins) {
      if ((skin as Map)['name'] == 'default') {
        defaultSkinAtts = (skin['attachments'] as Map<String, dynamic>? ?? {});
        break;
      }
    }

    // Parse slots (defines draw order)
    final slotList = (skel['slots'] as List? ?? []).cast<Map<String, dynamic>>();

    final calls = <({String slotName, _Attachment att, _WorldTransform world})>[];

    for (final slot in slotList) {
      final slotName   = slot['name'] as String;
      final boneName   = slot['bone'] as String;
      final attName    = overrides[slotName] ?? (slot['attachment'] as String? ?? '');
      if (attName.isEmpty) continue;

      // Skip non-visible slots (shadow, ball, legs)
      if (slotName == 'shadow' || slotName == 'ball' ||
          slotName.startsWith('leg-') || slotName == 'body-pattern') continue;

      final slotAtts = defaultSkinAtts[slotName] as Map<String, dynamic>?;
      if (slotAtts == null) continue;
      final attData = slotAtts[attName] as Map<String, dynamic>?;
      if (attData == null) continue;

      // Resolve atlas region name
      // In Spine the skin attachment 'path' field overrides the region name
      final regionName = (attData['path'] as String?) ?? attName;

      if (atlas[regionName] == null) continue;

      final world = worlds[boneName] ?? _WorldTransform.identity;
      final att   = _Attachment(
        regionName: regionName,
        x:        (attData['x'] as num? ?? 0).toDouble(),
        y:        (attData['y'] as num? ?? 0).toDouble(),
        rotation: (attData['rotation'] as num? ?? 0).toDouble(),
        scaleX:   (attData['scaleX'] as num? ?? 1).toDouble(),
        scaleY:   (attData['scaleY'] as num? ?? 1).toDouble(),
        width:    (attData['width'] as num? ?? attData['w'] as num? ?? 0).toDouble(),
        height:   (attData['height'] as num? ?? attData['h'] as num? ?? 0).toDouble(),
      );
      calls.add((slotName: slotName, att: att, world: world));
    }

    return calls;
  }

  static void _computeWorld(
    String name,
    Map<String, _Bone> bones,
    Map<String, _WorldTransform> worlds,
  ) {
    if (worlds.containsKey(name)) return;
    final bone = bones[name];
    if (bone == null) { worlds[name] = _WorldTransform.identity; return; }

    final parentName = bone.parent;
    if (parentName == null || parentName == 'root') {
      worlds[name] = _WorldTransform.identity.applyBone(bone);
      return;
    }
    if (!worlds.containsKey(parentName)) {
      _computeWorld(parentName, bones, worlds);
    }
    worlds[name] = worlds[parentName]!.applyBone(bone);
  }
}

// ── PetAtlasPainter ───────────────────────────────────────────────────────────

class PetAtlasPainter extends CustomPainter {
  final PetAtlasRenderer renderer;
  final double scale;
  // Spine is Y-up; we flip Y to get Flutter's Y-down.
  // offsetX/Y shift the whole skeleton so it's centered on canvas.
  final double offsetX, offsetY;

  const PetAtlasPainter({
    required this.renderer,
    this.scale   = 0.12,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.medium;

    canvas.save();
    // Center on canvas, apply Y-flip for Spine coordinate system
    canvas.translate(size.width / 2 + offsetX, size.height / 2 + offsetY);
    canvas.scale(scale, -scale); // negative Y = flip

    for (final call in renderer.drawCalls) {
      final region = renderer.atlasData[call.att.regionName];
      if (region == null) continue;

      final w   = call.world;
      final att = call.att;

      // Compute attachment world transform
      final cos = math.cos(att.rotation * math.pi / 180);
      final sin = math.sin(att.rotation * math.pi / 180);
      final wa  = w.a * cos * att.scaleX + w.b * -sin * att.scaleY;
      final wb  = w.a * sin * att.scaleX + w.b *  cos * att.scaleY;
      final wc  = w.c * cos * att.scaleX + w.d * -sin * att.scaleY;
      final wd  = w.c * sin * att.scaleX + w.d *  cos * att.scaleY;
      final wx  = w.a * att.x + w.b * att.y + w.x;
      final wy  = w.c * att.x + w.d * att.y + w.y;

      final rW  = region.width.toDouble();
      final rH  = region.height.toDouble();

      // Build local-to-world matrix for this attachment (centered on attachment)
      canvas.save();
      canvas.transform(Float64List.fromList([
        wa,   wc,   0,  0,
        wb,   wd,   0,  0,
        0,    0,    1,  0,
        wx,   wy,   0,  1,
      ]));

      // Draw region from atlas (src rect → dest rect centered at origin)
      canvas.drawImageRect(
        renderer.atlasImage,
        Rect.fromLTWH(
          region.x.toDouble(), region.y.toDouble(), rW, rH),
        Rect.fromCenter(
          center: Offset.zero,
          width: att.width > 0 ? att.width : rW,
          height: att.height > 0 ? att.height : rH,
        ),
        paint,
      );

      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(PetAtlasPainter old) => old.renderer != renderer;
}

// ── PetAtlasWidget ────────────────────────────────────────────────────────────

class PetAtlasWidget extends StatefulWidget {
  final String atlasImagePath;
  final String atlasDataPath;
  final String skeletonPath;
  final Map<String, String> slotOverrides;
  final double size;
  final double offsetX, offsetY;
  final double scale;

  const PetAtlasWidget({
    super.key,
    required this.atlasImagePath,
    required this.atlasDataPath,
    required this.skeletonPath,
    this.slotOverrides = const {},
    this.size          = 200,
    this.offsetX       = 0,
    this.offsetY       = 0,
    this.scale         = 0.12,
  });

  @override
  State<PetAtlasWidget> createState() => _PetAtlasWidgetState();
}

class _PetAtlasWidgetState extends State<PetAtlasWidget> {
  PetAtlasRenderer? _renderer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PetAtlasWidget old) {
    super.didUpdateWidget(old);
    if (old.skeletonPath    != widget.skeletonPath ||
        old.slotOverrides.toString() != widget.slotOverrides.toString()) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await PetAtlasRenderer.load(
      atlasImagePath: widget.atlasImagePath,
      atlasDataPath:  widget.atlasDataPath,
      skeletonPath:   widget.skeletonPath,
      slotOverrides:  widget.slotOverrides,
    );
    if (mounted) setState(() { _renderer = r; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _renderer == null) {
      return SizedBox(width: widget.size, height: widget.size,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return SizedBox(
      width:  widget.size,
      height: widget.size,
      child:  CustomPaint(
        size: Size(widget.size, widget.size),
        painter: PetAtlasPainter(
          renderer: _renderer!,
          scale:    widget.scale,
          offsetX:  widget.offsetX,
          offsetY:  widget.offsetY,
        ),
      ),
    );
  }
}
