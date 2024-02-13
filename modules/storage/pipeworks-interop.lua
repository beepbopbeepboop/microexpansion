-- Interoperability file for pipework support.
local me = microexpansion

me.register_inventory("pipeworks:autocrafter", function(net, ctrl_inv, int_meta, n, pos)
  local meta = minetest.get_meta(n.pos)
  local rinv = meta:get_inventory()
  -- Autoinsert all the outputs
  --for i = 1, rinv:get_size("dst")
  --  local stack = rinv:get_stack("dst", i)
  --  local leftovers = me.insert_item(stack, net, ctrl_inv, "main")
  --  rinv:set_stack("dst", i, leftovers)
  --end
  -- register the crafted items so the autocrafter can use them
  local craft = rinv:get_stack("output", 1)
  if not craft:is_empty() then
    local hash = minetest.hash_node_position(pos)
    if not net.autocrafters_by_pos[hash] then
      net.autocrafters_by_pos[hash] = {}
    end
    local nhash = minetest.hash_node_position(n.pos)
    net.autocrafters_by_pos[hash][craft:get_name()] = nhash
    if not net.autocrafters[craft:get_name()] then
      net.autocrafters[craft:get_name()] = {}
    end
    net.autocrafters[craft:get_name()][nhash] = hash
  end
end)
