import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/features/ai_proxy/widget/ai_pricing_page.dart';
import 'package:hiddify/features/ai_proxy/widget/ai_proxy_page.dart';
import 'package:hiddify/features/psroute_api/psroute_api_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Gate page: checks AI subscription → shows chat or pricing.
/// No login here — login lives on the Account tab.
class AIGatePage extends HookConsumerWidget {
  const AIGatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(psrouteApiProvider);
    final theme = Theme.of(context);

    // Loading / subscription state
    final isLoading = useState(true);
    final hasAiAccess = useState(false);
    final errorMsg = useState<String?>(null);

    useEffect(() {
      if (!api.isAuthenticated) {
        isLoading.value = false;
        hasAiAccess.value = false;
        return null;
      }
      // Check user profile for AI tier
      api.getUserProfile().then((profile) {
        final aiTier = profile['ai_tier'] as String?;
        final aiExpiresAt = profile['ai_expires_at'] as String?;
        if (aiTier != null && aiTier.isNotEmpty && aiTier != 'none') {
          // Check expiry
          if (aiExpiresAt != null) {
            final expiry = DateTime.tryParse(aiExpiresAt);
            if (expiry != null && expiry.isAfter(DateTime.now())) {
              hasAiAccess.value = true;
            }
          } else {
            // No expiry set — lifetime or unlimited
            hasAiAccess.value = true;
          }
        }
        isLoading.value = false;
      }).catchError((e) {
        errorMsg.value = e.toString();
        isLoading.value = false;
      });
      return null;
    }, [api.isAuthenticated]);

    if (isLoading.value) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI Чат')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Not logged in → redirect to Account tab
    if (!api.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI Чат')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    FluentIcons.bot_sparkle_24_filled,
                    size: 36,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Gap(20),
                Text(
                  'Войдите в аккаунт',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Gap(8),
                Text(
                  'Для доступа к AI Чату необходимо войти в аккаунт',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Gap(24),
                FilledButton.icon(
                  onPressed: () => context.goNamed('account'),
                  icon: const Icon(FluentIcons.person_24_regular),
                  label: const Text('Перейти в Аккаунт'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Has AI access → show chat
    if (hasAiAccess.value) {
      return const AIProxyPage();
    }

    // No AI subscription → show pricing
    return const AIPricingPage();
  }
}
