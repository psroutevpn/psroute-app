import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/features/psroute_api/psroute_api_service.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum AIPricingReason { notLoggedIn, noSubscription }

class AIPricingPage extends HookConsumerWidget {
  const AIPricingPage({super.key, required this.reason});

  final AIPricingReason reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(psrouteApiProvider);
    final theme = Theme.of(context);
    final isLoading = useState(false);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Чат')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Gap(16),
            // Hero icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.tertiary,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(FluentIcons.bot_sparkle_24_filled,
                  size: 40, color: Colors.white),
            ),
            const Gap(20),
            Text(
              'AI без ограничений',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Gap(8),
            Text(
              reason == AIPricingReason.notLoggedIn
                  ? 'Войдите в аккаунт для доступа к AI моделям'
                  : 'Подключите AI для доступа к ChatGPT, Claude и другим моделям',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(32),

            // If not logged in — show login button
            if (reason == AIPricingReason.notLoggedIn) ...[
              FilledButton.icon(
                onPressed: () {
                  UriUtils.tryLaunch(
                    Uri.parse('https://t.me/PSRouteBot?start=login'),
                  );
                },
                icon: const Icon(FluentIcons.person_24_regular),
                label: const Text('Войти через Telegram'),
              ),
              const Gap(16),
            ],

            // If logged in but no sub — show features + pricing
            if (reason == AIPricingReason.noSubscription) ...[
              // Features list
              _FeatureItem(
                icon: FluentIcons.chat_sparkle_24_regular,
                title: 'ChatGPT, Claude, Gemini',
                subtitle: 'Все топовые модели в одном месте',
              ),
              _FeatureItem(
                icon: FluentIcons.shield_checkmark_24_regular,
                title: 'Без блокировок',
                subtitle: 'Работает из России без VPN',
              ),
              _FeatureItem(
                icon: FluentIcons.history_24_regular,
                title: 'История чатов',
                subtitle: 'Все диалоги сохраняются',
              ),
              _FeatureItem(
                icon: FluentIcons.rocket_24_regular,
                title: 'Быстрый доступ',
                subtitle: 'Прямое подключение через наш прокси',
              ),
              const Gap(24),

              // Pricing cards
              _PricingCard(
                title: '1 месяц',
                price: '299 ₽',
                perMonth: '299 ₽/мес',
                isPopular: false,
                onTap: () => _buyAI(context, api, 'ai_1m', isLoading),
              ),
              const Gap(12),
              _PricingCard(
                title: '3 месяца',
                price: '699 ₽',
                perMonth: '233 ₽/мес',
                isPopular: true,
                onTap: () => _buyAI(context, api, 'ai_3m', isLoading),
              ),
              const Gap(12),
              _PricingCard(
                title: '12 месяцев',
                price: '1 990 ₽',
                perMonth: '166 ₽/мес',
                isPopular: false,
                onTap: () => _buyAI(context, api, 'ai_12m', isLoading),
              ),
              const Gap(16),
              if (isLoading.value)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _buyAI(
    BuildContext context,
    PSRouteApiService api,
    String plan,
    ValueNotifier<bool> isLoading,
  ) async {
    isLoading.value = true;
    try {
      // Redirect to bot for payment (same flow as VPN)
      await UriUtils.tryLaunch(
        Uri.parse('https://t.me/PSRouteBot?start=buy_ai_$plan'),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      isLoading.value = false;
    }
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 22),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _PricingCard extends StatelessWidget {
  const _PricingCard({
    required this.title,
    required this.price,
    required this.perMonth,
    required this.isPopular,
    required this.onTap,
  });

  final String title;
  final String price;
  final String perMonth;
  final bool isPopular;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: isPopular ? 2 : 0,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPopular
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: isPopular ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                        if (isPopular) ...[
                          const Gap(8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Выгодно',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Gap(2),
                    Text(
                      perMonth,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                price,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Gap(8),
              Icon(FluentIcons.chevron_right_24_regular,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
