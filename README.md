# IVPN

VPN client for Windows and Android built with Flutter and Material 3. The interface and Windows installer are available in Russian, English and German.

## Features

- Remnawave-compatible subscriptions, HWID headers, usage and expiry data
- sing-box and Xray cores with VLESS, VMess, Trojan, Shadowsocks and Hysteria2 profiles
- WireGuard through sing-box and external OpenVPN support
- TUN and system proxy modes
- Optional LAN proxy access with connected-device traffic statistics
- Windows accent color, light and dark themes
- Interface and Windows installer in Russian, English and German
- Android VPN mode powered by the sing-box plugin

## Install

Download the current Windows package from [GitHub Releases](https://github.com/I114rk/IVPN/releases/latest), extract it and run `ivpn_installer.exe`.

The installer can add a subscription, create shortcuts and launch IVPN. TUN mode requires administrator rights.

## Build

Requirements:

- Flutter 3.50.1 or newer
- Visual Studio with Desktop development with C++
- Windows 10 or 11 x64

Build the app and installer package:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_installer.ps1
```

The script writes a versioned distributable ZIP to `dist\`.

Build an Android APK:

```powershell
flutter build apk --release
```

The APK is written to `build\app\outputs\flutter-apk\app-release.apk`.

Run checks:

```powershell
flutter analyze
flutter test
```

## Data

IVPN stores settings, subscriptions, downloaded cores and logs under `%APPDATA%\com.ivpn\ivpn`.
