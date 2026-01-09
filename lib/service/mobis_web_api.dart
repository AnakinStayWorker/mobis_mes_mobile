import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:android_id/android_id.dart';

import 'package:mobis_mes_mobile/const/api_info.dart';
import 'package:mobis_mes_mobile/model/mobis_auth_models.dart';
import 'package:mobis_mes_mobile/model/version_check_info.dart';
import 'package:mobis_mes_mobile/model/inventory_models.dart';
import 'package:mobis_mes_mobile/model/stock_depletion_models.dart';

class ApiCallResult {
  final bool success;
  final String? error;
  const ApiCallResult(this.success, [this.error]);
}

class BasicApiResult {
  final String resultCode;
  final String resultMessage;
  BasicApiResult({required this.resultCode, required this.resultMessage});
}

class MobisWebApi {
  static const _storage = FlutterSecureStorage();

  /// refresh 동시 호출 방지(single-flight)
  /// - refresh 진행 중이면 모두 여기 future에 합류
  /// - 성공/실패 모두 complete 되도록 보장
  static Completer<ApiCallResult>? _refreshing;

  // 로그인 직후 'Y' 안내용
  static String? lastLoginVerChkRet; // 'Y'/'N'/'U'/'B'/'E'
  static String? lastLoginRetMsg;

  // --------------------------- Auth: Login / Refresh / Logout ---------------------------

