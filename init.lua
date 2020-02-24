
--[[

Copyright (C) 2015 - Auke Kok <sofar@foo-projects.org>

"inspector" is free software; you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as
published by the Free Software Foundation; either version 2.1
of the license, or (at your option) any later version.

--]]

local S = minetest.get_translator(minetest.get_current_modname())
-- NOTE: don't wrap literal variable names in S(), such as "param2" or "timeout",
-- even though it's being displayed in formspec text. Source code is not localized.

local fsc_modpath = minetest.get_modpath("fsc")
local function show_formspec(player_name, formspec)
	if fsc_modpath then
		fsc.show(player_name, formspec, {}, function() end)
	else
		-- none of Inspector's formspecs have player response handlers, so
		-- the name doesn't really matter.
		minetest.show_formspec(player_name, "inspector:formspec", formspec)
	end
end

local function make_fs(title, desc)
	return "size[12,8]"..
		"label[0.2,0.2;"..title.."]"..
		"textlist[0.2,1.0;11.5,7;;"..
		desc:gsub("\n", ",").."]"..
		"button_exit[11.1,0.2;0.8,0.8;close;x]"
end

local indent_string = "     "

local function text_header(text)
	return "==== " .. text .. " ===="
end

local function indent(level, text, emphasize)
	local result = text
	for i = 1, level do
		if emphasize then
			result = "->  "        .. string.gsub(result, "\n", "\n" .. indent_string)
		else
			result = indent_string .. string.gsub(result, "\n", "\n" .. indent_string)
		end
	end
	return result
end

local function adjusted_dump(o)
	local result = dump(o, indent_string)
	if result == "{\n" .. indent_string .. "\n}" then result = "{}" end
	return result
end

-- Left-align or right-align a numeric value by padding it with Figure-width spaces until the string is maxDigits long.
local function pad_figure(value, maxDigits, padLeft)
	local valueStr = tostring(value)
	local padding = string.rep("\u{2007}", maxDigits - valueStr:len())
	if padLeft then
		return padding .. valueStr
	else
		return valueStr .. padding
	end
end

local function describe_param(paramtype, value)

	local upper5bits = math.floor(value / 8)
	local upper4bits = math.floor(value / 16)
	local upper3bits = math.floor(value / 32)
	local lower3bits = value - upper5bits * 8
	local lower4bits = value - upper4bits * 16
	local lower5bits = value - upper3bits * 32

	local prefix = S("storing @1: ", paramtype)

	if paramtype == "none" then
		return ""

	elseif paramtype == "light" then
		-- lua_api.txt says "The value stores light with and without sun in its upper and lower 4 bits respectively", but it
		-- looks to me like it's the other way around, and the lower 4 bits store the "with sun" value.
		return prefix .. S("@1 with sun, @2 without sun", lower4bits, upper4bits)

	elseif paramtype == "flowingliquid" then
		if lower4bits >= 8 then -- Flag 0x08 is "liquid flow down", i.e. there's no node underneath the flowing liquid node
			return prefix .. S("liquid level @1 of 8, with vertical downflow", lower3bits + 1)
		else
			return prefix .. S("liquid level @1 of 8, without vertical downflow", lower3bits + 1)
		end

	elseif paramtype == "degrotate" then
		return prefix .. S("rotation of @1°", value * 2)

	elseif paramtype == "facedir" or paramtype == "colorfacedir" then
		local axisDirection = math.floor(lower5bits / 4)
		local rotation = lower5bits % 4
		local axisDesc = {
			S("up, +Y"),
			S("North, +Z"),
			S("South, -Z"),
			S("East, +X"),
			S("West, -X"),
			S("down, -Y")
		}
		local colorInfo = ""
		if paramtype == "colorfacedir" then
			colorInfo = S(", color @1", upper3bits)
		end
		return prefix .. S("axis-direction @1 (@2), rotation @3 (@4°)", axisDirection, axisDesc[axisDirection + 1], rotation, rotation * 90) .. colorInfo

	elseif paramtype == "wallmounted" or paramtype == "colorwallmounted" then
		local direction = lower3bits
		local axisDesc = {
			S("face down, -Y"),
			S("face up, +Y"),
			S("facing West, -X"),
			S("facing East, +X"),
			S("facing South, -Z"),
			S("facing North, +Z")
		}
		local colorInfo = ""
		if paramtype == "colorwallmounted" then
			colorInfo = S(", color index @1", upper5bits)
		end
		return prefix .. S("direction @1 (@2)", direction, axisDesc[direction + 1]) .. colorInfo

	elseif paramtype == "meshoptions" then
		local shape = lower3bits
		local shapeDesc = {
			"X",
			"\u{253c}",
			"*",
			"#",
			"#",
			S("?unknown?"),
			S("?unknown?"),
			S("?unknown?")
		}
		local result = prefix .. S("@1 shaped", shapeDesc[shape + 1])
		if shape == 4          then result = result .. S(" with faces leaning out") end
		if lower4bits >= 8     then result = result .. S(", horz. variance") end
		if lower5bits >= 16    then result = result .. S(", enlarged 1.4x")  end
		if upper3bits % 2 == 1 then result = result .. S(", vert. variance") end
		return result

	elseif paramtype == "color" then
		return S("storing color index")

	elseif paramtype == "glasslikeliquidlevel" then
		return prefix .. S("liquid level @1 (@2%)", value, math.floor(value * 1000 / 63 + 0.5) / 10)

	end

	return ""
