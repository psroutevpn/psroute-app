import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/features/psroute_api/psroute_api_service.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AIProxyPage extends HookConsumerWidget {
  const AIProxyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(psrouteApiProvider);
    final theme = Theme.of(context);

    final messages = useState<List<Map<String, String>>>([]);
    final isLoading = useState(false);
    final selectedModel = useState('gpt-4o');
    final textController = useTextEditingController();
    final scrollController = useScrollController();

    // Fetch available models from API
    final availableModels = useState<List<Map<String, dynamic>>>([
      {'id': 'gpt-4o', 'name': 'GPT-4o'},
      {'id': 'claude-sonnet', 'name': 'Claude Sonnet'},
      {'id': 'gemini-pro', 'name': 'Gemini Pro'},
    ]);

    useEffect(() {
      if (api.isAuthenticated) {
        api.getAIModels().then((data) {
          final models = data['models'] as List?;
          if (models != null && models.isNotEmpty) {
            availableModels.value = List<Map<String, dynamic>>.from(models);
          }
        }).catchError((_) {}); // fallback to hardcoded
      }
      return null;
    }, [api.isAuthenticated]);

    if (!api.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI Прокси')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.bot_24_regular, size: 64, color: theme.colorScheme.primary),
                const Gap(16),
                Text('Доступ к AI моделям', style: theme.textTheme.headlineSmall),
                const Gap(8),
                Text(
                  'Войдите в аккаунт для доступа к ChatGPT, Claude и другим моделям',
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.textTheme.bodySmall?.color),
                  textAlign: TextAlign.center,
                ),
                const Gap(24),
                FilledButton(
                  onPressed: () {
                    UriUtils.tryLaunch(
                      Uri.parse('https://t.me/PSRouteBot?start=login'),
                    );
                  },
                  child: const Text('Войти в аккаунт'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Прокси'),
        actions: [
          // Model selector — dynamic from API
          PopupMenuButton<String>(
            initialValue: selectedModel.value,
            onSelected: (value) => selectedModel.value = value,
            itemBuilder: (context) => availableModels.value
                .map((m) => PopupMenuItem(
                      value: m['id'] as String,
                      child: Text(m['name'] as String? ?? m['id'] as String),
                    ))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(selectedModel.value, style: theme.textTheme.bodyMedium),
                  const Gap(4),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messages.value.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.bot_sparkle_24_regular,
                            size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                        const Gap(12),
                        Text(
                          'Задайте вопрос AI',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.value.length,
                    itemBuilder: (context, index) {
                      final msg = messages.value[index];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.8,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: isUser
                              ? Text(msg['content'] ?? '')
                              : MarkdownBody(data: msg['content'] ?? ''),
                        ),
                      );
                    },
                  ),
          ),

          // Loading indicator
          if (isLoading.value)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(color: theme.colorScheme.primary),
            ),

          // Input field
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textController,
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Введите сообщение...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(
                        api, textController, messages, isLoading,
                        selectedModel, scrollController,
                      ),
                    ),
                  ),
                  const Gap(8),
                  IconButton.filled(
                    onPressed: isLoading.value
                        ? null
                        : () => _sendMessage(
                            api, textController, messages, isLoading,
                            selectedModel, scrollController,
                          ),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(
    PSRouteApiService api,
    TextEditingController controller,
    ValueNotifier<List<Map<String, String>>> messages,
    ValueNotifier<bool> isLoading,
    ValueNotifier<String> selectedModel,
    ScrollController scrollController,
  ) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    controller.clear();
    messages.value = [
      ...messages.value,
      {'role': 'user', 'content': text},
    ];
    isLoading.value = true;

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      final response = await api.aiChat(
        model: selectedModel.value,
        message: text,
        history: messages.value.length > 1
            ? messages.value.sublist(0, messages.value.length - 1)
            : null,
      );
      final choices = response['choices'] as List?;
      final reply = choices?.firstOrNull;
      final content = reply?['message']?['content'] as String? ?? 'Нет ответа';

      messages.value = [
        ...messages.value,
        {'role': 'assistant', 'content': content},
      ];
    } catch (e) {
      messages.value = [
        ...messages.value,
        {'role': 'assistant', 'content': 'Ошибка: ${e.toString()}'},
      ];
    } finally {
      isLoading.value = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }
}
