obs           = obslua
source_name   = ""

stop_text     = ""
mode          = ""
a_mode        = ""
format        = ""
up_format     = ""
up_color_1    = ""
up_color_2    = ""
activated     = false
global        = false
timer_active  = false
settings_     = nil
orig_time     = 0
cur_time      = 0
cur_ns        = 0
up_when_finished = true
up            = false
paused        = false
switch_to_scene = false
next_scene    = ""

hotkey_id_reset     = obs.OBS_INVALID_HOTKEY_ID
hotkey_id_pause     = obs.OBS_INVALID_HOTKEY_ID

function delta_time(year, month, day, hour, minute, second)
	local now = os.time()

	if (year == -1) then
		year = os.date("%Y", now)
	end

	if (month == -1) then
		month = os.date("%m", now)
	end

	if (day == -1) then
		day = os.date("%d", now)
	end

	local future = os.time{year=year, month=month, day=day, hour=hour, min=minute, sec=second}
	local seconds = os.difftime(future, now)

	if (seconds < 0) then
		seconds = seconds + 86400
	end

	return seconds * 1000000000
end

function get_color_code(color)
    local r = tonumber(color:sub(1,2),16)
	local g = tonumber(color:sub(3,4),16)
    local b = tonumber(color:sub(5,6),16)
	local value = 255*256*256*256 + b*256*256 + g*256 + r
	return value
end

function set_time_text(ns, text)
	local ms = math.floor(ns / 1000000)

	if string.match(text, "%%0H") then
		local hours_infinite = math.floor(ms / 3600000)
		hours_infinite = string.format("%02d", hours_infinite)
		text = string.gsub(text, "%%0H", hours_infinite)
	end

	if string.match(text, "%%0M") then
		local minutes_infinite = math.floor(ms / 60000)
		minutes_infinite = string.format("%02d", minutes_infinite)
		text = string.gsub(text, "%%0M", minutes_infinite)
	end

	if string.match(text, "%%0S") then
		local seconds_infinite = math.floor(ms / 1000)
		seconds_infinite = string.format("%02d", seconds_infinite)
		text = string.gsub(text, "%%0S", seconds_infinite)
	end

	if string.match(text, "%%0h") then
		local hours = math.floor(ms / 3600000) % 24
		hours = string.format("%02d", hours)
		text = string.gsub(text, "%%0h", hours)
	end

	if string.match(text, "%%0m") then
		local minutes = math.floor(ms / 60000) % 60
		minutes = string.format("%02d", minutes)
		text = string.gsub(text, "%%0m", minutes)
	end

	if string.match(text, "%%0s") then
		local seconds = math.floor(ms / 1000) % 60
		seconds = string.format("%02d", seconds)
		text = string.gsub(text, "%%0s", seconds)
	end

	if string.match(text, "%%H") then
		local hours_infinite = math.floor(ms / 3600000)
		text = string.gsub(text, "%%H", hours_infinite)
	end

	if string.match(text, "%%M") then
		local minutes_infinite = math.floor(ms / 60000)
		text = string.gsub(text, "%%M", minutes_infinite)
	end

	if string.match(text, "%%S") then
		local seconds_infinite = math.floor(ms / 1000)
		text = string.gsub(text, "%%S", seconds_infinite)
	end

	if string.match(text, "%%h") then
		local hours = math.floor(ms / 3600000) % 24
		text = string.gsub(text, "%%h", hours)
	end

	if string.match(text, "%%m") then
		local minutes = math.floor(ms / 60000) % 60
		text = string.gsub(text, "%%m", minutes)
	end

	if string.match(text, "%%s") then
		local seconds = math.floor(ms / 1000) % 60
		text = string.gsub(text, "%%s", seconds)
	end

	if string.match(text, "%%d") then
		local days = math.floor(ms / 86400000)
		text = string.gsub(text, "%%d", tostring(days))
	end

	local decimal = string.format("%.3d", ms % 1000)

	if string.match(text, "%%3t") then
		decimal = string.sub(decimal, 1, 3)
		text = string.gsub(text, "%%3t", decimal)
	end

	if string.match(text, "%%2t") then
		decimal = string.sub(decimal, 1, 2)
		text = string.gsub(text, "%%2t", decimal)
	end

	if string.match(text, "%%t") then
		decimal = string.sub(decimal, 1, 1)
		text = string.gsub(text, "%%t", decimal)
	end

	local source = obs.obs_get_source_by_name(source_name)
	if source ~= nil then
		local settings = obs.obs_data_create()
		obs.obs_data_set_string(settings, "text", text)
		if up and up_color_1 then
			if up_color_2 and ((ms/1000)%2) >= 1 then
				obs.obs_data_set_int(settings, "color", get_color_code(up_color_2))
			else
				obs.obs_data_set_int(settings, "color", get_color_code(up_color_1))
			end
		else
			obs.obs_data_set_int(settings, "color", get_color_code("FFFFFF"))
		end
		obs.obs_source_update(source, settings)
		obs.obs_data_release(settings)
		obs.obs_source_release(source)
	end
