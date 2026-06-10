/* =========================================================================
 * VIP Panel — JS bridge
 *
 * Exposes `updateVipData(data)` as a global function that the Lua
 * side calls via `g_ultralight.callJSFunction("vip_panel",
 * "updateVipData", json.encode(data))`. The payload is the JSON object
 * from the server's `vip_info` opcode (see docs/specs/vip-system.md
 * section 7.7).
 *
 * Outbound bridge: `window.callLuaFunction(path, ...)` is auto-injected
 * on DOMReady by the C++ side (see UltraViewBridge::OnDOMReady in
 * ultralightmanager.cpp). We use it to forward user actions back to
 * Lua: `window.callLuaFunction('game_vip.onActivateSubscription', subId)`.
 * ========================================================================= */

(function () {
    'use strict';

    const BADGE_MAP = {
        'free':   'assets/vip-icon-empty.png',
        'bronze': 'assets/badge-bronze.png',
        'silver': 'assets/badge-silver.png',
        'gold':   'assets/badge-gold.png',
    };

    function badgeFor(tierName) {
        if (!tierName) return BADGE_MAP.free;
        return BADGE_MAP[tierName.toLowerCase()] || BADGE_MAP.free;
    }

    function setText(id, text) {
        const el = document.getElementById(id);
        if (el) el.textContent = text;
    }

    function showError(msg) {
        const el = document.getElementById('error-banner');
        if (!el) return;
        el.textContent = msg;
        el.style.display = msg ? 'block' : 'none';
    }

    function renderStack(stack) {
        const list = document.getElementById('stack-list');
        if (!list) return;
        list.innerHTML = '';

        if (!stack || stack.length === 0) {
            const empty = document.createElement('div');
            empty.className = 'stack-empty';
            empty.textContent = 'No subscriptions';
            list.appendChild(empty);
            return;
        }

        stack.forEach((sub) => {
            const tierName = (sub.tierName || '').toLowerCase();
            const isActive = !!sub.isActive;
            const days = sub.daysRemaining != null ? sub.daysRemaining : 0;
            const sourceLabel = sub.source === 'gm' ? ' <span class="source-tag">GM</span>' : '';

            const row = document.createElement('div');
            row.className = 'stack-item' + (isActive ? ' stack-active' : '');

            // tier tag
            const tierTag = document.createElement('span');
            tierTag.className = 'stack-tier tier-' + tierName;
            tierTag.textContent = (sub.tierName || 'Free').toUpperCase();

            // days
            const daysEl = document.createElement('span');
            daysEl.className = 'stack-days';
            daysEl.innerHTML = days + ' day' + (days === 1 ? '' : 's') + sourceLabel;

            // action: Active badge or Activate button
            const action = document.createElement('span');
            if (isActive) {
                const badge = document.createElement('span');
                badge.className = 'stack-badge';
                badge.textContent = 'Active';
                action.appendChild(badge);
            } else {
                const btn = document.createElement('button');
                btn.className = 'stack-activate';
                btn.type = 'button';
                btn.textContent = 'Activate';
                btn.dataset.subId = String(sub.id);
                btn.addEventListener('click', function (e) {
                    e.stopPropagation();
                    if (typeof window.callLuaFunction !== 'function') {
                        showError('JS bridge unavailable.');
                        return;
                    }
                    window.callLuaFunction('game_vip.onActivateSubscription', String(sub.id));
                });
                action.appendChild(btn);
            }

            row.appendChild(tierTag);
            row.appendChild(daysEl);
            row.appendChild(action);
            list.appendChild(row);
        });
    }

    function bindBuyButton() {
        const btn = document.getElementById('buy-btn');
        if (!btn) return;
        // Re-bind defensively (re-render path may run multiple times).
        btn.onclick = function () {
            if (typeof window.callLuaFunction !== 'function') {
                showError('JS bridge unavailable.');
                return;
            }
            window.callLuaFunction('game_vip.onBuyClick');
        };
    }

    /**
     * Public entrypoint. Called by the C++ side with the raw object
     * (EvaluateScript concatenates the JSON, so we receive a JS object).
     */
    window.updateVipData = function (data) {
        if (!data || typeof data !== 'object') {
            showError('Malformed VIP data from server.');
            return;
        }
        showError(null);

        const tierName = (data.activeTierName || 'Free');
        const tierKey  = tierName.toLowerCase();

        // Badge
        const badge = document.getElementById('tier-badge');
        if (badge) badge.src = badgeFor(tierKey);

        // Header text
        const nameEl = document.getElementById('tier-name');
        if (nameEl) {
            nameEl.textContent = tierName;
            nameEl.className = 'vip-tier-name tier-' + tierKey;
        }
        setText('vip-days', data.isVip
            ? (data.activeDaysRemaining + ' days remaining')
            : 'No active VIP');

        // Perks
        setText('xp-bonus',      '+' + (data.xpBonus      || 0) + '%');
        setText('loot-bonus',    '+' + (data.lootBonus    || 0) + '%');
        setText('outfit-count',  String((data.outfitsUnlocked || []).length));
        setText('mount-count',   String((data.mountsUnlocked  || []).length));

        // Stack
        renderStack(data.stack || []);

        // Action button
        bindBuyButton();
    };
})();
