import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<Map<String, dynamic>> httpGetTest({required String path}) async {
  /*String baseUrl = 'https://reqres.in$path';*/
  String baseUrl = path;
  try {
    http.Response response = await http.get(Uri.parse(baseUrl), headers: {
      "accept": "application/json",
      "Content-Type": "application/json",
    });
    try {
      Map<String, dynamic> resBody =
      jsonDecode(utf8.decode(response.bodyBytes));
      resBody['statusCode'] = response.statusCode;
      return resBody;
    } catch (e) {
      // response body is not json type.
      return {'statusCode': 490};
    }
  } catch (e) {
    // response body is not json type.
    debugPrint("httpGet error: $e");
    return {'statusCode': 503};
  }
}

Future<Map<String, dynamic>> httpGet({required String path}) async {
  /*String baseUrl = 'http://10.204.12.108/BackendOpenApiSvc/MobileAppService.svc/v1$path';*/
  String baseUrl = path;
  try {
    http.Response response = await http.get(Uri.parse(baseUrl), headers: {
      "accept": "application/json",
      "Content-Type": "application/json",
    });
    try {
      Map<String, dynamic> resBody =
      jsonDecode(utf8.decode(response.bodyBytes));
      resBody['statusCode'] = response.statusCode;
      return resBody;
    } catch (e) {
      // response body is not json type.
      return {'statusCode': 490};
    }
  } catch (e) {
    // Server is not respond
    debugPrint("httpGet error: $e");
    return {'statusCode': 503};
  }
}

Future<Map<String, dynamic>> httpPost({required String path, Map? data}) async {
  /*String baseUrl = 'http://10.204.12.108/BackendOpenApiSvc/MobileAppService.svc/v1$path';*/
  String baseUrl = path;
  var body = jsonEncode(data);
  try {
    http.Response response =
    await http.post(Uri.parse(baseUrl), body: body, headers: {
      "accept": "application/json",
      "Content-Type": "application/json",
    });
    try {
      Map<String, dynamic> resBody =
      jsonDecode(utf8.decode(response.bodyBytes));
      resBody['statusCode'] = response.statusCode;
      return resBody;
    } catch (e) {
      // response body is not json type.
      return {'statusCode': 490};
    }
  } catch (e) {
    debugPrint("httpPost error: $e");
    return {'statusCode': 503};
  }
}

/*Future<int> httpPost({required String path, Map? data}) async {
  String baseUrl = 'http://10.204.12.108/BackendOpenApiSvc/MobileAppService.svc/v1$path';
  var body = jsonEncode(data);
  try {
    http.Response response =
    await http.post(Uri.parse(baseUrl), body: body, headers: {
      "accept": "application/json",
      "Content-Type": "application/json",
    });
    return response.statusCode;
  } catch (e) {
    debugPrint("httpPost error: $e");
    return 503;
  }
}*/

Future<int> httpPut({required String path, Map? data}) async {
  String baseUrl = path;
  var body = jsonEncode(data);
  try {
    http.Response response =
    await http.post(Uri.parse(baseUrl), body: body, headers: {
      "accept": "application/json",
      "Content-Type": "application/json",
    });
    return response.statusCode;
  } catch (e) {
    debugPrint("httpPut error: $e");
    return 503;
  }
}

Future<int> httpDelete({required String path, Map? data}) async {
  String baseUrl = path;
  var body = jsonEncode(data);
  try {
    http.Response response =
    await http.delete(Uri.parse(baseUrl), body: body, headers: {
      "accept": "application/json",
      "Content-Type": "application/json",
    });
    return response.statusCode;
  } catch (e) {
    debugPrint("httpDelete error: $e");

    return 503;
  }
}