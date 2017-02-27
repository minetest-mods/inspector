
--[[

Copyright (C) 2015 - Auke Kok <sofar@foo-projects.org>

"inspector" is free software; you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as
published by the Free Software Foundation; either version 2.1
of the license, or (at your option) any later version.

--]]

local function inspect_pos(pos)
	local node = minetest.get_node(pos)
	local desc = "===== node data =====\n"
	desc = desc .. "name = " .. node.name .. "\n"
	desc = desc .. "param1 = " .. node.param1 .. "\n"
	desc = desc .. "param2 = " .. node.param2 .. "\n"
	local light = minetest.get_node_light({x = pos.x, y = pos.y + 1, z = pos.x}, nil)
	if light then
		desc = desc .. "light = " .. light .. "\n"
	end

	local timer = minetest.get_node_timer(pos)
	if timer:get_timeout() ~= 0 then
	desc = desc .. "==== node timer ====\n"
	desc = desc .. "timeout = " .. timer:get_timeout() .. "\n"
	desc = desc .. "elapsed = " .. timer:get_elapsed() .. "\n"
	end

	local nodedef = minetest.registered_items[node.name]
	if nodedef then  -- Some built in nodes have no nodedef
		desc = desc .. "==== nodedef ====\n"
		desc = desc .. dump(nodedef) .. "\n"
	end
	local meta = minetest.get_meta(pos)
	local table = meta:to_table()
	local fields = minetest.serialize(table.fields)
	desc = desc .. "==== meta ====\n"
	desc = desc .. "meta.fields = " .. fields .. "\n"
	desc = desc .. "\n"
	local inventory = meta:get_inventory()
	desc = desc .. "meta.inventory = \n"
	for key, list in pairs(inventory:get_lists()) do
		desc = desc .. key .. " : \n"
		local size = #list
		for i = 1, size do
			local stack = list[i]
			if not stack:is_empty() then
				desc = desc .. "\"" .. stack:get_name() .. "\" - " .. stack:get_count() .. "\n"
			end
		end
	end

	return minetest.formspec_escape(desc)
end

minetest.register_tool("inspector:inspector", {
	description = "Inspector Tool",
	inventory_image = "inspector.png",
	liquids_pointable = true, -- makes it hard to use underwater.

	on_use = function(itemstack, user, pointed_thing)

		local desc = ""
		if pointed_thing.type == "nothing" then
			return
		elseif pointed_thing.type == "node" then

			local pll = user:get_player_name()
			local pos = pointed_thing.under

			if pointed_thing.type ~= "node" then
				desc = "..."
			else
				desc = inspect_pos(pos)
			end

		elseif pointed_thing.type == "object" then

			local ref = pointed_thing.ref
			local entity = ref:get_luaentity()
			desc = dump(entity)

		end

		local formspec = "size[12,8]"..
							 "label[0.5,0.5;Node Information]"..
							 "textarea[0.5,1.5;11.5,7;text;Contents:;"..
							 minetest.formspec_escape(desc).."]"..
							 "button_exit[2.5,7.5;3,1;close;Close]"

		minetest.show_formspec(user:get_player_name(), "inspector:inspector", formspec)
	end,
})

minetest.register_chatcommand("inspect", {
	params = "inspect",
	description = "inspect a pos",
	privs = {server = true},
	func = function(name, param)
		local paramlist = string.split(param, " ")
		local pos = {x = paramlist[1], y = paramlist[2], z = paramlist[3]}
		local desc = inspect_pos(pos)
		local formspec = "size[12,8]"..
							 "label[0.5,0.5;Node Information]"..
							 "textarea[0.5,1.5;11.5,7;text;Contents:;"..
							 minetest.formspec_escape(desc).."]"..
							 "button_exit[2.5,7.5;3,1;close;Close]"

		minetest.show_formspec(name, "inspector:inspector", formspec)
		return true
	end,
})
