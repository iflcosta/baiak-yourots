# VIP System — Feature Spec

> **Status:** `agreed` (user approved 2026-06-09 20:34)
> **Phase:** 3 (Systems & Spells)
> **Owner:** `agent_leader` (planning), `agent_developer` (server C++/Lua),
> `agent_client` (HTML/CSS/JS panel), `agent_qa` (audit)
> **Source of inspiration:** [aethrium-baiak](https://github.com/iflcosta/aethrium-baiak)
> — not a port, **a reference for the architecture**. The Baiak-Yourots
> implementation is custom-built, uses Ultralight for the UI (not native OTUI
> modals), and uses a freePremium baseline.

---

## 1. Problem

Baiak-Yourots needs a **monetized VIP subscription** — players pay monthly for
perks (XP/loot bonus, exclusive outfits/mounts, area access). The system must:

- Be **independent of the free-premium baseline** (the rest of the server
  treats all accounts as premium because `freePremium = true`; VIP is an
  *additional* flag on top of that).
- Use **TFS 1.x OOP Lua API** — no legacy TFS 0.4 procedural functions.
- **Reuse the existing extended-opcode channel** (opcode 181) for the
  server↔client UI sync, same pattern as `wheel.lua` and `astra_helper.lua`.
- Be **cumulative across tiers** (Silver = Bronze + Silver; Gold = Bronze
  + Silver + Gold) — that was the aethrium design and we keep it because
  it's the simplest mental model for the player.
- Use the **Ultralight SDK** (already integrated in AstraClient) to render
  a **custom HTML/CSS/JS panel** instead of native OTUI widgets.

### 1.1 Subscription stacking model (LIFO + player choice)

A player may have **multiple VIP subscriptions at the same time**. The
**active tier** is **player-controlled**: at any moment the player picks
which subscription from their stack is currently active. The default
behavior on a fresh purchase is **LIFO** (the most recently purchased
subscription becomes active automatically), but the player can switch
via the VIP panel.

**Auto-fallback on expiration:** when the currently active subscription
expires, the system automatically picks a new one — preferring the
**highest tier** among the remaining unexpired subscriptions. This way,
if a Gold expires and Bronze is next in the queue, the player
automatically falls back to Bronze (better than going to Free).

**Why player choice:** the aethrium model (LIFO rigid) is fine for
casual play, but a paying customer who bought Bronze 180 + Silver 30
might *want* to be Bronze for a while (e.g. they're PvPing and don't
need the Silver loot bonus), and then switch to Silver when they go
hunting. The player knows their play style better than the algorithm.

**Why auto-fallback:** without it, an active subscription that quietly
expires would leave the player with no active VIP even though they have
valid subscriptions in the queue. The auto-pick ensures the player
always gets the best tier available until everything is spent.

Example timeline:
```
T+0   : buys Bronze 180d
        Stack: [Bronze T+180]                                    active=Bronze (default)

T+5   : buys Gold 30d
        Stack: [Gold T+35, Bronze T+180]                         active=Gold (newest = default)

T+10  : player switches to Bronze via UI
        Stack: [Bronze T+180, Gold T+35]                         active=Bronze (manual override)

T+190 : Bronze expires
        Stack: [Gold T+35]                                       active=Gold (auto-fallback: highest tier remaining)
         ↑ player is still in Silver tier (Gold 30d, left 0 days from the T+5 buy at this point)
         ↑ wait, T+35 was at T+5+30=T+35, that already passed
         ↑ correction: at T+190, only Bronze (T+180, expired) and Gold (T+35, expired) are in the past
         ↑ so no active subscription remains → Free

        Actually let me redo this example more carefully:
```

Let me redo the example with proper math:

```
T+0    : buys Bronze 180d → expires at T+180
         Stack: [Bronze T+180]                                  active=Bronze (auto)

T+5    : buys Gold 30d   → expires at T+35
         Stack: [Gold T+35, Bronze T+180]                       active=Gold (auto, LIFO)

T+10   : player switches to Bronze via UI
         Stack: [Bronze T+180, Gold T+35]                       active=Bronze (manual)
         Note: Gold's expires_at is unchanged; it's just not active.

T+190  : Bronze expires
         Stack: [Gold T+35]                                     → Gold's expires_at is T+35
                                                                → Gold already expired at T+35
                                                                → stack is effectively empty
                                                                → active=Free

         Hmm, that's bad. The Gold 30d the player bought was wasted because
         the player switched to Bronze and Bronze's longer duration pushed
         Gold past its own expiration.

         This is a known trade-off: the player CHOSE to spend Bronze first,
         so they got what they asked for. But the Gold 30d is gone.
```

Trade-off acknowledgment: with player choice + auto-fallback, a subscription
that gets "skipped" by the player choosing a longer-duration subscription
is effectively lost. The spec accepts this — the player has full agency.
The alternative (auto-merge) would be confusing.

**The "LIFO by default + manual override" hybrid** keeps things simple
on the happy path (most players don't switch manually) and gives power
users the control they want.

## 2. Goals

| Goal                                         | Acceptance                                         |
| -------------------------------------------- | -------------------------------------------------- |
| Three subscription tiers (Bronze/Silver/Gold) | `tier` ∈ {1, 2, 3} in `player_vip_subscriptions`    |
| Multi-subscription stacking (LIFO)           | `player_vip_subscriptions` table, multiple rows    |
| Absolute expiration dates (no time freeze)   | `expires_at` set at purchase, never modified       |
| XP bonus per tier applied on login           | Bronze +10%, Silver +20%, Gold +30%                |
| Loot bonus per tier applied on login         | Bronze +10%, Silver +15%, Gold +25%                |
| Cumulative outfits (with addons) per tier    | Bronze 5, Silver 10, Gold 26                       |
| Cumulative mounts per tier                   | Bronze 5, Silver 10, Gold 25                       |
| Restricted-area tiles (Action IDs 50010-12)  | Movement event blocks entry on insufficient tier  |
| Activation scrolls (item IDs 24774-24776)    | Grants 30 days of Bronze/Silver/Gold              |
| GM command `!setvip <player> <tier> <days>`  | Used for testing, manual grants, customer support  |
| Auto-revoke perks on expiration              | Login handler revokes outfits/mounts, warns player |
| Ultralight HTML panel (`/vip` command)       | Shows active tier, total days, full stack, perks   |

## 3. Non-goals (out of scope for v1)

- **Real payment gateway** (Pix, PayPal, Stripe). The "Buy" button in the
  UI is a stub that links to an external site.
- **Daily rewards for VIP players.** Separate system.
- **Auto-renewal / subscriptions.** Manual top-up only.
- **Tier downgrade protection.** If a Gold player buys Silver, they
  *will* drop to Silver when the Gold expires — they keep all dates
  absolute, so it's not destructive, just less efficient.
- **VIP-only chat channels.** Future.
- **VIP commands for staff** (e.g. `/vipmsg`). Out of scope.

## 4. Tier Matrix

| Tier    | ID | XP Bonus | Loot Bonus | Outfits (male lookType)       | Outfits (female lookType)     | Mounts (server IDs)                              | Areas       |
| ------- | -- | -------- | ---------- | ----------------------------- | ----------------------------- | ------------------------------------------------ | ----------- |
| Free    | 0  | +0%      | +0%        | —                             | —                             | —                                                | Free zones  |
| Bronze  | 1  | +10%     | +10%       | 134, 143, 152, 154, 289       | 142, 147, 156, 158, 288       | 17, 16, 5, 6, 11                                 | Bronze area |
| Silver  | 2  | +20%     | +15%       | Bronze + 268, 432, 465, 884, 899 | Bronze + 269, 433, 466, 885, 900 | Bronze + 40, 9, 31, 39, 106                       | Bronze + Silver areas |
| Gold    | 3  | +30%     | +25%       | Silver + 541, 512, 665, 667, 846, 1202, 1444, 1489, 1675, 1680, 1713, 1725, 1745, 1809, 1831, 1824 | Silver + 542, 513, 664, 666, 845, 1203, 1445, 1490, 1676, 1681, 1714, 1726, 1746, 1808, 1832, 1825 | Silver + 144, 184, 175, 174, 87, 99, 179, 180, 181, 94, 98, 206, 202, 167, 162 | All zones |

**Cumulative logic** (Gold has all 26 outfits and 25 mounts; Silver has
10 outfits + 10 mounts, etc.).

**Standard premium outfits** (lookTypes 128-133 male / 136-141 female) get
addon 3 unlocked for any VIP player. Implemented in the login handler.

## 5. Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Client (AstraClient / Ultralight)                               │
│                                                                 │
│  mods/game_vip/                                                 │
│    vip.lua          — module: registerExtendedOpcode(181)       │
│    vip_panel.html   — UI: tier badge, stack list, perks         │
│    vip.css          — purple/gray theme                         │
│    vip.js           — calls window.callLuaFunction(...)         │
│                                                                 │
│  Window opens on:                                               │
│    - Talkaction "!vip" (server-side) → opcode 181 push          │
│    - Keybind Ctrl+V (client-side)                                │
└─────────────────────────────────────────────────────────────────┘
                            │ extended opcode 181
                            │ (JSON payload)
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ Server (TFS 1.8 + Lua)                                          │
│                                                                 │
│  data/scripts/network/vip/vip_protocol.lua  — onExtendedOpcode(181) │
│  data/lib/core/vip_system.lua               — helpers           │
│  data/scripts/creaturescripts/vip_login.lua — login handler     │
│  data/scripts/movements/vip_tiles.lua       — area restriction  │
│  data/scripts/actions/vip_scroll.lua        — activation scrolls│
│  data/scripts/talkactions/gm/setvip.lua     — GM command         │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ C++ engine (TFS 1.8)                                            │
│                                                                 │
│  src/player.h    — vipTier, vipExpires members + 5 method decls │
│  src/player.cpp  — isVip, getVipDaysRemaining, getVipXpBonus,   │
│                    getVipLootBonus implementations              │
│  src/luaplayer.cpp — register 5 Lua bindings                     │
│  src/iologindata.cpp — load active subscription into player     │
│  src/database.cpp    — DB access layer (subscription queries)  │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ Database (MariaDB)                                              │
│                                                                 │
│  player_vip_subscriptions                                       │
│    id, player_id, tier, expires_at, created_at, source          │
│                                                                 │
│  — `vip_tier` and `vip_expires` are NOT used in v1 (kept out    │
│    of players table). Active subscription is computed by query. │
└─────────────────────────────────────────────────────────────────┘
```

## 6. Data Layer

### 6.1 Migration `048_vip_system.lua`

```lua
-- New table: VIP subscription stack (LIFO with player choice)
db.query([[
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
]])
```

### 6.2 Migration `049_vip_player_choice.lua`

```lua
-- Add player-choice columns to subscription stack
db.query([[
    ALTER TABLE `player_vip_subscriptions`
        ADD COLUMN `is_active` TINYINT(1) NOT NULL DEFAULT 0 AFTER `source`,
        ADD COLUMN `activation_order` INT NOT NULL DEFAULT 0 AFTER `is_active`,
        ADD KEY `idx_player_active` (`player_id`, `is_active`);
]])
```

**Why no columns on `players` table:** the active tier is *derived* from
the subscription stack. Storing it on `players` would create a
denormalization that's easy to desync.

### 6.3 Schema update (`server/schema.sql`)

Both CREATE TABLE (with `is_active` + `activation_order` columns) +
ALTER statements at the bottom of the file.

### 6.4 Computing the active subscription

```sql
-- Active subscription (the one the player chose, or auto-fallback)
SELECT id, tier, expires_at
FROM player_vip_subscriptions
WHERE player_id = ? AND is_active = 1 AND expires_at > UNIX_TIMESTAMP()
LIMIT 1;
```

### 6.5 Auto-fallback query

Used when the active subscription expires and no manual choice is pending:

```sql
-- Highest tier remaining (auto-fallback)
SELECT id, tier
FROM player_vip_subscriptions
WHERE player_id = ? AND expires_at > UNIX_TIMESTAMP()
ORDER BY tier DESC, expires_at ASC
LIMIT 1;
```

(Tier DESC → picks the best tier available. Tie-break: the one that
expires first, because that's the next one to "use up".)

### 6.6 C++ state — **transient, not persisted**

The `players` table does NOT store vip_tier or vip_expires. Instead, the
values live in `player_vip_subscriptions` and the C++ Player object
holds them as **in-memory cache** populated on login and refreshed on
tier changes.

```cpp
// player.h
// VIP system (in-memory cache, populated from DB on login)
uint8_t vipTier = 0;
int64_t vipExpires = 0;
```

### 6.7 C++ public methods (`player.h`)

```cpp
// VIP system — getters only (setters go through Lua, which writes to DB)
bool isVip() const;
uint8_t getVipTier() const { return vipTier; }
int64_t getVipExpires() const { return vipExpires; }
int32_t getVipDaysRemaining() const;
int32_t getVipXpBonus() const;   // returns 0, 10, 20 or 30
int32_t getVipLootBonus() const; // returns 0, 10, 15 or 25
```

No `setVip` C++ method — all mutations go through Lua scripts that write
to `player_vip_subscriptions` and call a `reloadVipCache(player)` helper.

### 6.8 C++ implementations (`player.cpp`)

```cpp
bool Player::isVip() const {
    return vipTier > 0 && vipExpires > time(nullptr);
}

int32_t Player::getVipDaysRemaining() const {
    if (!isVip()) return 0;
    return static_cast<int32_t>(std::ceil((vipExpires - time(nullptr)) / 86400.0));
}

int32_t Player::getVipXpBonus() const {
    if (!isVip()) return 0;
    switch (vipTier) {
        case 1: return 10;
        case 2: return 20;
        case 3: return 30;
        default: return 0;
    }
}

int32_t Player::getVipLootBonus() const {
    if (!isVip()) return 0;
    switch (vipTier) {
        case 1: return 10;
        case 2: return 15;
        case 3: return 25;
        default: return 0;
    }
}

// Helper called by Lua after a subscription change
void Player::reloadVipCache() {
    auto result = g_database.storeQuery(fmt::format(
        "SELECT tier, expires_at FROM player_vip_subscriptions "
        "WHERE player_id = {} AND is_active = 1 AND expires_at > UNIX_TIMESTAMP() "
        "LIMIT 1",
        getGUID()));
    if (result) {
        vipTier = result->getNumber<uint8_t>("tier");
        vipExpires = result->getNumber<int64_t>("expires_at");
    } else {
        vipTier = 0;
        vipExpires = 0;
    }
}
```

### 6.9 Lua bindings (`luaplayer.cpp`)

Register 5 methods:

| Lua method                      | C++ binding              | Returns        |
| ------------------------------- | ------------------------ | -------------- |
| `player:isVip()`                | `Player::isVip`          | boolean        |
| `player:getVipTier()`           | `Player::getVipTier`     | int (0..3)     |
| `player:getVipExpires()`        | `Player::getVipExpires`  | int (timestamp)|
| `player:getVipDaysRemaining()`  | `Player::getVipDaysRemaining` | int (days)|
| `player:getVipXpBonus()`        | `Player::getVipXpBonus`  | int (0/10/20/30)|
| `player:getVipLootBonus()`      | `Player::getVipLootBonus`| int (0/10/15/25)|

(No `player:setVip()` binding — subscriptions are managed via Lua
helpers in `vip_system.lua`.)

## 7. Server Lua Layer

### 7.1 Outfit / mount tables (`data/lib/core/vip_system.lua`)

```lua
VipSystem = VipSystem or {}

VipSystem.TIERS = { [0] = "Free", [1] = "Bronze", [2] = "Silver", [3] = "Gold" }

VipSystem.OUTFITS = {
    [1] = { male = {134, 143, 152, 154, 289},         female = {142, 147, 156, 158, 288} },
    [2] = { male = {268, 432, 465, 884, 899},          female = {269, 433, 466, 885, 900} },
    [3] = { male = {541, 512, 665, 667, 846, 1202, 1444, 1489, 1675, 1680, 1713, 1725, 1745, 1809, 1831, 1824},
            female = {542, 513, 664, 666, 845, 1203, 1445, 1490, 1676, 1681, 1714, 1726, 1746, 1808, 1832, 1825} },
}

VipSystem.MOUNTS = {
    [1] = { 17, 16, 5, 6, 11 },
    [2] = { 40, 9, 31, 39, 106 },
    [3] = { 144, 184, 175, 174, 87, 99, 179, 180, 181, 94, 98, 206, 202, 167, 162 },
}

VipSystem.STANDARD_PREMIUM_OUTFITS = {
    male   = { 128, 129, 130, 131, 132, 133, 134, 143, 144, 145, 146 },
    female = { 136, 137, 138, 139, 140, 141, 142, 147, 148, 149, 150 },
}

-- Get all outfits from tier 1..tier (cumulative)
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

function VipSystem.getAllTierMounts(tier)
    local result = {}
    for t = 1, tier do
        for _, mountId in ipairs(VipSystem.MOUNTS[t] or {}) do
            result[#result + 1] = mountId
        end
    end
    return result
end

function VipSystem.grantRewards(player, tier)
    local isFemale = player:getSex() == PLAYERSEX_FEMALE
    local key = isFemale and "female" or "male"
    for _, lookType in ipairs(VipSystem.STANDARD_PREMIUM_OUTFITS[key]) do
        player:addOutfitAddon(lookType, 3)
    end
    for _, lookType in ipairs(VipSystem.getAllTierOutfits(tier, isFemale)) do
        player:addOutfitAddon(lookType, 3)
    end
    for _, mountId in ipairs(VipSystem.getAllTierMounts(tier)) do
        player:addMount(mountId)
    end
end

function VipSystem.revokeAllRewards(player)
    local isFemale = player:getSex() == PLAYERSEX_FEMALE
    for tier = 1, 3 do
        for _, lookType in ipairs(VipSystem.getAllTierOutfits(tier, isFemale)) do
            player:removeOutfit(lookType)
        end
        for _, mountId in ipairs(VipSystem.getAllTierMounts(tier)) do
            player:removeMount(mountId)
        end
    end
end

-- ── Subscription stack (LIFO + player choice) ──────────────────────

-- Get the player's currently active subscription (or nil)
function VipSystem.getActiveSubscription(player)
    local result = db.asyncQuery(string.format(
        "SELECT id, tier, expires_at, source, activation_order " ..
        "FROM player_vip_subscriptions " ..
        "WHERE player_id = %d AND is_active = 1 AND expires_at > %d " ..
        "LIMIT 1",
        player:getGuid(), os.time()))
    if not result or not result:getNumber("id") then
        return nil
    end
    return {
        id              = result:getNumber("id"),
        tier            = result:getNumber("tier"),
        expiresAt       = result:getNumber("expires_at"),
        source          = result:getString("source"),
        activationOrder = result:getNumber("activation_order"),
    }
end

-- Get the next auto-fallback subscription (highest tier remaining)
function VipSystem.getAutoFallbackSubscription(player)
    local result = db.asyncQuery(string.format(
        "SELECT id, tier, expires_at " ..
        "FROM player_vip_subscriptions " ..
        "WHERE player_id = %d AND expires_at > %d " ..
        "ORDER BY tier DESC, expires_at ASC LIMIT 1",
        player:getGuid(), os.time()))
    if not result or not result:getNumber("id") then
        return nil
    end
    return {
        id        = result:getNumber("id"),
        tier      = result:getNumber("tier"),
        expiresAt = result:getNumber("expires_at"),
    }
end

-- Get the full subscription stack (all unexpired, ordered)
function VipSystem.getStack(player)
    local result = db.asyncQuery(string.format(
        "SELECT id, tier, expires_at, created_at, source, is_active, activation_order " ..
        "FROM player_vip_subscriptions " ..
        "WHERE player_id = %d AND expires_at > %d " ..
        "ORDER BY is_active DESC, tier DESC, expires_at ASC",
        player:getGuid(), os.time()))
    local stack = {}
    if result then
        repeat
            table.insert(stack, {
                id              = result:getNumber("id"),
                tier            = result:getNumber("tier"),
                expiresAt       = result:getNumber("expires_at"),
                createdAt       = result:getNumber("created_at"),
                source          = result:getString("source"),
                isActive        = result:getNumber("is_active") == 1,
                activationOrder = result:getNumber("activation_order"),
            })
        until not result:next()
    end
    return stack
end

-- Push a new subscription to the player's stack
-- Default: becomes the new active (LIFO)
-- @param player Player
-- @param tier   1..3
-- @param days   positive integer
-- @param source string: "scroll" | "gm" | "payment"
-- @return table {id, tier, expires_at, daysAdded, becameActive}
function VipSystem.grantSubscription(player, tier, days, source)
    assert(tier >= 1 and tier <= 3, "Invalid VIP tier")
    assert(days > 0, "Days must be positive")

    local playerId = player:getGuid()
    local now = os.time()
    local expiresAt = now + (days * 86400)

    -- The new subscription becomes active by default (LIFO behavior)
    -- Previous active is deactivated.
    db.asyncQuery(string.format(
        "UPDATE player_vip_subscriptions SET is_active = 0 " ..
        "WHERE player_id = %d", playerId))

    -- Insert the new subscription as the active one
    db.asyncQuery(string.format(
        "INSERT INTO player_vip_subscriptions " ..
        "(player_id, tier, expires_at, created_at, source, is_active, activation_order) " ..
        "VALUES (%d, %d, %d, %d, '%s', 1, %d)",
        playerId, tier, expiresAt, now, source, os.time()))

    VipSystem.reloadPlayerCache(player)
    return { tier = tier, expiresAt = expiresAt, daysAdded = days, becameActive = true }
end

-- Player-initiated switch: activate a specific subscription from their stack
-- @param player Player
-- @param subscriptionId INT
-- @return bool ok, string err
function VipSystem.activateSubscription(player, subscriptionId)
    local playerId = player:getGuid()
    local now = os.time()

    -- Verify the subscription belongs to this player and is still valid
    local result = db.asyncQuery(string.format(
        "SELECT id, tier FROM player_vip_subscriptions " ..
        "WHERE id = %d AND player_id = %d AND expires_at > %d",
        subscriptionId, playerId, now))

    if not result or not result:getNumber("id") then
        return false, "Invalid or expired subscription"
    end

    -- Deactivate all of the player's subscriptions
    db.asyncQuery(string.format(
        "UPDATE player_vip_subscriptions SET is_active = 0 " ..
        "WHERE player_id = %d", playerId))

    -- Activate the chosen one
    db.asyncQuery(string.format(
        "UPDATE player_vip_subscriptions SET is_active = 1, activation_order = %d " ..
        "WHERE id = %d", os.time(), subscriptionId))

    VipSystem.reloadPlayerCache(player)
    return true
end

-- Revoke all subscriptions for a player
function VipSystem.revokeAll(player)
    db.asyncQuery(string.format(
        "DELETE FROM player_vip_subscriptions WHERE player_id = %d",
        player:getGuid()))
    VipSystem.reloadPlayerCache(player)
end

-- Auto-fallback: pick highest tier remaining and activate it.
-- Called on login when the previously-active subscription has expired.
-- @return table|nil  the activated subscription, or nil if stack is empty
function VipSystem.autoFallback(player)
    local next = VipSystem.getAutoFallbackSubscription(player)
    if not next then return nil end

    db.asyncQuery(string.format(
        "UPDATE player_vip_subscriptions SET is_active = 0 " ..
        "WHERE player_id = %d", player:getGuid()))

    db.asyncQuery(string.format(
        "UPDATE player_vip_subscriptions SET is_active = 1, activation_order = %d " ..
        "WHERE id = %d", os.time(), next.id))

    VipSystem.reloadPlayerCache(player)
    return next
end

-- Reloads the player's in-memory vipTier/vipExpires cache.
-- Called after any subscription change.
function VipSystem.reloadPlayerCache(player)
    local sub = VipSystem.getActiveSubscription(player)
    if sub then
        VipSystem._setPlayerCache(player, sub.tier, sub.expiresAt)
    else
        VipSystem._setPlayerCache(player, 0, 0)
    end
end
```

**Correction on the LIFO logic:** I had the ordering wrong in the first
draft. The LIFO stack where the **latest purchase is spent first** means:

- The active subscription is the one with the **earliest unexpired
  `expires_at`** (smallest future timestamp), not the largest.

Visualizing with a real stack:
```
Stack from "top" (active) to "bottom" (last to be reached):

T+0   buys Bronze 180 → expires at T+180        [Bronze T+180]
T+5   buys Gold 30   → expires at T+35          [Gold T+35, Bronze T+180]
                                                      ^--- active (smallest unexpired)
T+35  Gold expires, Bronze becomes active       [Bronze T+180]
T+215 Bronze expires                            []
```

So the active subscription is the one with the **smallest unexpired
`expires_at`**. Updating the query and helpers:

```sql
-- Active subscription (top of stack, consumed first)
SELECT id, tier, expires_at
FROM player_vip_subscriptions
WHERE player_id = ? AND expires_at > UNIX_TIMESTAMP()
ORDER BY expires_at ASC
LIMIT 1;
```

```lua
function VipSystem.getActiveSubscription(player)
    local result = db.asyncQuery(string.format(
        "SELECT id, tier, expires_at FROM player_vip_subscriptions " ..
        "WHERE player_id = %d AND expires_at > %d " ..
        "ORDER BY expires_at ASC LIMIT 1",
        player:getGuid(), os.time()))
    if not result or not result:getNumber("id") then
        return nil
    end
    return {
        id        = result:getNumber("id"),
        tier      = result:getNumber("tier"),
        expiresAt = result:getNumber("expires_at"),
    }
end

function VipSystem.getStack(player)
    local result = db.asyncQuery(string.format(
        "SELECT id, tier, expires_at, created_at, source " ..
        "FROM player_vip_subscriptions " ..
        "WHERE player_id = %d AND expires_at > %d " ..
        "ORDER BY expires_at ASC",  -- top of stack first
        player:getGuid(), os.time()))
    local stack = {}
    if result then
        repeat
            table.insert(stack, {
                id        = result:getNumber("id"),
                tier      = result:getNumber("tier"),
                expiresAt = result:getNumber("expires_at"),
                createdAt = result:getNumber("created_at"),
                source    = result:getString("source"),
            })
        until not result:next()
    end
    return stack
end

function VipSystem.grantSubscription(player, tier, days, source)
    local now = os.time()
    local expiresAt = now + (days * 86400)
    db.asyncQuery(string.format(
        "INSERT INTO player_vip_subscriptions " ..
        "(player_id, tier, expires_at, created_at, source) " ..
        "VALUES (%d, %d, %d, %d, '%s')",
        player:getGuid(), tier, expiresAt, now, source))
    -- Re-cache player's VIP state
    VipSystem.reloadPlayerCache(player)
    return { tier = tier, expiresAt = expiresAt, daysAdded = days }
end

function VipSystem.revokeAll(player)
    db.asyncQuery(string.format(
        "DELETE FROM player_vip_subscriptions WHERE player_id = %d",
        player:getGuid()))
    VipSystem.reloadPlayerCache(player)
end

-- Reloads the player's in-memory vipTier/vipExpires cache.
-- Called after any subscription change.
function VipSystem.reloadPlayerCache(player)
    local sub = VipSystem.getActiveSubscription(player)
    if sub then
        -- Set the C++ cache directly (we add a binding for this)
        VipSystem._setPlayerCache(player, sub.tier, sub.expiresAt)
    else
        VipSystem._setPlayerCache(player, 0, 0)
    end
end
```

### 7.2 Login handler (`data/scripts/creaturescripts/vip_login.lua`)

CreatureEvent `VipLogin` — `onLogin` callback:

```lua
local loginEvent = CreatureEvent("VipLogin")

function loginEvent.onLogin(player)
    -- First check: is the currently-active subscription still valid?
    local active = VipSystem.getActiveSubscription(player)

    if not active then
        -- Active expired (or never set). Try auto-fallback to highest tier.
        local fallback = VipSystem.autoFallback(player)
        if not fallback then
            -- Stack is empty. Revoke rewards and return.
            VipSystem.revokeAllRewards(player)
            VipSystem.reloadPlayerCache(player)
            return true
        end
        active = fallback
    end

    -- Reload cache (in case auto-fallback just ran)
    VipSystem.reloadPlayerCache(player)

    local stack = VipSystem.getStack(player)
    local tier = active.tier
    local daysLeft = math.ceil((active.expiresAt - os.time()) / 86400)

    -- Grant rewards for the active tier
    VipSystem.grantRewards(player, tier)

    -- Apply XP bonus
    local xpBonus = player:getVipXpBonus()
    if xpBonus > 0 then
        player:setExperienceRate(ExperienceRateType.BONUS, 100 + xpBonus)
    end

    -- Send status message
    if daysLeft <= 3 then
        player:sendTextMessage(MESSAGE_STATUS_WARNING,
            string.format("[VIP] Your VIP %s expires in %d day(s)!",
                VipSystem.TIERS[tier] or "", daysLeft))
    else
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
            string.format("[VIP] Welcome! VIP %s active — %d days remaining.",
                VipSystem.TIERS[tier] or "", daysLeft))
    end

    -- Notify if there are more subscriptions in the stack
    if #stack > 1 then
        local others = {}
        for _, sub in ipairs(stack) do
            if sub.id ~= active.id then
                local d = math.ceil((sub.expiresAt - os.time()) / 86400)
                table.insert(others, string.format("%s (%dd)", VipSystem.TIERS[sub.tier], d))
            end
        end
        if #others > 0 then
            player:sendTextMessage(MESSAGE_INFO_DESCR,
                "[VIP] Other subscriptions: " .. table.concat(others, ", "))
        end
    end

    return true
end

loginEvent:register()
```

### 7.3 VIP tile restriction (`data/scripts/movements/vip_tiles.lua`)

MoveEvent with Action IDs:

| Action ID | minTier | Friendly name   |
| --------- | ------- | --------------- |
| 50010     | 1       | "VIP"           |
| 50011     | 2       | "VIP Silver"    |
| 50012     | 3       | "VIP Gold"      |

`onStepIn` callback: if `player:getVipTier() < minTier`, teleport back to
`fromPosition`, send message, POFF effect. Uses the in-memory cache
(`getVipTier()`) which is always up-to-date after `reloadPlayerCache`.

### 7.4 Activation scrolls (`data/scripts/actions/vip_scroll.lua`)

| Item ID | Tier | Days | Name   |
| ------- | ---- | ---- | ------ |
| 24774   | 1    | 30   | Bronze |
| 24775   | 2    | 30   | Silver |
| 24776   | 3    | 30   | Gold   |

`onUse` callback:
```lua
function action.onUse(player, item, fromPosition, target, toPosition, isHotkey)
    local config = VIP_SCROLLS[item:getId()]
    if not config then return false end

    local result = VipSystem.grantSubscription(player, config.tier, config.days, "scroll")

    player:getPosition():sendMagicEffect(CONST_ME_GIFT_WRAPS)
    player:sendTextMessage(MESSAGE_EVENT_ADVANCE,
        string.format("[VIP] You have activated %d days of VIP %s!",
            config.days, config.name))

    item:remove(1)
    return true
end
```

Items need to be defined in `data/items/items.xml` and `data/items/items.otb`.

### 7.5 GM command (`data/scripts/talkactions/gm/setvip.lua`)

Talkaction `!setvip <player> <tier> <days>`:
- Tier 0-3, days 0-365.
- GM access only (`player:getGroup():getAccess()`).
- If `tier == 0` and `days == 0` → revoke all subscriptions.
- Else, call `VipSystem.grantSubscription(targetPlayer, tier, days, "gm")`.

```
!setvip iflopes2 3 90       # Grant 90 days of Gold (becomes active by default)
!setvip iflopes2 0 0        # Revoke all VIP
!setvip iflopes2 1 30       # Grant 30 days of Bronze (becomes active if no Gold present)
```

### 7.6 Talkaction `!vip` (player-facing) (`data/scripts/talkactions/vip.lua`)

Triggers the UI: sends extended opcode 181 to the player with current
tier/days/entire stack. Client interprets the opcode and opens the panel.

```lua
function player.onSay(player, words, param)
    local payload = json.encode({
        type = "vip_info",
        activeTier = player:getVipTier(),
        activeDays = player:getVipDaysRemaining(),
        activeExpiresAt = player:getVipExpires(),
        stack = VipSystem.getStack(player),  -- full stack with is_active flags
        isVip = player:isVip(),
    })
    player:sendExtendedOpcode(181, payload)
end
```

### 7.7 Network protocol (`data/scripts/network/vip/vip_protocol.lua`)

`onExtendedOpcode(181, player, buffer)`:

#### Server → client message
- Opcode 181 + JSON payload:
  ```json
  {
    "type": "vip_info",
    "activeSubscriptionId": 42,
    "activeTier": 2,
    "activeTierName": "Silver",
    "activeDaysRemaining": 14,
    "activeExpiresAt": 1735689600,
    "xpBonus": 20,
    "lootBonus": 15,
    "isVip": true,
    "outfitsUnlocked": [134, 143, ...],
    "mountsUnlocked": [17, 16, ...],
    "stack": [
      { "id": 42, "tier": 2, "tierName": "Silver", "expiresAt": 1735689600,
        "daysRemaining": 14, "source": "scroll", "isActive": true },
      { "id": 41, "tier": 1, "tierName": "Bronze", "expiresAt": 1738281600,
        "daysRemaining": 45, "source": "scroll", "isActive": false }
    ]
  }
  ```

The `stack` array shows the full subscription queue. `isActive: true` marks
the current active subscription (max 1 at a time). The UI uses this to
render "Activar" buttons on non-active items.

#### Client → server messages
- Request refresh:
  ```json
  { "type": "request_update" }
  ```
  Server re-sends `vip_info`.

- Activate a specific subscription (player choice):
  ```json
  { "type": "activate_subscription", "subscriptionId": 41 }
  ```
  Server calls `VipSystem.activateSubscription(player, subscriptionId)`,
  then re-sends `vip_info`. If the subscription is invalid or expired,
  server sends an `error` message back.

#### Error message
- Opcode 181 + JSON payload:
  ```json
  { "type": "error", "message": "Invalid or expired subscription" }
  ```
  Client displays via `displayFailureMessage`.

## 8. Client Layer (Ultralight)

### 8.1 Module structure (`client/mods/game_vip/`)

```
mods/game_vip/
  vip.otmod          — module manifest, autoload-priority 1002
  vip.lua            — registers opcode 181, instantiates Ultralight view
  styles/
    vip_panel.html   — UI markup
    vip.css          — purple/gray theme
    vip.js           — event handlers, callLuaFunction bridge
  assets/
    badge-bronze.png, badge-silver.png, badge-gold.png
    vip-icon.png
```

### 8.2 Module bootstrap (`vip.lua`)

```lua
VIP_OPCODE = 181
VIP_VIEW_NAME = "vip_panel"
VIP_HTML_PATH = "/vip/vip_panel.html"

function init()
    ProtocolGame.registerExtendedOpcode(VIP_OPCODE, onExtendedOpcode)
    connect(g_game, { onGameStart = onGameStart, onGameEnd = onGameEnd })
    connect(g_keyboard, { onPress = onKeyPress })
    if g_game.isOnline() then onGameStart() end
end

function onGameStart()
    g_game.getProtocolGame():sendExtendedOpcode(VIP_OPCODE, '{"type":"request_update"}')
end

function onExtendedOpcode(protocol, opcode, buffer)
    if opcode ~= VIP_OPCODE then return end
    local data = json.decode(buffer)
    if data.type == "vip_info" then
        renderVipPanel(data)
    end
end

function toggleVipPanel()
    g_ultralight.createView(VIP_VIEW_NAME, 480, 540, VIP_HTML_PATH)
    g_ui.displayUI("vip_panel"):show()
end
```

### 8.3 UI markup (`vip_panel.html`)

```html
<div class="vip-container" id="app">
  <div class="vip-header">
    <img id="tier-badge" src="badge-bronze.png" />
    <div>
      <div class="vip-tier-name" id="tier-name">Bronze</div>
      <div class="vip-days" id="vip-days">30 days remaining</div>
    </div>
  </div>

  <div class="vip-perks">
    <div class="perk"><span>XP Bonus</span><span id="xp-bonus">+10%</span></div>
    <div class="perk"><span>Loot Bonus</span><span id="loot-bonus">+10%</span></div>
    <div class="perk"><span>Outfits</span><span id="outfit-count">5</span></div>
    <div class="perk"><span>Mounts</span><span id="mount-count">5</span></div>
  </div>

  <div class="vip-stack" id="stack-section">
    <h3>Subscription Stack</h3>
    <div id="stack-list"></div>
  </div>

  <div class="vip-actions">
    <button id="buy-btn">Buy / Extend VIP</button>
  </div>
</div>
```

### 8.4 Theme (`vip.css`)

Palette:
- Background: `#1a1a1f` (near-black)
- Primary accent: `#7c3aed` (purple)
- Secondary accent: `#a1a1aa` (gray)
- Tier colors: Bronze `#cd7f32`, Silver `#c0c0c0`, Gold `#ffd700`

### 8.5 JS bridge (`vip.js`)

```js
function updateVipData(json) {
    const data = JSON.parse(json);
    const tierName = (data.activeTierName || 'Free').toLowerCase();

    document.getElementById('tier-badge').src = `badge-${tierName}.png`;
    document.getElementById('tier-name').textContent = data.activeTierName || 'Free';
    document.getElementById('tier-name').className = `vip-tier-name tier-${tierName}`;
    document.getElementById('vip-days').textContent =
        data.isVip ? `${data.activeDaysRemaining} days remaining` : 'No active VIP';

    document.getElementById('xp-bonus').textContent = `+${data.xpBonus}%`;
    document.getElementById('loot-bonus').textContent = `+${data.lootBonus}%`;
    document.getElementById('outfit-count').textContent = data.outfitsUnlocked.length;
    document.getElementById('mount-count').textContent = data.mountsUnlocked.length;

    // Render the stack with Activate buttons on non-active items
    const stackList = document.getElementById('stack-list');
    stackList.innerHTML = '';
    if (data.stack && data.stack.length > 0) {
        data.stack.forEach((sub) => {
            const item = document.createElement('div');
            item.className = 'stack-item' + (sub.isActive ? ' stack-active' : '');
            item.dataset.subId = sub.id;

            const days = sub.daysRemaining;
            const sourceLabel = sub.source === 'gm' ? ' (GM)' : '';
            const activateBtn = sub.isActive
                ? '<span class="stack-badge">Active</span>'
                : '<button class="stack-activate" data-sub-id="' + sub.id + '">Activate</button>';

            item.innerHTML = `
                <span class="stack-tier tier-${sub.tierName.toLowerCase()}">${sub.tierName}</span>
                <span class="stack-days">${days} days${sourceLabel}</span>
                ${activateBtn}
            `;
            stackList.appendChild(item);
        });

        // Bind activate buttons
        stackList.querySelectorAll('.stack-activate').forEach((btn) => {
            btn.onclick = (e) => {
                e.stopPropagation();
                const subId = btn.dataset.subId;
                window.callLuaFunction('game_vip.onActivateSubscription', subId);
            };
        });
    } else {
        stackList.innerHTML = '<div class="stack-empty">No subscriptions</div>';
    }

    document.getElementById('buy-btn').onclick = () => {
        window.callLuaFunction('game_vip.onBuyClick');
    };
}
```

### 8.6 Lua ↔ JS callbacks

The `UltraLightManager` already provides a `window.callLuaFunction(path, ...)`.
We register:

- `game_vip.onBuyClick()` (Lua) — currently a no-op stub that displays
  "Payment integration coming soon" text message.
- `game_vip.onActivateSubscription(subscriptionId)` (Lua) — receives a
  subscription ID from the UI and triggers the switch:
  ```lua
  function onActivateSubscription(subId)
      local ok, err = VipSystem.activateSubscription(g_game.getLocalPlayer(), tonumber(subId))
      if ok then
          g_game.getProtocolGame():sendExtendedOpcode(VIP_OPCODE, '{"type":"request_update"}')
      else
          modules.game_textmessage.displayFailureMessage("[VIP] " .. (err or "Failed"))
      end
  end
  ```

## 9. Config Changes (`server/config.lua`)

No new config keys for v1. The bonus values (10/20/30 XP, 10/15/25 loot)
are hardcoded in C++ (matches aethrium). Exposed via `config.lua` in v2
when we have a balance pass.

`freePremium = true` stays as is (unrelated to VIP).

## 10. Verification

### 10.1 Smoke tests (manual, post-deploy)

1. **Free player** — log in with no VIP. Confirm:
   - No XP bonus.
   - No VIP outfits.
   - Walking onto AID 50010 tile → bounce back.

2. **Bronze via scroll** — use item 24774. Confirm:
   - Server log: "You have activated 30 days of VIP Bronze!".
   - Logout/login → 5 bronze outfits + addons available.
   - XP rate `+10%`.
   - Walking onto AID 50010 → success; 50011 → bounce.

3. **Gold via GM command** — `!setvip <name> 3 30`. Confirm:
   - 26 outfits + 25 mounts available.
   - XP rate `+30%`, loot rate `+25%`.

4. **LIFO default + manual switch** — Bronze 180, then Gold 30:
   - Active tier: Gold (auto, newest = LIFO default).
   - Stack shows: [Gold 30d (Active), Bronze 180d].
   - Open VIP panel, click "Activate" on Bronze.
   - Active tier changes to Bronze. Outfits drop to Bronze's 5 (Silver/Gold revoked).
   - Gold's expires_at unchanged — it's still in the stack, just inactive.

5. **Auto-fallback on expiration** — Gold active, advance time past Gold's expiry:
   - Logout/login.
   - System auto-activates the highest tier remaining.
   - If only Bronze left → active becomes Bronze (auto-fallback to highest).
   - If nothing left → tier 0, rewards revoked.

6. **Player switches to lower tier** — Gold active, switch to Bronze:
   - Active becomes Bronze (manually).
   - Gold stays in stack but inactive.
   - When Bronze expires, auto-fallback picks the highest remaining
     (which is Gold, since Bronze just expired).

7. **Cumulative outfits re-applied on switch** — Gold → switch to Silver:
   - Silver's outfits (10) granted on next login.
   - Outfits NOT cumulative when switching down (the player explicitly
     chose Silver, so they get Silver's perks, not Gold's).

8. **Expiration** — set `expires_at` to past timestamp in DB. Logout/login:
   - Tier 0, no rewards.
   - Auto-fallback to highest remaining, or Free if empty.

9. **UI panel** — `!vip` → Ultralight window appears.
   - Shows active tier, days, perks.
   - Stack section shows all subscriptions with "Active" badge on the
     current one and "Activate" buttons on the others.
   - Buy button → text message.

10. **Activate button error** — try to activate an expired subscription
    (e.g. by manipulating the UI to send a stale ID):
    - Server rejects, sends `error` message.
    - Client displays failure text message.

### 10.2 Edge cases

| Case                                          | Expected behavior                          |
| --------------------------------------------- | ------------------------------------------ |
| Bronze 180 + Gold 30 (lifo default)           | Active=Gold (auto), Bronze queued. After Gold expires, auto-fallback to Bronze. |
| Player switches Gold→Bronze                    | Active=Bronze, Gold stays in stack. When Bronze expires, auto-fallback picks Gold. |
| Player switches to a tier that expires later  | Other tier's expires_at unchanged. The "skipped" tier is effectively lost when its time runs out. |
| Buy Gold 7 then Bronze 30 same day            | Default active=Bronze (last bought). Gold 7d is in stack but smaller than Bronze 30d. |
| Server crash mid-INSERT (no commit)           | On reload, no subscription exists (rolled back) |
| Login with all subscriptions expired          | Auto-fallback returns nil, all rewards revoked, tier 0. |
| Two scrolls used same tick                    | Both INSERTs commit, both in stack. Last one becomes active. |
| `!setvip name 0 0`                            | All subscriptions deleted, tier 0, all rewards revoked |
| Player changes sex while VIP active           | Outfit list re-applied with new sex on next login |
| Player has 10 subscriptions in stack          | All 10 returned, ordered by tier DESC, expires ASC. UI shows scrollable list. |
| Subscription created_at in far past (data migration) | Treated normally, only expires_at matters |
| Activate subscription of another player       | Server rejects (player_id check in activateSubscription) |
| Activate an already-expired subscription     | Server rejects, sends error message       |
| Race: 2 scrolls used in same tick (DB-side)   | Both rows commit. Last-write-wins for is_active. Order depends on AUTO_INCREMENT id. |

## 11. Files Touched

### Server (new)

| Path                                                          | Purpose                              |
| ------------------------------------------------------------- | ------------------------------------ |
| `server/data/migrations/048_vip_system.lua`                   | Create `player_vip_subscriptions`    |
| `server/data/migrations/049_vip_player_choice.lua`           | Add `is_active` + `activation_order` columns |
| `server/data/lib/core/vip_system.lua`                         | Helper lib (outfit/mount tables, stack management, activateSubscription, autoFallback) |
| `server/data/scripts/creaturescripts/vip_login.lua`           | Login handler, applies perks + auto-fallback |
| `server/data/scripts/movements/vip_tiles.lua`                 | AID-based area restriction           |
| `server/data/scripts/actions/vip_scroll.lua`                  | Activation scroll handler            |
| `server/data/scripts/talkactions/gm/setvip.lua`               | GM command                           |
| `server/data/scripts/talkactions/vip.lua`                     | Player `!vip` talkaction             |
| `server/data/scripts/network/vip/vip_protocol.lua`            | Extended opcode 181 handler (request_update + activate_subscription) |

### Server (modified)

| Path                                  | Change                                  |
| ------------------------------------- | --------------------------------------- |
| `server/src/player.h`                 | Add 2 transient members + 6 method decls (incl. `reloadVipCache`) |
| `server/src/player.cpp`               | Add 5 method implementations + `reloadVipCache` |
| `server/src/luaplayer.cpp`            | Register 5 Lua bindings                 |
| `server/src/iologindata.cpp`          | On login, populate `vipTier`/`vipExpires` from subscription stack |
| `server/schema.sql`                   | Add CREATE TABLE statement              |
| `server/data/events/events.xml`       | Register `VipLogin` CreatureEvent       |
| `server/data/items/items.xml`         | Define VIP scroll item IDs 24774-24776 |
| `server/data/items/items.otb`         | Match server-side item definitions      |

### Client (new)

| Path                                  | Purpose                              |
| ------------------------------------- | ------------------------------------ |
| `client/mods/game_vip/vip.otmod`      | Module manifest                      |
| `client/mods/game_vip/vip.lua`        | Opcode + Ultralight integration      |
| `client/mods/game_vip/styles/vip_panel.html` | UI markup with stack section  |
| `client/mods/game_vip/styles/vip.css`| Purple/gray theme                    |
| `client/mods/game_vip/styles/vip.js`  | Data binding + JS bridge             |
| `client/mods/game_vip/assets/*.png`   | Tier badges + icons                  |

### Client (modified)

| Path                                  | Change                                  |
| ------------------------------------- | --------------------------------------- |
| `client/init.lua` or module autoload  | Ensure `game_vip` is autoloaded         |

## 12. Out of Scope (Future Features)

- **Daily rewards** — separate spec
- **VIP-only chat channels** — defer
- **Real payment integration** — defer
- **VIP shop with cosmetics not in outfits.xml** — needs art pipeline
- **Per-vocation VIP outfits** — design question, defer
- **VIP expiring emails / Discord notifications** — needs webhook infra
- **Player-initiated tier upgrade with proration** — would require a
  "what-if cancel" calculator, defer

## 13. Open Questions

1. **Storage engine / collation** — `utf8mb4` is what the rest of the
   schema uses, but if any tier name needs emoji in the future (unlikely),
   this handles it. Confirmed correct.
2. **Where is the Ultralight HTML base directory configured?** Confirmed
   it's the same as the existing `ultralightmanager.cpp` looks for
   (`resources/`, `cache/`). The vip.html will be served from
   `client/data/ultralight/vip/` or similar. **Verify the exact
   location in `ultralightmanager.cpp` before generating assets.**
3. **Should we deduplicate identical subscriptions** (e.g. player buys
   Bronze 30d twice in a row — merge into one Bronze 60d)? **No** —
   keep them as separate rows so the user can see the purchase history
   and the stack UI is meaningful.
4. **Should the stack UI show entries from the past** (expired but
   visible in history)? **No** for v1 — only unexpired subscriptions
   are shown. Expired ones are auto-cleaned by a daily task (future
   feature, see `tasks/cleanup_expired_vip.sql` — TBD).

## 14. References

- aethrium-baiak repo (reference only):
  - `data/scripts/creaturescripts/vip_login.lua`
  - `data/scripts/actions/vip_scroll.lua`
  - `data/scripts/movements/vip_tiles.lua`
  - `src/player.cpp` lines 4512-4560
  - `src/player.h` lines 309-315
  - `src/luaplayer.cpp`
- TFS 1.8 wheel.lua (`server/data/scripts/network/wheel/wheel.lua`) — the
  existing extended-opcode pattern we copy for vip_protocol.lua
- AstraClient Ultralight (`client/src/framework/ultralight/`) — the
  view manager we integrate with
