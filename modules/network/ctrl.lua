-- power/ctrl.lua

local me = microexpansion
local network = me.network
local access_level = microexpansion.constants.security.access_levels

local ctrl_recipe = nil

ctrl_recipe = {
  { 1, {
    {microexpansion.iron_ingot_ingredient, "microexpansion:steel_infused_obsidian_ingot", microexpansion.iron_ingot_ingredient},
    {microexpansion.iron_ingot_ingredient, "microexpansion:machine_casing", microexpansion.iron_ingot_ingredient},
    {microexpansion.iron_ingot_ingredient, "microexpansion:cable", microexpansion.iron_ingot_ingredient},
    },
  }
}
	
-- [register node] Controller
me.register_node("ctrl", {
  description = "ME Controller",
  tiles = {
    "ctrl_sides",
    "ctrl_bottom",
    "ctrl_sides",
    "ctrl_sides",
    "ctrl_sides",
    "ctrl_sides"
  },
  recipe = ctrl_recipe,
  drawtype = "nodebox",
  paramtype = "light",
  node_box = {
    type = "fixed",
    fixed = {
      {-0.375, -0.375, -0.375, 0.375, 0.375, 0.375}, -- Core
      {0.1875, -0.5, -0.5, 0.5, 0.5, -0.1875}, -- Corner1
      {-0.5, -0.5, -0.5, -0.1875, 0.5, -0.1875}, -- Corner2
      {-0.5, -0.5, 0.1875, -0.1875, 0.5, 0.5}, -- Corner3
      {0.1875, -0.5, 0.1875, 0.5, 0.5, 0.5}, -- Corner4
      {-0.5, -0.4375, -0.5, 0.5, -0.1875, 0.5}, -- Bottom
      {-0.5, 0.1875, -0.5, 0.5, 0.5, -0.1875}, -- Top1
      {0.1875, 0.1875, -0.5, 0.5, 0.5, 0.5}, -- Top2
      {-0.5, 0.1875, -0.5, -0.1875, 0.5, 0.5}, -- Top3
      {-0.5, 0.1875, 0.1875, 0.5, 0.5, 0.5}, -- Top4
      {-0.1875, -0.5, -0.1875, 0.1875, -0.25, 0.1875}, -- Bottom2
    },
  },
  groups = { cracky = 1, me_connect = 1,
    -- for technic integration
    technic_machine = 1, technic_hv = 1,
    -- for on/off switch to conserve power
    mesecon_effector_off = 1, mesecon = 2,
  },
  connect_sides = "nobottom",
  --HV_EU_demand = 10,
  -- typical technic connections:
  -- connect_sides = {"bottom", "front", "left", "right"},
  --HV_EU_input = 23,
  --HV_EU_supply = 144,
  --HV_EU_demand = 44,
  technic_run = function(pos, node)
    local meta = minetest.get_meta(pos)
    -- quick cheat sheet for how to wire:
    --meta:set_int("HV_EU_input", 23)
    --meta:set_int("HV_EU_demand", 45)
    --meta:set_int("HV_EU_supply", 1045)
    local net = me.get_network(pos)
    if not net then
      -- This is impossible, delete?
      local meta = minetest.get_meta(pos)
      meta:set_int("HV_EU_input", 0)
      return
    end
    if net.input ~= meta:get_int("HV_EU_input") then
      net.input = meta:get_int("HV_EU_input")
      me.log("EU: input changed to "..net.input, "error")
      -- This only needs to see changes to inbound power levels.
      me.send_event(pos, "power")
    end
  end,
  me_update = function(pos,_,ev)
    local meta = minetest.get_meta(pos)
    if meta:get_string("source") ~= "" then
      return
    end
    local cnet = me.get_network(pos)
    if cnet == nil then
      microexpansion.log("no network for ctrl at pos "..minetest.pos_to_string(pos),"error")
      return
    end
    net:update()
  end,
  mesecons = {effector = {
    action_on = function (pos, node)
      local net = me.get_network(pos)
      --me.log("SWITCH: on", "error")
      -- turn OFF on mese power
      local meta = minetest.get_meta(pos)
      meta:set_int("enabled", 0)
      net:update_demand()
    end,
    action_off = function (pos, node)
      --me.log("SWITCH: off", "error")
      local net = me.get_network(pos)
      -- turn ON without mesepower
      local meta = minetest.get_meta(pos)
      meta:set_int("enabled", 1)
      net:update_demand()
    end
  }},
  on_construct = function(pos)
    local meta = minetest.get_meta(pos)
    local net,cp = me.get_connected_network(pos)
    if net then
      meta:set_string("source", vector.to_string(cp))
    else
      net = network.new({controller_pos = pos})
      table.insert(me.networks,net)
    end
    me.send_event(pos,"connect",{net=net})

    meta:set_int("enabled", 0)
    net:update_demand()
  end,
  after_place_node = function(pos, player)
    local name = player:get_player_name()
    local meta = minetest.get_meta(pos)
    meta:set_string("infotext", "Network Controller (owned by "..name..")")
    meta:set_string("owner", name)
  end,
  after_place_node = function(pos, player)
    local name = player:get_player_name()
    local meta = minetest.get_meta(pos)
    meta:set_string("infotext", "Network Controller")
    meta:set_string("owner", name)
    local net,idx = me.get_network(pos)
    if net then
      net:set_access_level(name, me.constants.security.access_levels.full)
    elseif meta:get_string("source") == "" then
      me.log("no network after placing controller", "warning")
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
    local meta = minetest.get_meta(pos)
    local net
    if meta:get_string("source") == "" then
      net = me.get_network(pos)
    else
      net = me.get_connected_network(pos)
    end
    if not net then
      me.log("ME Network Controller without Network","error")
      return true
    end
    return net:get_access_level(name) >= access_level.full
  end,
  on_destruct = function(pos)
    local net,idx = me.get_network(pos)
    --disconnect all those who need the network
    me.send_event(pos,"disconnect",{net=net})
    if net then
      if me.promote_controller(pos,net) then
	--reconnect with new controller
	me.send_event(pos,"reconnect",{net=net})
      else
	net:destruct()
	if idx then
	  table.remove(me.networks,idx)
	end
	--disconnect all those that haven't realized the network is gone
	me.send_event(pos,"disconnect")
      end
    else
      -- disconnect just in case
      me.send_event(pos,"disconnect")
    end
    if idx then
      table.remove(me.networks,idx)
    end
    --disconnect all those that haven't realized the network is gone
    me.send_event(pos,"disconnect")
  end,
  after_destruct = function(pos)
    --disconnect all those that haven't realized the controller was disconnected
    me.send_event(pos,"disconnect")
  end,
  machine = {
    type = "controller",
  },
  on_timer = function(pos, elapsed)
    --FIXME: we don't do that here (no goto statements please)
    --       replace with loop or zero timer (next worldstep)
    ::top::
    me.log("TIMER: starting service", "error")
    local net = me.get_network(pos)
    if not net then return false end
    if not net.pending then return false end
    local i = net.pending.index
    local action = net.pending[i]
    -- me.log("TIMER: doing service", "error")
    if not action then
      net.pending = nil
      return false
    end
    local prev_time = net.pending.time[i]
    action(net)
    net.pending[i] = nil
    net.pending.time[i] = nil
    net.pending.index = i + 1
    if net.pending[i+1] then
      local next_action_time = net.pending.time[i+1]
      local step_time = next_action_time - prev_time
      me.log("TIMER: starting next timer for "..step_time.." seconds", "error")
      if step_time == 0 then
        goto top
      end
      me.start_crafting(pos, step_time)
    else
      -- me.log("TIMER: ending service", "error")
      net.pending = nil
    end
    return false
  end,
})

