# Database (MariaDB)

> Schema overview, conventions, and migration notes for the
> `baiak_tfs18` database backing the TFS 1.8 server.

## Connection

- **Host:** `127.0.0.1`
- **Port:** `3306`
- **Database:** `baiak_tfs18`
- **User:** `root`
- **Password:** _(empty — local dev only)_
- **Charset:** `utf8mb4` / `utf8mb4_unicode_ci`

Configured in `server/config.lua` (`mysqlHost`, `mysqlPort`,
`mysqlUser`, `mysqlPassword`, `mysqlDatabase`).

CLI:

```powershell
& "C:\Program Files\MariaDB 12.3\bin\mysql.exe" -u root baiak_tfs18
```

## Schema source

- `server/schema.sql` — the canonical schema dump. Import order:
  tables first, foreign keys last. The engine uses `schema.sql` as
  the **target** schema on first run; the C++ side checks for
  missing tables and creates them on the fly in some cases.
- Migrations live in `server/data/migrations/` (see
  [Migrations](#migrations) below).

## Table groups

### Account & session

| Table                | Purpose                                       |
| -------------------- | --------------------------------------------- |
| `accounts`           | Login credentials, account flags (type, premium) |
| `account_sessions`   | Active session list (online state)           |
| `account_bans`       | Account-level ban history                     |
| `account_vipgroups`  | VIP group memberships (Phase 3)               |

### Player

| Table                 | Purpose                                      |
| --------------------- | -------------------------------------------- |
| `players`             | Player base row (id, name, level, vocation, health, mana, position, look) |
| `player_deaths`       | Death history                                |
| `player_depotitems`   | Depot chest contents                         |
| `player_inboxitems`   | Reward inbox                                 |
| `player_items`        | All inventory slots (backpack, equipment, etc.) |
| `player_spells`       | Known spells                                 |
| `player_storage`      | Persistent key/value storage (Lua scripts use) |
| `player_skills`       | Skill levels (sword, axe, dist, shield, etc.) |
| `player_statements`   | Guild / alliance statements                  |
| `player_namelocks`    | Name lock history                            |
| `player_rewards`      | Daily reward streak (Phase 3)                |
| `player_rewarditems`  | Reward items delivered _(see Migrations)_    |

### World

| Table              | Purpose                                       |
| ------------------ | --------------------------------------------- |
| `houses`           | House data (rent, owner, doors)               |
| `house_lists`      | Guest lists per house                         |
| `guilds`           | Guild base row                                |
| `guild_invites`    | Pending guild invites                         |
| `guild_members`    | Guild membership                              |
| `guild_ranks`      | Guild rank definitions                        |
| `guild_wars`       | Active guild wars                             |
| `tiles`            | Persistent map mutations (doors, signs, etc.) |
| `tile_items`       | Items on persistent tiles                     |

### Game

| Table              | Purpose                                       |
| ------------------ | --------------------------------------------- |
| `global_storage`   | Server-wide key/value (Lua: `Game.getStorage`) |
| `migrations`       | Migration tracking (see below)                |
| `server_config`    | Server config overrides (loaded by C++)      |
| `chatchannels`     | Chat channel definitions                      |
| `chatchannel_histories` | Channel scrollback                       |
| `market_offers`    | Market listings                               |
| `market_history`   | Market price history                          |

### System

| Table              | Purpose                                       |
| ------------------ | --------------------------------------------- |
| `reports`          | Player-submitted reports                      |
| `raids`            | Active raid state                             |
| `spy_reports`      | GM / command spy log                          |

## Migrations

The `migrations/` table tracks applied migrations:

```sql
CREATE TABLE `migrations` (
    `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(255) NOT NULL UNIQUE,
    `applied_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
);
```

### How to add a migration

1. Create a new file in `server/data/migrations/` named
   `NNNN_<short-desc>.sql` where `NNNN` is a zero-padded
   sequence number (e.g. `0001_add_player_rewarditems.sql`).
2. The file contains raw SQL: DDL, DML, or both. Use
   `CREATE TABLE IF NOT EXISTS` / `ALTER TABLE ... ADD IF NOT EXISTS`
   where possible so the migration is idempotent.
3. Insert a row: `INSERT INTO migrations (name) VALUES
   ('0001_add_player_rewarditems');`
4. Add a one-liner to [CHANGELOG.md](../CHANGELOG.md) under the
   unreleased section.
5. Update [todo.md](../todo.md) to mark the migration as done.

The engine runs migrations on boot (or has a dedicated
`./tfs --migrate` flag, check the C++ side).

### Known applied migrations

#### 0001 — `player_rewarditems` table _(2026-06-07)_

The TFS 1.8 upstream `server/schema.sql` does NOT include the
`player_rewarditems` table, but the C++ engine's `iologindata.cpp`
queries it on every player save. Missing it = the engine logs an
error and refuses to save. Fix:

```sql
CREATE TABLE IF NOT EXISTS `player_rewarditems` (
  `player_id`   INT(11)   NOT NULL,
  `pid`         INT(11)   NOT NULL,
  `sid`         INT(11)   NOT NULL,
  `itemtype`    INT(11)   NOT NULL,
  `count`       INT(11)   NOT NULL DEFAULT 0,
  `attributes`  BLOB,
  PRIMARY KEY (`player_id`, `pid`, `sid`),
  CONSTRAINT `player_rewarditems_fk` FOREIGN KEY (`player_id`)
    REFERENCES `players`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

## Storage key conventions (Lua)

Lua scripts use `player:setStorageValue(key, value)` /
`player:getStorageValue(key)` for persistent per-player state.
Conventions:

- **Range `100000 - 199999`** — quest flags
- **Range `200000 - 299999`** — VIP / account-tier flags (Phase 3)
- **Range `300000 - 399999`** — event participation (Phase 3)
- **Negative keys** — reserved, do not use
- **Range `0 - 99999`** — system / engine reserved

`Game.setStorageValue(key, value)` / `Game.getStorageValue(key)` —
server-wide state, same conventions.

## Backup / restore

Quick backup (run before any schema change):

```powershell
& "C:\Program Files\MariaDB 12.3\bin\mysqldump.exe" `
    -u root baiak_tfs18 > backup-$(Get-Date -Format yyyyMMdd).sql
```

Restore:

```powershell
& "C:\Program Files\MariaDB 12.3\bin\mysql.exe" `
    -u root baiak_tfs18 < backup-YYYYMMDD.sql
```

For continuous backup, configure MariaDB's binary log
(`log_bin = mariadb-bin`) and ship to a separate volume.
