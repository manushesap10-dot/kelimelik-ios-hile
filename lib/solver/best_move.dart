import 'dart:collection';

/// Turkish Kelimelik / Scrabble-like best move search (ported from Android RE).
class BestMoveEngine {
  static const boardSize = 15;
  static const center = 7;
  static const empty = '.';

  static const letterScores = <String, int>{
    'a': 1, 'b': 3, 'c': 4, 'ç': 4, 'd': 3, 'e': 1, 'f': 7, 'g': 5, 'ğ': 8,
    'h': 5, 'ı': 2, 'i': 1, 'j': 10, 'k': 1, 'l': 1, 'm': 2, 'n': 1, 'o': 2,
    'ö': 7, 'p': 5, 'r': 1, 's': 2, 'ş': 4, 't': 1, 'u': 2, 'ü': 3, 'v': 7,
    'y': 3, 'z': 4, '#': 0, '*': 0,
  };

  static final List<List<String>> premiums = _buildPremiums();

  static List<List<String>> _buildPremiums() {
    final m = List.generate(boardSize, (_) => List.filled(boardSize, ''));
    void set(List<List<int>> pts, String t) {
      for (final p in pts) {
        m[p[0]][p[1]] = t;
      }
    }

    set([
      [0, 0], [0, 7], [0, 14], [7, 0], [7, 14], [14, 0], [14, 7], [14, 14]
    ], 'TW');
    set([
      [1, 1], [2, 2], [3, 3], [4, 4], [1, 13], [2, 12], [3, 11], [4, 10],
      [13, 1], [12, 2], [11, 3], [10, 4], [13, 13], [12, 12], [11, 11], [10, 10], [7, 7]
    ], 'DW');
    set([
      [1, 5], [1, 9], [5, 1], [5, 5], [5, 9], [5, 13], [9, 1], [9, 5], [9, 9], [9, 13], [13, 5], [13, 9]
    ], 'TL');
    set([
      [0, 3], [0, 11], [2, 6], [2, 8], [3, 0], [3, 7], [3, 14], [6, 2], [6, 6], [6, 8], [6, 12],
      [7, 3], [7, 11], [8, 2], [8, 6], [8, 8], [8, 12], [11, 0], [11, 7], [11, 14], [12, 6], [12, 8], [14, 3], [14, 11]
    ], 'DL');
    return m;
  }

  static const alphabet = [
    'a', 'b', 'c', 'ç', 'd', 'e', 'f', 'g', 'ğ', 'h', 'ı', 'i', 'j', 'k', 'l', 'm',
    'n', 'o', 'ö', 'p', 'r', 's', 'ş', 't', 'u', 'ü', 'v', 'y', 'z'
  ];

  final Set<String> dict;
  BestMoveEngine(this.dict);

  static Future<BestMoveEngine> loadFromLines(Iterable<String> lines) async {
    final d = <String>{};
    for (final line in lines) {
      final w = line.trim().toLowerCase();
      if (w.length >= 2) d.add(w);
    }
    return BestMoveEngine(d);
  }

