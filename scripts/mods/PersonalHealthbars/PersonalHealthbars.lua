-- PersonalHealthbars
-- Description: Show healthbars with color-coded health levels (always full bar)
-- Author: Based on Healthbars by raindish
local mod = get_mod("PersonalHealthbars")
local Breeds = require("scripts/settings/breed/breeds")
local breed = require("scripts/utilities/breed")
local HealthExtension = require("scripts/extension_systems/health/health_extension")
local MarkerTemplate = mod:io_dofile("PersonalHealthbars/scripts/mods/PersonalHealthbars/HealthbarMarker")

--[[
	Таблица для отслеживания накопленного урона от локального игрока.
	Ключ: unit (userdata) - юнит врага
	Значение: number - накопленный урон
]]
mod._player_damage = {}

--[[
	Таблица для хранения информации о последнем попадании для каждого юнита.
	Ключ: unit (userdata) - юнит врага
	Значение: table - таблица с полями:
		- was_critical (boolean) - было ли критическое попадание
		- hit_weakspot (boolean) - попадание в слабое место
		- last_hit_zone_name (string|nil) - название зоны попадания
]]
mod._last_hit_info = {}

--[[
	Хук инициализации HudElementWorldMarkers.
	Регистрирует шаблон маркера полоски здоровья в системе маркеров.
	
	Параметры:
		self (table) - экземпляр HudElementWorldMarkers
]]
mod:hook_safe("HudElementWorldMarkers", "init", function(self)
	self._marker_templates[MarkerTemplate.name] = MarkerTemplate
end)

--[[
	Хук AttackReportManager.add_attack_result для отслеживания урона от локального игрока.
	Сохраняет накопленный урон и информацию о попадании для каждого атакованного юнита.
	
	Параметры:
		self (AttackReportManager) - экземпляр AttackReportManager
		damage_profile (table) - профиль урона атаки
		attacked_unit (userdata) - юнит, который был атакован
		attacking_unit (userdata) - юнит, который атаковал
		attack_direction (Vector3) - направление атаки
		hit_world_position (Vector3) - позиция попадания в мировых координатах
		hit_weakspot (boolean) - попадание в слабое место
		damage (number) - количество нанесенного урона
		attack_result (string) - результат атаки
		attack_type (string) - тип атаки (melee, ranged, explosion, etc.)
		damage_efficiency (number) - эффективность урона
		is_critical_strike (boolean) - было ли критическое попадание
	
	Действия:
		- Проверяет, что урон нанесен локальным игроком
		- Накапливает урон в mod._player_damage[attacked_unit]
		- Сохраняет информацию о попадании в mod._last_hit_info[attacked_unit]
]]
mod:hook_safe(CLASS.AttackReportManager, "add_attack_result", function(self, 
	damage_profile,
	attacked_unit,
	attacking_unit,
	attack_direction,
	hit_world_position,
	hit_weakspot,
	damage,
	attack_result,
	attack_type,
	damage_efficiency,
	is_critical_strike)
	
	-- Check if damage is from local player
	local local_player = Managers.player:local_player(1)
	if local_player and local_player.player_unit == attacking_unit then
		local dmg = tonumber(damage) or 0
		if dmg > 0 then
			-- Track damage for this unit
			mod._player_damage[attacked_unit] = (mod._player_damage[attacked_unit] or 0) + dmg
			
			-- Store hit info for this unit
			mod._last_hit_info[attacked_unit] = {
				was_critical = is_critical_strike or false,
				hit_weakspot = hit_weakspot or false,
				last_hit_zone_name = nil -- Will be set from health extension
			}
		end
	end
end)

