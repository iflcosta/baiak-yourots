-- NpcType Wrapper
if not _G.OriginalNpcTypeRegister then
	_G.OriginalNpcTypeRegister = NpcType.register
end

function NpcType:register(npcConfig)
	_G.OriginalNpcTypeRegister(self, npcConfig)
	
	local handler = _G.LastCrystalNpcHandler
	if handler then
		_G.LastCrystalNpcHandler = nil
		return
	end
end
