-- VIP network protocol: extended opcode 181 handler.
--
-- Registered as CreatureEvent "VipProtocol" with onExtendedOpcode.
-- The vip_login.lua login event calls player:registerEvent("VipProtocol")
-- on every login so the player is wired to the handler.
--
-- Supported client → server messages (JSON):
--   { "type": "request_update" }                  → re-send vip_info
--   { "type": "activate_subscription", "id": N }  → switch active to subscription N
--
-- Server → client messages (JSON):
--   { "type": "vip_info", ... }                   → full VIP state (same as !vip)
--   { "type": "error", "message": "..." }         → client displays failure

local VIP_OPCODE = 181

local vipProtocol = CreatureEvent("VipProtocol")

-- Build the same payload as !vip.lua so client and !vip speak the same shape.
local function buildVipInfo(player)
	local activeTier = player:getVipTier()
	local stack = VipSystem.getStack(player)
	local outfits, mounts = {}, {}
	if activeTier > 0 then
		local isFemale = (player:getSex() == PLAYERSEX_FEMALE)
		outfits = VipSystem.getAllTierOutfits(activeTier, isFemale)
		mounts  = VipSystem.getAllTierMounts(activeTier)
	end

	local stackOut = {}
	for _, sub in ipairs(stack) do
		local days = math.max(0, math.ceil((sub.expiresAt - os.time()) / 86400))
		stackOut[#stackOut + 1] = {
			id              = sub.id,
			tier            = sub.tier,
			tierName        = VipSystem.TIERS[sub.tier] or "VIP",
			expiresAt       = sub.expiresAt,
			daysRemaining   = days,
			source          = sub.source,
			isActive        = sub.isActive,
			activationOrder = sub.activationOrder,
		}
	end

	return {
		type             = "vip_info",
		activeSubscriptionId = (stackOut[1] and stackOut[1].isActive) and stackOut[1].id or 0,
		activeTier       = activeTier,
		activeTierName   = VipSystem.TIERS[activeTier] or "Free",
		activeDaysRemaining = player:getVipDaysRemaining(),
		activeExpiresAt  = player:getVipExpires(),
		xpBonus          = player:getVipXpBonus(),
		lootBonus        = player:getVipLootBonus(),
		isVip            = player:isVip(),
		outfitsUnlocked  = outfits,
		mountsUnlocked   = mounts,
		stack            = stackOut,
	}
end

local function sendVipInfo(player)
	if not player or not player.sendExtendedOpcode then
		return
	end
	player:sendExtendedOpcode(VIP_OPCODE, json.encode(buildVipInfo(player)))
end

local function sendError(player, message)
	if not player or not player.sendExtendedOpcode then
		return
	end
	player:sendExtendedOpcode(VIP_OPCODE, json.encode({
		type    = "error",
		message = message or "Unknown VIP error",
	}))
end

function vipProtocol.onExtendedOpcode(player, opcode, buffer)
	if opcode ~= VIP_OPCODE then
		return true
	end
	if not player or not player:isPlayer() or not buffer or buffer == "" then
		return true
	end

	-- Decode the message. We use pcall because malformed JSON shouldn't crash
	-- the protocol handler.
	local ok, data = pcall(json.decode, buffer)
	if not ok or type(data) ~= "table" then
		sendError(player, "Invalid VIP request payload.")
		return true
	end

	local msgType = data.type
	if msgType == "request_update" then
		sendVipInfo(player)
		return true
	end

	if msgType == "activate_subscription" then
		local subId = tonumber(data.id) or tonumber(data.subscriptionId)
		if not subId or subId <= 0 then
			sendError(player, "Invalid subscription id.")
			return true
		end
		local ok2, err = VipSystem.activateSubscription(player, subId)
		if not ok2 then
			sendError(player, err or "Failed to activate subscription.")
			return true
		end
		-- Re-apply perks for the new active tier (the switch may downgrade
		-- from Gold → Bronze; perks are not cumulative on switch).
		VipSystem.revokeAllRewards(player)
		VipSystem.grantRewards(player, player:getVipTier())
		-- Re-apply XP bonus.
		local xpBonus = player:getVipXpBonus()
		if xpBonus and xpBonus > 0 then
			player:setExperienceRate(ExperienceRateType.BONUS, 100 + xpBonus)
		end
		sendVipInfo(player)
		return true
	end

	-- Unknown message type — ignore silently but log so a future change is
	-- traceable.
	logWarning(string.format(
		"[VipProtocol] Unknown message type from %s: %s",
		player:getName(), tostring(msgType)))
	return true
end

vipProtocol:register()
