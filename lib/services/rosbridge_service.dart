// lib/services/rosbridge_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import '../models/rosbridge.dart';

const _uuid = Uuid();

enum ConnectionStatus { disconnected, connecting, connected, error }

class RosBridgeService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _topicsController  = StreamController<List<RosTopicInfo>>.broadcast();

  ConnectionStatus _status = ConnectionStatus.disconnected;
  String _uri = '';
  bool _autoReconnect = true;
  Timer? _reconnectTimer;

  Stream<ConnectionStatus>       get statusStream  => _statusController.stream;
  Stream<Map<String, dynamic>>   get messageStream => _messageController.stream;
  Stream<List<RosTopicInfo>>     get topicsStream  => _topicsController.stream;
  ConnectionStatus               get status        => _status;

  // ── connect ──────────────────────────────────────────────────────────────
  Future<void> connect(String uri, {bool autoReconnect = true}) async {
    _uri = uri;
    _autoReconnect = autoReconnect;
    _reconnectTimer?.cancel();
    await _disconnect();
    _setStatus(ConnectionStatus.connecting);

    try {
      _channel = WebSocketChannel.connect(Uri.parse(uri));
      await _channel!.ready.timeout(const Duration(seconds: 5));
      _setStatus(ConnectionStatus.connected);

      _sub = _channel!.stream.listen(
        _onFrame,
        onError: (_) => _onLost(),
        onDone: _onLost,
        cancelOnError: false,
      );

      // auto-fetch topic list on connect
      requestTopics();
    } catch (e) {
      _setStatus(ConnectionStatus.error);
      _scheduleReconnect();
    }
  }

  // ── disconnect ───────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    await _disconnect();
    _setStatus(ConnectionStatus.disconnected);
  }

  Future<void> _disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void _onLost() {
    _setStatus(ConnectionStatus.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_autoReconnect || _uri.isEmpty) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_status != ConnectionStatus.connected) {
        connect(_uri, autoReconnect: _autoReconnect);
      }
    });
  }

  // ── send ─────────────────────────────────────────────────────────────────
  void send(RosBridgeMsg msg) {
    if (_status != ConnectionStatus.connected) return;
    _channel?.sink.add(msg.toJson());
  }

  // ── subscribe / unsubscribe ───────────────────────────────────────────────
  String subscribe(String topic, {String type = ''}) {
    final id = 'sub_${_uuid.v4()}';
    send(SubscribeMsg(id: id, topic: topic, type: type));
    return id;
  }

  void unsubscribe(String id, String topic) {
    send(UnsubscribeMsg(id: id, topic: topic));
  }

  // ── topic discovery ───────────────────────────────────────────────────────
  void requestTopics() {
    send(GetTopicsMsg(id: 'topics_${_uuid.v4()}'));
  }

  // ── frame parser ─────────────────────────────────────────────────────────
  void _onFrame(dynamic raw) {
    try {
      final frame = jsonDecode(raw as String) as Map<String, dynamic>;
      final op = frame['op'] as String?;

      if (op == 'publish') {
        _messageController.add(frame);
      } else if (op == 'service_response') {
        _handleServiceResponse(frame);
      }
    } catch (_) {}
  }

  void _handleServiceResponse(Map<String, dynamic> frame) {
    final id = (frame['id'] as String? ?? '');
    final values = frame['values'] as Map<String, dynamic>?;

    if (id.startsWith('topics_') && values != null) {
      final names  = List<String>.from(values['topics'] as List? ?? []);
      final types  = List<String>.from(values['types']  as List? ?? []);
      final infos  = <RosTopicInfo>[];
      for (var i = 0; i < names.length; i++) {
        infos.add(RosTopicInfo.fromName(
          names[i],
          type: i < types.length ? types[i] : '',
        ));
      }
      _topicsController.add(infos);
    }
  }

  void _setStatus(ConnectionStatus s) {
    _status = s;
    _statusController.add(s);
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _statusController.close();
    _messageController.close();
    _topicsController.close();
  }
}

// ── Riverpod providers ────────────────────────────────────────────────────────

final rosBridgeServiceProvider = Provider<RosBridgeService>((ref) {
  final svc = RosBridgeService();
  ref.onDispose(svc.dispose);
  return svc;
});

final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  return ref.watch(rosBridgeServiceProvider).statusStream;
});

final rosTopicsProvider = StreamProvider<List<RosTopicInfo>>((ref) {
  return ref.watch(rosBridgeServiceProvider).topicsStream;
});
