// import 'package:flutter/foundation.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// class RoutePreferencesService {
//   static const String _busRoutesKey =
//       'tracked_bus_routes';
//
//   static const String _trainRoutesKey =
//       'tracked_train_routes';
//
//   static const String _enabledBusRoutesKey =
//       'enabled_bus_routes';
//
//   static const String _enabledTrainRoutesKey =
//       'enabled_train_routes';
//
//   // Used to tell screens that route preferences changed.
//   static final ValueNotifier<int> changes =
//   ValueNotifier<int>(0);
//
//   static void _notifyChanged() {
//     changes.value++;
//   }
//
//   // ============================================================
//   // BUS ROUTES
//   // ============================================================
//
//   static Future<List<String>> getBusRoutes() async {
//     final prefs =
//     await SharedPreferences.getInstance();
//
//     return prefs.getStringList(
//       _busRoutesKey,
//     ) ??
//         [];
//   }
//
//   static Future<void> saveBusRoutes(
//       List<String> routeIds,
//       ) async {
//     final prefs =
//     await SharedPreferences.getInstance();
//
//     await prefs.setStringList(
//       _busRoutesKey,
//       routeIds,
//     );
//
//     _notifyChanged();
//   }
//
//   static Future<List<String>> getEnabledBusRoutes() async {
//     final prefs =
//     await SharedPreferences.getInstance();
//
//     return prefs.getStringList(
//       _enabledBusRoutesKey,
//     ) ??
//         [];
//   }
//
//   static Future<void> saveEnabledBusRoutes(
//       List<String> routeIds,
//       ) async {
//     final prefs =
//     await SharedPreferences.getInstance();
//
//     await prefs.setStringList(
//       _enabledBusRoutesKey,
//       routeIds,
//     );
//
//     _notifyChanged();
//   }
//
//   // ============================================================
//   // TRAIN ROUTES
//   // ============================================================
//
//   static Future<List<String>> getTrainRoutes() async {
//     final prefs =
//     await SharedPreferences.getInstance();
//
//     return prefs.getStringList(
//       _trainRoutesKey,
//     ) ??
//         [];
//   }
//
//   static Future<void> saveTrainRoutes(
//       List<String> routeIds,
//       ) async {
//     final prefs =
//     await SharedPreferences.getInstance();
//
//     await prefs.setStringList(
//       _trainRoutesKey,
//       routeIds,
//     );
//
//     _notifyChanged();
//   }
//
//   static Future<List<String>> getEnabledTrainRoutes() async {
//     final prefs =
//     await SharedPreferences.getInstance();
//
//     return prefs.getStringList(
//       _enabledTrainRoutesKey,
//     ) ??
//         [];
//   }
//
//   static Future<void> saveEnabledTrainRoutes(
//       List<String> routeIds,
//       ) async {
//     final prefs =
//     await SharedPreferences.getInstance();
//
//     await prefs.setStringList(
//       _enabledTrainRoutesKey,
//       routeIds,
//     );
//
//     _notifyChanged();
//   }
// }

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoutePreferencesService {
  static const String _busRoutesKey =
      'tracked_bus_routes';

  static const String _trainRoutesKey =
      'tracked_train_routes';

  static const String _enabledBusRoutesKey =
      'enabled_bus_routes';

  static const String _enabledTrainRoutesKey =
      'enabled_train_routes';

  // Notifies MapScreen that route preferences changed.
  static final ValueNotifier<int> changes =
  ValueNotifier<int>(0);

  static void _notifyChanged() {
    changes.value++;
  }

  // ============================================================
  // BUS ROUTES
  // ============================================================

  static Future<List<String>> getBusRoutes() async {
    final prefs =
    await SharedPreferences.getInstance();

    return prefs.getStringList(
      _busRoutesKey,
    ) ??
        [];
  }

  static Future<void> saveBusRoutes(
      List<String> routeIds,
      ) async {
    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setStringList(
      _busRoutesKey,
      routeIds,
    );

    _notifyChanged();
  }

  static Future<List<String>>
  getEnabledBusRoutes() async {
    final prefs =
    await SharedPreferences.getInstance();

    return prefs.getStringList(
      _enabledBusRoutesKey,
    ) ??
        [];
  }

  static Future<void> saveEnabledBusRoutes(
      List<String> routeIds,
      ) async {
    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setStringList(
      _enabledBusRoutesKey,
      routeIds,
    );

    _notifyChanged();
  }

  // Save tracked + enabled bus routes together.
  //
  // Used when adding/removing a route so only ONE
  // preference-change notification is sent.
  static Future<void> saveBusPreferences({
    required List<String> trackedRouteIds,
    required List<String> enabledRouteIds,
  }) async {
    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setStringList(
      _busRoutesKey,
      trackedRouteIds,
    );

    await prefs.setStringList(
      _enabledBusRoutesKey,
      enabledRouteIds,
    );

    _notifyChanged();
  }

  // ============================================================
  // TRAIN ROUTES
  // ============================================================

  static Future<List<String>>
  getTrainRoutes() async {
    final prefs =
    await SharedPreferences.getInstance();

    return prefs.getStringList(
      _trainRoutesKey,
    ) ??
        [];
  }

  static Future<void> saveTrainRoutes(
      List<String> routeIds,
      ) async {
    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setStringList(
      _trainRoutesKey,
      routeIds,
    );

    _notifyChanged();
  }

  static Future<List<String>>
  getEnabledTrainRoutes() async {
    final prefs =
    await SharedPreferences.getInstance();

    return prefs.getStringList(
      _enabledTrainRoutesKey,
    ) ??
        [];
  }

  static Future<void>
  saveEnabledTrainRoutes(
      List<String> routeIds,
      ) async {
    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setStringList(
      _enabledTrainRoutesKey,
      routeIds,
    );

    _notifyChanged();
  }

  static Future<void> saveTrainPreferences({
    required List<String> trackedRouteIds,
    required List<String> enabledRouteIds,
  }) async {
    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setStringList(
      _trainRoutesKey,
      trackedRouteIds,
    );

    await prefs.setStringList(
      _enabledTrainRoutesKey,
      enabledRouteIds,
    );

    _notifyChanged();
  }
}