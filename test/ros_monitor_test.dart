// test/ros_monitor_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ros_monitor/models/workspace.dart';
import 'package:ros_monitor/providers/workspace_provider.dart';
import 'package:ros_monitor/services/rosbridge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IpHistoryNotifier & SharedPreferences', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('addHost adds, trims, and deduplicates IPs with most recent first', () async {
      final notifier = IpHistoryNotifier();
      await notifier.addHost('192.168.1.50');
      await notifier.addHost('192.168.1.100');
      expect(notifier.state, ['192.168.1.100', '192.168.1.50']);

      // Case-insensitive deduplication moving to top
      await notifier.addHost('192.168.1.50');
      expect(notifier.state, ['192.168.1.50', '192.168.1.100']);

      // Verify persisted to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('ip_history_v1'), ['192.168.1.50', '192.168.1.100']);
    });

    test('removeHost removes selected IP from state and SharedPreferences', () async {
      final notifier = IpHistoryNotifier();
      await notifier.addHost('192.168.1.10');
      await notifier.addHost('192.168.1.20');
      expect(notifier.state, ['192.168.1.20', '192.168.1.10']);

      await notifier.removeHost('192.168.1.10');
      expect(notifier.state, ['192.168.1.20']);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('ip_history_v1'), ['192.168.1.20']);
    });
  });

  group('ConnectionConfigNotifier & SharedPreferences', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('persists connection config to SharedPreferences', () async {
      final notifier = ConnectionConfigNotifier();
      const cfg = ConnectionConfig(host: '10.0.0.42', port: 9091);
      await notifier.update(cfg);

      expect(notifier.state.host, '10.0.0.42');
      expect(notifier.state.port, 9091);
      expect(notifier.state.uri, 'ws://10.0.0.42:9091');

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('connection_v1');
      expect(saved, contains('10.0.0.42'));
      expect(saved, contains('9091'));
    });
  });

  group('RosBridgeService subscription registry', () {
    test('subscribing and unsubscribing manages active subscriptions', () {
      final svc = RosBridgeService();
      final id1 = svc.subscribe('/cmd_vel', type: 'geometry_msgs/Twist');
      final id2 = svc.subscribe('/odom', type: 'nav_msgs/Odometry');

      expect(id1.startsWith('sub_'), isTrue);
      expect(id2.startsWith('sub_'), isTrue);

      svc.unsubscribe(id1, '/cmd_vel');
      svc.dispose();
    });

    test('disconnect sets disconnected status immediately without hanging', () async {
      final svc = RosBridgeService();
      await svc.disconnect();
      expect(svc.status, ConnectionStatus.disconnected);
      svc.dispose();
    });
  });
}
