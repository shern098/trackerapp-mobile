import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrackedRoutesService {
  final SupabaseClient _client;

  TrackedRoutesService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static void _notifyChanged() => changes.value++;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw Exception('No logged in user.');
    return id;
  }

  Future<Map<String, bool>> getTrackedRoutes(String routeType) async {
    final rows = await _client
        .from('tracked_routes')
        .select('route_id, is_enabled')
        .eq('user_id', _userId)
        .eq('route_type', routeType);

    final result = <String, bool>{};
    for (final row in rows as List) {
      final map = row as Map<String, dynamic>;
      result[map['route_id'] as String] = map['is_enabled'] as bool;
    }
    return result;
  }

  Future<void> upsertRoute({
    required String routeKey,
    required String routeType,
    required bool isEnabled,
  }) async {
    await _client.from('tracked_routes').upsert({
      'user_id': _userId,
      'route_id': routeKey,
      'route_type': routeType,
      'is_enabled': isEnabled,
    }, onConflict: 'user_id,route_id,route_type');
    _notifyChanged();
  }

  Future<void> removeRoute({
    required String routeKey,
    required String routeType,
  }) async {
    await _client
        .from('tracked_routes')
        .delete()
        .eq('user_id', _userId)
        .eq('route_id', routeKey)
        .eq('route_type', routeType);
    _notifyChanged();
  }
}