--[[
	Определяет, нужно ли показывать полоску здоровья для указанного юнита.
	Проверяет тип врага и возвращает true только для boss, elite, special, captain.
	Обычные мобы (infested, unarmoured и т.д.) не показывают полоски здоровья.
	
	Параметры:
		unit (userdata) - юнит врага для проверки
	
	Возвращает:
		boolean - true если нужно показывать полоску здоровья, false в противном случае
	
	Логика проверки:
		1. Проверяет доступность игрового режима
		2. Получает данные о породе (breed) врага через unit_data_system
		3. Проверяет, является ли враг боссом (is_boss или теги monster/captain)
		4. Проверяет тип врага через breed.enemy_type() (elite, special, captain)
		5. Проверяет теги врага как запасной вариант (elite, special)
		6. Возвращает false для всех остальных типов (обычные мобы)
]]
local function should_enable_healthbar(unit)
	-- Check if game mode is available
	if not Managers.state or not Managers.state.game_mode then
		return false
	end

	local unit_data_extension = ScriptUnit.extension(unit, "unit_data_system")
	local breed_data = unit_data_extension:breed()
	if not breed_data then
		return false
	end

	-- Check if it's a boss
	local is_boss = false
	if breed_data.is_boss then
		is_boss = true
	elseif breed_data.tags then
		is_boss = breed_data.tags.monster or breed_data.tags.captain or breed_data.tags.cultist_captain or false
	end

	if is_boss then
		return true
	end

	-- Check enemy type using breed utility
	local enemy_type = breed.enemy_type(breed_data) or breed_data.breed_type

	-- Show healthbars only for boss, elite, special, captain
	-- Do not show for regular minions (infested, unarmoured, etc.)
	if enemy_type == "elite" or enemy_type == "special" or enemy_type == "captain" then
		return true
	end

	-- Also check tags as fallback
	if breed_data.tags then
		if breed_data.tags.elite or breed_data.tags.special then
			return true
		end
	end

	return false
end

--[[
	Хук инициализации HealthExtension.
	Создает маркер полоски здоровья при инициализации расширения здоровья врага.
	
	Параметры:
		_self (HealthExtension) - экземпляр HealthExtension
		_extension_init_context (table) - контекст инициализации расширения
		unit (userdata) - юнит, для которого инициализируется расширение
		_extension_init_data (table) - данные инициализации расширения
		_game_object_data (table) - данные игрового объекта
	
	Действия:
		- Проверяет через should_enable_healthbar(), нужно ли показывать полоску здоровья
		- Если да, создает маркер через событие add_world_marker_unit
]]
mod:hook_safe(
	"HealthExtension",
	"init",
	function(_self, _extension_init_context, unit, _extension_init_data, _game_object_data)
		if should_enable_healthbar(unit) then
			Managers.event:trigger("add_world_marker_unit", MarkerTemplate.name, unit)
		end
	end
)

--[[
	Хук инициализации HuskHealthExtension.
	Создает маркер полоски здоровья для сетевых юнитов (husks - синхронизированные юниты других игроков).
	Копирует необходимые методы из HealthExtension для работы с сетевыми юнитами.
	
	Параметры:
		self (HuskHealthExtension) - экземпляр HuskHealthExtension
		_extension_init_context (table) - контекст инициализации расширения
		unit (userdata) - юнит, для которого инициализируется расширение
		_extension_init_data (table) - данные инициализации расширения
		_game_session (table) - игровая сессия
		_game_object_id (number) - ID игрового объекта
		_owner_id (number) - ID владельца объекта
	
	Действия:
		- Копирует методы из HealthExtension для работы с сетевыми юнитами
		- Проверяет через should_enable_healthbar(), нужно ли показывать полоску здоровья
		- Если да, создает маркер через событие add_world_marker_unit
]]
mod:hook_safe(
	"HuskHealthExtension",
	"init",
	function(self, _extension_init_context, unit, _extension_init_data, _game_session, _game_object_id, _owner_id)
		-- Make sure husks have the methods needed
		self.set_last_damaging_unit = HealthExtension.set_last_damaging_unit
		self.last_damaging_unit = HealthExtension.last_damaging_unit
		self.last_hit_zone_name = HealthExtension.last_hit_zone_name
		self.last_hit_was_critical = HealthExtension.last_hit_was_critical
		self.was_hit_by_critical_hit_this_render_frame = HealthExtension.was_hit_by_critical_hit_this_render_frame

		-- Set has a healthbar
		if should_enable_healthbar(unit) then
			Managers.event:trigger("add_world_marker_unit", MarkerTemplate.name, unit)
		end
	end
)

