import '../core/hwid.dart';
import '../platform/device_info.dart';

class HwidService {
  HwidService(this._device);

  final DeviceInfoService _device;
  String? _value;

  Future<String> get value async {
    _value ??= deriveHwid([
      await _device.machineId(),
      await _device.deviceModel(),
      await _device.osName(),
    ]);
    return _value!;
  }

  Future<Map<String, String>> headers({
    String? deviceOs,
    String? deviceOsVersion,
    String? deviceModel,
  }) async {
    return {
      'x-hwid': await value,
      'x-device-os': deviceOs ?? await _device.osName(),
      'x-ver-os': deviceOsVersion ?? await _device.osVersion(),
      'x-device-model': deviceModel ?? await _device.deviceModel(),
    };
  }

  Future<Map<String, String>> info() async => {
    'hwid': await value,
    'os': await _device.osName(),
    'osVersion': await _device.osVersion(),
    'model': await _device.deviceModel(),
  };
}
