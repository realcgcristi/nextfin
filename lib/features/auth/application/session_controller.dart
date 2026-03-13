import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/jellyfin_api.dart';
import '../../../core/storage/app_storage.dart';
import '../../../core/storage/providers.dart';
import '../../../shared/models/server_account.dart';

class SessionState {
  const SessionState({
    required this.accounts,
    required this.activeAccount,
    required this.recentSearches,
  });

  final List<ServerAccount> accounts;
  final ServerAccount? activeAccount;
  final List<String> recentSearches;

  bool get isAuthenticated => activeAccount != null;

  SessionState copyWith({
    List<ServerAccount>? accounts,
    ServerAccount? activeAccount,
    bool clearActive = false,
    List<String>? recentSearches,
  }) {
    return SessionState(
      accounts: accounts ?? this.accounts,
      activeAccount: clearActive ? null : activeAccount ?? this.activeAccount,
      recentSearches: recentSearches ?? this.recentSearches,
    );
  }
}

final jellyfinApiProvider = Provider<JellyfinApi>((Ref ref) => JellyfinApi());

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  late final AppStorage _storage;
  late final JellyfinApi _api;

  @override
  SessionState build() {
    _storage = ref.watch(appStorageProvider);
    _api = ref.watch(jellyfinApiProvider);

    final accounts = _storage.loadAccounts();
    final activeId = _storage.loadActiveAccountId();
    final active =
        accounts.where((ServerAccount item) => item.id == activeId).firstOrNull;
    return SessionState(
      accounts: accounts,
      activeAccount: active ?? (accounts.isNotEmpty ? accounts.first : null),
      recentSearches: _storage.loadRecentSearches(),
    );
  }

  Future<void> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final current = state;
    final result = await _api.authenticate(
      serverUrl: serverUrl,
      username: username,
      password: password,
    );
    final others =
        current.accounts
            .where((ServerAccount item) => item.id != result.account.id)
            .toList();
    final updated = <ServerAccount>[result.account, ...others];
    await _storage.saveAccounts(updated);
    await _storage.saveActiveAccountId(result.account.id);
    state = current.copyWith(accounts: updated, activeAccount: result.account);
  }

  Future<void> switchAccount(String accountId) async {
    final current = state;
    final account =
        current.accounts
            .where((ServerAccount item) => item.id == accountId)
            .firstOrNull;
    if (account == null) return;
    await _storage.saveActiveAccountId(accountId);
    state = current.copyWith(activeAccount: account);
  }

  Future<void> logout([String? accountId]) async {
    final current = state;
    final targetId = accountId ?? current.activeAccount?.id;
    final accounts =
        current.accounts
            .where((ServerAccount item) => item.id != targetId)
            .toList();
    final active = accounts.isEmpty ? null : accounts.first;
    await _storage.saveAccounts(accounts);
    await _storage.saveActiveAccountId(active?.id);
    state = current.copyWith(
      accounts: accounts,
      activeAccount: active,
      clearActive: active == null,
    );
  }

  Future<void> saveRecentSearch(String value) async {
    final current = state;
    final normalized = value.trim();
    if (normalized.isEmpty) return;
    final updated =
        <String>[
          normalized,
          ...current.recentSearches.where(
            (String item) => item.toLowerCase() != normalized.toLowerCase(),
          ),
        ].take(8).toList();
    await _storage.saveRecentSearches(updated);
    state = current.copyWith(recentSearches: updated);
  }

  Future<void> clearRecentSearches() async {
    final current = state;
    await _storage.saveRecentSearches(<String>[]);
    state = current.copyWith(recentSearches: <String>[]);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
