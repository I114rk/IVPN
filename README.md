# IVPN

Windows VPN client built with Flutter and Material 3.

## Features

- Remnawave-compatible subscriptions, HWID headers, usage and expiry data
- sing-box and Xray cores with VLESS, VMess, Trojan, Shadowsocks and Hysteria2 profiles
- WireGuard through sing-box and external OpenVPN support
- TUN and system proxy modes
- Optional LAN proxy access with connected-device traffic statistics
- Windows accent color, light and dark themes
- Russian interface in v1.0.0

## Install

Download the current Windows package from [GitHub Releases](https://github.com/I114rk/IVPN/releases/latest), extract it and run `ivpn_installer.exe`.

The installer can add a subscription, create shortcuts and launch IVPN. TUN mode requires administrator rights.

## Build

Requirements:

- Flutter 3.47 or newer
- Visual Studio with Desktop development with C++
- Windows 10 or 11 x64

Build the app and installer package:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_installer.ps1
```

The script writes the distributable ZIP to `dist\`.

Run checks:

```powershell
flutter analyze
flutter test
```

## Data

IVPN stores settings, subscriptions, downloaded cores and logs under `%APPDATA%\com.ivpn\ivpn`.