  /// POST /api/Auth/Login
  static Future<MobisLoginResult> requestLogin({
    required String userId,
    required String password,
  }) async {
    lastLoginVerChkRet = null;
    lastLoginRetMsg = null;

    final androidId = AndroidId();
    final deviceId = await androidId.getId() ?? 'unknown';
    final pkg = await PackageInfo.fromPlatform();

    final uri = Uri.parse('$MOBIS_WEB_API_BASE_URL/Auth/Login');
    final client = http.Client();

    try {
      final resp = await client.post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'password': password,
          'deviceId': deviceId,
          'appName': pkg.appName,
          'appVer': pkg.version,
        }),
      );

      final Map<String, dynamic> map = _tryDecode(resp.body);
      final rc = _str(map, 'ResultCode', 'resultCode');
      final rm = _str(map, 'ResultMessage', 'resultMessage');

      if (resp.statusCode != 200 || rc != '00') {
        final msg = rm.isNotEmpty ? rm : 'Login failed (HTTP ${resp.statusCode}).';
        return MobisLoginResult(error: msg);
      }

      final data = _map(map, 'Data', 'data');
      final token = TokenResponse.fromJson(_map(data, 'tokenResponse', 'TokenResponse'));
      final user = UserProfile.fromJson(_map(data, 'user', 'User'));

      // 버전 체크 결과(문자열 Y/N/U/B/E)
      final mv = _map(data, 'mobileVersion', 'MobileVersion');
      final verChkRet = _str(mv, 'VerChkRet', 'verChkRet').toUpperCase();
      final retMsg = _str(mv, 'RetMsg', 'retMsg');

      // DeviceNickName 읽기
      final deviceNick = _str(mv, 'DeviceNickName', 'deviceNickName');

      // 강제/차단/오류는 로그인 차단
      if (verChkRet == 'U' || verChkRet == 'B' || verChkRet == 'E') {
        final msg = retMsg.isNotEmpty ? retMsg : 'Login blocked by version/device policy.';
        return MobisLoginResult(error: msg);
      }

      // 토큰 저장
      final expEpoch = _decodeJwtExp(token.accessToken);
      await _storage.write(key: 'AccessToken', value: token.accessToken);
      await _storage.write(key: 'RefreshToken', value: token.refreshToken);
      if (expEpoch != null) {
        await _storage.write(key: 'AccessTokenExp', value: expEpoch.toString());
      }

      // 사용자/디바이스 정보 저장
      await _storage.write(key: 'UserId', value: user.userId);
      await _storage.write(key: 'UserName', value: user.userName ?? '');
      await _storage.write(key: 'Email', value: user.email ?? '');
      await _storage.write(key: 'Department', value: user.department ?? '');
      await _storage.write(key: 'DepartmentName', value: user.departmentName ?? '');
      await _storage.write(key: 'UserType', value: user.userType);
      await _storage.write(key: 'DeviceId', value: deviceId);

      if (deviceNick.isNotEmpty) {
        await _storage.write(key: 'DeviceNickName', value: deviceNick);
      } else {
        // 혹시 빈 값이면 지워서 UI가 "-" 처리.
        await _storage.delete(key: 'DeviceNickName');
      }

      // Y: 새버전 있음. 안내만(선택 업데이트)
      if (verChkRet == 'Y' && retMsg.isNotEmpty) {
        lastLoginVerChkRet = 'Y';
        lastLoginRetMsg = retMsg;
      }

      return MobisLoginResult(token: token, user: user);
    } catch (e) {
      return MobisLoginResult(error: 'Network/Parsing error: $e');
    } finally {
      client.close();
    }
  }

  /// POST /api/Auth/Refresh
  static Future<ApiCallResult> requestRefresh() async {
    final refreshToken = await _storage.read(key: 'RefreshToken') ?? '';
    if (refreshToken.isEmpty) return const ApiCallResult(false, 'No refresh token.');

    final deviceId = await _storage.read(key: 'DeviceId') ?? 'unknown';
    final pkg = await PackageInfo.fromPlatform();

    final uri = Uri.parse('$MOBIS_WEB_API_BASE_URL/Auth/Refresh');
    final client = http.Client();

    try {
      final resp = await client.post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'refreshToken': refreshToken,
          'deviceId': deviceId,
          'appName': pkg.appName,
          'appVer': pkg.version,
          // 'accessToken': await _storage.read(key: 'AccessToken') ?? '', // 필요하면 켜
        }),
      );

      final Map<String, dynamic> map = _tryDecode(resp.body);
      final rc = _str(map, 'ResultCode', 'resultCode');
      final rm = _str(map, 'ResultMessage', 'resultMessage');

      // 정책 차단(U/B/E)이면 여기서 에러로 종료
      // 서버는 403/426/500 등을 주고 ApiResponse<MobileVersionDto> 바디를 줌
      if (resp.statusCode != 200 || rc != '00') {
        final msg = rm.isNotEmpty ? rm : 'Refresh failed (HTTP ${resp.statusCode}).';
        return ApiCallResult(false, msg);
      }

      final data = _map(map, 'Data', 'data');

      // tokenResponse 우선, 없으면 fallback(Data가 토큰일 수도 있으므로.)
      final tr = _maybeMap(data, 'tokenResponse', 'TokenResponse');
      final tokenJson = tr ?? data;

      final token = TokenResponse.fromJson(tokenJson);
      final exp = _decodeJwtExp(token.accessToken);

      await _storage.write(key: 'AccessToken', value: token.accessToken);
      await _storage.write(key: 'RefreshToken', value: token.refreshToken);
      if (exp != null) await _storage.write(key: 'AccessTokenExp', value: exp.toString());

      return const ApiCallResult(true);
    } catch (e) {
      return ApiCallResult(false, 'Network/Parsing error: $e');
    } finally {
      client.close();
    }
  }

  /// 단일 Refresh 래퍼
  /// - refresh 진행 중이면 합류
  /// - requestRefresh()가 throw/실패해도 항상 complete
  static Future<ApiCallResult> _refreshSingleFlight() async {
    if (_refreshing != null) {
      return await _refreshing!.future;
    }

    final c = Completer<ApiCallResult>();
    _refreshing = c;

    try {
      final r = await requestRefresh();
      if (!c.isCompleted) c.complete(r);
      return r;
    } catch (e) {
      final r = ApiCallResult(false, 'Refresh error: $e');
      if (!c.isCompleted) c.complete(r);
      return r;
    } finally {
      _refreshing = null;
    }
  }

  /// POST /api/Auth/Logout
  static Future<ApiCallResult> requestLogout() async {
    final headers = await authHeader();
    final refreshToken = await _storage.read(key: 'RefreshToken') ?? '';
    final deviceId = await _storage.read(key: 'DeviceId') ?? 'unknown';

    final uri = Uri.parse('$MOBIS_WEB_API_BASE_URL/Auth/Logout');
    final client = http.Client();

    try {
      final resp = await client.post(
        uri,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refreshToken': refreshToken, 'deviceId': deviceId}),
      );

      final Map<String, dynamic> map = _tryDecode(resp.body);
      final rc = _str(map, 'ResultCode', 'resultCode');
      final rm = _str(map, 'ResultMessage', 'resultMessage');

      if (resp.statusCode == 200 && rc == '00') {
        await _storage.delete(key: 'AccessToken');
        await _storage.delete(key: 'RefreshToken');
        await _storage.delete(key: 'AccessTokenExp');
        return const ApiCallResult(true);
      } else {
        return ApiCallResult(false, rm.isNotEmpty ? rm : 'Logout failed (HTTP ${resp.statusCode}).');
      }
    } catch (e) {
      return ApiCallResult(false, 'Network/Parsing error: $e');
    } finally {
      client.close();
    }
  }

  // --------------------------- Version Check / Ping ---------------------------

  /// POST /api/Auth/version-check  → VersionCheckInfoResponse
  static Future<VersionCheckInfoResponse> versionCheck() async {
    final pkg = await PackageInfo.fromPlatform();
    final deviceId = await _storage.read(key: 'DeviceId') ?? 'unknown';

    final uri = Uri.parse('$MOBIS_WEB_API_BASE_URL/Auth/version-check');
    final client = http.Client();

    try {
      final resp = await client.post(
        uri,
        headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'appName': pkg.appName, 'deviceId': deviceId, 'appVer': pkg.version}),
      );

      final Map<String, dynamic> map = _tryDecode(resp.body);
      final rc = _str(map, 'ResultCode', 'resultCode', '${resp.statusCode}');
      final rm = _str(map, 'ResultMessage', 'resultMessage');

      VersionInfo? vi;
      final data = _maybeMap(map, 'Data', 'data');
      if (data != null) {
        String s(String a, [String? b]) => _str(data, a, b);
        int n(String a, [String? b]) => _toInt(_pick(data, a, b));

        vi = VersionInfo(
          appName: s('AppName', 'appName'),
          majorVer: n('MajorVer', 'majorVer'),
          minorVer: n('MinorVer', 'minorVer'),
          patchVer: n('PatchVer', 'patchVer'),
          lastAppVer: s('LastAppVer', 'lastAppVer'),
          installUrl: s('InstallUrl', 'installUrl'),
          fileName: s('FileName', 'fileName'),
          verChkRet: s('VerChkRet', 'verChkRet'),
          retMsg: s('RetMsg', 'retMsg'),
        );
      }

      return VersionCheckInfoResponse(
        resultCode: rc,
        resultMessage: rm,
        versionInfo: vi,
      );
    } catch (e) {
      return VersionCheckInfoResponse(
        resultCode: 'ERR',
        resultMessage: 'Version check failed: $e',
      );
    } finally {
      client.close();
    }
  }

  /// GET /api/Auth/ping?echo=...
  static Future<ApiCallResult> ping({String? echo}) async {
    final q = (echo == null || echo.isEmpty) ? '' : '?echo=${Uri.encodeQueryComponent(echo)}';
    final uri = Uri.parse('$MOBIS_WEB_API_BASE_URL/Auth/ping$q');
    final client = http.Client();
    try {
      final resp = await client.get(uri, headers: const {'Accept': 'application/json'});

      final Map<String, dynamic> map = _tryDecode(resp.body);
      final rc = _str(map, 'ResultCode', 'resultCode');
      final rm = _str(map, 'ResultMessage', 'resultMessage');

      if (resp.statusCode == 200 && rc == '00') {
        return const ApiCallResult(true);
      }
      return ApiCallResult(false, rm.isNotEmpty ? rm : 'Ping failed (HTTP ${resp.statusCode}).');
    } catch (e) {
      return ApiCallResult(false, 'Ping error: $e');
    } finally {
      client.close();
    }
  }

  // --------------------------- Inventory APIs ---------------------------

  /// GET /api/Inventory  (전체)
  static Future<InventoryAllResult> getInventoryAll() async {
    final deviceId = await _storage.read(key: 'DeviceId') ?? 'unknown';
    final resp = await authedGet('Inventory', extraHeaders: {'X-Device-Id': deviceId});

    final map = _tryDecode(resp.body);
    final rc = _str(map, 'ResultCode', 'resultCode', '${resp.statusCode}');
    final rm = _str(map, 'ResultMessage', 'resultMessage');

    List<InventoryItem> items = [];

    final dynamic data = _pick(map, 'Data', 'data');

    if (data is List) {
      items = data
          .whereType<Map>()
          .map((e) => InventoryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else if (data is Map) {
      final dynamic listLike = data['items'] ?? data['Items'] ?? data['rows'] ?? data['Rows'];
      if (listLike is List) {
        items = listLike
            .whereType<Map>()
            .map((e) => InventoryItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }

    return InventoryAllResult(resultCode: rc, resultMessage: rm, items: items);
  }

  /// GET /api/Inventory/{id} (단건)
  static Future<InventoryQtyResult> getInventoryQty(String id) async {
    final deviceId = await _storage.read(key: 'DeviceId') ?? 'unknown';
    final resp = await authedGet('Inventory/$id', extraHeaders: {'X-Device-Id': deviceId});

    final map = _tryDecode(resp.body);
    final rc = _str(map, 'ResultCode', 'resultCode', '${resp.statusCode}');
    final rm = _str(map, 'ResultMessage', 'resultMessage');

    InventoryItem? item;
    final data = _maybeMap(map, 'Data', 'data');
    if (data != null) {
      item = InventoryItem.fromJson(data);
    }

    return InventoryQtyResult(resultCode: rc, resultMessage: rm, item: item);
  }

  static Future<StockDepletionResult> getStockDepletionInfo() async {
    final deviceId = await _storage.read(key: 'DeviceId') ?? 'unknown';
    final resp = await authedGet(
      'Inventory/stock-depletion',
      query: {'deviceId': deviceId},
      extraHeaders: {'X-Device-Id': deviceId},
    );

    final map = _tryDecode(resp.body);
    final rc = _str(map, 'ResultCode', 'resultCode', '${resp.statusCode}');
    final rm = _str(map, 'ResultMessage', 'resultMessage');

    final data = _pick(map, 'Data', 'data');
    final items = <StockDepletionItem>[];
    if (data is List) {
      for (final e in data) {
        if (e is Map) items.add(StockDepletionItem.fromAny(e));
      }
    }

    return StockDepletionResult(resultCode: rc, resultMessage: rm, items: items);
  }

  static Future<CurrentStockInfoResult> getPartStock(String partNo, String pcCode) async {
    final deviceId = await _storage.read(key: 'DeviceId') ?? 'unknown';

    final resp = await authedGet(
      'Inventory/part-stock/$partNo/$pcCode',
      extraHeaders: {'X-Device-Id': deviceId},
    );

    final map = _tryDecode(resp.body);

    final rc = _str(map, 'ResultCode', 'resultCode', '${resp.statusCode}');
    final rm = _str(map, 'ResultMessage', 'resultMessage', '');

    final data = _pick(map, 'Data', 'data');
    CurrentStockInfo? info;
    if (data is Map) {
      info = CurrentStockInfo.fromJson(Map<String, dynamic>.from(data));
    }

    return CurrentStockInfoResult(resultCode: rc, resultMessage: rm, data: info);
  }

  static Future<UpdateStockResult> updateStock({
    required String partNo,
    required String pcCode,
    required int currentQty,
    required int editQty,
    required int scannedQty,
    required int totalQty,
    String? requestBarcodeJson,
  }) async {
    final deviceId = await _storage.read(key: 'DeviceId') ?? 'unknown';
    final userId = await _storage.read(key: 'UserId') ?? '';

    final resp = await authedPost(
      'Inventory/update-stock',
      extraHeaders: {'X-Device-Id': deviceId},
      body: {
        'partNo': partNo,
        'pcCode': pcCode,
        'userId': userId,
        'currentQty': currentQty,
        'editQty': editQty,
        'scannedQty': scannedQty,
        'totalQty': totalQty,
        'deviceId': deviceId,
        'requestBarcodeJson': requestBarcodeJson ?? '',
      },
    );

    final map = _tryDecode(resp.body);
    final rc = _str(map, 'ResultCode', 'resultCode', '${resp.statusCode}');
    final rm = _str(map, 'ResultMessage', 'resultMessage');

    return UpdateStockResult(resultCode: rc, resultMessage: rm);
  }

  // --------------------------- Authed helpers ---------------------------

  static Future<bool> isAccessTokenExpired({int safetyBufferSec = 60}) async {
    final expStr = await _storage.read(key: 'AccessTokenExp');
    if (expStr == null) return true;

    final exp = int.tryParse(expStr);
    if (exp == null) return true;

    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    return now >= (exp - safetyBufferSec);
  }

  static Future<Map<String, String>> authHeader() async {
    final token = await _storage.read(key: 'AccessToken') ?? '';
    return {'Authorization': 'Bearer $token'};
  }

  /// 만료(또는 만료 임박)면 refresh(단일) 시도 후 header 반환
  static Future<Map<String, String>> ensureAuthHeader({int safetyBufferSec = 60}) async {
    final expired = await isAccessTokenExpired(safetyBufferSec: safetyBufferSec);

    if (expired) {
      final r = await _refreshSingleFlight();
      if (!r.success) {
        // refresh 실패 시, 그냥 header만 반환. 실제 판단은 API 응답(401/403/426)에서.
        return await authHeader();
      }
    }
    return await authHeader();
  }

  // 공용 래퍼
  static Uri _buildUri(String relativePath, {Map<String, dynamic>? query}) {
    final base = MOBIS_WEB_API_BASE_URL.endsWith('/')
        ? MOBIS_WEB_API_BASE_URL.substring(0, MOBIS_WEB_API_BASE_URL.length - 1)
        : MOBIS_WEB_API_BASE_URL;
    final path = relativePath.startsWith('/') ? relativePath : '/$relativePath';
    final url = '$base$path';
    if (query == null || query.isEmpty) return Uri.parse(url);
    return Uri.parse(url).replace(
      queryParameters: query.map((k, v) => MapEntry(k, v?.toString() ?? '')),
    );
  }

  static Future<http.Response> authedGet(
      String relativePath, {
        Map<String, dynamic>? query,
        Map<String, String>? extraHeaders,
      }) async {
    var headers = await ensureAuthHeader();
    var uri = _buildUri(relativePath, query: query);

    var resp = await http.get(uri, headers: {
      'Accept': 'application/json',
      ...headers,
      if (extraHeaders != null) ...extraHeaders,
    });

    // 서버가 401 주면 여기서 최종 refresh + retry
    if (resp.statusCode == 401) {
      final r = await _refreshSingleFlight();
      if (r.success) {
        final h2 = await authHeader();
        uri = _buildUri(relativePath, query: query);
        resp = await http.get(uri, headers: {
          'Accept': 'application/json',
          ...h2,
          if (extraHeaders != null) ...extraHeaders,
        });
      }
    }

    return resp;
  }

  static Future<http.Response> authedPost(
      String relativePath, {
        Object? body,
        Map<String, dynamic>? query,
        Map<String, String>? extraHeaders,
      }) async {
    var headers = await ensureAuthHeader();
    var uri = _buildUri(relativePath, query: query);

    var resp = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        ...headers,
        if (extraHeaders != null) ...extraHeaders,
      },
      body: body == null ? null : jsonEncode(body),
    );

    if (resp.statusCode == 401) {
      final r = await _refreshSingleFlight();
      if (r.success) {
        final h2 = await authHeader();
        uri = _buildUri(relativePath, query: query);
        resp = await http.post(
          uri,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            ...h2,
            if (extraHeaders != null) ...extraHeaders,
          },
          body: body == null ? null : jsonEncode(body),
        );
      }
    }

    return resp;
  }

  /// 세션이 살아 있는지 확인
  static Future<BasicApiResult> checkSessionAlive() async {
    final resp = await authedGet('auth/devices');
    final map = _tryDecode(resp.body);
    final rc = _str(map, 'ResultCode', 'resultCode', '${resp.statusCode}');
    final rm = _str(map, 'ResultMessage', 'resultMessage', '');
    return BasicApiResult(resultCode: rc, resultMessage: rm);
  }

  // --------------------------- helpers ---------------------------

  static Map<String, dynamic> _tryDecode(String body) {
    try {
      final parsed = jsonDecode(body);
      return (parsed is Map<String, dynamic>) ? parsed : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static dynamic _pick(Map<String, dynamic> m, String a, [String? b]) {
    if (m.containsKey(a)) return m[a];
    if (b != null && m.containsKey(b)) return m[b];
    return null;
  }

  static Map<String, dynamic> _map(Map<String, dynamic> m, String a, [String? b]) {
    final v = _pick(m, a, b);
    return (v is Map<String, dynamic>) ? v : <String, dynamic>{};
  }

  static Map<String, dynamic>? _maybeMap(Map<String, dynamic> m, String a, [String? b]) {
    final v = _pick(m, a, b);
    return (v is Map<String, dynamic>) ? v : null;
  }

  static String _str(Map<String, dynamic> m, String a, [String? b, String def = '']) {
    final v = _pick(m, a, b);
    if (v == null) return def;
    return v.toString();
  }

  static int _toInt(dynamic v, [int def = 0]) {
    if (v == null) return def;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? def;
  }

  static int? _decodeJwtExp(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(base64Url.decode(_padBase64(parts[1])));
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final exp = map['exp'];
      if (exp is int) return exp;
      if (exp is num) return exp.toInt();
      return null;
    } catch (_) {
      return null;
    }
  }

  static String _padBase64(String s) {
    switch (s.length % 4) {
      case 0:
        return s;
      case 2:
        return '$s==';
      case 3:
        return '$s=';
      default:
        return s;
    }
  }
}
