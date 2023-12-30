local me = microexpansion

local pipeworks_craft_time = 1

function me.autocraft_next_start(net)
  if net.pending then
    -- start subsequent autocrafting jobs sequentially.
    -- We really only need zero/not zero for build to queue actions or not
    return net.pending.time[net.pending.max_index]
  end
  return 0
end

function me.start_crafting(pos, step_time)
  local meta = minetest.get_meta(pos)
  local timer = minetest.get_node_timer(pos)
  timer:set(step_time, 0)
end

local function round(v)
  return math.floor(v + 0.5)
end

-- technic_plus doesn't export machine speed.  We
-- use this to know exactly how long a machine will take to process
-- anything, after that time, we know it is done and we can grab the
-- outputs, no polling. We do this for efficiency.
me.speed = {
  ["default:furnace"] = 1,
}

-- Use to wire in how long a machine takes to process something.
function me.set_speed(name, speed)
  me.speed[name] = speed
end

-- Sometimes the poor autocrafter doesn't have infinite input and output room
-- for a craft, break large ones up to fit.
-- Also machine inputs/outputs don't fit.
me.maximums = {
}

-- Allow a maximum craft to be defined to avoid overrunning machine
-- inputs and outputs and the autocrafter inputs and output..
function me.register_max(name, count)
  me.maximums[name] = count
end


