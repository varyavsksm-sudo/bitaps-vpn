# Apple Developer + provisioning (для VPN)

Entitlements в проекте уже правильные (`Config/*.entitlements`): NetworkExtension
`packet-tunnel-provider`, App Group `group.app.bitaps.vpn`, `allow-vpn`.
Осталась работа в аккаунте Apple — её делает владелец аккаунта.

## 1. Аккаунт — ОРГАНИЗАЦИЯ (важно!)
Apple Guideline **5.4**: VPN-приложения принимаются только от аккаунта-организации,
не от Individual. Нужно:
- Apple Developer Program ($99/год) с типом **Organization**.
- **D-U-N-S номер** на юрлицо/ИП (бесплатно, оформляется ~1-2 недели через Apple/D&B).
- Если уже есть Individual-аккаунт — придётся завести/сконвертировать в Organization.

## 2. Identifiers (developer.apple.com → Certificates, IDs & Profiles)
Создать App IDs с capabilities:
- `app.bitaps.vpn` (app) → **Network Extensions**, **App Groups**, **Personal VPN**.
- `app.bitaps.vpn.PacketTunnel` → **Network Extensions**, **App Groups**.
- `app.bitaps.vpn.BitapsWidget` → **App Groups**.
- App Group: **`group.app.bitaps.vpn`** — создать и привязать ко всем трём.

> Packet Tunnel Provider обычно доступен сразу при включённом Network Extensions.
> Если Apple потребует обоснование — описать: «consumer VPN client routing user
> traffic through our sing-box-based tunnel».

## 3. Подпись (проще — автоматическая)
В Xcode: каждый таргет (BitapsVPN, PacketTunnel, BitapsWidget) →
Signing & Capabilities → **Team = <организация>**, **Automatically manage signing**.
Xcode сам создаст App IDs/профили под capabilities из .entitlements.
- Проверить, что у всех трёх стоит App Group `group.app.bitaps.vpn`.
- У app и PacketTunnel — capability **Network Extensions (Packet Tunnel)**.

## 4. Сборка движка в проект (один раз)
- Перетащить `~/bitaps-libbox/Libbox.xcframework` на таргет **PacketTunnel** → **Embed & Sign**.
- PacketTunnel → Build Phases → Link Binary With Libraries → добавить (статик-движок тянет):
  Security, Network, SystemConfiguration, CoreText, IOKit, CoreServices, AppKit,
  CoreLocation, NetworkExtension, UniformTypeIdentifiers, IOUSBHost, Carbon,
  libresolv.tbd, libbsm.tbd.
- После этого `#if canImport(Libbox)` станет true → реальный туннель.
- Снять флаги: `APIFactory.useSupabase = true`, `TunnelFactory.useSingBox = true`.

## 5. Сборка/выгрузка
- Подключить iPhone, выбрать его как destination, Run → проверить, что VPN
  реально поднимается и заворачивает трафик (сайт «мой IP» показывает IP ноды).
- Archive → Distribute App → App Store Connect → TestFlight → submit на ревью.

## Частые причины отказа (заранее закрыть)
- Individual-аккаунт для VPN → нужен Organization (см. п.1).
- Нет рабочего тест-аккаунта для ревьюера → дать demo с активной подпиской.
- Только Telegram-логин → добавить email/Apple (email уже есть).
- Не задекларирован export compliance → `ITSAppUsesNonExemptEncryption=NO`.
