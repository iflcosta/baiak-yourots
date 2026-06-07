function onUpdateDatabase()
	if not db.storeQuery("SELECT `config` FROM `server_config` WHERE `config` = 'db_version_47_done'") then
		logMigration("Updating database to version 47 (final migration marker)")
		db.query("INSERT INTO `server_config` VALUES ('db_version_47_done', '1')")
	end
	return true
end
