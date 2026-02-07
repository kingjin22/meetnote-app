import 'package:permission_handler/permission_handler.dart';

class MicrophonePermissionService {
  Future<PermissionStatus> request() => Permission.microphone.request();

  Future<bool> isGranted() async => (await Permission.microphone.status).isGranted;

  Future<bool> openSettings() => openAppSettings();
}
