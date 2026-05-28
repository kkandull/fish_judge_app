import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  static Future<void> copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  static Future<void> share(String text) async {
    await Share.share(text);
  }
}