minetest.register_lbm({
  name = "microexpansion:update_network",
  label = "integrate new ME Network data",
  nodenames = {"microexpansion:ctrl"},
  run_at_every_load = true,
  action = function(pos)
    local meta = minetest.get_meta(pos)
    local net,idx = me.get_network(pos)
    if not meta then
      me.log("activated controller before metadata was available", "warning")
      return
    end
    local source = meta:get_string("source")
    if not net then
      if source == "" then
	me.log("activated controller without network", "warning")
	return
      else
	net = me.get_network(vector.from_string(source))
	if not net then
	  me.log("activated controller that is linked to an unloaded controller", "info")
	  return
	end
      end
    end
    if not net.access then
      me.log("added access table to old network", "action")
      net.access = {}
    end
    net:fallback_access()
  end
})

-- [register node] Cable
me.register_machine("cable", {
  description = "ME Cable",
  tiles = {
    "cable",
  },
  recipe = {
    { 12, "shapeless", {
	"microexpansion:steel_infused_obsidian_ingot", "microexpansion:machine_casing"
      },
    }
  },
  drawtype = "nodebox",
  node_box = {
    type = "connected",
    fixed          = {-0.25, -0.25, -0.25, 0.25,  0.25, 0.25},
    connect_top    = {-0.25, -0.25, -0.25, 0.25,  0.5,  0.25}, -- y+
    connect_bottom = {-0.25, -0.5,  -0.25, 0.25,  0.25, 0.25}, -- y-
    connect_front  = {-0.25, -0.25, -0.5,  0.25,  0.25, 0.25}, -- z-
    connect_back   = {-0.25, -0.25,  0.25, 0.25,  0.25, 0.5 }, -- z+
    connect_left   = {-0.5,  -0.25, -0.25, 0.25,  0.25, 0.25}, -- x-
    connect_right  = {-0.25, -0.25, -0.25, 0.5,   0.25, 0.25}, -- x+
  },
  paramtype = "light",
  groups = { crumbly = 1, },
  --TODO: move these functions into the registration
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
  on_construct = function(pos)
    --perhaps this needs to be done after the check if it can be placed
    me.send_event(pos,"connect")
  end,
  after_place_node = function(pos, placer)
    if not placer then
      return false
    end
    local name = placer:get_player_name()
    if minetest.is_protected(pos, name) then
      minetest.record_protection_violation(pos, name)
      --protection probably handles this itself
      --minetest.remove_node(pos)
      return true
    end
    --TODO: prevent connecting multiple networks
    local net,cp = me.get_connected_network(pos)
    if not net then
      return false
    end
    if net:get_access_level(name) < access_level.modify then
      -- prevent placing cables on a network that a player doesn't have access to
      minetest.remove_node(pos)
      return true
    end
  end,
  after_destruct = function(pos)
    --FIXME: write drives before disconnecting
    me.send_event(pos,"disconnect")
  end,
  me_update = function(pos,_,ev)
    if ev then
      if ev.type ~= "disconnect" then return end
    end
    --maybe this shouldn't be called on every update
    local meta = minetest.get_meta(pos)
    if me.get_connected_network(pos) then
      meta:set_string("infotext", "Network connected")
    else
      meta:set_string("infotext", "No Network")
    end
  end,
  machine = {
    type = "conductor",
  },
})

if technic then
   -- quick cheat sheet for how to wire:
   -- producer receiver, producer_receiver, battery
  technic.register_machine("HV", "microexpansion:ctrl", technic.receiver)
end

if me.uinv_category_enabled then
  unified_inventory.add_category_item("storage", "microexpansion:ctrl")
  unified_inventory.add_category_item("storage", "microexpansion:cable")
end

