import 'dart:convert';
import 'package:flutter/services.dart';

// ── LikhaMixer ────────────────────────────────────────────────────────────────
//
// Dart port of @axieinfinity/mixer (SplatSkeletonMixer.ts).
//
// How it works:
//   1. One shared atlas (axie-2d-v3-stuff.png, 4096×4096) holds ALL body parts
//      for every class variant — just like a font file holds all glyphs.
//   2. creature-samples.json holds 67 "mini-skeletons" (one per class×variant).
//      Each mini-skeleton only knows about the bones/slots/skins for that
//      specific variant (e.g., beast-04 knows "beast horn variant 4", etc.).
//   3. mix(boneCombo) takes 7 sample names and topologically merges their
//      bones/slots/skins into one coherent Spine 3.8 JSON at runtime.
//   4. The caller provides animations from an existing full-body Spine file so
//      the mixed skeleton can actually animate.
//
// boneComboTypes order (matches BodyStructure.ts):
//   [0] body   [1] back  [2] ear  [3] eyes  [4] horn  [5] tail  [6] mouth
//
// Usage:
//   final mixer = await LikhaMixer.instance();
//   final combo = mixer.comboFor(bodyClass: 'beast', hornCardArt: '…', …);
//   final json  = mixer.mix(combo);   // Map<String, dynamic> Spine JSON

class LikhaMixer {
  // boneComboTypes order — index 0 = body, 1 = back, 2 = ear, 3 = eyes,
  //                         4 = horn, 5 = tail, 6 = mouth
  static const _kBoneComboTypes = [
    'body', 'back', 'ear', 'eyes', 'horn', 'tail', 'mouth',
  ];

  final Map<String, dynamic> _samples;         // { 'beast-04': {bones,slots,…}, … }
  final Map<String, List<String>> _sortRules;  // { 'mouth': ['eyes', …], … }

  LikhaMixer._(this._samples, this._sortRules);

  // ── Singleton ──────────────────────────────────────────────────────────────

  static LikhaMixer? _instance;

  static Future<LikhaMixer> instance() async {
    if (_instance != null) return _instance!;
    final raw = await rootBundle.loadString('assets/data/creature-samples.json');
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    final items  = Map<String, dynamic>.from(parsed['items'] as Map);
    final rulesRaw = parsed['sortingRules'] as Map? ?? {};
    final rules = <String, List<String>>{};
    rulesRaw.forEach((k, v) {
      rules[k as String] = (v as List).cast<String>();
    });
    _instance = LikhaMixer._(items, rules);
    return _instance!;
  }

  // ── Public helpers ─────────────────────────────────────────────────────────

  /// Derive the Axie sample name from a card-art asset path.
  ///   'assets/images/cards/beast-horn-04.png'  →  'beast-04'
  ///   'assets/images/cards/aquatic-back-10.png' →  'aquatic-10'
  static String sampleFromCardArt(String cardArtPath) {
    final file = cardArtPath.split('/').last.replaceAll('.png', '');
    final parts = file.split('-');
    return '${parts[0]}-${parts[2]}';
  }

  /// Build the 7-element boneCombo for a pet given its body class and 4 card arts.
  /// Ears and eyes default to the body class's "-04" sample (standard look).
  List<String?> comboFor({
    required String bodyClass,
    required String hornCardArt,
    required String backCardArt,
    required String tailCardArt,
    required String mouthCardArt,
  }) {
    final defaultPart = '$bodyClass-04';
    return [
      'body-normal',                       // [0] body
      sampleFromCardArt(backCardArt),      // [1] back
      defaultPart,                         // [2] ear  (not exposed as gene)
      defaultPart,                         // [3] eyes (not exposed as gene)
      sampleFromCardArt(hornCardArt),      // [4] horn
      sampleFromCardArt(tailCardArt),      // [5] tail
      sampleFromCardArt(mouthCardArt),     // [6] mouth
    ];
  }

  // ── Core mix ───────────────────────────────────────────────────────────────

