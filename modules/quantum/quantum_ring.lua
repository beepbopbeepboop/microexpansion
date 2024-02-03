-- network/quantum_ring.lua

local me = microexpansion
local network = me.network
local access_level = microexpansion.constants.security.access_levels

local recipe = {
  { 1, {
    {microexpansion.iron_ingot_ingredient, microexpansion.iron_ingot_ingredient, "microexpansion:steel_infused_obsidian_ingot"},
    {microexpansion.iron_ingot_ingredient, "microexpansion:machine_casing", microexpansion.iron_ingot_ingredient},
    {microexpansion.iron_ingot_ingredient, "microexpansion:cable", microexpansion.iron_ingot_ingredient},
    },
  }
}
	
-- [register node] Quantum Ring
me.register_node("quantum_ring", {
  description = "Quantum Ring",
  tiles = {
    "quantum_ring",
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
    else
      meta:set_string("infotext", "Quantum Link Established")
    end
  end,
  on_construct = function(pos)
    local meta = minetest.get_meta(pos)
    local net,cp = me.get_connected_network(pos)
    --me.send_event(pos, "connect", {net=net})
    if net == nil then
      meta:set_string("infotext", "No Network")
    else
      meta:set_string("infotext", "Quantum Link Established")
    end
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
  machine = {
    type = "conductor",
  },
})