end

function on_event(event)
	if event == obs.OBS_FRONTEND_EVENT_STREAMING_STARTED then
		if mode == "Streaming timer" then
			cur_time = 0
			stop_timer()
			start_timer()
		end
	elseif event == obs.OBS_FRONTEND_EVENT_STREAMING_STOPPED then
		if mode == "Streaming timer" then
			stop_timer()
		end
	elseif event == obs.OBS_FRONTEND_EVENT_RECORDING_STARTED then
		if mode == "Recording timer" then
			cur_time = 0
			stop_timer()
			start_timer()
		end
	elseif event == obs.OBS_FRONTEND_EVENT_RECORDING_STOPPED then
		if mode == "Recording timer" then
			stop_timer()
		end
	end
end

function script_tick(sec)
	if timer_active == false then
		return
	end

	local delta = obs.os_gettime_ns() - orig_time

	if mode == "Countup" or mode == "Streaming timer" or mode == "Recording timer" or up == true then
		cur_ns = cur_time + delta
	else
		cur_ns = cur_time - delta
	end

	if cur_ns < 1 and (mode == "Countdown" or mode == "Specific time" or mode == "Specific date and time") then
		if up_when_finished == false then
			stop_timer()
			if next_scene ~= "" and switch_to_scene == true then
				local source = obs.obs_get_source_by_name(next_scene)
				obs.obs_source_release(source)
				obs.obs_frontend_remove_event_callback(on_event)
				obs.obs_frontend_set_current_scene(source)
				obs.obs_frontend_add_event_callback(on_event)
			else
				set_time_text(cur_ns, stop_text)
			end

			return
		else
			cur_time = 0
			up = true
			start_timer()
			return
		end
	end

	this_format = format
	if up and up_format then
		this_format = up_format
	end
	set_time_text(cur_ns, this_format)
end

function start_timer()
	timer_active = true
	orig_time = obs.os_gettime_ns()
end

function stop_timer()
	timer_active = false
end

function activate(activating)
	if activated == activating then
		return
	end

	if (mode == "Streaming timer" or mode == "Recording timer") then
		return
	end

	activated = activating

	if activating then
		if global then
			return
		end

		script_update(settings_)
	end
end

function activate_signal(cd, activating)
	local source = obs.calldata_source(cd, "source")
	if source ~= nil then
		local name = obs.obs_source_get_name(source)
		if (name == source_name) then
			activate(activating)
		end
	end
end

function source_activated(cd)
	activate_signal(cd, true)
end

function source_deactivated(cd)
	activate_signal(cd, false)
end

function reset(pressed)
	if not pressed then
		return
	end

	if mode == "Streaming timer" or mode == "Recording timer" then
		return
	end

	script_update(settings_)
end

function on_pause(pressed)
	if not pressed then
		return
	end

	if mode == "Streaming timer" or mode == "Recording timer" then
		return
	end

	if cur_ns < 1 then
		reset(true)
	end

	if timer_active then
		stop_timer()
		cur_time = cur_ns
		paused = true
	else
		stop_timer()
		start_timer()
		paused = false
	end