end

local function inspect_pos(pos, light_pos)
	local node    = minetest.get_node(pos)
	local nodedef = minetest.registered_items[node.name]
	local desc = text_header(S("node data")) .. "\n" ..
		indent(1, "name = " .. node.name) .. "\n"
	local param1type = "param1"
	local param2type = "param2"
	if nodedef then
		param1type = nodedef.paramtype
		param2type = nodedef.paramtype2
	end
	desc = desc ..
		indent(1, "param1 = " .. pad_figure(node.param1, 3) .. indent_string ..
		describe_param(param1type,  node.param1)) .. "\n" ..
		indent(1, "param2 = " .. pad_figure(node.param2, 3) .. indent_string ..
		describe_param(param2type, node.param2)) .. "\n"

	if light_pos == nil then
		light_pos = {x = pos.x, y = pos.y + 1, z = pos.z}
	end
	local light_current = minetest.get_node_light(light_pos, nil)
	local light_noon    = minetest.get_node_light(light_pos, 0.5)
	local light_night   = minetest.get_node_light(light_pos, 0)
	if light_current ~= nil then
		desc = desc .. indent(1, "light = " .. pad_figure(light_current, 2)) ..
			"            " .. S("@1 at noon, @2 at night", light_noon, light_night) .. "\n"
	end

	local timer = minetest.get_node_timer(pos)
	if timer:get_timeout() ~= 0 then
		desc = desc .. text_header(S("node timer")) .. "\n" ..
			indent(1, "timeout = " .. timer:get_timeout()) .. "\n" ..
			indent(1, "elapsed = " .. timer:get_elapsed()) .. "\n"
	end

	local meta = minetest.get_meta(pos)
	local metatable = meta:to_table()
	desc = desc .. text_header(S("meta")) .. "\n" ..
		indent(1, "meta.fields = " .. adjusted_dump(metatable.fields)) .. "\n"
	local inventory = meta:get_inventory()
	desc = desc .. indent(1, "meta.inventory = ") .. "\n"
	for key, list in pairs(inventory:get_lists()) do
		desc = desc .. indent(2, key .. " : ") .. "\n"
		local size = #list
		for i = 1, size do
			local stack = list[i]
			if not stack:is_empty() then
				desc = desc .. indent(3, '"' .. stack:get_name() .. '" - ' .. stack:get_count()) .. "\n"
			end
		end
	end

	if nodedef then  -- Some built in nodes have no nodedef

		-- combine nodedef table with its "superclass" table
		local combined_fields = {}
		local nodedef_fields = {}
		for key, value in pairs(getmetatable(nodedef).__index) do
			combined_fields[key] = value
		end
		for key, value in pairs(nodedef) do
			nodedef_fields[key] = true
			if combined_fields[key] == nil then
				combined_fields[key] = value
			end
		end

		-- sort
		local key_list = {}
		for key, _ in pairs(combined_fields) do
			table.insert(key_list, key)
		end
		table.sort(key_list)

		desc = desc .. text_header(S("nodedef")) .. "\n"
		for _, key in ipairs(key_list) do 
			desc = desc .. indent(1, key .. " = " .. adjusted_dump(nodedef[key]), nodedef_fields[key]) .. "\n"
		end
	end

	desc = desc .. "\n" .. text_header(S("location")) .. "\n" ..
		indent(1, "position = " .. minetest.pos_to_string(pos)) .. "\n"
	if minetest.get_biome_data ~= nil and minetest.registered_biomes ~= nil then
		local biomeData = minetest.get_biome_data(pos)

		desc = desc .. indent(1, "heat = "     .. tostring(biomeData.heat))     .."\n" ..
			indent(1, "humidity = " .. tostring(biomeData.humidity)) .. "\n"
		local biomeDescription = S("<none>")
		if biomeData.biome ~= nil then
			local biomeName = minetest.get_biome_name(biomeData.biome)
			biomeDescription = biomeName

			local biomeTable = minetest.registered_biomes[biomeName]
			if biomeTable ~= nil then biomeDescription = biomeDescription .. " " .. adjusted_dump(biomeTable) end
		end
		desc = desc .. indent(1, "biome = " .. biomeDescription) .. "\n"
	end

	return desc
