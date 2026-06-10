-- VIP system: login handler.
--
-- Registered as CreatureEvent "VipLogin" so it runs after the player's
-- C++ VIP cache has been populated by IOLoginData::loadPlayer() (see
-- src/iologindata.cpp). It then:
--   1. Checks if the previously-active subscription has expired. If yes,
--      auto-fallback picks the highest tier remaining.
--   2. Refreshes the in-memory cache.
--   3. Grants outfits/mounts for the active tier (cumulative 1..tier).
--   4. Applies the XP bonus via setExperienceRate(BONUS, 100+x).
--   5. Sends a status message and (if the stack has more than one item)
--      lists the other subscriptions.

local vipLogin = CreatureEvent("VipLogin")

function vipLogin.onLogin(player)
	if not player or not player:isPlayer() then
		return true
	end

	-- 1. Active subscription check + auto-fallback.
	--    The C++ cache was just populated from DB on login, but if the active
	--    row's expires_at is in the past, we need to flip is_active to the
	--    next row before granting perks.
	local active = VipSystem.getActiveSubscription(player)
	if not active then
		-- Either nothing in the stack or the active row has expired.
		local fallback = VipSystem.autoFallback(player)
		if not fallback then
			-- Stack is empty. Make sure perks are revoked and the cache is clear.
			VipSystem.revokeAllRewards(player)
			VipSystem.reloadPlayerCache(player)
			return true
		end
		active = fallback
	end

	-- 2. Refresh cache (in case autoFallback just ran, or a previous
	--    session left is_active set on an expired row that the SELECT above
	--    ignored — reloadPlayerCache reads the active row fresh).
	VipSystem.reloadPlayerCache(player)

	-- 3. Grant rewards.
	local tier = active.tier
	VipSystem.grantRewards(player, tier)

	-- 4. Apply XP bonus.
	local xpBonus = player:getVipXpBonus()
	if xpBonus and xpBonus > 0 then
		player:setExperienceRate(ExperienceRateType.BONUS, 100 + xpBonus)
	end

	-- 5. Status message + stack summary.
	local stack = VipSystem.getStack(player)
	local tierName = VipSystem.TIERS[tier] or "VIP"
	local daysLeft = math.max(0, math.ceil((active.expiresAt - os.time()) / 86400))

	if daysLeft <= 3 then
		player:sendTextMessage(MESSAGE_STATUS_WARNING,
			string.format("[VIP] Your VIP %s expires in %d day(s)!", tierName, daysLeft))
	else
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
			string.format("[VIP] Welcome back! VIP %s active — %d day(s) remaining.",
				tierName, daysLeft))
	end

	if #stack > 1 then
		local others = {}
		for _, sub in ipairs(stack) do
			if sub.id ~= active.id then
				local d = math.max(0, math.ceil((sub.expiresAt - os.time()) / 86400))
				others[#others + 1] = string.format("%s (%dd)", VipSystem.TIERS[sub.tier] or "?", d)
			end
		end
		if #others > 0 then
			player:sendTextMessage(MESSAGE_INFO_DESCR,
				"[VIP] Other subscriptions: " .. table.concat(others, ", "))
		end
	end

	return true
end

vipLogin:register()

-- The VIP protocol handler (extended opcode 181) is a separate CreatureEvent
-- (see data/scripts/network/vip/vip_protocol.lua). It must be registered on
-- every logged-in player so the client can talk to the server. We do that
-- here in the same login flow so we don't need a second CreatureEvent file.
local vipLoginProtocol = CreatureEvent("VipLoginProtocol")

function vipLoginProtocol.onLogin(player)
	if not player or not player:isPlayer() then
		return true
	end
	player:registerEvent("VipProtocol")
	return true
end

vipLoginProtocol:register()