end

function pause_button_clicked(props, p)
	on_pause(true)
	return true
end

function reset_button_clicked(props, p)
	reset(true)
	return true
end

function settings_modified(props, prop, settings)
	local mode_setting = obs.obs_data_get_string(settings, "mode")
	local p_duration = obs.obs_properties_get(props, "duration")
	local p_offset = obs.obs_properties_get(props, "offset")
	local p_year = obs.obs_properties_get(props, "year")
	local p_month = obs.obs_properties_get(props, "month")
	local p_day = obs.obs_properties_get(props, "day")
	local p_hour = obs.obs_properties_get(props, "hour")
	local p_minutes = obs.obs_properties_get(props, "minutes")
	local p_seconds = obs.obs_properties_get(props, "seconds")
	local p_stop_text = obs.obs_properties_get(props, "stop_text")
	local p_a_mode = obs.obs_properties_get(props, "a_mode")
	local button_pause = obs.obs_properties_get(props, "pause_button")
	local button_reset = obs.obs_properties_get(props, "reset_button")
	local up_finished = obs.obs_properties_get(props, "countup_countdown_finished")
	local switch_to = obs.obs_properties_get(props, "switch_to_scene")
	local next_scene = obs.obs_properties_get(props, "next_scene")

	local enable_scene_switch = obs.obs_data_get_bool(settings, "switch_to_scene")
	obs.obs_property_set_enabled(next_scene, enable_scene_switch)

	if (mode_setting == "Countdown") then
		obs.obs_property_set_visible(p_duration, true)
		obs.obs_property_set_visible(p_offset, false)
		obs.obs_property_set_visible(p_year, false)
		obs.obs_property_set_visible(p_month, false)
		obs.obs_property_set_visible(p_day, false)
		obs.obs_property_set_visible(p_hour, false)
		obs.obs_property_set_visible(p_minutes, false)
		obs.obs_property_set_visible(p_seconds, false)
		obs.obs_property_set_visible(p_stop_text, true)
		obs.obs_property_set_visible(button_pause, true)
		obs.obs_property_set_visible(button_reset, true)
		obs.obs_property_set_visible(p_a_mode, true)
		obs.obs_property_set_visible(up_finished, true)
		obs.obs_property_set_visible(switch_to, true)
		obs.obs_property_set_visible(next_scene, true)
	elseif (mode_setting == "Countup") then
		obs.obs_property_set_visible(p_duration, false)
		obs.obs_property_set_visible(p_offset, true)
		obs.obs_property_set_visible(p_year, false)
		obs.obs_property_set_visible(p_month, false)
		obs.obs_property_set_visible(p_day, false)
		obs.obs_property_set_visible(p_hour, false)
		obs.obs_property_set_visible(p_minutes, false)
		obs.obs_property_set_visible(p_seconds, false)
		obs.obs_property_set_visible(p_stop_text, false)
		obs.obs_property_set_visible(button_pause, true)
		obs.obs_property_set_visible(button_reset, true)
		obs.obs_property_set_visible(p_a_mode, true)
		obs.obs_property_set_visible(up_finished, false)
		obs.obs_property_set_visible(switch_to, false)
		obs.obs_property_set_visible(next_scene, false)
	elseif (mode_setting == "Specific time") then
		obs.obs_property_set_visible(p_duration, false)
		obs.obs_property_set_visible(p_offset, false)
		obs.obs_property_set_visible(p_year, false)
		obs.obs_property_set_visible(p_month, false)
		obs.obs_property_set_visible(p_day, false)
		obs.obs_property_set_visible(p_hour, true)
		obs.obs_property_set_visible(p_minutes, true)
		obs.obs_property_set_visible(p_seconds, true)
		obs.obs_property_set_visible(p_stop_text, true)
		obs.obs_property_set_visible(button_pause, true)
		obs.obs_property_set_visible(button_reset, true)
		obs.obs_property_set_visible(p_a_mode, true)
		obs.obs_property_set_visible(up_finished, true)
		obs.obs_property_set_visible(switch_to, true)
		obs.obs_property_set_visible(next_scene, true)
	elseif (mode_setting == "Specific date and time") then
		obs.obs_property_set_visible(p_duration, false)
		obs.obs_property_set_visible(p_offset, false)
		obs.obs_property_set_visible(p_year, true)
		obs.obs_property_set_visible(p_month, true)
		obs.obs_property_set_visible(p_day, true)
		obs.obs_property_set_visible(p_hour, true)
		obs.obs_property_set_visible(p_minutes, true)
		obs.obs_property_set_visible(p_seconds, true)
		obs.obs_property_set_visible(p_stop_text, true)
		obs.obs_property_set_visible(button_pause, true)
		obs.obs_property_set_visible(button_reset, true)
		obs.obs_property_set_visible(p_a_mode, true)
		obs.obs_property_set_visible(up_finished, true)
		obs.obs_property_set_visible(switch_to, true)
		obs.obs_property_set_visible(next_scene, true)
	elseif (mode_setting == "Streaming timer") then
		obs.obs_property_set_visible(p_duration, false)
		obs.obs_property_set_visible(p_offset, false)
		obs.obs_property_set_visible(p_year, false)
		obs.obs_property_set_visible(p_month, false)
		obs.obs_property_set_visible(p_day, false)
		obs.obs_property_set_visible(p_hour, false)
		obs.obs_property_set_visible(p_minutes, false)
		obs.obs_property_set_visible(p_seconds, false)
		obs.obs_property_set_visible(p_stop_text, false)
		obs.obs_property_set_visible(button_pause, false)
		obs.obs_property_set_visible(button_reset, false)
		obs.obs_property_set_visible(p_a_mode, false)
		obs.obs_property_set_visible(up_finished, false)
		obs.obs_property_set_visible(switch_to, false)
		obs.obs_property_set_visible(next_scene, false)
	elseif (mode_setting == "Recording timer") then
		obs.obs_property_set_visible(p_duration, false)
		obs.obs_property_set_visible(p_offset, false)
		obs.obs_property_set_visible(p_year, false)
		obs.obs_property_set_visible(p_month, false)
		obs.obs_property_set_visible(p_day, false)
		obs.obs_property_set_visible(p_hour, false)
		obs.obs_property_set_visible(p_minutes, false)
		obs.obs_property_set_visible(p_seconds, false)
		obs.obs_property_set_visible(p_stop_text, false)
		obs.obs_property_set_visible(button_pause, false)
		obs.obs_property_set_visible(button_reset, false)
		obs.obs_property_set_visible(p_a_mode, false)
		obs.obs_property_set_visible(up_finished, false)
		obs.obs_property_set_visible(switch_to, false)
		obs.obs_property_set_visible(next_scene, false)
	end

	return true
