import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/providers/providers.dart';
import '../utility/app_localizations.dart';

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  // Metodo statico per aprire pannello dal basso da qualsiasi pagina
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    // Osserviamo stati reattivi da Riverpod
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final habitualCounts = ref.watch(habitualProductsProvider);

    final isDark = themeMode == ThemeMode.dark;
    final hasHistory = habitualCounts.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titolo del pannello Impostazioni
            Text(
              loc.translate('settings_title'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),

            // 1. Switch Tema Chiaro / Scuro
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(loc.translate('dark_mode')),
              value: isDark,
              onChanged: (_) {
                ref.read(themeModeProvider.notifier).toggleTheme();
              },
            ),

            const SizedBox(height: 8),

            // 2. Selettore Lingua (IT / EN)
            Row(
              children: [
                Icon(
                  Icons.language_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    loc.translate('language'),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment<String>(value: 'it', label: Text('IT')),
                    ButtonSegment<String>(value: 'en', label: Text('EN')),
                  ],
                  selected: {locale.languageCode},
                  onSelectionChanged: (selection) {
                    ref
                        .read(localeProvider.notifier)
                        .setLanguage(selection.first);
                  },
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(),
            ),

            // 3. Tasto Privacy: Azzera cronologia acquisti abituali
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: hasHistory,
              leading: Icon(
                Icons.delete_outline_rounded,
                color: hasHistory
                    ? theme.colorScheme.error
                    : theme.disabledColor,
              ),
              title: Text(
                hasHistory
                    ? '${loc.translate('reset_history')} (${habitualCounts.length})'
                    : loc.translate('reset_history'),
                style: TextStyle(
                  color: hasHistory ? theme.colorScheme.error : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(loc.translate('reset_history_subtitle')),
              onTap: hasHistory
                  ? () async {
                await ref
                    .read(habitualProductsProvider.notifier)
                    .clearHistory();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(loc.translate('history_cleared')),
                    ),
                  );
                }
              }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}