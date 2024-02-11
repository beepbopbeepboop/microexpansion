-- matter condenser
-- microexpansion/modules/quantum/matter_condenser.lua

local me = microexpansion
local pipeworks_enabled = minetest.get_modpath("pipeworks") and true or false
local access_level = microexpansion.constants.security.access_levels

me.register_item("singularity", {
  description = "Singularity",
  usedfor = "used to link quantum rings",
  groups = {not_in_creative_inventory = 1},
})

function me.create_singularity()
  -- todo: this uuid needs to be saved
  me.singularity = (me.singularity or 0) + 1
  local singularity = ItemStack("microexpansion:singularity 2")
  singularity:get_meta():set_string("id", me.singularity)
  return singularity
end

local fire = function(pos)
  local meta = minetest.get_meta(pos)
  local inv = meta:get_inventory()
  local dstack = inv:get_stack("input", 1)
  local timer = minetest.get_node_timer(pos)
  -- one at a time please
  if timer:is_started() then return end
  timer:start(1)
end

-- [me matter condenser] Get formspec
local function chest_formspec(pos)
  local net = me.get_connected_network(pos)
  local list
  list = [[
      list[context;input;0,0.3;1,1]
      tooltip[input;Trash can of items to be destroyed]
      list[context;dst;2,0.3;1,1]
      list[current_player;main;0,3.5;8,1;]
      list[current_player;main;0,4.73;8,3;8]
      listring[current_name;dst]
      listring[current_player;main]
      listring[current_name;input]
      listring[current_player;main]
  ]]

  local formspec =
      "size[9,7.5]"..
      microexpansion.gui_bg ..
      microexpansion.gui_slots ..
      "label[0,-0.23;Matter Condenser]" ..
      list
  return formspec
end

local function update_chest(pos,_,ev)
  --for now all events matter
  local meta = minetest.get_meta(pos)
  meta:set_string("formspec", chest_formspec(pos))
end

local recipe = nil
if minetest.get_modpath("mcl_core") then
recipe = {
    { 1, {
	{"",                    "mcl_chests:chest", ""},
	{"",                    "microexpansion:machine_casing", ""},
	{"mcl_core:iron_ingot", "microexpansion:cable", "mcl_core:iron_ingot"},
      },
    }
}

else

recipe = {
    { 1, {
	{"",                    "default:chest",                 ""},
	{"",                    "microexpansion:machine_casing", ""},
	{"default:steel_ingot", "microexpansion:cable",          "default:steel_ingot"},
      },
    }
  }
end

-- [me chest] Register node
me.register_node("matter_condenser", {
  description = "Matter Condenser",
  usedfor = "Used to make singularities",
  tiles = {
    "matter_condenser",
  },
  recipe = recipe,
  is_ground_content = false,
  groups = { cracky = 1, me_connect = 1, tubedevice = 1, tubedevice_receiver = 1 },
  paramtype = "light",
  paramtype2 = "facedir",
  me_update = update_chest,
  on_construct = function(pos)
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    inv:set_size("dst", 1)
    inv:set_size("input", 1)
    meta:set_string("formspec", chest_formspec(pos, 1))
    local net,cp = me.get_connected_network(pos)
    me.send_event(pos, "connect", {net=net})
  end,
  can_dig = function(pos, player)
    if not player then
      return false
    end
    local name = player:get_player_name()
    if minetest.is_protected(pos, name) then
      minetest.record_protection_violation(pos, name)
      return false
    end
    local net,cp = me.get_connected_network(pos)
    if not net then
      return true
    end
    return net:get_access_level(name) >= access_level.modify
  end,
  after_destruct = function(pos)
    me.send_event(pos, "disconnect")
  end,
  allow_metadata_inventory_take = function(pos,_,_,stack, player)
    local network = me.get_connected_network(pos)
    if network then
      if network:get_access_level(player) < access_level.interact then
	return 0
      end
    elseif minetest.is_protected(pos, player) then
      minetest.record_protection_violation(pos, player)
      return 0
    end
    return stack:get_count()
  end,
  on_metadata_inventory_put = function(pos)
    fire(pos)
  end,
  on_timer = function(pos, elapsed)
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    local dstack = inv:get_stack("input", 1)
    if dstack:get_name() == "" then
      return
    end
    inv:set_stack("input", 1, "")
    if math.random() < dstack:get_count()/256000 then
      inv:set_stack("dst", 1, me.create_singularity())
    end
  end,
  tube = {
    can_insert = function(pos, _, stack) --pos, node, stack, direction
      local net = me.get_connected_network(pos)
      if not net then
	return false
      end
      local inv = minetest.get_meta(pos):get_inventory()
      local dstack = inv:get_stack("input", 1)
      if dstack:get_name() == "" then
        return true
      end
      if dstack:get_name() == stack:get_name() and
         dstack:get_wear() == stack:get_wear() then
        return true
      end
      return false
    end,
    insert_object = function(pos, _, stack)
      local inv = minetest.get_meta(pos):get_inventory()
      local dstack = inv:get_stack("input", 1)
      stack:set_count(stack:get_count() + dstack:get_count())
      inv:set_stack("input", 1, stack)
      fire(pos)
      return ItemStack()
    end,
    connect_sides = {left=1, right=1, front=1, back=1, top=1, bottom=1},
  },
  after_place_node = pipeworks_enabled and pipeworks.after_place,
  after_dig_node = pipeworks_enabled and pipeworks.after_dig,
})

if me.uinv_category_enabled then
  unified_inventory.add_category_item("storage", "microexpansion:matter_condenser")
end
