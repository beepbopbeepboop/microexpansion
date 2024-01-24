-- power/network.lua

local me = microexpansion
local power = me.power

---
--- Helper Functions
---

-- [local function] Get netitem by position
local function get_netitem_by_pos(list, pos)
  for _, i in pairs(list) do
    if vector.equals(pos, i.pos) then
      return i
    end
  end
end

-- [function] Generate new network ID
function power.new_id()
  return "network_"..#me.networks+1
end

-- [function] Add machine to network
function power.add_machine(pos, def)

end

-- [function] Remove machine from network
function power.remove_machine(pos)
  local meta = minetest.get_meta(pos)
  meta:set_string("network_ignore", "true")
end

-- [function] Trace network
function power.trace(pos)
  local netpos = me.networks[minetest.get_meta(pos):get_string("network_id")]

  -- if no network, return
  if not netpos then
    return
  end

  local meta  = minetest.get_meta(netpos)
  local netid = meta:get_string("network_id")
  local list  = {}

  local delete = false
  if meta:get_string("network_ignore") == "true" then
    delete = true
  end

  -- [local function] Indexed
  local function indexed(p)
    for _, i in pairs(list) do
      if vector.equals(p, i.pos) then
        return true
      end
    end
  end

  -- [local function] Trace
  local function trace(nodes)
    for _, p in pairs(nodes) do
      if not indexed(p) then
        local machine = minetest.get_meta(p)
        if machine:get_string("network_ignore") ~= "true" then
          local node = me.get_node(p).name
          local desc = minetest.registered_nodes[node].description
          if delete then
            machine:set_string("network_id", nil)
            machine:set_string("infotext", desc.."\nNo Network")
            me.network_set_demand(p, 0)
          else
            machine:set_string("network_id", netid)
            machine:set_string("infotext", desc.."\nNetwork ID: "..netid)
          end

          list[#list + 1] = { pos = p, demand = machine:get_int("demand") }
          trace(power.get_connected_nodes(p, false))
        end
      end
    end
  end

  trace(power.get_connected_nodes(netpos))

  -- Check original list
  local original = minetest.deserialize(meta:get_string("netitems"))
  if original then
    for _, i in pairs(original) do
      if not indexed(i.pos) then
        local node = me.get_node(i.pos).name
        local desc = minetest.registered_nodes[node].description
        local machine = minetest.get_meta(i.pos)
        machine:set_string("network_id", nil)
        machine:set_string("infotext", desc.."\nNo Network")
        me.network_set_demand(pos, 0)
      end
    end
  end

  meta:set_string("netitems", minetest.serialize(list))

  -- Update infotext
  meta:set_string("infotext", "Network Controller (owned by "..
    meta:get_string("owner")..")\nNetwork ID: "..meta:get_string("network_id")..
    "\nDemand: "..dump(me.network_get_demand(netpos)))
end

---
--- Load Management
---

-- [function] Get load information
function me.network_get_load(pos)
  local ctrl = me.networks[minetest.get_meta(pos):get_string("network_id")]
  if ctrl then
    local meta = minetest.get_meta(ctrl)
    local list = minetest.deserialize(meta:get_string("netitems"))
  end
end

---- Generators ----

---- Output ----

-- [function] Get total network demand
function me.network_get_demand(pos)
  local ctrl = me.networks[minetest.get_meta(pos):get_string("network_id")]

  -- if no network, return
  if not ctrl then
    return
  end

  local meta = minetest.get_meta(ctrl)
  local list = minetest.deserialize(meta:get_string("netitems"))

  local demand = 0
  for _, i in pairs(list) do
    if i.demand then
      demand = demand + i.demand
    end
  end

  return demand
end

-- [function] Set demand for machine
function me.network_set_demand(pos, demand)
  -- Update original metadata
  minetest.get_meta(pos):set_int("demand", demand)

  local ctrl = me.networks[minetest.get_meta(pos):get_string("network_id")]

  -- if no network, return
  if not ctrl then
    return
  end

  local meta = minetest.get_meta(ctrl)
  local list = minetest.deserialize(meta:get_string("netitems"))
  local item = get_netitem_by_pos(list, pos)

  if not item then
    return
  end

  item.demand = demand
  meta:set_string("netitems", minetest.serialize(list))

  -- Update infotext
  meta:set_string("infotext", "Network Controller (owned by "..
    meta:get_string("owner")..")\nNetwork ID: "..meta:get_string("network_id")..
    "\nDemand: "..dump(me.network_get_demand(pos)))
end

---- Storage ----
