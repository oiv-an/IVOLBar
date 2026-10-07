# Contributing / Участие в проекте

## English

Thanks for helping improve IVOL Bar. Small, focused fixes and accurate compatibility reports are more useful than large rewrites.

### Report an issue

Use [GitHub Issues](https://github.com/oiv-an/IVOLBar/issues). Include:

- macOS version/build, chip architecture, IVOL Bar version and installation method;
- display configuration, including notches and external monitors;
- expected behavior, actual behavior and minimal reproduction steps;
- whether the issue persists with other menu bar organizers closed;
- relevant **redacted** diagnostics, not your entire system log.

Logs can contain application paths and menu bar layout. Crop screenshots to the menu bar and remove personal data, tokens, account information and unrelated applications. Do not post signing keys or private certificates.

### Work on a change

1. Fork and clone the repository.
2. Follow the [build instructions](README.md#build-from-source).
3. Keep changes scoped. Do not modify another user's preferences, icon positions or accessibility permissions as a side effect.
4. Build with a fresh output directory when checking reproducibility. Do not run two IVOL Bar copies at once.
5. Explain manual verification in the pull request: collapse, expand, auto-hide, quit, preserved outside icons and the display configuration you used.
6. Update both user guides when behavior changes.

A successful private-framework callback or retained Accessibility node is **not** proof of icon visibility. Verify the actual menu bar. Preserve bundle ID `pro.ivol.bar` and status-item autosave names `IVOLBar.arrow` / `IVOLBar.divider` for compatibility.

There is no automated UI test suite. Do not claim that a build alone proves menu bar compatibility. CI is not configured because the supported macOS 27 toolchain/runtime must be available; releases currently use a documented local process.

By submitting a contribution, you agree to license it under the project's [MIT license](LICENSE). Identify any third-party code and its license; do not copy incompatible or unlicensed code.

## Русский

Небольшие исправления и точные отчёты о совместимости полезнее полной переработки.

В [issue](https://github.com/oiv-an/IVOLBar/issues) укажите версию и сборку macOS, архитектуру, версию приложения и способ установки, мониторы/вырез экрана, шаги воспроизведения и ожидаемый результат. Прикладывайте только нужную диагностику **без личных данных**. На снимке достаточно строки меню. Не публикуйте ключи и сертификаты.

Для изменений используйте [инструкцию сборки](README.ru.md). Не меняйте настройки, расстановку значков и системные разрешения побочным эффектом. Не запускайте одновременно две копии IVOL Bar. В pull request опишите ручную проверку скрытия, раскрытия, автоскрытия, завершения и сохранения внешних значков. При изменении поведения обновляйте обе инструкции.

Системный callback и наличие Accessibility-элемента не доказывают видимость: проверяйте реальную строку меню. Сохраняйте bundle ID и имена статусных элементов. Автоматизированного UI-тестирования нет; одна успешная сборка не означает подтверждённую совместимость.

Вклад распространяется под [MIT](LICENSE). Для стороннего кода указывайте источник и совместимую лицензию.
