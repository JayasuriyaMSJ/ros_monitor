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

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(connectionConfigProvider);
    _hostCtrl = TextEditingController(text: cfg.host);
    _portCtrl = TextEditingController(text: cfg.port.toString());
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  void _connect() {
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9090;
    final cfg = ref.read(connectionConfigProvider).copyWith(
          host: host,
          port: port,
        );
    ref.read(connectionConfigProvider.notifier).update(cfg);
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
    final statusAsync = ref.watch(connectionStatusProvider);
    final status = statusAsync.value ?? ConnectionStatus.disconnected;
    final isConnected = status == ConnectionStatus.connected;
    final isConnecting = status == ConnectionStatus.connecting;

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

          // host
          SizedBox(
            width: 160,
            child: TextField(
              controller: _hostCtrl,
              style: AppTheme.mono(size: 12),
              decoration: const InputDecoration(
                hintText: 'host / IP',
                prefixText: 'ws://',
              ),
              onSubmitted: (_) => _connect(),
            ),
          ),
          const SizedBox(width: 6),

          // port
          SizedBox(
            width: 72,
            child: TextField(
              controller: _portCtrl,
              style: AppTheme.mono(size: 12),
              decoration: const InputDecoration(hintText: 'port'),
              keyboardType: TextInputType.number,
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
            ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)]
            : null,
      ),
    );
  }
}