end

function script_properties()
	local props = obs.obs_properties_create()

	local p_mode = obs.obs_properties_add_list(props, "mode", "Mode", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(p_mode, "Countdown", "countdown")
	obs.obs_property_list_add_string(p_mode, "Countup", "countup")
	obs.obs_property_list_add_string(p_mode, "Specific time", "specific_time")
	obs.obs_property_list_add_string(p_mode, "Specific date and time", "specific_date_and_time")
	obs.obs_property_list_add_string(p_mode, "Streaming timer", "stream")
	obs.obs_property_list_add_string(p_mode, "Recording timer", "recording")
	obs.obs_property_set_modified_callback(p_mode, settings_modified)

	obs.obs_properties_add_int(props, "duration", "Countdown duration (seconds)", 1, 100000000, 1)
	obs.obs_properties_add_int(props, "offset", "Countup from (seconds)", 0, 100000000, 1)
	obs.obs_properties_add_int(props, "year", "Year", 1971, 100000000, 1)
	obs.obs_properties_add_int(props, "month", "Month (1-12)", 1, 12, 1)
	obs.obs_properties_add_int(props, "day", "Day (1-31)", 1, 31, 1)
	obs.obs_properties_add_int(props, "hour", "Hour (0-24)", 0, 24, 1)
	obs.obs_properties_add_int(props, "minutes", "Minutes (0-59)", 0, 59, 1)
	obs.obs_properties_add_int(props, "seconds", "Seconds (0-59)", 0, 59, 1)
	local f_prop = obs.obs_properties_add_text(props, "format", "Format", obs.OBS_TEXT_DEFAULT)
	obs.obs_property_set_long_description(f_prop, "%d - days\n%0h - hours with leading zero (00..23)\n%h - hours (0..23)\n%0H - hours with leading zero (00..infinity)\n%H - hours (0..infinity)\n%0m - minutes with leading zero (00..59)\n%m - minutes (0..59)\n%0M - minutes with leading zero (00..infinity)\n%M - minutes (0..infinity)\n%0s - seconds with leading zero (00..59)\n%s - seconds (0..59)\n%0S - seconds with leading zero (00..infinity)\n%S - seconds (0..infinity)\n%t - tenths\n%2t - hundredths\n%3t - thousandths")
	local f_up_prop = obs.obs_properties_add_text(props, "up_format", "Countup format", obs.OBS_TEXT_DEFAULT)
	obs.obs_property_set_long_description(f_up_prop, "If countup is enabled, use a different format when counting up?")
	
	obs.obs_properties_add_text(props, "up_color_1", "Countup color 1", obs.OBS_TEXT_DEFAULT)
	obs.obs_properties_add_text(props, "up_color_2", "Countup color 2", obs.OBS_TEXT_DEFAULT)
	
	local p = obs.obs_properties_add_list(props, "source", "Text source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			source_id = obs.obs_source_get_unversioned_id(source)
			if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(p, name, name)
			end
		end
	end
	obs.source_list_release(sources)

	local switch_scene = obs.obs_properties_add_bool(props, "switch_to_scene", "Switch to scene when finished")
	obs.obs_property_set_modified_callback(switch_scene, settings_modified)
	p = obs.obs_properties_add_list(props, "next_scene", "Scene", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local scenes = obs.obs_frontend_get_scenes()
	if scenes ~= nil then
		for _, scene in ipairs(scenes) do
			local name = obs.obs_source_get_name(scene)
			obs.obs_property_list_add_string(p, name, name)
		end
	end
	obs.source_list_release(scenes)

	obs.obs_properties_add_text(props, "stop_text", "Countdown final text", obs.OBS_TEXT_DEFAULT)

	local p_a_mode = obs.obs_properties_add_list(props, "a_mode", "Activation mode", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(p_a_mode, "Global (timer always active)", "global")
	obs.obs_property_list_add_string(p_a_mode, "Start timer on activation", "start_reset")
	obs.obs_properties_add_bool(props, "countup_countdown_finished", "Countup when done")

	obs.obs_properties_add_button(props, "pause_button", "Start/Stop", pause_button_clicked)
	obs.obs_properties_add_button(props, "reset_button", "Reset", reset_button_clicked)

	settings_modified(props, nil, settings_)

	return props
end

function script_description()
	return "Sets a text source to act as a timer with advanced options. Hotkeys can be set for starting/stopping and to the reset timer."
end

function script_update(settings)
	stop_timer()
	up = false

	mode = obs.obs_data_get_string(settings, "mode")
	a_mode = obs.obs_data_get_string(settings, "a_mode")
	source_name = obs.obs_data_get_string(settings, "source")
	stop_text = obs.obs_data_get_string(settings, "stop_text")
	local year = obs.obs_data_get_int(settings, "year")
	local month = obs.obs_data_get_int(settings, "month")
	local day = obs.obs_data_get_int(settings, "day")
	local hour = obs.obs_data_get_int(settings, "hour")
	local minute = obs.obs_data_get_int(settings, "minutes")
	local second = obs.obs_data_get_int(settings, "seconds")
	format = obs.obs_data_get_string(settings, "format")
	up_format = obs.obs_data_get_string(settings, "up_format")
	up_color_1 = obs.obs_data_get_string(settings, "up_color_1")
	up_color_2 = obs.obs_data_get_string(settings, "up_color_2")
	up_when_finished = obs.obs_data_get_bool(settings, "countup_countdown_finished")
	switch_to_scene = obs.obs_data_get_bool(settings, "switch_to_scene")
	next_scene = obs.obs_data_get_string(settings, "next_scene")

	if mode == "Countdown" then
		cur_time = obs.obs_data_get_int(settings, "duration") * 1000000000
	elseif mode == "Countup" then
		cur_time = obs.obs_data_get_int(settings, "offset") * 1000000000
	elseif mode == "Specific time" then
		cur_time = delta_time(-1, -1, -1, hour, minute, second)
	elseif mode == "Specific date and time" then
		cur_time = delta_time(year, month, day, hour, minute, second)
	else
		cur_time = 0
	end

	global = a_mode == "Global (timer always active)"

	if mode == "Streaming timer" or mode == "Recording timer" then
		global = true
	end

	this_format = format
	if up and up_format then
		this_format = up_format
	end
	set_time_text(cur_time, this_format)

	if global == false and paused == false then
		start_timer()
	end
end

function script_defaults(settings)
	obs.obs_data_set_default_int(settings, "duration", 5)
	obs.obs_data_set_default_int(settings, "offset", 0)
	obs.obs_data_set_default_int(settings, "year", os.date("%Y", os.time()))
	obs.obs_data_set_default_int(settings, "month", os.date("%m", os.time()))
	obs.obs_data_set_default_int(settings, "day", os.date("%d", os.time()))
	obs.obs_data_set_default_string(settings, "stop_text", "")
	obs.obs_data_set_default_string(settings, "mode", "Countdown")
	obs.obs_data_set_default_string(settings, "a_mode", "Global (timer always active)")
	obs.obs_data_set_default_string(settings, "format", "%0m:%0s")
	obs.obs_data_set_default_string(settings, "up_format", "+%0m:%0s")
	obs.obs_data_set_default_string(settings, "up_color_1", "FF0000")
	obs.obs_data_set_default_string(settings, "up_color_2", "FFFFFF")
end

function script_save(settings)
	local hotkey_save_array_reset = obs.obs_hotkey_save(hotkey_id_reset)
	local hotkey_save_array_pause = obs.obs_hotkey_save(hotkey_id_pause)
	obs.obs_data_set_array(settings, "reset_hotkey", hotkey_save_array_reset)
	obs.obs_data_set_array(settings, "pause_hotkey", hotkey_save_array_pause)
	obs.obs_data_array_release(hotkey_save_array_pause)
	obs.obs_data_array_release(hotkey_save_array_reset)
end

function script_load(settings)
	local sh = obs.obs_get_signal_handler()
	obs.signal_handler_connect(sh, "source_activate", source_activated)
	obs.signal_handler_connect(sh, "source_deactivate", source_deactivated)

	hotkey_id_reset = obs.obs_hotkey_register_frontend("reset_timer_thingy", "Reset Timer", reset)
	hotkey_id_pause = obs.obs_hotkey_register_frontend("pause_timer", "Start/Stop Timer", on_pause)
	local hotkey_save_array_reset = obs.obs_data_get_array(settings, "reset_hotkey")
	local hotkey_save_array_pause = obs.obs_data_get_array(settings, "pause_hotkey")
	obs.obs_hotkey_load(hotkey_id_reset, hotkey_save_array_reset)
	obs.obs_hotkey_load(hotkey_id_pause, hotkey_save_array_pause)
	obs.obs_data_array_release(hotkey_save_array_reset)
	obs.obs_data_array_release(hotkey_save_array_pause)

	obs.obs_frontend_add_event_callback(on_event)

	settings_ = settings

	script_update(settings)
end
