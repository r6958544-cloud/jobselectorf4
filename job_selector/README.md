# Riverside RP Job Selector

Система профессий для Sandbox с профессией Civil и whitelist New York Police Department.

## Полиция

- В профессиях появляется `Полицейский`.
- Доступ имеют `superadmin` и игроки, добавленные в whitelist по SteamID64.
- Группа ULX `policewl` может управлять whitelist через вкладку `Список полиции`.
- Вкладка показывает всех игроков whitelist отдельными строками, SteamID64, ник онлайн-игрока или статус `Оффлайн`, а также кнопку `Удалить`.
- Whitelist сохраняется в локальной SQLite-базе сервера.
- При входе за полицию игрок умирает и автоматически респавнится.
- Полицейский появляется в точке `8662.185546875, 7320.47021484375, 200.03125`.
- Модель устанавливается через 1.3 секунды после респавна, после чего полностью сбрасываются все бодигруппы, skin, material, изменения костей и прикреплённые prop/bonemerge-объекты:
  - `models/kerry/nypd_v2/male_04.mdl`
- Оружие:
  - `weapon_hands_sh`
  - `weapon_glock17`
  - `weapon_handcuffs`
  - `weapon_handcuffs_key`
  - `weapon_medkit_sh`
  - `weapon_bigbandage_sh`
  - `weapon_morphine`
  - `weapon_taser`
- Боеприпасы:
  - 50 `9x19 mm Parabellum`
  - 5 `Taser Cartridge`

## Установка

Скопируйте папку `job_selector` в `garrysmod/addons/`.
Убедитесь, что на сервере установлены оружейные аддоны с указанными классами оружия и боеприпасов.
