-- network/quantum_link.lua

local me = microexpansion
local network = me.network
local access_level = microexpansion.constants.security.access_levels

local recipe = {
  { 1, {
    {"microexpansion:steel_infused_obsidian_ingot", microexpansion.iron_ingot_ingredient, microexpansion.iron_ingot_ingredient},
    {microexpansion.iron_ingot_ingredient, "microexpansion:machine_casing", microexpansion.iron_ingot_ingredient},
    {microexpansion.iron_ingot_ingredient, "microexpansion:cable", microexpansion.iron_ingot_ingredient},
    },
  }
}

-- [me matter condenser] Get formspec
local function chest_formspec(pos)
  local net = me.get_connected_network(pos)
  local list
  list = [[
      list[context;input;0,0.3;1,1]
      tooltip[input;Place singularity to link two rings]
      list[current_player;main;0,3.5;8,1;]
      list[current_player;main;0,4.73;8,3;8]
      listring[current_name;input]
      listring[current_player;main]
  ]]

  local formspec =
      "size[9,7.5]"..
      microexpansion.gui_bg ..
      microexpansion.gui_slots ..
      "label[0,-0.23;Quantum Link]" ..
      list
  return formspec
end

local link_down = function(pos)
  local meta = minetest.get_meta(pos)
  local source = meta:get_string("source")
  if source ~= "" then
    local net,idx = me.get_network(pos)
    --we want to write all the drives, then cut things
    --me.send_event(pos, "writedrives")
    me.send_event(pos, "disconnect")

    local rpos = vector.from_string(source)
    -- this fails?
    local rnode = me.get_node(rpos)
    local rmeta = minetest.get_meta(rpos)

    local nn = me.get_node(rpos).name
    -- todo: verify the other side is still a quantum link?
    -- once taken, the bidirectional link goes away, it was powered
    -- by the singularity.
    meta:set_string("source", "")
    rmeta:set_string("source", "")
    me.send_event(pos, "disconnect")
  end
end
	
-- [register node] Quantum Link
me.register_node("quantum_link", {
  description = "Quantum Link",
  tiles = {
    "quantum_link",
  },
  recipe = recipe,
  drawtype = "nodebox",
  paramtype = "light",
  paramtype2 = "facedir",
  groups = { cracky = 1, me_connect = 1 },
  connect_sides = {left=1, right=1, front=1, back=1, top=1, bottom=1},
  me_update = function(pos,_,ev)
    local net = me.get_connected_network(pos)
    local meta = minetest.get_meta(pos)
    if net == nil then
      meta:set_string("infotext", "No Network")
      -- swap_nodes to inactive
    else
      meta:set_string("infotext", "Quantum Link Established")
      -- swap_nodes to active
    end
  end,
  on_construct = function(pos)
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    inv:set_size("input", 1)
    meta:set_string("formspec", chest_formspec(pos))
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
  on_destruct = function(pos)
    link_down(pos)
  end,
  after_destruct = function(pos)
    me.send_event(pos, "disconnect")
  end,
  allow_metadata_inventory_take = function(pos,_,_,stack, player)
    local net = me.get_connected_network(pos)
    if net then
      if net:get_access_level(player) < access_level.interact then
	return 0
      end
    elseif minetest.is_protected(pos, player) then
      minetest.record_protection_violation(pos, player)
      return 0
    end

    link_down(pos)

    return stack:get_count()
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
    if stack:get_name() ~= "microexpansion:singularity" then
      return 0
    end
    local qid = stack:get_meta():get_int("id")
    if stack:get_meta():get_int("id") == 0 then
      -- only singularities from the matter condenser, and
      -- they can only be used once.
      return 0
    end
    if not me.qnets then
      me.qnets = {}
    end
    -- note: a link has to be established in one session
    if me.qnets[qid] then
      local meta = minetest.get_meta(pos)
      -- link remote to us.
      local rpos = me.qnets[qid]
      local rmeta = minetest.get_meta(rpos)
      -- links are uniform bidirectional
      if rmeta then
        local nodes = me.network.adjacent_connected_nodes(pos)
	local rpos = vector.zero()
	local count = 0
	for x = pos.x-1, pos.x+1 do
	  for y = pos.y-1, pos.y+1 do
	    for z = pos.z-1, pos.z+1 do
	      local npos = vector.new(x, y, z)
	      local n = me.get_node(npos)
	      if n.name == "microexpansion:quantum_ring" then
	        rpos = vector.add(rpos, npos)
	        count = count + 1
	      end
	    end
	  end
	end
	local spos = vector.multiply(pos, count)
	-- The structure must be balanced and we need at least 8 quantum rings
	if vector.equals(spos, rpos) and count >= 8 then
          meta:set_string("source", vector.to_string(rpos))
          rmeta:set_string("source", vector.to_string(pos))
	end
      end
      me.qnets[qid] = 0
      -- And just like that, we are now up
      me.send_event(pos, "connect")
    else
      -- remember us
      me.qnets[qid] = pos
      me.send_event(pos, "connect", {net=net})
    end
    return 1
  end,
  on_metadata_inventory_put = function(pos, listname, index, stack, player)
    -- the power required to estabilish the link causes the
    -- singularities to decohere
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    stack:get_meta():set_int("id", 0)
    inv:set_stack(listname, index, stack)
  end,
  machine = {
    type = "conductor",
  },
})
