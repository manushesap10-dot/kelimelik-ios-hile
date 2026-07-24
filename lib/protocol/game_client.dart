import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'codec.dart';

typedef FrameHandler = void Function(ProtoFrame frame);

/// TCP client for Kelimelik custom protocol (host 88.218.130.131:443).
class KelimelikClient {
  static const defaultHost = '88.218.130.131';
  static const defaultPort = 443;
  static const fallbackPort = 30443;

  Socket? _socket;
  final _parser = FrameParser();
  final _controllers = <String, StreamController<ProtoFrame>>{};
  final _all = StreamController<ProtoFrame>.broadcast();
  bool connected = false;

  Stream<ProtoFrame> get frames => _all.stream;

  Stream<ProtoFrame> on(String name) {
    return _controllers
        .putIfAbsent(name, () => StreamController<ProtoFrame>.broadcast())
        .stream;
  }

  Future<void> connect({String host = defaultHost, int port = defaultPort}) async {
    await disconnect();
    try {
      _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 8));
    } catch (_) {
      _socket = await Socket.connect(host, fallbackPort, timeout: const Duration(seconds: 8));
    }
    connected = true;
    _socket!.listen(
      (data) {
        _parser.add(Uint8List.fromList(data));
        for (final f in _parser.takeFrames()) {
          _all.add(f);
          _controllers.putIfAbsent(f.name, () => StreamController<ProtoFrame>.broadcast());
          if (!(_controllers[f.name]!.isClosed)) {
            _controllers[f.name]!.add(f);
          }
        }
      },
      onDone: () => connected = false,
      onError: (_) => connected = false,
      cancelOnError: true,
    );
  }

  Future<void> disconnect() async {
    connected = false;
    await _socket?.close();
    _socket = null;
  }

  void send(String name, [Uint8List? body]) {
    final sock = _socket;
    if (sock == null) throw StateError('not connected');
    sock.add(ProtoCodec.encodeFrame(name, body ?? Uint8List.fromList([0x00])));
  }

  void login({required int pid, required String passwordHex, int third = 432}) {
    final body = ProtoCodec.encList([
      ProtoCodec.encInt(pid),
      ProtoCodec.encStr(passwordHex),
      ProtoCodec.encInt(third),
    ]);
    send('GameModule_requestLogin', body);
  }

  /// Step 1 of email login: precheck that the account exists.
  void submitEmail(String email) {
    send('GameModule_requestCreateAccountSubmitEmail',
        ProtoCodec.encList([ProtoCodec.encStr(email.trim())]));
  }

  /// Step 2 of email login: send email + PLAINTEXT password.
  /// The server replies with a createAccountResponse carrying PID + password hash.
  void retrieveAccount(String email, String password) {
    send('GameModule_requestRetrieveAccount', ProtoCodec.encList([
      ProtoCodec.encStr(email.trim()),
      ProtoCodec.encStr(password),
    ]));
  }

  /// Full email + password login. Verified against the real client via RE:
  ///   1) requestCreateAccountSubmitEmail(email)  -> server confirms email exists
  ///   2) requestRetrieveAccount(email, password) -> server returns PID + hash
  ///   3) requestLogin(PID, hash, 432)            -> loginAccepted
  /// We never compute the hash ourselves; the server derives it and returns it.
  Future<EmailLoginResult> emailLogin(String email, String password,
      {int third = 432}) async {
    // 1) email precheck (best-effort; we don't depend on its exact response)
    submitEmail(email);
    await Future<void>.delayed(const Duration(milliseconds: 600));

    // 2) retrieve account -> find the frame that carries PID + 64-hex hash
    retrieveAccount(email, password);
    final resp = await waitForAny(
      (f) => _extractAccount(f) != null,
      timeout: const Duration(seconds: 12),
    );
    final acct = resp == null ? null : _extractAccount(resp);
    if (acct == null) {
      return EmailLoginResult(
          false, 0, '', 'Hesap bilgisi alinamadi (e-posta/sifre hatali olabilir).');
    }

    // 3) login with the server-provided PID + hash
    login(pid: acct.pid, passwordHex: acct.hash, third: third);
    final ok = await waitFor('GameModule_loginAccepted',
        timeout: const Duration(seconds: 10));
    if (ok == null) {
      return EmailLoginResult(
          false, acct.pid, acct.hash, 'Login zaman asimi (PID ${acct.pid}).');
    }
    return EmailLoginResult(true, acct.pid, acct.hash, 'Login OK',
        username: acct.username);
  }

  /// Parse a createAccountResponse-style frame into (PID, hash[64], username).
  /// Returns null if the frame does not contain a valid PID + 64-hex hash.
  _Account? _extractAccount(ProtoFrame f) {
    final vals = f.values;
    int pid = 0;
    String hash = '';
    String username = '';
    final hex64 = RegExp(r'^[0-9a-fA-F]{64}$');
    for (final v in vals) {
      if (v.type == 'int' && v.asInt > 0 && pid == 0) {
        pid = v.asInt;
      } else if (v.type == 'str') {
        final s = v.asStr;
        if (s.length == 64 && hex64.hasMatch(s)) {
          hash = s;
        } else if (username.isEmpty &&
            s.isNotEmpty &&
            !s.contains('@') &&
            s.length <= 32) {
          username = s;
        }
      }
    }
    if (pid > 0 && hash.isNotEmpty) return _Account(pid, hash, username);
    return null;
  }

  void updateDeviceInfo({String platform = 'ios', String deviceId = 'ios-hile-rebuild'}) {
    final body = ProtoCodec.encList([
      ProtoCodec.encStr(platform),
      ProtoCodec.encStr(deviceId),
    ]);
    send('GameModule_requestUpdateDeviceInfo', body);
  }

  void requestGameInfo(int gameId) {
    send('GameModule_requestGameInfo', ProtoCodec.encList([ProtoCodec.encInt(gameId)]));
  }

  /// Ask the server for the user's active games list.
  void requestUserGames() {
    send('GameModule_requestUserGamesList');
  }

  /// Confirmed working submit (Android RE):
  /// count=5, gameId, word, row, col, dir (0=H,1=V)
  void requestSubmitLetters({
    required int gameId,
    required String word,
    required int row,
    required int col,
    required int dir,
  }) {
    final body = ProtoCodec.encList([
      ProtoCodec.encInt(gameId),
      ProtoCodec.encStr(word.toLowerCase()),
      ProtoCodec.encInt(row),
      ProtoCodec.encInt(col),
      ProtoCodec.encInt(dir),
    ]);
    send('GameModule_requestSubmitLetters', body);
  }

  void ping() => send('GameModule_requestPing');

  Future<ProtoFrame?> waitFor(
    String name, {
    Duration timeout = const Duration(seconds: 12),
    bool Function(ProtoFrame f)? where,
  }) async {
    try {
      return await on(name)
          .where((f) => where == null || where(f))
          .first
          .timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  /// Wait for ANY incoming frame that satisfies [test], regardless of name.
  /// Useful when the exact response frame name is uncertain.
  Future<ProtoFrame?> waitForAny(
    bool Function(ProtoFrame f) test, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      return await frames.where(test).first.timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    disconnect();
    for (final c in _controllers.values) {
      c.close();
    }
    _all.close();
  }
}

/// Result of an email + password login attempt.
class EmailLoginResult {
  final bool ok;
  final int pid;
  final String hash;
  final String message;
  final String username;
  EmailLoginResult(this.ok, this.pid, this.hash, this.message,
      {this.username = ''});
}

class _Account {
  final int pid;
  final String hash;
  final String username;
  _Account(this.pid, this.hash, this.username);
}

class GameState {
  int gameId = 0;
  String rack = '';
  String board = '.' * 225;
  String lastMoveStr = '';
  DateTime updated = DateTime.fromMillisecondsSinceEpoch(0);

  bool get hasBoard => board.length == 225;

  void applyGameInfo(List<ProtoValue> vals) {
    var gid = 0;
    String rack = this.rack;
    String board = this.board;
    String last = lastMoveStr;
    for (var i = 0; i < vals.length; i++) {
      final v = vals[i];
      if (v.type == 'int' && gid == 0) gid = v.asInt;
      if (v.type == 'str') {
        final s = v.asStr;
        if (s.length == 225) {
          board = s;
        } else if (s.contains(',') && RegExp(r'\d').hasMatch(s)) {
          last = s;
        } else if (s.isNotEmpty && s.length <= 10) {
          rack = s;
        }
      }
    }
    if (gid != 0) gameId = gid;
    this.rack = rack;
    this.board = board;
    lastMoveStr = last;
    updated = DateTime.now();
  }
}
