import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Phase 3 onboarding tutorial — shows on first launch after intro screen.
/// 3 pages: Welcome, How it works, Permissions.
class OnboardingPage extends HookConsumerWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pageController = usePageController();
    final currentPage = useState(0);

    final pages = [
      _OnboardingStep(
        icon: Icons.shield_rounded,
        iconColor: theme.colorScheme.primary,
        title: 'Добро пожаловать в PS Route',
        subtitle: 'Быстрый и надёжный VPN\nдля вашей приватности',
      ),
      _OnboardingStep(
        icon: Icons.touch_app_rounded,
        iconColor: theme.colorScheme.tertiary,
        title: 'Как это работает',
        subtitle: 'Установите → Нажмите кнопку → Пользуйтесь свободным интернетом',
      ),
      _OnboardingStep(
        icon: Icons.vpn_lock_rounded,
        iconColor: theme.colorScheme.secondary,
        title: 'VPN подключение',
        subtitle: 'Приложение запросит разрешение на VPN-подключение.\n'
            'Это нужно для безопасного туннелирования трафика.',
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: pageController,
                itemCount: pages.length,
                onPageChanged: (i) => currentPage.value = i,
                itemBuilder: (_, index) => pages[index],
              ),
            ),

            // Page indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: currentPage.value == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: currentPage.value == i
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (currentPage.value > 0)
                    TextButton(
                      onPressed: () {
                        pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('Назад'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      if (currentPage.value < pages.length - 1) {
                        pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text(
                      currentPage.value < pages.length - 1 ? 'Далее' : 'Начать',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: iconColor),
          const Gap(32),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const Gap(16),
          Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
