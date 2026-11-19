import '../core/api_service.dart';
import '../models/admin.dart';

/// The /admin endpoints (administrator accounts only).
class AdminRepository {
  AdminRepository(this._api);

  final ApiService _api;

  Map<String, dynamic> _map(Object? value) {
    if (value is! Map) throw ApiException('Invalid response from the server.');
    return Map<String, dynamic>.from(value);
  }

  List<Map<String, dynamic>> _list(Object? response) {
    final data = response is Map ? response['data'] : null;
    if (data is! List) throw ApiException('Invalid response from the server.');
    return data.map(_map).toList();
  }

  String _date(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<AdminUserPage> fetchUsers({String? search, String? status, int page = 1}) async {
    final response = await _api.get('/admin/users', query: {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null) 'status': status,
      'page': page,
    });
    final meta = _map((response as Map)['meta']);

    return AdminUserPage(
      users: _list(response).map(AdminUser.fromJson).toList(),
      currentPage: (meta['current_page'] as num).toInt(),
      lastPage: (meta['last_page'] as num).toInt(),
      total: (meta['total'] as num).toInt(),
    );
  }

  Future<AdminUser> setActive(int userId, bool active) async {
    final response = await _api.patch('/admin/users/$userId/status', data: {'is_active': active});
    return AdminUser.fromJson(_map(_map(response)['data']));
  }

  Future<AdminReport> fetchReport({required String period, required DateTime date}) async {
    final response = await _api.get('/admin/reports', query: {'period': period, 'date': _date(date)});
    return AdminReport.fromJson(_map(_map(response)['data']));
  }

  Future<List<AdminBadge>> fetchBadges() async =>
      _list(await _api.get('/admin/badges')).map(AdminBadge.fromJson).toList();

  Future<AdminBadge> saveBadge(Map<String, dynamic> data, {int? id}) async {
    final response = id == null
        ? await _api.post('/admin/badges', data: data)
        : await _api.put('/admin/badges/$id', data: data);
    return AdminBadge.fromJson(_map(_map(response)['data']));
  }

  Future<List<XpRule>> fetchSettings() async =>
      _list(await _api.get('/admin/settings')).map(XpRule.fromJson).toList();

  Future<List<XpRule>> saveSettings(Map<String, int> values) async =>
      _list(await _api.put('/admin/settings', data: values)).map(XpRule.fromJson).toList();
}
