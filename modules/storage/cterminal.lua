-- crafting terminal
-- microexpansion/modules/storage/cterminal.lua

-- TODO: Bugs, can't craft sticks, oil extract by using the
-- output. Does work when updating the recipe. Groups are hanky. We
-- only use the last recipe registered. Would be nice to be able to
-- cycle trough them. We handle this by merely requiring the user to
-- select the input recipe they want.

-- TODO: Bugs in original, if you remove controller, this wipes all drives
-- Spacing sucks.

-- The search list doesn't update when main updates or when autocrafting updates.

local me = microexpansion
local pipeworks_enabled = minetest.get_modpath("pipeworks") and true or false
local access_level = microexpansion.constants.security.access_levels

-- caches some recipe data to avoid to call the slow function minetest.get_craft_result() every second
me.autocrafterCache = {}
local autocrafterCache = me.autocrafterCache

-- [me chest] Get formspec
local function chest_formspec(pos, start_id, listname, page_max, q, c, d)
  local list
  local page_number = ""
  local buttons = ""
  local query = q or ""
  local crafts = (c and "true") or "false"
  local desc = (d and "true") or "false"
  local net,cpos = me.get_connected_network(pos)

  if cpos then
    local inv = net:get_inventory()
    if listname and (inv:get_size(listname) > 0 or net:get_item_capacity() > 0) then
      local ctrlinvname = net:get_inventory_name()
      if listname == "main" then
	list = "list[detached:"..ctrlinvname..";"
	  .. listname .. ";0,0.3;8,4;" .. (start_id - 1) .. "]"
      else
	list = "list[context;" .. listname .. ";0,0.3;8,4;" .. (start_id - 1) .. "]"
      end
      if minetest.get_modpath("i3") then
	list = list .. [[
	  list[current_player;main;0,8.5;9,4;]
	]]
      else
	list = list .. [[
	  list[current_player;main;0,8.5;8,1;]
	  list[current_player;main;0,9.73;8,3;8]
	]]
      end
      list = list .. [[
	list[context;recipe;0.22,5.22;3,3;]
	list[context;output;4,6.22;1,1;]
      ]]
      list = list .. [[
	listring[current_player;main]
	listring[detached:]]..ctrlinvname..[[;main]
	listring[current_player;main]
	listring[context;recipe]
	listring[current_player;main]
	listring[context;output]
	listring[current_player;main]
	listring[context;search]
      ]]
      buttons = [[
	button[3.56,4.35;0.9,0.9;tochest;To Drive]
	tooltip[tochest;Move everything from your inventory to the ME network.]
	checkbox[4.46,4.35;desc;desc;]]..desc..[[]
	tooltip[desc;Search the descriptions]
	button[5.4,4.35;0.8,0.9;prev;<]
	button[7.25,4.35;0.8,0.9;next;>]
	tooltip[prev;Previous]
	tooltip[next;Next]
	field[0.29,4.6;2.2,1;filter;;]]..query..[[]
	button[2.1,4.5;0.8,0.5;search;?]
	button[2.75,4.5;0.8,0.5;clear;X]
	tooltip[search;Search]
	tooltip[clear;Reset]
	field[6,5.42;2,1;autocraft;;1]
	tooltip[autocraft;Number of items to Craft]
	checkbox[6,6.45;crafts;crafts;]]..crafts..[[]
	tooltip[crafts;Show only craftable items]
      ]]
    else
      list = "label[3,2;" .. minetest.colorize("red", "No connected storage!") .. "]"
    end
  else
    list = "label[3,2;" .. minetest.colorize("red", "No connected network!") .. "]"
  end
  if page_max then
    page_number = "label[6.15,4.5;" .. math.floor((start_id / 32)) + 1 ..
      "/" .. page_max .."]"
  end

  if net and not net:powered() then
    list = "label[3,2;" .. minetest.colorize("red", "No power!") .. "]"
    buttons = ""
    page_number = ""
  end

  return [[
    size[9,12.5]
  ]]..
    microexpansion.gui_bg ..
    microexpansion.gui_slots ..
    list ..
  [[
    label[0,-0.23;ME Crafting Terminal]
    field_close_on_enter[filter;false]
    field_close_on_enter[autocraft;false]
  ]]..
    page_number ..
    buttons
