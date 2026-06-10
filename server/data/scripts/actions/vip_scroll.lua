-- VIP activation scroll handler.
--
-- Item IDs:
--   24774 → VIP Bronze Scroll  (grants 30 days of Bronze)
--   24775 → VIP Silver Scroll  (grants 30 days of Silver)
--   24776 → VIP Gold Scroll    (grants 30 days of Gold)
--
-- Using a scroll calls VipSystem.grantSubscription(player, tier, 30, "scroll")
-- which inserts a new row in player_vip_subscriptions and refreshes the
-- player's in-memory VIP cache. The new row becomes the active row (LIFO
-- default).

local VIP_SCROLLS = {
	[24774] = { tier = 1, days = 30, name = "Bronze" },
	[24775] = { tier = 2, days = 30, name = "Silver" },
	[24776] = { tier = 3, days = 30, name = "Gold" },
}

local vipScroll = Action()

function vipScroll.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if not player or not item then
		return false
	end

	local config = VIP_SCROLLS[item:getId()]
	if not config then
		return false
	end

	local result = VipSystem.grantSubscription(player, config.tier, config.days, "scroll")

	player:getPosition():sendMagicEffect(CONST_ME_GIFT_WRAPS)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE,
		string.format("[VIP] You have activated %d day(s) of VIP %s!",
			config.days, config.name))

	item:remove(1)
	return true
end

for itemId, _ in pairs(VIP_SCROLLS) do
	vipScroll:id(itemId)
end

vipScroll:register()
