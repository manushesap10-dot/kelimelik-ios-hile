import 'dart:convert';
import 'dart:typed_data';

/// Kelimelik binary protocol codec (RE from Android client).
/// Frame: [u32be payload_len][u16be name_len][name_utf8][body]
/// Body list: [u8 count][typed values...]
///  0x00 + u32be int
///  0x07 + u16be len + utf8 string
///  0x01 / 0x02 bool true/false
class ProtoCodec {
  static Uint8List u16be(int n) =>
      Uint8List.fromList([(n >> 8) & 0xff, n & 0xff]);

  static Uint8List u32be(int n) {
    final v = n & 0xffffffff;
    return Uint8List.fromList([
      (v >> 24) & 0xff,
      (v >> 16) & 0xff,
      (v >> 8) & 0xff,
      v & 0xff,
    ]);
  }

  static Uint8List encInt(int n) =>
      Uint8List.fromList([0x00, ...u32be(n)]);

  static Uint8List encStr(String s) {
    final b = utf8.encode(s);
    return Uint8List.fromList([0x07, ...u16be(b.length), ...b]);
  }

  static Uint8List encBool(bool v) => Uint8List.fromList([v ? 0x01 : 0x02]);

  static Uint8List encList(List<Uint8List> items) {
    final out = BytesBuilder();
    out.addByte(items.length);
    for (final it in items) {
      out.add(it);
    }
    return out.toBytes();
  }

  static Uint8List encodeFrame(String name, Uint8List body) {
    final nb = utf8.encode(name);
    final payload = BytesBuilder();
    payload.add(u16be(nb.length));
    payload.add(nb);
    payload.add(body.isEmpty ? Uint8List.fromList([0x00]) : body);
    final p = payload.toBytes();
    return Uint8List.fromList([...u32be(p.length), ...p]);
  }

  static List<ProtoValue> parseBody(Uint8List body) {
    if (body.isEmpty) return [];
    final count = body[0];
    var i = 1;
    final vals = <ProtoValue>[];
    for (var n = 0; n < count && i < body.length; n++) {
      final tag = body[i];
      if (tag == 0x00 && i + 5 <= body.length) {
        final v = ((body[i + 1] << 24) |
                (body[i + 2] << 16) |
                (body[i + 3] << 8) |
                body[i + 4]) >>>
            0;
        vals.add(ProtoValue.intVal(v));
        i += 5;
      } else if (tag == 0x07 && i + 3 <= body.length) {
        final ln = (body[i + 1] << 8) | body[i + 2];
        i += 3;
        final end = (i + ln).clamp(0, body.length);
        final s = utf8.decode(body.sublist(i, end), allowMalformed: true);
        i = end;
        vals.add(ProtoValue.strVal(s));
      } else if (tag == 0x01 || tag == 0x02) {
        vals.add(ProtoValue.boolVal(tag == 0x01));
        i += 1;
      } else {
        break;
      }
    }
    return vals;
  }
}

class ProtoValue {
  final String type; // int|str|bool
  final dynamic value;
  ProtoValue._(this.type, this.value);
  factory ProtoValue.intVal(int v) => ProtoValue._('int', v);
  factory ProtoValue.strVal(String v) => ProtoValue._('str', v);
  factory ProtoValue.boolVal(bool v) => ProtoValue._('bool', v);
  int get asInt => value as int;
  String get asStr => value as String;
  bool get asBool => value as bool;
}

class ProtoFrame {
  final String name;
  final Uint8List body;
  ProtoFrame(this.name, this.body);
  List<ProtoValue> get values => ProtoCodec.parseBody(body);
}

/// Streaming frame parser for TCP bytes.
class FrameParser {
  final BytesBuilder _buf = BytesBuilder(copy: false);

  void add(Uint8List chunk) => _buf.add(chunk);

  List<ProtoFrame> takeFrames() {
    final data = _buf.toBytes();
    var o = 0;
    final frames = <ProtoFrame>[];
    while (o + 4 <= data.length) {
      final plen = ((data[o] << 24) |
              (data[o + 1] << 16) |
              (data[o + 2] << 8) |
              data[o + 3]) >>>
          0;
      if (plen <= 0 || plen > 2000000) break;
      if (o + 4 + plen > data.length) break;
      final payload = data.sublist(o + 4, o + 4 + plen);
      o += 4 + plen;
      if (payload.length < 3) continue;
      final nlen = (payload[0] << 8) | payload[1];
      if (nlen <= 0 || nlen >= 300 || 2 + nlen > payload.length) continue;
      final name = utf8.decode(payload.sublist(2, 2 + nlen), allowMalformed: true);
      final body = payload.sublist(2 + nlen);
      frames.add(ProtoFrame(name, Uint8List.fromList(body)));
    }
    // keep remainder
    _buf.clear();
    if (o < data.length) _buf.add(data.sublist(o));
    return frames;
  }
}
