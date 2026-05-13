import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class EmptyProfilesHomeBody extends HookConsumerWidget {
  const EmptyProfilesHomeBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;

    return SliverFillRemaining(
      hasScrollBody: false,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            t.dialogs.noActiveProfile.msg,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const Gap(16),
          ElevatedButton.icon(
            onPressed: () => context.goNamed('account'),
            icon: const Icon(Icons.person_rounded),
            label: Text(t.dialogs.noActiveProfile.helpBtn.label),
          ),
        ],
      ),
    );
  }
}

// class EmptyActiveProfileHomeBody extends HookConsumerWidget {
//   const EmptyActiveProfileHomeBody({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final t = ref.watch(translationsProvider).requireValue;

//     return SliverFillRemaining(
//       hasScrollBody: false,
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Text(t.home.noActiveProfileMsg),
//           const Gap(16),
//           OutlinedButton(
//             onPressed: () => const ProfilesOverviewRoute().push(context),
//             child: Text(t.profile.overviewPageTitle),
//           ),
//         ],
//       ),
//     );
//   }
// }
