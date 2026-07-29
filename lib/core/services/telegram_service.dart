import 'package:url_launcher/url_launcher.dart';

class TelegramService {
  static const String _adminUsername = 'Neuroscienceadmin';

  /// t.me / @user / faqat username — kurs admini maydoni bilan bir xil ma'noda.
  static String? telegramUsernameFromContactField(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;

    if (!s.contains('/') && !s.contains('.')) {
      final u = s.replaceFirst(RegExp(r'^@'), '');
      if (_isLikelyTelegramUsername(u)) return u;
    }

    Uri? uri = Uri.tryParse(s);
    if ((uri == null || !uri.hasScheme) &&
        (s.toLowerCase().startsWith('t.me/') ||
            s.toLowerCase().startsWith('telegram.me/'))) {
      uri = Uri.tryParse('https://${s.replaceFirst(RegExp(r'^//'), '')}');
    }
    if (uri != null && uri.hasScheme) {
      final host = uri.host.toLowerCase();
      if (host == 't.me' || host == 'telegram.me') {
        final parts = uri.pathSegments.where((p) => p.isNotEmpty).toList();
        if (parts.isEmpty) return null;
        final first = parts.first;
        if (first == 'share' || first.startsWith('+')) return null;
        if (_isLikelyTelegramUsername(first)) return first;
      }
    }
    return null;
  }

  static bool _isLikelyTelegramUsername(String u) {
    return RegExp(r'^[a-zA-Z0-9_]{4,32}$').hasMatch(u);
  }

  Future<bool> _launchTelegramPrefilledChat({
    required String recipientUsername,
    required String message,
  }) async {
    var recipient = recipientUsername.trim();
    if (recipient.startsWith('@')) recipient = recipient.substring(1);
    if (recipient.isEmpty) recipient = _adminUsername;

    final encoded = Uri.encodeComponent(message);
    final tmeUri = Uri.parse('https://t.me/$recipient?text=$encoded');
    final tgUri = Uri.parse('tg://msg?text=$encoded&to=@$recipient');

    try {
      if (await launchUrl(tmeUri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {}

    try {
      if (await launchUrl(tgUri, mode: LaunchMode.externalNonBrowserApplication)) {
        return true;
      }
    } catch (_) {}

    try {
      return await launchUrl(tmeUri, mode: LaunchMode.platformDefault);
    } catch (_) {
      return false;
    }
  }


  Future<bool> _launchExternalHttpUrl(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return true;
    } catch (_) {}
    try {
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      return false;
    }
  }

  Future<bool> openTelegram({
    required String courseName,
    required String userId,
    String? courseId,
    String? userName,
    String? userPhone,
    String? telegramRecipient,
  }) async {
    var recipient = (telegramRecipient ?? _adminUsername).trim();
    if (recipient.startsWith('@')) recipient = recipient.substring(1);
    if (recipient.isEmpty) recipient = _adminUsername;

    final normalizedName =
        (userName ?? '').trim().isEmpty ? '-' : userName!.trim();
    final normalizedPhone =
        (userPhone ?? '').trim().isEmpty ? '-' : userPhone!.trim();
    final message = '''
Salom men shu kursni sotib olmoqchiman.

Ism: $normalizedName
Telefon: $normalizedPhone
Kurs nomi: "$courseName"
''';
    return _launchTelegramPrefilledChat(
      recipientUsername: recipient,
      message: message,
    );
  }

  /// Kitob: admin paneldagi «Admin lichkasi» — kurs [`admin_telegram`] bilan bir xil ma’noda (username / t.me havola).
  /// Bo‘sh bo‘lsa umumiy admin; boshqa HTTPS havola bo‘lsa brauzerda ochiladi.
  Future<bool> openBookPurchase({
    required String bookTitle,
    required String bookId,
    required int priceUzs,
    required String userId,
    String? userName,
    String? userPhone,
    String? purchaseContactUrl,
  }) async {
    final normalizedName =
        (userName ?? '').trim().isEmpty ? '-' : userName!.trim();
    final normalizedPhone =
        (userPhone ?? '').trim().isEmpty ? '-' : userPhone!.trim();
    final message = '''
Salom men shu kitobni sotib olmoqchiman.

Ism: $normalizedName
Telefon: $normalizedPhone
Kitob nomi: "$bookTitle"
''';

    final custom = (purchaseContactUrl ?? '').trim();
    if (custom.isNotEmpty) {
      final fromLink = telegramUsernameFromContactField(custom);
      if (fromLink != null) {
        return _launchTelegramPrefilledChat(
          recipientUsername: fromLink,
          message: message,
        );
      }
      final uriDirect = Uri.tryParse(custom);
      if (uriDirect != null &&
          uriDirect.hasScheme &&
          (uriDirect.scheme == 'http' || uriDirect.scheme == 'https')) {
        return _launchExternalHttpUrl(uriDirect);
      }
    }

    return _launchTelegramPrefilledChat(
      recipientUsername: _adminUsername,
      message: message,
    );
  }
}
