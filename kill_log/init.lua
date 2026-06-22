local last_hitter = {}

_G.last_hitter = last_hitter -- share with other mods

local kill_feed = {}

local player_settings = {}

local huds = {}

local last_pos = {}

local last_hp = {}

local MAX_HUD_KILLS = 6

local total_kills = 0

---------------------------------------------------
-- NAME SHORTENER
---------------------------------------------------

local function short_name(name)

    if not name then
        return "?"
    end

    if #name > 12 then
        return name:sub(1, 10) .. ".."
    end

    return name
end

---------------------------------------------------
-- TRACK HITS
---------------------------------------------------

minetest.register_on_punchplayer(function(player, hitter)

    if hitter and hitter:is_player() then

        last_hitter[player:get_player_name()] = {

            name = hitter:get_player_name(),

            weapon = hitter:get_wielded_item():get_name(),

            time = os.time()

        }

    end

end)

---------------------------------------------------
-- TRACK MOVEMENT + HP
---------------------------------------------------

minetest.register_globalstep(function()

    for _, player in ipairs(minetest.get_connected_players()) do

        local name = player:get_player_name()

        last_pos[name] = player:get_pos()

        last_hp[name] = player:get_hp()

    end

end)

---------------------------------------------------
-- ADD KILL
---------------------------------------------------

local function add_kill(killer, victim, weapon, death_type)

    total_kills = total_kills + 1

    table.insert(kill_feed, 1, {

        id = total_kills,

        killer = killer,

        victim = victim,

        weapon = weapon,

        type = death_type or "kill",

        time = os.time()

    })

    update_hud_all()

end

_G.add_kill = add_kill

---------------------------------------------------
-- GET TEXTURE
---------------------------------------------------

local function get_texture(itemname)

    if itemname == "suicide.png" then

        return "suicide.png"

    end

    local def = minetest.registered_items[itemname]

    local texture = ""

    if def then

        texture = def.inventory_image or def.wield_image or ""

    end

    if texture == "" then

        texture = "punch.png"

    end

    return texture:match("([^%^]+)")

end

---------------------------------------------------
-- CREATE HUD
---------------------------------------------------

local function create_hud(player)

    local name = player:get_player_name()

    huds[name] = {}

    local y = 0.70

    for i = 1, MAX_HUD_KILLS do

        local killer_id = player:hud_add({

            hud_elem_type = "text",

            position = {x = 0.08, y = y},

            text = "",

            number = 0xFFFFFF

        })

        local img_id = player:hud_add({

            hud_elem_type = "image",

            position = {x = 0.14, y = y},

            text = "punch.png",

            scale = {x = 1, y = 1}

        })

        local victim_id = player:hud_add({

            hud_elem_type = "text",

            position = {x = 0.20, y = y},

            text = "",

            number = 0xFFFFFF

        })

        huds[name][i] = {

            killer = killer_id,

            image = img_id,

            victim = victim_id

        }

        y = y + 0.05

    end

end

---------------------------------------------------
-- UPDATE HUD
---------------------------------------------------

local function update_hud(player)

    local name = player:get_player_name()

    if not player_settings[name] or not huds[name] then return end

    for i = 1, MAX_HUD_KILLS do

        local entry = kill_feed[i]

        local slot = huds[name][i]

        if entry then

            local texture = get_texture(entry.weapon)

            local left_text = short_name(entry.killer)

            local right_text = ""

            if entry.type == "suicide" then

                right_text = "(suicided)"

            elseif entry.type == "combat_log" then

                right_text = short_name(entry.victim) .. " (combat log)"

            elseif entry.type:find("assist_") then

                right_text =
                    short_name(entry.victim)
                    .. " ("
                    .. entry.type:gsub("assist_", "")
                    .. ")"

            elseif entry.type == "lava" then

                right_text = short_name(entry.victim) .. " (lava)"

            elseif entry.type == "void" then

                right_text = short_name(entry.victim) .. " (void)"

            elseif entry.type == "fall" then

                right_text = short_name(entry.victim) .. " (fall)"

            else

                right_text = short_name(entry.victim)

            end

            player:hud_change(slot.killer, "text", left_text)

            player:hud_change(slot.image, "text", texture)

            player:hud_change(slot.victim, "text", right_text)

        else

            player:hud_change(slot.killer, "text", "")

            player:hud_change(slot.image, "text", "")

            player:hud_change(slot.victim, "text", "")

        end

    end

end

function update_hud_all()

    for _, player in ipairs(minetest.get_connected_players()) do

        update_hud(player)

    end

end

---------------------------------------------------
-- DEATH HANDLING
---------------------------------------------------

