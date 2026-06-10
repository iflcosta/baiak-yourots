function onUpdateDatabase()
	logMigration("Updating database to version 49 (VIP system: player choice columns)")

	-- Add player-choice columns to subscription stack.
	-- Idempotent: wrap each ALTER in a check on information_schema so re-running
	-- the migration on an already-updated DB is a no-op (idempotent migrations).
	local function columnExists(tableName, columnName)
		local result = db.storeQuery(string.format(
			"SELECT 1 FROM information_schema.COLUMNS " ..
			"WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '%s' AND COLUMN_NAME = '%s' LIMIT 1",
			tableName, columnName))
		if not result then
			return false
		end
		result.free()
		return true
	end

	local function indexExists(tableName, indexName)
		local result = db.storeQuery(string.format(
			"SELECT 1 FROM information_schema.STATISTICS " ..
			"WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '%s' AND INDEX_NAME = '%s' LIMIT 1",
			tableName, indexName))
		if not result then
			return false
		end
		result.free()
		return true
	end

	if not columnExists("player_vip_subscriptions", "is_active") then
		if not db.query("ALTER TABLE `player_vip_subscriptions` ADD COLUMN `is_active` TINYINT(1) NOT NULL DEFAULT 0 AFTER `source`") then
			return false
		end
	end

	if not columnExists("player_vip_subscriptions", "activation_order") then
		if not db.query("ALTER TABLE `player_vip_subscriptions` ADD COLUMN `activation_order` INT NOT NULL DEFAULT 0 AFTER `is_active`") then
			return false
		end
	end

	if not indexExists("player_vip_subscriptions", "idx_player_active") then
		if not db.query("ALTER TABLE `player_vip_subscriptions` ADD KEY `idx_player_active` (`player_id`, `is_active`)") then
			return false
		end
	end

	return true
end
