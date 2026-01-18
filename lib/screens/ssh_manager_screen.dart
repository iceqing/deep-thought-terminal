import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ssh_host.dart';
import '../providers/ssh_provider.dart';
import '../providers/terminal_provider.dart';

class SSHManagerScreen extends StatelessWidget {
  const SSHManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sshProvider = context.watch<SSHProvider>();

    // Determine colors based on theme if possible, otherwise fallback to Material colors
    // We can use the theme.foreground/background for a custom feel or standard Scaffold colors.
    // Let's mix standard Scaffold with terminal colors for the list items.

    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH Connections'),
        actions: [
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
                  Icon(Icons.computer, size: 64, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text('No SSH hosts saved'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _showEditDialog(context, null),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Host'),
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
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Host'),
                        content: Text('Are you sure you want to delete ${host.displayName}?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) {
                    sshProvider.removeHost(host.id);
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        host.displayName.characters.first.toUpperCase(),
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
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
    
    // Create new session
    terminalProvider.createSession(title: host.displayName).then((session) {
      // Small delay to ensure shell is ready to receive input
      Future.delayed(const Duration(milliseconds: 300), () {
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
    _portController = TextEditingController(text: widget.host?.port.toString() ?? '22');
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
    return AlertDialog(
      title: Text(widget.host == null ? 'Add SSH Host' : 'Edit SSH Host'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _aliasController,
              decoration: const InputDecoration(
                labelText: 'Alias (Optional)',
                hintText: 'My Server',
                border: OutlineInputBorder(),
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
                    decoration: const InputDecoration(
                      labelText: 'Host',
                      hintText: '192.168.1.1 or example.com',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress, // for better keyboard
                    autocorrect: false,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'root',
                border: OutlineInputBorder(),
              ),
              autocorrect: false,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _argsController,
              decoration: const InputDecoration(
                labelText: 'Extra Args (Optional)',
                hintText: '-i /path/to/key.pem',
                border: OutlineInputBorder(),
              ),
              autocorrect: false,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    final hostStr = _hostController.text.trim();
    if (hostStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Host is required')),
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
