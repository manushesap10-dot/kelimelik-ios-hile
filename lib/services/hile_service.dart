import 'package:flutter/services.dart';

import '../protocol/game_client.dart';
import '../solver/best_move.dart';

/// Orchestrates login/gameInfo/solve/submit — port of Android HILE CLEAN logic.
class HileService {
  final KelimelikClient client = KelimelikClient();
  final GameState state = GameState();
  BestMoveEngine? engine;

  // Email + password login (preferred). Server derives PID + hash for us.
  String email = '';
  String password = '';

  // Advanced/manual fallback (filled automatically after a successful email login).
  int pid = 0;
  String passwordHex = '';
  int loginThird = 432;
  String username = '';

  String status = 'Hazir';
  Move? lastMove;
  final Map<int, DateTime> playedByGame = {};

  Future<void> init() async {
    final raw = await rootBundle.loadString('assets/data/wordlist.txt');
    engine = await BestMoveEngine.loadFromLines(raw.split(RegExp(r'\r?\n')));
    status = 'Sozluk: ${engine!.dict.length} kelime';
  }

  /// Preferred flow: connect + email/password login (email -> PID/hash -> login).
  Future<void> connectAndEmailLogin() async {
    status = 'Baglaniyor...';
    await client.connect();
    if (email.trim().isEmpty || password.isEmpty) {
      status = 'E-posta ve sifre girin';
      return;
    }
    status = 'Giris yapiliyor...';
    final res = await client.emailLogin(email.trim(), password, third: loginThird);
    if (!res.ok) {
      status = res.message;
      return;
    }
    pid = res.pid;
    passwordHex = res.hash;
    username = res.username;
    client.updateDeviceInfo(platform: 'ios', deviceId: 'kelimelik-ios-hile');
    status = 'Login OK — ${username.isEmpty ? 'PID $pid' : username}';
    _attachGameListeners();
    client.requestUserGames();
  }

  /// Manual fallback flow: connect + login with a raw PID + password hash.
  Future<void> connectAndLogin() async {
    status = 'Baglaniyor...';
    await client.connect();
    status = 'Login...';
    if (pid == 0 || passwordHex.isEmpty) {
      status = 'PID/sifre girin';
      return;
    }
    client.login(pid: pid, passwordHex: passwordHex, third: loginThird);
    final ok = await client.waitFor('GameModule_loginAccepted', timeout: const Duration(seconds: 10));
    if (ok == null) {
      status = 'Login basarisiz/timeout';
      return;
    }
    client.updateDeviceInfo(platform: 'ios', deviceId: 'kelimelik-ios-hile');
    status = 'Login OK';
    _attachGameListeners();
  }

  void _attachGameListeners() {
    client.on('GameModule_gameInfo').listen((f) {
      state.applyGameInfo(f.values);
      status = 'gameInfo gid=${state.gameId} rack=${state.rack}';
    });
    client.on('GameModule_wordSubmitAccepted').listen((f) {
      status = 'SUNUCU ONAY: wordSubmitAccepted';
      if (state.gameId != 0) playedByGame[state.gameId] = DateTime.now();
    });
    client.on('GameModule_spawnNewLetters').listen((f) {
      status = 'spawnNewLetters';
      for (final v in f.values) {
        if (v.type == 'str' && v.asStr.length <= 10) state.rack = v.asStr;
      }
    });
    client.on('GameModule_newTurn').listen((_) {
      status = 'newTurn';
    });
    client.on('GameModule_submitError').listen((_) {
      status = 'submitError (sira/oturum?)';
    });
    client.on('GameModule_wordNotFound').listen((f) {
      status = 'wordNotFound ${f.values.map((e) => e.value).join(',')}';
    });
  }

  Future<void> refreshGame([int? gameId]) async {
    final gid = gameId ?? state.gameId;
    if (gid == 0) {
      status = 'gameId yok';
      return;
    }
    client.requestGameInfo(gid);
    final f = await client.waitFor('GameModule_gameInfo', timeout: const Duration(seconds: 8));
    if (f != null) state.applyGameInfo(f.values);
  }

  /// One clean autoplay: solve best + single submit (dir flip only on wordNotFound).
  Future<String> autoPlay() async {
    if (engine == null) await init();
    if (!client.connected) {
      return 'Bagli degil — once login';
    }
    if (state.gameId == 0 || !state.hasBoard || state.rack.isEmpty) {
      return 'Oyun verisi yok — gameId/rack/board gerekli';
    }
    final lock = playedByGame[state.gameId];
    if (lock != null && DateTime.now().difference(lock) < const Duration(minutes: 3)) {
      return 'Bu oyunda bu turda hamle yapildi. Rakibi bekle.';
    }

    status = 'Hamle hesaplaniyor...';
    final moves = engine!.findBestMoves(state.rack, state.board, limit: 15);
    if (moves.isEmpty) {
      status = 'Gecerli hamle yok';
      return status;
    }
    final best = moves.first;
    lastMove = best;
    status = 'Gonderiliyor: $best';

    // try preferred dir then optional flip on wordNotFound only
    for (final dir in [best.dirInt, best.dirInt == 0 ? 1 : 0]) {
      client.requestSubmitLetters(
        gameId: state.gameId,
        word: best.word,
        row: best.row,
        col: best.col,
        dir: dir,
      );

      // race wait for accept/fail
      final result = await Future.any([
        client.waitFor('GameModule_wordSubmitAccepted', timeout: const Duration(seconds: 20)).then((f) => f == null ? null : 'ok'),
        client.waitFor('GameModule_spawnNewLetters', timeout: const Duration(seconds: 20)).then((f) => f == null ? null : 'ok'),
        client.waitFor('GameModule_newTurn', timeout: const Duration(seconds: 20)).then((f) => f == null ? null : 'ok'),
        client.waitFor('GameModule_wordNotFound', timeout: const Duration(seconds: 20)).then((f) => f == null ? null : 'notfound'),
        client.waitFor('GameModule_submitError', timeout: const Duration(seconds: 20)).then((f) => f == null ? null : 'error'),
      ]);

      if (result == 'ok') {
        playedByGame[state.gameId] = DateTime.now();
        status = 'ONAYLANDI: ${best.word.toUpperCase()} ${best.score}p';
        await refreshGame();
        return status;
      }
      if (result == 'error') {
        status = 'submitError — sira/oturum';
        return status;
      }
      if (result == 'notfound') {
        // try flip once
        continue;
      }
      // timeout — check board change
      final before = state.lastMoveStr;
      await refreshGame();
      if (state.lastMoveStr != before || state.board.contains(best.word)) {
        playedByGame[state.gameId] = DateTime.now();
        status = 'ONAY (board degisti): ${best.word}';
        return status;
      }
      status = 'Timeout / kabul yok';
      return status;
    }
    status = 'Kabul edilmedi';
    return status;
  }

  void dispose() => client.dispose();
}
