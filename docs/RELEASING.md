# Release checklist / Выпуск релиза

## English

Releases are built locally on **Apple Silicon, macOS 27**, with the macOS 27 SDK and Swift 6.4. This procedure does not require an Apple signing identity. The default published ZIP is ad-hoc signed and **not notarized**; say so in every release. No hosted CI or notarization service is configured.

1. Review source changes and update the version/build values in [build.sh](../build.sh), the download filenames in both guides, and [CHANGELOG.md](../CHANGELOG.md).
2. Check that only public source and documentation are tracked. Never include local backups, system logs, editor history, preferences, screenshots of personal layouts, certificates or keys.
3. Commit the reviewed source. Export that exact commit into a new disposable directory using `git archive`; use this clean source tree for the release build.
4. Run `/bin/zsh scripts/package-release.sh` inside the clean tree. It builds without personal signing material, validates arm64 and the signature, and packages the application with MIT license and installation notes. Existing release files are not overwritten.
5. Verify the checksum from `dist/<version>/` with `shasum -a 256 -c SHA256SUMS.txt`. Extract the ZIP into a new directory and run `codesign --verify --deep --strict` on the extracted app. Inspect its architecture, version, file list and signature type; check for accidental personal paths/data.
6. Verify functionality on a suitable Mac without disrupting a user's live installation. Clearly distinguish checks on the release archive from runtime checks on an equivalent development build. Do not claim a public unsigned download was tested if only a local signed app was run.
7. Push the reviewed commit to the public repository; tag that commit `v<version>`. Create a GitHub Release with the matching tag, release notes, ZIP and checksum file. Include supported architecture, verified macOS version, unsigned/notarized status and known limitations.
8. Verify the public source, license, release links and assets. Download the uploaded artifact and compare its SHA-256 with the local file.

GitHub's automatic source archives contain tracked files, not your local build tree. The release ZIP contains only the app, MIT license and installation note. The packaging script keeps its temporary output under the ignored `dist/` directory for inspection; clean it up manually only when no longer needed.

### Future Developer ID releases

Use your own valid Apple Developer ID identity and Apple's current distribution/notarization workflow. The build script's optional identity setting alone is **not** a complete Developer ID release pipeline. Never store credentials or signing assets in the repository. Changing the signing identity may affect Accessibility permission on existing installations.

## Русский

Релиз собирается локально на **Apple Silicon с macOS 27**, SDK macOS 27 и Swift 6.4. Публичный ZIP по умолчанию подписан ad-hoc и **не нотарифицирован** — это обязательно указывать в описании выпуска.

- Обновите версию в [build.sh](../build.sh), обе инструкции и [CHANGELOG.md](../CHANGELOG.md).
- Проверьте состав Git: никаких локальных резервов, журналов, настроек, личных снимков и ключей.
- Зафиксируйте проверенные исходники и соберите экспорт конкретного коммита в отдельной чистой папке через [scripts/package-release.sh](../scripts/package-release.sh).
- Проверьте SHA-256, распаковку, подпись, архитектуру, версию и отсутствие личных данных. Не заменяйте рабочее приложение пользователя ради упаковки.
- Отдельно укажите, какие проверки выполнены на релизном архиве и какие — на эквивалентной локальной сборке. Не приписывайте неподтверждённые проверки.
- Опубликуйте коммит, тег и GitHub Release с ZIP, контрольной суммой, требованиями, предупреждением о подписи и ограничениями.
- Скачайте опубликованный архив и сравните контрольную сумму; проверьте доступность документации и лицензии.

Скрипт ничего не устанавливает и не загружает на GitHub. Apple Developer ID и нотарификация требуют отдельного процесса; включение имени сертификата в сборке само по себе его не заменяет.
