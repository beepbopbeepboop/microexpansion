local me       = microexpansion
me.networks    = {}
local networks = me.networks
local path     = microexpansion.get_module_path("network")
local storage  = minetest.get_mod_storage()

dofile(path.."/constants.lua")

--deprecated: use ItemStack(x) instead
--[[
local function split_stack_values(stack)
  if type(stack) == "string" then
    local split_string = stack:split(" ")
    if (#split_string < 1) then
      return "",0,0,nil
    end
    local stack_name = split_string[1]
    if (#split_string < 2) then
      return stack_name,1,0,nil
    end
    local stack_count = tonumber(split_string[2])
    if (#split_string < 3) then
      return stack_name,stack_count,0,nil
    end
    local stack_wear = tonumber(split_string[3])
    if (#split_string < 4) then
      return stack_name,stack_count,stack_wear,nil
    end
    return stack_name,stack_count,stack_wear,true
  else
    return stack:get_name(), stack:get_count(), stack:get_wear(), stack:get_meta()
  end
end
--]]

function me.insert_item(stack, net, inv, listname)
  if me.settings.huge_stacks == false then
    return inv:add_item(listname, stack)
  end
  local to_insert = type(stack) == "userdata" and stack or ItemStack(stack)
  local found = false
  for i = 0, inv:get_size(listname) do
    local inside = inv:get_stack(listname, i)
    if inside:get_name() == to_insert:get_name() and inside:get_wear() == to_insert:get_wear() then
      if inside:get_meta():equals(to_insert:get_meta()) then
        local total_count = inside:get_count() + to_insert:get_count()
        -- bigger item count is not possible, we only have unsigned 16 bit
        if total_count <= math.pow(2,16) then
          if not inside:set_count(total_count) then
            microexpansion.log("adding items to stack in microexpansion network failed","error")
            print("stack is now " .. inside:to_string())
          end
          inv:set_stack(listname, i, inside)
          found = true
          break;
        end
      end
    end
  end
  if not found then
    return inv:add_item(listname, stack)
  end
  return ItemStack(), slot
end

function me.remove_item(net, inv, listname, stack)
  return inv:remove_item(listname, stack)
end

dofile(path.."/loan.lua") -- Loan Management
dofile(path.."/network.lua") -- Network Management
dofile(path.."/autocraft.lua") -- Autocrafting

-- generate iterator to find all connected nodes
function me.connected_nodes(start_pos,include_ctrl)
  -- nodes to be checked
  local open_list = {{pos = start_pos}}
  -- nodes that were checked
  local closed_set = {}
  -- local connected nodes function to reduce table lookups
  local adjacent_connected_nodes = me.network.adjacent_connected_nodes
  -- return the generated iterator
  return function ()
    -- start looking for next pos
    local open = false
    -- pos to be checked
    local current
    -- find next unclosed
    while not open do
      -- get unchecked pos
      current = table.remove(open_list)
      -- none are left
      if current == nil then return end
      -- assume it's open
      open = true
      -- check the closed positions
      for _,closed in pairs(closed_set) do
        -- if current is unclosed
        if vector.equals(closed,current.pos) then
          --found one was closed
          open = false
        end
      end
    end
    -- get all connected nodes
    local nodes = adjacent_connected_nodes(current.pos,include_ctrl)
    -- iterate through them
    for _,n in pairs(nodes) do
      -- mark position to be checked
      table.insert(open_list,n)
    end
    -- add this one to the closed set
    table.insert(closed_set,current.pos)
    -- return the one to be checked
    return current.pos,current.name
  end
end

-- get network connected to position
function me.get_connected_network(start_pos)
  for npos,nn in me.connected_nodes(start_pos,true) do
    if nn == "microexpansion:ctrl" then
      local source = minetest.get_meta(npos):get_string("source")
      local network
      if source == "" then
        network = me.get_network(npos)
      else
        network = me.get_network(vector.from_string(source))
      end
      if network then
        return network,npos
      end
    end
  end
end

function me.promote_controller(start_pos,net)
  local promoted = false
  for npos,nn in me.connected_nodes(start_pos,true) do
    if nn == "microexpansion:ctrl" and npos ~= start_pos then
      if promoted then
        minetest.get_meta(npos):set_string("source", promoted)
      else
        promoted = vector.to_string(npos)
        minetest.get_meta(npos):set_string("source", "")
        net.controller_pos = npos
      end
    end
  end
  return promoted and true or false
end

function me.update_connected_machines(start_pos,event,include_start)
  microexpansion.log("updating connected machines","action")
  local ev = event or {type = "n/a"}
  local sn = microexpansion.get_node(start_pos)
  local sd = minetest.registered_nodes[sn.name]
  local sm = sd.machine or {}
  ev.origin = {
    pos = start_pos,
    name = sn.name,
    type = sm.type
  }
  --print(dump2(ev,"event"))
  for npos in me.connected_nodes(start_pos) do
    if include_start or not vector.equals(npos,start_pos) then
      me.update_node(npos,ev)
    end
  end
end

function me.send_event(spos,type,data)
  local d = data or {}
  local event = {
    type = type,
    net = d.net,
    payload = d.payload
  }
  me.update_connected_machines(spos,event,false)
end

function me.get_network(pos)
  for i,net in pairs(networks) do
    if net.controller_pos then
      if vector.equals(pos, net.controller_pos) then
        return net,i
      end
    end
  end
end

dofile(path.."/ctrl.lua") -- Controller/wires
dofile(path.."/security.lua") --Security Terminal

-- load networks
function me.load()
  local res = storage:get_string("networks")
  if res == "" then
    local f = io.open(me.worldpath.."/microexpansion_networks", "r")
    if f then
      me.log("loading network data from file","action")
      res = minetest.deserialize(f:read("*all"))
      f:close()
    else
      me.log("no network data loaded","action")
      return
    end
  else
    me.log("loading network data from mod storage","action")
    res = minetest.deserialize(res)
  end
  if type(res) == "table" then
    for _,n in pairs(res) do
     local net = me.network.new(n)
     net:load()
     table.insert(me.networks,net)
    end
  else
    me.log("network data in unexpected format","error")
  end
end

-- load now
me.load()

-- save networks
function me.save()
  local data = {}
  for _,v in pairs(me.networks) do
    table.insert(data,v:serialize())
  end
  if storage then
    me.log("saving network data to mod storage","info")
    storage:set_string("networks", minetest.serialize(data))
  else
    me.log("saving network data to file","info")
    local f = io.open(me.worldpath.."/microexpansion_networks", "w")
    f:write(minetest.serialize(data))
    f:close()
  end
end

function me.do_autosave()
  me.last_autosave = -1
  minetest.after(1, function()
    --print("autosaving ME Networks")
    me.save()
    me.last_autosave = minetest.get_server_uptime()
  end)
end

function me.autosave()
  --TODO: make max autosave interval settable
  if not me.last_autosave then
    me.do_autosave()
  elseif me.last_autosave == -1 then
    return
  elseif minetest.get_server_uptime() - me.last_autosave >= 600 then
    me.do_autosave()
  end
end

-- save on server shutdown
minetest.register_on_shutdown(me.save)
