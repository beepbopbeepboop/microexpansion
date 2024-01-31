-- Interoperability file for drawers support.
local me = microexpansion

local S = function(d)
  return d
end

me.register_inventory("drawers:wood1", function(net, ctrl_inv, int_meta, n, pos, doinventories)
  if true then return end -- no loans yet
  if not doinventories then return end
  local c = drawers.drawer_get_content(n.pos, "")
  if c.name ~= "" and c.count > 1 then
    -- A poor man's locking system will have us never remove the last item from a drawer.
    c.count = c.count-1
    local stack = ItemStack(c.name)
    local bias = nil
    if c.count > math.pow(2,15) then -- assumes me.settings.huge_stacks == true
      bias = c.count - math.pow(2,15)
      c.count = math.pow(2,15)
    end
    stack:set_count(c.count)
    net:create_loan(stack, {pos=n.pos, drawer=true, slot="", ipos=pos}, ctrl_inv, int_meta, bias)
  end
  -- local rest = drawers.drawer_insert_object(n.pos, ItemStack("default:stone"), "")
  -- meta:set_int("count", meta:get_int("count")+1)
  -- drawers.remove_visuals(n.pos)
  -- drawers.spawn_visuals(n.pos)
end)

me.register_inventory("drawers:wood2", function(net, ctrl_inv, int_meta, n, pos, doinventories)
  if not doinventories then return end
  -- local c = drawers.drawer_get_content(n.pos, "")
  -- local rest = drawers.drawer_insert_object(n.pos, ItemStack("default:stone"), "")
end)

me.register_inventory("drawers:wood4", function(net, ctrl_inv, int_meta, n, pos, doinventories)
  if not doinventories then return end
  -- local c = drawers.drawer_get_content(n.pos, "")
  -- local rest = drawers.drawer_insert_object(n.pos, ItemStack("default:stone"), "")
end)

me.register_inventory("drawers:controller", function(net, ctrl_inv, int_meta, n, pos)
  -- inv:add_item("src", ItemStack("default:stone"))
end)

drawers.register_drawer_upgrade("microexpansion:upgrade_me64k", {
  description = S("Microexpansion Drawer Upgrade (x64*4)"),
  inventory_image = "drawers_upgrade_mithril.png",
  groups = {drawer_upgrade = 8000},
  recipe_item = "microexpansion:cell_64k"
})
