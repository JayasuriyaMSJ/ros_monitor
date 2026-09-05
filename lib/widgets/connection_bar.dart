// lib/widgets/connection_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/rosbridge_service.dart';
import '../providers/workspace_provider.dart';
import '../theme/app_theme.dart';

class ConnectionBar extends ConsumerStatefulWidget {
  const ConnectionBar({super.key});

  @override
  ConsumerState<ConnectionBar> createState() => _ConnectionBarState();
}

class _ConnectionBarState extends ConsumerState<ConnectionBar> {
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  late final FocusNode _hostFocus;
  bool _userEditedHost = false;
  bool _userEditedPort = false;

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(connectionConfigProvider);
    _hostCtrl = TextEditingController(text: cfg.host);
    _portCtrl = TextEditingController(text: cfg.port.toString());
    _hostFocus = FocusNode();
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _hostFocus.dispose();
    super.dispose();
  }

  void _connect() {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) return;
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9090;
    final cfg = ref.read(connectionConfigProvider).copyWith(
          host: host,
          port: port,
        );
    ref.read(connectionConfigProvider.notifier).update(cfg);
    ref.read(ipHistoryProvider.notifier).addHost(host);
    ref.read(rosBridgeServiceProvider).connect(cfg.uri);
  }

  void _disconnect() {
    ref.read(rosBridgeServiceProvider).disconnect();
  }

  void _refreshTopics() {
    ref.read(rosBridgeServiceProvider).requestTopics();
  }

  @override
  Widget build(BuildContext context) {
    // Automatically populate controllers when saved config finishes loading from SharedPreferences
    ref.listen(connectionConfigProvider, (prev, next) {
      if (!_userEditedHost && _hostCtrl.text != next.host) {
        _hostCtrl.text = next.host;
      }
      if (!_userEditedPort && _portCtrl.text != next.port.toString()) {
        _portCtrl.text = next.port.toString();
      }
    });

    final statusAsync = ref.watch(connectionStatusProvider);
    final status = statusAsync.value ?? ConnectionStatus.disconnected;
    final isConnected = status == ConnectionStatus.connected;
    final isConnecting = status == ConnectionStatus.connecting;
    final history = ref.watch(ipHistoryProvider);

    return Container(
      height: 46,
      color: AppTheme.bg1,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // logo / title
          Text('ROS Monitor',
              style: AppTheme.ui(
                  size: 13,
                  weight: FontWeight.w600,
                  color: AppTheme.textPrim)),
          const SizedBox(width: 20),

          // status dot
          _StatusDot(status: status),
          const SizedBox(width: 8),

          // host with autocomplete & dropdown menu from history
          SizedBox(
            width: 210,
            child: RawAutocomplete<String>(
              textEditingController: _hostCtrl,
              focusNode: _hostFocus,
              optionsBuilder: (TextEditingValue textVal) {
                if (textVal.text.trim().isEmpty) {
                  return history;
                }
                return history.where((ip) =>
                    ip.toLowerCase().contains(textVal.text.toLowerCase()));
              },
              onSelected: (String selection) {
                _hostCtrl.text = selection;
                _userEditedHost = true;
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: AppTheme.mono(size: 12),
                  decoration: InputDecoration(
                    hintText: 'host / IP',
                    prefixText: 'ws://',
                    prefixStyle: AppTheme.mono(size: 12, color: AppTheme.textMuted),
                    contentPadding: const EdgeInsets.only(left: 8, right: 4, top: 8, bottom: 8),
                    suffixIcon: history.isEmpty
                        ? null
                        : PopupMenuButton<String>(
                            tooltip: 'IP history',
                            icon: const Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.textSec),
                            padding: EdgeInsets.zero,
                            color: AppTheme.bg2,
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: const BorderSide(color: AppTheme.border),
                            ),
                            onSelected: (ip) {
                              _hostCtrl.text = ip;
                              _userEditedHost = true;
                            },
                            itemBuilder: (popupCtx) => [
                              PopupMenuItem<String>(
                                enabled: false,
                                height: 26,
                                child: Text('RECENT IPS',
                                    style: AppTheme.ui(
                                        size: 10,
                                        weight: FontWeight.w600,
                                        color: AppTheme.textMuted)),
                              ),
                              for (final ip in history)
                                PopupMenuItem<String>(
                                  value: ip,
                                  height: 32,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.history, size: 13, color: AppTheme.textMuted),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(ip,
                                            style: AppTheme.mono(size: 12, color: AppTheme.textPrim),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 12, color: AppTheme.textMuted),
                                        splashRadius: 10,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                        onPressed: () {
                                          Navigator.pop(popupCtx);
                                          ref.read(ipHistoryProvider.notifier).removeHost(ip);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),
                  onChanged: (_) => _userEditedHost = true,
                  onSubmitted: (_) => _connect(),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                if (options.isEmpty) return const SizedBox.shrink();
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 8,
                    color: AppTheme.bg2,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 210,
                      decoration: BoxDecoration(
                        color: AppTheme.bg2,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.border),
                      ),
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return InkWell(
                            onTap: () => onSelected(option),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.history, size: 13, color: AppTheme.textMuted),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: AppTheme.mono(size: 12, color: AppTheme.textPrim),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 6),

          // port
          SizedBox(
            width: 70,
            child: TextField(
              controller: _portCtrl,
              style: AppTheme.mono(size: 12),
              decoration: const InputDecoration(hintText: 'port'),
              keyboardType: TextInputType.number,
              onChanged: (_) => _userEditedPort = true,
              onSubmitted: (_) => _connect(),
            ),
          ),
          const SizedBox(width: 8),

          // connect / disconnect button
          isConnected
              ? OutlinedButton(
                  onPressed: _disconnect,
                  child: const Text('disconnect'),
                )
              : ElevatedButton(
                  onPressed: isConnecting ? null : _connect,
                  child: isConnecting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('connect'),
                ),

          const SizedBox(width: 8),
          if (isConnected)
            Tooltip(
              message: 'refresh topic list',
              child: IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _refreshTopics,
                color: AppTheme.textSec,
              ),
            ),

          const Spacer(),

          // status label
          Text(
            _statusLabel(status),
            style: AppTheme.ui(size: 11, color: _statusColor(status)),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _statusLabel(ConnectionStatus s) => switch (s) {
        ConnectionStatus.connected    => 'connected',
        ConnectionStatus.connecting   => 'connecting…',
        ConnectionStatus.error        => 'connection error — retrying',
        ConnectionStatus.disconnected => 'disconnected',
      };

  Color _statusColor(ConnectionStatus s) => switch (s) {
        ConnectionStatus.connected    => AppTheme.accentAlt,
        ConnectionStatus.connecting   => AppTheme.warn,
        ConnectionStatus.error        => AppTheme.err,
        ConnectionStatus.disconnected => AppTheme.textMuted,
      };
}

class _StatusDot extends StatelessWidget {
  final ConnectionStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ConnectionStatus.connected    => AppTheme.accentAlt,
      ConnectionStatus.connecting   => AppTheme.warn,
      ConnectionStatus.error        => AppTheme.err,
      ConnectionStatus.disconnected => AppTheme.textMuted,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: status == ConnectionStatus.connected
            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
            : null,
      ),
    );
  }
}
