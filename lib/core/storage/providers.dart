import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_storage.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (Ref ref) => throw UnimplementedError(),
);

final appStorageProvider = Provider<AppStorage>(
  (Ref ref) => AppStorage(ref.watch(sharedPreferencesProvider)),
);
