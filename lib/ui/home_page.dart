import 'package:flutter/material.dart';

import '../services/hile_service.dart';
import '../solver/best_move.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final svc = HileService();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final gameIdCtrl = TextEditingController();
  final rackCtrl = TextEditingController();
  final boardCtrl = TextEditingController();
  String log = '';
  bool busy = false;
  bool obscure = true;
  List<Move> candidates = [];

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await svc.init();
    setState(() => log = svc.status);
  }

  void _syncFieldsFromState() {
    if (svc.state.gameId != 0) gameIdCtrl.text = '${svc.state.gameId}';
    if (svc.state.rack.isNotEmpty) rackCtrl.text = svc.state.rack;
    if (svc.state.hasBoard) boardCtrl.text = svc.state.board;
  }

  Future<void> _login() async {
    setState(() => busy = true);
    svc.email = emailCtrl.text.trim();
    svc.password = passwordCtrl.text;
    await svc.connectAndEmailLogin();
    _syncFieldsFromState();
    setState(() {
      log = svc.status;
      busy = false;
    });
  }

  Future<void> _refresh() async {
    setState(() => busy = true);
    final gid = int.tryParse(gameIdCtrl.text.trim());
    if (gid != null) svc.state.gameId = gid;
    await svc.refreshGame();
    _syncFieldsFromState();
    setState(() {
      log = svc.status;
      busy = false;
    });
  }

  Future<void> _solveOnly() async {
    setState(() => busy = true);
    await svc.init();
    final rack = rackCtrl.text.trim().isEmpty ? svc.state.rack : rackCtrl.text.trim();
    final board = boardCtrl.text.trim().isEmpty ? svc.state.board : boardCtrl.text.trim();
    candidates = svc.engine!.findBestMoves(rack, board, limit: 12);
    setState(() {
      log = candidates.isEmpty ? 'Hamle yok' : 'Aday: ${candidates.length} — best ${candidates.first}';
      busy = false;
    });
  }

  Future<void> _hile() async {
    setState(() => busy = true);
    // push field overrides
    final gid = int.tryParse(gameIdCtrl.text.trim());
    if (gid != null) svc.state.gameId = gid;
    if (rackCtrl.text.trim().isNotEmpty) svc.state.rack = rackCtrl.text.trim();
    if (boardCtrl.text.trim().length == 225) svc.state.board = boardCtrl.text.trim();

    final msg = await svc.autoPlay();
    _syncFieldsFromState();
    setState(() {
      log = msg;
      if (svc.lastMove != null) {
        candidates = [svc.lastMove!, ...candidates.where((m) => m != svc.lastMove)].take(12).toList();
      }
      busy = false;
    });
  }

  @override
  void dispose() {
    svc.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    gameIdCtrl.dispose();
    rackCtrl.dispose();
    boardCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelimelik iOS HILE'),
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('1) Giris (e-posta + sifre)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: emailCtrl,
            decoration: const InputDecoration(labelText: 'E-posta', border: OutlineInputBorder()),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: passwordCtrl,
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: 'Sifre',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => obscure = !obscure),
              ),
            ),
            onSubmitted: (_) => busy ? null : _login(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(onPressed: busy ? null : _login, child: const Text('Giris yap')),
              OutlinedButton(onPressed: busy ? null : _refresh, child: const Text('gameInfo yenile')),
            ],
          ),
          const Divider(height: 32),
          const Text('2) Oyun durumu', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: gameIdCtrl,
            decoration: const InputDecoration(labelText: 'gameId', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: rackCtrl,
            decoration: const InputDecoration(labelText: 'Rack (orn. naele#n)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: boardCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Board 225 karakter (opsiyonel — gameInfo doldurur)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          // Board preview
          if ((boardCtrl.text.length == 225) || svc.state.hasBoard)
            _BoardPreview(board: boardCtrl.text.length == 225 ? boardCtrl.text : svc.state.board),
          const Divider(height: 32),
          const Text('3) HILE', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: busy ? null : _solveOnly,
                  child: const Text('Sadece hesapla'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
                  onPressed: busy ? null : _hile,
                  child: const Text('HILE OYNAT'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(log.isEmpty ? '...' : log),
            ),
          ),
          if (busy) const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          ),
          const SizedBox(height: 12),
          ...candidates.map((m) => ListTile(
                dense: true,
                title: Text('${m.word.toUpperCase()}  ${m.score}p'),
                subtitle: Text('${m.dir} r${m.row + 1} c${m.col + 1} main=${m.main} x=${m.crosses.join(',')}'),
              )),
          const SizedBox(height: 24),
          const Text(
            'Not: Giris e-posta + sifre ile yapilir. Sunucu PID + hash uretir,\n'
            'istemci bunlarla oturum acar. IPA derlemesi Codemagic/Mac ister.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _BoardPreview extends StatelessWidget {
  final String board;
  const _BoardPreview({required this.board});

  @override
  Widget build(BuildContext context) {
    final b = board.length == 225 ? board : '.' * 225;
    return AspectRatio(
      aspectRatio: 1,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 15),
        itemCount: 225,
        itemBuilder: (_, i) {
          final ch = b[i];
          final filled = ch != '.';
          return Container(
            margin: const EdgeInsets.all(0.5),
            alignment: Alignment.center,
            color: filled ? Colors.amber.shade200 : Colors.grey.shade200,
            child: Text(
              filled ? ch.toUpperCase() : '',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }
}
