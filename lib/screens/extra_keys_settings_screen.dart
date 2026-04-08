import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/extra_key_layout.dart';
import '../providers/settings_provider.dart';
import '../widgets/extra_keys.dart';

class ExtraKeysSettingsScreen extends StatelessWidget {
  const ExtraKeysSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<SettingsProvider>();
    final layout = settings.extraKeysLayout;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.extraKeysLayout)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _SectionCard(
            title: l10n.showExtraKeys,
            subtitle: l10n.showExtraKeysDesc,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.keyboard),
              title: Text(l10n.showExtraKeys),
              subtitle: Text(l10n.showExtraKeysDesc),
              value: settings.showExtraKeys,
              onChanged: (value) => settings.setShowExtraKeys(value),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.extraKeysPosition,
            subtitle: l10n.extraKeysLayoutDesc,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExtraKeysPosition.values.map((position) {
                return ChoiceChip(
                  label: Text(_positionLabel(l10n, position)),
                  selected: layout.position == position,
                  onSelected: (_) => context
                      .read<SettingsProvider>()
                      .setExtraKeysPosition(position),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.extraKeysLayout,
            subtitle: l10n.extraKeysTapToChange,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LayoutPreview(layout: layout),
                const SizedBox(height: 12),
                Text(
                  l10n.extraKeysMenuLocked,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () =>
                        context.read<SettingsProvider>().resetExtraKeysLayout(),
                    icon: const Icon(Icons.restart_alt),
                    label: Text(l10n.resetToDefaults),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _positionLabel(AppLocalizations l10n, String position) {
    switch (position) {
      case ExtraKeysPosition.top:
        return l10n.extraKeysPositionTop;
      case ExtraKeysPosition.bottom:
      default:
        return l10n.extraKeysPositionBottom;
    }
  }
}

class _LayoutPreview extends StatelessWidget {
  final ExtraKeysLayoutConfig layout;

  const _LayoutPreview({required this.layout});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(ExtraKeysLayoutConfig.rowCount, (rowIndex) {
        return Row(
          children: List.generate(ExtraKeysLayoutConfig.columnCount, (column) {
            final keyId = layout.rows[rowIndex][column];
            final isEditable =
                ExtraKeysLayoutConfig.isEditableCell(rowIndex, column);

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: _LayoutCell(
                  keyId: keyId,
                  editable: isEditable,
                  onTap: isEditable
                      ? () => _showKeyPicker(context, rowIndex, column, keyId)
                      : null,
                ),
              ),
            );
          }),
        );
      }),
    );
  }

  Future<void> _showKeyPicker(
    BuildContext context,
    int row,
    int column,
    String currentKeyId,
  ) async {
    final settings = context.read<SettingsProvider>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext);

        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.82,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Text(
                    l10n.extraKeysTapToChange,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      _PickerSection(
                        title: l10n.categoryCommon,
                        keyIds: ExtraKeyIds.common,
                        currentKeyId: currentKeyId,
                        onSelected: (keyId) async {
                          await settings.setExtraKeysKey(row, column, keyId);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                      ),
                      _PickerSection(
                        title: l10n.categoryNav,
                        keyIds: ExtraKeyIds.navigation,
                        currentKeyId: currentKeyId,
                        onSelected: (keyId) async {
                          await settings.setExtraKeysKey(row, column, keyId);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                      ),
                      _PickerSection(
                        title: l10n.categorySymbols,
                        keyIds: ExtraKeyIds.symbols,
                        currentKeyId: currentKeyId,
                        onSelected: (keyId) async {
                          await settings.setExtraKeysKey(row, column, keyId);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                      ),
                      _PickerSection(
                        title: l10n.categoryFKeys,
                        keyIds: ExtraKeyIds.functionKeys,
                        currentKeyId: currentKeyId,
                        onSelected: (keyId) async {
                          await settings.setExtraKeysKey(row, column, keyId);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LayoutCell extends StatelessWidget {
  final String keyId;
  final bool editable;
  final VoidCallback? onTap;

  const _LayoutCell({
    required this.keyId,
    required this.editable,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final key = ExtraKeys.fromId(keyId);

    return Material(
      color: editable
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 56,
          child: Center(
            child: key?.icon != null
                ? Icon(
                    key!.icon,
                    size: 20,
                    color: editable
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onPrimaryContainer,
                  )
                : Text(
                    ExtraKeys.visualLabel(keyId),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: editable
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _PickerSection extends StatelessWidget {
  final String title;
  final List<String> keyIds;
  final String currentKeyId;
  final Future<void> Function(String keyId) onSelected;

  const _PickerSection({
    required this.title,
    required this.keyIds,
    required this.currentKeyId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...keyIds.map((keyId) {
          final selected = currentKeyId == keyId;
          return ListTile(
            leading: _PickerPreview(keyId: keyId),
            title: Text(ExtraKeys.localizedLabel(context, keyId)),
            trailing: selected
                ? Icon(Icons.check, color: theme.colorScheme.primary)
                : null,
            onTap: () => onSelected(keyId),
          );
        }),
      ],
    );
  }
}

class _PickerPreview extends StatelessWidget {
  final String keyId;

  const _PickerPreview({required this.keyId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final key = ExtraKeys.fromId(keyId);

    return Container(
      width: 40,
      height: 32,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: key?.icon != null
          ? Icon(key!.icon, size: 18, color: theme.colorScheme.onSurface)
          : Text(
              ExtraKeys.visualLabel(keyId),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
