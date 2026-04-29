import 'package:url_launcher/url_launcher.dart';

class TelegramService {
  static const String _adminUsername = 'Neuroscienceadmin';

  Future<bool> openTelegram({
    required String courseName,
    required String userId,
  }) async {
    final message =
        'Salom, men kurs sotib olmoqchiman. ID: $userId. Kurs: "$courseName"';
    final encoded = Uri.encodeComponent(message);
    final appUri = Uri.parse(
      'tg://resolve?domain=$_adminUsername&text=$encoded',
    );
    final webUri = Uri.parse('https://t.me/$_adminUsername?text=$encoded');

    try {
      final openedInTelegram = await launchUrl(
        appUri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (openedInTelegram) return true;
    } catch (_) {
      // If deep link fails, continue with web fallback.
    }

    try {
      final openedExternal = await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
      if (openedExternal) return true;
    } catch (_) {
      // Last fallback below.
    }

    try {
      return await launchUrl(webUri, mode: LaunchMode.platformDefault);
    } catch (_) {
      return false;
    }
  }
}
