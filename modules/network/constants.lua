local me = microexpansion
if not me.constants then
  me.constants = {}
end
local constants = me.constants

local access_levels = {
  -- cannot interact at all with the network or it's components
  blocked = 0,
  -- can only look into the network but not move, modify, etc.
  view = 20,
  -- can use chests, craft terminals, etc.
  interact = 40,
  -- can use all components except security, can build and dig (except core)
  modify = 60,
  -- can use security terminal, can modify all players with less access
  manage = 80,
  -- can modify all players with less access and self
  full = 100
}

local access_level_descriptions = {}
access_level_descriptions[access_levels.blocked] = {
  name = "Blocked",
  color = "gray",
  index = 1
}
access_level_descriptions[access_levels.view] = {
  name = "View",
  color = "orange",
  index = 2
}
access_level_descriptions[access_levels.interact] = {
  color = "yellow",
  name = "Interact",
  index = 3
}
access_level_descriptions[access_levels.modify] = {
  name = "Modify",
  color = "yellowgreen",
  index = 4
}
access_level_descriptions[access_levels.manage] = {
  name = "Manage",
  color = "green",
  index = 5
}
access_level_descriptions[access_levels.full] = {
  name = "Full",
  color = "blue",
  index = 6
}

constants.security = {
  access_levels = access_levels,
  access_level_descriptions = access_level_descriptions
}
