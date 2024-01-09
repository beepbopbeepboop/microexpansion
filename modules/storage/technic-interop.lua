-- Interoperability file for technic and technic_plus support.
local me = microexpansion


-- technic_plus doesn't export machine speed, so wire it in here.  We
-- use this to know exactly how long a machine will take to process
-- anything, after that time, we know it is done and we can grab the
-- outputs, no polling. We do this for efficiency.

-- The speeds of the various machines:
me.set_speed("technic:electric_furnace", 2)
me.set_speed("technic:mv_electric_furnace", 4)
me.set_speed("technic:hv_electric_furnace", 12)
me.set_speed("technic:lv_alloy_furnace", 1)
me.set_speed("technic:mv_alloy_furnace", 1.5)
me.set_speed("technic:lv_compressor", 1)
me.set_speed("technic:mv_compressor", 2)
me.set_speed("technic:hv_compressor", 5)
me.set_speed("technic:lv_extractor", 1)
me.set_speed("technic:mv_extractor", 2)
me.set_speed("technic:lv_grinder", 1)
me.set_speed("technic:mv_grinder", 2)
me.set_speed("technic:hv_grinder", 5)
me.set_speed("technic:mv_centrifuge", 2)
me.set_speed("technic:mv_freezer", 0.5)

-- ======================================================================== --


-- Register maximal output sizes for all the ingredients we produce.
-- We also break up deeply recursive crafts that would blow a pipeworks

-- autocrafter if it tried to make something.
-- might not be necessary, but maybe it is.  It might limit
-- oversupply of inputs to batteries.
me.register_max("technic:lv_battery_box0", 3)
me.register_max("technic:battery", 12)

-- HV furnace only has 4 output slots
me.register_max("technic:cast_iron_ingot", 380)
me.register_max("mesecons_materials:glue", 380)
me.register_max("mesecons_materials:fiber", 380)
me.register_max("default:stone", 380)
me.register_max("basic_materials:plastic_sheet", 380)
me.register_max("basic_materials:paraffin", 380)

-- HV grinder only has 4 output slots
me.register_max("technic:coal_dust", 380)
me.register_max("technic:gold_dust", 380)
me.register_max("technic:sulfur_dust", 380)
me.register_max("technic:stone_dust", 380)
me.register_max("default:gravel", 380)
me.register_max("default:sand", 380)
me.register_max("default:snowblock", 380)
me.register_max("technic:rubber_tree_grindings", 380)

-- MV alloy furnace only has 4 output slots
me.register_max("technic:doped_silicon_wafer", 380)
me.register_max("technic:silicon_wafer", 380)
me.register_max("basic_materials:brass_ingot", 380)
me.register_max("default:bronze_ingot", 380)
me.register_max("technic:stainless_steel_ingot", 380)
me.register_max("technic:rubber", 380)
me.register_max("bucket:bucket_lava", 4)
me.register_max("technic:carbon_steel_ingot", 380)

-- LV extractor only has 4 output slots
me.register_max("technic:raw_latex", 380)

-- HV compressor only has 4 output slots
me.register_max("technic:composite_plate", 380)
me.register_max("technic:copper_plate", 380)
me.register_max("technic:graphite", 380)
me.register_max("technic:carbon_plate", 380)
me.register_max("technic:uranium_fuel", 380)
me.register_max("default:diamond", 380)

-- freezer only has 4 output slots
me.register_max("default:ice", 380)

-- ======================================================================== --


-- The type of machines all the machines are: We have to list these
-- before me.register_inventory.
me.register_typename("technic:electric_furnace", "cooking")
me.register_typename("technic:mv_electric_furnace", "cooking")
me.register_typename("technic:hv_electric_furnace", "cooking")
me.register_typename("technic:lv_grinder", "grinding")
me.register_typename("technic:mv_grinder", "grinding")
me.register_typename("technic:hv_grinder", "grinding")
me.register_typename("technic:coal_alloy_furnace", "alloy")
me.register_typename("technic:lv_alloy_furnace", "alloy")
me.register_typename("technic:mv_alloy_furnace", "alloy")
me.register_typename("technic:lv_extractor", "extracting")
me.register_typename("technic:mv_extractor", "extracting")
me.register_typename("technic:lv_compressor", "compressing")
me.register_typename("technic:mv_compressor", "compressing")
me.register_typename("technic:hv_compressor", "compressing")
me.register_typename("technic:mv_centrifuge", "separating")
me.register_typename("technic:mv_freezer", "freezing")

