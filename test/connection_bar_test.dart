// test/connection_bar_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ros_monitor/providers/workspace_provider.dart';
import 'package:ros_monitor/widgets/connection_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ConnectionBar renders host, port, and connect controls', (tester) async {
    SharedPreferences.setMockInitialValues({
      'connection_v1': '{"host":"192.168.1.105","port":9090,"autoReconnect":true}',
      'ip_history_v1': ['192.168.1.105', '10.0.0.5'],
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ConnectionBar(),
          ),
        ),
      ),
    );

    // Initial pump
    await tester.pump();
    // Allow async load to complete
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ROS Monitor'), findsOneWidget);
    expect(find.text('connect'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // host & port
  });
}
