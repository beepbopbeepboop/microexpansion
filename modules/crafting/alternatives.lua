---
-- craftitems that offer alternative craft recipes

local me = microexpansion

--TODO: build specialized integrated circuits / chips out of the ic and other stuff that are required to build the devices / machines instead of the control unit being an alternative

---
-- [Microexpansion Control Unit]
-- a different logic chip that uses gold, quartz and wood
-- for use instead of basic_materials:ic that requires sand, coal and copper
me.register_item("logic_chip", {
  description = "Control Unit",
  recipe = {
    { 2,
      {
        {"basic_materials:gold_wire"},
        {"basic_materials:silicon"},
        {"basic_materials:plastic_sheet"}
      },
    },
    { 2,
      {
        {"basic_materials:gold_wire"},
        {"microexpansion:quartz_crystal"},
        {"basic_materials:plastic_sheet"}
      },
    },
    { 2, 
      {
        {"microexpansion:gold_wire"},
        {"microexpansion:quartz_crystal"},
        {"group:wood"}
      },
    },
  },
})
