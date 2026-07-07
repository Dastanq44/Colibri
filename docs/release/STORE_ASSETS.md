# Store listing assets & copy (TASK-1703)

Plan rule: **avoid misleading speed-reading claims** — describe fast mode as
focused, optional pacing, not "read 10× faster".

## Copy — English

**Name:** Colibri — Reader & Fast Mode
**Subtitle / short description:** A calm e-reader with an optional
rotate-to-focus fast mode.
**Description:**

> Colibri is a serious reader first. Import your EPUB, TXT, and PDF books,
> read offline, and keep your place across devices.
>
> When you want focus, rotate your phone: fast mode shows one word at a
> time at a pace you control, and rotating back returns you to the page —
> exactly where you were.
>
> • Import EPUB, TXT, PDF — reading works fully offline
> • Portrait = normal reading, landscape = fast mode; lock either mode
> • Adjustable pace (150–700 WPM) with simple tap controls
> • Notes, bookmarks, and in-book search
> • Reading themes, fonts, and readability profiles (incl. dyslexia-friendly)
> • Optional account to sync progress, notes, and your library

## Copy — Russian

**Название:** Colibri — читалка и быстрый режим
**Краткое описание:** Спокойная читалка с необязательным быстрым режимом
по повороту телефона.
**Описание:**

> Colibri — прежде всего серьёзная читалка. Импортируйте книги EPUB, TXT и
> PDF, читайте офлайн и продолжайте с того же места на любом устройстве.
>
> Хотите сфокусироваться — поверните телефон: быстрый режим показывает по
> одному слову в удобном вам темпе, а при повороте назад вы вернётесь на ту
> же страницу.
>
> • Импорт EPUB, TXT, PDF — чтение полностью офлайн
> • Портрет — обычное чтение, альбомная — быстрый режим; режим можно заблокировать
> • Настраиваемый темп (150–700 слов/мин), управление касаниями
> • Заметки, закладки и поиск по книге
> • Темы, шрифты и профили читаемости (включая режим для дислексии)
> • Аккаунт по желанию: синхронизация прогресса, заметок и библиотеки

## Assets needed (user/designer action)

- [ ] App icon 1024×1024 (currently the default Flutter icon — must be
      replaced; suggestion: hummingbird + open book mark). Wire via
      `flutter_launcher_icons` once the master PNG exists.
- [ ] iPhone screenshots (6.9" and 6.5"): Home, portrait reader, fast mode
      (landscape), reader settings, catalog — EN + RU
- [ ] Android phone screenshots (same five) + feature graphic 1024×500
- [ ] Privacy policy hosted at a public URL (see docs/legal/)

## Submission checklist

- [ ] Bundle IDs/signing: iOS team + provisioning; Android upload keystore
      (`android/key.properties` — NOT in git)
- [ ] Version/build number bump in pubspec.yaml
- [ ] `.env.production` with production Supabase project + SENTRY_DSN
- [ ] Deploy the `delete-account` edge function (store requirement)
- [ ] TestFlight internal group / Play internal testing track
