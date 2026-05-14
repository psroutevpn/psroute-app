import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/animated_text.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ConnectionButton extends HookConsumerWidget {
  const ConnectionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final activeProxy = ref.watch(activeProxyNotifierProvider);
    final delay = activeProxy.valueOrNull?.urlTestDelay ?? 0;

    final requiresReconnect = ref.watch(configOptionNotifierProvider).valueOrNull;

    const buttonTheme = ConnectionButtonTheme.light;

    return _ConnectionButton(
      onTap: switch (connectionStatus) {
        AsyncData(value: Connected()) when requiresReconnect == true => () async {
          final activeProfile = await ref.read(activeProfileProvider.future);
          return await ref.read(connectionNotifierProvider.notifier).reconnect(activeProfile);
        },
        AsyncData(value: Disconnected()) || AsyncError() => () async {
          if (ref.read(activeProfileProvider).valueOrNull == null) {
            await ref.read(dialogNotifierProvider.notifier).showNoActiveProfile();
            ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile();
          }
          if (await ref.read(dialogNotifierProvider.notifier).showExperimentalFeatureNotice()) {
            return await ref.read(connectionNotifierProvider.notifier).toggleConnection();
          }
        },
        AsyncData(value: Connected()) => () async {
          if (requiresReconnect == true &&
              await ref.read(dialogNotifierProvider.notifier).showExperimentalFeatureNotice()) {
            return await ref
                .read(connectionNotifierProvider.notifier)
                .reconnect(await ref.read(activeProfileProvider.future));
          }
          return await ref.read(connectionNotifierProvider.notifier).toggleConnection();
        },
        _ => () {},
      },
      enabled: switch (connectionStatus) {
        AsyncData(value: Connected()) || AsyncData(value: Disconnected()) || AsyncError() => true,
        _ => false,
      },
      label: switch (connectionStatus) {
        AsyncData(value: Connected()) when requiresReconnect == true => t.connection.reconnect,
        AsyncData(value: Connected()) when delay <= 0 || delay >= 65000 => t.connection.connecting,
        AsyncData(value: final status) => status.present(t),
        _ => "",
      },
      buttonColor: switch (connectionStatus) {
        AsyncData(value: Connected()) when requiresReconnect == true => Colors.teal,
        AsyncData(value: Connected()) when delay <= 0 || delay >= 65000 => const Color.fromARGB(255, 185, 176, 103),
        AsyncData(value: Connected()) => buttonTheme.connectedColor!,
        AsyncData(value: _) => buttonTheme.idleColor!,
        _ => Colors.red,
      },
      isConnecting: switch (connectionStatus) {
        AsyncData(value: Connecting()) => true,
        _ => false,
      },
    );
  }
}

class _ConnectionButton extends StatelessWidget {
  const _ConnectionButton({
    required this.onTap,
    required this.enabled,
    required this.label,
    required this.buttonColor,
    required this.isConnecting,
  });

  final VoidCallback onTap;
  final bool enabled;
  final String label;
  final Color buttonColor;
  final bool isConnecting;

  static const double _buttonSize = 152.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Semantics(
          button: true,
          enabled: enabled,
          label: label,
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: buttonColor),
            duration: const Duration(milliseconds: 300),
            builder: (context, color, child) {
              final c = color ?? buttonColor;
              return Container(
                width: _buttonSize,
                height: _buttonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 32,
                      spreadRadius: 0,
                      color: c.withValues(alpha: 0.35),
                    ),
                  ],
                ),
                child: Material(
                  key: const ValueKey("home_connection_button"),
                  shape: CircleBorder(
                    side: BorderSide(
                      color: c.withValues(alpha: 0.4),
                      width: 2.5,
                    ),
                  ),
                  color: const Color(0xFF1A1A2E),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    splashColor: c.withValues(alpha: 0.15),
                    highlightColor: c.withValues(alpha: 0.08),
                    onTap: onTap,
                    child: Center(
                      child: CustomPaint(
                        size: const Size(56, 56),
                        painter: _PowerIconPainter(color: c),
                      ),
                    ),
                  ),
                ),
              );
            },
          ).animate(target: enabled ? 0 : 1).scaleXY(end: 0.9, curve: Curves.easeIn),
        ),
        const Gap(16),
        ExcludeSemantics(
          child: AnimatedText(label, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }
}

/// Mathematically symmetric power icon painter.
/// All geometry is derived from center point — guaranteed symmetric.
class _PowerIconPainter extends CustomPainter {
  _PowerIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double radius = size.width * 0.40; // arc radius
    final double strokeWidth = size.width * 0.07;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Arc: 40 degrees gap at top (from 250° to 290° is the gap)
    // Draw from 290° to 250° (going clockwise through bottom)
    const double gapHalf = 40 * math.pi / 180; // 40° half-gap = 20° each side
    const double startAngle = -math.pi / 2 + gapHalf; // from top + 20°
    const double sweepAngle = 2 * math.pi - 2 * gapHalf; // full circle minus 40°

    final arcRect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    canvas.drawArc(arcRect, startAngle, sweepAngle, false, paint);

    // Vertical line: centered, from top going down to center
    final double lineTop = cy - radius - strokeWidth * 0.3;
    final double lineBottom = cy + size.height * 0.04;
    canvas.drawLine(Offset(cx, lineTop), Offset(cx, lineBottom), paint);
  }

  @override
  bool shouldRepaint(_PowerIconPainter oldDelegate) => oldDelegate.color != color;
}
