import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/features/psroute_api/psroute_api_service.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';

class ReferralPage extends HookConsumerWidget {
  const ReferralPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(psrouteApiProvider);
    final theme = Theme.of(context);
    final stats = useState<Map<String, dynamic>?>(null);
    final isLoading = useState(true);
    final errorMsg = useState<String?>(null);

    useEffect(() {
      if (api.isAuthenticated) {
        api.getReferralStats().then((data) {
          stats.value = data;
          isLoading.value = false;
        }).catchError((e) {
          errorMsg.value = e.toString();
          isLoading.value = false;
        });
      } else {
        isLoading.value = false;
      }
      return null;
    }, [api.isAuthenticated]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Реферальная программа'),
      ),
      body: !api.isAuthenticated
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.people_team_24_regular,
                        size: 64, color: theme.colorScheme.primary),
                    const Gap(16),
                    const Text('Войдите для доступа к реферальной программе'),
                  ],
                ),
              ),
            )
          : isLoading.value
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Referral code card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(FluentIcons.gift_24_regular,
                                  size: 48, color: theme.colorScheme.primary),
                              const Gap(12),
                              Text('Ваш реферальный код',
                                  style: theme.textTheme.titleMedium),
                              const Gap(8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  stats.value?['ref_code'] ?? '—',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                              const Gap(16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      final code = stats.value?['ref_code'] ?? '';
                                      Clipboard.setData(ClipboardData(text: code));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Код скопирован')),
                                      );
                                    },
                                    icon: const Icon(FluentIcons.copy_24_regular),
                                    label: const Text('Копировать'),
                                  ),
                                  const Gap(12),
                                  FilledButton.icon(
                                    onPressed: () {
                                      final shareUrl = stats.value?['share_url'] ?? '';
                                      if (shareUrl.isNotEmpty) {
                                        Share.share(
                                          'Попробуй PS Route — быстрый и надёжный сервис! '
                                          'Переходи по ссылке и получи бонус: $shareUrl',
                                        );
                                      }
                                    },
                                    icon: const Icon(FluentIcons.share_24_regular),
                                    label: const Text('Поделиться'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Gap(16),

                      // Stats
                      Row(
                        children: [
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Text(
                                      '${stats.value?['total_referrals'] ?? 0}',
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const Gap(4),
                                    Text('Друзей приглашено',
                                        style: theme.textTheme.bodySmall,
                                        textAlign: TextAlign.center),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Gap(12),
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Text(
                                      '${stats.value?['bonus_days_earned'] ?? 0}',
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const Gap(4),
                                    Text('Бонусных дней',
                                        style: theme.textTheme.bodySmall,
                                        textAlign: TextAlign.center),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(24),

                      // Rules
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Как это работает',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  )),
                              const Gap(12),
                              _ruleRow(theme, '1', 'Поделитесь кодом с другом'),
                              const Gap(8),
                              _ruleRow(theme, '2', 'Друг регистрируется и оплачивает подписку'),
                              const Gap(8),
                              _ruleRow(theme, '3', 'Вы оба получаете +7 дней бесплатно'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _ruleRow(ThemeData theme, String num, String text) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: theme.colorScheme.primary,
          child: Text(num,
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              )),
        ),
        const Gap(12),
        Expanded(
          child: Text(text, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}
