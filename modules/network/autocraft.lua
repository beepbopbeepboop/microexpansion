local me = microexpansion

local pipeworks_craft_time = 1

function me.autocraft_next_start(net)
  -- We use machine reservations to allow simultaneous crafting jobs
  -- todo: implement a limiter or a power consumption or 'crafting
  -- cpus' for realism.
  local parallel = true
  if not parallel and net.pending then
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

-- This reserves a machine for length seconds. This is used to
-- schedule machines and know when they are done processing a job.
-- The jobs run sequentially. A 10 second job followed by a 5 second
-- job will finish at 15 seconds, not 5 seconds.  Return the new start
-- time.  todo: this solves the end and the outputs, but not the
-- inputs.  They can be overloaded and we might have to delay putting
-- things into the machine.
function me.reserve(net, hash, original_start, length)
  if not net.pending then
    net.pending = {}
    net.pending.time = {}
  end
  if not net.pending.busy then
    net.pending.busy = {}
  end
  local free_time = net.pending.busy[hash] or 0
  local start = math.max(free_time, original_start)
  local ending = start + length
  -- inputs and outputs can collide if we run them too close
  net.pending.busy[hash] = ending + 0.1
  --net:aclog(original_start, "Machine "..hash.." in use: "..free_time.." and needed for "..length.." finishing at "..(ending+0.0))
  return start
end

local length = function(a)
  local count = 0
  for k,v in pairs(a) do
    count = count + 1
  end
  return count
end