-- We need active nodes defined as well, as the recipe system doesn't otherwise have
-- recipes for them.
me.register_machine_alias("technic:electric_furnace_active", "technic:electric_furnace")
me.register_machine_alias("technic:mv_electric_furnace_active", "technic:mv_electric_furnace")
me.register_machine_alias("technic:hv_electric_furnace_active", "technic:hv_electric_furnace")
me.register_machine_alias("technic:lv_grinder_active", "technic:lv_grinder")
me.register_machine_alias("technic:mv_grinder_active", "technic:mv_grinder")
me.register_machine_alias("technic:hv_grinder_active", "technic:hv_grinder")
me.register_machine_alias("technic:coal_alloy_furnace_active", "technic:coal_alloy_furnace")
me.register_machine_alias("technic:lv_alloy_furnace_active", "technic:lv_alloy_furnace")
me.register_machine_alias("technic:mv_alloy_furnace_active", "technic:mv_alloy_furnace")
me.register_machine_alias("technic:lv_extractor_active", "technic:lv_extractor")
me.register_machine_alias("technic:mv_extractor_active", "technic:mv_extractor")
me.register_machine_alias("technic:lv_compressor_active", "technic:lv_compressor")
me.register_machine_alias("technic:mv_compressor_active", "technic:mv_compressor")
me.register_machine_alias("technic:hv_compressor_active", "technic:hv_compressor")
me.register_machine_alias("technic:mv_centrifuge_active", "technic:mv_centrifuge")
me.register_machine_alias("technic:mv_freezer_active", "technic:mv_freezer")

-- ======================================================================== --


-- The various blocks and how to interface to them:
me.register_inventory("technic:gold_chest", me.chest_reload)
me.register_inventory("technic:mithril_chest", me.chest_reload)

me.register_inventory("technic:quarry", function(net, ctrl_inv, int_meta, n, pos)
  local meta = minetest.get_meta(n.pos)
  local rinv = meta:get_inventory()
  for i = 1, rinv:get_size("cache") do
    local stack = rinv:get_stack("cache", i)
    if not stack:is_empty() then
      local leftovers = me.insert_item(stack, net, ctrl_inv, "main")
      rinv:set_stack("cache", i, leftovers)
    end
  end
  -- we can set up a timer to recheck the cache every 30 seconds and
  -- clean it out for example.
end)

me.register_inventory("technic:mv_centrifuge", function(net, ctrl_inv, int_meta, n, pos)
  local meta = minetest.get_meta(n.pos)
  local rinv = meta:get_inventory()
  for i = 1, rinv:get_size("dst") do
    local stack = rinv:get_stack("dst", i)
    if not stack:is_empty() then
      local leftovers = me.insert_item(stack, net, ctrl_inv, "main")
      rinv:set_stack("dst", i, leftovers)
    end
  end
  for i = 1, rinv:get_size("dst2") do
    local stack = rinv:get_stack("dst2", i)
    if not stack:is_empty() then
      local leftovers = me.insert_item(stack, net, ctrl_inv, "main")
      rinv:set_stack("dst2", i, leftovers)
    end
  end
end)

-- ======================================================================== --


-- The various outputs the various machine types can generate:
me.register_output_by_typename("cooking", "default:copper_ingot")
me.register_output_by_typename("cooking", "default:gold_ingot")
me.register_output_by_typename("cooking", "default:steel_ingot")
me.register_output_by_typename("cooking", "default:tin_ingot")
me.register_output_by_typename("cooking", "technic:chromium_ingot")
--me.register_output_by_typename("cooking", "technic:uranium_ingot")
me.register_output_by_typename("cooking", "technic:zinc_ingot")
me.register_output_by_typename("cooking", "technic:lead_ingot")
me.register_output_by_typename("cooking", "technic:cast_iron_ingot")
me.register_output_by_typename("cooking", "mesecons_materials:glue")
me.register_output_by_typename("cooking", "mesecons_materials:fiber")
me.register_output_by_typename("cooking", "basic_materials:plastic_sheet")
me.register_output_by_typename("cooking", "basic_materials:paraffin")
me.register_output_by_typename("cooking", "moreores:silver_ingot")

