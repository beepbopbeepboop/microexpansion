-- microexpansion/modules/item_transfer/annihilation.lua

local me = microexpansion
local item_transfer = me.item_transfer
local access_level = microexpansion.constants.security.access_levels

local importer_timer = function(pos, elapsed)
  local net, cp = me.get_connected_network(pos)
  if not net then
    return false
  end
  local node = minetest.get_node(pos)
  local target = vector.add(pos, microexpansion.facedir_to_right_dir(node.param2))
  --TODO: allow setting list with upgrade
  local n = minetest.get_node(target)
  if n and n.name ~= "air" and n.name ~= "default:water_flowing" and n.name ~= "default:lava_flowing"
     and n.name ~= "default:river_water_flowing" then
    minetest.remove_node(target)
    local own_inv = minetest.get_meta(pos):get_inventory()
    local upgrades = me.count_upgrades(own_inv)
    local count = math.min(net:get_inventory_space(),math.pow(2, upgrades.bulk or 0))
    local list = "main"
    local inv = own_inv
    if count <= 0 then
      return true
    end
    if n.name ~= "default:stone" then
      count = 1
    end
    local stack = ItemStack(n.name)
    stack:set_count(count)
    inv:add_item(list, stack)
    local import_filter = function(stack)
      local stack_name = stack:get_name()
      if upgrades.filter then
        return not own_inv:contains_item("filter",stack:peek_item())
      end
      return false
    end
    me.move_inv(net, {inv=inv, name=list}, {inv=net:get_inventory(), name="main", huge=true}, count, import_filter)
    net:set_storage_space(true)
  end
  return true
end

-- [MicroExpansion Annihilation] Register node
item_transfer.register_io_device("annihilation", {
  description = "ME Annihilation Plane",
  usedfor = "Annihilates items and imports them into ME Networks",
  tiles = {
    "importer",
    "importer",
    "interface",
    "cable",
    "microexpansion_importer.png^[transform4",
    "importer",
  },
  drawtype = "nodebox",
  node_box = {
    type = "fixed",
    fixed = {
      {-0.5, -0.25, -0.25, 0.25,  0.25, 0.25},
      {0.25, -0.375, -0.375, 0.5,  0.375, 0.375},
    },
  },
  connect_sides = { "left" },
  recipe = {
    { 1, {
        {"", "basic_materials:ic", microexpansion.iron_ingot_ingredient },
        {"", "microexpansion:cable", "group:hoe" },
        {"", "", microexpansion.iron_ingot_ingredient },
      },
    },
    { 1, {
        {"", "microexpansion:logic_chip", microexpansion.iron_ingot_ingredient },
        {"", "microexpansion:cable", "group:hoe" },
        {"", "", microexpansion.iron_ingot_ingredient },
      },
    }
  },
  is_ground_content = false,
  groups = { crumbly = 1 },
  on_timer = importer_timer,
  on_construct = function(pos)
    local own_inv = minetest.get_meta(pos):get_inventory()
    own_inv:set_size("main", 1)
    item_transfer.setup_io_device("ME Annihilation Plane",pos)
    me.send_event(pos,"connect")
    item_transfer.update_timer_based(pos)
  end,
  after_destruct = function(pos)
    minetest.get_node_timer(pos):stop()
    me.send_event(pos,"disconnect")
  end,
  on_metadata_inventory_put = function(pos, listname, _, stack, player)
    if listname == "upgrades" then
      item_transfer.setup_io_device("ME Annihilation Plane",pos)
    end
  end,
  on_metadata_inventory_take = function(pos, listname, _, stack, player)
    if listname == "upgrades" then
      item_transfer.setup_io_device("ME Annihilation Plane",pos)
    end
  end
})

if me.uinv_category_enabled then
  unified_inventory.add_category_item("storage", "microexpansion:annihilation")
end
