// lib/services/socket_channel.dart

import 'package:web_socket_channel/web_socket_channel.dart';
import 'socket_channel_stub.dart'
    if (dart.library.io) 'socket_channel_io.dart'
    if (dart.library.html) 'socket_channel_html.dart';

WebSocketChannel openWebSocket(Uri uri, {Duration? pingInterval}) =>
    createWebSocketChannel(uri, pingInterval: pingInterval);
