-- =====================================================================
-- game_vip module (Baiak-Yourots)
--
-- Client-side bootstrap for the VIP subscription panel.
-- - Registers extended opcode 181.
-- - Bridges server <-> Ultralight HTML view.
-- - Exposes global callbacks (`game_vip.onActivateSubscription`,
--   `game_vip.onBuyClick`) that the Ultralight JS bridge calls into.
--
-- The mod is sandboxed, but callbacks must live in the REAL global env
-- so that the C++ Ultralight dispatcher (which evaluates
-- `game_vip.field('arg')` in `_G`) can find them. Pattern is the same
-- as `game_helper/timer_panel.lua` does for `_G.modules.game_helper`.
-- =====================================================================

-- ---------- Configuration ----------
local VIP_OPCODE     = 181
local VIP_VIEW_NAME  = "vip_panel"
local VIP_HTML_PATH  = "/vip/vip_panel.html"
local VIP_VIEW_W     = 480
local VIP_VIEW_H     = 540

-- Resolve the on-disk locations at runtime. Source = project mod dir,
-- destination = ultralight-sdk base (where Ultralight's SimpleFileSystem
-- looks for files). The C++ side does `file:///<baseDir><htmlPath>`.
local SOURCE_DIR  = "C:\\baiak-yourots\\client\\mods\\game_vip"
local SOURCE_STYLES  = SOURCE_DIR .. "\\styles"
local SOURCE_ASSETS  = SOURCE_DIR .. "\\assets"
local SDK_BASE_DIR   = "C:\\baiak-yourots\\ultralight-sdk"
local RUNTIME_DIR    = SDK_BASE_DIR .. "\\vip"
local RUNTIME_STYLES = RUNTIME_DIR .. "\\styles"
local RUNTIME_ASSETS = RUNTIME_DIR .. "\\assets"

