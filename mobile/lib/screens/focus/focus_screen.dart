import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../providers/pet_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/session_provider.dart';
import '../../repositories/session_repository.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  static const _options = [10, 15, 25, 45, 60];

  FocusSessionInfo? _active;
  DateTime? _startedAt; // display clock only; the server decides the real time
  Timer? _ticker;
  int _planned = 25;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // If the app was closed during a session, pick it up again.
  Future<void> _restore() async {
    try {
      final s = await ref.read(sessionRepositoryProvider).fetchActive();
      if (s != null) _begin(s, s.startedAt);
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _begin(FocusSessionInfo s, DateTime startedAt) {
    _active = s;
    _startedAt = startedAt;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_active != null && _remaining <= 0 && !_busy) _finish(auto: true);
    });
  }

  int get _elapsed => DateTime.now().difference(_startedAt!).inSeconds;
  int get _remaining => (_active!.plannedMinutes * 60) - _elapsed;

  String _clock(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = await ref.read(sessionRepositoryProvider).start(_planned);
      _begin(s, DateTime.now());
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _finish({bool auto = false}) async {
    if (!auto && _elapsed < 10 * 60) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Finish early?'),
          content: const Text(
              'Sessions shorter than 10 minutes earn no XP. Finish anyway?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep going')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Finish')),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _busy = true);
    try {
      final result =
          await ref.read(sessionRepositoryProvider).finish(_active!.id);
      _ticker?.cancel();
      _active = null;
      ref.invalidate(progressProvider);
      ref.invalidate(petProvider);
      if (mounted) {
        setState(() => _busy = false);
        await _showResult(result);
      }
    } on ApiException catch (e) {
      // 409 means the session is already over; show the setup screen again.
      if (e.statusCode == 409) {
        _ticker?.cancel();
        _active = null;
      }
      _error = e.message;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel session?'),
        content: const Text('You will not earn any XP for this session.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep going')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel session')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(sessionRepositoryProvider).cancel(_active!.id);
      _ticker?.cancel();
      _active = null;
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _showResult(Map<String, dynamic> r) async {
    final xp = r['xp_awarded'] as int;
    final progress = (r['progress'] as Map).cast<String, dynamic>();
    final pet = (r['pet'] as Map).cast<String, dynamic>();
    final minutes = (r['session'] as Map)['duration_minutes'];

    final lines = <String>[
      '$minutes minutes studied',
      if (xp > 0) '+$xp XP' else 'No XP (sessions need at least 10 minutes)',
      if (r['capped'] == true) 'Daily XP cap reached',
      'Level ${progress['level']} · ${progress['current_streak']}-day streak',
      if (pet['evolved'] == true) '${pet['name']} evolved into a ${pet['stage']}!',
    ];

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Session complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(l),
              ),
          ],
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Nice!')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Focus')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: _active == null ? _setup(scheme) : _running(scheme),
            ),
    );
  }

  Widget _setup(ColorScheme scheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('How long will you focus?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            for (final m in _options)
              ChoiceChip(
                label: Text('$m min'),
                selected: _planned == m,
                onSelected: (_) => setState(() => _planned = m),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Sessions of 10 minutes or more earn XP.',
            textAlign: TextAlign.center),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.error)),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _busy ? null : _start,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start focus'),
        ),
      ],
    );
  }

  Widget _running(ColorScheme scheme) {
    final total = _active!.plannedMinutes * 60;
    final progress = (_elapsed / total).clamp(0.0, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
                Text(_clock(_remaining),
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('${_active!.plannedMinutes}-minute session',
            textAlign: TextAlign.center),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.error)),
        ],
        const SizedBox(height: 32),
        FilledButton(
          onPressed: _busy ? null : () => _finish(),
          child: const Text('Finish'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _busy ? null : _cancel,
          child: const Text('Cancel session'),
        ),
      ],
    );
  }
}