end

local function update_chest(pos,_,ev)
  --me.log("CTERM: got event "..((ev and ev.type) or "<null>"), "error")
  --for now all events matter

  local net = me.get_connected_network(pos)
  local meta = minetest.get_meta(pos)
  if net == nil then
    page = 1
    meta:set_int("page", page)
    meta:set_string("formspec", chest_formspec(pos, 1))
    return
  end
  local size = net:get_item_capacity()
  local page_max = me.int_to_pagenum(size) + 1

  meta:set_string("inv_name", "main")
  meta:set_string("formspec", chest_formspec(pos, 1, "main", page_max))
end

-- From pipeworks/autocrafter.lua
local function count_index(invlist)
  local index = {}
  for _, stack in pairs(invlist) do
    if not stack:is_empty() then
      local stack_name = stack:get_name()
      index[stack_name] = (index[stack_name] or 0) + stack:get_count()
    end
  end
  return index
end

-- From pipeworks/autocrafter.lua
function me.get_craft(pos, inventory, hash)
  local hash = hash or minetest.hash_node_position(pos)
  local craft = autocrafterCache[hash]
  if not craft then
    local recipe = inventory:get_list("recipe")
    for i = 1, 9 do
      if recipe[i]:get_count() > 1 then
	recipe[i] = ItemStack(recipe[i]:get_name())
      end
    end
    local output, decremented_input = minetest.get_craft_result({method = "normal", width = 3, items = recipe})
    craft = {recipe = recipe, consumption=count_index(recipe), output = output, decremented_input = decremented_input}
    autocrafterCache[hash] = craft
  end
  return craft
end

-- From pipeworks/autocrafter.lua
-- note, that this function assumes already being updated to virtual items
-- and doesn't handle recipes with stacksizes > 1
function me.after_recipe_change(pos, inventory)
  -- if we emptied the grid, there's no point in keeping it running or cached
  if inventory:is_empty("recipe") then
    autocrafterCache[minetest.hash_node_position(pos)] = nil
    inventory:set_stack("output", 1, "")
    return
  end
  local recipe = inventory:get_list("recipe")

  local hash = minetest.hash_node_position(pos)
  local craft = autocrafterCache[hash]

  if craft then
    -- check if it changed
    local cached_recipe = craft.recipe
    for i = 1, 9 do
      if recipe[i]:get_name() ~= cached_recipe[i]:get_name() then
	autocrafterCache[hash] = nil -- invalidate recipe
	craft = nil
	break
      end
    end
  end

  craft = craft or me.get_craft(pos, inventory, hash)
  local output_item = craft.output.item
  inventory:set_stack("output", 1, output_item)
end

-- From pipeworks/autocrafter.lua
-- clean out unknown items and groups, which would be handled like unknown items in the crafting grid
-- if minetest supports query by group one day, this might replace them
-- with a canonical version instead
local function normalize(item_list)
  for i = 1, #item_list do
    local name = item_list[i]
    if not minetest.registered_items[name] then
      item_list[i] = ""
      if name == "group:stick" then
	item_list[i] = "default:stick"
      elseif name == "group:glass" then
	item_list[i] = "default:glass"
      elseif name == "group:wood" then
	name = "moretrees:oak_planks"
	if minetest.registered_items[name] then
	  item_list[i] = name
	else
	  item_list[i] = "default:wood"
	end
      elseif name == "group:wood" then
	item_list[i] = "moretrees:oak_trunk"
      elseif name == "group:wool" then
	item_list[i] = "wool:white"
      elseif name == "group:sand" then
	item_list[i] = "default:sand"
      elseif name == "group:stone" then
	item_list[i] = "default:cobble"
      elseif name == "group:leaves" then
	name = "moretrees:sequoia_leaves"
	if minetest.registered_items[name] then
	  item_list[i] = name
	else
	  item_list[i] = "default:leaves"
	end
      elseif name == "group:coal" then
	item_list[i] = "default:coal"
      elseif name == "group:tree" then
	item_list[i] = "default:tree"
      end
    end
  end
  return item_list
end

-- 0 to 34
function me.uranium_dust(p)
  return "technic:uranium"..(p == 7 and "" or p).."_dust"