  /// Merge 7 sample mini-skeletons into one Spine 3.8 JSON.
  /// The returned map has no animations; call [mergeAnimations] to add them.
  Map<String, dynamic> mix(List<String?> boneCombo) {
    var bones = _correctBones(_mixEntries(_getBones, boneCombo));
    final boneNames = bones.map((b) => b['name'] as String).toList();

    final slots = _mixEntries(_getSlots, boneCombo);
    final slotNames = slots.map((s) => s['name'] as String).toList();

    final ik = _mixEntries(_getIk, boneCombo);

    final skins = _mixSkins(boneCombo, boneNames, slotNames);

    final events = <String, dynamic>{};
    for (final name in boneCombo) {
      if (name == null) continue;
      final evts = _samples[name]?['events'];
      if (evts is Map) evts.forEach((k, v) => events[k as String] = {});
    }

    return {
      'skeleton': {'spine': '3.8.79'},
      'bones':    bones,
      'slots':    slots,
      'ik':       ik,
      'skins':    skins,
      'events':   events,
      'animations': <String, dynamic>{},
    };
  }

  /// Copy animations from [animSourceJson] (a full Spine JSON) into [mixedJson].
  /// Since both share the same bone-name conventions, animations transfer directly.
  static void mergeAnimations(
    Map<String, dynamic> mixedJson,
    Map<String, dynamic> animSourceJson,
  ) {
    final anims = animSourceJson['animations'];
    if (anims is Map) {
      mixedJson['animations'] = Map<String, dynamic>.from(anims);
    }
  }

  // ── Internal: topological bone/slot/IK merge ──────────────────────────────

  static List _getBones(Map<String, dynamic> s) => s['bones'] as List? ?? [];
  static List _getSlots(Map<String, dynamic> s) => s['slots'] as List? ?? [];
  static List _getIk(Map<String, dynamic> s)    => s['ik']    as List? ?? [];

  bool _isBodyEntry(String name) {
    for (int i = 1; i < _kBoneComboTypes.length; i++) {
      if (name.startsWith(_kBoneComboTypes[i])) return false;
    }
    return true;
  }

  String? _getSampleName(String entryName, List<String?> boneCombo) {
    if (entryName.startsWith('@') || _isBodyEntry(entryName)) return boneCombo[0];
    for (int i = 1; i < _kBoneComboTypes.length; i++) {
      if (entryName.startsWith(_kBoneComboTypes[i])) {
        return i < boneCombo.length ? boneCombo[i] : boneCombo[0];
      }
    }
    return boneCombo[0];
  }

  List<Map<String, dynamic>> _mixEntries(
    List Function(Map<String, dynamic>) getEntries,
    List<String?> boneCombo,
  ) {
    final edges = <String, List<String>>{};

    // Body sample (index 0): walk its entries and build dependency edges
    final bodyName = boneCombo.isNotEmpty ? boneCombo[0] : null;
    if (bodyName != null) {
      final bodySample = _samples[bodyName];
      if (bodySample != null) {
        final nodes = getEntries(bodySample as Map<String, dynamic>);
        String? prev = nodes.isNotEmpty ? nodes[0]['name'] as String : null;
        for (int i = 1; i < nodes.length; i++) {
          final name = nodes[i]['name'] as String;
          if (!_isBodyEntry(name)) continue;
          if (prev != null) edges.putIfAbsent(name, () => []).add(prev);
          prev = name;
        }
      }
    }

    // Part samples (indices 1-6)
    for (int i = 1; i < _kBoneComboTypes.length; i++) {
      final partName = i < boneCombo.length ? boneCombo[i] : null;
      if (partName == null) continue;
      final sample = _samples[partName];
      if (sample == null) continue;

      final prefix = _kBoneComboTypes[i];
      final nodes = getEntries(sample as Map<String, dynamic>);
      String? prev = nodes.isNotEmpty ? nodes[0]['name'] as String : null;

      for (int j = 1; j < nodes.length; j++) {
        final name = nodes[j]['name'] as String;
        if (!_isBodyEntry(name)) {
          if (!name.startsWith(prefix)) continue;
        } else if (!name.startsWith('body') && !name.startsWith('shadow')) {
          continue;
        }
        if (prev != null) edges.putIfAbsent(name, () => []).add(prev);
        prev = name;
      }
    }

    // Apply custom sorting rules
    _applyRules(edges);

    // DFS topological sort
    final visited   = <String, bool>{};
    final sortedNames = <String>[];

    void visit(String name) {
      if (visited[name] == true) return;
      visited[name] = true;
      for (final dep in edges[name] ?? const <String>[]) { visit(dep); }
      sortedNames.add(name);
    }

    for (final sampleName in boneCombo) {
      if (sampleName == null) continue;
      final sample = _samples[sampleName];
      if (sample == null) continue;
      for (final entry in getEntries(sample as Map<String, dynamic>)) {
        visit(entry['name'] as String);
      }
    }

    // Build result in sorted order, picking each entry from its owner sample
    final result = <Map<String, dynamic>>[];
    for (final name in sortedNames) {
      final ownerName = _getSampleName(name, boneCombo);
      if (ownerName == null) continue;
      final owner = _samples[ownerName];
      if (owner == null) continue;
      for (final entry in getEntries(owner as Map<String, dynamic>)) {
        if (entry['name'] == name) {
          result.add(Map<String, dynamic>.from(entry as Map));
          break;
        }
      }
    }

    return result;
  }

