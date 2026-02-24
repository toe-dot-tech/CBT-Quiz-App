import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TimerState {
  final int remainingSeconds;
  final bool isUrgent; // True if < 300 seconds (5 mins)

  TimerState(this.remainingSeconds, this.isUrgent);
}

class TimerNotifier extends StateNotifier<TimerState> {
  TimerNotifier() : super(TimerState(1800, false)); // Default 30 mins
  Timer? _timer;

  void startTimer(int durationMinutes) {
    int totalSeconds = durationMinutes * 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (totalSeconds <= 0) {
        timer.cancel();
        // Trigger Auto-Submit Logic here
      } else {
        totalSeconds--;
        state = TimerState(totalSeconds, totalSeconds <= 300);
      }
    });
  }

  String get formattedTime {
    int mins = state.remainingSeconds ~/ 60;
    int secs = state.remainingSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final timerProvider = StateNotifierProvider<TimerNotifier, TimerState>((ref) => TimerNotifier());