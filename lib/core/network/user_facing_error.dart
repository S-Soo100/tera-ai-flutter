import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;

import 'terra_rest_client.dart';

/// 오류를 유저에게 보일 짧은 한글로 바꾼다. 원시 예외 문자열
/// (`TerraRestException(400): …`)을 화면에 그대로 내지 않는다(2026-09-25 점검).
String userFacingError(Object e) {
  if (e is TerraRestException) {
    final code = e.statusCode;
    if (code == 401 || code == 403) return 'error_auth'.tr();
    if (code == 404) return 'error_not_found'.tr();
    if (code >= 500) return 'error_server'.tr();
    if (code >= 400) return 'error_request_rejected'.tr();
  }
  if (e is TimeoutException || e is SocketException || e is http.ClientException) {
    return 'error_network'.tr();
  }
  return 'error_unknown'.tr();
}
