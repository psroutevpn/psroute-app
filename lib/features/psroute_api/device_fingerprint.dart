import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

/// Generates a deterministic device fingerprint for anonymous trial auth.
/// SHA-256 hash of: ANDROID_ID (SSAID) + brand + model + hardware + product + board + device.
/// On non-Android platforms, uses platform-specific identifiers.
class DeviceFingerprint {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// MethodChannel to read Settings.Secure.ANDROID_ID (SSAID).
  /// This is the real unique device identifier, NOT Build.ID.
  static const _channel = MethodChannel('xyz.psroute.app/device');

  /// Returns SHA-256 hex string (64 chars).
  /// Never throws — returns a fallback fingerprint on error.
  static Future<String> generate() async {
    try {
      return await _generateInternal();
    } catch (e) {
      // Fallback: hash of timestamp + platform — unique but not deterministic.
      // This means the user gets a trial but can't re-login on same device.
      // Better than crashing the entire auth flow.
      final fallback = '${DateTime.now().microsecondsSinceEpoch}|${Platform.operatingSystem}';
      return sha256.convert(utf8.encode(fallback)).toString();
    }
  }

  static Future<String> _generateInternal() async {
    final parts = <String>[];

    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;

      // Try to get the real ANDROID_ID (SSAID) via MethodChannel.
      // SSAID is unique per device+user+app signing key combo,
      // persists across app installs, reset only on factory reset.
      String androidId = '';
      try {
        androidId = await _channel.invokeMethod<String>('getAndroidId') ?? '';
      } catch (_) {
        // MethodChannel not available — fall back to Build.FINGERPRINT
        // which is per-ROM but still unique in combination with other fields.
      }

      if (androidId.isNotEmpty) {
        parts.add(androidId);
      }
      parts.add(info.brand);
      parts.add(info.model);
      parts.add(info.hardware);
      parts.add(info.product);
      parts.add(info.board);
      parts.add(info.device);
      parts.add(info.fingerprint); // Build fingerprint (brand/product/device:version/...)
    } else if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      parts.add(info.identifierForVendor ?? '');
      parts.add(info.model);
      parts.add(info.name);
      parts.add(info.systemName);
      parts.add(info.utsname.machine);
    } else {
      // Desktop fallback
      parts.add(Platform.localHostname);
      parts.add(Platform.operatingSystem);
      parts.add(Platform.operatingSystemVersion);
    }

    final raw = parts.join('|');
    return sha256.convert(utf8.encode(raw)).toString();
  }
}