me.register_output_by_typename("grinding", "technic:coal_dust")
me.register_output_by_typename("grinding", "technic:copper_dust")
me.register_output_by_typename("grinding", "technic:gold_dust")
me.register_output_by_typename("grinding", "technic:wrought_iron_dust")
me.register_output_by_typename("grinding", "technic:tin_dust")
me.register_output_by_typename("grinding", "technic:chromium_dust")
--me.register_output_by_typename("grinding", "technic:uranium_dust")
me.register_output_by_typename("grinding", "technic:zinc_dust")
me.register_output_by_typename("grinding", "technic:lead_dust")
me.register_output_by_typename("grinding", "technic:sulfur_dust")
me.register_output_by_typename("grinding", "technic:stone_dust")
me.register_output_by_typename("grinding", "default:gravel")
me.register_output_by_typename("grinding", "default:sand")
me.register_output_by_typename("grinding", "default:snowblock")
me.register_output_by_typename("grinding", "technic:rubber_tree_grindings")
me.register_output_by_typename("grinding", "technic:silver_dust")

me.register_output_by_typename("alloy", "technic:doped_silicon_wafer")
me.register_output_by_typename("alloy", "technic:silicon_wafer")
me.register_output_by_typename("alloy", "basic_materials:brass_ingot")
me.register_output_by_typename("alloy", "default:bronze_ingot")
me.register_output_by_typename("alloy", "technic:stainless_steel_ingot")
me.register_output_by_typename("alloy", "technic:rubber")
me.register_output_by_typename("alloy", "bucket:bucket_lava")
me.register_output_by_typename("alloy", "technic:carbon_steel_ingot")

me.register_output_by_typename("extracting", "technic:raw_latex")

me.register_output_by_typename("compressing", "technic:composite_plate")
me.register_output_by_typename("compressing", "technic:copper_plate")
me.register_output_by_typename("compressing", "technic:graphite")
me.register_output_by_typename("compressing", "technic:carbon_plate")
me.register_output_by_typename("compressing", "technic:uranium_fuel")
me.register_output_by_typename("compressing", "default:diamond")

-- Any of these worth doing? TODO: Uranium, sure.
--me.register_output_by_typename("separating", "")

me.register_output_by_typename("freezing", "default:ice")

-- ======================================================================== --

-- The inputs required for the given output.  The inputs are exact count, the output it just
-- for 1.  We'll figure out how many are actually produced later.  For multiple outputs
-- only list the more interesting one.
-- furnace ("cooking")
me.register_output_to_inputs("default:copper_ingot",	{ ItemStack("technic:copper_dust") })
me.register_output_to_inputs("default:gold_ingot",	{ ItemStack("technic:gold_dust") })
me.register_output_to_inputs("default:steel_ingot",	{ ItemStack("technic:wrought_iron_dust") })
me.register_output_to_inputs("default:tin_ingot",	{ ItemStack("technic:tin_dust") })
me.register_output_to_inputs("technic:chromium_ingot",	{ ItemStack("technic:chromium_dust") })
--me.register_output_to_inputs("technic:uranium_ingot",	{ ItemStack("technic:uranium_dust") })
me.register_output_to_inputs("technic:zinc_ingot",	{ ItemStack("technic:zinc_dust") })
me.register_output_to_inputs("technic:lead_ingot",	{ ItemStack("technic:lead_dust") })
me.register_output_to_inputs("technic:cast_iron_ingot",	{ ItemStack("default:steel_ingot") })
me.register_output_to_inputs("mesecons_materials:glue", { ItemStack("technic:raw_latex") })
me.register_output_to_inputs("mesecons_materials:fiber", { ItemStack("mesecons_materials:glue") })
me.register_output_to_inputs("basic_materials:plastic_sheet", { ItemStack("basic_materials:paraffin") })
me.register_output_to_inputs("basic_materials:paraffin", { ItemStack("basic_materials:oil_extract") })
me.register_output_to_inputs("moreores:silver_ingot",	{ ItemStack("technic:silver_dust") })