local function build(net, cpos, inv, name, count, stack, sink, time)
  -- The autocrafters nor the machines can take really large amounts
  -- of things, help them out.
  local max = me.maximums[name]
  if not max then
    -- If no explicit max, assume this is a pipeworks autocrafter and
    -- it only has 12 outputs.
    max = stack:get_stack_max()*12
  end
  if max and count > max then
    local next_time = time
    local built = true
    while count > 1 and built do
      local substack = ItemStack(stack)
      max = math.min(max, count)
      substack:set_count(max)
      local step_time
      built, step_time = build(net, cpos, inv, name, max, substack, sink, next_time)
      if not built then
        -- we are done, can't craft, so stop
      else
        next_time = math.max(next_time, next_time + step_time)
      end
      count = count - max
    end
    local step_time = next_time - time
    return built, step_time
  end
  me.log("BUILD: count is "..count.." and stack size is "..stack:get_count(), "error")
  local dat = {}
  local second_output = nil
  if net.process and net.process[name] then
    dat.apos, dat.ipos = next(net.process[name])
    dat.rinv = minetest.get_meta(dat.apos):get_inventory()
    me.log("INT: looking up output "..name, "error")
    local inputs = me.find_by_output(name)
    local machine_name = minetest.get_node(dat.apos).name
    local typename = me.block_to_typename_map[machine_name]
    dat.recip = me.get_recipe(typename, inputs)
    me.log("MACHINE: "..machine_name.." typename is "..typename.." and time is "..tostring(dat.recip.time), "error")
    dat.recip.input = inputs
    -- freezer can produce two outputs, we only care about the first.
    if dat.recip.output[1] then
      second_output = dat.recip.output[2]
      dat.recip.output = dat.recip.output[1]
    end
    dat.ostack = ItemStack(dat.recip.output)
    -- me.log("SEE: "..machine_name.." "..minetest.serialize(technic.recipes))
    local speed = me.speed[machine_name]
    local craft_count = dat.ostack:get_count()
    local total = math.ceil(count/craft_count)
    -- crafting 4 carbon plates misses taking 1 carbin plate on output, make this bigger
    -- we'll try 1 for now, figure out right formula.  1 looks perfect
    dat.recip.time = round((total+1)*dat.recip.time/speed)
    if second_output then
      second_output = ItemStack(second_output)
      second_output:set_count(second_output:get_count()*total)
    end
    me.log("MACHINE: "..machine_name.." is speed "..speed.." and final time is "..dat.recip.time, "error")
  elseif net.autocrafters[name] then
    -- fill all recipe slots, wait, grab all output slots
    -- "src" "dst" "recipe" "output"
    dat.apos, dat.ipos = next(net.autocrafters[name])
    -- TODO: If we set up pipeworks ac, then we remove interface for it and craft
    -- it goes to ac, and dies here. Flush net.autocrafters for all the
    -- attached inventories during interface removal.
    dat.rinv = minetest.get_meta(dat.apos):get_inventory()
    if dat.rinv == nil then
      me.log("no inventory", "error")
      return
    end
    dat.ostack = dat.rinv:get_stack("output", 1)
    if dat.ostack:get_name() ~= name then
      -- invalidate it
      net.autocrafters[name][dat.apos] = nil
      -- me.log("invalidating autocrafter", "error")
      return
    end
  else
    me.log("can't craft a "..name, "error")
    return
  end
  dat.isink = function(sstack)
    me.log("TIMER: prep inputs, moving "..sstack:get_count().." "..sstack:get_name(), "error")
    return dat.rinv:add_item("src", sstack)
  end
  local craft_count = dat.ostack:get_count()
  -- These will be returned to the me system
  local extra = ItemStack(name)
  local total = math.ceil(count/craft_count)
  extra:set_count(total*craft_count - count)
  me.log("AC: count "..count.." craft_count "..craft_count.." extra "..extra:get_count(), "error");
  -- we craft a minimum of count, to the multiple of the crafting count
  count = total
  me.log("AC: numcount "..count, "error");
  
  local consume = {}
  if net.process and net.process[name] then
    for i = 1, #dat.recip.input do
    local inp = dat.recip.input[i]
    me.log("MID: consuming "..inp:get_name().." count: "..count.." inp:getcount: "..inp:get_count(), "error")
    consume[inp:get_name()] = (consume[inp:get_name()] or 0) + count*inp:get_count()
    end
  else
    for i = 1, 9 do
      local inp = dat.rinv:get_stack("recipe", i)
      if inp and not inp:is_empty() then
        consume[inp:get_name()] = (consume[inp:get_name()] or 0) + count*inp:get_count()
      end
    end
  end
  local replace = true
  local next_time = time
  me.log("PREP: pre count is "..count, "error")
  -- prepwork
  me.log("PREP: count is "..count, "error")
  local prepworkbits = {}
  local previous_ac_size = inv:get_size("ac")
  me.log("PREP: ac size at top is "..previous_ac_size, "error")
  for name, count in pairs(consume) do
    local istack = ItemStack(name)
    if count >= math.pow(2,16) then
      replace = false
      break
    end
    -- Don't consume the last item by autocrafting
    istack:set_count(count+1)
    local hasit = inv:contains_item("main", istack)
    istack:set_count(count)
    me.log("ac checking "..name, "error")
    if hasit then
      me.log("ac grabbing "..name, "error")
      local grabbed = me.remove_item(net, inv, "main", istack)
      if grabbed then
        me.log("ac grabbed "..name, "error")
	local slot = inv:get_size("ac")+1
	inv:set_size("ac", slot)
	inv:set_stack("ac", slot, grabbed)
	-- and later we do this:
	prepworkbits[function()
	  me.log("PREP: about to move "..name, "error")
	  local stack = inv:get_stack("ac", slot)
	  me.log("PREP: before move actual content of slot "..slot.." is "..stack:get_count().." "..stack:get_name(), "error")
          local leftovers = dat.rinv:add_item("src", stack)
	  me.log("PREP: post move into real inventory "..leftovers:get_count().." leftovers", "error")
	  me.log("PREP: did move "..name, "error")
	  inv:set_stack("ac", slot, leftovers)
	end] = name
	-- and then something moves the size of ac back to before we started
      end
    else
      -- Try and autocraft it
      me.log("AC: recursive crafting "..count.." "..istack:get_count(), "error")
      local built, step_time = build(net, cpos, inv, name, count, istack, dat.isink, time)
      if built then
	hasit = true
	next_time = math.max(next_time, time + step_time)
      else
        me.log("can't craft "..istack:get_count().." "..istack:get_name(), "error")
      end
    end
    replace = replace and hasit
  end
  local prepwork = function ()
    -- Do all the little bits of prepwork
    for func, name in pairs(prepworkbits) do
      me.log("PREPing: before "..name, "error")
      func()
      me.log("PREPing: done "..name, "error")
    end
  end
  -- end of prepwork
  if not replace then
    -- If we don't have everything, and can't craft it, we're stuck,
    -- do as much as we can, then nothing else
    me.log("missing items", "error")
    -- Existing items are already loaded.
    return
  end
  local main_action_time = count * pipeworks_craft_time + 1
  if net.process and net.process[name] then
    main_action_time = dat.recip.time + 1
  end
  local main_action = function() 
    me.log("ACTION: prep for "..stack:get_name(), "error")
    prepwork()
    -- and once we are done with all the postponed work, we can reduce "ac"
    -- lifetimes are more complex than you can imagine.
    -- We use a simple rule. When all done, there is nothing left. At that point,
    -- we can put any leftovers back into the main inventory.
    -- Even this might be too soon, if we have multiple independent crafts going, we
    -- need the last one.
    if previous_ac_size == 0 then
      for i = 1,inv:get_size("ac") do
        local stack = inv:get_stack("ac", i)
	if stack:get_count() ~= 0 then
	  me.log("AC: putting "..stack:get_count().." "..stack:get_name().." back into main inventory", "error")
	  local leftovers = me.insert_item(stack, net, inv, "main")
	  if leftovers:get_count() > 0 then
	    -- drop on floor, todo: play sound
            minetest.add_item(cpos, leftovers)
	  end
	end
      end
      me.log("PREP: ac size is now down to "..previous_ac_size, "error")
      inv:set_size("ac", previous_ac_size)
    end
    me.log("ACTION: main for "..stack:get_name(), "error")
    local rmeta = minetest.get_meta(dat.apos)

    -- Let's start up the crafter since we loaded it up to run
    if (net.process and net.process[name]) or rmeta:get_int("enabled") == 1 then
      local timer = minetest.get_node_timer(dat.apos)
      if not timer:is_started() then
	me.log("TIMER: starting ac now for "..stack:get_name(), "error")
        timer:start(pipeworks_craft_time)
      end
      me.log("TIMER: registering timer for "..stack:get_name(), "error")
      local action_time_step = count * pipeworks_craft_time + 1
      if net.process and net.process[name] then
        action_time_step = dat.recip.time + 1
      end
      local action = function(net)
        me.log("ACTION: post craft for "..stack:get_name(), "error")
        me.log("TIMER: moving "..stack:get_count().." "..stack:get_name(), "error")
        -- deal with output and replacements
	local dst_stack = dat.rinv:remove_item("dst", stack)
	if dst_stack:get_count() ~= stack:get_count() then
          me.log("wow, missing items that should have been crafted "..stack:get_name(), "error")
	  -- me.log("saw "..dst_stack:get_count().." items instead of "..stack:get_count().." items", "error")
	end
	if not dst_stack:is_empty() then
	  me.log("TIMER: inserting "..dst_stack:get_count().." "..dst_stack:get_name(), "error")
	  local leftovers = sink(dst_stack)
	  if leftovers and not leftovers:is_empty() then
	    me.log("autocrafter overflow, backpressuring", "error")
	    -- If any don't fit, back pressure on the crafter, we don't
	    -- mean to do this, and want to chunk the crafting items smaller
	    dat.rinv:add_item("dst", leftovers)
	  end
	end
	if not extra:is_empty() then
	  dst_stack = dat.rinv:remove_item("dst", extra)
	  if dst_stack:get_count() ~= extra:get_count() then
            me.log("wow, missing items that should have been crafted "..stack:get_name(), "error")
	    me.log("saw "..dst_stack:get_count().." items instead of "..extra:get_count().." items", "error")
	  end
	  if not dst_stack:is_empty() then
	    local leftovers = me.insert_item(dst_stack, net, inv, "main")
	    net:set_storage_space(true)
	    if leftovers and not leftovers:is_empty() then
	      me.log("autocrafter overflow, backpressuring", "error")
	      -- If any don't fit, back pressure on the crafter, we don't
	      -- mean to do this, and want to chunk the crafting items smaller
	      dat.rinv:add_item("dst", leftovers)
	    end
	  end
	end
	if second_output then
	  local second = dat.rinv:remove_item("dst", second_output)
	  if second and not second:is_empty() then
	    local leftovers = sink(second)
	    if leftovers and not leftovers:is_empty() then
	      me.log("autocrafter overflow, backpressuring", "error")
	      -- If any don't fit, back pressure on the crafter, we don't
	      -- mean to do this, and want to chunk the crafting items smaller
	      dat.rinv:add_item("dst", leftovers)
	    end
	  end
	end
        me.log("ACTION: done post craft for "..stack:get_name(), "error")
      end
      local net,cpos = me.get_connected_network(dat.ipos)
      me.later(net, cpos, action, next_time + action_time_step)
    end
    me.log("ACTION: main done for "..stack:get_name(), "error")
  end

  local net,cpos = me.get_connected_network(dat.ipos)
  -- queue main action for later
  me.log("LATER: main action for "..stack:get_name().." in "..next_time.." seconds", "error")
  me.later(net, cpos, main_action, next_time)

  -- The step time is the prep time and the main_action_time
  local step_time = next_time - time + main_action_time
  return true, step_time