end

minetest.register_tool("inspector:inspector", {
	description = S("Inspector Tool"),
	inventory_image = "inspector.png",
	liquids_pointable = true, -- makes it hard to use underwater.

	on_use = function(itemstack, user, pointed_thing)
		if not minetest.check_player_privs(user, "server") then
			minetest.chat_send_player(user:get_player_name(), S("You don't have permission to run this command (missing privileges: server)"))
			return
		end

		local t = S("Node Information")

		local desc = ""
		if pointed_thing.type == "nothing" then
			return
		elseif pointed_thing.type == "node" then
			local pos = pointed_thing.under

			if pointed_thing.type ~= "node" then
				desc = "..."
			else
				desc = inspect_pos(pos, pointed_thing.above)
			end
		elseif pointed_thing.type == "object" then
			local ref = pointed_thing.ref
			local obj = ref:get_properties()
			if ref.get_physics_override then
				obj.physics_override = ref:get_physics_override()
			end
			desc = adjusted_dump(obj)
			t = S("Entity Information")
		end

		local formspec = "size[12,8]"..
				 "label[0.5,0.5;" .. t .. "]" ..
				 "textarea[0.5,1.5;11.5,7;text;" .. S("Contents:") .. ";" ..
				 minetest.formspec_escape(desc) .. "]" ..
				 "button_exit[2.5,7.5;3,1;close;" .. S("Close") .."]"

		show_formspec(user:get_player_name(), formspec)
	end,
	on_place = function(itemstack, user, pointed_thing)
		if not minetest.check_player_privs(user, "server") then
			minetest.chat_send_player(user:get_player_name(), S("You don't have permission to run this command (missing privileges: server)"))
			return
		end

		local desc = ""
		if pointed_thing.type == "nothing" then
			return
		elseif pointed_thing.type == "node" then
			local pos = pointed_thing.above

			if pointed_thing.type ~= "node" then
				desc = "..."
			else
				desc = inspect_pos(pos, pos)
			end
		elseif pointed_thing.type == "object" then
			local ref = pointed_thing.ref
			local entity = ref:get_luaentity()
			desc = dump(entity)
		end

		local formspec = "size[12,8]"..
				 "label[0.5,0.5;" .. S("Node Information") .. "]" ..
				 "textarea[0.5,1.5;11.5,7;text;" .. S("Contents:") .. ";" ..
				 minetest.formspec_escape(desc) .. "]" ..
				 "button_exit[2.5,7.5;3,1;close;" .. S("Close") .. "]"

		show_formspec(user:get_player_name(), formspec)
	end
})