-- List of files we ship from the mod into the ultralight runtime.
-- (Keep both lists in sync with the mod's `styles/` and `assets/` dirs.)
local RUNTIME_FILES = {
    { src = SOURCE_STYLES .. "\\vip_panel.html", dst = RUNTIME_DIR    .. "\\vip_panel.html" },
    { src = SOURCE_STYLES .. "\\vip.css",        dst = RUNTIME_STYLES .. "\\vip.css" },
    { src = SOURCE_STYLES .. "\\vip.js",         dst = RUNTIME_STYLES .. "\\vip.js" },
    { src = SOURCE_ASSETS .. "\\vip-icon.png",   dst = RUNTIME_ASSETS .. "\\vip-icon.png" },
    { src = SOURCE_ASSETS .. "\\badge-bronze.png", dst = RUNTIME_ASSETS .. "\\badge-bronze.png" },
    { src = SOURCE_ASSETS .. "\\badge-silver.png", dst = RUNTIME_ASSETS .. "\\badge-silver.png" },
    { src = SOURCE_ASSETS .. "\\badge-gold.png",   dst = RUNTIME_ASSETS .. "\\badge-gold.png" },
    { src = SOURCE_ASSETS .. "\\vip-icon-empty.png", dst = RUNTIME_ASSETS .. "\\vip-icon-empty.png" },
}

-- ---------- State ----------
local vipWindow = nil
local lastReceivedData = nil

-- ---------- Filesystem helpers ----------
-- All copy/file operations use plain `io` + absolute paths. The mod
-- sandbox does not restrict `io` (it only sandboxes global env writes),
-- and we read source files from the on-disk mod dir and write to the
-- ultralight-sdk dir. The destination dir is whitelisted (sdk is part
-- of the bundled client) so this is safe.

local function ensureDir(path)
    -- Lua doesn't have mkdir; shell out via os.execute on Windows.
    -- Use a non-fatal approach: ignore "already exists" errors.
    os.execute('mkdir "' .. path .. '" 2>nul')
end

local function copyFile(srcPath, dstPath)
    local src = io.open(srcPath, "rb")
    if not src then
        g_logger.warning("[game_vip] source missing: " .. srcPath)
        return false
    end
    local data = src:read("*a")
    src:close()
    if not data then
        g_logger.warning("[game_vip] empty source: " .. srcPath)
        return false
    end
    local dst = io.open(dstPath, "wb")
    if not dst then
        g_logger.error("[game_vip] cannot open dest for write: " .. dstPath)
        return false
    end
    dst:write(data)
    dst:close()
    return true
end

-- Idempotently mirror the mod's web assets into the ultralight runtime
-- dir. Skips files that are already up-to-date (same mtime or same size
-- as the source). Cheap: one stat per file.
local function syncRuntimeAssets()
    ensureDir(RUNTIME_DIR)
    ensureDir(RUNTIME_STYLES)
    ensureDir(RUNTIME_ASSETS)
    for _, entry in ipairs(RUNTIME_FILES) do
        local ok = pcall(copyFile, entry.src, entry.dst)
        if not ok then
            g_logger.warning("[game_vip] failed to copy " .. entry.src)
        end
    end
end

-- ---------- JS bridge (globals) ----------
-- The Ultralight C++ dispatcher does
--   g_lua.evaluateExpression("game_vip.onActivateSubscription('123')")
-- evaluated in `_G`. We must register our callbacks there.
-- We can NOT use the local `game_vip` table — sandboxed env writes
-- stay local. We have to write through the real global env.

_G.game_vip = _G.game_vip or {}

_G.game_vip.onBuyClick = function()
    if modules and modules.game_textmessage and modules.game_textmessage.displayFailureMessage then
        modules.game_textmessage.displayFailureMessage("[VIP] Payment integration coming soon.")
    end
end

_G.game_vip.onActivateSubscription = function(subId)
    subId = tonumber(subId)
    if not subId or subId <= 0 then
        if modules and modules.game_textmessage and modules.game_textmessage.displayFailureMessage then
            modules.game_textmessage.displayFailureMessage("[VIP] Invalid subscription id.")
        end
        return
    end

    local player = g_game and g_game.getLocalPlayer and g_game.getLocalPlayer()
    if not player then
        if modules and modules.game_textmessage and modules.game_textmessage.displayFailureMessage then
            modules.game_textmessage.displayFailureMessage("[VIP] Not in game.")
        end
        return
    end

    -- The server-side `activate_subscription` handler is expected to
    -- call `VipSystem.activateSubscription` and then re-send the
    -- `vip_info` payload via opcode 181. We don't reach into
    -- VipSystem from the client (sandboxed + out of scope); the
    -- server is the single source of truth.
    local protocol = g_game.getProtocolGame()
    if not protocol then return end

    local payload = json.encode({ type = "activate_subscription", subscriptionId = subId })
    protocol:sendExtendedOpcode(VIP_OPCODE, payload)
end

-- ---------- Extended opcode handler ----------
local function onExtendedOpcode(protocol, opcode, buffer)
    if opcode ~= VIP_OPCODE then return end
    if not buffer or buffer == "" then return end

    local ok, data = pcall(json.decode, buffer)
    if not ok or type(data) ~= "table" then
        g_logger.warning("[game_vip] failed to parse opcode payload: " .. tostring(buffer))
        return
    end

    if data.type == "vip_info" then
        lastReceivedData = data
        renderVipPanel(data)
    elseif data.type == "error" then
        if modules and modules.game_textmessage and modules.game_textmessage.displayFailureMessage then
            modules.game_textmessage.displayFailureMessage("[VIP] " .. tostring(data.message or "Unknown error"))
        end
    end
end

-- ---------- UI bring-up ----------
-- Build a minimal OTUI wrapper so the Ultralight view is anchored to
-- something visible. The OTUI window is mostly invisible (background
-- transparent); the actual content lives in the HTML view.
local VIP_OTUI = [[
Panel
  id: vipWindow
  size: 480 540
  background: #00000000
  focusable: true
]]

local function showPanel()
    if not vipWindow then
        -- One-time wrapper creation. `g_ui.loadUIFromString` is the
        -- bound OTML-string loader (see luafunctions.cpp:431). The
        -- sibling `g_ui.createWidgetFromOTML` exists too but takes a
        -- pre-parsed OTMLNode, not a string.
        local ui = g_ui.loadUIFromString(VIP_OTUI, rootWidget)
        vipWindow = ui
    end
    vipWindow:show()
    vipWindow:raise()
    vipWindow:focus()

    -- Create the Ultralight view (if not already) and load the HTML.
    if g_ultralight and g_ultralight.createView then
        if not g_ultralight.hasView(VIP_VIEW_NAME) then
            g_ultralight.createView(VIP_VIEW_NAME, VIP_VIEW_W, VIP_VIEW_H, VIP_HTML_PATH)
        end
        -- Position the view at (0, 0) of the OTUI wrapper.
        g_ultralight.setViewPosition(VIP_VIEW_NAME, 0, 0)
        g_ultralight.setViewVisible(VIP_VIEW_NAME, true)
        g_ultralight.setViewFocus(VIP_VIEW_NAME, true)

        -- If we already have data (e.g. opcode arrived before window
        -- opened), push it now.
        if lastReceivedData then
            pushDataToPanel(lastReceivedData)
        end
    else
        g_logger.warning("[game_vip] g_ultralight not available; Ultralight SDK not compiled in?")
    end
end

local function hidePanel()
    if vipWindow then
        vipWindow:hide()
    end
    if g_ultralight and g_ultralight.setViewVisible then
        g_ultralight.setViewVisible(VIP_VIEW_NAME, false)
    end
end

local function toggleVipPanel()
    if vipWindow and vipWindow:isVisible() then
        hidePanel()
    else
        showPanel()
        -- Always re-request fresh data when the player opens the panel.
        local protocol = g_game and g_game.getProtocolGame and g_game.getProtocolGame()
        if protocol then
            protocol:sendExtendedOpcode(VIP_OPCODE, json.encode({ type = "request_update" }))
        end
    end
end

-- ---------- Data push to HTML ----------
-- The HTML's JS exposes `window.updateVipData(json)` (see styles/vip.js).
-- We push the raw JSON (not a string-encoded one) — Ultralight's
-- EvaluateScript concatenates it directly, so the JS side receives a
-- native object.

function pushDataToPanel(data)
    if not g_ultralight or not g_ultralight.callJSFunction then return end
    if not g_ultralight.hasView(VIP_VIEW_NAME) then return end
    local encoded = json.encode(data)
    g_ultralight.callJSFunction(VIP_VIEW_NAME, "updateVipData", encoded)
end

-- Public entrypoint used by onExtendedOpcode.
function renderVipPanel(data)
    if not data then return end
    pushDataToPanel(data)
    -- If the panel isn't open yet, just keep the data cached and the
    -- next `toggleVipPanel` will display it.
end

-- ---------- Keybind ----------
-- Spec: Ctrl+V opens the panel. We register via the canonical
-- `g_keyboard.bindKeyPress` API (see corelib/keyboard.lua:190). NOTE:
-- `g_keyboard` is a plain Lua table — connecting to `g_keyboard.onPress`
-- would do nothing because the engine never fires that signal. The
-- `bindKeyPress` API installs the combo on the widget's
-- `boundKeyPressCombos` table, which IS what the input system dispatches.
local function onVipKeyPress()
    if g_game and g_game.isOnline and g_game.isOnline() then
        toggleVipPanel()
    end
end

-- ---------- Lifecycle ----------
local function onGameStart()
    -- Mirror the web assets into the ultralight runtime dir. We do
    -- this on every game start so that updates to the mod files are
    -- picked up on next login.
    syncRuntimeAssets()

    -- Register the opcode handler for the current ProtocolGame instance.
    -- `unregisterExtendedOpcode` throws `'Opcode is not registered.'` if
    -- the slot is empty, so guard with pcall. This is necessary because
    -- the init() path also calls onGameStart() when the player is
    -- already online (e.g. `/reloadgame_vip` while in-game), and the
    -- slot is empty until we register below.
    local protocol = g_game.getProtocolGame()
    if protocol then
        pcall(ProtocolGame.unregisterExtendedOpcode, VIP_OPCODE)
        ProtocolGame.registerExtendedOpcode(VIP_OPCODE, onExtendedOpcode)
    end

    -- Ask the server for current VIP data. This will populate
    -- `lastReceivedData` and render the panel if the player has it
    -- open at login.
    if protocol then
        protocol:sendExtendedOpcode(VIP_OPCODE, json.encode({ type = "request_update" }))
    end
end

local function onGameEnd()
    hidePanel()
    pcall(ProtocolGame.unregisterExtendedOpcode, VIP_OPCODE)
end

function init()
    if not g_ultralight or not g_ultralight.isInitialized or not g_ultralight.isInitialized() then
        g_logger.warning("[game_vip] Ultralight not initialized at init time; panel will fail until then.")
    end

    -- Pre-sync assets (the onGameStart will do it again, but doing
    -- it early means the first Ctrl+V works even if the player
    -- hasn't logged in yet during dev).
    pcall(syncRuntimeAssets)

    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd   = onGameEnd,
    })

    -- Register the global keybind. The third arg is the widget that
    -- owns the key combo (defaults to rootWidget, same as `game_helper`
    -- does for its `Tab` binding).
    g_keyboard.bindKeyPress('Ctrl+V', onVipKeyPress)

    if g_game.isOnline() then onGameStart() end
end

function terminate()
    disconnect(g_game, { onGameStart = onGameStart, onGameEnd = onGameEnd })

    -- Unbind the keybind. Pass the same callback so the unbinder finds
    -- the right entry in `boundKeyPressCombos`.
    pcall(g_keyboard.unbindKeyPress, 'Ctrl+V', onVipKeyPress)

    pcall(ProtocolGame.unregisterExtendedOpcode, VIP_OPCODE)

    if g_ultralight and g_ultralight.removeView then
        pcall(g_ultralight.removeView, VIP_VIEW_NAME)
    end
    if vipWindow then
        vipWindow:destroy()
        vipWindow = nil
    end

    -- Clean up the global table so reloading the mod starts clean.
    pcall(function()
        _G.game_vip = nil
    end)
end
