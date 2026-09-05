// lib/services/socket_channel_stub.dart

import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel createWebSocketChannel(Uri uri, {Duration? pingInterval}) {
  return WebSocketChannel.connect(uri);
}
