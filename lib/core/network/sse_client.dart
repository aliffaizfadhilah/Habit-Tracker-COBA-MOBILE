import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

typedef SseEventCallback = void Function(String event, String data);

/// Lightweight SSE client built on Dio.
///
/// Call [connect] to open the stream; it completes when the server closes it
/// (e.g. after the 5-minute server-side timeout). Reconnect by calling
/// [connect] again. Call [close] to permanently cancel the connection.
class SseClient {
  final Dio _dio;
  final String path;
  final SseEventCallback onEvent;

  CancelToken? _cancelToken;
  bool _closed = false;

  SseClient({required Dio dio, required this.path, required this.onEvent})
      : _dio = dio;

  /// Opens the SSE connection and reads events until the server closes it.
  /// Throws [DioException] with type [DioExceptionType.cancel] when [close] is called.
  Future<void> connect() async {
    _closed = false;
    _cancelToken = CancelToken();

    final response = await _dio.get<ResponseBody>(
      path,
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: Duration.zero,
        headers: {
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        },
      ),
      cancelToken: _cancelToken,
    );

    String eventType = '';
    final buf = StringBuffer();

    final body = response.data;
    if (body == null) return;
    await body.stream
        .transform(StreamTransformer<Uint8List, String>.fromHandlers(
          handleData: (data, sink) => sink.add(utf8.decode(data)),
        ))
        .transform(const LineSplitter())
        .forEach((line) {
          if (_closed) return;
          if (line.startsWith('event:')) {
            eventType = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            buf.write(line.substring(5).trim());
          } else if (line.isEmpty && buf.isNotEmpty) {
            onEvent(eventType, buf.toString());
            eventType = '';
            buf.clear();
          }
        });
  }

  /// Cancels the current connection. Safe to call multiple times.
  void close() {
    _closed = true;
    _cancelToken?.cancel('SseClient.close');
  }
}
