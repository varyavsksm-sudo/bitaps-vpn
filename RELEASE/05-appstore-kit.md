# App Store Connect — комплект для подачи (паста-готов)

Всё, что вписывается в форму нового приложения. Заполняешь по разделам.

## Основное
- **Имя (Name, ≤30):** bitaps VPN
- **Подзаголовок (Subtitle, ≤30):** Быстрый VPN без логов
- **Категория:** Primary = Utilities · Secondary = Productivity
- **Bundle ID:** `app.bitaps.vpn`
- **Возрастной рейтинг:** 17+ (Unrestricted Web Access)
- **Цена:** Free (подписка вне App Store / в боте — см. примечание ревьюеру)
- **Поддержка URL:** https://t.me/bitapssupport
- **Маркетинг URL:** https://bitaps-vpn.surge.sh
- **Privacy Policy URL:** https://bitaps-vpn.surge.sh/privacy.html

## Описание (RU)
```
bitaps — быстрый и приватный VPN на протоколе VLESS + Reality. Без логов,
без слежки: трафик маскируется под обычный сайт, поэтому работает там, где
обычные VPN блокируются.

• Подключение в один тап
• Умный режим: российские сайты — напрямую (быстрее), остальное — через VPN
• Стриминг, игры, работа — режимы под задачу
• Один аккаунт — все устройства
• Проверка утечек (IP, DNS/WebRTC) прямо в приложении
• Тёмная и светлая темы, русский и английский

Без рекламы. Без продажи данных. Только защита соединения.
```

## Описание (EN)
```
bitaps is a fast, private VPN built on VLESS + Reality. No logs, no tracking:
your traffic looks like an ordinary website, so it works where regular VPNs
are blocked.

• One-tap connect
• Smart mode: Russian sites go direct (faster), everything else via VPN
• Modes for streaming, gaming and work
• One account, all your devices
• Built-in leak check (IP, DNS/WebRTC)
• Dark & light themes, Russian and English

No ads. No data selling. Just a protected connection.
```

## Промо-текст (Promotional Text, ≤170)
```
RU: Защита в один тап. VLESS+Reality обходит блокировки, российские сайты — напрямую. Без логов, без рекламы.
EN: One-tap protection. VLESS+Reality bypasses blocks; Russian sites stay direct. No logs, no ads.
```

## Ключевые слова (Keywords, ≤100 симв, через запятую)
```
vpn,reality,vless,прокси,обход блокировок,приватность,без логов,proxy,unblock,privacy,fast vpn
```

## App Privacy («ярлык») — что отвечать
Политика — **no-logs**. Указать как собираемое (Account):
- **Identifiers → User ID** (Telegram ID) — Purpose: App Functionality. Linked to user: Yes. Tracking: **No**.
- **Contact Info → Email Address** (только если вошёл по email) — App Functionality. Linked: Yes. Tracking: No.
- НЕ собираем: историю просмотров, геолокацию, рекламные идентификаторы.
- **Data used to track you:** None. **Third-party SDK:** none.

## Export Compliance (шифрование)
Приложение использует только стандартное шифрование (TLS/VPN) → подпадает под exemption.
- В `Info.plist` добавить: `ITSAppUsesNonExemptEncryption = NO`
  (xcconfig/Build Settings: `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`).
- В App Store Connect на вопрос про шифрование: «Yes, uses encryption» → «exempt»
  (standard encryption built into OS / standard VPN). Год-репорт обычно не нужен.

## Примечание для ревьюера (App Review Information → Notes)
```
bitaps is a managed VPN client (VLESS + Reality over NetworkExtension /
Packet Tunnel). Sign-in is via Telegram or email; the per-user VPN config is
issued by our backend after login.

For review, use the demo account below — it grants a working VPN profile
without payment. Subscriptions are handled outside the App Store (in our
Telegram bot); no purchasable content is sold inside the app.

The Packet Tunnel extension routes traffic through sing-box; no user activity
is logged.
```
- **Demo account:** (создать тест-аккаунт в боте с активной подпиской и рабочим vpn_key; вписать сюда логин/способ входа)
- **Contact:** @bitapssupport

## Скриншоты (нужны минимум для 6.9"/6.7" iPhone; остальное масштабируется)
Снять на устройстве/симуляторе эти 5 экранов (порядок = порядок показа):
1. **Главная** — подключено, таймер, режимы (витрина продукта).
2. **Серверы** — список + «Авто: быстрейший узел».
3. **Проверка защиты / Мой IP** — экран утечек «Вы защищены».
4. **Кабинет** — подписка (кольцо дней) + ключ доступа.
5. **Настройки** — чистый список (без эксперт-режима) + тёмная/светлая.
Текст-оверлеи (RU/EN): «В один тап», «Обход блокировок», «Без логов».

## Чек-лист перед Submit
- [ ] iOS-сборка с прилинкованным движком, тест на устройстве (туннель реально работает)
- [ ] `useSupabase=true`, `useSingBox=true`
- [ ] Тест-аккаунт ревьюера живой (вход + рабочий vpn_key)
- [ ] `ITSAppUsesNonExemptEncryption=NO`
- [ ] Скриншоты загружены, тексты RU/EN, privacy-ярлык, export — заполнены
- [ ] Privacy Policy и Оферта доступны по ссылкам
- [ ] Подписка/оплата работает (или явно вне App Store — указано в notes)
