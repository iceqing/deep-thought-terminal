import 'package:flutter/material.dart';
import '../models/ssh_config_entry.dart';
import '../services/ssh_config_service.dart';
import '../l10n/app_localizations.dart';

class SshConfigScreen extends StatefulWidget {
  const SshConfigScreen({super.key});

  @override
  State<SshConfigScreen> createState() => _SshConfigScreenState();
}

class _SshConfigScreenState extends State<SshConfigScreen> {
  final _service = SshConfigService();
  List<SshConfigEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final entries = await _service.load();
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveConfig() async {
    try {
      await _service.save(_entries);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).sshConfigSaved),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _addHostBlock() {
    setState(() {
      // 查找下一个可用的 host 序号
      int maxNum = 0;
      for (final e in _entries) {
        final match = RegExp(r'^host(\d+)$').firstMatch(e.hostPattern);
        if (match != null) {
          final num = int.tryParse(match.group(1)!) ?? 0;
          if (num > maxNum) maxNum = num;
        }
      }
      _entries.add(SshConfigEntry(hostPattern: 'host${maxNum + 1}'));
    });
  }

  void _deleteHostBlock(int index) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.sshConfigDeleteHost),
        content: Text(l10n.sshConfigDeleteConfirm(_entries[index].displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _entries.removeAt(index);
              });
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _applyKeepAliveDefaults() {
    // 查找或创建全局 Host * 块
    SshConfigEntry? globalEntry;
    for (final e in _entries) {
      if (e.isGlobal) {
        globalEntry = e;
        break;
      }
    }

    if (globalEntry == null) {
      globalEntry = SshConfigEntry(hostPattern: '*');
      _entries.insert(0, globalEntry);
    }
    final targetEntry = globalEntry;

    setState(() {
      targetEntry.serverAliveInterval = 30;
      targetEntry.serverAliveCountMax = 3;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).sshConfigApplyKeepAlive),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sshConfig),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.sshConfigAddHost,
            onPressed: _addHostBlock,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: l10n.save,
            onPressed: _saveConfig,
          ),
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(l10n.sshConfigNoFile),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loadConfig,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings_ethernet, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(l10n.sshConfigNoFile),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _addHostBlock,
              icon: const Icon(Icons.add),
              label: Text(l10n.sshConfigCreateNew),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 快捷操作栏
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _applyKeepAliveDefaults,
                  icon: const Icon(Icons.speed, size: 18),
                  label: Text(
                    l10n.sshConfigApplyKeepAlive,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.sshConfigApplyKeepAliveDesc,
                style: Theme.of(context).textTheme.bodySmall,
                softWrap: true,
              ),
            ],
          ),
        ),
        // 配置列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _entries.length,
            itemBuilder: (context, index) {
              return _HostConfigTile(
                entry: _entries[index],
                onChanged: () => setState(() {}),
                onDelete: () => _deleteHostBlock(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 单个 Host 块的配置卡片
class _HostConfigTile extends StatelessWidget {
  final SshConfigEntry entry;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _HostConfigTile({
    required this.entry,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isGlobal = entry.isGlobal;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isGlobal
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            isGlobal ? Icons.public : Icons.computer,
            size: 20,
          ),
        ),
        title: Text(
          isGlobal ? l10n.sshConfigGlobal : entry.hostPattern,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isGlobal ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
        subtitle: Text(
          isGlobal ? 'Host *' : entry.hostPattern,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
          tooltip: l10n.sshConfigDeleteHost,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Host Pattern
                TextField(
                  decoration: InputDecoration(
                    labelText: l10n.sshConfigHostPattern,
                    hintText: l10n.sshConfigHostPatternHint,
                    isDense: true,
                  ),
                  controller: TextEditingController(text: entry.hostPattern),
                  onChanged: (value) {
                    entry.hostPattern = value;
                    onChanged();
                  },
                ),
                const SizedBox(height: 16),

                // Keep-Alive
                _SectionHeader(title: l10n.sshConfigKeepAlive),
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(
                        label: l10n.sshConfigServerAliveInterval,
                        value: entry.serverAliveInterval,
                        onChanged: (v) {
                          entry.serverAliveInterval = v;
                          onChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _NumberField(
                        label: l10n.sshConfigServerAliveCountMax,
                        value: entry.serverAliveCountMax,
                        onChanged: (v) {
                          entry.serverAliveCountMax = v;
                          onChanged();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Connection
                _SectionHeader(title: l10n.sshConfigConnection),
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(
                        label: l10n.sshConfigConnectTimeout,
                        value: entry.connectTimeout,
                        onChanged: (v) {
                          entry.connectTimeout = v;
                          onChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _NumberField(
                        label: l10n.sshConfigConnectionAttempts,
                        value: entry.connectionAttempts,
                        onChanged: (v) {
                          entry.connectionAttempts = v;
                          onChanged();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(
                        label: l10n.sshPort,
                        value: entry.port,
                        onChanged: (v) {
                          entry.port = v;
                          onChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TextField(
                        label: l10n.sshUsername,
                        value: entry.user ?? '',
                        onChanged: (v) {
                          entry.user = v.isEmpty ? null : v;
                          onChanged();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Authentication
                _SectionHeader(title: l10n.sshConfigAuth),
                _TextField(
                  label: l10n.sshConfigIdentityFile,
                  value: entry.identityFile ?? '',
                  hint: '~/.ssh/id_rsa',
                  onChanged: (v) {
                    entry.identityFile = v.isEmpty ? null : v;
                    onChanged();
                  },
                ),
                const SizedBox(height: 8),
                _DropdownField(
                  label: l10n.sshConfigPreferredAuth,
                  value: entry.preferredAuthentications,
                  items: const [null, 'publickey', 'password', 'publickey,password,keyboard-interactive'],
                  itemLabels: const ['Default', 'publickey', 'password', 'publickey,password,keyboard-interactive'],
                  onChanged: (v) {
                    entry.preferredAuthentications = v;
                    onChanged();
                  },
                ),
                const SizedBox(height: 16),

                // Security
                _SectionHeader(title: l10n.sshConfigSecurity),
                _DropdownField(
                  label: l10n.sshConfigStrictHostKey,
                  value: entry.strictHostKeyChecking,
                  items: const [null, 'yes', 'no', 'ask', 'accept-new'],
                  itemLabels: const ['Default', 'yes', 'no', 'ask', 'accept-new'],
                  onChanged: (v) {
                    entry.strictHostKeyChecking = v;
                    onChanged();
                  },
                ),
                const SizedBox(height: 16),

                // Performance
                _SectionHeader(title: l10n.sshConfigPerformance),
                _SwitchField(
                  label: l10n.sshConfigCompression,
                  value: entry.compression == 'yes',
                  onChanged: (v) {
                    entry.compression = v ? 'yes' : 'no';
                    onChanged();
                  },
                ),
                _SwitchField(
                  label: l10n.sshConfigForwardAgent,
                  value: entry.forwardAgent == 'yes',
                  onChanged: (v) {
                    entry.forwardAgent = v ? 'yes' : 'no';
                    onChanged();
                  },
                ),
                _SwitchField(
                  label: l10n.sshConfigTcpKeepAlive,
                  value: entry.tcpKeepAlive == 'yes',
                  onChanged: (v) {
                    entry.tcpKeepAlive = v ? 'yes' : 'no';
                    onChanged();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final int? value;
  final void Function(int?) onChanged;

  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      controller: TextEditingController(text: value?.toString() ?? ''),
      onChanged: (v) => onChanged(int.tryParse(v)),
    );
  }
}

class _TextField extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final void Function(String) onChanged;

  const _TextField({
    required this.label,
    required this.value,
    this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
      ),
      controller: TextEditingController(text: value),
      onChanged: onChanged,
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String?> items;
  final List<String> itemLabels;
  final void Function(String?) onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
      ),
      value: value,
      items: List.generate(items.length, (i) {
        return DropdownMenuItem(
          value: items[i],
          child: Text(itemLabels[i]),
        );
      }),
      onChanged: onChanged,
    );
  }
}

class _SwitchField extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;

  const _SwitchField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
