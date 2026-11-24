import 'dart:async';

import 'package:http/http.dart' as http;

import '../../../core/auth/auth_service.dart';

/// Drive wouldn't take the token, or there is none without the user (they
/// signed out, or Google ended a test user's access after 7 days).
class DriveNotAuthorized implements Exception {
  const DriveNotAuthorized();

  @override
  String toString() => 'DriveNotAuthorized';
}

/// An HTTP client for Drive that adds the user's access token
/// ([AuthService.driveAccessToken]) to every request. After a 401 it drops
/// the token and retries once with a fresh one (m3-design §6.7).
class DriveAuthClient extends http.BaseClient {
  DriveAuthClient(
    this._auth, {
    http.Client? inner,
    this.timeout = const Duration(seconds: 60),
  }) : _inner = inner ?? http.Client();

  final AuthService _auth;
  final http.Client _inner;

  /// Until the response's headers arrive.
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // The body is kept so the request can be sent again after a 401. Record
    // files are small and resumable uploads send one chunk per request.
    final body = await request.finalize().toBytes();
    final first = await _sendWithToken(request, body);
    if (first.response.statusCode != 401) return first.response;
    await first.response.stream.drain<void>();
    await _auth.clearDriveToken(first.token);
    final second = await _sendWithToken(request, body);
    if (second.response.statusCode == 401) {
      await second.response.stream.drain<void>();
      throw const DriveNotAuthorized();
    }
    return second.response;
  }

  Future<({String token, http.StreamedResponse response})> _sendWithToken(
    http.BaseRequest original,
    List<int> body,
  ) async {
    final token = await _auth.driveAccessToken();
    if (token == null) throw const DriveNotAuthorized();
    final request = http.Request(original.method, original.url)
      ..followRedirects = original.followRedirects
      ..maxRedirects = original.maxRedirects
      ..persistentConnection = original.persistentConnection
      ..headers.addAll(original.headers)
      ..headers['authorization'] = 'Bearer $token'
      ..bodyBytes = body;
    final response = await _inner.send(request).timeout(timeout);
    return (token: token, response: response);
  }

  @override
  void close() => _inner.close();
}
