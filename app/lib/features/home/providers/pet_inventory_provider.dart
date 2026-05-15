import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/pet_model.dart';

/// Notifier for managing pet inventory
class PetInventoryNotifier extends AsyncNotifier<List<PetModel>> {
  @override
  Future<List<PetModel>> build() async {
    return _fetchPets();
  }

  Future<List<PetModel>> _fetchPets() async {
    try {
      final response = await ApiClient.getWithAuth('/api/inventory');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.body;
        return data
            .map((json) => PetModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load pets');
      }
    } catch (e) {
      throw Exception('Error fetching pets: $e');
    }
  }

  /// Refresh pet inventory from API
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchPets);
  }

  /// Hatch an egg by ID
  Future<PetModel?> hatchEgg(String petId) async {
    try {
      final response = await ApiClient.postWithAuth('/api/hatch/$petId', {});

      if (response.statusCode == 200) {
        final pet = PetModel.fromJson(response.body);
        await refresh();
        return pet;
      } else {
        throw Exception('Failed to hatch egg');
      }
    } catch (e) {
      throw Exception('Error hatching egg: $e');
    }
  }
}

/// Provider for pet inventory
final petInventoryProvider =
    AsyncNotifierProvider<PetInventoryNotifier, List<PetModel>>(
  () => PetInventoryNotifier(),
);

/// Provider for eggs only (filter state == 'Egg')
final eggsProvider = FutureProvider<List<PetModel>>((ref) async {
  final pets = await ref.watch(petInventoryProvider.future);
  return pets.where((pet) => pet.isEgg).toList();
});

/// Provider for hatched pets only
final hatchedPetsProvider = FutureProvider<List<PetModel>>((ref) async {
  final pets = await ref.watch(petInventoryProvider.future);
  return pets.where((pet) => pet.isHatched).toList();
});