local defer_move = function(net, name, count, total, time, dat, inv, prepworkbits, grabbed)
  local slot = inv:get_size("ac")+1
  --me.log("SLOT: inv now has "..slot.." slots.", "error")
  --net:aclog(time, "  Did save "..grabbed:get_count().." "..grabbed:get_name().." into slot "..slot)
  inv:set_size("ac", slot)
  inv:set_stack("ac", slot, grabbed)
  -- and later we do this:
  local func = function(time)
    --me.log("PREP: about to move "..name, "error")
    local stack = inv:get_stack("ac", slot)
    --me.log("PREP: before move actual content of slot "..slot.." is "..stack:get_count().." "..stack:get_name(), "error")
    --net:aclog(time, "  Loading "..stack:get_count().." "..name.." from slot "..slot)
    local leftovers = 0
    for i = 1, #dat do
       -- todo: prove the below is correct.
       -- This spreads across evenly when craft_count is > 0 (stainless, carbon steel for example).
       local inner_stack = stack:take_item(count/total*math.floor((total+i-1)/#dat))
       leftovers = leftovers + dat[i].rinv:add_item("src", inner_stack):get_count()
    end
    stack = ItemStack(name)
    stack:set_count(leftovers)
    --me.log("PREP: post move into real inventory "..stack:get_count().." "..name.." leftovers", "error")
    if leftovers > 0 then
      net:aclog(time, "Machine was in use, backpressuring "..leftovers.." "..name)
    end
    inv:set_stack("ac", slot, stack)
  end
  prepworkbits[func] = name
end

local function trim(net, dat, total)
  local recip = dat[1].recip
  local ostack = dat[1].ostack
  dat[1].recip = nil
  dat[1].ostack = nil
  -- don't split stupidly small counts across machines, too much
  -- wasted time and too inefficient.
  --if total < 5 then total = 1 end

  -- we sort all available machines so we can use the least busy machines first
  if not net.pending then
    net.pending = {}
    net.pending.time = {}
  end
  if not net.pending.busy then
    net.pending.busy = {}
  end
  local key = function(r)
    return net.pending.busy[r.ahash] or 0
  end
  local cmp = function(a, b)
    return key(a) < key(b)
  end
  table.sort(dat, cmp)
  -- Remove the extra machines.
  while #dat > total do
    table.remove(dat)
  end
  dat[1].recip = recip
  dat[1].ostack = ostack
end

-- Testing: HV solar is realiable, big loans are screwy.
-- HV batteries are realiable.
local function build(net, cpos, inv, name, count, stack, iprepworkbits, sink, time)
  -- The autocrafters nor the machines can take really large amounts
  -- of things, help them out.
  local max = me.maximums[name]
  if not max then
    -- If no explicit max, assume this is a machine with 4 stacks of outputs.
    max = stack:get_stack_max()*4
  end
  if net.process and net.process[name] then
    max = max * length(net.process[name])
  elseif net.autocrafters[name] then
    -- autocrafters from pipeworks have a 12 slot output
    max = stack:get_stack_max()*12
    max = max * length(net.autocrafters[name])
  end
  --me.log("AC: max is "..max , "error")
  if max and count > max then
    local next_time = time
    local built = true
    while count > 1 and built do
      local substack = ItemStack(stack)
      max = math.min(max, count)
      substack:set_count(max)
      local step_time
      built, step_time = build(net, cpos, inv, name, max, substack, iprepworkbits, sink, next_time)
      if not built then
        -- we are done, can't craft, so stop
      else
	next_time = next_time + step_time
      end
      count = count - max
    end
    local step_time = next_time - time
    return built, step_time
  end
  --me.log("BUILD: count is "..count.." and stack size is "..stack:get_count(), "error")
  local dat = {}
  local second_output = nil
  local main_action_time = count * pipeworks_craft_time + 1.1
  if net.process and net.process[name] then
    local machines = net.process[name]
    for k, v in pairs(machines) do
      local apos = minetest.get_position_from_hash(k)
      local ipos = minetest.get_position_from_hash(v)
      local mname = minetest.get_node(apos).name
      if not me.block_to_typename_map[mname] then
        -- There is no way this can be. Prune.
	-- Would be nice if we had a way to notice blocks going away.
	-- Maybe latch into on_destruct for them?
	net.process[name][k] = nil
        goto continue
      end
      local i = #dat + 1
      dat[i] = {}
      dat[i].ahash = k
      dat[i].ihash = v
      dat[i].apos = apos
      dat[i].ipos = ipos
      dat[i].rinv = minetest.get_meta(dat[i].apos):get_inventory()
      ::continue::
    end
    --me.log("INT: looking up output "..name, "error")
    local inputs = me.find_by_output(name)
    local machine_name = minetest.get_node(dat[1].apos).name
    local typename = me.block_to_typename_map[machine_name]
    --me.log("Looking up "..(typename or "nil").." recipe for a "..(machine_name or nil), "error")
    dat[1].recip = me.get_recipe(typename, inputs)
    --me.log("MACHINE: "..machine_name.." typename is "..typename.." and time is "..tostring(dat[1].recip.time), "error")
    dat[1].recip.input = inputs
    -- freezer can produce two outputs, we only care about the first.
    if dat[1].recip.output[1] then
      second_output = dat[1].recip.output[2]
      dat[1].recip.output = dat[1].recip.output[1]
    end
    dat[1].ostack = ItemStack(dat[1].recip.output)
    -- me.log("SEE: "..machine_name.." "..minetest.serialize(technic.recipes))
    local speed = me.speed[machine_name] or 1
    local craft_count = dat[1].ostack:get_count()
    local total = math.ceil(count/craft_count)
    trim(net, dat, total)
    -- crafting 4 carbon plates misses taking 1 carbon plate on output, make this bigger
    -- we'll try 1 for now, figure out right formula.  1 looks perfect.  128 glue is short by 2
    -- 1  + 1 is a second too slow on the doped for 81., 2 +0 doesn't work, a second shy
    --main_action_time = round((total+2)*dat[1].recip.time/speed) + 1
    --main_action_time = (total+1)*round(dat[1].recip.time/speed) -- one shy
    --main_action_time = total*dat[1].recip.time/speed + 2 -- 2 at 80 shy, 3 at 160 shy
    local subtotal = math.floor((total+#dat-1)/#dat)
    --main_action_time = subtotal*1.025*dat[1].recip.time/speed + 2 -- ok
    --main_action_time = math.ceil(subtotal*1.02*dat[1].recip.time/speed) + 1 -- too fast?
    --main_action_time = math.ceil(subtotal*1.02*dat[1].recip.time/speed) + 1.2 -- too fast?
    --main_action_time = math.ceil((subtotal+1)*1.02*dat[1].recip.time/speed) + 1.2 -- too fast?
    main_action_time = math.ceil((subtotal+1)*1.04*dat[1].recip.time/speed) + 1.2 -- too fast?
    if second_output then
      second_output = ItemStack(second_output)
      second_output:set_count(second_output:get_count()*total)
    end
    --me.log("MACHINE: "..machine_name.." is speed "..speed.." and final time is "..main_action_time, "error")
  elseif net.autocrafters[name] then
    -- fill all recipe slots, wait, grab all output slots
    -- "src" "dst" "recipe" "output"
    local machines = net.autocrafters[name]
    for k, v in pairs(machines) do
      local i = #dat + 1
      dat[i] = {}
      dat[i].ahash = k
      dat[i].ihash = v
      dat[i].apos = minetest.get_position_from_hash(k)
      dat[i].ipos = minetest.get_position_from_hash(v)
      dat[i].rinv = minetest.get_meta(dat[i].apos):get_inventory()
      -- TODO: If we set up pipeworks ac, then we remove interface for it and craft
      -- it goes to ac, and dies here. Flush net.autocrafters for all the
      -- attached inventories during interface removal.
      if dat[i].rinv == nil then
        --me.log("no inventory", "error")
        return
      end
      dat[i].ostack = dat[i].rinv:get_stack("output", 1)
      if dat[i].ostack:get_name() ~= name then
        -- invalidate it
        net.autocrafters[name][dat[i].ahash] = nil
        --me.log("invalidating autocrafter for "..name, "error")
	table.remove(dat)
	if #dat == 0 then
          return
	end
      end
    end
    -- Consider looking up the recipe and finding the replacements that way.
    if name == "technic:copper_coil" or name == "technic:control_logic_unit"
       or name == "technic:solar_panel" then
      second_output = ItemStack("basic_materials:empty_spool 999")
    end
    local craft_count = dat[1].ostack:get_count()
    local total = math.ceil(count/craft_count)
    trim(net, dat, total)
    local subtotal = math.floor((total+#dat-1)/#dat)
    main_action_time = subtotal * pipeworks_craft_time + 1.1
  else
    me.log("can't craft a "..name, "error")
    return
  end
  local prepworkbits = {}
  local funcs = {}
  for i = 1, #dat do
    dat[i].isink = function(sstack, time)
      if dat[i].slots == true then
        -- if we have already run the final move, we can move in place directly.
	--net:aclog(time, "  Simple sink, about to move "..sstack:get_count().." "..sstack:get_name())
        local leftovers = dat[i].rinv:add_item("src", sstack)
        --net:aclog(time, "  Leftovers "..leftovers:get_count().." "..leftovers:get_name())
	return leftovers
      end
      local slot = inv:get_size("ac")+1
      --me.log("SLOT: inv now has "..slot.." slots.", "error")
      --net:aclog(time, "  For "..count.." "..name.." for machine "..i.." created slot "..slot)
      inv:set_size("ac", slot)
      if not dat[i].slots then
	dat[i].slots = {}
      end
      dat[i].slots[slot] = true
      --me.log("TIMER: prep inputs, moving "..sstack:get_count().." "..sstack:get_name(), "error")
      --net:aclog(time, "  Sinking "..sstack:get_count().." "..sstack:get_name().." for "..name.." into slot "..slot)
      inv:set_stack("ac", slot, sstack)
      return ItemStack()
    end
    funcs[i] = function(i, time)
      if not dat[i].slots then
        dat[i].slots = true
	return
      end
      for slot,_ in pairs(dat[i].slots) do
        local stack = inv:get_stack("ac", slot)
	--me.log("PREP: before move actual content of slot "..slot.." is "..stack:get_count().." "..stack:get_name(), "error")
        --net:aclog((time, "  About to move sunk "..stack:get_count().." "..stack:get_name()..", for "..count.." "..name.." from slot "..slot)
        local leftovers = dat[i].rinv:add_item("src", stack)
        --me.log("PREP: post move into real inventory "..stack:get_count().." "..name.." leftovers", "error")
        --net:aclog(time, "  Leftovers "..leftovers:get_count().." "..leftovers:get_name())
        if not leftovers:is_empty() then
          net:aclog(time, "Machine was in use, backpressuring "..leftovers:get_count().." "..name)
        end
        inv:set_stack("ac", slot, leftovers)
	--slot = 0
      end
      dat[i].slots = true
    end
  end
  prepworkbits[function(time)
    for i = 1, #dat do
      --net:aclog(time, "PREP2ing before "..name)
      funcs[i](i, time)
      --net:aclog(time, "PREP2ing after "..name)
    end
  end] = name
  local craft_count = dat[1].ostack:get_count()
  -- These will be returned to the me system
  local extra = ItemStack(name)
  local total = math.ceil(count/craft_count)
  extra:set_count(total*craft_count - count)
  --me.log("AC: count "..count.." craft_count "..craft_count.." extra "..extra:get_count(), "error");
  -- we craft a minimum of count, to the multiple of the crafting count
  count = total
  --me.log("AC: numcount "..count, "error");

  local consume = {}
  if net.process and net.process[name] then
    for i = 1, #dat[1].recip.input do
    local inp = dat[1].recip.input[i]
    --me.log("MID: consuming "..inp:get_name().." count: "..count.." inp:getcount: "..inp:get_count(), "error")
    --net:aclog(time, "    Consuming "..inp:get_count().." "..inp:get_name())
    consume[inp:get_name()] = (consume[inp:get_name()] or 0) + count*inp:get_count()
    end
  else
    for i = 1, 9 do
      -- TODO: This assumes that all the crafters have the same exact recipe.
      local inp = dat[1].rinv:get_stack("recipe", i)
      if inp and not inp:is_empty() then
        consume[inp:get_name()] = (consume[inp:get_name()] or 0) + count*inp:get_count()
      end
    end
  end
  local replace = true
  local next_time = {}
  for i = 1, #dat do
    next_time[i] = time
  end
  --me.log("RESERVE: "..name.." stime "..time.." step "..main_action_time.." reserve "..next_time[1], "error")
  --me.log("PREP: pre count is "..count, "error")
  -- prepwork
  --me.log("PREP: count is "..count, "error")
  local previous_ac_size = inv:get_size("ac")
  --me.log("PREP: ac size at top is "..previous_ac_size, "error")
  for name, count in pairs(consume) do
    local istack = ItemStack(name)
    if count >= math.pow(2,16) then
      replace = false
      break
    end
    istack:set_count(count)
    local hasit = inv:contains_item("main", istack)
    --me.log("ac checking "..name, "error")
    if hasit then
      --me.log("ac grabbing "..name, "error")
      local grabbed = me.remove_item(net, inv, "main", istack)
      if grabbed and grabbed:get_count() == count then
        --me.log("ac grabbed "..name, "error")
	net:aclog(time, " Grabbed "..count.." "..name)
	defer_move(net, name, count, total, time, dat, inv, prepworkbits, grabbed)
	-- and then something moves the size of ac back to before we started
      else
	--me.log("ac could not grab "..count.." "..name, "error")
	net:aclog(time, "Could not grab "..count.." "..name)
	hasit = false
      end
    else
      -- Try and autocraft it
      --me.log("AC: recursive crafting "..count.." "..istack:get_count(), "error")
      net:aclog(time, " Need to craft "..count.." "..name)
      hasit = true
      local final_step_time = 0
      for i = 1, #dat do
	-- todo: prove the below is correct.
	-- Does this spread across evenly when craft_count is > 0 (? for example)?
	-- I think this works, but it is slightly wasteful, but in a good way as
	-- 10 on 10 machines will each craft 1 on craft_count 2 item yielding 10 extra.
        local subcount = math.floor((count+i-1)/#dat)
	local inner_istack = ItemStack(istack)
	inner_istack:set_count(subcount)
        local built, step_time = build(net, cpos, inv, name, subcount, inner_istack, prepworkbits, dat[i].isink, time)
        if built then
	  next_time[i] = math.max(next_time[i], time + step_time)
	  --net:aclog(next_time[i], "recursive time for "..i.." is "..next_time[i])
	  final_step_time = math.max(final_step_time, step_time)
        else
	  hasit = false
        end
      end
      if hasit then
	net:aclog(time, "Craft "..count.." "..name.." in "..final_step_time.." seconds")
      else
	me.log("can't craft "..istack:get_count().." "..istack:get_name(), "error")
	net:aclog(time+final_step_time, "Can't craft "..count.." "..name)
      end
    end
    replace = replace and hasit
  end
  local prepwork = function (time)
    -- Do all the little bits of prepwork
    for func, name in pairs(prepworkbits) do
      --me.log("PREPing: before "..name, "error")
      --net:aclog(time, "PREPing before "..name)
      func(time)
      --me.log("PREPing: done "..name, "error")
      --net:aclog(time, "PREPing after "..name)
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
  local tmp_next_time = next_time
  next_time = 0
  for i = 1, #dat do
    -- We need to bump next time up to account for all machine reservations, use 0
    -- to merely find when the machine is free next. When all are free, that's when
    -- we start.
    next_time = math.max(next_time, me.reserve(net, dat[i].ahash, tmp_next_time[i], 0))
  end
  local actual_time = next_time
  --net:aclog(actual_time, " Actual time was "..actual_time)
  -- and reserve all of them til the end of the last one
  for i = 1, #dat do
    actual_time = math.max(actual_time, me.reserve(net, dat[i].ahash, next_time, main_action_time) + main_action_time)
  end
  --net:aclog(actual_time, " Actual endtime is "..actual_time)
  local main_action = function()
    --me.log("ACTION: prep for "..stack:get_name(), "error")
    net:aclog(next_time, "Now crafting "..name)
    prepwork(next_time)
    -- and once we are done with all the postponed work, we can reduce "ac"
    -- lifetimes are more complex than you can imagine.
    -- We use a simple rule. When all done, there is nothing left. At that point,
    -- we can put any leftovers back into the main inventory.
    -- Even this might be too soon, if we have multiple independent crafts going, we
    -- need the last one.
    if previous_ac_size == 0 and false then
      for i = 1,inv:get_size("ac") do
        local stack = inv:get_stack("ac", i)
	if stack:get_count() ~= 0 then
	  --me.log("AC: putting "..stack:get_count().." "..stack:get_name().." back into main inventory", "error")
	  local leftovers = me.insert_item(stack, net, inv, "main")
	  if not leftovers:is_empty() then
	    me.leftovers(cpos, leftovers)
	  end
	end
      end
      --me.log("PREP: ac size is now down to "..previous_ac_size, "error")
      inv:set_size("ac", previous_ac_size)
    end
    --me.log("ACTION: main for "..stack:get_name(), "error")
    for i = 1, #dat do
    local rmeta = minetest.get_meta(dat[i].apos)

    -- Let's start up the crafter since we loaded it up to run
    if (net.process and net.process[name]) or rmeta:get_int("enabled") == 1 then
      local timer = minetest.get_node_timer(dat[i].apos)
      if not timer:is_started() then
	--me.log("TIMER: starting ac now for "..stack:get_name(), "error")
        timer:start(pipeworks_craft_time)
      end
      --me.log("TIMER: registering timer for "..stack:get_name(), "error")
      local action_time_step = main_action_time
      local action = function(net)
        --me.log("ACTION: post craft for "..stack:get_name(), "error")
	local inner_stack = ItemStack(stack)
	-- todo: prove the below is correct.
	-- See extra below for how I think it fails.
	inner_stack:set_count(craft_count*math.floor((total+i-1)/#dat))
	if i == 1 and extra:get_count() > 0 then
	  inner_stack:take_item(extra:get_count())
	end
        --me.log("TIMER: moving "..inner_stack:get_count().." "..stack:get_name(), "error")
        -- deal with output and replacements
	local dst_stack = dat[i].rinv:remove_item("dst", inner_stack)
	local ctime = next_time+action_time_step
        net:aclog(ctime, "  Now done with "..name)
	if dst_stack:get_count() ~= inner_stack:get_count() then
          --me.log("wow, missing items that should have been crafted "..stack:get_name(), "error")
	  -- me.log("saw "..dst_stack:get_count().." items instead of "..inner_stack:get_count().." items", "error")
	  net:aclog(ctime, "Missing "..(inner_stack:get_count()-dst_stack:get_count()).." "..name..", only made "..dst_stack:get_count())
	end
	if not dst_stack:is_empty() then
	  --me.log("TIMER: inserting "..dst_stack:get_count().." "..dst_stack:get_name(), "error")
	  local leftovers = sink(dst_stack, ctime)
	  if leftovers and not leftovers:is_empty() then
	    --me.log("autocrafter overflow, backpressuring", "error")
	    net:aclog(ctime, "Backpressure of "..name)
	    -- If any don't fit, back pressure on the crafter, we don't
	    -- mean to do this, and want to chunk the crafting items smaller
	    dat[i].rinv:add_item("dst", leftovers)
	  end
	end
	if i == 1 and not extra:is_empty() then
	  -- extra is once, not per machine. It will appear in the
	  -- first machine as extra.
	  -- todo: extra I think is broken by switch the dst getter from being count based
	  -- to being total*craft count based.  This leaves extra when we need to craft
	  -- for a recipe that needs less than an even multiple of the craft_count.  Test, broken.
	  dst_stack = dat[i].rinv:remove_item("dst", extra)
	  if dst_stack:get_count() ~= extra:get_count() then
            --me.log("wow, missing items that should have been crafted "..stack:get_name(), "error")
	    --me.log("saw "..dst_stack:get_count().." items instead of "..extra:get_count().." items", "error")
	    net:aclog(ctime, "Missing "..(extra:get_count() - dst_stack:get_count()).." extra "..name)
	  end
	  if not dst_stack:is_empty() then
	    local leftovers = me.insert_item(dst_stack, net, inv, "main")
	    net:set_storage_space(true)
	    if leftovers and not leftovers:is_empty() then
	      --me.log("autocrafter overflow, backpressuring", "error")
	      net:aclog(ctime, "Backpressure of "..name)
	      -- If any don't fit, back pressure on the crafter, we don't
	      -- mean to do this, and want to chunk the crafting items smaller
	      dat[i].rinv:add_item("dst", leftovers)
	    end
	  end
	end
	if second_output then
	  local second = dat[i].rinv:remove_item("dst", second_output)
	  if second and not second:is_empty() then
	    local leftovers = me.insert_item(second, net, inv, "main")
	    if leftovers and not leftovers:is_empty() then
	      --me.log("autocrafter overflow, backpressuring", "error")
	      net:aclog(ctime, "Backpressure of "..name)
	      -- If any don't fit, back pressure on the crafter, we don't
	      -- mean to do this, and want to chunk the crafting items smaller
	      dat[i].rinv:add_item("dst", leftovers)
	    end
	  end
	end
        --me.log("ACTION: done post craft for "..stack:get_name(), "error")
      end
      local net,cpos = me.get_connected_network(dat[i].ipos)
      me.later(net, cpos, action, next_time + action_time_step)
    end
    end
    --me.log("ACTION: main done for "..stack:get_name(), "error")
  end

  local net,cpos = me.get_connected_network(dat[1].ipos)
  -- queue main action for later
  --me.log("LATER: main action for "..stack:get_name().." in "..next_time.." seconds", "error")
  me.later(net, cpos, main_action, next_time)

  local step_time = actual_time - time
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
    --me.log("TIMER: starting timer to fire at "..time.." seconds", "error")
    me.start_crafting(cpos, time+0.0)
  else
    -- me.log("TIMER: did not start timer for later, index "..i.." at time "..time, "error")
    -- bubble sort the entry back to the right spot
    while i > 1 do
      -- me.log("TIME ds: "..i.." "..net.pending.time[i].." "..net.pending.time[i-1], "error")
      if  tonumber(net.pending.time[i]) and tonumber(net.pending.time[i-1])
          and net.pending.time[i] < net.pending.time[i-1] then
        -- if out of order, swap.  This works as previously the list was sorted
        local t = net.pending.time[i-1]
        net.pending.time[i-1] = net.pending.time[i]
	net.pending.time[i] = t
	t = net.pending[i-1]
	net.pending[i-1] = net.pending[i]
	net.pending[i] = t
	if i == 2 then
	  me.start_crafting(cpos, net.pending.time[1]+0.0)
	end
      else
        break
      end
      i = i - 1
    end
  end
end

local recipe_is_empty = function(linv)
  for i = 1, 9 do
    local inp = linv:get_stack("recipe", i)
    if inp and not inp:is_empty() then
      return false
    end
  end
  return true
end

local lautocraft = function(autocrafterCache, cpos, net, linv, inv, count, stack)
  --me.log("using microexpansion autocrafter", "error")
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
    stack:set_count(count)
    replace = replace and inv:contains_item("main", stack)
  end
  if replace then
    for name, count in pairs(consume) do
      local stack = ItemStack(name)
      stack:set_count(count)
      --me.log("REMOVE: "..count.." "..stack:get_name(), "error")
      if not inv:contains_item("main", stack) then
        fixme1()
      end
      local ret = me.remove_item(net, inv, "main", stack)
      if ret:get_count() ~= stack:get_count() then
        --me.log("AUTO: found "..(ret:get_count()).." "..(stack:get_name()).." but wanted "..stack:get_count(), "error")
        -- fixme2()
      end
    end
    local leftovers = me.insert_item(stack, net, inv, "main")
    if not leftovers:is_empty() then
      me.leftovers(cpos, leftovers)
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
	if not leftovers:is_empty() then
	  me.leftovers(cpos, leftovers)
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

function me.autocraft(autocrafterCache, cpos, net, linv, inv, count)
  local ostack = linv:get_stack("output", 1)
  local name = ostack:get_name()
  --me.log("crafting "..name.." "..tostring(count), "error")

  local stack = ItemStack(name)
  local craft_count = ostack:get_count()
  --me.log("auto: craft_count "..craft_count.." count "..count, "error")
  -- we craft a minimum of count, to the multiple of the crafting count
  count = math.ceil(count/craft_count)
  --me.log("auto: count is now "..count, "error")
  stack:set_count(count*craft_count)
  --me.log("auto: stack size is now "..stack:get_count(), "error")
  --me.log("auto: and build count is "..(count*craft_count), "error")

  -- me.log("autocrafters: "..minetest.serialize(net.autocrafters), "error")

  if not recipe_is_empty(linv) then
    lautocraft(autocrafterCache, cpos, net, linv, inv, count, stack)
  end

  if not net.process then
    -- rewalk the interfaces on the network to rebuild the machines.
    net:reload_network()
  end
  if net.autocrafters[name] or net.process[name] then
    --me.log("Using pipeworks autocrafter", "error")
    if not net.pending or not net.ac_status then
      net.ac_status = ""
    end
    local start_time = me.autocraft_next_start(net) or 0
    net:aclog(start_time, "\nUsing pipeworks autocrafter")
    local sink = function(stack, time)
      local leftovers = me.insert_item(stack, net, inv, "main")
      net:set_storage_space(true)
      return leftovers
    end
    local built, step_time = build(net, cpos, inv, name, count*craft_count, stack, nil, sink, start_time)
    if built then
      --me.log("crafting "..stack:get_count().." "..stack:get_name().." in "..step_time.." seconds", "error")
      net:aclog(start_time, "Crafting "..(count*craft_count).." "..name.." in "..step_time.." seconds")
    else
      --me.log("can't craft "..stack:get_count().." "..stack:get_name(), "error")
      net:aclog(start_time, "Can't craft "..(count*craft_count).." "..name)
    end
    return
  end
end
