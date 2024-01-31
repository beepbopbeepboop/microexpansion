-- microexpansion/api.lua
local BASENAME = "microexpansion"

-- [function] Register Recipe
function microexpansion.register_recipe(output, recipe)
  -- Check if disabled
  if recipe.disabled == true then
    return
  end

  for _,r in ipairs(recipe) do
    local def = {
      type   = type(r[2]) == "string" and r[2] or nil,
      output = output.." "..(r[1] or 1),
      recipe = r[3] or r[2]
    }
    minetest.register_craft(def)
  end
end

-- [function] Register oredef
function microexpansion.register_oredef(ore, defs)
  -- Check if disabled
  if defs.disabled == true then
    return
  end

  for _,d in ipairs(defs) do
    d.ore = ore
    minetest.log("action", minetest.serialize(d))
    minetest.register_ore(d)
  end
end

-- [local function] Choose description colour
local function desc_colour(status, desc)
  if status == "unstable" then
    return minetest.colorize("orange", desc)
  elseif status == "no" then
    return minetest.colorize("red", desc)
  else
    return minetest.colorize("white", desc)
  end
end

-- [function] Register Item
function microexpansion.register_item(itemstring, def)
  -- Check if disabled
  if def.disabled == true then
    return
  end
  -- Set usedfor
  if def.usedfor then
    def.description = def.description .. "\n"..minetest.colorize("grey", def.usedfor)
  end
  -- Update inventory image
  if def.inventory_image then
    def.inventory_image = BASENAME.."_"..def.inventory_image..".png"
  else
    def.inventory_image = BASENAME.."_"..itemstring..".png"
  end
  -- Colour description
  def.description = desc_colour(def.status, def.description)

  -- Register craftitem
  minetest.register_craftitem(BASENAME..":"..itemstring, def)

  -- if recipe, Register recipe
  if def.recipe then
    microexpansion.register_recipe(BASENAME..":"..itemstring, def.recipe)
  end
end

-- [function] Register Node
function microexpansion.register_node(itemstring, def)
  if minetest.get_modpath("mcl_core") then
    def._mcl_hardness = def._mcl_hardness or 3
    def._mcl_blast_resistance = def._mcl_blast_resistance or 3
    def._mcl_hardness = def._mcl_hardness or 3
    def._mcl_silk_touch_drop = def._mcl_silk_touch_drop or true
    def.groups.pickaxey = def.groups.pickaxey or 3
  end
  -- Check if disabled
  if def.disabled == true then
    return
  end
  -- Set usedfor
  if def.usedfor then
    def.description = def.description .. "\n"..minetest.colorize("grey", def.usedfor)
  end
  -- Update texture
  if def.auto_complete ~= false then
    for i,n in ipairs(def.tiles) do
      if #def.tiles[i]:split("^") <= 1 then
        local prefix = ""
        if def.type == "ore" then
          prefix = "ore_"
        end

        def.tiles[i] = BASENAME.."_"..prefix..n..".png"
      end
    end
  end
  -- Colour description
  def.description = desc_colour(def.status, def.description)
  -- Update connect_sides
  if def.connect_sides == "nobottom" then
    def.connect_sides = { "top", "front", "left", "back", "right" }
  elseif def.connect_sides == "machine" then
    def.connect_sides = { "top", "bottom", "left", "back", "right" }
  end

  -- Register node
  minetest.register_node(BASENAME..":"..itemstring, def)

  -- if recipe, Register recipe
  if def.recipe then
    microexpansion.register_recipe(BASENAME..":"..itemstring, def.recipe)
  end

  -- if oredef, Register oredef
  if def.oredef then
    microexpansion.register_oredef(BASENAME..":"..itemstring, def.oredef)
  end
end

-- get a node, if necessary load it
function microexpansion.get_node(pos)
  local node = minetest.get_node_or_nil(pos)
  if node then return node end
  local vm = VoxelManip()
  vm:read_from_map(pos, pos)
  return minetest.get_node(pos)
end

function microexpansion.update_node(pos,event)
  local node = microexpansion.get_node(pos)
  local def = minetest.registered_nodes[node.name]
  local ev = event or {type = "n/a"}
  if def.me_update then
    def.me_update(pos,node,ev)
  end
end

-- [function] Move items from inv to inv
function microexpansion.move_inv(net, inv1, inv2, max, filter)
  if max <= 0 then return end
  local finv, tinv   = inv1.inv, inv2.inv
  local fname, tname = inv1.name, inv2.name
  local huge = inv2.huge
  local inserted = 0

  for _,v in ipairs(finv:get_list(fname) or {}) do
    local left = max-inserted
    if left <= 0 then
      break;
    end
    if not v:is_empty() then
      if v:get_count() > left then
	v = v:peek_item(left)
      end
      if tinv and tinv:room_for_item(tname, v) and (not filter or not filter(v)) then
	if huge then
	  microexpansion.insert_item(v, net, tinv, tname)
	  finv:remove_item(fname, v)
        else
	  --TODO: continue inserting from the same stack if it is bigger than max
	  if v:get_count() > v:get_stack_max() then
	    v = v:peek_item(v:get_stack_max())
	  end
	  local leftovers = tinv:add_item(tname, v)
	  finv:remove_item(fname, v)
	  if leftovers and not leftovers:is_empty() then
	    microexpansion.log("leftover items when transferring inventory", "warning")
	    finv:add_item(fname, leftovers)
	  end
	end
	inserted = inserted + v:get_count()
      end
    end
  end
  return inserted
end
