local mod = get_mod("PersonalHealthbars")

-- Загрузка необходимых модулей
local HudHealthBarLogic = require("scripts/ui/hud/elements/hud_health_bar_logic")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local UIRenderer = require("scripts/managers/ui/ui_renderer")
local UIWidget = require("scripts/managers/ui/ui_widget")

-- Инициализация шаблона маркера
local template = {}

--[[
	Размеры полоски здоровья в пикселях.
	[1] - ширина (120 пикселей)
	[2] - высота (6 пикселей)
]]
local size = {
	120,
	6,
}
template.size = size
template.name = "custom_healthbar"  -- Уникальное имя шаблона маркера
template.unit_node = "root_point"   -- Нода юнита для привязки маркера
template.position_offset = {        -- Смещение позиции маркера относительно ноды
	0,  -- X
	0,  -- Y
	0,  -- Z
}
template.check_line_of_sight = true  -- Проверять линию видимости для отображения
template.max_distance = 25            -- Максимальная дистанция видимости в метрах
template.screen_clamp = false        -- Не прижимать к краям экрана
template.remove_on_death_duration = 0.5  -- Задержка удаления маркера после смерти (секунды)
--[[
	Настройки отображения чисел урона.
	Определяет размеры, цвета, анимации и позиционирование чисел урона.
]]
template.damage_number_settings = {
	first_hit_size_scale = 1.2,              -- Масштаб первого попадания (120%)
	crit_hit_size_scale = 1.5,               -- Масштаб критического попадания (150%)
	visibility_delay = 5,                     -- Задержка перед показом чисел урона (секунды)
	expand_bonus_scale = 30,                 -- Дополнительный размер при расширении анимации
	default_color = "white",                 -- Цвет обычного урона
	has_taken_damage_timer_y_offset = 34,    -- Смещение по Y для таймера урона
	weakspot_color = "orange",               -- Цвет попадания в слабое место
	fade_delay = 0.35,                       -- Задержка перед затуханием (секунды)
	add_numbers_together_timer = 0.2,         -- Время для объединения близких попаданий (секунды)
	shrink_duration = 1,                     -- Длительность сжатия анимации (секунды)
	duration = 3,                            -- Длительность отображения числа урона (секунды)
	x_offset_between_numbers = 38,           -- Смещение по X между числами урона
	expand_duration = 0.2,                   -- Длительность расширения анимации (секунды)
	crit_color = "yellow",                   -- Цвет критического попадания
	hundreds_font_size = 14.4,               -- Размер шрифта для чисел >= 100
	default_font_size = 17,                  -- Размер шрифта по умолчанию
	has_taken_damage_timer_remove_after_time = 5,  -- Время удаления таймера урона (секунды)
	max_float_y = 100,                       -- Максимальное смещение по Y при всплытии
	dps_font_size = 14.4,                    -- Размер шрифта для DPS
	x_offset = 1,                            -- Базовое смещение по X
	dps_y_offset = -24,                      -- Смещение по Y для DPS
	y_offset = 15,                           -- Базовое смещение по Y
}
--[[
	Настройки анимации полоски здоровья.
	Определяет поведение анимации при изменении здоровья.
]]
template.bar_settings = {
	animate_on_health_increase = true,       -- Анимировать при увеличении здоровья
	bar_spacing = 2,                         -- Расстояние между полосками (если несколько)
	duration_health_ghost = 0.2,             -- Длительность анимации "призрака" здоровья (секунды)
	health_animation_threshold = 0.1,        -- Порог изменения здоровья для запуска анимации (10%)
	alpha_fade_delay = 0.3,                  -- Задержка перед затуханием прозрачности (секунды)
	duration_health = 0.5,                    -- Длительность анимации изменения здоровья (секунды)
	alpha_fade_min_value = 50,               -- Минимальное значение прозрачности (0-255)
	alpha_fade_duration = 0.4,               -- Длительность затухания прозрачности (секунды)
}
--[[
	Таблица соответствия типов брони и локализованных строк.
	Используется для отображения типа брони пораженной зоны.
	Ключ: тип брони (string)
	Значение: ключ локализации (string)
]]
local armor_type_string_lookup = {
	disgustingly_resilient = "loc_weapon_stats_display_disgustingly_resilient",
	super_armor = "loc_weapon_stats_display_super_armor",
	armored = "loc_weapon_stats_display_armored",
	resistant = "loc_glossary_armour_type_resistant",
	berserker = "loc_weapon_stats_display_berzerker",
	unarmored = "loc_weapon_stats_display_unarmored",
}
--[[
	Настройки затухания маркера в зависимости от дистанции.
	Определяет прозрачность маркера на разных дистанциях.
]]
template.fade_settings = {
	fade_to = 1,                              -- Прозрачность на минимальной дистанции (1 = полностью видимый)
	fade_from = 0.1,                          -- Прозрачность на максимальной дистанции (0.1 = почти невидимый)
	default_fade = 0.1,                       -- Прозрачность по умолчанию
	distance_max = template.max_distance,     -- Максимальная дистанция (25 метров)
	distance_min = template.max_distance * 0.5, -- Минимальная дистанция для затухания (12.5 метров)
	easing_function = math.ease_out_quad,     -- Функция плавности затухания
}

