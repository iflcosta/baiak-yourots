-- VIP restricted-area tile handler.
--
-- Tiles with the following Action IDs (AIDs) gate entry by VIP tier:
--   50010 → requires VIP Bronze or higher  (min tier 1)
--   50011 → requires VIP Silver or higher  (min tier 2)
--   50012 → requires VIP Gold               (min tier 3)
--
-- Behavior: if the player's VIP tier is below the required tier, they are
-- teleported back to fromPosition with a message and the POFF magic effect.
-- The check uses player:getVipTier() (the in-memory cache), which is kept
-- in sync with DB by VipSystem.reloadPlayerCache().

local VIP_TILE_AIDS = {
	[50010] = { minTier = 1, name = "VIP Bronze" },
	[50011] = { minTier = 2, name = "VIP Silver" },
	[50012] = { minTier = 3, name = "VIP Gold" },
}

local vipTile = MoveEvent()
vipTile:type("stepin")

function vipTile.onStepIn(creature, item, position, fromPosition)
	local player = creature:getPlayer()
	if not player or player:isInGhostMode() then
		return true
	end

	local aid = item.actionid
	local config = VIP_TILE_AIDS[aid]
	if not config then
		return true
	end

	if player:getVipTier() < config.minTier then
		player:teleportTo(fromPosition, false)
		player:getPosition():sendMagicEffect(CONST_ME_POFF)
		player:sendTextMessage(MESSAGE_STATUS_SMALL,
			string.format("[VIP] This area requires %s or higher.", config.name))
		return true
	end

	return true
end

for aid, _ in pairs(VIP_TILE_AIDS) do
	vipTile:aid(aid)
end

vipTile:register()
