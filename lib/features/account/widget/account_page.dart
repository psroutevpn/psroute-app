import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';
import 'package:hiddify/features/psroute_api/psroute_api_service.dart';
import 'package:hiddify/features/referral/widget/referral_page.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AccountPage extends HookConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(psrouteApiProvider);
    final isLoading = useState(false);
    final isInitialized = useState(false);
    final userProfile = useState<Map<String, dynamic>?>(null);
    final subscription = useState<Map<String, dynamic>?>(null);
    final errorMsg = useState<String?>(null);

    // Wait for init to complete, then load profile if authenticated
    useEffect(() {
      () async {
        await api.initialized;
        isInitialized.value = true;
        if (api.isAuthenticated) {
          _loadProfile(api, userProfile, subscription, errorMsg, isLoading);
        }
      }();
      return null;
    }, []);

    final theme = Theme.of(context);

    // Still loading saved auth token
    if (!isInitialized.value) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!api.isAuthenticated) {
      return _buildLoggedOutState(context, theme, ref, api, isLoading, errorMsg, userProfile, subscription);
    }

    if (isLoading.value) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Error state or no data — show retry
    if (userProfile.value == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.error_circle_24_regular,
                    size: 64, color: theme.colorScheme.error),
                const Gap(16),
                Text(
                  errorMsg.value ?? 'Не удалось загрузить профиль',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const Gap(24),
                FilledButton(
                  onPressed: () => _loadProfile(
                    api, userProfile, subscription, errorMsg, isLoading,
                  ),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _buildLoggedInState(
      context, theme, api, userProfile, subscription, isLoading, errorMsg, ref,
    );
  }

  Future<void> _loadProfile(
    PSRouteApiService api,
    ValueNotifier<Map<String, dynamic>?> userProfile,
    ValueNotifier<Map<String, dynamic>?> subscription,
    ValueNotifier<String?> errorMsg,
    ValueNotifier<bool> isLoading,
  ) async {
    isLoading.value = true;
    errorMsg.value = null;
    try {
      userProfile.value = await api.getUserProfile();
      subscription.value = await api.getSubscription();
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Widget _buildLoggedOutState(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref,
    PSRouteApiService api,
    ValueNotifier<bool> isLoading,
    ValueNotifier<String?> errorMsg,
    ValueNotifier<Map<String, dynamic>?> userProfile,
    ValueNotifier<Map<String, dynamic>?> subscription,
  ) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FluentIcons.person_circle_24_regular,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const Gap(24),
              Text(
                'Аккаунт',
                style: theme.textTheme.headlineMedium,
              ),
              const Gap(12),
              Text(
                'Войдите через Telegram для управления подпиской',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(32),
              FilledButton.icon(
                onPressed: isLoading.value
                    ? null
                    : () => _showLoginFlow(context, ref, api, isLoading, errorMsg, userProfile, subscription),
                icon: const Icon(FluentIcons.chat_24_regular),
                label: const Text('Войти через Telegram'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
              const Gap(16),
              OutlinedButton.icon(
                onPressed: () async {
                  await UriUtils.tryLaunch(
                    Uri.parse('https://t.me/PSRouteBot?start=trial'),
                  );
                },
                icon: const Icon(FluentIcons.rocket_24_regular),
                label: const Text('Попробовать бесплатно'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
              if (errorMsg.value != null) ...[
                const Gap(16),
                Text(
                  errorMsg.value!,
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Two-step login flow:
  /// 1. Open bot to get 6-digit code
  /// 2. Enter code in dialog → verify via API
  void _showLoginFlow(
    BuildContext context,
    WidgetRef ref,
    PSRouteApiService api,
    ValueNotifier<bool> isLoading,
    ValueNotifier<String?> errorMsg,
    ValueNotifier<Map<String, dynamic>?> userProfile,
    ValueNotifier<Map<String, dynamic>?> subscription,
  ) {
    // First open bot so user can get the code
    UriUtils.tryLaunch(
      Uri.parse('https://t.me/PSRouteBot?start=login'),
    );

    // Then show code entry dialog
    Future.delayed(const Duration(milliseconds: 500), () {
      if (context.mounted) {
        _showCodeEntryDialog(context, ref, api, isLoading, errorMsg, userProfile, subscription);
      }
    });
  }

  void _showCodeEntryDialog(
    BuildContext context,
    WidgetRef ref,
    PSRouteApiService api,
    ValueNotifier<bool> isLoading,
    ValueNotifier<String?> errorMsg,
    ValueNotifier<Map<String, dynamic>?> userProfile,
    ValueNotifier<Map<String, dynamic>?> subscription,
  ) {
    final codeController = TextEditingController();
    final theme = Theme.of(context);
    // State declared OUTSIDE the builder so it persists across rebuilds
    bool isVerifying = false;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Введите код'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Отправьте /login боту @PSRouteBot и введите полученный 6-значный код:',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Gap(16),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: theme.textTheme.headlineMedium?.copyWith(
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: '000000',
                      counterText: '',
                      errorText: dialogError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                    ),
                    autofocus: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
                            setDialogState(() {
                              dialogError = 'Введите 6-значный код';
                            });
                            return;
                          }

                          setDialogState(() {
                            isVerifying = true;
                            dialogError = null;
                          });

                          try {
                            await api.verifyLoginCode(code);
                            errorMsg.value = null;
                            // Close dialog on success
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }

                            // Trigger rebuild: set loading, fetch profile, then unload
                            // This replaces the broken isLoading=true/false sync pair
                            isLoading.value = true;
                            await _loadProfile(api, userProfile, subscription, errorMsg, isLoading);

                            // Auto-import subscription URL into VPN core
                            try {
                              final subUrl = subscription.value?['subscription_url']?.toString();
                              if (subUrl != null && subUrl.isNotEmpty) {
                                await ref.read(addProfileNotifierProvider.notifier).addClipboard(subUrl);
                              }
                            } catch (e) {
                              // Non-fatal: user can add profile manually later
                              // Don't show error — profile was loaded, VPN config can be added via Home screen
                              debugPrint('Auto-import subscription failed: $e');
                            }
                          } catch (e) {
                            final msg = e.toString().replaceFirst('Exception: ', '');
                            setDialogState(() {
                              isVerifying = false;
                              dialogError = msg;
                            });
                          }
                        },
                  child: isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Войти'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLoggedInState(
    BuildContext context,
    ThemeData theme,
    PSRouteApiService api,
    ValueNotifier<Map<String, dynamic>?> userProfile,
    ValueNotifier<Map<String, dynamic>?> subscription,
    ValueNotifier<bool> isLoading,
    ValueNotifier<String?> errorMsg,
    WidgetRef ref,
  ) {
    final profile = userProfile.value!;
    final sub = subscription.value;

    final plan = profile['plan']?.toString() ?? 'Нет';
    final isActive = profile['is_active'] == true;
    final isTrial = profile['is_trial'] == true;
    final daysLeftRaw = profile['days_left'];
    final daysLeft = (daysLeftRaw is num) ? daysLeftRaw.toInt() : int.tryParse(daysLeftRaw?.toString() ?? '') ?? 0;
    final refCode = profile['ref_code']?.toString() ?? '';
    final bonusDaysRaw = profile['bonus_days'];
    final bonusDays = (bonusDaysRaw is num) ? bonusDaysRaw.toInt() : int.tryParse(bonusDaysRaw?.toString() ?? '') ?? 0;

    // Traffic — handle both int and double from JSON
    final trafficUsedRaw = sub?['traffic_used_bytes'];
    final trafficTotalRaw = sub?['traffic_total_bytes'];
    final trafficUsed = (trafficUsedRaw is num) ? trafficUsedRaw.toDouble() : 0.0;
    final trafficTotal = (trafficTotalRaw is num) ? trafficTotalRaw.toDouble() : 0.0;
    final trafficUsedGB = trafficUsed / (1024 * 1024 * 1024);
    final trafficTotalGB = trafficTotal > 0 ? trafficTotal / (1024 * 1024 * 1024) : 0.0;
    final trafficPercent = trafficTotal > 0 ? trafficUsed / trafficTotal : 0.0;

    String planLabel;
    if (isTrial) {
      planLabel = 'Пробный';
    } else {
      switch (plan) {
        case '1m':
          planLabel = '1 месяц';
          break;
        case '3m':
          planLabel = '3 месяца';
          break;
        case '6m':
          planLabel = '6 месяцев';
          break;
        case '12m':
          planLabel = '12 месяцев';
          break;
        default:
          planLabel = plan;
      }
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _loadProfile(api, userProfile, subscription, errorMsg, isLoading),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Gap(16),
                    // Avatar
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        FluentIcons.person_24_filled,
                        size: 40,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const Gap(12),
                    Text(
                      'ID: ${profile['telegram_id']}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const Gap(4),

                    // Plan badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isActive ? planLabel : 'Неактивна',
                        style: TextStyle(
                          color: isActive
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Gap(24),

                    // Days left card
                    if (isActive) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(FluentIcons.calendar_24_regular,
                                  color: theme.colorScheme.primary),
                              const Gap(12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Осталось дней',
                                        style: theme.textTheme.bodySmall),
                                    Text('$daysLeft',
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              if (daysLeft <= 7)
                                Icon(FluentIcons.warning_24_regular,
                                    color: theme.colorScheme.error),
                            ],
                          ),
                        ),
                      ),
                      const Gap(12),
                    ],

                    // Traffic usage card
                    if (trafficTotal > 0) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(FluentIcons.arrow_bidirectional_up_down_24_regular,
                                      color: theme.colorScheme.primary),
                                  const Gap(12),
                                  Text('Трафик',
                                      style: theme.textTheme.titleSmall),
                                ],
                              ),
                              const Gap(12),
                              LinearProgressIndicator(
                                value: trafficPercent.clamp(0.0, 1.0),
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              ),
                              const Gap(8),
                              Text(
                                '${trafficUsedGB.toStringAsFixed(1)} / ${trafficTotalGB.toStringAsFixed(0)} ГБ',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Gap(12),
                    ],

                    // Referral code
                    if (refCode.isNotEmpty) ...[
                      Card(
                        child: ListTile(
                          leading: Icon(FluentIcons.people_24_regular,
                              color: theme.colorScheme.primary),
                          title: const Text('Реферальный код'),
                          subtitle: Text(refCode),
                          trailing: IconButton(
                            icon: const Icon(FluentIcons.copy_24_regular),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: refCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Код скопирован')),
                              );
                            },
                          ),
                        ),
                      ),
                      if (bonusDays > 0) ...[
                        const Gap(4),
                        Text(
                          'Бонусных дней: $bonusDays',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                      const Gap(12),
                    ],
                  ],
                ),
              ),
            ),

            // Action buttons
            SliverList(
              delegate: SliverChildListDelegate([
                const Divider(),
                ListTile(
                  leading: Icon(FluentIcons.shopping_bag_24_regular,
                      color: theme.colorScheme.primary),
                  title: Text(isActive ? 'Продлить подписку' : 'Купить подписку'),
                  trailing: const Icon(FluentIcons.chevron_right_24_regular),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PlanSelectionPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(FluentIcons.people_24_regular),
                  title: const Text('Реферальная программа'),
                  trailing: const Icon(FluentIcons.chevron_right_24_regular),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ReferralPage(),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(FluentIcons.sign_out_24_regular,
                      color: theme.colorScheme.error),
                  title: Text('Выйти',
                      style: TextStyle(color: theme.colorScheme.error)),
                  onTap: () async {
                    await api.logout();
                    userProfile.value = null;
                    subscription.value = null;
                  },
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plan Selection Page (PRD 5.5)
class PlanSelectionPage extends HookConsumerWidget {
  const PlanSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(psrouteApiProvider);
    final plans = useState<List<Map<String, dynamic>>>([]);
    final isLoading = useState(true);
    final errorMsg = useState<String?>(null);

    useEffect(() {
      api.getPlans().then((p) {
        plans.value = p;
        isLoading.value = false;
      }).catchError((e) {
        errorMsg.value = e.toString();
        isLoading.value = false;
      });
      return null;
    }, []);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Выберите план'),
      ),
      body: isLoading.value
          ? const Center(child: CircularProgressIndicator())
          : errorMsg.value != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Не удалось загрузить тарифы',
                          style: theme.textTheme.titleMedium,
                        ),
                        const Gap(8),
                        Text(
                          errorMsg.value!,
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const Gap(16),
                        FilledButton(
                          onPressed: () {
                            isLoading.value = true;
                            errorMsg.value = null;
                            api.getPlans().then((p) {
                              plans.value = p;
                              isLoading.value = false;
                            }).catchError((e) {
                              errorMsg.value = e.toString();
                              isLoading.value = false;
                            });
                          },
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: plans.value.length,
              itemBuilder: (context, index) {
                final plan = plans.value[index];
                final badge = plan['badge'] as String?;
                final pricePerMonth = (plan['price_per_month'] as num?)?.toInt() ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _showPaymentMethods(context, api, plan),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      plan['name'] as String,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    if (badge != null) ...[
                                      const Gap(8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          badge,
                                          style: TextStyle(
                                            color: theme.colorScheme.onPrimary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const Gap(4),
                                Text(
                                  '${plan['traffic_gb']} ГБ · ${plan['devices']} устройства',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${plan['price_rub']} ₽',
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '$pricePerMonth ₽/мес',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showPaymentMethods(
    BuildContext context,
    PSRouteApiService api,
    Map<String, dynamic> plan,
  ) {
    final theme = Theme.of(context);
    final planId = plan['id'] as String;

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Способ оплаты',
                style: theme.textTheme.titleLarge,
              ),
              const Gap(16),
              ListTile(
                leading: const Icon(FluentIcons.payment_24_regular),
                title: const Text('Карта / СБП'),
                subtitle: const Text('Через LAVA'),
                trailing: const Icon(FluentIcons.chevron_right_24_regular),
                onTap: () => _processPayment(
                  context, sheetContext, api, planId, 'lava',
                ),
              ),
              ListTile(
                leading: const Icon(FluentIcons.currency_dollar_euro_24_regular),
                title: const Text('Криптовалюта'),
                subtitle: const Text('USDT, TON, BTC, ETH'),
                trailing: const Icon(FluentIcons.chevron_right_24_regular),
                onTap: () => _processPayment(
                  context, sheetContext, api, planId, 'cryptocloud',
                ),
              ),
              ListTile(
                leading: const Icon(FluentIcons.star_24_regular),
                title: const Text('Telegram Stars'),
                subtitle: Text('${plan['price_stars']} Stars'),
                trailing: const Icon(FluentIcons.chevron_right_24_regular),
                onTap: () => _processPayment(
                  context, sheetContext, api, planId, 'stars',
                ),
              ),
              const Gap(8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processPayment(
    BuildContext parentContext,
    BuildContext sheetContext,
    PSRouteApiService api,
    String planId,
    String method,
  ) async {
    Navigator.pop(sheetContext);

    // Track whether loading dialog is showing to prevent double-pop
    bool loadingDialogShown = false;

    // Show loading indicator
    if (parentContext.mounted) {
      loadingDialogShown = true;
      showDialog(
        context: parentContext,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final result = await api.createPayment(
        plan: planId,
        method: method,
      );

      // Close loading
      if (loadingDialogShown && parentContext.mounted) {
        Navigator.pop(parentContext);
        loadingDialogShown = false;
      }

      // Stars → redirect to Telegram bot
      if (result['redirect_to_bot'] == true) {
        final botUrl = result['bot_url'] as String?;
        if (botUrl != null && botUrl.isNotEmpty) {
          await UriUtils.tryLaunch(Uri.parse(botUrl));
        }
        return;
      }

      // LAVA / CryptoCloud → open payment URL in browser
      final paymentUrl = result['payment_url'] as String?;
      if (paymentUrl != null && paymentUrl.isNotEmpty) {
        final launched = await UriUtils.tryLaunch(Uri.parse(paymentUrl));
        if (!launched && parentContext.mounted) {
          await Clipboard.setData(ClipboardData(text: paymentUrl));
          ScaffoldMessenger.of(parentContext).showSnackBar(
            const SnackBar(content: Text('Ссылка скопирована — откройте в браузере')),
          );
        }
      }
    } catch (e) {
      // Close loading if still showing
      if (loadingDialogShown && parentContext.mounted) {
        Navigator.pop(parentContext);
        loadingDialogShown = false;
      }

      if (parentContext.mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $msg'),
            backgroundColor: Theme.of(parentContext).colorScheme.error,
          ),
        );
      }
    }
  }
}
