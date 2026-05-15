# Dynamic Pet Architecture: Database-Driven Pet System

## Problem Statement

**Current State:**
- Static pet definitions in `creature_registry.dart` (Treant, Smooch, etc.)
- `OwnedPet` already exists to represent dynamic player pets
- But player pets are only used in roster/breeding, NOT in battle
- Battle still uses static `kCreatureRegistry` for all creatures

**Correct Architecture:**
- Bodies (visual templates) → Static registry (OK)
- Parts (skill/stat generators) → Static registry (OK)
- **Dynamic pets (player & enemy)** → Database (Firestore) with mixer-based skeleton generation

---

## Current Flow vs. Desired Flow

### Current (Wrong)
```
Battle Screen
  ├─ Player team: Uses OwnedPet → Converts to CreatureDefinition
  │  └─ BUT: Uses pre-baked skeleton from body definition
  └─ Enemy team: Direct from kCreatureRegistry
     └─ Static skeleton
```

### Desired (Right)
```
Battle Screen
  ├─ Player team: OwnedPet → Firestore → CreatureDefinition
  │  └─ Uses MixedSkeletonService to generate skeleton dynamically
  └─ Enemy team: Firestore (NPC enemies) or Registry (fallback)
     └─ Uses MixedSkeletonService to generate skeleton dynamically
```

---

## Data Flow: From OwnedPet to Battle

### Step 1: OwnedPet in Firestore

```dart
// Collection: users/{userId}/pets
{
  "uid": "pet-uuid-12345",
  "name": "Blaze",
  "bodyId": "beast_1",           // References kBodyCatalogue
  "horn": { "d": "reptile-horn-08" },      // References kPartCatalogue
  "back": { "d": "aquatic-back-10" },
  "tail": { "d": "plant-tail-02" },
  "mouth": { "d": "beast-mouth-04" },
  "breedCount": 0,
  "generation": 0,
  "createdAt": "2026-05-15T...",
}
```

### Step 2: Load from Firestore

```dart
// In player_provider.dart or battle_provider.dart
final ownedPet = OwnedPet.fromJson(firestoreDoc.data());
```

### Step 3: Convert to CreatureDefinition

```dart
// This already works! OwnedPet.toCreatureDefinition()
final creatureDef = ownedPet.toCreatureDefinition();
```

### Step 4: Generate Mixed Skeleton

```dart
// NEW: Use MixedSkeletonService (what we just integrated)
final service = await MixedSkeletonService.instance();
final skeleton = await service.buildMixedSkeleton(creatureDef);
```

### Step 5: Create Battle Config

```dart
// NEW: Store in PetCharacterConfig with skeletonJson
final config = PetCharacterConfig(
  texturePath: 'assets/spines/mixer/likha-2d-v3-all.png',
  spineAtlasPath: 'assets/spines/mixer/likha-2d-v3-all.atlas',
  skeletonJson: skeleton,  // Dynamic generated skeleton
);
```

### Step 6: Render in Battle

```dart
// Already works with our Phase 1 integration
PetCharacterWidget(
  config: config,
  size: 200,
  animState: PetCharacterAnimState.idle,
);
```

---

## Implementation Steps

### Step 1: Create PetDatabase Service

**File:** `app/lib/features/pets/services/pet_database_service.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/owned_pet.dart';

class PetDatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Load all pets for a user
  Future<List<OwnedPet>> getPetsForUser(String userId) async {
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('pets')
        .get();
    
    return [
      for (final doc in snapshot.docs)
        OwnedPet.fromJson(doc.data())
    ];
  }

  /// Load a specific pet by ID
  Future<OwnedPet?> getPet(String userId, String petId) async {
    final doc = await _db
        .collection('users')
        .doc(userId)
        .collection('pets')
        .doc(petId)
        .get();
    
    if (!doc.exists) return null;
    return OwnedPet.fromJson(doc.data()!);
  }

  /// Save a pet (used for breeding/creation)
  Future<void> savePet(String userId, OwnedPet pet) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('pets')
        .doc(pet.uid)
        .set(pet.toJson());
  }

  /// Load enemy roster (NPC enemies for PvE)
  /// Could be stored in a separate 'enemyRosters' collection
  Future<List<OwnedPet>> getEnemyRoster(String stageId) async {
    final doc = await _db
        .collection('enemyRosters')
        .doc(stageId)
        .get();
    
    if (!doc.exists) return [];
    
    final enemies = doc['enemies'] as List;
    return [
      for (final enemyData in enemies)
        OwnedPet.fromJson(enemyData as Map<String, dynamic>)
    ];
  }
}
```

### Step 2: Modify BattleProvider to Use Database

**File:** `app/lib/features/battle/providers/pve_battle_provider.dart`

Key changes:
```dart
// Add imports
import '../../../pets/services/pet_database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

// In constructor:
Future<void> _loadBattleTeams(List<OwnedPet> activeRoster) async {
  final db = PetDatabaseService();
  final userId = FirebaseAuth.instance.currentUser!.uid;

  // Load player pets from database or use provided roster
  if (activeRoster.isNotEmpty) {
    _playerPets = activeRoster.map((p) => p.toCreatureDefinition().toPet()).toList();
  } else {
    final dbPets = await db.getPetsForUser(userId);
    _playerPets = dbPets.map((p) => p.toCreatureDefinition().toPet()).toList();
  }

  // Load enemy roster from database (by stageId)
  if (stageId != null) {
    final enemyData = await db.getEnemyRoster(stageId);
    _enemyPets = enemyData.map((p) => p.toCreatureDefinition().toPet()).toList();
  } else {
    _enemyPets = _teamBeta(); // Fallback to default
  }
}
```

