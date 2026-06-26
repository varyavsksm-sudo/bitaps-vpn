# bitaps VPN — приложение (iOS + macOS)

Нативное приложение на **Swift + SwiftUI**, единый multiplatform-таргет: **iOS 16+** и **macOS 13+**.
Дизайн перенесён с лендинга `bitaps-vpn.surge.sh` (оранжевый акцент `#ff7a1a`, тёмная/светлая темы,
Space Grotesk + JetBrains Mono). Сейчас всё работает на **моках** — кликабельно целиком, без серверов.

## Как открыть и собрать

Нужен **полный Xcode** (не Command Line Tools).

```bash
# 1. сгенерировать .xcodeproj (если его нет или менялся project.yml)
./bootstrap.sh        # скачает xcodegen и сгенерит BitapsVPN.xcodeproj

# 2. открыть
open BitapsVPN.xcodeproj
```

`.xcodeproj` уже сгенерирован и лежит в репо — можно просто `open BitapsVPN.xcodeproj`.
Выбрать схему **BitapsVPN**, целевое устройство (iPhone-симулятор или My Mac) и ⌘R.

> В Signing & Capabilities подставь свой **Team ID** (см. «Что нужно от тебя»).

## Архитектура

```
Sources/
  App/                BitapsVPNApp (@main), RootView, iOS TabView / macOS Sidebar, MenuBarExtra
  Core/
    Models/           Server, ServerGroup, Plan, Subscription, Device, User,
                      VPNStatus, ConnectionStats, AppError, Fmt (форматтеры)
    DesignSystem/     Theme (цвета/шрифты/метрики/AppTheme), Components
                      (BitCard/BitButton/BitToggle/BitBadge/Kicker/LoadBar/BitLogo/BitBackground),
                      PowerButton (круглая кнопка с кольцом)
    Services/
      VPNService      протокол VPNTunnel + TunnelFactory
        MockTunnel    ✅ работает: имитирует коннект, таймер, скорости, IP
        SingBoxTunnel  каркас → NetworkExtension + sing-box (libbox)
      API             протокол BitAPI + APIFactory + TelegramAuth
        MockAPI       ✅ демо-данные (цены/серверы/подписка/устройства)
        SupabaseAPI    каркас → Supabase bjkozsukvifkxriojxrz (тот же, что бот)
      AppStore        единый ObservableObject — состояние всего приложения
  Features/           Onboarding, Auth, Home(коннект), Servers, Subscription, Settings
  Platform/           MenuBarView (только macOS)
PacketTunnel/         PacketTunnelProvider (NEPacketTunnelProvider) — отдельный таргет
Config/               entitlements (app + extension)
```

### Переключение Mock → реальное
Один флаг, без правок UI:
- `TunnelFactory.useSingBox = true` — реальный туннель через NetworkExtension.
- `APIFactory.useSupabase = true` — реальный бэкенд Supabase.

## Что РАБОТАЕТ сейчас (на моках)
- Онбординг, вход (Telegram deep-link / email-каркас / демо), вся навигация.
- Экран коннекта: кнопка-питание, статусы, таймер сессии, живые ↓/↑ скорости, IP, смена локации, **«Авто — быстрейший сервер»**.
- Серверы: 🇷🇺 Россия (живой мок) + 🌍 Зарубежные («скоро»), **пинг-тест + сортировка по пингу + авто-выбор**, загрузка/PRO.
- Подписка: тарифы 199/499/899/1490 ₽, продление (мок), Telegram Stars deep-link.
- Настройки: тема, **акцент-темы (5 цветов)**, **режимы маршрутизации (Весь/Правила/РФ-обход)**, устройства, протокол, DNS-пресеты, kill-switch, авто-подключение, авто-быстрейший, split-tunnel, язык RU/EN, выход.
- **Свой конфиг (BYO):** вставка vless:///vmess:///trojan:///ss:///hysteria2:// и подписок, буфер обмена, QR-сканер (iOS).
- **Статистика:** суммарный трафик, текущая сессия, история подключений.
- **Live Activity + Dynamic Island + виджет** (iOS): статус подключения на экране блокировки и домашнем экране.
- macOS: пункт в menu bar с быстрым коннектом и сменой локации.

### Сравнение с Happ
Берём сильные функции Happ (мульти-протоколы, пинг/авто-быстрейший, импорт конфигов/QR, Live Activity, маршрутизация) и добавляем своё: управляемый аккаунт через Telegram (без возни с конфигами), единый дизайн (тёмная/светлая + акцент-темы), RU-обход в один тап.

## Что ЗАГЛУШЕНО (нужна инфраструктура — см. отдельный список от меня)
- Реальные VLESS+Reality серверы (РУ-нода на Яндексе + зарубежные).
- libbox (gomobile-сборка sing-box) — `Libbox.xcframework` в таргет PacketTunnel.
- Supabase endpoints + anon key, реальный Telegram-логин, провайдер платежей.
- Apple Developer аккаунт, Team ID, App Group, провижининг для NetworkExtension.
