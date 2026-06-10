-- VIP GM command: !setvip <player> <tier> <days>
--
-- Examples:
--   !setvip iflopes2 3 90   → grant 90 days of Gold (becomes active by default)
--   !setvip iflopes2 1 30   → grant 30 days of Bronze (LIFO; active if no higher)
--   !setvip iflopes2 0 0    → revoke ALL VIP subscriptions
--
-- Access: GAMEMASTER+ only.
--
-- Note: this script lives in talkactions/gm/ but is registered with
-- `access(true)` so anyone with group access ≥ GAMEMASTER can use it.
-- If the project also uses an accountType-based restriction, we set both.

local setvip = TalkAction("!setvip")

local function getPlayerByNameWildcard(name)
	if not name or name == "" then
		return nil
	end
	-- Online first.
	local exact = Player(name)
	if exact then
		return exact
	end
	-- Loose match for partial names ("iflo" → "iflopes2").
	local lower = name:lower()
	for _, p in ipairs(Game.getPlayers()) do
		if p:getName():lower():sub(1, #lower) == lower then
			return p
		end
	end
	return nil
end

function setvip.onSay(player, words, param)
	param = (param or ""):trim()
	if param == "" then
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
			"Usage: !setvip <player name> <tier 0-3> <days 0-365>")
		return false
	end

	local parts = {}
	for word in param:gmatch("%S+") do
		parts[#parts + 1] = word
	end
	if #parts < 3 then
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
			"Usage: !setvip <player name> <tier 0-3> <days 0-365>")
		return false
	end

	local targetName = parts[1]
	local tier = tonumber(parts[2])
	local days = tonumber(parts[3])

	if not tier or tier < 0 or tier > 3 then
		player:sendTextMessage(MESSAGE_STATUS_SMALL, "Tier must be 0, 1, 2, or 3.")
		return false
	end
	if not days or days < 0 or days > 365 then
		player:sendTextMessage(MESSAGE_STATUS_SMALL, "Days must be between 0 and 365.")
		return false
	end

	-- Find the target. Online first; fall back to the OfflinePlayer helper.
	local target = getPlayerByNameWildcard(targetName)
	if not target then
		local offline = OfflinePlayer(targetName)
		if offline and offline:getGuid() and offline:getGuid() > 0 then
			-- Offline grant path: write directly via db.query, then the player's
			-- in-memory cache will refresh on next login (IOLoginData calls
			-- player->reloadVipCache() in loadPlayer()).
			local guid = offline:getGuid()
			if tier == 0 and days == 0 then
				db.query(string.format(
					"DELETE FROM `player_vip_subscriptions` WHERE `player_id` = %d", guid))
				player:sendTextMessage(MESSAGE_EVENT_ADVANCE,
					string.format("[VIP] Revoked all VIP subscriptions for offline player %s.", targetName))
				return false
			end

			local now = os.time()
			local expiresAt = now + (days * 86400)
			db.query(string.format(
				"UPDATE `player_vip_subscriptions` SET `is_active` = 0 WHERE `player_id` = %d", guid))
			db.query(string.format(
				"INSERT INTO `player_vip_subscriptions` " ..
				"(`player_id`, `tier`, `expires_at`, `created_at`, `source`, " ..
				" `is_active`, `activation_order`) " ..
				"VALUES (%d, %d, %d, %d, 'gm', 1, %d)",
				guid, tier, expiresAt, now, now))
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE,
				string.format("[VIP] Granted %d day(s) of VIP %s to offline player %s. " ..
					"(Cache will refresh on next login.)",
					days, VipSystem.TIERS[tier] or "?", targetName))
			return false
		end

		player:sendTextMessage(MESSAGE_STATUS_SMALL,
			"Player " .. targetName .. " not found.")
		return false
	end

	-- Online target.
	if tier == 0 and days == 0 then
		VipSystem.revokeAll(target)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE,
			"[VIP] Revoked all VIP subscriptions for " .. target:getName() .. ".")
		target:sendTextMessage(MESSAGE_STATUS_WARNING,
			"Your VIP subscription(s) have been revoked by a GM.")
		return false
	end

	local result = VipSystem.grantSubscription(target, tier, days, "gm")
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE,
		string.format("[VIP] Granted %d day(s) of VIP %s to %s.",
			days, VipSystem.TIERS[tier] or "?", target:getName()))
	target:sendTextMessage(MESSAGE_EVENT_ADVANCE,
		string.format("[VIP] A GM granted you %d day(s) of VIP %s!",
			days, VipSystem.TIERS[tier] or "?"))
	return false
end

setvip:separator(" ")
setvip:accountType(ACCOUNT_TYPE_GAMEMASTER)
setvip:access(true)
setvip:register()
