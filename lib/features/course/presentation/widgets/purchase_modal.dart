import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/state/auth_controller.dart';
import '../../../../core/services/telegram_service.dart';

/// Qaysi turdagi taklif ekanini bildiradi — snackbar matni shunga bog‘liq.
enum PurchaseOfferKind {
  /// Ilova ichidagi kurs: serverga xarid yoziladi + Telegram admin bilan.
  platformPaidCourse,

  /// «Onlayn kurslar» — faqat tashqi maxfiy kanal / Telegram; ilova kursi tasdig‘i yo‘q.
  externalTelegramChannel,
}

Future<void> showPurchaseModal({
  required BuildContext context,
  required String courseName,
  required String description,
  required String price,
  String? courseId,
  String? telegramRecipient,
  PurchaseOfferKind offerKind = PurchaseOfferKind.platformPaidCourse,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return _PurchaseModalContent(
        courseName: courseName,
        description: description,
        price: price,
        courseId: courseId,
        telegramRecipient: telegramRecipient,
        offerKind: offerKind,
      );
    },
  );
}

class _PurchaseModalContent extends ConsumerStatefulWidget {
  const _PurchaseModalContent({
    required this.courseName,
    required this.description,
    required this.price,
    this.courseId,
    this.telegramRecipient,
    required this.offerKind,
  });

  final String courseName;
  final String description;
  final String price;
  final String? courseId;
  final String? telegramRecipient;
  final PurchaseOfferKind offerKind;

  @override
  ConsumerState<_PurchaseModalContent> createState() =>
      _PurchaseModalContentState();
}

class _PurchaseModalContentState extends ConsumerState<_PurchaseModalContent> {
  final TelegramService _telegramService = TelegramService();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final isExternal = widget.offerKind == PurchaseOfferKind.externalTelegramChannel;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x29000000),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Obuna sotib olish',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              if (isExternal) ...[
                const SizedBox(height: 8),
                Text(
                  'Bu taklif ilova ichidagi kurs bilan bog‘lanmasligi mumkin — to‘lov va maxfiy kanalga kirish Telegram orqali.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
              const SizedBox(height: 14),
              _InfoTile(
                icon: Icons.school_outlined,
                title: 'Kurs',
                value: widget.courseName,
              ),
              const SizedBox(height: 10),
              _InfoTile(
                icon: Icons.info_outline,
                title: 'Qisqa tavsif',
                value: widget.description,
              ),
              const SizedBox(height: 10),
              _InfoTile(
                icon: Icons.payments_outlined,
                title: 'Narx',
                value: widget.price,
                valueColor: const Color(0xFF0E8F61),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF229ED9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _loading
                      ? null
                      : () async {
                          final auth = ref.read(authControllerProvider);
                          if (!auth.isLoggedIn || auth.userId == null) {
                            Navigator.of(context).pop();
                            context.push(AppRoutes.login);
                            return;
                          }

                          setState(() => _loading = true);

                          // Kursni bu yerda ochmaymiz va serverga avtomatik
                          // grant yozmaymiz. Faqat Telegram orqali adminga
                          // so'rov yuboramiz; kurs admin tasdiqlagandan keyin
                          // (entitlement sync orqali) ochiladi.
                          var opened = false;
                          try {
                            opened = await _telegramService.openTelegram(
                              courseName: widget.courseName,
                              userId: auth.userId!,
                              courseId: widget.courseId,
                              userName: auth.name,
                              userPhone: auth.email,
                              telegramRecipient: widget.telegramRecipient,
                            );
                          } catch (_) {
                            opened = false;
                          }

                          if (!context.mounted) return;
                          setState(() => _loading = false);
                          Navigator.of(context).pop();

                          final messenger = ScaffoldMessenger.maybeOf(context);
                          if (messenger == null) return;

                          if (widget.offerKind == PurchaseOfferKind.externalTelegramChannel) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  opened
                                      ? 'Telegram ochildi. Maxfiy kanal yoki admin bo‘yicha ko‘rsatmalarni o‘tishingiz mumkin.'
                                      : 'Telegram havolasini ochib bo‘lmadi. Ilovani yangilang yoki Telegram o‘rnatilganini tekshiring.',
                                ),
                              ),
                            );
                            return;
                          }

                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                opened
                                    ? 'So‘rov yuborildi. Kurs admin tasdiqlagandan keyin ochiladi.'
                                    : 'Telegram havolasini ochib bo‘lmadi. Qayta urinib ko‘ring.',
                              ),
                            ),
                          );
                        },
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.telegram),
                  label: Text(
                    _loading ? 'Ochilmoqda...' : 'Telegram orqali sotib olish',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1E6BB8)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? Colors.black87,
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