  // ── Internal: skin attachment merge with bone-index remapping ─────────────

  List<Map<String, dynamic>> _mixSkins(
    List<String?> boneCombo,
    List<String> mergedBoneNames,
    List<String> slotNames,
  ) {
    final mixed = <String, Map<String, dynamic>>{};

    for (final slotName in slotNames) {
      final ownerName = _getSampleName(slotName, boneCombo) ?? boneCombo[0];
      if (ownerName == null) continue;
      final owner = _samples[ownerName];
      if (owner == null) continue;

      final skins = owner['skins'] as List? ?? [];
      final defaultSkin = skins.firstWhere(
        (s) => (s as Map)['name'] == 'default',
        orElse: () => null,
      ) as Map?;
      if (defaultSkin == null) continue;

      final attachments = defaultSkin['attachments'] as Map?;
      if (attachments == null) continue;

      final slotAttachments = attachments[slotName] as Map?;
      if (slotAttachments == null) continue;

      final ownerBones = (owner['bones'] as List? ?? [])
          .cast<Map>()
          .map((b) => b['name'] as String)
          .toList();

      mixed[slotName] = _transformSlot(
        slotAttachments, ownerBones, mergedBoneNames);
    }

    return [
      {
        'name': 'default',
        'attachments': mixed,
      }
    ];
  }

  Map<String, dynamic> _transformSlot(
    Map rawSlot,
    List<String> sampleBones,
    List<String> mergedBones,
  ) {
    final result = <String, dynamic>{};
    rawSlot.forEach((key, rawAttachment) {
      final attachment = Map<String, dynamic>.from(rawAttachment as Map);
      if (attachment['type'] == 'mesh') {
        final vertices = List<dynamic>.from(attachment['vertices'] as List);
        final uvs      = attachment['uvs'] as List? ?? [];
        if (vertices.length > uvs.length) {
          // Weighted mesh: remap embedded bone indices
          int i = 0;
          while (i < vertices.length) {
            final numBones = (vertices[i] as num).toInt();
            i++;
            for (int j = 0; j < numBones; j++) {
              final sampleIdx = (vertices[i] as num).toInt();
              if (sampleIdx < sampleBones.length) {
                final boneName   = sampleBones[sampleIdx];
                final mergedIdx  = mergedBones.indexOf(boneName);
                vertices[i] = mergedIdx >= 0 ? mergedIdx : sampleIdx;
              }
              i += 4; // skip x, y, weight (3 values) + next index
            }
          }
          attachment['vertices'] = vertices;
        }
      }
      result[key as String] = attachment;
    });
    return result;
  }

  // ── Internal: bone ordering + sorting rules ───────────────────────────────

  /// Ensures every bone appears in the list AFTER its parent (Spine requirement).
  List<Map<String, dynamic>> _correctBones(List<Map<String, dynamic>> bones) {
    final known  = <String>{};
    final result = <Map<String, dynamic>>[];
    var pending  = List<Map<String, dynamic>>.from(bones);

    for (int loop = 0; loop < 100 && pending.isNotEmpty; loop++) {
      final nextPending = <Map<String, dynamic>>[];
      for (final bone in pending) {
        final parent = bone['parent'] as String?;
        if (parent == null || known.contains(parent)) {
          known.add(bone['name'] as String);
          result.add(bone);
        } else {
          nextPending.add(bone);
        }
      }
      if (nextPending.length == pending.length) break; // no progress → stop
      pending = nextPending;
    }
    result.addAll(pending); // any remaining (orphan) bones appended as-is
    return result;
  }

  void _applyRules(Map<String, List<String>> edges) {
    _sortRules.forEach((p, deps) {
      if (!edges.containsKey(p)) return;
      for (final q in deps) {
        if (edges.containsKey(q)) edges[p]!.add(q);
      }
    });
  }
}
