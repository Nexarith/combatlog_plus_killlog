local combat_time = 30

local combat_players = {}

local hud_ids = {}

-- shared external systems (safe fallback)
local last_hitter = rawget(_G, "last_hitter") or {}
local add_kill = rawget(_G, "add_kill")

----------------------------------------------------
-- GLOBAL COMBAT API (for other mods)
----------------------------------------------------

function minetest.is_player_in_combat(name)
    return in_combat(name)
end

----------------------------------------------------
-- COMBAT CHECK (GLOBAL SAFE)
----------------------------------------------------

function in_combat(name)
    local t = combat_players[name]
    if not t then return false end

    if os.time() >= t then
        combat_players[name] = nil
        return false
    end
    return true
end

----------------------------------------------------
-- START COMBAT
----------------------------------------------------

local function start_combat(player)
    local name = player:get_player_name()
    combat_players[name] = os.time() + combat_time

    if not hud_ids[name] then
        hud_ids[name] = player:hud_add({
            hud_elem_type = "text",
            position = {x = .94, y = .22},
            text = "Combat",
            number = 0xFF0000,
            alignment = {x = 0, y = 0},
            scale = {x = .65, y = 2},
        })
    end
end

----------------------------------------------------
-- HUD UPDATER
----------------------------------------------------

minetest.register_globalstep(function()
    for name, end_time in pairs(combat_players) do
        local player = minetest.get_player_by_name(name)
        if not player then
            combat_players[name] = nil
            hud_ids[name] = nil
            goto continue
        end

        local remaining = end_time - os.time()
        if remaining <= 0 then
            combat_players[name] = nil
            if hud_ids[name] then
                player:hud_remove(hud_ids[name])
                hud_ids[name] = nil
            end
            minetest.chat_send_player(name, "You are no longer in combat.")
        else
            if hud_ids[name] then
                player:hud_change(
                    hud_ids[name],
                    "text",
                    "Combat: " .. remaining .. "s"
                )
            end
        end
        ::continue::
    end
end)

----------------------------------------------------
-- PVP TRIGGER
----------------------------------------------------

minetest.register_on_punchplayer(function(player, hitter)
    if hitter and hitter:is_player() then
        start_combat(player)
        start_combat(hitter)
    end
end)

----------------------------------------------------
-- DROP SYSTEM
----------------------------------------------------

local function drop_all(player)
    local name = player:get_player_name()
    local pos = player:get_pos()
    pos.y = math.floor(pos.y + 0.5)

    -- teleport fallback if too low
    if pos.y < 40 then
        local spawns = {
            {x = -81, y = 176, z = 4},
            {x = -5,  y = 174, z = 1},
            {x = 48,  y = 174, z = 59},
            {x = 57,  y = 174, z = 21},
        }
        pos = spawns[math.random(#spawns)]
    end

    local inv = player:get_inventory()

    -- main inventory drop
    for i = 1, inv:get_size("main") do
        local stack = inv:get_stack("main", i)
        if not stack:is_empty() then
            minetest.add_item(pos, stack)
        end
    end
    inv:set_list("main", {})

    -- 3d armor support
    if minetest.get_modpath("3d_armor") then
        local armor_inv = minetest.get_inventory({
            type = "detached",
            name = name .. "_armor"
        })
        if armor_inv then
            local list = armor_inv:get_list("armor") or {}
            for _, stack in ipairs(list) do
                if not stack:is_empty() then
                    minetest.add_item(pos, stack)
                end
            end
            armor_inv:set_list("armor", {})
        end
        if armor and armor.set_player_armor then
            armor:set_player_armor(player)
        end
    end
end

----------------------------------------------------
-- DEATH HANDLER
----------------------------------------------------

minetest.register_on_dieplayer(function(player)
    local meta = player:get_meta()
    if meta:get_string("void_kill") == "true" then
        meta:set_string("void_kill", "")
        return
    end
    drop_all(player)
    meta:set_string("combat_logged", "")
end)

----------------------------------------------------
-- COMBAT LOG PENALTY
----------------------------------------------------

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    if in_combat(name) then
        drop_all(player)
        local data = last_hitter[name]
        if data and data.name and data.name ~= name and add_kill then
            add_kill(
                data.name,
                name,
                data.weapon or "default:hand",
                "combat_log"
            )
        elseif add_kill then
            add_kill(name, name, "suicide.png", "combat_log")
        end
        last_hitter[name] = nil
        minetest.chat_send_all(
            "-!- " .. name .. " combat logged and got clapped."
        )
        player:get_meta():set_string("combat_logged", "true")
    end
end)

----------------------------------------------------
-- ANTI-GHOST WIPE ON REJOIN
----------------------------------------------------

minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    local meta = player:get_meta()
    if meta:get_string("combat_logged") == "true" then
        minetest.after(0.2, function()
            local p = minetest.get_player_by_name(name)
            if not p then return end
            local inv = p:get_inventory()
            inv:set_list("main", {})
            if minetest.get_modpath("3d_armor") then
                local armor_inv = minetest.get_inventory({
                    type = "detached",
                    name = name .. "_armor"
                })
                if armor_inv then
                    armor_inv:set_list("armor", {})
                end
                if armor and armor.set_player_armor then
                    armor:set_player_armor(p)
                end
            end
            meta:set_string("combat_logged", "")
            minetest.chat_send_player(name, "Your inventory was wiped for combat logging!")
        end)
    end
end)