end

-- time is absolute, starting from 0 from the front of a craft or
-- non-zero if a previous craft was running.
function me.later(net, cpos, action, time)
  if not net.pending then
    net.pending = {}
    net.pending.time = {}
  end
  local i = (net.pending.max_index or 0) + 1
  net.pending.max_index = i
  net.pending[i] = action
  net.pending.time[i] = time
  if not net.pending.index then
    net.pending.index = 1
  end
  if i == 1 then
    me.log("TIMER: starting timer to fire at "..time.." seconds", "error")
    me.start_crafting(cpos, time+0.1)
  else
    -- me.log("TIMER: did not start timer for later, index "..i.." at time "..time, "error")
    -- bubble sort the entry back to the right spot
    while i > 1 do
      -- me.log("TIME ds: "..i.." "..net.pending.time[i].." "..net.pending.time[i-1], "error")
      if net.pending.time[i] < net.pending.time[i-1] then
        -- if out of order, swap.  This works as previously the list was sorted
        local t = net.pending.time[i-1]
        net.pending.time[i-1] = net.pending.time[i]
	net.pending.time[i] = t
	t = net.pending[i-1]
	net.pending[i-1] = net.pending[i]
	net.pending[i] = t
	if i == 2 then
	  me.start_crafting(cpos, net.pending.time[1]+0.1)
	end
      else
        break
      end
      i = i - 1
    end
  end
