-- VIP system core module.
--
-- Source of truth for VIP subscription state lives in the DB table
-- `player_vip_subscriptions` (see migrations 48 + 49 in
-- `server/data/migrations/`). The C++ Player object holds an in-memory cache
-- (vipTier, vipExpires) populated on login and refreshed via
-- VipSystem._setPlayerCache(player, tier, expires) after any mutation.
--
-- All UI / tile / scroll / GM paths go through this module; no C++ setter
-- exists. The player-facing perks (outfits, mounts, XP bonus) are applied
-- on login by `data/scripts/creaturescripts/vip_login.lua`.
--
-- LIFO semantics with player choice:
--   - The "active" subscription is the one with the smallest unexpired
--     expires_at (top of the stack, consumed first).
--   - grantSubscription() always pushes a new row. By default the new row
--     becomes the active one (LIFO latest = top of stack = next to be used).
--   - The player can call activateSubscription(id) to switch which row in
--     their stack is active.
--   - When the active row expires, autoFallback() picks the highest tier
--     remaining in the stack and makes it active.

VipSystem = VipSystem or {}

-- Tier constants (matches player_vip_subscriptions.tier)
VipSystem.TIERS = { [0] = "Free", [1] = "Bronze", [2] = "Silver", [3] = "Gold" }

-- Per-tier rewards (cumulative: Gold has 26 male + 26 female outfits; Silver
-- has 10; Bronze has 5. Same idea for mounts.)
VipSystem.OUTFITS = {
	[1] = {
		male   = { 134, 143, 152, 154, 289 },
		female = { 142, 147, 156, 158, 288 },
	},
	[2] = {
		male   = { 268, 432, 465, 884, 899 },
		female = { 269, 433, 466, 885, 900 },
	},
	[3] = {
		male   = { 541, 512, 665, 667, 846, 1202, 1444, 1489, 1675, 1680,
		           1713, 1725, 1745, 1809, 1831, 1824 },
		female = { 542, 513, 664, 666, 845, 1203, 1445, 1490, 1676, 1681,
		           1714, 1726, 1746, 1808, 1832, 1825 },
	},
}

VipSystem.MOUNTS = {
	[1] = { 17, 16, 5, 6, 11 },
	[2] = { 40, 9, 31, 39, 106 },
	[3] = { 144, 184, 175, 174, 87, 99, 179, 180, 181, 94, 98, 206, 202, 167, 162 },
}

-- Standard premium outfits (lookTypes 128-133 male / 136-141 female + a couple
-- of legacy addon-3 lookTypes). Any VIP player gets addon 3 for these.
VipSystem.STANDARD_PREMIUM_OUTFITS = {
	male   = { 128, 129, 130, 131, 132, 133, 134, 143, 144, 145, 146 },
	female = { 136, 137, 138, 139, 140, 141, 142, 147, 148, 149, 150 },
}

-- ---------------------------------------------------------------------------
-- Helpers: rewards (outfits / mounts)
-- ---------------------------------------------------------------------------

