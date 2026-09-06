import 'dart:io' show Platform;

import 'ads_service.dart';
import 'ads_service_mobile.dart';

AdsService createAdsService() => Platform.isAndroid ? MobileAdsService() : NoAdsService();