--[[
	Определяет цвет индикатора здоровья на основе процента здоровья.
	Используется для изменения цвета круглого индикатора здоровья.
	
	Параметры:
		health_percent (number) - процент здоровья от 0.0 до 1.0
	
	Возвращает:
		table - массив цветов RGBA в формате {alpha, red, green, blue}
			- Зеленый: {255, 0, 255, 0} для health_percent >= 0.5 (>= 50%)
			- Желтый: {255, 255, 255, 0} для health_percent >= 0.25 и < 0.5 (25-50%)
			- Красный: {255, 255, 0, 0} для health_percent < 0.25 (< 25%)
	
	Примечание:
		Формат цвета: {alpha, red, green, blue}, где значения от 0 до 255
]]
local function get_health_color(health_percent)
	if health_percent >= 0.5 then
		-- Green
		return { 255, 0, 255, 0 }
	elseif health_percent >= 0.25 then
		-- Yellow
		return { 255, 255, 255, 0 }
	else
		-- Red
		return { 255, 255, 0, 0 }
	end
end

--[[
	Создает определение виджета для полоски здоровья.
	Определяет структуру UI виджета с логическим проходом для отображения чисел урона
	и прямоугольным проходом для круглого индикатора здоровья.
	
	Параметры:
		template (table) - шаблон маркера, содержащий настройки размера и стиля
		scenegraph_id (string) - ID сценографа для позиционирования виджета
	
	Возвращает:
		table - определение виджета UIWidget, содержащее:
			- Логический проход (logic pass) для отображения чисел урона, DPS и типа брони
			- Прямоугольный проход (rect pass) для круглого индикатора здоровья
	
	Создаваемые элементы:
		1. Логический проход:
			- Отображает числа урона с анимацией расширения/сжатия
			- Отображает DPS после смерти врага
			- Отображает тип брони пораженной зоны
		2. Прямоугольный проход:
			- Круглый индикатор здоровья (всегда полный, меняет цвет)
			- Позиционируется слева от полоски здоровья
]]
template.create_widget_defintion = function(template, scenegraph_id)
	local size = template.size
	local header_font_setting_name = "nameplates"
	local header_font_settings = UIFontSettings[header_font_setting_name]
	local header_font_color = header_font_settings.text_color
	local bar_size = {
		size[1],
		size[2],
	}
	local bar_offset = {
		-size[1] * 0.5,
		0,
		0,
	}

	return UIWidget.create_definition({
		{
			pass_type = "logic",
			value = function(pass, ui_renderer, ui_style, ui_content, position, size)
				local damage_numbers = ui_content.damage_numbers
				local damage_number_settings = template.damage_number_settings
				local z_position = position[3]
				local y_position = position[2] + damage_number_settings.y_offset
				local x_position = position[1] + damage_number_settings.x_offset
				local scale = RESOLUTION_LOOKUP.scale
				local default_font_size = damage_number_settings.default_font_size * scale
				local dps_font_size = damage_number_settings.dps_font_size * scale
				local hundreds_font_size = damage_number_settings.hundreds_font_size * scale
				local font_type = ui_style.font_type
				local default_color = Color[damage_number_settings.default_color](255, true)
				local crit_color = Color[damage_number_settings.crit_color](255, true)
				local weakspot_color = Color[damage_number_settings.weakspot_color](255, true)
				local text_color = table.clone(default_color)
				local num_damage_numbers = #damage_numbers

				for i = num_damage_numbers, 1, -1 do
					local damage_number = damage_numbers[i]
					local duration = damage_number.duration
					local time = damage_number.time
					local progress = math.clamp(time / duration, 0, 1)

					if progress >= 1 then
						table.remove(damage_numbers, i)
					else
						damage_number.time = damage_number.time + ui_renderer.dt
					end

					if damage_number.was_critical then
						text_color[2] = crit_color[2]
						text_color[3] = crit_color[3]
						text_color[4] = crit_color[4]
						damage_number.expand_duration = damage_number_settings.expand_duration
					elseif damage_number.hit_weakspot then
						text_color[2] = weakspot_color[2]
						text_color[3] = weakspot_color[3]
						text_color[4] = weakspot_color[4]
					else
						text_color[2] = default_color[2]
						text_color[3] = default_color[3]
						text_color[4] = default_color[4]
					end

					local value = damage_number.value
					local font_size = value <= 99 and default_font_size or hundreds_font_size
					local expand_duration = damage_number.expand_duration

					if expand_duration then
						local expand_time = damage_number.expand_time
						local expand_progress = math.clamp(expand_time / expand_duration, 0, 1)
						local anim_progress = 1 - expand_progress
						font_size = font_size + damage_number_settings.expand_bonus_scale * anim_progress

						if expand_progress >= 1 then
							damage_number.expand_duration = nil
							damage_number.shrink_start_t = duration - damage_number_settings.shrink_duration
						else
							damage_number.expand_time = expand_time + ui_renderer.dt
						end
					elseif damage_number.shrink_start_t and damage_number.shrink_start_t < time then
						local diff = time - damage_number.shrink_start_t
						local percentage = diff / damage_number_settings.shrink_duration
						local scale = 1 - percentage
						font_size = font_size * scale
						text_color[1] = text_color[1] * scale
					end

					local text = value
					local size = ui_style.size
					local current_order = num_damage_numbers - i

					if current_order == 0 then
						local scale_size = damage_number.was_critical and damage_number_settings.crit_hit_size_scale
							or damage_number_settings.first_hit_size_scale
						font_size = font_size * scale_size
					end

					position[3] = z_position + current_order
					position[2] = y_position
					position[1] = x_position + current_order * damage_number_settings.x_offset_between_numbers

					UIRenderer.draw_text(ui_renderer, text, font_size, font_type, position, size, text_color, {})
				end

				local damage_has_started = ui_content.damage_has_started

				if damage_has_started then
					if not ui_content.damage_has_started_timer then
						ui_content.damage_has_started_timer = ui_renderer.dt
					elseif not ui_content.dead then
						ui_content.damage_has_started_timer = ui_content.damage_has_started_timer + ui_renderer.dt
					end

					if ui_content.dead then
						local damage_has_started_position =
							Vector3(x_position, y_position - damage_number_settings.dps_y_offset, z_position)
						local dps = ui_content.damage_has_started_timer > 1
								and ui_content.damage_taken / ui_content.damage_has_started_timer
							or ui_content.damage_taken
						local text = string.format("%d DPS", dps)

						UIRenderer.draw_text(
							ui_renderer,
							text,
							dps_font_size,
							font_type,
							damage_has_started_position,
							size,
							ui_style.text_color,
							{}
						)
					end

					if ui_content.last_hit_zone_name then
						local hit_zone_name = ui_content.last_hit_zone_name
						local breed = ui_content.breed
						local armor_type = breed.armor_type

						if breed.hitzone_armor_override and breed.hitzone_armor_override[hit_zone_name] then
							armor_type = breed.hitzone_armor_override[hit_zone_name]
						end

						local armor_type_loc_string = armor_type and armor_type_string_lookup[armor_type] or ""
						local armor_type_text = Localize(armor_type_loc_string)
						local armor_type_position = Vector3(
							x_position,
							y_position - damage_number_settings.has_taken_damage_timer_y_offset,
							z_position
						)

						UIRenderer.draw_text(
							ui_renderer,
							armor_type_text,
							dps_font_size,
							font_type,
							armor_type_position,
							size,
							ui_style.text_color,
							{}
						)
					end
				end

				ui_style.font_size = default_font_size
				position[3] = z_position
				position[2] = y_position
				position[1] = x_position
			end,
			style = {
				horizontal_alignment = "left",
				font_size = 30,
				text_vertical_alignment = "bottom",
				text_horizontal_alignment = "left",
				vertical_alignment = "center",
				offset = {
					-size[1] * 0.5,
					-size[2],
					2,
				},
				font_type = header_font_settings.font_type,
				text_color = header_font_color,
				size = {
					600,
					size[2],
				},
			},
		},
		{
			value = "content/ui/materials/backgrounds/default_square",
			style_id = "health_circle",
			pass_type = "rect",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "left",
				offset = {
					-size[1] * 0.5 - size[2] * 0.5 - 2,
					0,
					3,
				},
				size = {
					size[2],
					size[2],
				},
				color = {
					255,
					0,
					255,
					0,
				},
				corner_radius = size[2] * 0.5,
			},
		},
	}, scenegraph_id)