minetest.register_chatcommand("inspect", {
	params = "inspect",
	description = S("inspect a pos"),
	privs = {server = true},
	func = function(name, param)
		local paramlist = {}
		for p in string.gmatch(param, "%S+") do
			paramlist[#paramlist + 1] = p
		end
		local pos = {x = paramlist[1], y = paramlist[2], z = paramlist[3]}
		if not pos.x or not pos.y or not pos.z then
			return false, "Need 3 parameters for X, Y and Z"
		end
		local desc = inspect_pos(pos)
		local formspec = "size[12,8]" ..
							 "label[0.5,0.5;Node Information]" ..
							 "textarea[0.5,1.5;11.5,7;text;" .. S("Contents:") .. ";" ..
							 minetest.formspec_escape(desc) .. "]" ..
							 "button_exit[2.5,7.5;3,1;close;" .. S("Close") .. "]"

		show_formspec(name, formspec)
		return true
	end,
})

local function inspect_item(itemstack)
	local desc = text_header(S("count")) .. "\n" ..
		indent(1, "count = " .. itemstack:get_count()) .. "\n"

	local meta = itemstack:get_meta()
	local metatable = meta:to_table()
	desc = desc .. text_header(S("meta")) .. "\n" ..
		indent(1, "meta.fields = " .. adjusted_dump(metatable.fields)) .. "\n"
	
	local itemdef = itemstack:get_definition()
	-- combine itemdef table with its "superclass" table
	local combined_fields = {}
	local nodedef_fields = {}
	for key, value in pairs(getmetatable(itemdef).__index) do
		combined_fields[key] = value
	end
	for key, value in pairs(itemdef) do
		nodedef_fields[key] = true
		if combined_fields[key] == nil then
			combined_fields[key] = value
		end
	end

	-- sort
	local key_list = {}
	for key, _ in pairs(combined_fields) do
		table.insert(key_list, key)
	end
	table.sort(key_list)

	desc = desc .. text_header(S("itemdef")) .. "\n"
	for _, key in ipairs(key_list) do 
		desc = desc .. indent(1, key .. " = " .. adjusted_dump(itemdef[key]), nodedef_fields[key]) .. "\n"
	end
	return desc
end

local function make_item_fs(player_name, title, desc)
	title = title or ""
	desc = desc or ""

	return "size[12,11]"
		.. "label[0.2,0.2;"..title.."]"
		.. "textlist[0.2,1.0;11.5,6;;"
		.. minetest.formspec_escape(desc):gsub("\n", ",").."]"
		.. "list[detached:inspector_"..player_name..";item;10.75,7.25;1,1;]"
		.. "list[current_player;main;2,7.25;8,4;]"
		.. "listring[]"
		.. "button_exit[11.1,0.2;0.8,0.8;close;x]"
end

minetest.register_on_joinplayer(function(player)
	local player_name = player:get_player_name()
	local inv = minetest.create_detached_inventory("inspector_"..player_name, {
		allow_put = function(inv, listname, index, stack, inv_player)
			local inv_player_name = inv_player:get_player_name()
			local desc = inspect_item(stack)
			local formspec = make_item_fs(inv_player_name, stack:get_name(), desc)
			show_formspec(inv_player_name, formspec)
			return 0
		end,
	})
	inv:set_size("item", 1)
end)

minetest.register_on_leaveplayer(function(player, timed_out)
	local player_name = player:get_player_name()
	minetest.remove_detached_inventory("inspector_"..player_name)
end)

minetest.register_chatcommand("inspect_item", {
	description = S("inspect an item"),
	privs = {server = true},
	func = function(name, param)
		local formspec = make_item_fs(name)
		show_formspec(name, formspec)
		return true
	end,
})
