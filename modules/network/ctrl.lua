-- power/ctrl.lua

local me = microexpansion
local network = me.network

--FIXME: accept multiple controllers in one network

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
  recipe = {
    { 1, {
	{"default:steel_ingot", "microexpansion:steel_infused_obsidian_ingot", "default:steel_ingot"},
	{"default:steel_ingot",       "microexpansion:machine_casing",         "default:steel_ingot"},
	{"default:steel_ingot",             "microexpansion:cable",            "default:steel_ingot"},
      },
    }
  },
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
  --HV_EU_demand = 10,
  -- typical technic connections:
  -- connect_sides = {"bottom", "front", "left", "right"},
  --HV_EU_input = 23,
  --HV_EU_supply = 144,
  --HV_EU_demand = 44,
  technic_run = function(pos, node)
    --local meta = minetest.get_meta(pos)
    -- quick cheat sheet for how to wire:
    --meta:set_int("HV_EU_input", 23)
    --meta:set_int("HV_EU_demand", 45)
    --meta:set_int("HV_EU_supply", 1045)
  end,
  connect_sides = "nobottom",
  me_update = function(pos,_,ev)
    local net = me.get_network(pos)
    if net == nil then
      me.log("no network for ctrl at pos "..minetest.pos_to_string(pos),"error")
      return
    end
    net:update()
  end,
  mesecons = {effector = {
    action_on = function (pos, node)
      local net = me.get_network(pos)
      -- turn OFF on mese power
      local meta = minetest.get_meta(pos)
      meta:set_int("enabled", 0)
      net:update_demand()
    end,
    action_off = function (pos, node)
      local net = me.get_network(pos)
      -- turn ON without mesepower
      local meta = minetest.get_meta(pos)
      meta:set_int("enabled", 1)
      net:update_demand()
    end
  }},
  on_construct = function(pos)
    local meta = minetest.get_meta(pos)
    local net = network.new({controller_pos = pos})
    table.insert(me.networks,net)
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
  on_destruct = function(pos)
    local net,idx = me.get_network(pos)
    --disconnect all those who need the network
    me.send_event(pos,"disconnect",{net=net})
    if net then
      net:destruct()
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
  on_construct = function(pos)
    me.send_event(pos,"connect")
  end,
  after_destruct = function(pos)
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
