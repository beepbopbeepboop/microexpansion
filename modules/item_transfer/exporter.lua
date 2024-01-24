-- microexpansion/machines.lua

local me = microexpansion
local item_transfer = me.item_transfer
local access_level = microexpansion.constants.security.access_levels

local function exporter_timer(pos, elapsed)
  local net, cp = me.get_connected_network(pos)
  if not net then
    return false
  end
  local node = minetest.get_node(pos)
  local target = vector.add(pos, microexpansion.facedir_to_right_dir(node.param2))
  --TODO: allow setting list with control upgrade
  --TODO: perhaps allow setting limits with control upgrade
  local list, inv = item_transfer.get_input_inventory(target)
  if list then
    --TODO: move more with upgrades
    local own_inv = minetest.get_meta(pos):get_inventory()
    local upgrades = me.count_upgrades(own_inv)
    local export_filter = upgrades.filter and function(stack)
      return not own_inv:contains_item("filter",stack:peek_item())
    end
    local max_count = math.pow(2, upgrades.bulk or 0)
    microexpansion.move_inv({inv=net:get_inventory(),name="main",huge=true}, {inv=inv,name=list}, max_count, export_filter)
    --TODO: perhaps call allow_insert and on_insert callbacks
  end
  return true
end

-- [MicroExpansion Exporter] Register node
item_transfer.register_io_device("exporter", {
  description = "ME exporter",
  usedfor = "Exports items from ME Networks into machines",
  tiles = {
    "exporter",
    "exporter",
    "interface",
    "cable",
    "microexpansion_exporter.png^[transform4",
    "exporter",
  },
  drawtype = "nodebox",
  node_box = {
    --perhaps convert to connectable
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
        {"", "microexpansion:cable", "group:shovel" },
        {"", "", microexpansion.iron_ingot_ingredient },
      },
    },
    { 1, {
        {"", "microexpansion:logic_chip", microexpansion.iron_ingot_ingredient },
        {"", "microexpansion:cable", "group:shovel" },
        {"", "", microexpansion.iron_ingot_ingredient },
      },
    }
  },
  groups = { crumbly = 1 },
  on_timer = exporter_timer,
  on_construct = function(pos)
    item_transfer.setup_io_device("ME Exporter",pos)
    me.send_event(pos,"connect")
    --perhaps write a propper update self function
    item_transfer.update_timer_based(pos,nil,{type="construct"})
  end,
  after_destruct = function(pos)
    minetest.get_node_timer(pos):stop()
    me.send_event(pos,"disconnect")
  end,
  on_metadata_inventory_put = function(pos, listname, _, stack, player)
    if listname == "upgrades" then
      item_transfer.setup_io_device("ME Exporter",pos)
    end
  end,
  on_metadata_inventory_take = function(pos, listname, _, stack, player)
    if listname == "upgrades" then
      item_transfer.setup_io_device("ME Exporter",pos)
    end
  end
})

if me.uinv_category_enabled then
  unified_inventory.add_category_item("storage", "microexpansion:exporter")
end
