-- VIP player talkaction: !vip
--
-- Triggers the client UI (Ultralight) by sending extended opcode 181
-- with the current VIP state and the full subscription stack.
-- The client interprets the payload and renders the panel.

local vip = TalkAction("!vip")

local function buildStackSummary(player)
	local stack = VipSystem.getStack(player)
	local out = {}
	for _, sub in ipairs(stack) do
		local days = math.max(0, math.ceil((sub.expiresAt - os.time()) / 86400))
		out[#out + 1] = {
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
	return out
end

local function buildOutfitAndMountLists(player)
	local tier = player:getVipTier()
	if tier <= 0 then
		return {}, {}
	end
	local isFemale = (player:getSex() == PLAYERSEX_FEMALE)
	return VipSystem.getAllTierOutfits(tier, isFemale),
	       VipSystem.getAllTierMounts(tier)
end

function vip.onSay(player, words, param)
	if not player or not player:isPlayer() then
		return false
	end

	local activeTier = player:getVipTier()
	local payload = {
		type             = "vip_info",
		activeSubscriptionId = 0,
		activeTier       = activeTier,
		activeTierName   = VipSystem.TIERS[activeTier] or "Free",
		activeDaysRemaining = player:getVipDaysRemaining(),
		activeExpiresAt  = player:getVipExpires(),
		xpBonus          = player:getVipXpBonus(),
		lootBonus        = player:getVipLootBonus(),
		isVip            = player:isVip(),
		outfitsUnlocked  = {},
		mountsUnlocked   = {},
		stack            = buildStackSummary(player),
	}

	local outfits, mounts = buildOutfitAndMountLists(player)
	payload.outfitsUnlocked = outfits
	payload.mountsUnlocked  = mounts

	-- Annotate the active id (for UI highlight).
	if payload.stack[1] and payload.stack[1].isActive then
		payload.activeSubscriptionId = payload.stack[1].id
	end

	player:sendExtendedOpcode(181, json.encode(payload))
	return false
end

vip:separator(" ")
vip:register()
