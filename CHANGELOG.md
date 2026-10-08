# Changelog

## 0.1.1 — 2026-10-08

### Fixed

- Removed the global collapse refusal when macOS resolves another installed copy of a running application. An application-path mismatch no longer blocks the entire group.
- Group membership continues to be recalculated from current menu bar positions on each collapse; no stored installation-path binding is required.
- Existing auto-hide settings and status-item placement are preserved.

### Known limitations and verification

- The private macOS allowlist can still hide a conflicting or development-folder app outside the middle group. This release does not fix that system behavior. In the verified local configuration, launching the current affected app from Applications restored its visibility; removing an old copy alone did not suffice. A later launch from an extension folder may reproduce the issue.
- Collapse, expansion and auto-hide were visually checked on macOS 27.0.1 using an equivalent locally signed build. The public archive is separately validated, ad-hoc signed and **not notarized**.

### По-русски

Устранена общая блокировка сворачивания при несовпадении запущенной и выбранной macOS копий приложения. Группа пересчитывается по текущему расположению; настройки автоскрытия и расстановка сохраняются.

Ограничение macOS остаётся: конфликтующая копия может скрываться даже вне группы. В проверенной конфигурации помог запуск актуальной версии затронутого приложения из Applications; одного удаления старой версии было недостаточно. Это локальный обход, не автоматическое исправление сторонних приложений в данном релизе.

## 0.1.0 — 2026-10-07

First public, experimental release for **macOS 27 / Apple Silicon**.

### Features

- Native divider and arrow delimiting a collapsible middle group of menu bar icons.
- Manual collapse/expand and optional auto-hide with 3/5/10/30-second delay.
- Group classification using hosted menu bar geometry from one display.
- Protection against some ambiguous application-identity configurations.
- Background relaunches/exits of known applications no longer cause periodic expansion.
- Failed hiding no longer disables the auto-hide preference; automatic retry backs off.
- English and Russian installation/build documentation, MIT license and local release packaging.

### Distribution and limitations

- Ad-hoc signed, **not Developer ID signed or notarized**.
- Uses undocumented Apple APIs; tested on macOS 27.0.1, not guaranteed on future versions.
- Runtime UI is currently Russian.
- No Intel binary, automatic updater, configured login item or independent per-display layouts.
- Restrictions operate per application, not per icon; third-party compatibility varies.

## По-русски

Первый открытый экспериментальный выпуск: скрытие средней группы значков, ручное управление и автоскрытие, устранение периодического раскрытия от фоновых процессов, сохранение настройки при ошибке. Добавлены инструкции на двух языках и упаковка релиза.

Готовая сборка — Apple Silicon, macOS 27. Подпись ad-hoc, нотарификации нет. Ограничения приватного API и совместимости описаны в [русской инструкции](README.ru.md).
