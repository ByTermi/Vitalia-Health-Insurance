import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class NtfyMessage {
  final String id;
  final String topic;
  final String message;
  final String title;

  const NtfyMessage({
    required this.id,
    required this.topic,
    required this.message,
    required this.title,
  });

  factory NtfyMessage.fromJson(Map<String, dynamic> j) => NtfyMessage(
        id:      j['id']      as String? ?? '',
        topic:   j['topic']   as String? ?? '',
        message: j['message'] as String? ?? '',
        title:   j['title']   as String? ?? '',
      );
}

class NtfyService {
  // Must match worker.py: topic = f"vitalia-falls-{user_id_hash[:8]}"
  static const _userId = 'demo_user_001';
  static String get topic => 'vitalia-falls-${_userId.substring(0, 8)}';

  static const defaultPort = 8080;

  StreamSubscription? _sub;
  http.Client? _client;
  final _controller = StreamController<NtfyMessage>.broadcast();

  Stream<NtfyMessage> get messages => _controller.stream;

  /// Subscribe to the fall alert topic via SSE.
  /// Calling again with a new IP cancels the previous connection first.
  void subscribe(String ip, {int port = defaultPort}) {
    _sub?.cancel();
    _client?.close();

    _client = http.Client();
    // ?since=all delivers messages cached in the last cache-duration window
    // so a client that reconnects after being offline still gets missed alerts
    final url = Uri.parse('http://$ip:$port/$topic/sse?since=all');
    final request = http.Request('GET', url)
      ..headers['Accept'] = 'text/event-stream';

    _sub = Stream.fromFuture(_client!.send(request))
        .asyncExpand((response) {
          if (response.statusCode != 200) return const Stream.empty();
          return response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter());
        })
        .listen(
          _onLine,
          onError: (_) {},   // swallow errors — service is optional
          cancelOnError: false,
        );
  }

  void _onLine(String line) {
    if (!line.startsWith('data:')) return;
    try {
      final json = jsonDecode(line.substring(5).trim()) as Map<String, dynamic>;
      if (json['event'] == 'open') return;  // ntfy sends this on connect
      _controller.add(NtfyMessage.fromJson(json));
    } catch (_) {}
  }

  void dispose() {
    _sub?.cancel();
    _client?.close();
    _controller.close();
  }
}