end
for pa = 0, 34 do
  -- uranium_dust(pa)
  -- me.uranium_dust(pa-1).." 2"
  -- No, this would require a billion uranium to do this. :-(
  -- Make a uranium centrifuge controller and have it be smart.
  --me.register_output_by_typename("separating", "")
end

me.output_by_typename = {
  -- aka me.register_output_by_typename("cooking", "default:stone")
  -- shared by technic and techage
  ["cooking"] = { "default:stone", "default:copper_ingot", "default:gold_ingot", "default:tin_ingot" }
}

-- Used to register what machine types (typename) produce which outputs.
-- Used to figure out what machine to use to create the given output.
-- If multiple outputs are produced, only use the main output, not the
-- incidental output.
function me.register_output_by_typename(typename, output)
  if not me.output_by_typename[typename] then
    me.output_by_typename[typename] = {}
  end
  table.insert(me.output_by_typename[typename], output)
end

-- shared by technic and techage
me.register_output_by_typename("cooking", "mesecons_materials:glue")
me.register_output_by_typename("cooking", "mesecons_materials:fiber")
me.register_output_by_typename("cooking", "basic_materials:plastic_sheet")
me.register_output_by_typename("cooking", "basic_materials:paraffin")

function me.register_output_to_inputs(output, inputs)
  --me.log("REG: output "..output.." from inputs "..dump(inputs))
  me.map_output_to_inputs[output] = inputs
end


me.map_output_to_inputs = {
  -- furnace ("cooking")
  ["default:stone"] = { ItemStack("default:cobble") },
}



function me.find_by_output(name)
  -- TODO: we'd love to be able to look this stuff up in the recipes.
  -- technic.recipes["technic:doped_silicon_wafer"].alloy.recipes[4].input[1]
  return me.map_output_to_inputs[name]
end

function me.register_inventory(name, func)
  -- me.log("INVENTORY: registering "..name, "error")
  if not me.registered_inventory then
    me.registered_inventory = {}
  end
  me.registered_inventory[name] = func
end

-- Allow any type of machine process to be registered. For example,
-- "alloy" for an alloy furnace for example.  These must be done
-- before specific me.register_inventory calls, as that one needs to
-- override this call.
function me.register_typename(name, typename)
  me.block_to_typename_map[name] = typename
  me.register_inventory(name, function() end)
end

me.block_to_typename_map = {
}

-- default wiring
me.register_typename("default:furnace", "cooking")

-- default:furnace "cooking" only has 4 output slots
me.register_max("default:copper_ingot", 99*4)
me.register_max("default:gold_ingot", 99*4)
me.register_max("default:steel_ingot", 99*4)
me.register_max("default:tin_ingot", 99*4)
me.register_max("default:stone", 99*4)
me.register_max("mesecons_materials:glue", 99*4)
me.register_max("mesecons_materials:fiber", 99*4)
me.register_max("basic_materials:plastic_sheet", 99*4)
me.register_max("basic_materials:paraffin", 99*4)

if not technic then
  -- default:furnace ("cooking")
  me.register_output_to_inputs("default:copper_ingot",	{ ItemStack("default:copper_lump") })
  me.register_output_to_inputs("default:gold_ingot",	{ ItemStack("default:gold_lump") })
  me.register_output_to_inputs("default:tin_ingot",	{ ItemStack("default:tin_lump") })
  me.register_output_to_inputs("mesecons_materials:glue", { ItemStack("default:aspen_sapling") })
end
me.register_output_to_inputs("mesecons_materials:fiber", { ItemStack("mesecons_materials:glue") })
me.register_output_to_inputs("basic_materials:plastic_sheet", { ItemStack("basic_materials:paraffin") })
me.register_output_to_inputs("basic_materials:paraffin", { ItemStack("basic_materials:oil_extract") })

-- These must be called after the true name of the machine is defined.
function me.register_machine_alias(alias, name)
  me.block_to_typename_map[alias] = me.block_to_typename_map[name]
  me.set_speed(alias, me.speed[name])
end

function me.get_recipe(typename, inputs)
  if technic then
    return technic.get_recipe(typename, inputs)
  end
  if typename == "cooking" then
    local result, new_input = minetest.get_craft_result({
      method = "cooking",
      width = 1,
      items = inputs})
    if not result or result.time == 0 then
      return nil
    elseif not new_input.items[1]:is_empty() and new_input.items[1]:get_name() ~= items[1]:get_name() then
      items[1]:take_item(1)
      return {time = result.time,
	new_input = {items[1]},
		     output = {new_input.items[1], result.item}}
    else
      return {time = result.time,
	      new_input = new_input.items,
	      output = result.item}
    end
  end
end

-- TODO: Removing an output when the recipe is empty that is in
-- net.autocrafters should not be allowed as the output in that case
-- is virtual. It can be removed if rinv:"output" has the item iff
-- that item is removed from the autocrafter's output.
function me.network:on_output_change(pos, linv, stack)
  local name = stack:get_name()
  -- me.log("PROCESS: "..name.." was found0", "error")
  local net = self
  local inv = net:get_inventory()
  local has_enough = true
  local function clear_recipe()
    local has_enough = true
    for i = 1, 9 do
      local prev = linv:get_stack("recipe", i)
      if prev and prev:get_name() ~= "" and not inv:room_for_item("main", prev) then
	-- full, no room to remove
	has_enough = false
      elseif prev and prev:get_name() ~= "" and me.insert_item(prev, net, inv, "main"):get_count() > 0 then
        -- These all can fault, see minetest.after in network.lua
	net:set_storage_space(true)
	-- Don't have to worry about this happening until minetest is fully multithreaded
	has_enough = false
      else
	net:set_storage_space(true)
	linv:set_stack("recipe", i, ItemStack(""))
      end
    end
    return has_enough
  end
  if not net.process then
    -- rewalk the interfaces on the network to rebuild loans and machines.
    net:reload_network()
  end
  if net and net.process[name] then
    -- me.log("PROCESS: "..name.." was found1", "error")
    has_enough = clear_recipe()
    local pos,ipos = next(net.process[name])
    if has_enough and pos then
      -- me.log("PROCESS: "..name.." was found2", "error")
      local inputs = me.find_by_output(name)
      -- me.log("PROCESS: inputs are "..dump(inputs), "error")
      local machine_name = minetest.get_node(pos).name
      local typename = me.block_to_typename_map[machine_name]
      local recip = typename and me.get_recipe(typename, inputs)
      if recip and recip.output then
	recip.intput = inputs
	-- me.log("PROCESS: "..name.." was found for "..typename.." on a "..machine_name, "error")
	-- freezer can produce two outputs, we only care about the first.
	if recip.output[1] then
	  recip.output = recip.output[1]
	end
	stack = ItemStack(recip.output)
	linv:set_stack("output", 1, stack)
	-- me.log("PROCESS: and the output is "..minetest.serialize(recip.output), "error")
	-- me.log("PROCESS: and the output is "..stack:get_name(), "error")
      else
	--me.log("PROCESS: "..name.." was missing from recipe on a "..machine_name, "error")
	linv:set_stack("output", 1, ItemStack())
      end
    end
    return 0
  elseif net and net.autocrafters[name] then
    has_enough = clear_recipe()
    if has_enough then
      local pos,ipos = next(net.autocrafters[name])
      if pos then
	local rinv = minetest.get_meta(pos):get_inventory()
	stack = ItemStack(rinv:get_stack("output", 1))
	linv:set_stack("output", 1, stack)
      else
	-- me.log("pos in autocrafters was missing", "error")
	linv:set_stack("output", 1, ItemStack())
      end
    else
      linv:set_stack("output", 1, ItemStack())
    end
    return 0
  end
  local input = minetest.get_craft_recipe(name)
  if not input.items or input.type ~= "normal" then return 0 end
  local items, width = normalize(input.items), input.width
  local item_idx, width_idx = 1, 1
  for i = 1, 9 do
    local prev = linv:get_stack("recipe", i)
    if prev and prev:get_name() ~= "" and not inv:room_for_item("main", prev) then
      -- full, no room to remove
      has_enough = false
      if width_idx <= width then
	item_idx = item_idx + 1
      end
    elseif prev and prev:get_name() ~= "" and me.insert_item(prev, net, inv, "main"):get_count() > 0 then
      net:set_storage_space(true)
      -- Don't have to worry about this happening until minetest is fully multithreaded
      has_enough = false
      if width_idx <= width then
	item_idx = item_idx + 1
      end
    elseif width_idx <= width then
      net:set_storage_space(true)
      if inv:contains_item("main", items[item_idx]) then
	me.remove_item(net, inv, "main", ItemStack(items[item_idx]))
	linv:set_stack("recipe", i, items[item_idx])
      else
	has_enough = false
	linv:set_stack("recipe", i, ItemStack(""))
      end
      item_idx = item_idx + 1
    else
      linv:set_stack("recipe", i, ItemStack(""))
    end
    width_idx = (width_idx < 3) and (width_idx + 1) or 1
  end
  -- we'll set the output slot in after_recipe_change to the actual result of the new recipe
  me.after_recipe_change(pos, linv)
  return 0
end

function me.network:take_output(pos, linv, inv)
  local replace = true
  -- This assumes that all inputs are only just 1 item, always true?
  for i = 1, 9 do
    local inp = linv:get_stack("recipe", i)
    if inp and inp:get_name() ~= "" then
      local consume = ItemStack(inp:get_name())
      replace = replace and (inp:get_count() > 1 or inv:contains_item("main", consume))
    end
  end
  for i = 1, 9 do
    local inp = linv:get_stack("recipe", i)
    if inp and inp:get_name() ~= "" then
      if inp:get_count() == 1 then
        if inv:contains_item("main", inp) then
	  local r = me.remove_item(net, inv, "main", inp)
	  if r:get_count() ~= 1 then
	    linv:set_stack("recipe", i, ItemStack(""))
	    replace = false
	  end
	else
	  linv:set_stack("recipe", i, ItemStack(""))
	  replace = false
	end
      else
	local stack_copy = ItemStack(inp)
	stack_copy:set_count(inp:get_count()-1)
	linv:set_stack("recipe", i, stack_copy)
      end
    end
  end
  -- deal with replacements
  local hash = minetest.hash_node_position(pos)
  local craft = autocrafterCache[hash] or me.get_craft(pos, linv, hash)
  for i = 1, 9 do
    if (craft.decremented_input.items[i]:get_count() ~= linv:get_stack("recipe", i):get_count()
	or craft.decremented_input.items[i]:get_name() ~= linv:get_stack("recipe", i):get_name())
	and not craft.decremented_input.items[i]:is_empty() then
      local leftovers = me.insert_item(craft.decremented_input.items[i], net, inv, "main")
      if not leftovers:is_empty() then
	me.leftovers(pos, leftovers)
      end
    end
    if replace then
      linv:set_stack("output", 1, craft.output.item)
    else
      linv:set_list("output", {})
    end
  end
end

local cterm_recipe = nil
if minetest.get_modpath("mcl_core") then
cterm_recipe = {
    { 1, {
	{"microexpansion:term", "mcl_chests:chest"},
      },
    }
}

else

cterm_recipe = {
    { 1, {
	{"microexpansion:term",   "default:chest"},
      },
    }
  }
end

-- [me cterminal] Register node
me.register_node("cterminal", {
  description = "ME Crafting Terminal",
  usedfor = "Can interact with storage cells in ME networks",
  tiles = {
    "chest_top",
    "chest_top",
    "chest_side",
    "chest_side",
    "chest_side",
    "chest_front",
  },
  recipe = cterm_recipe,
  is_ground_content = false,
  groups = { cracky = 1, me_connect = 1, tubedevice = 1, tubedevice_receiver = 1 },
  paramtype = "light",
  paramtype2 = "facedir",
  me_update = update_chest,
  on_construct = function(pos)
    local meta = minetest.get_meta(pos)
    meta:set_string("inv_name", "none")
    page = 1
    meta:set_int("page", page)

    local own_inv = meta:get_inventory()
    own_inv:set_size("src", 1)
    own_inv:set_size("recipe", 3*3)
    own_inv:set_size("output", 1)

    local net = me.get_connected_network(pos)
    me.send_event(pos, "connect", {net=net})
    update_chest(pos)
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
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    if not inv:is_empty("recipe") then
      return false
    end
    local net,cpos = me.get_connected_network(pos)
    if not net then
      return true
    end
    return net:get_access_level(name) >= access_level.modify
  end,
  after_destruct = function(pos)
    me.send_event(pos, "disconnect")
  end,
  allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
    local net = me.get_connected_network(pos)
    if net then
      if net:get_access_level(player) < access_level.interact then
	return 0
      end
    elseif minetest.is_protected(pos, player) then
      minetest.record_protection_violation(pos, player)
      return 0
    end
    --me.log("Allow a move from "..from_list.." to "..to_list, "error")
    local meta = minetest.get_meta(pos)
    if to_list == "recipe" and from_list == "search" then
      local linv = meta:get_inventory()
      local inv = net:get_inventory()
      local stack = linv:get_stack(from_list, from_index)
      count = math.min(count, stack:get_stack_max())
      stack:set_count(count)
      return me.remove_item(net, inv, "main", stack):get_count()
    end
    if from_list == "output" then
      local linv = minetest.get_meta(pos):get_inventory()
      -- an output with no recipe is a virtual item and can't be taken,
      -- but if there is a recipe, then it can be taken.
      local was_empty = true
      for i = 1, 9 do
	was_empty = was_empty and linv:get_stack("recipe", i):is_empty()
      end
      if was_empty then return 0 end
    end
    if to_list == "output" then
      local linv = meta:get_inventory()
      local stack = linv:get_stack(from_list, from_index)
      return net:on_output_change(pos, linv, stack)
    end
    if from_list == "crafts" or from_list == "search" then
      return 0
    end
    if to_list == "search" then
      local linv = meta:get_inventory()
      local inv = net:get_inventory()
      local stack = linv:get_stack(from_list, from_index)
      stack:set_count(count)
      -- meta:set_string("infotext", "allow moving: "..stack:get_name())
      -- TODO: Check capacity? Test.
      local leftovers = me.insert_item(stack, net, inv, "main")
      return count - leftovers:get_count()
    end
    return count
  end,
  allow_metadata_inventory_take = function(pos, listname, index, stack, player)
    local net = me.get_connected_network(pos)
    if net then
      if net:get_access_level(player) < access_level.interact then
	return 0
      end
    elseif minetest.is_protected(pos, player) then
      minetest.record_protection_violation(pos, player)
      return 0
    end
    -- This is used for removing items from "search", "recipe" and "output".
    --me.log("Allow a take from "..listname, "error")
    local count = stack:get_count()
    if listname == "search" or listname == "recipe" then
      count = math.min(count, stack:get_stack_max())
    elseif listname == "crafts" then
      return 0
    end
    if listname == "output" then
      local linv = minetest.get_meta(pos):get_inventory()
      -- an output with no recipe is a virtual item and can't be taken,
      -- but if there is a recipe, then it can be taken.
      local was_empty = true
      for i = 1, 9 do
        was_empty = was_empty and linv:get_stack("recipe", i):is_empty()
      end
      if was_empty then return 0 end
    end
    --[[if listname == "main" then
      -- This should be unused, we don't have a local inventory called main.
      local inv = net:get_inventory()
      local ret = me.remove_item(net, inv, "main", stack)
      --me.log("REMOVE: after remove count is "..ret:get_count(), "error")
      return ret:get_count()
    end
    ]]
    return count
  end,
  allow_metadata_inventory_put = function(pos, listname, index, stack, player)
    local net = me.get_connected_network(pos)
    if net then
      if net:get_access_level(player) < access_level.interact then
	return 0
      end
    elseif minetest.is_protected(pos, player) then
      minetest.record_protection_violation(pos, player)
      return 0
    end
    if listname == "output" then
      local linv = minetest.get_meta(pos):get_inventory()
      return net:on_output_change(pos, linv, stack)
    elseif listname == "search" or listname == "crafts" then
      local inv = net:get_inventory()
      -- TODO: Check full inv, should be fixed now, confirm.
      local leftovers = me.insert_item(stack, net, inv, "main")
      return stack:get_count() - leftovers:get_count()
    end
    return stack:get_count()
  end,
  on_metadata_inventory_put = function(pos, listname, _, stack)
    -- me.dbg()
    if listname == "recipe" then
      local linv = minetest.get_meta(pos):get_inventory()
      me.after_recipe_change(pos, linv)
    end
  end,
  on_metadata_inventory_take = function(pos, listname, index, stack)
    --me.log("A taking of "..stack:get_name().." from "..listname, "error")
    if listname == "output" then
      local linv = minetest.get_meta(pos):get_inventory()
      local num_left = linv:get_stack("output", 1):get_count()
      -- We only need to consume the recipe if there are no more items
      if num_left > 0 then return end
      local net = me.get_connected_network(pos)
      local inv = net:get_inventory()
      net:take_output(pos, linv, inv)
    elseif listname == "recipe" then
      local linv = minetest.get_meta(pos):get_inventory()
      me.after_recipe_change(pos, linv)
    elseif listname == "crafts" or listname == "search" then
      local net = me.get_connected_network(pos)
      local inv = net:get_inventory()
      me.remove_item(net, inv, "main", stack)
    end
  end,
  on_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
    --me.log("A move from "..from_list.." to "..to_list, "error")
    if to_list == "recipe" or from_list == "recipe" then
      local inv = minetest.get_meta(pos):get_inventory()
      me.after_recipe_change(pos, inv)
    elseif from_listname == "output" then
      local linv = minetest.get_meta(pos):get_inventory()
      local num_left = linv:get_stack("output", 1):get_count()
      -- We only need to consume the recipe if there are no more items
      if num_left > 0 then return end
      local net = me.get_connected_network(pos)
      local inv = net:get_inventory()
      net:take_output(pos, linv, inv)
    end
  end,
  tube = {
    can_insert = function(pos, _, stack) --pos, node, stack, direction
      -- TODO: update to use capacity_cache?
      local net = me.get_connected_network(pos)
      local inv = net:get_inventory()
      local max_slots = inv:get_size("main")
      local max_items = net.capacity_cache

      local slots, items = 0, 0
      -- Get amount of items in drive
      for i = 1, max_slots do
	local dstack = inv:get_stack("main", i)
	if dstack:get_name() ~= "" then
	  slots = slots + 1
	  local num = dstack:get_count()
	  if num == 0 then num = 1 end
	  items = items + num
	end
      end
      items = items + stack:get_count()
      return max_items > items
    end,
    insert_object = function(pos, _, stack)
      local net = me.get_connected_network(pos)
      if not net then
	return stack
      end
      local inv = net:get_inventory()
      local leftovers = me.insert_item(stack, net, inv, "main")
      net:set_storage_space(true)
      return leftovers
    end,
    connect_sides = {left=1, right=1, front=1, back=1, top=1, bottom=1},
  },
  after_place_node = pipeworks_enabled and pipeworks.after_place,
  after_dig_node = pipeworks_enabled and pipeworks.after_dig,
  on_receive_fields = function(pos, _, fields, sender)
    local net,cpos = me.get_connected_network(pos)
    if net then
      if cpos then
	me.log("network and ctrl_pos","info")
      else
	me.log("network but no ctrl_pos","warning")
      end
    else
      if cpos then
	me.log("no network but ctrl_pos","warning")
      else
	me.log("no network and no ctrl_pos","info")
      end
    end
    local meta = minetest.get_meta(pos)
    local page = meta:get_int("page")
    local did_update = false
    local update_search = false
    local inv_name = meta:get_string("inv_name")
    local query = meta:get_string("query")
    local crafts = meta:get_string("crafts") == "true"
    local desc = meta:get_string("desc") == "true"
    local own_inv = meta:get_inventory()
    local ctrl_inv
    if cpos then
      ctrl_inv = net:get_inventory()
    else
      me.log("no network connected","warning")
      return
    end
    local inv
    if inv_name == "main" then
      inv = ctrl_inv
      assert(inv,"no control inv")
    else
      inv = own_inv
      assert(inv,"no own inv")
    end
    local page_max = math.floor(inv:get_size(inv_name) / 32) + 1
    if inv_name == "none" then
      return
    end
    if fields.next then
      if page + 32 > inv:get_size(inv_name) then
	return
      end
      page = page + 32
      meta:set_int("page", page)
      did_update = true
    elseif fields.prev then
      if page - 32 < 1 then
	return
      end
      page = page - 32
      meta:set_int("page", page)
      did_update = true
    elseif fields.desc then
      meta:set_string("desc", fields.desc)
      desc = fields.desc == "true"
      page = 1
      meta:set_int("page", page)
      update_search = true
    elseif fields.crafts then
      crafts = fields.crafts == "true"
      meta:set_string("crafts", fields.crafts)
      page = 1
      meta:set_int("page", page)
      if crafts then
	inv_name = "crafts"
	local tab = {}
	if net then
	  if not net.process then
	    net:reload_network()
	  end
	  for name,pos in pairs(net.autocrafters) do
	    tab[#tab + 1] = ItemStack(name)
	  end
	  tab[#tab + 1] = ItemStack("")
	  for name,pos in pairs(net.process) do
	    tab[#tab + 1] = ItemStack(name)
	  end
	end
	own_inv:set_size(inv_name, #tab)
	own_inv:set_list(inv_name, tab)
	meta:set_string("inv_name", inv_name)
	page_max = math.floor(own_inv:get_size(inv_name) / 32) + 1
      else
        inv_name = "main"
	own_inv:set_size("crafts", 0)
	if query == "" then
	  meta:set_string("inv_name", inv_name)
	  page_max = math.floor(ctrl_inv:get_size(inv_name) / 32) + 1
	end
      end
      update_search = true
    elseif fields.search or fields.key_enter_field == "filter" then
      own_inv:set_size("search", 0)
      --me.log("CRAFT: got fields: "..dump(fields), "error")
      page = 1
      meta:set_int("page", page)
      query = fields.filter
      meta:set_string("query", query)
      update_search = true
    elseif fields.clear then
      --me.log("CRAFT: got fields: "..dump(fields), "error")
      own_inv:set_size("search", 0)
      own_inv:set_size("crafts", 0)
      page = 1
      meta:set_int("page", page)
      inv_name = "main"
      meta:set_string("inv_name", inv_name)
      query = ""
      meta:set_string("query", query)
      crafts = false
      meta:set_string("crafts", "false")
      page_max = math.floor(ctrl_inv:get_size(inv_name) / 32) + 1
      did_update = true
    elseif fields.tochest then
      if net:get_access_level(sender) < access_level.interact then
	return
      end
      local pinv = minetest.get_inventory({type="player", name=sender:get_player_name()})
      -- TODO: test and fix, net:set_storage_space(pinv:get_size("main"))
      local space = net:get_item_capacity()
      local contents = ctrl_inv:get_list("main") or {}
      for _,s in pairs(contents) do
	if not s:is_empty() then
	  space = space - s:get_count()
	end
      end
      me.move_inv(net, { inv=pinv, name="main" }, { inv=ctrl_inv, name="main", huge=true }, space)
      net:set_storage_space(true)
    elseif fields.autocraft or fields.key_enter_field == "autocraft" then
      if fields.autocraft ~= "" and tonumber(fields.autocraft) ~= nil then
	local count = tonumber(fields.autocraft)
	fields.autocraft = nil
	if not own_inv:get_stack("output", 1):is_empty() and count < math.pow(2,16) then
	  me.autocraft(autocrafterCache, pos, net, own_inv, ctrl_inv, count)
	end
      end
    end

    if update_search then
      inv_name = "main"
      inv = ctrl_inv
      if crafts then
	inv_name = "crafts"
	inv = own_inv
      end
      if query == "" then
	meta:set_string("inv_name", inv_name)
      else
	local tab = {}
	for i = 1, inv:get_size(inv_name) do
	  local match = inv:get_stack(inv_name, i):get_name():find(query)
	  if desc then
	    match = match or inv:get_stack(inv_name, i):get_description():find(query)
	    match = match or inv:get_stack(inv_name, i):get_short_description():find(query)
	  end
	  if match then
	    tab[#tab + 1] = inv:get_stack(inv_name, i)
	  end
	end
	inv_name = "search"
	own_inv:set_size(inv_name, #tab)
	own_inv:set_list(inv_name, tab)
	meta:set_string("inv_name", inv_name)
	page_max = math.floor(own_inv:get_size(inv_name) / 32) + 1
      end
      did_update = true
    end

    if did_update then
      meta:set_string("formspec", chest_formspec(pos, page, inv_name, page_max, query, crafts, desc))
    end
  end,
})