end

--[[
	Инициализирует виджет при создании маркера.
	Вызывается один раз при создании маркера полоски здоровья для врага.
	
	Параметры:
		widget (table) - виджет UI, который будет отображать полоску здоровья
		marker (table) - маркер, содержащий информацию о юните и позиции
		template (table) - шаблон маркера с настройками
	
	Действия:
		- Инициализирует таймеры и счетчики урона
		- Сбрасывает накопленный урон и массив чисел урона
		- Создает экземпляр HudHealthBarLogic для анимации полоски здоровья
		- Сохраняет данные о породе (breed) врага в content.breed
		- Инициализирует смещение головы (head_offset) для позиционирования маркера
	
	Инициализируемые поля:
		content.spawn_progress_timer (number) - таймер прогресса появления
		content.damage_taken (number) - накопленный урон (начинается с 0)
		content.damage_numbers (table) - массив чисел урона для отображения
		content.breed (table) - данные о породе врага
		marker.bar_logic (HudHealthBarLogic) - логика анимации полоски здоровья
		marker.head_offset (number) - смещение головы для позиционирования (вычисляется позже)
]]
template.on_enter = function(widget, marker, template)
	local content = widget.content
	content.spawn_progress_timer = 0
	content.damage_taken = 0
	content.damage_numbers = {}
	local bar_settings = template.bar_settings
	marker.bar_logic = HudHealthBarLogic:new(bar_settings)
	local unit = marker.unit
	local unit_data_extension = ScriptUnit.extension(unit, "unit_data_system")
	local breed = unit_data_extension:breed()
	content.breed = breed
	marker.head_offset = 0
