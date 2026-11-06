
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../core/token_storage.dart';
import '../../providers/progress_provider.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() =>
      _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen>
    with WidgetsBindingObserver {
  static const List<int> _presets = [25, 45, 60];

  late final ApiService _api = ApiService(TokenStorage());

  Timer? _ticker;
  DateTime? _endsAt;

  Duration _duration = const Duration(minutes: 25);
  Duration _remaining = const Duration(minutes: 25);

  int? _sessionId;
  bool _isRunning = false;
  bool _isFinished = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _restoreActiveSession();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.resumed) {
      _restoreActiveSession();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    return Map<String, dynamic>.from(value as Map);
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  void _showError(Object error) {
    if (!mounted) return;

    final message = error is ApiException
        ? error.message
        : error is FormatException
            ? error.message
            : 'Unable to contact the Focus server. '
                'Please try again.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Synchronize the timer with Laravel.
  void _applySession(Map<String, dynamic> response) {
    final rawSession = response['session'];

    if (rawSession is! Map) {
      throw const FormatException(
        'Laravel did not return a valid focus session.',
      );
    }

    final session = _asMap(rawSession);

    final id = _asInt(session['id']);
    final minutes = _asInt(
      session['planned_minutes'],
    );

    final status =
        session['status']?.toString() ?? '';

    if (id <= 0 ||
        minutes <= 0 ||
        (status != 'active' && status != 'paused')) {
      throw const FormatException(
        'Laravel returned invalid focus session details.',
      );
    }

    // FIX 1:
    // A missing remaining_seconds value is NOT zero.
    // Reject missing or invalid timer data.
    final rawSeconds = response['remaining_seconds'];

    final int? remainingSeconds = rawSeconds is int
        ? rawSeconds
        : int.tryParse(
            rawSeconds?.toString() ?? '',
          );

    if (remainingSeconds == null ||
        remainingSeconds < 0 ||
        remainingSeconds > minutes * 60) {
      throw const FormatException(
        'Laravel returned missing or invalid '
        'remaining_seconds. Check the pause-aware '
        'FocusSessionController.',
      );
    }

    if (!mounted) return;

    _ticker?.cancel();

    final remaining = Duration(
      seconds: remainingSeconds,
    );

    // FIX 2:
    // An expired restored session will NOT automatically
    // display a congratulations popup.
    // The student can press Finish Session instead.
    final running =
        status == 'active' &&
        remaining > Duration.zero;

    setState(() {
      _sessionId = id;
      _duration = Duration(minutes: minutes);
      _remaining = remaining;

      _isRunning = running;
      _isFinished = false;

      _endsAt = running
          ? DateTime.now().add(remaining)
          : null;

      _busy = false;
    });

    if (running) {
      _beginTicker();
    }
  }

  // Restore an active or paused focus session.
  Future<void> _restoreActiveSession() async {
    if (!mounted || _busy) return;

    setState(() => _busy = true);

    try {
      final response = _asMap(
        await _api.get('/sessions/active'),
      );

      if (!mounted) return;

      if (response['session'] == null) {
        _ticker?.cancel();

        setState(() {
          _sessionId = null;
          _isRunning = false;
          _isFinished = false;
          _endsAt = null;
          _remaining = _duration;
          _busy = false;
        });
      } else {
        _applySession(response);
      }
    } catch (error) {
      if (!mounted) return;

      setState(() => _busy = false);
      _showError(error);
    }
  }

  // Start updating the local countdown.
  void _beginTicker() {
    _ticker?.cancel();

    _ticker = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _updateRemaining(),
    );
  }

  // Start a new session or resume a paused one.
  
Future<void> _startTimer() async {
  if (_busy || _isRunning) return;

  // If the countdown has reached zero,
  // finish the existing session instead.
  if (_sessionId != null &&
      _remaining <= Duration.zero) {
    await _finishTimer();
    return;
  }

  setState(() {
    _busy = true;
  });

  try {
    // =========================================
    // EXISTING SESSION: CHECK LARAVEL FIRST
    // =========================================

    if (_sessionId != null) {
      final currentResponse = _asMap(
        await _api.get('/sessions/active'),
      );

      if (!mounted) return;

      final rawSession = currentResponse['session'];

      // The previous session no longer exists.
      if (rawSession == null) {
        _ticker?.cancel();

        setState(() {
          _sessionId = null;
          _isRunning = false;
          _isFinished = false;
          _endsAt = null;
          _remaining = _duration;
          _busy = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your previous session has ended. '
              'Press Start Focus to begin a new one.',
            ),
          ),
        );

        return;
      }

      final serverSession = _asMap(rawSession);

      final serverStatus =
          serverSession['status']?.toString() ?? '';

      final serverId = _asInt(
        serverSession['id'],
      );

      // CASE 1:
      // Laravel says the session is already active.
      // Don't call resume again; restore its countdown.
      if (serverStatus == 'active') {
        _applySession(currentResponse);
        return;
      }

      // CASE 2:
      // Laravel confirms the session is paused.
      // It is safe to resume.
      if (serverStatus == 'paused') {
        final resumedResponse = _asMap(
          await _api.patch(
            '/sessions/$serverId/resume',
          ),
        );

        if (!mounted) return;

        _applySession(resumedResponse);
        return;
      }

      throw const FormatException(
        'The session cannot be resumed '
        'because it has already ended.',
      );
    }

    // =========================================
    // NEW SESSION: START ON LARAVEL
    // =========================================

    final response = _asMap(
      await _api.post(
        '/sessions',
        data: {
          'planned_minutes': _duration.inMinutes,
        },
      ),
    );

    if (!mounted) return;

    // Verify that Laravel returned a proper
    // remaining_seconds value.
    final rawSeconds = response['remaining_seconds'];

    final remainingSeconds = rawSeconds is int
        ? rawSeconds
        : int.tryParse(
            rawSeconds?.toString() ?? '',
          );

    if (remainingSeconds == null ||
        remainingSeconds <= 0) {
      throw const FormatException(
        'Laravel returned invalid remaining time. '
        'Please check the Focus Session backend.',
      );
    }

    // Start the countdown only after receiving
    // valid session information from Laravel.
    _applySession(response);
  } on ApiException catch (error) {
    if (!mounted) return;

    setState(() {
      _busy = false;
    });

    // If the session changed status while the
    // request was processing, sync it again.
    if (error.statusCode == 409) {
      await _restoreActiveSession();
    } else {
      _showError(error);
    }
  } catch (error) {
    if (!mounted) return;

    setState(() {
      _busy = false;
    });

    _showError(error);
  }
}


  // Update the countdown using real clock time
  // so the timer does not drift.
  void _updateRemaining() {
    if (!mounted ||
        !_isRunning ||
        _endsAt == null ||
        _busy) {
      return;
    }

    final milliseconds = _endsAt!
        .difference(DateTime.now())
        .inMilliseconds;

    if (milliseconds <= 0) {
      _ticker?.cancel();

      setState(() {
        _remaining = Duration.zero;
        _isRunning = false;
        _endsAt = null;
      });

      // Only finish after a real countdown reaches zero.
      unawaited(_finishTimer());
      return;
    }

    final updated = Duration(
      seconds: (milliseconds / 1000).ceil(),
    );

    if (updated != _remaining) {
      setState(() {
        _remaining = updated;
      });
    }
  }

  // Pause the session on the Laravel server.
  Future<void> _pauseTimer() async {
    if (_busy ||
        !_isRunning ||
        _sessionId == null) {
      return;
    }

    setState(() => _busy = true);

    try {
      final response = _asMap(
        await _api.patch(
          '/sessions/$_sessionId/pause',
        ),
      );

      if (!mounted) return;

      _applySession(response);
    } catch (error) {
      if (!mounted) return;

      setState(() => _busy = false);
      _showError(error);
    }
  }

  // Reset cancels the Laravel session without XP.
  Future<void> _resetTimer() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      if (_sessionId != null) {
        await _api.patch(
          '/sessions/$_sessionId/cancel',
        );
      }

      if (!mounted) return;

      _ticker?.cancel();

      setState(() {
        _sessionId = null;
        _remaining = _duration;
        _isRunning = false;
        _isFinished = false;
        _endsAt = null;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _busy = false);
      _showError(error);
    }
  }

  // Finish the session and receive XP from Laravel.
  Future<void> _finishTimer() async {
    if (_busy || _sessionId == null) return;

    _ticker?.cancel();

    setState(() {
      _busy = true;
      _isRunning = false;
      _endsAt = null;
    });

    try {
      final response = _asMap(
        await _api.patch(
          '/sessions/$_sessionId/finish',
        ),
      );

      if (!mounted) return;

      final xpEarned = _asInt(
        response['xp_earned'],
      );

      final durationMinutes = _asInt(
        response['duration_minutes'],
      );

      // Update the Home Dashboard XP.
      ref.invalidate(progressProvider);

      setState(() {
        _sessionId = null;
        _remaining = Duration.zero;
        _isFinished = true;
        _busy = false;
      });

      await _showCompletionDialog(
        xpEarned: xpEarned,
        durationMinutes: durationMinutes,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _busy = false);
      _showError(error);
    }
  }

  // Change the selected duration.
  void _selectDuration(int minutes) {
    if (_busy || _sessionId != null) return;

    _ticker?.cancel();

    setState(() {
      _duration = Duration(minutes: minutes);
      _remaining = _duration;
      _isRunning = false;
      _isFinished = false;
      _endsAt = null;
    });
  }

  // Custom duration dialog.
  Future<void> _chooseCustomDuration() async {
    if (_busy || _sessionId != null) return;

    final formKey = GlobalKey<FormState>();
    int selectedMinutes = _duration.inMinutes;

    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        void submit() {
          final form = formKey.currentState;

          if (form == null || !form.validate()) {
            return;
          }

          form.save();

          Navigator.of(dialogContext).pop(
            selectedMinutes,
          );
        }

        return AlertDialog(
          backgroundColor: GalaxyColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(
              color: GalaxyColors.purple,
              width: 1.2,
            ),
          ),
          title: const Text(
            'Custom Focus Duration',
            style: TextStyle(
              color: GalaxyColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              initialValue: selectedMinutes.toString(),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'Minutes',
                hintText: '1 to 180',
                prefixIcon: Icon(
                  Icons.timer_outlined,
                  color: GalaxyColors.purple,
                ),
              ),
              validator: (value) {
                final minutes = int.tryParse(
                  value?.trim() ?? '',
                );

                if (minutes == null ||
                    minutes < 1 ||
                    minutes > 180) {
                  return 'Enter 1 to 180 minutes';
                }

                return null;
              },
              onSaved: (value) {
                selectedMinutes = int.parse(
                  value!.trim(),
                );
              },
              onFieldSubmitted: (_) => submit(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submit,
              child: const Text('Set Timer'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (selected != null) {
      _selectDuration(selected);
    }
  }

  // Format the countdown as MM:SS.
  String get _timeLabel {
    final totalSeconds = _remaining.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String get _timerStatus {
    if (_busy) {
      return 'Syncing with server...';
    }

    if (_isRunning) {
      return 'Stay focused';
    }

    if (_isFinished) {
      return 'Session complete!';
    }

    if (_sessionId != null) {
      return _remaining <= Duration.zero
          ? 'Ready to finish'
          : 'Timer paused';
    }

    return 'Ready when you are';
  }

  String get _actionLabel {
    if (_busy) {
      return 'Please wait...';
    }

    if (_sessionId != null &&
        _remaining <= Duration.zero) {
      return 'Finish Session';
    }

    if (_isRunning) {
      return 'Pause Session';
    }

    if (_isFinished) {
      return 'Start Again';
    }

    if (_sessionId != null) {
      return 'Resume Session';
    }

    return 'Start Focus';
  }

  // Completion popup showing actual XP from Laravel.
  Future<void> _showCompletionDialog({
    required int xpEarned,
    required int durationMinutes,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: GalaxyColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(
              color: GalaxyColors.purple,
              width: 1.3,
            ),
          ),
          title: const Column(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: GalaxyColors.gold,
                size: 47,
              ),
              SizedBox(height: 12),
              Text(
                'Focus Complete!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: GalaxyColors.textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You completed $durationMinutes full '
                '${durationMinutes == 1 ? 'minute' : 'minutes'} '
                'of focus.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: GalaxyColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 15),

              Text(
                '+$xpEarned XP',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: GalaxyColors.gold,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                xpEarned > 0
                    ? 'Experience awarded by AralPet!'
                    : 'No XP earned (under 10 minutes '
                        'or daily cap reached).',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: GalaxyColors.mint,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Awesome!'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    final ringSize = math.min(
      screenWidth - 58,
      318.0,
    );

    final progress = _duration.inMilliseconds > 0
        ? (_remaining.inMilliseconds /
                _duration.inMilliseconds)
            .clamp(0.0, 1.0)
            .toDouble()
        : 0.0;

    final reduceMotion =
        MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative Galaxy mountains.
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FocusMountainsPainter(),
                ),
              ),
            ),

            ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                22,
                22,
                22,
                130,
              ),
              children: [
                // HEADER
                _buildHeader(),

                const SizedBox(height: 32),

                // FOCUS MODE LABEL
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: GalaxyColors.purple
                          .withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(30),
                      border: Border.all(
                        color: GalaxyColors.purple
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.nightlight_round,
                          color: GalaxyColors.purple,
                          size: 16,
                        ),
                        SizedBox(width: 7),
                        Text(
                          'FOCUS MODE',
                          style: TextStyle(
                            color: GalaxyColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // GLOWING CIRCULAR TIMER
                Center(
                  child: SizedBox(
                    width: ringSize,
                    height: ringSize,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 1.0,
                        end: progress,
                      ),
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 450),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return CustomPaint(
                          painter: _FocusRingPainter(
                            progress: value,
                          ),
                          child: child,
                        );
                      },
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            color: GalaxyColors.gold,
                            size: 27,
                          ),

                          const SizedBox(height: 8),

                          Text(
                            _timeLabel,
                            style: const TextStyle(
                              color: GalaxyColors.textPrimary,
                              fontSize: 57,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.5,
                              shadows: [
                                Shadow(
                                  color: Color(0x887C63D7),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),

                          const Text(
                            'MINUTES : SECONDS',
                            style: TextStyle(
                              color: GalaxyColors.textSecondary,
                              fontSize: 10,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 13),

                          AnimatedSwitcher(
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(
                                    milliseconds: 250,
                                  ),
                            child: Text(
                              _timerStatus,
                              key: ValueKey(_timerStatus),
                              style: TextStyle(
                                color: _isFinished
                                    ? GalaxyColors.mint
                                    : GalaxyColors.blue,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // STUDY DURATION
                const Text(
                  'Study Duration',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: GalaxyColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 7),

                const Text(
                  'Choose how long you want to focus',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: GalaxyColors.textSecondary,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 18),

                // DURATION PRESETS
                Row(
                  children: [
                    for (final minutes in _presets) ...[
                      Expanded(
                        child: _durationButton(
                          label: '$minutes min',
                          selected:
                              _duration.inMinutes == minutes,
                          onTap: () {
                            _selectDuration(minutes);
                          },
                        ),
                      ),
                      const SizedBox(width: 7),
                    ],

                    Expanded(
                      child: _durationButton(
                        label: 'Custom',
                        selected: !_presets.contains(
                          _duration.inMinutes,
                        ),
                        onTap: _chooseCustomDuration,
                      ),
                    ),
                  ],
                ),

                if (_sessionId != null) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Reset the session to change its duration.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: GalaxyColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // START / PAUSE / RESUME
                _buildPrimaryButton(),

                const SizedBox(height: 12),

                // RESET
                Center(
                  child: TextButton.icon(
                    onPressed:
                        _busy ? null : _resetTimer,
                    icon: const Icon(
                      Icons.restart_alt_rounded,
                      size: 21,
                    ),
                    label: const Text('Reset Timer'),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          GalaxyColors.textSecondary,
                    ),
                  ),
                ),

                const SizedBox(height: 21),

                // FOCUS TIP
                _buildFocusTip(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Header matching the Galaxy UI.
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: GalaxyColors.blue
                .withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.timer_outlined,
            color: GalaxyColors.blue,
            size: 28,
          ),
        ),

        const SizedBox(width: 12),

        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Focus',
                style: TextStyle(
                  color: GalaxyColors.textPrimary,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Focus Chamber',
                style: TextStyle(
                  color: GalaxyColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        const Icon(
          Icons.auto_awesome_rounded,
          color: GalaxyColors.gold,
          size: 24,
        ),
      ],
    );
  }

  // Duration preset button.
  Widget _durationButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: selected
            ? GalaxyColors.purple.withValues(alpha: 0.27)
            : GalaxyColors.surface.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: selected
              ? GalaxyColors.purple
              : GalaxyColors.border,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: GalaxyColors.purple
                      .withValues(alpha: 0.23),
                  blurRadius: 13,
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (_busy || _sessionId != null)
              ? null
              : onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 2,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: (_isRunning ||
                        _busy ||
                        _sessionId != null)
                    ? GalaxyColors.textSecondary
                    : selected
                        ? GalaxyColors.textPrimary
                        : GalaxyColors.textSecondary,
                fontSize: 12,
                fontWeight: selected
                    ? FontWeight.w900
                    : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Main Start / Pause / Resume button.
  Widget _buildPrimaryButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 59,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isRunning
              ? [
                  const Color(0xFF236F9E),
                  GalaxyColors.blue,
                ]
              : [
                  const Color(0xFF7041D4),
                  const Color(0xFFA77BFF),
                  const Color(0xFF7846DD),
                ],
        ),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: _isRunning
              ? GalaxyColors.blue
              : const Color(0xFFD9BDFF),
        ),
        boxShadow: [
          BoxShadow(
            color: (_isRunning
                    ? GalaxyColors.blue
                    : GalaxyColors.purple)
                .withValues(alpha: 0.32),
            blurRadius: 23,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _busy
              ? null
              : (_isRunning
                  ? _pauseTimer
                  : _startTimer),
          borderRadius: BorderRadius.circular(19),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isRunning
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 27,
                ),

                const SizedBox(width: 10),

                AnimatedSwitcher(
                  duration: const Duration(
                    milliseconds: 220,
                  ),
                  child: Text(
                    _actionLabel,
                    key: ValueKey(_actionLabel),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Focus tip card.
  Widget _buildFocusTip() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GalaxyColors.surface
            .withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: GalaxyColors.blue
              .withValues(alpha: 0.25),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            color: GalaxyColors.gold,
            size: 23,
          ),

          SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Focus Tip',
                  style: TextStyle(
                    color: GalaxyColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Put distractions aside and concentrate '
                  'on one task at a time.',
                  style: TextStyle(
                    color: GalaxyColors.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Draw the glowing circular countdown.
class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter({
    required this.progress,
  });

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius =
        math.min(size.width, size.height) / 2 - 25;

    final rect = Rect.fromCircle(
      center: center,
      radius: radius,
    );

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    // Circular atmosphere.
    canvas.drawCircle(
      center,
      radius - 22,
      Paint()
        ..color = GalaxyColors.purple
            .withValues(alpha: 0.055),
    );

    // Background track.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..color = GalaxyColors.surfaceLight,
    );

    if (progress > 0) {
      // Soft outer glow.
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round
        ..color = GalaxyColors.purple
            .withValues(alpha: 0.37)
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          12,
        );

      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
        false,
        glowPaint,
      );

      // Gradient progress ring.
      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + 2 * math.pi,
          colors: const [
            GalaxyColors.blue,
            GalaxyColors.purple,
            GalaxyColors.pink,
          ],
        ).createShader(rect);

      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );

      // Bright progress indicator.
      final tip = Offset(
        center.dx +
            radius *
                math.cos(startAngle + sweepAngle),
        center.dy +
            radius *
                math.sin(startAngle + sweepAngle),
      );

      canvas.drawCircle(
        tip,
        5,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _FocusRingPainter oldDelegate,
  ) {
    return oldDelegate.progress != progress;
  }
}

// Decorative Galaxy mountains behind the timer.
class _FocusMountainsPainter extends CustomPainter {
  const _FocusMountainsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final back = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.88)
      ..lineTo(size.width * 0.2, size.height * 0.78)
      ..lineTo(size.width * 0.43, size.height * 0.9)
      ..lineTo(size.width * 0.7, size.height * 0.79)
      ..lineTo(size.width, size.height * 0.87)
      ..close();

    canvas.drawPath(
      back,
      Paint()
        ..color = const Color(0xFF28204E)
            .withValues(alpha: 0.65),
    );

    final front = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.96)
      ..lineTo(size.width * 0.25, size.height * 0.87)
      ..lineTo(size.width * 0.52, size.height * 0.96)
      ..lineTo(size.width * 0.78, size.height * 0.87)
      ..lineTo(size.width, size.height * 0.93)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(
      front,
      Paint()
        ..color = const Color(0xFF11142F)
            .withValues(alpha: 0.90),
    );
  }

  @override
  bool shouldRepaint(
    covariant _FocusMountainsPainter oldDelegate,
  ) {
    return false;
  }
}
