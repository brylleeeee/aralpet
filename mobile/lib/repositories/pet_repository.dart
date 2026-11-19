import '../core/api_service.dart';
import '../models/badge.dart';
import '../models/pet_info.dart';
import '../models/weekly_summary.dart';

/// Pet, badges and weekly summary endpoints.
class PetRepository {
  PetRepository(this._api);

  final ApiService _api;

  Map<String, dynamic> _data(dynamic response) {
    if (response is! Map || response['data'] is! Map) {
      throw ApiException('Invalid response from the server.');
    }
    return Map<String, dynamic>.from(response['data'] as Map);
  }

  // GET /pet
  Future<PetInfo> fetchPet() async =>
      PetInfo.fromJson(_data(await _api.get('/pet')));

  // PUT /pet
  Future<PetInfo> renamePet(String name) async =>
      PetInfo.fromJson(_data(await _api.put('/pet', data: {'name': name})));

  // GET /badges
  Future<List<StudyBadge>> fetchBadges() async {
    final response = await _api.get('/badges');
    final list = response is Map ? response['data'] : null;
    if (list is! List) {
      throw ApiException('Invalid badge response from the server.');
    }
    return list
        .map((b) => StudyBadge.fromJson(Map<String, dynamic>.from(b as Map)))
        .toList();
  }

  // GET /summary/weekly?week_of=YYYY-MM-DD
  Future<WeeklySummary> fetchWeeklySummary(DateTime weekOf) async {
    final day = '${weekOf.year.toString().padLeft(4, '0')}-'
        '${weekOf.month.toString().padLeft(2, '0')}-'
        '${weekOf.day.toString().padLeft(2, '0')}';
    return WeeklySummary.fromJson(
      _data(await _api.get('/summary/weekly', query: {'week_of': day})),
    );
  }
}
