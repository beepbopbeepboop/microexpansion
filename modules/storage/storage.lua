-- microexpansion/storage.lua

--TODO: use storagecomp for crafting

if minetest.get_modpath("mcl_core") then
microexpansion.register_cell("cell_1k", {
  description = "1k ME Storage Cell",
  capacity = 1000,
  recipe = {
    { 1, {
        {"moreores:tin_ingot",      "mcl_copper:copper_ingot",                     "moreores:tin_ingot"},
        {"mcl_copper:copper_ingot", "microexpansion:steel_infused_obsidian_ingot", "mcl_copper:copper_ingot"},
        {"moreores:tin_ingot",      "mcl_copper:copper_ingot",                     "moreores:tin_ingot"}
    }},
  },
})

microexpansion.register_cell("cell_2k", {
  description = "2k ME Storage Cell",
  capacity = 2000,
  recipe = {
    { 1, {
        {"mcl_copper:copper_ingot", "mcl_core:iron_ingot", "mcl_copper:copper_ingot"},
        {"mcl_core:iron_ingot",     "mcl_core:obsidian",   "mcl_core:iron_ingot"},
        {"mcl_copper:copper_ingot", "mcl_core:iron_ingot", "mcl_copper:copper_ingot"}
    }},
    { 1, "shapeless", {"microexpansion:cell_1k", "microexpansion:cell_1k"}}
  },
})
else

-- [drive] 1k
microexpansion.register_cell("cell_1k", {
  description = "1k ME Storage Cell",
  capacity = 1000,
  recipe = {
    { 1, {
        {"default:tin_ingot",    "default:copper_ingot",                        "default:tin_ingot"},
        {"default:copper_ingot", "microexpansion:steel_infused_obsidian_ingot", "default:copper_ingot"},
        {"default:tin_ingot",    "default:copper_ingot",                        "default:tin_ingot"}, 
      },
    }
  },
})

-- [drive] 2k
microexpansion.register_cell("cell_2k", {
  description = "2k ME Storage Cell",
  capacity = 2000,
  recipe = {
    { 1, {
        {"default:copper_ingot", "default:steel_ingot",    "default:copper_ingot"},
        {"default:steel_ingot",  "default:obsidian_shard", "default:steel_ingot"},
        {"default:copper_ingot", "default:steel_ingot",    "default:copper_ingot"},
      },
    },
    { 1, "shapeless", {"microexpansion:cell_1k", "microexpansion:cell_1k"}}
  },
})

end

-- [drive] 4k
microexpansion.register_cell("cell_4k", {
  description = "4k ME Storage Cell",
  capacity = 4000,
  recipe = {
    { 1, "shapeless", {
        "microexpansion:steel_infused_obsidian_ingot", "microexpansion:machine_casing", "microexpansion:steel_infused_obsidian_ingot"
      },
    },
    { 1, "shapeless", {"microexpansion:cell_2k", "microexpansion:cell_2k"}}
  },
})

-- [drive] 8k
microexpansion.register_cell("cell_8k", {
  description = "8k ME Storage Cell",
  capacity = 8000,
  recipe = {
    { 1, "shapeless", {"microexpansion:cell_4k", "microexpansion:cell_4k"}}
  },
})

-- [drive] 16k
microexpansion.register_cell("cell_16k", {
  description = "16k ME Storage Cell",
  capacity = 16000,
  recipe = {
    { 1, "shapeless", {"microexpansion:cell_8k", "microexpansion:cell_8k"}}
  },
})

-- [drive] 32k
microexpansion.register_cell("cell_32k", {
  description = "32k ME Storage Cell",
  capacity = 32000,
  recipe = {
    { 1, "shapeless", {"microexpansion:cell_16k", "microexpansion:cell_16k"}}
  },
})

-- [drive] 64k
microexpansion.register_cell("cell_64k", {
  description = "64k ME Storage Cell",
  capacity = 64000,
  recipe = {
    { 1, "shapeless", {"microexpansion:cell_32k", "microexpansion:cell_32k"}}
  },
})
