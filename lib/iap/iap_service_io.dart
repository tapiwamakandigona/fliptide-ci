import 'dart:io' show Platform;

import 'iap_service.dart';
import 'iap_service_mobile.dart';

IapService createIapService() => Platform.isAndroid ? PlayIapService() : NoIapService();