end

-- Константа: название ноды головы для вычисления позиции маркера
local HEAD_NODE = "j_head"

--[[
	Обновляет виджет каждый кадр.
	Основная функция обновления, которая обрабатывает все аспекты отображения полоски здоровья:
	- Получение текущего здоровья врага
	- Обновление чисел урона
	- Обновление логики полоски здоровья
	- Установка цвета индикатора на основе здоровья
	- Обработка видимости и прозрачности
	- Удаление маркера при смерти врага
	
	Параметры:
		parent (table) - родительский элемент UI
		ui_renderer (UIRenderer) - рендерер UI для отрисовки элементов
		widget (table) - виджет, который обновляется
		marker (table) - маркер, содержащий информацию о юните и состояние
		template (table) - шаблон маркера с настройками
		dt (number) - дельта времени с предыдущего кадра (в секундах)
		t (number) - текущее время игры (в секундах)
	
	Обрабатываемые задачи:
		1. Получение текущего процента здоровья через HealthExtension
		2. Получение накопленного урона от локального игрока из mod._player_damage
		3. Вычисление смещения головы для позиционирования маркера над врагом
		4. Обновление массива чисел урона при изменении урона:
			- Добавление новых чисел урона
			- Объединение близких по времени попаданий
			- Анимация расширения/сжатия для критических попаданий
		5. Обновление логики полоски здоровья через HudHealthBarLogic
		6. Установка цвета круглого индикатора на основе процента здоровья
		7. Обработка видимости:
			- Проверка линии видимости (line of sight)
			- Задержка видимости (visibility_delay)
			- Задержка затухания (fade_delay)
		8. Удаление маркера при смерти врага после задержки
	
	Обновляемые поля:
		content.damage_taken (number) - накопленный урон
		content.damage_numbers (table) - массив чисел урона
		content.damage_has_started (boolean) - начался ли урон
		content.last_hit_zone_name (string) - название зоны последнего попадания
		content.dead (boolean) - мертв ли враг
		marker.health_fraction (number) - текущая доля здоровья
		marker.head_offset (number) - смещение головы для позиционирования
		widget.alpha_multiplier (number) - множитель прозрачности (0-1)
]]
template.update_function = function(parent, ui_renderer, widget, marker, template, dt, t)
	-- Получение ссылок на компоненты виджета
	local content = widget.content
	local style = widget.style
	local unit = marker.unit
	
	-- Получение расширения здоровья и проверка состояния врага
	local health_extension = ScriptUnit.has_extension(unit, "health_system")
	local is_dead = not health_extension or not health_extension:is_alive()
	local health_percent = is_dead and 0 or health_extension:current_health_percent()
	local max_health = Managers.state.difficulty:get_minion_max_health(content.breed.name)
	
	-- Получение накопленного урона от локального игрока (только ваш урон учитывается)
	local damage_taken = mod._player_damage[unit] or 0

	-- Вычисление смещения головы для позиционирования маркера над врагом
	-- Вычисляется один раз при первом обновлении, если юнит жив
	if ALIVE[unit] and marker.head_offset == 0 then
		local root_position = Unit.world_position(unit, 1)
		local node = Unit.node(unit, HEAD_NODE)
		local head_position = Unit.world_position(unit, node)
		-- Смещение = разница по Z между головой и корнем + небольшое смещение вверх (0.4)
		marker.head_offset = head_position.z - root_position.z + 0.4
	end

	-- Информация о попадании хранится в mod._last_hit_info при нанесении урона
	-- (обрабатывается в хуке AttackReportManager.add_attack_result)

	-- Обновление позиции маркера, если враг жив и получил урон
	if ALIVE[unit] and damage_taken > 0 then
		local root_position = Unit.world_position(unit, 1)

		if not marker.world_position then
			local node = Unit.node(unit, HEAD_NODE)
			local head_position = Unit.world_position(unit, node)
			head_position.z = head_position.z + 0.5
			marker.world_position = Vector3Box(head_position)
		else
			local position = marker.world_position:unbox()
			position.x = root_position.x
			position.y = root_position.y
			position.z = root_position.z + marker.head_offset

			marker.world_position:store(position)
		end
	end

	local old_damage_taken = content.damage_taken
	local damage_number_settings = template.damage_number_settings

	if damage_taken and damage_taken ~= old_damage_taken then
		content.visibility_delay = damage_number_settings.visibility_delay
		content.damage_taken = damage_taken

		if old_damage_taken < damage_taken then
			local damage_numbers = content.damage_numbers
			local damage_diff = math.ceil(damage_taken - old_damage_taken)
			local latest_damage_number = damage_numbers[#damage_numbers]
			local should_add = true
			
			-- Get hit info from stored data
			local last_hit_info = mod._last_hit_info[unit]
			local was_critical = false
			local hit_weakspot = false
			if last_hit_info then
				was_critical = last_hit_info.was_critical or false
				hit_weakspot = last_hit_info.hit_weakspot or false
			end

			if
				latest_damage_number
				and t - latest_damage_number.start_time < damage_number_settings.add_numbers_together_timer
			then
				should_add = false
			end

			if content.add_on_next_number or was_critical or should_add then
				-- Создание нового числа урона
				local damage_number = {
					expand_time = 0,                                    -- Время расширения анимации
					time = 0,                                          -- Общее время жизни числа
					start_time = t,                                    -- Время создания
					duration = damage_number_settings.duration,         -- Длительность отображения
					value = damage_diff,                               -- Значение урона
					expand_duration = damage_number_settings.expand_duration,  -- Длительность расширения
				}
				damage_number.hit_weakspot = hit_weakspot      -- Попадание в слабое место
				damage_number.was_critical = was_critical      -- Критическое попадание
				damage_numbers[#damage_numbers + 1] = damage_number

				-- Сброс флага добавления следующего числа
				if content.add_on_next_number then
					content.add_on_next_number = nil
				end

				-- Если было критическое попадание, следующее число будет добавлено отдельно
				if was_critical then
					content.add_on_next_number = true
				end
			else
				-- Объединение урона с предыдущим числом (попадания близко по времени)
				latest_damage_number.value = math.clamp(latest_damage_number.value + damage_diff, 0, max_health)
				latest_damage_number.time = 0                    -- Сброс таймера
				latest_damage_number.y_position = nil            -- Сброс позиции
				latest_damage_number.start_time = t              -- Обновление времени начала
				latest_damage_number.hit_weakspot = hit_weakspot -- Обновление информации о попадании
				latest_damage_number.was_critical = was_critical
			end
		end

		-- Отметка, что урон начался (для отображения DPS и типа брони)
		if not content.damage_has_started then
			content.damage_has_started = true
		end

		content.last_damage_taken_time = t
	end

	-- Обновление названия зоны последнего попадания из расширения здоровья
	-- (если доступно)
	if health_extension then
		local last_damaging_unit = health_extension:last_damaging_unit()
		if last_damaging_unit then
			content.last_hit_zone_name = health_extension:last_hit_zone_name() or "center_mass"
		end
	end

	-- Обновление времени и логики полоски здоровья
	content.t = t
	local bar_logic = marker.bar_logic

	-- Обновление логики анимации полоски здоровья
	bar_logic:update(dt, t, health_percent)

	-- Получение анимированных долей здоровья
	local health_fraction, health_ghost_fraction, health_max_fraction = bar_logic:animated_health_fractions()

	-- Круглый индикатор всегда показывает полный круг, но меняет цвет на основе здоровья
	if health_fraction then
		-- Установка цвета круга на основе процента здоровья
		-- (зеленый >= 50%, желтый 25-50%, красный < 25%)
		local health_color = get_health_color(health_percent)
		style.health_circle.color = health_color
		
		marker.health_fraction = health_fraction
	end

	-- Обработка видимости на основе линии видимости (line of sight)
	local line_of_sight_progress = content.line_of_sight_progress or 0

	-- Обновление прогресса видимости на основе результата рейкаста
	if marker.raycast_initialized then
		local raycast_result = marker.raycast_result
		local line_of_sight_speed = 10  -- Скорость изменения видимости

		-- Если есть линия видимости, увеличиваем видимость
		-- Если нет линии видимости, уменьшаем видимость
		if raycast_result then
			line_of_sight_progress = math.max(line_of_sight_progress - dt * line_of_sight_speed, 0)
		else
			line_of_sight_progress = math.min(line_of_sight_progress + dt * line_of_sight_speed, 1)
		end
	end

	-- Обработка смерти врага и удаление маркера
	if not HEALTH_ALIVE[unit] then
		if not content.remove_timer then
			-- Инициализация таймера удаления при смерти
			content.remove_timer = template.remove_on_death_duration
			content.dead = true
		else
			-- Уменьшение таймера удаления
			content.remove_timer = content.remove_timer - dt

			-- Удаление маркера, если таймер истек и здоровье = 0
			if content.remove_timer <= 0 and (not marker.health_fraction or marker.health_fraction == 0) then
				marker.remove = true
			end
		end
	end

	-- Вычисление множителя прозрачности (alpha_multiplier)
	-- Начинается с прогресса линии видимости
	local alpha_multiplier = line_of_sight_progress
	content.line_of_sight_progress = line_of_sight_progress
	local visibility_delay = content.visibility_delay

	-- Обработка задержки видимости (показ маркера только после получения урона)
	if visibility_delay then
		visibility_delay = visibility_delay - dt
		content.visibility_delay = visibility_delay >= 0 and visibility_delay or nil

		-- После истечения задержки видимости, устанавливаем задержку затухания
		if not content.visibility_delay then
			content.fade_delay = damage_number_settings.fade_delay
		end
	end

	-- Обработка задержки затухания (постепенное скрытие маркера)
	local fade_delay = content.fade_delay

	if fade_delay then
		fade_delay = fade_delay - dt
		content.fade_delay = fade_delay >= 0 and fade_delay or nil
		-- Вычисление прогресса затухания (от 1 до 0)
		local progress = math.clamp(fade_delay / damage_number_settings.fade_delay, 0, 1)
		alpha_multiplier = alpha_multiplier * progress
	elseif not visibility_delay then
		-- Если нет задержки видимости и задержки затухания, полностью скрываем
		alpha_multiplier = 0
	end

	-- Если здоровье = 0% или враг мертв, немедленно скрываем маркер
	if health_percent <= 0 or is_dead then
		alpha_multiplier = 0
	end

	-- Установка финального множителя прозрачности для виджета
	widget.alpha_multiplier = alpha_multiplier
end

return template
