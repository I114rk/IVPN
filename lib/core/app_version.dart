import 'package:package_info_plus/package_info_plus.dart';

class AppVersion {
  AppVersion._();

  static final Future<String> value = PackageInfo.fromPlatform().then(
    (info) => info.version,
  );
}
