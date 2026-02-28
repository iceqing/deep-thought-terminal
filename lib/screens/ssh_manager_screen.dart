import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ssh_host.dart';
import '../providers/auth_provider.dart';
import '../providers/ssh_provider.dart';
import '../providers/terminal_provider.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import 'ssh_config_screen.dart';

class SSHManagerScreen extends StatelessWidget {
  const SSHManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sshProvider = context.watch<SSHProvider>();
    final l10n = AppLocalizations.of(context);

    // Determine colors based on theme if possible, otherwise fallback to Material colors
    // We can use the theme.foreground/background for a custom feel or standard Scaffold colors.
    // Let's mix standard Scaffold with terminal colors for the list items.

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sshConnections),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_ethernet),
            tooltip: l10n.sshConfig,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SshConfigScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEditDialog(context, null),
          ),
        ],
      ),
      body: sshProvider.hosts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.computer,
                      size: 64, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(l10n.sshNoHosts),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _showEditDialog(context, null),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addHost),
                  ),
                ],
              ),
            )
          : ListView.separated(
              itemCount: sshProvider.hosts.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final host = sshProvider.hosts[index];
                return Dismissible(
                  key: Key(host.id),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (context) {
                        final l10n = AppLocalizations.of(context);
                        return AlertDialog(
                          title: Text(l10n.deleteHost),
                          content: Text(l10n.deleteHostConfirm
                              .replaceAll('{name}', host.displayName)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(l10n.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(l10n.delete,
                                  style: const TextStyle(color: Colors.red)),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  onDismissed: (direction) {
                    sshProvider.removeHost(host.id);
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        host.displayName.characters.first.toUpperCase(),
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer),
                      ),
                    ),
                    title: Text(host.displayName),
                    subtitle: Text(
                      '${host.username}@${host.host}:${host.port}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showEditDialog(context, host),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => _connectToHost(context, host),
                  ),
                );
              },
            ),
    );
  }

  void _connectToHost(BuildContext context, SSHHost host) {
    final terminalProvider = context.read<TerminalProvider>();
    final shouldUploadHistory = context.read<AuthProvider>().isLoggedIn;

    // Create new session
    terminalProvider
        .createSession(title: host.displayName, isSshSession: true)
        .then((session) {
      // Small delay to ensure shell is ready to receive input
      Future.delayed(const Duration(milliseconds: 300), () {
        if (shouldUploadHistory) {
          ApiService.addHistory(host.command, sessionName: session.displayName);
        }
        // Send SSH command
        session.write('${host.command}\r');
      });
    });

    Navigator.pop(context); // Close manager
  }

  void _showEditDialog(BuildContext context, SSHHost? host) {
    showDialog(
      context: context,
      builder: (context) => _SSHEditDialog(host: host),
    );
  }
}

class _SSHEditDialog extends StatefulWidget {
  final SSHHost? host;

  const _SSHEditDialog({this.host});

  @override
  State<_SSHEditDialog> createState() => _SSHEditDialogState();
}

class _SSHEditDialogState extends State<_SSHEditDialog> {
  late TextEditingController _aliasController;
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _usernameController;
  late TextEditingController _argsController;

  @override
  void initState() {
    super.initState();
    _aliasController = TextEditingController(text: widget.host?.alias);
    _hostController = TextEditingController(text: widget.host?.host);
    _portController =
        TextEditingController(text: widget.host?.port.toString() ?? '22');
    _usernameController = TextEditingController(text: widget.host?.username);
    _argsController = TextEditingController(text: widget.host?.args);
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _argsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.host == null ? l10n.addHost : l10n.editHost),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _aliasController,
              decoration: InputDecoration(
                labelText: '${l10n.displayName} (${l10n.optional})',
                hintText: 'My Server',
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _hostController,
                    decoration: InputDecoration(
                      labelText: l10n.sshHost,
                      hintText: '192.168.1.1 or example.com',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType:
                        TextInputType.emailAddress, // for better keyboard
                    autocorrect: false,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _portController,
                    decoration: InputDecoration(
                      labelText: l10n.sshPort,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: l10n.sshUsername,
                hintText: 'root',
                border: const OutlineInputBorder(),
              ),
              autocorrect: false,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _argsController,
              decoration: InputDecoration(
                labelText: 'Extra Args (${l10n.optional})',
                hintText: '-i /path/to/key.pem',
                border: const OutlineInputBorder(),
              ),
              autocorrect: false,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }

  void _save() {
    final l10n = AppLocalizations.of(context);
    final hostStr = _hostController.text.trim();
    if (hostStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.hostRequired)),
      );
      return;
    }

    final newHost = SSHHost(
      id: widget.host?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      alias: _aliasController.text.trim(),
      host: hostStr,
      port: int.tryParse(_portController.text) ?? 22,
      username: _usernameController.text.trim(),
      args: _argsController.text.trim(),
    );

    final provider = context.read<SSHProvider>();
    if (widget.host == null) {
      provider.addHost(newHost);
    } else {
      provider.updateHost(newHost);
    }

    Navigator.pop(context);
  }
}
