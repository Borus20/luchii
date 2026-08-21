# ЛучII

Офлайн передача файлов через QR-код — без интернета, без регистрации, без серверов.

## Режимы передачи

- **Animated QR** — файлы ≤ 10 КБ: base64 + multi-frame QR (200 мс/кадр)
- **P2P WiFi** — файлы > 10 КБ: TCP-сокет + AES-256/CBC шифрование

## Стек

Flutter 3.27 · Dart 3.5 · go_router · provider · mobile_scanner · qr_flutter · encrypt

## Цветовая схема

Molten Gold — уникальная для экосистемы BorusLab (bgDeep `#090806`, gold `#FFB700`, ember `#FF6B00`)
