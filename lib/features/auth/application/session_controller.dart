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
    required this.recentLiveChannels,
    required this.favoriteLiveChannels,
    required this.pinnedItems,
  });

  final List<ServerAccount> accounts;
  final ServerAccount? activeAccount;
  final List<String> recentSearches;
  final List<String> recentLiveChannels;
  final List<String> favoriteLiveChannels;
  final List<String> pinnedItems;

  bool get isAuthenticated => activeAccount != null;

  SessionState copyWith({
    List<ServerAccount>? accounts,
    ServerAccount? activeAccount,
    bool clearActive = false,
    List<String>? recentSearches,
    List<String>? recentLiveChannels,
    List<String>? favoriteLiveChannels,
    List<String>? pinnedItems,
  }) {
    return SessionState(
      accounts: accounts ?? this.accounts,
      activeAccount: clearActive ? null : activeAccount ?? this.activeAccount,
      recentSearches: recentSearches ?? this.recentSearches,
      recentLiveChannels: recentLiveChannels ?? this.recentLiveChannels,
      favoriteLiveChannels: favoriteLiveChannels ?? this.favoriteLiveChannels,
      pinnedItems: pinnedItems ?? this.pinnedItems,
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
      recentLiveChannels: _storage.loadRecentLiveChannels(),
      favoriteLiveChannels: _storage.loadFavoriteLiveChannels(),
      pinnedItems: _storage.loadPinnedItems(),
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

  Future<void> addRecentLiveChannel(String itemId) async {
    final current = state;
    if (itemId.isEmpty) return;
    final updated =
        <String>[
          itemId,
          ...current.recentLiveChannels.where((String item) => item != itemId),
        ].take(8).toList();
    await _storage.saveRecentLiveChannels(updated);
    state = current.copyWith(recentLiveChannels: updated);
  }

  Future<void> toggleFavoriteLiveChannel(String itemId) async {
    final current = state;
    if (itemId.isEmpty) return;
    final exists = current.favoriteLiveChannels.contains(itemId);
    final updated =
        exists
            ? current.favoriteLiveChannels.where((String item) => item != itemId).toList()
            : <String>[itemId, ...current.favoriteLiveChannels].take(200).toList();
    await _storage.saveFavoriteLiveChannels(updated);
    state = current.copyWith(favoriteLiveChannels: updated);
  }

  Future<void> togglePinnedItem(String itemId) async {
    final current = state;
    if (itemId.isEmpty) return;
    final exists = current.pinnedItems.contains(itemId);
    final updated =
        exists
            ? current.pinnedItems.where((String item) => item != itemId).toList()
            : <String>[itemId, ...current.pinnedItems].take(100).toList();
    await _storage.savePinnedItems(updated);
    state = current.copyWith(pinnedItems: updated);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
