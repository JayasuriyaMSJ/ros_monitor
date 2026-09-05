// lib/services/rosbridge_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import '../models/rosbridge.dart';
import 'socket_channel.dart';

/// Threshold above which JSON parsing is offloaded to a background isolate.
const _kLargeFrameBytes = 4096;

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
  int _connectId = 0;

  // Active topic subscriptions registry for automatic resubscription across reconnects
  final Map<String, SubscribeMsg> _activeSubscriptions = {};

  Stream<ConnectionStatus>       get statusStream  => _statusController.stream;
  Stream<Map<String, dynamic>>   get messageStream => _messageController.stream;
  Stream<List<RosTopicInfo>>     get topicsStream  => _topicsController.stream;
  ConnectionStatus               get status        => _status;

  // ── connect ──────────────────────────────────────────────────────────────
  Future<void> connect(String uri, {bool autoReconnect = true}) async {
    final currentId = ++_connectId;
    _uri = uri;
    _autoReconnect = autoReconnect;
    _reconnectTimer?.cancel();

    await _disconnect();
    if (currentId != _connectId) return;

    _setStatus(ConnectionStatus.connecting);

    try {
      final channel = openWebSocket(
        Uri.parse(uri),
        pingInterval: const Duration(seconds: 2),
      );
      _channel = channel;

      await channel.ready.timeout(const Duration(seconds: 4));
      if (currentId != _connectId) {
        try {
          await channel.sink.close();
        } catch (_) {}
        return;
      }

      _setStatus(ConnectionStatus.connected);

      _sub = channel.stream.listen(
        _onFrame,
        onError: (_) {
          if (currentId == _connectId) _onLost();
        },
        onDone: () {
          if (currentId == _connectId) _onLost();
        },
        cancelOnError: false,
      );

      // Automatically re-subscribe all active topics on the newly established connection
      for (final sub in _activeSubscriptions.values) {
        channel.sink.add(sub.toJson());
      }

      // auto-fetch topic list on connect
      requestTopics();
    } catch (e) {
      if (currentId == _connectId) {
        await _disconnect();
        _setStatus(ConnectionStatus.error);
        _scheduleReconnect();
      }
    }
  }

  // ── disconnect ───────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _connectId++; // invalidate any ongoing connect attempts
    await _disconnect();
    _setStatus(ConnectionStatus.disconnected);
  }

  Future<void> _disconnect() async {
    try {
      await _sub?.cancel();
    } catch (_) {}
    _sub = null;

    final ch = _channel;
    _channel = null;
    if (ch != null) {
      try {
        await ch.sink.close().timeout(
          const Duration(milliseconds: 500),
          onTimeout: () => null,
        );
      } catch (_) {}
    }
  }

  void _onLost() {
    _disconnect();
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
    try {
      _channel?.sink.add(msg.toJson());
    } catch (_) {}
  }

  // ── subscribe / unsubscribe ───────────────────────────────────────────────
  String subscribe(String topic, {String type = '', int throttleRateMs = 0}) {
    final id = 'sub_${_uuid.v4()}';
    final msg = SubscribeMsg(id: id, topic: topic, type: type, throttleRateMs: throttleRateMs);
    _activeSubscriptions[id] = msg;
    send(msg);
    return id;
  }

  void unsubscribe(String id, String topic) {
    _activeSubscriptions.remove(id);
    send(UnsubscribeMsg(id: id, topic: topic));
  }

  // ── topic discovery ───────────────────────────────────────────────────────
  void requestTopics() {
    send(GetTopicsMsg(id: 'topics_${_uuid.v4()}'));
  }

  // ── frame parser ─────────────────────────────────────────────────────────
  void _onFrame(dynamic raw) {
    final str = raw as String;
    if (str.length > _kLargeFrameBytes) {
      // Offload large JSON decoding to a background isolate so the UI thread
      // stays responsive when big messages (PointCloud2, Image, etc.) arrive.
      compute(jsonDecode, str).then((decoded) {
        _dispatchFrame(decoded as Map<String, dynamic>);
      }).catchError((_) {});
    } else {
      try {
        _dispatchFrame(jsonDecode(str) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  void _dispatchFrame(Map<String, dynamic> frame) {
    final op = frame['op'] as String?;
    if (op == 'publish') {
      _messageController.add(frame);
    } else if (op == 'service_response') {
      _handleServiceResponse(frame);
    }
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
    _activeSubscriptions.clear();
    _disconnect();
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