-- Get all outfits from tier 1..tier (cumulative).
function VipSystem.getAllTierOutfits(tier, isFemale)
	local result = {}
	local key = isFemale and "female" or "male"
	for t = 1, tier do
		for _, lookType in ipairs(VipSystem.OUTFITS[t][key] or {}) do
			result[#result + 1] = lookType
		end
	end
	return result
end

-- Get all mounts from tier 1..tier (cumulative).
function VipSystem.getAllTierMounts(tier)
	local result = {}
	for t = 1, tier do
		for _, mountId in ipairs(VipSystem.MOUNTS[t] or {}) do
			result[#result + 1] = mountId
		end
	end
	return result
end

-- Grant all rewards for the given tier (cumulative 1..tier).
function VipSystem.grantRewards(player, tier)
	if not player or not tier or tier < 1 then
		return false
	end
	local isFemale = (player:getSex() == PLAYERSEX_FEMALE)
	local key = isFemale and "female" or "male"
	for _, lookType in ipairs(VipSystem.STANDARD_PREMIUM_OUTFITS[key] or {}) do
		player:addOutfitAddon(lookType, 3)
	end
	for _, lookType in ipairs(VipSystem.getAllTierOutfits(tier, isFemale)) do
		player:addOutfitAddon(lookType, 3)
	end
	for _, mountId in ipairs(VipSystem.getAllTierMounts(tier)) do
		player:addMount(mountId)
	end
	return true
end

-- Revoke all VIP rewards (outfits 1..3, mounts 1..3, standard premium addons).
function VipSystem.revokeAllRewards(player)
	if not player then
		return false
	end
	local isFemale = (player:getSex() == PLAYERSEX_FEMALE)
	for _, lookType in ipairs(VipSystem.STANDARD_PREMIUM_OUTFITS.male) do
		player:removeOutfit(lookType)
	end
	for _, lookType in ipairs(VipSystem.STANDARD_PREMIUM_OUTFITS.female) do
		player:removeOutfit(lookType)
	end
	for tier = 1, 3 do
		for _, lookType in ipairs(VipSystem.getAllTierOutfits(tier, isFemale)) do
			player:removeOutfit(lookType)
		end
		for _, mountId in ipairs(VipSystem.getAllTierMounts(tier)) do
			player:removeMount(mountId)
		end
	end
	return true
end

-- ---------------------------------------------------------------------------
-- Subscription stack queries
-- ---------------------------------------------------------------------------

-- Get the player's currently active subscription, or nil if none.
-- "Active" = is_active=1 AND expires_at > now.
function VipSystem.getActiveSubscription(player)
	local result = db.storeQuery(string.format(
		"SELECT `id`, `tier`, `expires_at`, `source`, `activation_order` " ..
		"FROM `player_vip_subscriptions` " ..
		"WHERE `player_id` = %d AND `is_active` = 1 AND `expires_at` > %d " ..
		"LIMIT 1",
		player:getGuid(), os.time()))
	if not result or not result:getNumber("id") then
		return nil
	end
	local sub = {
		id              = result:getNumber("id"),
		tier            = result:getNumber("tier"),
		expiresAt       = result:getNumber("expires_at"),
		source          = result:getString("source"),
		activationOrder = result:getNumber("activation_order"),
	}
	result.free()
	return sub
end

-- Get the highest-tier unexpired subscription remaining in the stack.
-- Used by autoFallback() when the active subscription has expired.
function VipSystem.getAutoFallbackSubscription(player)
	local result = db.storeQuery(string.format(
		"SELECT `id`, `tier`, `expires_at` " ..
		"FROM `player_vip_subscriptions` " ..
		"WHERE `player_id` = %d AND `expires_at` > %d " ..
		"ORDER BY `tier` DESC, `expires_at` ASC LIMIT 1",
		player:getGuid(), os.time()))
	if not result or not result:getNumber("id") then
		return nil
	end
	local sub = {
		id        = result:getNumber("id"),
		tier      = result:getNumber("tier"),
		expiresAt = result:getNumber("expires_at"),
	}
	result.free()
	return sub
end

-- Get the player's full unexpired stack, ordered active-first then by
-- expires_at ASC (top of stack = next to be consumed).
function VipSystem.getStack(player)
	local result = db.storeQuery(string.format(
		"SELECT `id`, `tier`, `expires_at`, `created_at`, `source`, " ..
		"       `is_active`, `activation_order` " ..
		"FROM `player_vip_subscriptions` " ..
		"WHERE `player_id` = %d AND `expires_at` > %d " ..
		"ORDER BY `is_active` DESC, `expires_at` ASC",
		player:getGuid(), os.time()))
	local stack = {}
	if result then
		repeat
			stack[#stack + 1] = {
				id              = result:getNumber("id"),
				tier            = result:getNumber("tier"),
				expiresAt       = result:getNumber("expires_at"),
				createdAt       = result:getNumber("created_at"),
				source          = result:getString("source"),
				isActive        = result:getNumber("is_active") == 1,
				activationOrder = result:getNumber("activation_order"),
			}
		until not result:next()
		result.free()
	end
	return stack
end

-- ---------------------------------------------------------------------------
-- Stack mutations
-- ---------------------------------------------------------------------------

-- Push a new subscription to the player's stack.
-- Default behavior (LIFO): the new row becomes the active one (replaces
-- any previously-active row). Pass `setActive = false` to insert as
-- inactive (e.g. for "future purchases" or batch grants).
-- @param player Player
-- @param tier   1..3
-- @param days   positive integer
-- @param source string: "scroll" | "gm" | "payment" | etc.
-- @return table { id, tier, expiresAt, daysAdded, becameActive }
function VipSystem.grantSubscription(player, tier, days, source)
	assert(tier >= 1 and tier <= 3, "Invalid VIP tier")
	assert(days and days > 0, "Days must be positive")

	local playerId = player:getGuid()
	local now      = os.time()
	local expiresAt = now + (days * 86400)

	-- Deactivate any previously-active row. With LIFO default the new grant
	-- becomes the only active row.
	db.query(string.format(
		"UPDATE `player_vip_subscriptions` SET `is_active` = 0 " ..
		"WHERE `player_id` = %d", playerId))

	local insertResult = db.storeQuery(string.format(
		"INSERT INTO `player_vip_subscriptions` " ..
		"(`player_id`, `tier`, `expires_at`, `created_at`, `source`, " ..
		" `is_active`, `activation_order`) " ..
		"VALUES (%d, %d, %d, %d, '%s', 1, %d)",
		playerId, tier, expiresAt, now, source, now))
	local newId
	if insertResult then
		newId = insertResult:getNumber("id")
		insertResult.free()
	end

	VipSystem.reloadPlayerCache(player)
	return {
		id           = newId,
		tier         = tier,
		expiresAt    = expiresAt,
		daysAdded    = days,
		becameActive = true,
	}
end

-- Player-initiated switch: activate a specific subscription from the stack.
-- @param player Player
-- @param subscriptionId INT
-- @return bool ok, string err
function VipSystem.activateSubscription(player, subscriptionId)
	local playerId = player:getGuid()
	local now      = os.time()

	-- Verify the subscription belongs to this player and is still unexpired.
	local result = db.storeQuery(string.format(
		"SELECT `id`, `tier` FROM `player_vip_subscriptions` " ..
		"WHERE `id` = %d AND `player_id` = %d AND `expires_at` > %d",
		subscriptionId, playerId, now))
	if not result or not result:getNumber("id") then
		if result then result.free() end
		return false, "Invalid or expired subscription"
	end
	result.free()

	-- Deactivate all of the player's subscriptions, then activate the chosen one.
	db.query(string.format(
		"UPDATE `player_vip_subscriptions` SET `is_active` = 0 " ..
		"WHERE `player_id` = %d", playerId))
	db.query(string.format(
		"UPDATE `player_vip_subscriptions` SET `is_active` = 1, " ..
		"       `activation_order` = %d WHERE `id` = %d",
		now, subscriptionId))

	VipSystem.reloadPlayerCache(player)
	return true
end

-- Revoke all subscriptions for a player (GM "!setvip <name> 0 0").
function VipSystem.revokeAll(player)
	db.query(string.format(
		"DELETE FROM `player_vip_subscriptions` WHERE `player_id` = %d",
		player:getGuid()))
	VipSystem.reloadPlayerCache(player)
	return true
end

-- Auto-fallback: pick the highest-tier unexpired subscription remaining
-- and make it active. Called by the login handler when the previously-active
-- subscription has expired. No-op if the stack is empty.
-- @return table|nil  the activated subscription, or nil if stack is empty
function VipSystem.autoFallback(player)
	local next = VipSystem.getAutoFallbackSubscription(player)
	if not next then
		VipSystem._setPlayerCache(player, 0, 0)
		return nil
	end

	local now = os.time()
	db.query(string.format(
		"UPDATE `player_vip_subscriptions` SET `is_active` = 0 " ..
		"WHERE `player_id` = %d", player:getGuid()))
	db.query(string.format(
		"UPDATE `player_vip_subscriptions` SET `is_active` = 1, " ..
		"       `activation_order` = %d WHERE `id` = %d",
		now, next.id))

	VipSystem.reloadPlayerCache(player)
	return next
end

-- ---------------------------------------------------------------------------
-- Cache bridge
-- ---------------------------------------------------------------------------

-- Wrapper around the C++ global `vipSetCache(player, tier, expires)`.
-- Called by reloadPlayerCache() and from autoFallback() / grantSubscription()
-- / activateSubscription() / revokeAll() after any DB write.
function VipSystem._setPlayerCache(player, tier, expires)
	if not vipSetCache then
		-- Defensive: if the engine is misconfigured (no C++ binding), fail loud
		-- instead of silently leaving a stale cache.
		logError("[VipSystem] vipSetCache is not registered in the global scope; "
			.. "Player VIP cache will not update.")
		return false
	end
	vipSetCache(player, tier or 0, expires or 0)
	return true
end

-- Recompute the player's in-memory cache from the DB active row.
-- Called after every subscription mutation. If there's no active row, the
-- cache is cleared.
function VipSystem.reloadPlayerCache(player)
	local sub = VipSystem.getActiveSubscription(player)
	if sub then
		VipSystem._setPlayerCache(player, sub.tier, sub.expiresAt)
	else
		VipSystem._setPlayerCache(player, 0, 0)
	end
end

return VipSystem
