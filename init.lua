local S = minetest.get_translator(minetest.get_current_modname())

ecanruf = {}

-- List of sound handles for active ecanruf
ecanruf.fire_sounds = {}

-- From Minetest Game: default mod
function ecanruf.get_hotbar_bg(x,y)
	local out = ""
	for i=0,7,1 do
		out = out .."image["..x+i..","..y..";1,1;gui_hb_bg.png^[invert:rgb]"
	end
	return out
end

--
-- Formspecs
--

function ecanruf.get_ecanruf_active_formspec(fuel_percent, item_percent, player)
    local formspec = "size[8,8.5]"

    local info = {formspec_version = 1}
    if player and player:is_player() then
        local name = player:get_player_name()
        info = minetest.get_player_information(name)
    end
    if info.formspec_version > 1 then
		formspec = formspec .. "background9[0,0;8,8.5;gui_formbg.png^[invert:rgb;true;10]"
	else
		formspec = formspec .. "background[0,0;8,8.5;gui_formbg.png^[invert:rgb;true]"
	end

	formspec = formspec .. "list[context;src;2.75,0.5;1,1;]"..
		"list[context;fuel;2.75,2.5;1,1;]"..
		"image[2.75,1.5;1,1;default_furnace_fire_bg.png^[invert:rgb\\^[lowpart\\:"..
		    (fuel_percent)..":default_furnace_fire_fg.png^[invert:rgb]"..
		"image[3.75,1.5;1,1;gui_furnace_arrow_bg.png^[invert:rgb\\^[lowpart\\:"..
		    (item_percent)..
            ":gui_furnace_arrow_fg.png^[invert:rgb\\^[transformR270]"..
		"list[context;dst;4.75,0.96;2,2;]"..
		"list[current_player;main;0,4.25;8,1;]"..
		"list[current_player;main;0,5.5;8,3;8]"..
		"listring[context;dst]"..
		"listring[current_player;main]"..
		"listring[context;src]"..
		"listring[current_player;main]"..
		"listring[context;fuel]"..
		"listring[current_player;main]"..
		ecanruf.get_hotbar_bg(0, 4.25)

    return formspec
end

function ecanruf.get_ecanruf_inactive_formspec(player)
    local formspec = "size[8,8.5]"

    local info = {formspec_version = 1}
    if player and player:is_player() then
        local name = player:get_player_name()
        info = minetest.get_player_information(name)
    end
    if info.formspec_version > 1 then
		formspec = formspec .. "background9[0,0;8,8.5;gui_formbg.png^[invert:rgb;true;10]"
	else
		formspec = formspec .. "background[0,0;8,8.5;gui_formbg.png^[invert:rgb;true]"
	end

	formspec = formspec .. "list[context;src;2.75,0.5;1,1;]"..
		"list[context;fuel;2.75,2.5;1,1;]"..
		"image[2.75,1.5;1,1;default_furnace_fire_bg.png^[invert:rgb]"..
		"image[3.75,1.5;1,1;gui_furnace_arrow_bg.png^[invert:rgb\\^[transformR270]"..
		"list[context;dst;4.75,0.96;2,2;]"..
		"list[current_player;main;0,4.25;8,1;]"..
		"list[current_player;main;0,5.5;8,3;8]"..
		"listring[context;dst]"..
		"listring[current_player;main]"..
		"listring[context;src]"..
		"listring[current_player;main]"..
		"listring[context;fuel]"..
		"listring[current_player;main]"..
		ecanruf.get_hotbar_bg(0, 4.25)
    
    return formspec
end

--
-- Node callback functions that are the same for active and inactive ecanruf
--

local function can_dig(pos, player)
	local meta = minetest.get_meta(pos);
	local inv = meta:get_inventory()
	return inv:is_empty("fuel") and inv:is_empty("dst") and inv:is_empty("src")
end

