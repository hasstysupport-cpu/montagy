import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// تسجيل صوتي أصلي (MediaRecorder عبر MethodChannel) — بدون حزم خارجية.
class VoiceRecorder {
  static const _channel = MethodChannel('montagy/record');

  /// يطلب إذن الميكروفون ويعيد true إن مُنح.
  static Future<bool> ensurePermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    return status.isGranted || status.isLimited;
  }

  /// يبدأ التسجيل إلى المسار المحدد (m4a/AAC).
  static Future<bool> start(String path) async {
    try {
      final ok = await _channel.invokeMethod<bool>('start', {'path': path});
      return ok == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// يوقف التسجيل ويعيد مسار الملف (أو null عند الفشل).
  static Future<String?> stop() async {
    try {
      return await _channel.invokeMethod<String>('stop');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// يلغي التسجيل ويحذف الملف.
  static Future<void> cancel() async {
    try {
      await _channel.invokeMethod<bool>('cancel');
    } catch (_) {}
  }
}
