-- storage/api.lua

local BASENAME = "microexpansion"

--FIXME: either consolidate or forbid crafting with filled cells

-- [function] register cell
function microexpansion.register_cell(itemstring, def)
	if not def.inventory_image then
		def.inventory_image = itemstring
	end

	-- register craftitem
	minetest.register_craftitem(BASENAME..":"..itemstring, {
		description = def.description,
		inventory_image = BASENAME.."_"..def.inventory_image..".png",
		groups = {microexpansion_cell = 1},
		stack_max = 1,
		microexpansion = {
			base_desc = def.description,
			drive = {
				capacity = def.capacity or 5000,
			},
		},
	})

	-- if recipe, register recipe
	if def.recipe then
		microexpansion.register_recipe(BASENAME..":"..itemstring, def.recipe)
	end

	if microexpansion.uinv_category_enabled then
		unified_inventory.add_category_item("storage", BASENAME..":"..itemstring)
	end
end

-- [function] Get cell size
function microexpansion.get_cell_size(name)
	if minetest.get_item_group(name, "microexpansion_cell") == 0 then
		return 0
	end
	local item = minetest.registered_craftitems[name]
	return item.microexpansion.drive.capacity
end

-- [function] Calculate max stacks
function microexpansion.int_to_stacks(int)
	return math.ceil(int / 99)
end

-- [function] Calculate number of pages
function microexpansion.int_to_pagenum(int)
	return math.floor(microexpansion.int_to_stacks(int) / 32)
end

--[[ [function] Move items from inv to inv
function microexpansion.move_inv(inv1, inv2, max)
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
      if tinv and tinv:room_for_item(tname, v) then
        if huge then
          microexpansion.insert_item(v, tinv, tname)
          finv:remove_item(fname, v)
        else
          local leftover = tinv:add_item(tname, v)
          finv:remove_item(fname, v)
          if leftover and not(leftover:is_empty()) then
            microexpansion.log("leftover items when transferring inventory","warning")
            finv:add_item(fname, leftover)
          end
        end
        inserted = inserted + v:get_count()
      end
    end
  end
end
]]