### Step 3: Update `_registerPlayerDefs()` to Include Database Pets

```dart
void _registerPlayerDefs(List<OwnedPet> activeRoster) {
  // OwnedPet already has the body/parts info
  for (final p in activeRoster) {
    _petDefs[p.uid] = p.toCreatureDefinition();  // Store the creature def
  }
}
```

### Step 4: Ensure Phase 1 Integration Works with Dynamic Pets

Our Phase 1 integration already handles this! The `_petVM()` method now:
1. Looks up `_petDefs[pet.id]` (the CreatureDefinition)
2. Calls `service.buildMixedSkeleton(def)` (Phase 1)
3. Creates config with `skeletonJson` (Phase 1)
4. Falls back to pre-baked if mixing fails

**No changes needed!** Phase 1 integration is perfect for dynamic pets.

---

## Firestore Schema

### User Pets Collection
```
/users/{userId}/pets/{petId}
  uid: string
  name: string
  bodyId: string (reference to kBodyCatalogue)
  horn: PetGenes
    d: string (reference to kPartCatalogue)
    r1: string (optional)
    r2: string (optional)
  back: PetGenes (same structure)
  tail: PetGenes (same structure)
  mouth: PetGenes (same structure)
  breedCount: number
  generation: number
  parentAId: string (optional)
  parentBId: string (optional)
  createdAt: timestamp
```

### Enemy Rosters (For PvE Stages)
```
/enemyRosters/{stageId}
  enemies: array
    - uid, name, bodyId, horn, back, tail, mouth, ...
    - uid, name, bodyId, horn, back, tail, mouth, ...
    - uid, name, bodyId, horn, back, tail, mouth, ...
```

---

## Benefits of This Architecture

### Before (Static Registries)
❌ All players see same pets  
❌ Can't customize pet appearance based on parts  
❌ No hybrid pets for players  
❌ Doesn't scale with user-generated content  
❌ No breeding/genetics implementation  

### After (Database-Driven)
✅ Each player has unique pets  
✅ Dynamic skeleton generation per pet  
✅ Full hybrid pet support  
✅ Scalable (add new bodies/parts without code changes)  
✅ Breeding/genetics fully supported  
✅ Real-time pet updates (Firestore real-time listeners)  
✅ Cloud backup and sync  

---

## Testing Strategy

### Test 1: Load Player Pet from Firestore
```dart
final db = PetDatabaseService();
final pets = await db.getPetsForUser('test-user-123');
print('Loaded ${pets.length} pets from Firestore');
```

### Test 2: Convert to CreatureDefinition
```dart
final def = pets[0].toCreatureDefinition();
print('Creature: ${def.name}');
print('Body: ${def.bodyClass}');
print('Parts: ${def.parts.map((p) => p.partClass.name).toList()}');
```

### Test 3: Generate Mixed Skeleton
```dart
final service = await MixedSkeletonService.instance();
final skeleton = await service.buildMixedSkeleton(def);
print('✅ Mixed skeleton generated with ${(skeleton['bones'] as List).length} bones');
```

### Test 4: Battle with Database Pet
```dart
// Navigate to PvE battle with database pets
// Verify console logs:
// ✅ Mixed skeleton for [player pet 1]
// ✅ Mixed skeleton for [player pet 2]
// ✅ Mixed skeleton for [player pet 3]
// Verify battle plays normally with database pets
```

---

## Migration Path

### Phase 1: ✅ Done
- Integrate MixedSkeletonService with battle engine
- Mixed skeletons work with static registry creatures

### Phase 2 (This): In Progress
- Create PetDatabaseService
- Modify BattleProvider to load from Firestore
- Ensure Phase 1 works with database pets

### Phase 3: Verification
- Load player pets from Firestore
- Verify mixed skeleton generation
- Test battle with database pets

### Phase 4: Optimization
- Add caching layer (avoid repeated DB queries)
- Optimize Firestore reads (batch, indexes)
- Real-time listeners for pet roster updates

---

## Code Summary

**New Classes:**
- `PetDatabaseService` — Loads pets from Firestore

**Modified Classes:**
- `pve_battle_provider.dart` — Uses database for pet loading

**Unchanged:**
- `OwnedPet` — Already perfect structure
- `creature_registry.dart` — Bodies/parts stay static
- `MixedSkeletonService` — Already integrated (Phase 1)
- `PetCharacterConfig` — Already extended (Phase 1)

---

## Firestore Security Rules

Once database is set up, add these rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User pets — only owner can read/write
    match /users/{userId}/pets/{petId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    // Enemy rosters — public read, admin write
    match /enemyRosters/{document=**} {
      allow read: if true;  // All users can see enemy rosters
      allow write: if request.auth.token.admin == true;
    }
  }
}
```

---

## Expected Outcome

After implementing this:

1. ✅ Player pets stored in Firestore (not hardcoded)
2. ✅ Battle loads pets from database
3. ✅ Mixed skeletons generated dynamically (Phase 1 integration)
4. ✅ Each pet gets unique skeleton based on body + parts
5. ✅ Hybrid pets fully supported
6. ✅ Scalable architecture for growth

---

## Next Action

Should we:
1. **Implement PetDatabaseService** — Create the service layer
2. **Modify BattleProvider** — Connect battle to database
3. **Test with Firestore** — Load real player pets and battle

This is a higher-priority foundation than Phase 2 (hybrid testing) because it enables the mixer to be used with actual player pets rather than static test creatures.

**Recommendation:** Implement this first, then Phase 2 hybrid testing becomes automatic (all player pets are potentially hybrids now).
