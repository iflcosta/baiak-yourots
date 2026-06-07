# Phase 2 — Aethrium Systems Catalog

> Catálogo dos sistemas customizados identificados em
> [iflcosta/aethrium](https://github.com/iflcosta/aethrium) para apoio à
> decisão de import / adaptação / re-desenvolvimento no baiak-yourots.
>
> **Escopo deste documento**: apenas catalogar e propor decisões. Nenhum
> download de código ou mapa do aethrium é feito a partir deste doc — o
> import concreto começa após aprovação do plano na sessão.

---

## 1. Contexto da análise

- **Repositório origem**: `https://github.com/iflcosta/aethrium`
- **Subpastas**: `aethrium-baiak/` (servidor, TFS 1.8 com 61% Lua + 36% C++)
  e `aethrium-client/` (OTClient customizado, 72 módulos)
- **Engine servidor**: TFS 1.8 (mesma versão do baiak-yourots — portabilidade
  total das APIs Lua/C++)
- **Stack UI cliente**: Extended Opcode + JSON, dois padrões paralelos
  — `game_vip`/`game_reset`/`game_battlepass_html` (HTML+CSS, moderno) e
  `game_store` (OTUI widgets, legado)
- **Banco**: MariaDB, com migrations numeradas em `data/migrations/*.lua`
  (padrão recomendado) — **não seguir** os `.sql` avulsos legados

### Documentos fonte

| Doc | Status |
|-----|--------|
| `DOCUMENTATION_SISTEMAS.md` | fetched (5 sistemas map-anchored) |
| `RESET_SYSTEM.md` | fetched (reset com overshoot + skill seal) |
| `VIP_SYSTEM.md` | fetched (3 tiers + freePremium) |
| `OUTFITS_MOUNTS.md` | fetched (looktypes + mount IDs) |
| `crafting_system_design.md` | fetched (Aetherita masterwork) |
| `battlepass_ui_reboot_plan.md` | fetched (refactor UI) |
| `technical_handoff_battlepass.md` | fetched (handoff técnico completo) |
| `AETHERITE_MASTEMORY.md` | **não fetched** (mojibake UTF-16 ao baixar; precisa retry via API) |

---

## 2. Categorização

### 2.1. Map-anchored (requerem `world.otbm`)

Sistemas que dependem de coordenadas, áreas, NPCs posicionados ou tiles
específicos no mapa. **Não podem ser importados antes do mapa** — quando
viessem sem o mapa correto, falhariam em runtime (NPC inexistente, área
vazia, etc).

| Sistema | Ancora no mapa | Notas |
|---------|----------------|-------|
| **Task System** (NPC Bianca) | NPC em coord fixa | Storages 200001, 30100–30105; 10 monstros por task |
| **Hunt by Instance** | Salas z=9, ±6 tiles, y≈867–980 | Usa engine instance; 20 hunts |
| **Boss Room by Instance** | Salas z=9, ±6 tiles | 20 bosses, party support |
| **NPC Moveleiro** | NPC em coord fixa | Catálogo de itens de decoração |
| **NPC Armeiro** | NPC em coord fixa | Troca de addons por itens |
| **VIP Tiles** (zona VIP) | Tiles restritos no mapa | Marcar como "pendente" no doc VIP |

### 2.2. Independentes de mapa

Sistemas que operam sobre o jogador/inventário/DB sem referência espacial
fixa. Podem ser desenvolvidos (ou importados) **antes** do mapa estar pronto.

| Sistema | Categoria |
|---------|-----------|
| Reset System | Progressão |
| VIP System (sem a área de tiles) | Conta |
| Outfits & Mounts (tabelas de alocação) | Conta/Inventário |
| Crafting (Aetherita) | Inventário |
| Battle Pass | Conta |
| Achievements (104 KB) | Conta |
| Forge (item upgrading) | Inventário |
| Monk Harmony (3 virtudes) | Personagem |
| Cassino (NPC) | NPC funcional (pode ser linkado a qualquer coord) |

---

## 3. Catálogo por sistema

> Cada linha resume: o que faz, arquivos relevantes, opcodes, storages e
> decisão proposta. Detalhes de implementação ficam para o(s) PR(s) de import.

### 3.1. Task System (NPC Bianca)

- **Propósito**: tasks diárias e semanais de kill de monstros, recompensadas
  com task points
- **Arquivos servidor**: `data/lib/core/task_system.lua`,
  `data/scripts/creaturescripts/task_kill.lua`, `data/npc/scripts/{task,taskdaily}.lua`
- **Arquivos cliente**: nenhum (NPC usa diálogo nativo OTClient)
- **Storages**: `200001` (points), `30100–30102` (task normal),
  `30103–30105` (task diária)
- **DB tables**: `task_monsters` (catálogo), `task_daily` (progresso)
- **Map-anchored**: sim (NPC Bianca em coord fixa)
- **Decisão proposta**: **importar + adaptar**
  - Aproveitar: lógica de seleção de monstros, contagem, recompensa
  - Adaptar: coordenada da Bianca (escolher uma posição temática no nosso
    mapa — não usar a do baiakthunder diretamente)
  - Storages: ok com nossa convenção (200k+ = sistema, 30k = estado)

### 3.2. Hunt by Instance

- **Propósito**: 20 salas instanciadas de hunt (área limpa + 1 boss no final)
- **Arquivos servidor**: `data/lib/core/hunt_system.lua`,
  `data/scripts/actions/influenced_death.lua`
- **Arquivos cliente**: `modules/game_hunts/` (OTUI grid)
- **Map-anchored**: sim (z=9, ±6 tiles, y≈867–980)
- **Decisão proposta**: **re-desenvolver**
  - Engine instance já é nativa do TFS 1.x — reaproveitar o mecanismo
  - **Não importar as coords**: elas são do mapa baiakthunder e não fazem
    sentido sem aquele mapa exato
  - Redesenhar: número de salas, monstros, recompensas para a nossa curva
  - UI: rebuild do zero em HTML+CSS (padrão moderno), não portar o OTUI

### 3.3. Boss Room by Instance

- **Propósito**: 20 bosses instanciados em party (instância compartilhada)
- **Arquivos servidor**: `data/lib/core/boss_room.lua`,
  `data/scripts/actions/boss_room.lua`
- **Map-anchored**: sim (z=9, ±6 tiles, salas próprias)
- **Decisão proposta**: **re-desenvolver** (mesma justificativa do Hunt)
  - Reaproveitar o conceito de "instância por party" do TFS 1.x nativo
  - Redesenhar bosses, mecânicas, drops para a nossa economia

### 3.4. NPC Moveleiro (decoração)

- **Propósito**: vende/troca itens de mobília para casas
- **Arquivos servidor**: `data/npc/scripts/moveleiro.lua`
- **Map-anchored**: sim (NPC fixo)
- **Decisão proposta**: **importar + adaptar**
  - Catálogo de itens é nosso (pode aproveitar a lista)
  - Coord do NPC: definir no nosso mapa
  - Mecânica: standard NPC trade

### 3.5. NPC Armeiro (addons)

- **Propósito**: troca de addons de outfits clássicos por itens
- **Arquivos servidor**: `data/npc/scripts/armeiro.lua`
- **Map-anchored**: sim (NPC fixo)
- **Decisão proposta**: **importar + adaptar**
  - Listas de addons/itens são transferíveis
  - Coord do NPC: definir no nosso mapa

### 3.6. Reset System

- **Propósito**: reset de personagem ao lv 8, mantendo bônus cumulativos
  por vocação, com overshoot de skills antes do reset e redux no momento
- **Arquivos servidor**:
  - C++: `src/player.{h,cpp}`, `src/luaplayer.cpp`, `src/iologindata.cpp`,
    `src/luascript.cpp` (carrega `json.lua` global)
  - Lua: `data/scripts/talkactions/player/misc/{reset,sealskill}.lua`
  - DB: `data/migrations/reset_system_v2.sql` (ou migrar para
    `data/migrations/NN.lua` no padrão numerado)
- **Arquivos cliente**: `modules/game_reset/{game_reset.otmod,lua,html,css}`
- **Protocolo**: Extended Opcode **180** (JSON)
- **DB columns**: `players.reset_bonus_hp/mana/cap` (INT), `sealed_skills`
  (INT UNSIGNED bitmask)
- **Map-anchored**: não
- **Decisão proposta**: **importar + adaptar**
  - Toda a lógica de overshoot/redux/selo é 100% Lua — portabilidade total
  - C++ do `player.h/.cpp`: patch simples em TFS 1.8 stock — só precisamos
    adicionar os 4 campos e seus getters
  - UI: aproveitar o padrão HTML+CSS, mas ajustar cores ao tema do servidor
  - Pendência do aethrium: "Hunts por Reset" — reavaliar no nosso design

### 3.7. VIP System

- **Propósito**: 3 tiers (Bronze/Silver/Gold) com XP/loot bonus, área
  exclusiva, outfits/mounts, desconto em bless (Gold)
- **Arquivos servidor**:
  - C++: `src/player.{h,cpp}`, `src/luaplayer.cpp`, `src/iologindata.cpp`
  - Lua: `data/scripts/talkactions/player/misc/vip.lua`,
    `talkactions/god/vipadmin.lua`, `actions/vip_scroll.lua`,
    `creaturescripts/vip_login.lua`, `movements/vip_tiles.lua`,
    `npc/scripts/bless.lua` (NPC bless com desconto Gold)
  - DB: `data/migrations/vip_system.sql` → ou converter para
    `data/migrations/NN.lua`
- **Arquivos cliente**: `modules/game_vip/{game_vip.otmod,lua,html,css}`
- **Protocolo**: Extended Opcode **181** (JSON)
- **DB columns**: `players.vip_tier` (TINYINT), `vip_expires` (BIGINT)
- **Map-anchored**: parcialmente (tiles da área VIP — pendência do aethrium)
- **Decisão proposta**: **importar + adaptar**
  - Toda a lógica de tier/expire/benefícios é portável
  - Outfits/mounts por tier: aproveitar a tabela do `OUTFITS_MOUNTS.md`
  - `vip_tiles.lua` (movements): reescrever para nossas coords
  - NPC bless: implementar como NPC comum com `onSay` (não precisa de C++)

### 3.8. Outfits & Mounts (alocações)

- **Propósito**: tabela de origem/alocação de cada looktype de outfit e ID
  de mount (default, vip, store, quest, evento, addon)
- **Arquivos**: nenhum código (apenas referência para `VIP_SYSTEM.md` e
  quests futuras)
- **DB**: nenhum (informação vai para o `players` via `vip_tier`)
- **Map-anchored**: não
- **Decisão proposta**: **aproveitar a tabela como base**, mas com
  ressalvas:
  - Aethrium usa Tibia.spr **completo** (até looktype 1837) — o nosso
    `client/data/things/860/Tibia.spr` é 8.6 stock (limita a looktype ~280)
  - **Decisão a confirmar com usuário**: limitar alocações a outfits 8.6 ou
    investir em um Tibia.spr estendido (volumoso: ~430 MB)
  - Para Phase 2: usar apenas outfits 8.6 (default + quest/evento)

### 3.9. Crafting / Aetherita

- **Propósito**: criar itens "Masterworked" via salvage + blueprints +
  catalisadores; sinergia com Forge e Imbuement (Slot de Alma)
- **Arquivos servidor**: `data/lib/crafting_core.lua`,
  `data/scripts/actions/crafting.lua`
- **DB**: `item_recipes` + C++ `ITEM_ATTRIBUTE_CRAFTED` (atributo de item)
- **Arquivos cliente**: `modules/game_crafting/`
- **Protocolo**: Extended Opcode **151** (JSON)
- **Map-anchored**: não (UI modal, não ancorada)
- **Decisão proposta**: **re-desenvolver**
  - C++ `ITEM_ATTRIBUTE_CRAFTED` requer patch no TFS 1.8 (item attributes
    table) — barreira de portabilidade alta
  - Conceito é sólido (Aetherita em 3 estados) mas precisa de desenho próprio
  - **Phase 2**: deixar como backlog, focar no que é map-anchored primeiro

### 3.10. Battle Pass + Daily Pass

- **Propósito**: passe sazonal de 50 tiers, trilhas Free + Elite (paga),
  Daily Pass com 3 tarefas aleatórias/dia; desconto VIP na compra do Elite
- **Arquivos servidor**:
  - `data/lib/battlepass/{config,core}.lua` (split em config + lógica)
  - `data/scripts/eventcallbacks/player/battlepass_onKill.lua` (hook de kill)
  - `data/scripts/globalevents/battlepass_daily_reset.lua` (cron 00:00)
  - `data/scripts/talkactions/player/misc/battlepass.lua` (comando `!battlepass`)
  - DB: `data/migrations/36.lua` (adicionar como próximo número correto)
- **Arquivos cliente**: **duas UIs paralelas planejadas no aethrium**:
  - `modules/game_battlepass_html/` (HTML+CSS, padrão `game_vip`)
  - `modules/game_battlepass_otui/` (OTUI widgets, padrão `game_store`)
- **Protocolo**: Extended Opcode **150** (JSON)
- **Storages**: `GlobalStorageKeys.battlepassSeason = 90010`,
  `battlepassExpires = 90011`
- **DB tables**: `player_battlepass` (xp, level, elite, claimed_free bitmask,
  claimed_elite bitmask, season), `player_battlepass_daily` (3 tarefas/dia)
- **Map-anchored**: não
- **Decisão proposta**: **importar + adaptar, com 1 UI apenas**
  - Lógica servidor (config + core + eventcallbacks) é totalmente portável
  - **Decisão a confirmar com usuário**: importar 1 UI (HTML+CSS é o padrão
    moderno, mais alinhado com nosso projeto) ou 2 UIs paralelas?
  - Bitmask de `claimed_*` (50 bits em BIGINT) é uma decisão de design boa
    — manter

### 3.11. Achievements

- **Propósito**: sistema de conquistas (~1000 entries no `achievements.lua`)
- **Arquivos servidor**: `data/lib/core/achievements.lua` (104 KB)
- **DB**: provavelmente `player_achievements` (a confirmar com grep)
- **Map-anchored**: não
- **Decisão proposta**: **re-desenvolver**
  - 1000 achievements prontos é tentador, mas tied a um balanceamento de
    quests/hunts do aethrium
  - Fazer o nosso próprio: começar com 20–30 marcos (level 100, primeiro
    reset, primeira hunt, etc.) e crescer organicamente

### 3.12. Forge (item upgrading)

- **Propósito**: upgrade de itens via combinação (chance de sucesso/falha)
- **Arquivos servidor**: `data/lib/core/forge.lua`,
  `data/scripts/actions/forge.lua`
- **DB**: a confirmar
- **Map-anchored**: não
- **Decisão proposta**: **re-desenvolver**
  - Conceito é genérico (Forge existe em vários OTs), mas os itens/recetas
    do aethrium são específicos
  - Deixar para Phase 3/4

### 3.13. Monk Harmony (3 virtudes)

- **Propósito**: sistema de 3 virtudes (harmonia entre combate/magia/etc)
- **Arquivos servidor**: `data/lib/monk_harmony.lua`
- **Map-anchored**: não
- **Decisão proposta**: **estudar depois**
  - Mencionado em 1 doc; não temos contexto suficiente. Avaliar em Phase 3

### 3.14. Cassino (NPC)

- **Propósito**: NPC cassino/roulette
- **Arquivos servidor**: `npc/scripts/cassino.lua`
- **Map-anchored**: sim (NPC fixo), mas trivial de posicionar
- **Decisão proposta**: **estudar depois**
  - Cassino num servidor PvP pode gerar problemas de economia. Avaliar
    viabilidade com a comunidade antes de importar

---

## 4. Mapa de opcodes reservados

| Opcode | Sistema | Servidor | Cliente | Status |
|-------:|---------|----------|---------|--------|
| 150 | Battle Pass | `talkactions/player/misc/battlepass.lua` | `game_battlepass_{html,otui}` | planejado |
| 151 | Crafting (Aetherita) | `actions/crafting.lua` | `game_crafting/` | planejado |
| 180 | Reset | `talkactions/player/misc/reset.lua` | `game_reset/` | planejado |
| 181 | VIP | `talkactions/player/misc/vip.lua` | `game_vip/` | planejado |

> Antes de implementar qualquer um, **grep** no nosso projeto para
> confirmar que os opcodes 150/151/180/181 não estão em uso (conforme
> recomendação do aethrium handoff).

---

## 5. Tabela de DB tables customizadas

| Tabela | Sistema | Colunas chave | Migration |
|--------|---------|---------------|-----------|
| `task_monsters` | Task | catálogo de 10 monstros | `data/migrations/NN.lua` |
| `task_daily` | Task | progresso diário | idem |
| `player_rewarditems` | (já temos) | reward bag | já existe |
| `players` (+cols) | Reset/VIP | `reset_bonus_hp/mana/cap`, `sealed_skills`, `vip_tier`, `vip_expires` | `data/migrations/NN.lua` |
| `player_battlepass` | Battle Pass | xp, level, elite, claimed_free/elite bitmask, season | `data/migrations/NN.lua` |
| `player_battlepass_daily` | Battle Pass | 3 tarefas/dia com type/target/current/completed | idem |
| `item_recipes` | Crafting | receitas | a criar se importarmos |
| (achievements) | Achievements | a confirmar com grep | n/a (re-desenvolver) |

---

## 6. Plano de import proposto (ordem)

### Bloco A — Pré-requisito (mapa)

1. Decidir o mapa final: **baiakthunder** (origem do aethrium) ou custom?
   - O aethrium foi construído sobre o baiakthunder, então as 20 hunts/
     bosses/task rooms referenciam coords daquele mapa específico
   - Se quisermos aqueles sistemas map-anchored funcionando "out of the
     box", o mapa tem que ser o baiakthunder
2. Copiar `world.otbm`, `world-spawn.xml`, `world-house.xml` do aethrium
3. Atualizar `server/data/world/towns.xml` com as towns do mapa
4. Regenerar minimap (192 PNGs) via `scripts/minimap-export.ps1`
5. Smoke test: loga, anda pelo mapa, verifica que spawns carregam

### Bloco B — Sistemas map-anchored (dependem do mapa)

6. NPC Bianca (Task) — coord definida no nosso mapa
7. NPC Moveleiro (furniture) — coord definida
8. NPC Armeiro (addons) — coord definida
9. Hunt by Instance — **redesenhado** (não importado) com salas no nosso mapa
10. Boss Room by Instance — idem
11. VIP Tiles (zona VIP) — coord definida

### Bloco C — Sistemas independentes (paralelos ao Bloco B)

12. Reset System (C++ patch + Lua + UI)
13. VIP System (sem tiles — só a lógica + outfits/mounts + NPC bless)
14. Outfits & Mounts (tabela de alocação)
15. Battle Pass (1 UI: HTML+CSS)

### Bloco D — Backlog (Phase 3+)

16. Crafting / Aetherita (re-desenvolver com C++ patch próprio)
17. Achievements (re-desenvolver do zero, menor escopo)
18. Forge (re-desenvolver)
19. Monk Harmony (avaliar)
20. Cassino (avaliar viabilidade)

---

## 7. Decisões pendentes (a confirmar com o usuário)

> Itens que bloqueiam o início do Bloco A. Cada um deve virar uma resposta
> antes de prosseguirmos.

1. **Mapa**: usar o baiakthunder (vindo do aethrium) ou construir mapa
   custom? — **impacto**: define o que dos sistemas 3.2 e 3.3 é "re-
   desenvolver vs adaptar"
2. **Outfits**: limitar a looktypes 8.6 (~280) ou investir em Tibia.spr
   estendido (até 1837)? — **impacto**: define o universo de
   alocações VIP/Store/Quest
3. **Battle Pass UI**: importar só HTML+CSS ou manter as 2 UIs paralelas
   planejadas no aethrium? — **impacto**: 1 PR vs 2 PRs
4. **VIP freePremium**: manter `freePremium = true` (todos têm premium
   grátis) ou mudar para premium pago? — **impacto**: muda o balanceamento
   de quase tudo
5. **AETHERITE_MASTERY.md**: como buscar o conteúdo (API GitHub, versão
   alternativa, ou abandonar)? — **impacto**: pode complementar nosso
   conhecimento do crafting

---

## 8. Próximos passos concretos (quando aprovado)

1. Decidir os 5 itens da §7 em conversa
2. Criar `feature/phase-2-map-import` off `develop`
3. Baixar `aethrium-baiak/data/world/*` (otbm + spawn + house)
4. Smoke test do mapa em ambiente local
5. PR `feature/phase-2-map-import` → `develop` com:
   - novo `world.otbm` + `world-spawn.xml` + `world-house.xml`
   - `towns.xml` ajustado
   - PNGs do minimap regenerados
   - 1 parágrafo de "como testar" no PR body

---

## 9. Referências externas

- Repositório: https://github.com/iflcosta/aethrium
- TFS 1.x Lua API: https://github.com/otland/forgottenserver/wiki
- Spec do projeto: `C:\baiak-yourots\spec.md`
- Estado atual: `C:\baiak-yourots\AGENTS.md` → Progress Log