  List<Move> findBestMoves(String rack, String board, {int limit = 20}) {
    rack = rack.toLowerCase().replaceAll('*', '#');
    if (board.length != 225) board = empty * 225;
    board = board.toLowerCase();

    final cells = List.generate(boardSize, (r) => List.generate(boardSize, (c) => board[r * boardSize + c]));
    final emptyBoard = board.split('').every((c) => c == empty);
    final letters = rack.split('').where((c) => c.isNotEmpty).toList();
    final nonJoker = letters.where((c) => c != '#').toList();
    final blanks = letters.where((c) => c == '#').length;

    final moves = <Move>[];
    final maxL = letters.length.clamp(0, 7);

    for (var L = maxL; L >= 2; L--) {
      if (L > nonJoker.length + blanks) continue;
      final perms = _uniquePerms(letters, L);
      for (final w in perms) {
        if (!dict.contains(w)) continue;
        // horizontal
        for (var r = 0; r < boardSize; r++) {
          for (var c = 0; c <= boardSize - L; c++) {
            final m = _tryPlace(cells, w, r, c, true, emptyBoard);
            if (m != null) moves.add(m);
          }
        }
        // vertical
        for (var c = 0; c < boardSize; c++) {
          for (var r = 0; r <= boardSize - L; r++) {
            final m = _tryPlace(cells, w, r, c, false, emptyBoard);
            if (m != null) moves.add(m);
          }
        }
      }
      if (moves.length >= 80) break;
    }

    moves.sort((a, b) {
      final s = b.score.compareTo(a.score);
      if (s != 0) return s;
      final n = b.newCount.compareTo(a.newCount);
      if (n != 0) return n;
      return b.word.length.compareTo(a.word.length);
    });

    // unique
    final seen = <String>{};
    final uniq = <Move>[];
    for (final m in moves) {
      final k = '${m.word}|${m.dir}|${m.row}|${m.col}|${m.main}';
      if (seen.add(k)) uniq.add(m);
      if (uniq.length >= limit) break;
    }
    return uniq;
  }

  Move? findBest(String rack, String board) {
    final ms = findBestMoves(rack, board, limit: 1);
    return ms.isEmpty ? null : ms.first;
  }

  List<String> _uniquePerms(List<String> letters, int L) {
    final out = <String>{};
    final used = List.filled(letters.length, false);
    final path = <String>[];

    void rec() {
      if (path.length == L) {
        out.add(path.join());
        return;
      }
      for (var i = 0; i < letters.length; i++) {
        if (used[i]) continue;
        used[i] = true;
        final ch = letters[i];
        if (ch == '#' || ch == '*') {
          for (final a in alphabet) {
            path.add(a);
            rec();
            path.removeLast();
          }
        } else {
          path.add(ch);
          rec();
          path.removeLast();
        }
        used[i] = false;
      }
    }

    rec();
    return out.toList();
  }

  bool _canForm(List<String> need, List<String> rack) {
    final used = List<String>.from(rack);
    for (final ch in need) {
      var idx = used.indexOf(ch);
      if (idx < 0) {
        idx = used.indexOf('#');
        if (idx < 0) idx = used.indexOf('*');
        if (idx < 0) return false;
      }
      used.removeAt(idx);
    }
    return true;
  }

  String _readHoriz(List<List<String>> B, int r, int c) {
    var c0 = c;
    while (c0 > 0 && B[r][c0 - 1] != empty) {
      c0--;
    }
    var c1 = c;
    while (c1 < boardSize - 1 && B[r][c1 + 1] != empty) {
      c1++;
    }
    final sb = StringBuffer();
    for (var cc = c0; cc <= c1; cc++) {
      sb.write(B[r][cc]);
    }
    return sb.toString();
  }

  String _readVert(List<List<String>> B, int r, int c) {
    var r0 = r;
    while (r0 > 0 && B[r0 - 1][c] != empty) {
      r0--;
    }
    var r1 = r;
    while (r1 < boardSize - 1 && B[r1 + 1][c] != empty) {
      r1++;
    }
    final sb = StringBuffer();
    for (var rr = r0; rr <= r1; rr++) {
      sb.write(B[rr][c]);
    }
    return sb.toString();
  }

