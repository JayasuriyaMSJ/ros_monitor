// lib/models/rosbridge.dart
// ROSBridge v2 protocol message models

import 'dart:convert';

class RosBridgeMsg {
  final String op;
  final Map<String, dynamic> data;

  const RosBridgeMsg(this.op, this.data);

  String toJson() => jsonEncode({'op': op, ...data});
}

class SubscribeMsg extends RosBridgeMsg {
  SubscribeMsg({required String id, required String topic, String type = ''})
      : super('subscribe', {
          'id': id,
          'topic': topic,
          if (type.isNotEmpty) 'type': type,
          'compression': 'none',
          'throttle_rate': 0,
          'queue_length': 0,
        });
}

class UnsubscribeMsg extends RosBridgeMsg {
  UnsubscribeMsg({required String id, required String topic})
      : super('unsubscribe', {'id': id, 'topic': topic});
}

class GetTopicsMsg extends RosBridgeMsg {
  GetTopicsMsg({required String id})
      : super('call_service', {
          'id': id,
          'service': '/rosapi/topics',
          'args': {},
        });
}

class GetTopicTypeMsg extends RosBridgeMsg {
  GetTopicTypeMsg({required String id, required String topic})
      : super('call_service', {
          'id': id,
          'service': '/rosapi/topic_type',
          'args': {'topic': topic},
        });
}

// ─── incoming ──────────────────────────────────────────────────────────────

class TopicMessage {
  final String topic;
  final Map<String, dynamic> msg;
  final DateTime receivedAt;

  const TopicMessage({
    required this.topic,
    required this.msg,
    required this.receivedAt,
  });

  factory TopicMessage.fromFrame(Map<String, dynamic> frame) {
    return TopicMessage(
      topic: frame['topic'] as String,
      msg: Map<String, dynamic>.from(frame['msg'] as Map? ?? {}),
      receivedAt: DateTime.now(),
    );
  }
}

class RosTopicInfo {
  final String name;
  final String type;
  final String namespace;

  const RosTopicInfo({
    required this.name,
    required this.type,
    required this.namespace,
  });

  factory RosTopicInfo.fromName(String name, {String type = ''}) {
    final parts = name.split('/');
    final ns = parts.length > 2 ? '/${parts[1]}' : '/';
    return RosTopicInfo(name: name, type: type, namespace: ns);
  }
}
