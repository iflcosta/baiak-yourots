function onUpdateDatabase()
	logMigration("Updating database to version 48 (VIP system: player_vip_subscriptions table)")

	-- New table: VIP subscription stack (LIFO with player choice)
	-- Idempotent: safe to re-run on a DB that already has this table.
	local createQuery = [[
		CREATE TABLE IF NOT EXISTS `player_vip_subscriptions` (
			`id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
			`player_id` INT UNSIGNED NOT NULL,
			`tier` TINYINT UNSIGNED NOT NULL,
			`expires_at` BIGINT NOT NULL,
			`created_at` BIGINT NOT NULL,
			`source` VARCHAR(32) NOT NULL DEFAULT 'scroll',
			PRIMARY KEY (`id`),
			KEY `idx_player_expires` (`player_id`, `expires_at`),
			CONSTRAINT `fk_player_vip_subs_player` FOREIGN KEY (`player_id`)
				REFERENCES `players` (`id`) ON DELETE CASCADE
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
	]]

	if not db.query(createQuery) then
		return false
	end

	return true
end