  Move? _tryPlace(List<List<String>> B, String word, int row, int col, bool across, bool emptyBoard) {
    final L = word.length;
    if (across) {
      if (col < 0 || col + L > boardSize || row < 0 || row >= boardSize) return null;
    } else {
      if (row < 0 || row + L > boardSize || col < 0 || col >= boardSize) return null;
    }

    final need = <String>[];
    final newMask = <bool>[];
    var touchesExisting = false;
    var coversCenter = false;

    for (var i = 0; i < L; i++) {
      final r = across ? row : row + i;
      final c = across ? col + i : col;
      final cur = B[r][c];
      if (cur == empty) {
        need.add(word[i]);
        newMask.add(true);
      } else if (cur == word[i]) {
        newMask.add(false);
        touchesExisting = true;
      } else {
        return null;
      }
      if (r == center && c == center) coversCenter = true;
    }
    if (need.isEmpty) return null;

    // rack formability checked via original rack string reconstruction is external;
    // caller filters perms from rack so need is formable by construction of perms.

    if (emptyBoard) {
      if (!coversCenter) return null;
    } else {
      if (!touchesExisting) {
        var adj = false;
        for (var i = 0; i < L; i++) {
          if (!newMask[i]) continue;
          final r2 = across ? row : row + i;
          final c2 = across ? col + i : col;
          for (final d in const [
            [1, 0],
            [-1, 0],
            [0, 1],
            [0, -1]
          ]) {
            final rr = r2 + d[0];
            final cc = c2 + d[1];
            if (rr < 0 || rr >= boardSize || cc < 0 || cc >= boardSize) continue;
            if (B[rr][cc] == empty) continue;
            var part = false;
            for (var k = 0; k < L; k++) {
              final r3 = across ? row : row + k;
              final c3 = across ? col + k : col;
              if (r3 == rr && c3 == cc) {
                part = true;
                break;
              }
            }
            if (!part) adj = true;
          }
        }
        if (!adj) return null;
      }
    }

    // place
    final changed = <List<dynamic>>[];
    for (var i = 0; i < L; i++) {
      if (!newMask[i]) continue;
      final r = across ? row : row + i;
      final c = across ? col + i : col;
      changed.add([r, c, B[r][c]]);
      B[r][c] = word[i];
    }

    final main = across ? _readHoriz(B, row, col) : _readVert(B, row, col);
    var ok = dict.contains(main);
    final crosses = <String>[];
    if (ok) {
      for (var i = 0; i < L; i++) {
        if (!newMask[i]) continue;
        final r = across ? row : row + i;
        final c = across ? col + i : col;
        final cw = across ? _readVert(B, r, c) : _readHoriz(B, r, c);
        if (cw.length > 1) {
          if (!dict.contains(cw)) {
            ok = false;
            crosses.add(cw);
            break;
          }
          crosses.add(cw);
        }
      }
    }

    var score = 0;
    if (ok) {
      var total = 0;
      var wm = 1;
      var nc = 0;
      for (var i = 0; i < L; i++) {
        final r = across ? row : row + i;
        final c = across ? col + i : col;
        var p = letterScores[word[i]] ?? 0;
        if (newMask[i]) {
          nc++;
          final pr = premiums[r][c];
          if (pr == 'DL') {
            p *= 2;
          } else if (pr == 'TL') {
            p *= 3;
          } else if (pr == 'DW') {
            wm *= 2;
          } else if (pr == 'TW') {
            wm *= 3;
          }
        }
        total += p;
      }
      score = total * wm;
      for (final cw in crosses) {
        for (var j = 0; j < cw.length; j++) {
          score += letterScores[cw[j]] ?? 0;
        }
      }
      if (nc == 7) score += 50;
    }

    // revert
    for (final ch in changed) {
      B[ch[0] as int][ch[1] as int] = ch[2] as String;
    }
    if (!ok) return null;

    return Move(
      word: word,
      main: main,
      row: row,
      col: col,
      horizontal: across,
      score: score,
      newCount: need.length,
      crosses: crosses,
    );
  }
}

class Move {
  final String word;
  final String main;
  final int row;
  final int col;
  final bool horizontal;
  final int score;
  final int newCount;
  final List<String> crosses;

  Move({
    required this.word,
    required this.main,
    required this.row,
    required this.col,
    required this.horizontal,
    required this.score,
    required this.newCount,
    required this.crosses,
  });

  String get dir => horizontal ? 'H' : 'V';
  int get dirInt => horizontal ? 0 : 1;

  @override
  String toString() =>
      '$word ($main) $dir r${row + 1}c${col + 1} =$score new=$newCount x=$crosses';
}
