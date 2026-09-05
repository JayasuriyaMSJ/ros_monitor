// lib/services/socket_channel_html.dart

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/html.dart';

WebSocketChannel createWebSocketChannel(Uri uri, {Duration? pingInterval}) {
  return HtmlWebSocketChannel.connect(uri);
}