-- grinder ("grinding")
me.register_output_to_inputs("technic:coal_dust", { ItemStack("default:coal_lump") })
me.register_output_to_inputs("technic:copper_dust", { ItemStack("default:copper_lump") })
me.register_output_to_inputs("technic:gold_dust", { ItemStack("default:gold_lump") })
me.register_output_to_inputs("technic:wrought_iron_dust", { ItemStack("default:iron_lump") })
me.register_output_to_inputs("technic:tin_dust", { ItemStack("default:tin_lump") })
me.register_output_to_inputs("technic:chromium_dust", { ItemStack("default:chromium_lump") })
me.register_output_to_inputs("technic:uranium_dust", { ItemStack("default:uranium_lump") })
me.register_output_to_inputs("technic:zinc_dust", { ItemStack("technic:zinc_lump") })
me.register_output_to_inputs("technic:lead_dust", { ItemStack("default:lead_lump") })
me.register_output_to_inputs("technic:sulfur_dust", { ItemStack("technic:sulfur_lump") })
me.register_output_to_inputs("technic:stone_dust", { ItemStack("default:stone") })
me.register_output_to_inputs("default:gravel", { ItemStack("default:cobble") })
me.register_output_to_inputs("default:sand", { ItemStack("default:gravel") })
me.register_output_to_inputs("default:snowblock", { ItemStack("default:ice") })
me.register_output_to_inputs("technic:rubber_tree_grindings", { ItemStack("moretrees:rubber_tree_trunk") })
me.register_output_to_inputs("technic:silver_dust", { ItemStack("moreores:silver_lump") })

-- alloy_furnace ("alloy")
-- The most useful alloy recipes.  We don't do the less useful ones as we don't yet have
-- a way for the user to say, no, don't do that.
me.register_output_to_inputs("technic:doped_silicon_wafer", { ItemStack("technic:gold_dust"), ItemStack("technic:silicon_wafer") })
me.register_output_to_inputs("technic:silicon_wafer", { ItemStack("default:sand 2"), ItemStack("technic:coal_dust 2") })
me.register_output_to_inputs("basic_materials:brass_ingot", { ItemStack("default:copper_ingot 2"), ItemStack("technic:zinc_ingot") })
me.register_output_to_inputs("default:bronze_ingot", { ItemStack("default:copper_ingot 7"), ItemStack("default:tin_ingot") })
me.register_output_to_inputs("technic:stainless_steel_ingot", { ItemStack("technic:carbon_steel_ingot 4"), ItemStack("technic:chromium_ingot") })
me.register_output_to_inputs("technic:rubber", { ItemStack("technic:raw_latex 4"), ItemStack("technic:coal_dust 2") })
me.register_output_to_inputs("bucket:bucket_lava", { ItemStack("default:obsidian"), ItemStack("bucket:bucket_empty") })
me.register_output_to_inputs("technic:carbon_steel_ingot", { ItemStack("default:steel_ingot 2"), ItemStack("technic:coal_dust") })

-- extractor ("extracting")
me.register_output_to_inputs("technic:raw_latex", { ItemStack("technic:rubber_tree_grindings 4") })

-- compressor ("compressing")
me.register_output_to_inputs("technic:composite_plate", { ItemStack("technic:mixed_metal_ingot") })
me.register_output_to_inputs("technic:copper_plate", { ItemStack("default:copper_ingot 5") })
me.register_output_to_inputs("technic:graphite", { ItemStack("technic:coal_dust 4") })
me.register_output_to_inputs("technic:carbon_plate", { ItemStack("technic:carbon_cloth") })
me.register_output_to_inputs("technic:uranium_fuel", { ItemStack("technic:uranium35_ingot 5") })
me.register_output_to_inputs("default:diamond", { ItemStack("technic:graphite 25") })

-- centrifuge ("separating")

-- freezer ("freezing")
me.register_output_to_inputs("default:ice", { ItemStack("bucket:bucket_water") })
