local me       = microexpansion
local loan = {
}
me.loan = loan

function me.loan.get_stack(net, inv, loan_slot)
  local lstack = inv:get_stack("loan", loan_slot)
  return lstack
end

function me.loan.set_stack(net, inv, loan_slot, lstack)
  inv:set_stack("loan", loan_slot, lstack)
end

function me.loan.get_size(net, inv)
  return inv:get_size("loan")
end

function me.loan.set_size(net, inv, size)
  return inv:set_size("loan", size)
end

function me.loan.bump_loan(net, inv, loan_slot, remaining, addition_real_loaned)
  local lstack = me.loan.get_stack(net, inv, loan_slot)
  local ref
  local real_count
  if lstack:is_empty() then
    -- TODO: should never happen, verify and remove
    return
  end
  ref = me.network.get_ref(lstack)
  real_count = nil
  local prev_lstack_count = lstack:get_count()
  if ref.drawer then
    local stack = ItemStack(lstack)
    -- the drawer api only allow up to 2^16-1, ask them for a better api, 2^48 max
    local count = math.pow(2,16)-1
    -- ensure that lstack:get_count() + spare below is at most 2^16-1
    count = math.min(count, math.pow(2,16)-1 - lstack:get_count())
    -- ensure at most 2^16-1 as the stack api doesn't allow more
    count = math.min(count, remaining)
    -- if the loan size is already  maximal, then we can't update the loan any
    if count > 0 then
      stack:set_count(count)

      -- bump up the actual inventory, spare is how many fit
      local excess = drawers.drawer_insert_object(ref.pos, stack, ref.slot)
      local spare = count - excess:get_count()

      -- bump loan by spare
      lstack:set_count(lstack:get_count() + spare)
      me.log("LOAN: bump_loan to "..lstack:get_count(), "error")
      me.loan.set_stack(net, inv, loan_slot, lstack)
      net.counts[lstack:get_name()] = net.counts[lstack:get_name()] + spare
      me.log("COUNT: loan now to "..net.counts[lstack:get_name()].." "..lstack:get_name()..", "..spare.." more", "error")
      me.log("LOAN: adril "..addition_real_loaned.." loan "..prev_lstack_count.." and adjustment(spare) "..spare, "error")
      addition_real_loaned = math.min(addition_real_loaned, spare)
      me.add_capacity(ref.ipos, addition_real_loaned)

      -- reduce remaining by spare
      remaining = remaining - spare
    end
  else
    local rinv = minetest.get_meta(ref.pos):get_inventory()
    local real_stack = rinv:get_stack(ref.invname, ref.slot)
    local max = real_stack:get_stack_max()
    if real_stack:get_count() < max then
      local spare = max - real_stack:get_count()
      spare = math.min(spare, remaining)
      -- me.log("bumping "..lstack:get_name().." by "..spare, "error")

      -- bump up the actual inventory by spare
      real_stack:set_count(real_stack:get_count() + spare)
      rinv:set_stack(ref.invname, ref.slot, real_stack)

      -- bump loan by spare
      lstack:set_count(lstack:get_count() + spare)
      -- me.log("bumping "..lstack:get_name().." to "..lstack:get_count(), "error")
      me.log("LOAN: bump_loan to "..lstack:get_count(), "error")
      me.loan.set_stack(net, inv, loan_slot, lstack)
      -- me.log("COUNTS: "..minetest.serialize(net.counts), "error")
      net.counts[lstack:get_name()] = net.counts[lstack:get_name()] + spare
      me.log("COUNT: bump_loan loan now to "..net.counts[lstack:get_name()].." "..lstack:get_name()..", "..spare.." more", "error")
      me.log("LOAN: adril "..addition_real_loaned.." loan "..prev_lstack_count.." and adjustment(spare) "..spare, "error")
      addition_real_loaned = math.min(addition_real_loaned, spare)
      me.add_capacity(ref.ipos, addition_real_loaned)

      -- reduce remaining by spare
      remaining = remaining - spare
    end
  end
  -- This code is misguided.  We've already added them as real, we can
  -- only add them to a loan if those items are added to that
  -- inventory being loaded.  This is only possible if there is room.
  if false and remaining > 0 then
    if not net.bias then
      net.bias = {}
    end
    if not net.bias["loan"] then
      net.bias["loan"] = {}
    end
    if not net.bias["loan"][loan_slot] then
      net.bias["loan"][loan_slot] = 0
    end
    net.bias["loan"][loan_slot] = net.bias["loan"][loan_slot] + remaining
    me.log("LARGE: bump_loan bias is "..net.bias["loan"][loan_slot].." "..lstack:get_name()..", "..remaining.." more", "error")
  end
end