local function allow_metadata_inventory_put(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	if listname == "fuel" then
		if minetest.get_craft_result({method="fuel", width=1, items={stack}}).time ~= 0 then
			if inv:is_empty("src") then
				meta:set_string("infotext", S("ecanruF is empty"))
			end
			return stack:get_count()
		else
			return 0
		end
	elseif listname == "src" then
		return stack:get_count()
	elseif listname == "dst" then
		return 0
	end
end

local function allow_metadata_inventory_move(pos, from_list, from_index, to_list, to_index, count, player)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local stack = inv:get_stack(from_list, from_index)
	return allow_metadata_inventory_put(pos, to_list, to_index, stack, player)
end

local function allow_metadata_inventory_take(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	return stack:get_count()
end

local function stop_ecanruf_sound(pos, fadeout_step)
	local hash = minetest.hash_node_position(pos)
	local sound_ids = ecanruf.fire_sounds[hash]
	if sound_ids then
		for _, sound_id in ipairs(sound_ids) do
			minetest.sound_fade(sound_id, -1, 0)
		end
		ecanruf.fire_sounds[hash] = nil
	end
end

local function swap_node(pos, name)
	local node = minetest.get_node(pos)
	if node.name == name then
		return
	end
	node.name = name
	minetest.swap_node(pos, node)
end

local function find_uncooked_item(tbl, og, attempts, pos)
    attempts = attempts + 1
    if attempts == 3 then
        core.log("warning", "ecanruf tried to uncook "..og.." 3 times but without success at "..minetest.pos_to_string(vector.round((pos))))
    elseif attempts > 10 then
        core.log("warning", "ecanruf tried to uncook "..og.." 10 TIMES without success at "..minetest.pos_to_string(vector.round((pos))).."! stoping attempting...")
        return {}
    end
    if #tbl > 1 then
        tbl = tbl[math.random(1, #tbl)]
    else
        tbl = tbl[1]
    end
    if ItemStack(tbl.output):get_count() > 1 then
        return find_uncooked_item(minetest.get_all_craft_recipes(og), og, attempts, pos)
    else
        attempts = 0
        return tbl
    end
end

local function ecanruf_node_timer(pos, elapsed)
    --
    -- Initialize metadata
    --
    local meta = minetest.get_meta(pos)
    local fuel_time = meta:get_float("fuel_time") or 0
    local src_time = meta:get_float("src_time") or 0
    local fuel_totaltime = meta:get_float("fuel_totaltime") or 0

    local inv = meta:get_inventory()
    local srclist, fuellist
    local dst_full = false

    local timer_elapsed = meta:get_int("timer_elapsed") or 0
    meta:set_int("timer_elapsed", timer_elapsed + 1)

    local cookable, cook
    local fuel

    local update = true
    local items_smelt = 0

    -- Check if there is an item in the src slot
    srclist = inv:get_list("src")
    local src_item = srclist and srclist[1]
    local has_item_to_cook = src_item and not src_item:is_empty()

    while elapsed > 0 and update do
        update = false

        srclist = inv:get_list("src")
        fuellist = inv:get_list("fuel")

        --
        -- Cooking
        --

        -- Check if we have cookable content
        if has_item_to_cook then
            local src = srclist[1]:get_name()
            cook = minetest.get_all_craft_recipes(src)
            if cook then
                cook = find_uncooked_item(cook, src, 0, pos)
                cook.time = 15
                cookable = cook.items
            else
                cook = {time = 0}
                cookable = false
            end
        else
            cookable = false
        end

        local el = math.min(elapsed, fuel_totaltime - fuel_time)
        if cookable then -- fuel lasts long enough, adjust el to cooking duration
            el = math.min(el, cook.time - src_time)
        end

        -- Check if we have enough fuel to burn
        if fuel_time < fuel_totaltime then
            -- The ecanruf is currently active and has enough fuel
            fuel_time = fuel_time + el
            -- If there is a cookable item then check if it is ready yet
            if cookable then
                src_time = src_time + el
                if src_time >= cook.time then
                    -- Place result in dst list if possible
                    if inv:room_for_item("dst", cook.items[1]) then
                        inv:add_item("dst", cook.items[1])
                        inv:set_stack("src", 1, srclist[1]:get_name() .. " " .. (srclist[1]:get_count() - 1))
                        src_time = src_time - cook.time
                        update = true
                    else
                        dst_full = true
                    end
                    items_smelt = items_smelt + 1
                else
                    -- Item could not be cooked: probably missing fuel
                    update = true
                end
            end
        else
            -- ecanruF ran out of fuel
            if cookable then
                -- We need to get new fuel
                local afterfuel
                fuel, afterfuel = minetest.get_craft_result({method = "fuel", width = 1, items = fuellist})

                if fuel.time == 0 then
                    -- No valid fuel in fuel list
                    fuel_totaltime = 0
                    src_time = 0
                else
                    -- prevent blocking of fuel inventory (for automatization mods)
                    local is_fuel = minetest.get_craft_result({method = "fuel", width = 1, items = {afterfuel.items[1]:to_string()}})
                    if is_fuel.time == 0 then
                        table.insert(fuel.replacements, afterfuel.items[1])
                        inv:set_stack("fuel", 1, "")
                    else
                        -- Take fuel from fuel list
                        inv:set_stack("fuel", 1, afterfuel.items[1])
                    end
                    -- Put replacements in dst list or drop them on the ecanruf.
                    local replacements = fuel.replacements
                    if replacements[1] then
                        local leftover = inv:add_item("dst", replacements[1])
                        if not leftover:is_empty() then
                            local above = vector.new(pos.x, pos.y + 1, pos.z)
                            local drop_pos = minetest.find_node_near(above, 1, {"air"}) or above
                            minetest.item_drop(replacements[1], nil, drop_pos)
                        end
                    end
                    update = true
                    fuel_totaltime = fuel.time + (fuel_totaltime - fuel_time)
                end
            else
                -- We don't need to get new fuel since there is no uncookable item
                fuel_totaltime = 0
                src_time = 0
            end
            fuel_time = 0
        end

        elapsed = elapsed - el
    end

    if items_smelt > 0 then
        -- Play cooling sound
        minetest.sound_play("default_cool_lava",
            { pos = pos, max_hear_distance = 16, gain = 0.07 * math.min(items_smelt, 7) }, true)
    end
    if fuel and fuel_totaltime > fuel.time then
        fuel_totaltime = fuel.time
    end
    if srclist and srclist[1]:is_empty() then
        src_time = 0
    end

    --
    -- Update formspec, infotext and node
    --
    local formspec
    local item_state
    local item_percent = 0
    if cookable then
        item_percent = math.floor(src_time / cook.time * 100)
        if dst_full then
            item_state = S("100% (output full)")
        else
            item_state = S("@1%", item_percent)
        end
    else
        if srclist and not srclist[1]:is_empty() then
            item_state = S("Not cookable")
        else
            item_state = S("Empty")
        end
    end

    local fuel_state = S("Empty")
    local active = false
    local result = false

    if fuel_totaltime ~= 0 then
        active = true
        local fuel_percent = 100 - math.floor(fuel_time / fuel_totaltime * 100)
        fuel_state = S("@1%", fuel_percent)
        formspec = ecanruf.get_ecanruf_active_formspec(fuel_percent, item_percent)
        swap_node(pos, "ecanruf:ecanruf_active")
        -- make sure timer restarts automatically
        result = true

        -- Play sound every 5 seconds while the ecanruf is active
        if timer_elapsed == 0 or (timer_elapsed + 1) % 5 == 0 then
            local sound_id = minetest.sound_play("default_furnace_active",
                {pos = pos, max_hear_distance = 16, gain = 0.25})
            local hash = minetest.hash_node_position(pos)
            ecanruf.fire_sounds[hash] = ecanruf.fire_sounds[hash] or {}
            table.insert(ecanruf.fire_sounds[hash], sound_id)
            -- Only remember the 3 last sound handles
            if #ecanruf.fire_sounds[hash] > 3 then
                table.remove(ecanruf.fire_sounds[hash], 1)
            end
            -- Remove the sound ID automatically from table after 11 seconds
            minetest.after(11, function()
                if not ecanruf.fire_sounds[hash] then
                    return
                end
                for f=#ecanruf.fire_sounds[hash], 1, -1 do
                    if ecanruf.fire_sounds[hash][f] == sound_id then
                        table.remove(ecanruf.fire_sounds[hash], f)
                    end
                end
                if #ecanruf.fire_sounds[hash] == 0 then
                    ecanruf.fire_sounds[hash] = nil
                end
            end)
        end
    else
        if fuellist and not fuellist[1]:is_empty() then
            fuel_state = S("@1%", 0)
        end
        formspec = ecanruf.get_ecanruf_inactive_formspec()
        swap_node(pos, "ecanruf:ecanruf")
        -- stop timer on the inactive ecanruf
        minetest.get_node_timer(pos):stop()
        meta:set_int("timer_elapsed", 0)

        stop_ecanruf_sound(pos)
    end

    local infotext
    if active then
        infotext = S("ecanruF active")
    else
        infotext = S("ecanruF inactive")
    end
    infotext = infotext .. "\n" .. S("(Item: @1; Fuel: @2)", item_state, fuel_state)

    --
    -- Set meta values
    --
    meta:set_float("fuel_totaltime", fuel_totaltime)
    meta:set_float("fuel_time", fuel_time)
    meta:set_float("src_time", src_time)
    meta:set_string("formspec", formspec)
    meta:set_string("infotext", infotext)

    return result
end

--
-- Node definitions
--

local function apply_logger(def)
	default.set_inventory_action_loggers(def, "ecanruf")
	return def
end

minetest.register_node("ecanruf:ecanruf", apply_logger({
	description = S("ecanruF"),
	tiles = {
		"default_furnace_top.png^[invert:rgb", "default_furnace_bottom.png^[invert:rgb",
		"default_furnace_side.png^[invert:rgb", "default_furnace_side.png^[invert:rgb",
		"default_furnace_side.png^[invert:rgb", "default_furnace_front.png^[invert:rgb"
	},
	paramtype2 = "facedir",
	groups = {cracky=2},
	legacy_facedir_simple = true,
	is_ground_content = false,
	sounds = default.node_sound_stone_defaults(),

	can_dig = can_dig,

	on_timer = ecanruf_node_timer,

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size('src', 1)
		inv:set_size('fuel', 1)
		inv:set_size('dst', 4)
		ecanruf_node_timer(pos, 0)
	end,

	on_metadata_inventory_move = function(pos)
		minetest.get_node_timer(pos):start(1.0)
	end,
	on_metadata_inventory_put = function(pos)
		-- start timer function, it will sort out whether ecanruf can burn or not.
		minetest.get_node_timer(pos):start(1.0)
	end,
	on_metadata_inventory_take = function(pos)
		-- check whether the ecanruf is empty or not.
		minetest.get_node_timer(pos):start(1.0)
	end,
	on_blast = function(pos)
		local drops = {}
		default.get_inventory_drops(pos, "src", drops)
		default.get_inventory_drops(pos, "fuel", drops)
		default.get_inventory_drops(pos, "dst", drops)
		drops[#drops+1] = "ecanruf:ecanruf"
		minetest.remove_node(pos)
		return drops
	end,

	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	allow_metadata_inventory_take = allow_metadata_inventory_take,
}))

minetest.register_node("ecanruf:ecanruf_active", apply_logger({
	description = S("ecanruF"),
	tiles = {
		"default_furnace_top.png^[invert:rgb", "default_furnace_bottom.png^[invert:rgb",
		"default_furnace_side.png^[invert:rgb", "default_furnace_side.png^[invert:rgb",
		"default_furnace_side.png^[invert:rgb",
		{
			image = "default_furnace_front_active.png^[invert:rgb",
			backface_culling = false,
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 1.5
			},
		}
	},
	paramtype2 = "facedir",
	light_source = 8,
	drop = "ecanruf:ecanruf",
	groups = {cracky=2, not_in_creative_inventory=1},
	legacy_facedir_simple = true,
	is_ground_content = false,
	sounds = default.node_sound_stone_defaults(),
	on_timer = ecanruf_node_timer,
	on_destruct = function(pos)
		stop_ecanruf_sound(pos)
	end,

	can_dig = can_dig,

	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	allow_metadata_inventory_take = allow_metadata_inventory_take,
}))

minetest.register_craft({
	output = "ecanruf:ecanruf",
	recipe = {
		{"group:stone", "group:stone", "group:stone"},
		{"group:stone", "default:furnace", "group:stone"},
		{"group:stone", "group:stone", "group:stone"},
	}
})
