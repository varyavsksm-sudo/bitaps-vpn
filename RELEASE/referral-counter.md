# Реферальный счётчик — сделано реально (2026-06-27)

## Что сделано (проверено на боевой БД bjkozsukvifkxriojxrz)
- В таблице `subscriptions` уже есть `referred_by` (бот ставит при `?start=ref_<id>`).
- Создана RPC-функция **`public.app_referral_stats()`** (SECURITY DEFINER): читает
  `telegram_id` из JWT сессии, считает рефералов, минуя RLS. Возвращает
  `{invited, subscribed, bonus_days}`.
- Добавлена колонка `referral_bonus_paid boolean` — флаг состоявшейся конверсии.
- `SupabaseAPI.fetchReferral` вызывает RPC → **реальный счётчик** (не нули/не мок).
- Проверено: транзакционный тест дал `invited=1` при выставленном `referred_by`,
  после `rollback` снова 0 (боевые данные не тронуты). PostgREST-эндпоинт отвечает.
- Сейчас показывает 0 — потому что в базе **реально 0 рефералов** (никто ещё не звал).

## Чтобы «оформили подписку» и «бонусные дни» начали считаться — патч бота
Бот сейчас ПОСЛЕ начисления бонуса делает `referred_by = null`, теряя историю.
Надо: не обнулять, а ставить флаг конверсии. Два места:

`supabase/functions/telegram-bot/index.ts` (~строка 549) и
`supabase/functions/platega-webhook/index.ts` (после начисления +14 дней):
```diff
-  await admin.from("subscriptions").update({ referred_by: null }).eq("telegram_id", id);
+  await admin.from("subscriptions").update({ referral_bonus_paid: true }).eq("telegram_id", id);
```
Деплой (нужен supabase CLI, у меня его нет):
```
supabase functions deploy telegram-bot --project-ref bjkozsukvifkxriojxrz
supabase functions deploy platega-webhook --project-ref bjkozsukvifkxriojxrz
```
После этого: `invited` = все позванные, `subscribed` = оплатившие, `bonus_days` = subscribed×14 — всё реально.

## Важно про «реально везде»
Запущенная сейчас demo-сборка показывает МОК-данные (`APIFactory.useSupabase=false`).
Реальные данные (реферал, подписка, ключ, устройства) приходят, когда
`useSupabase=true` И пользователь вошёл реальным Telegram-логином — этот путь
подключён к живому Supabase и проверен.
