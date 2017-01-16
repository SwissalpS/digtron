minetest.register_craft({
	output = "digtron:empty_crate",
	recipe = {
			{"","default:chest",""},
			{"","digtron:digtron_core",""},
			{"","default:mese_crystal",""}
			}
})

minetest.register_node("digtron:empty_crate", {
	description = "Empty Digtron Crate",
	groups = {cracky = 3, oddly_breakable_by_hand=3},
	drop = "digtron:empty_crate",
	sounds = default.node_sound_wood_defaults(),
	tiles = {"digtron_crate.png"},
	is_ground_content = false,
	drawtype = "nodebox",
	paramtype = "light",
	
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		local layout = DigtronLayout.create(pos, clicker)
		if layout.contains_protected_node then
			local meta = minetest.get_meta(pos)
			minetest.sound_play("buzzer", {gain=0.5, pos=pos})
			meta:set_string("infotext", "Digtron can't be packaged, it contains protected nodes")
			-- no stealing other peoples' digtrons
			return
		end

		local layout_string = layout:serialize()
		
		-- destroy everything. Note that this includes the empty crate, which will be bundled up with the layout.
		for _, node_image in pairs(layout.all) do
			minetest.remove_node(node_image.pos)
		end
		
		-- Create the loaded crate node
		minetest.set_node(pos, {name="digtron:loaded_crate", param1=node.param1, param2=node.param2})
		
		local meta = minetest.get_meta(pos)
		meta:set_string("crated_layout", layout_string)
		meta:set_string("title", "Crated Digtron")
		meta:set_string("infotext", "Crated Digtron")
	end,
})

local loaded_formspec =  "size[4,1.5]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"field[0.3,0.5;4,0.5;title;Digtron Name;${title}]" ..
	"button_exit[0.5,1.2;1,0.1;save;Save Title]" ..
	"tooltip[save;Saves the title of this Digtron]" ..
	"button_exit[2.5,1.2;1,0.1;unpack;Unpack]" ..
	"tooltip[unpack;Attempts to unpack the Digtron on this location]"

minetest.register_node("digtron:loaded_crate", {
	description = "Loaded Digtron Crate",
	groups = {cracky = 3, oddly_breakable_by_hand=3, not_in_creative_inventory=1, digtron=1},
	stack_max = 1,
	sounds = default.node_sound_wood_defaults(),
	tiles = {"digtron_plate.png^digtron_crate.png"},
	is_ground_content = false,
	
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", loaded_formspec)
	end,
	
	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.get_meta(pos)
		
		if fields.unpack or fields.save then
			meta:set_string("title", fields.title)
			meta:set_string("infotext", fields.title)
		end
		
		if not fields.unpack then
			return
		end
		
		local layout_string = meta:get_string("crated_layout")
		local layout = DigtronLayout.deserialize(layout_string)
		
		if layout == nil then
			meta:set_string("infotext", meta:get_string("title") .. "\nUnable to read layout from crate metadata, regrettably this Digtron may be corrupted or lost.")
			minetest.sound_play("buzzer", {gain=0.5, pos=pos})			
			-- Something went horribly wrong
			return
		end
		
		local pos_diff = vector.subtract(pos, layout.controller)
		layout.controller = pos
		for _, node_image in pairs(layout.all) do
			node_image.pos = vector.add(pos_diff, node_image.pos)
			
			if minetest.is_protected(node_image.pos, sender:get_player_name()) and not minetest.check_player_privs(sender, "protection_bypass") then
				meta:set_string("infotext", meta:get_string("title") .. "\nUnable to deploy Digtron due to protected nodes in target area")
				minetest.sound_play("buzzer", {gain=0.5, pos=pos})
				return
			end
			
			if not minetest.registered_nodes[minetest.get_node(node_image.pos).name].buildable_to
			  and not vector.equals(layout.controller, node_image.pos) then
				meta:set_string("infotext", meta:get_string("title") .. "\nUnable to deploy Digtron due to obstruction in target area")
				minetest.sound_play("buzzer", {gain=0.5, pos=pos})
				return
			end
		end
		
		-- build digtron. Since the empty crate was included in the layout, that will overwrite this loaded crate and destroy it.
		if layout then
			layout:write_layout_image(sender)
		end
	end,
		
	on_dig = function(pos, node, player)
	
		local meta = minetest.get_meta(pos)
		local to_serialize = {title=meta:get_string("title"), layout=meta:get_string("crated_layout")}
		
		local stack = ItemStack({name="digtron:loaded_crate", count=1, wear=0, metadata=minetest.serialize(to_serialize)})
		local inv = player:get_inventory()
		local stack = inv:add_item("main", stack)
		if stack:get_count() > 0 then
			minetest.add_item(pos, stack)
		end		
		-- call on_dignodes callback
		minetest.remove_node(pos)
	end,
	
	on_place = function(itemstack, placer, pointed_thing)
		local pos = minetest.get_pointed_thing_position(pointed_thing, true)
		local deserialized = minetest.deserialize(itemstack:get_metadata())
		if pos and deserialized then
			minetest.set_node(pos, {name="digtron:loaded_crate"})
			local meta = minetest.get_meta(pos)
			
			meta:set_string("crated_layout", deserialized.layout)
			meta:set_string("title", deserialized.title)
			meta:set_string("infotext", deserialized.title)
			meta:set_string("formspec", loaded_formspec)
			
			itemstack:take_item(1)
			return itemstack
		end
		-- after-place callbacks
	end,
})