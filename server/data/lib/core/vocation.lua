VOCATION = {
	ID = {
		NONE = 0,
		SORCERER = 1,
		DRUID = 2,
		PALADIN = 3,
		KNIGHT = 4,
		MONK = 9,
	}
}

function Vocation.getBase(self)
	local base = self
	while base:getDemotion() do base = base:getDemotion() end
	return base
end
