// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'widgets/connection_bar.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const ProviderScope(child: RosMonitorApp()));
}

class RosMonitorApp extends StatelessWidget {
  const RosMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ROS Monitor',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      home: const _AppShell(),
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // top connection bar
          const ConnectionBar(),
          const Divider(height: 1, color: AppTheme.border),
          // main dashboard
          const Expanded(child: DashboardScreen()),
        ],
      ),
    );
  }
}
