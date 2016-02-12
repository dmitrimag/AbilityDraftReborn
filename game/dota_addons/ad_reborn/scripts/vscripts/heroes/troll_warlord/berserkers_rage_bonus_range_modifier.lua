if berserkers_rage_bonus_range_modifier == nil then
	berserkers_rage_bonus_range_modifier = class({})
end

function berserkers_rage_bonus_range_modifier:OnCreated( kv )
	if IsServer() then
		self.range = kv.range
	end
end

function berserkers_rage_bonus_range_modifier:DeclareFunctions()
    local funcs = {
        MODIFIER_PROPERTY_ATTACK_RANGE_BONUS
    }

    return funcs
end

function berserkers_rage_bonus_range_modifier:GetModifierAttackRangeBonus( params )
	if IsServer() then
		return (( self.range - 128 ) * -1 )
	end
	return 0
end

function berserkers_rage_bonus_range_modifier:IsHidden()
	return true
end

function berserkers_rage_bonus_range_modifier:IsPurgable()
    return false
end