end

function me.autocraft(autocrafterCache, cpos, net, linv, inv, count)
  local ostack = linv:get_stack("output", 1)
  local name = ostack:get_name()
  me.log("crafting "..name.." "..tostring(count), "error")

  local stack = ItemStack(name)
  local craft_count = ostack:get_count()
  me.log("auto: craft_count "..craft_count.." count "..count, "error")
  -- we craft a minimum of count, to the multiple of the crafting count
  count = math.ceil(count/craft_count)
  me.log("auto: count is now "..count, "error")
  stack:set_count(count*craft_count)
  me.log("auto: stack size is now "..stack:get_count(), "error")
  me.log("auto: and build count is "..(count*craft_count), "error")

  -- me.log("autocrafters: "..minetest.serialize(net.autocrafters), "error")

  if not net.process then
    -- rewalk the interfaces on the network to rebuild the machines.
    net:reload_network()
  end
  if net.autocrafters[name] or net.process[name] then
    me.log("using pipeworks autocrafter", "error")
    local sink = function(stack)
      local leftovers = me.insert_item(stack, net, inv, "main")
      net:set_storage_space(true)
      return leftovers
    end
    local start_time = me.autocraft_next_start(net)
    local built, step_time = build(net, cpos, inv, name, count*craft_count, stack, sink, start_time)
    if built then
      me.log("crafting "..stack:get_count().." "..stack:get_name().." in "..step_time.." seconds", "error")
    else
      me.log("can't craft "..stack:get_count().." "..stack:get_name(), "error")
    end
    return
  end

  me.log("using microexpansion autocrafter", "error")
  local consume = {}
  for i = 1, 9 do
    local inp = linv:get_stack("recipe", i)
    if inp and inp:get_name() ~= "" then
      consume[inp:get_name()] = (consume[inp:get_name()] or 0) + count*inp:get_count()
    end
  end
  local replace = true
  for name, count in pairs(consume) do
    local stack = ItemStack(name)
    if count >= math.pow(2,16) then
      replace = false
      break
    end
    -- Don't consume the last item by autocrafting
    stack:set_count(count+1)
    replace = replace and inv:contains_item("main", stack)
  end
  if replace then
    for name, count in pairs(consume) do
      local stack = ItemStack(name)
      stack:set_count(count)
      me.log("REMOVE: "..count.." "..stack:get_name(), "error")
      if not inv:contains_item("main", stack) then
        fixme1()
      end
      local ret = me.remove_item(net, inv, "main", stack)
      if ret:get_count() ~= stack:get_count() then
        me.log("AUTO: found "..(ret:get_count()).." "..(stack:get_name()).." but wanted "..stack:get_count(), "error")
        -- fixme2()
      end
    end
    local leftovers = me.insert_item(stack, net, inv, "main")
    if leftovers:get_count() > 0 then
      -- Ick, no room, just drop on the floor. Maybe player inventory?
      minetest.add_item(cpos, leftovers)
    end
    net:set_storage_space(true)
    -- deal with replacements
    local hash = minetest.hash_node_position(cpos)
    local craft = autocrafterCache[hash] or me.get_craft(cpos, linv, hash)
    for i = 1, 9 do
      if (craft.decremented_input.items[i]:get_count() ~= linv:get_stack("recipe", i):get_count()
	or craft.decremented_input.items[i]:get_name() ~= linv:get_stack("recipe", i):get_name())
	and not craft.decremented_input.items[i]:is_empty() then
	local leftovers = me.insert_item(craft.decremented_input.items[i], net, inv, "main")
	net:set_storage_space(true)
	if leftovers:get_count() > 0 then
	  -- Ick, no room, just drop on the floor. Maybe player inventory?
	  minetest.add_item(cpos, leftovers)
	end
      end
      if replace then
	linv:set_stack("output", 1, craft.output.item)
      else
	linv:set_list("output", {})
      end
    end
  end
end
