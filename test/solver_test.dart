import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelik_ios_hile/solver/best_move.dart';

void main() {
  test('empty board first move covers center', () {
    final eng = BestMoveEngine({'el', 'le', 'kelime', 'masa', 'at'});
    final board = '.' * 225;
    final moves = eng.findBestMoves('kelime', board, limit: 5);
    expect(moves, isNotEmpty);
    final m = moves.first;
    // must cover center 7,7
    var covers = false;
    for (var i = 0; i < m.word.length; i++) {
      final r = m.horizontal ? m.row : m.row + i;
      final c = m.horizontal ? m.col + i : m.col;
      if (r == 7 && c == 7) covers = true;
    }
    expect(covers, isTrue);
  });
}
