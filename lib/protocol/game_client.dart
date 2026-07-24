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

  void dispose() {
    disconnect();
    for (final c in _controllers.values) {
      c.close();
    }
    _all.close();
  }
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
