#ifndef FS_FAMILIAR_H
#define FS_FAMILIAR_H

#include "player.h"
#include <string>

namespace Familiar {

std::string getFamiliarName(const Player* player);
bool dispellFamiliar(Player* player);
bool createFamiliar(Player* player, const std::string& familiarName, uint32_t timeLeft);
bool createFamiliarSpell(Player* player, uint32_t spellId);
void restoreFamiliarOnLogin(uint32_t playerId);
void onPlayerLogout(Player* player);

}

#endif