minetest.register_on_dieplayer(function(player)

    local victim = player:get_player_name()

    local pos = last_pos[victim]

    local data = last_hitter[victim]

    local death_type = "suicide"

    local weapon = "suicide.png"

    local killer = victim

    if pos then

        local node = minetest.get_node(pos).name

        if node:find("lava") then

            death_type = "lava"

        end

    end

    if pos and pos.y < -40 then

        death_type = "void"

    end

    if not data then

        death_type = "fall"

    end

    if data then

        local diff = os.time() - data.time

        local hitter = data.name

        if hitter ~= victim then

            if diff <= 3 then

                add_kill(
                    hitter,
                    victim,
                    data.weapon ~= "" and data.weapon or "default:hand",
                    "kill"
                )

                last_hitter[victim] = nil

                return

            elseif diff <= 15 then

                add_kill(
                    hitter,
                    victim,
                    data.weapon ~= "" and data.weapon or "default:hand",
                    "assist_" .. death_type
                )

                last_hitter[victim] = nil

                return

            end

        end

    end

    add_kill(killer, victim, weapon, death_type)

    last_hitter[victim] = nil

end)

---------------------------------------------------
-- JOIN
---------------------------------------------------

minetest.register_on_joinplayer(function(player)

    local name = player:get_player_name()

    player_settings[name] = true

    minetest.after(0.5, function()

        create_hud(player)

        update_hud(player)

    end)

end)

---------------------------------------------------
-- TIME FORMAT
---------------------------------------------------

local function format_time(ts)

    local diff = os.time() - ts

    if diff < 60 then

        return diff .. "s ago"

    elseif diff < 3600 then

        return math.floor(diff / 60) .. "m ago"

    elseif diff < 86400 then

        return math.floor(diff / 3600) .. "h ago"

    else

        return os.date("%H:%M", ts)

    end

end

---------------------------------------------------
-- BUILD UI LIST
---------------------------------------------------

local function build_kill_list(filter)

    local now = os.time()

    local text = ""

    for _, entry in ipairs(kill_feed) do

        if now - entry.time <= 86400 then

            local line = ""

            if entry.type == "kill" then

                line = entry.killer .. " killed " .. entry.victim

            elseif entry.type == "suicide" then

                line = entry.victim .. " died"

            elseif entry.type == "lava" then

                line = entry.victim .. " burned in lava"

            elseif entry.type == "void" then

                line = entry.victim .. " fell into the void"

            elseif entry.type == "fall" then

                line = entry.victim .. " hit the ground too hard"

            elseif entry.type == "combat_log" then

                line = entry.victim .. " tried to escape combat (combat log)"

            elseif entry.type:find("assist_") then

                local cause = entry.type:gsub("assist_", "")

                line = entry.killer
                    .. " pushed "
                    .. entry.victim
                    .. " to "
                    .. cause

            end

            line = line
                .. " ("
                .. entry.weapon
                .. ")"
                .. " ("
                .. format_time(entry.time)
                .. ")"

            if not filter or filter == "" then

                text = text .. minetest.formspec_escape(line) .. ","

            else

                local f = filter:lower()

                if line:lower():find(f) then

                    text = text .. minetest.formspec_escape(line) .. ","

                end

            end

        end

    end

    return text

end

---------------------------------------------------
-- UI
---------------------------------------------------

local function show_kill_log_ui(player, filter)

    local list = build_kill_list(filter)

    local formspec =
        "formspec_version[4]" ..
        "size[12,9]" ..
        "label[0.5,0.4;24h Kill Log]" ..
        "field[0.5,1.2;7,1;search;Search player:;" .. (filter or "") .. "]" ..
        "button[7.7,1.2;2,1;go;Search]" ..
        "textlist[0.5,2.2;11,6.2;kills;" .. list .. ";]" ..
        "button_exit[4.5,8;3,1;exit;Close]"

    minetest.show_formspec(
        player:get_player_name(),
        "kill_log:ui",
        formspec
    )

end

---------------------------------------------------
-- COMMAND
---------------------------------------------------

minetest.register_chatcommand("kill_log", {

    description = "Open 24h kill log UI",

    func = function(name)

        local player = minetest.get_player_by_name(name)

        if player then

            show_kill_log_ui(player)

        end

    end

})

---------------------------------------------------
-- SEARCH
---------------------------------------------------

minetest.register_on_player_receive_fields(function(player, formname, fields)

    if formname ~= "kill_log:ui" then return end

    if fields.go or fields.key_enter_field == "search" then

        show_kill_log_ui(player, fields.search)

    end

end)
