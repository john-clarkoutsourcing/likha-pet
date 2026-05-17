import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:likha_pet/features/pvp/models/battle_action_log.dart';
import 'package:likha_pet/features/pvp/services/pvp_validation_service.dart';

void main() {
  group('PvpValidationService', () {
    late PvpValidationService service;

    setUp(() {
      service = PvpValidationService();
    });

    tearDown(() {
      service.close();
    });

    test('BattleValidationRequest serializes to JSON', () {
      final request = BattleValidationRequest(
        playerId: 'player1',
        playerTeam: ['pet1', 'pet2', 'pet3'],
        opponentTeam: ['opp1', 'opp2', 'opp3'],
        winner: 'player',
        finalPlayerTeamState: [
          PetTeamSnapshot(
            petId: 'pet1',
            hp: 100,
            statusEffects: [
              StatusEffectSnapshot(
                type: 'buff',
                duration: 2,
                value: 20,
              ),
            ],
          ),
        ],
        finalOpponentTeamState: [
          PetTeamSnapshot(
            petId: 'opp1',
            hp: 0,
            statusEffects: [],
          ),
        ],
        actionLog: [
          BattleActionLog(
            round: 1,
            actor: 'pet1',
            action: 'Bite',
            target: 'opp1',
            energyUsed: 1,
            damageDealt: 30,
            timestamp: 1000,
          ),
        ],
        battleDurationMs: 30000,
        randomSeed: 12345,
      );

      final json = request.toJson();

      expect(json['playerId'], 'player1');
      expect(json['playerTeam'], ['pet1', 'pet2', 'pet3']);
      expect(json['opponentTeam'], ['opp1', 'opp2', 'opp3']);
      expect(json['winner'], 'player');
      expect(json['battleDurationMs'], 30000);
      expect(json['randomSeed'], 12345);
      expect(json['actionLog'], isNotEmpty);
      expect(json['finalPlayerTeamState'], isNotEmpty);
      expect(json['finalOpponentTeamState'], isNotEmpty);
    });

    test('BattleValidationResponse parses from JSON', () {
      final json = {
        'result': 'accepted',
        'mmrChange': 20,
        'flaggedForReview': false,
        'success': true,
      };

      final response = BattleValidationResponse.fromJson(json);

      expect(response.isAccepted, true);
      expect(response.isSuspicious, false);
      expect(response.isRejected, false);
      expect(response.mmrChange, 20);
    });

    test('BattleValidationResponse detects suspicious result', () {
      final json = {
        'result': 'suspicious',
        'reason': 'Win rate anomaly',
        'success': false,
      };

      final response = BattleValidationResponse.fromJson(json);

      expect(response.isSuspicious, true);
      expect(response.isAccepted, false);
      expect(response.reason, 'Win rate anomaly');
    });

    test('BattleValidationResponse detects rejected result', () {
      final json = {
        'result': 'rejected',
        'reason': 'Energy cheat detected',
        'flaggedForReview': true,
        'success': false,
      };

      final response = BattleValidationResponse.fromJson(json);

      expect(response.isRejected, true);
      expect(response.isAccepted, false);
      expect(response.flaggedForReview, true);
    });

    test('StatusEffectSnapshot serializes correctly', () {
      final effect = StatusEffectSnapshot(
        type: 'poison',
        duration: 3,
        value: 8,
      );

      final json = effect.toJson();

      expect(json['type'], 'poison');
      expect(json['duration'], 3);
      expect(json['value'], 8);
    });

    test('PetTeamSnapshot with multiple status effects', () {
      final snapshot = PetTeamSnapshot(
        petId: 'pet123',
        hp: 75,
        statusEffects: [
          StatusEffectSnapshot(type: 'poison', duration: 2, value: 8),
          StatusEffectSnapshot(type: 'buff', duration: 1, value: 20),
        ],
      );

      final json = snapshot.toJson();

      expect(json['petId'], 'pet123');
      expect(json['hp'], 75);
      expect(json['statusEffects'], hasLength(2));
    });

    test('BattleActionLog timestamps are preserved', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final action = BattleActionLog(
        round: 2,
        actor: 'pet1',
        action: 'Heal',
        energyUsed: 2,
        damageDealt: 0,
        timestamp: now,
      );

      final json = action.toJson();

      expect(json['timestamp'], now);
      expect(json['round'], 2);
      expect(json['energyUsed'], 2);
    });
  });

  group('PvpValidationService - Error Handling', () {
    late PvpValidationService service;

    setUp(() {
      service = PvpValidationService();
    });

    tearDown(() {
      service.close();
    });

    test('TimeoutException has correct message', () {
      final ex = TimeoutException('Test timeout');
      expect(ex.toString(), contains('TimeoutException'));
      expect(ex.toString(), contains('Test timeout'));
    });

    test('UnauthorizedException has correct message', () {
      final ex = UnauthorizedException('Missing token');
      expect(ex.toString(), contains('UnauthorizedException'));
      expect(ex.toString(), contains('Missing token'));
    });

    test('ServerException has correct message', () {
      final ex = ServerException('500 Internal Server Error');
      expect(ex.toString(), contains('ServerException'));
    });

    test('ValidationException has correct message', () {
      final ex = ValidationException('Invalid request');
      expect(ex.toString(), contains('ValidationException'));
    });
  });
}
