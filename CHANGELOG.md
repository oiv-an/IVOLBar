# Changelog

## 0.1.3 — 2026-10-09

- Recover IVOL Bar's arrow and divider after wake/display changes by recreating them once after 10 seconds without further display events. Each event restarts the wait.
- Defer recovery while asleep, configuring the group, using the menu, hovering over the menu bar or holding mouse buttons/Command. Resume normal auto-hide after recovery; retain existing autosave names and saved membership.
- Only IVOL Bar's own items are recreated; other applications and the system menu bar process are not restarted.
- После пробуждения стрелка и разделитель восстанавливаются с задержкой 10 секунд после последнего изменения экранов. Настройки группы и автоскрытия сохраняются; другие приложения не затрагиваются.

### Verification / Проверка

- Equivalent locally signed build: compilation, signature, launch, auto-hide and external-display arrow checked; preferences before/after installation matched byte-for-byte.
- A real sleep/wake cycle and the delayed recreation path have not yet been exercised. Released with this limitation explicitly acknowledged; recovery across all display setups is not guaranteed.
- Public ZIP: Apple Silicon, macOS 27+, ad-hoc signed, not notarized. Existing private-API and duplicate-application limitations remain.

## 0.1.2 — 2026-10-08

- Persist hidden application membership independently of menu bar geometry. Display wake/reconnection and relaunch no longer recalculate an established group from displaced markers.
- Add explicit configure/save/cancel actions; failed configuration retains the previous membership. Auto-hide pauses during configuration and display transitions.
- Physical icon order remains managed by macOS; duplicate-app visibility limitations remain unchanged.

### Verification / Проверка

- Collapse, reveal and auto-hide were visually checked on an equivalent locally signed build with adjacent markers. A later display-change event reused the same saved membership according to the runtime log; that event was not visually observed. A controlled sleep/reconnect cycle and GUI saving of a new group were not tested.
- Public ZIP: Apple Silicon, macOS 27+, ad-hoc signed, not notarized. Physical icon order and private-API duplicate-app limitations are unchanged.
- По-русски: состав скрываемой группы теперь сохраняется отдельно от координат. Сон и смена экранов не переписывают его. Для изменения состава используйте «Настроить группу по расположению…», затем «Сохранить группу по расположению»; обычное перетаскивание вне режима настройки не меняет состав.

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
