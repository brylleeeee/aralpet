import '../core/api_service.dart';
import '../models/pet.dart';

class PetRepository {
  PetRepository(this._api);

  final ApiService _api;

  PetInfo _parse(dynamic body) =>
      PetInfo.fromJson((body['data'] as Map).cast<String, dynamic>());

  // GET /pet
  Future<PetInfo> fetchPet() async => _parse(await _api.get('/pet'));

  // PATCH /pet
  Future<PetInfo> rename(String name) async =>
      _parse(await _api.patch('/pet', data: {'name': name}));
}
