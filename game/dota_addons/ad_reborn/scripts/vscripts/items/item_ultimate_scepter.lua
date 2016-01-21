--[[ Called when Aghanim's Scepter is purchased or picked up. Applies the stock Aghanim's Scepter modifier, which
	is used internally to upgrade spells and such. ]]
function modifier_item_ultimate_scepter_on_created( keys )
	local itemName = keys.ability:GetAbilityName()
	local scepter_modifier = "modifier_" .. itemName
	local layout_modifier = scepter_modifier .. "_ability_layout_change"
	local hero = keys.caster

	if not hero:HasModifier( scepter_modifier ) then
		hero:AddNewModifier( hero, nil, scepter_modifier, { duration = -1 } )

		Timers:CreateTimer( 0, function()

			if hero:HasModifier( layout_modifier ) then
				hero:RemoveModifierByName( layout_modifier )
			end

			Timers:CreateTimer( 0, function()
				local abCount = hero:GetAbilityCount() - 1

				local ult = nil

			  	for i = 0, abCount do
			    	local ab = hero:GetAbilityByIndex( i )

			    	if ab then
			    		if ab:GetAbilityType() == 1 then
			    			ult = ab
			    		end

			      		local abName = ab:GetAbilityName()

			      		if abName == INCREASE_ABILITY_LAYOUT then
			      			local ultName = ult:GetAbilityName()

			      			local subUlt = GameMode.SubAbilitiesKV[ ultName ]
			      			
							if subUlt then
							    local subSkills = vlua.split( subUlt, "||" ) -- source 2 engine

							    local abHidden = hero:FindAbilityByName( subSkills[2] )
							    abHidden:SetHidden( false )

							    if abHidden:GetMaxLevel() > 1 then
							    	abHidden:SetLevel( ult:GetLevel() )
							    end

			      				keys.ability:ApplyDataDrivenModifier( hero, hero, layout_modifier, { duration = -1 })

			      				break
			      			end
			      		end
			    	end
			  	end

			end)
	 	end)
	end
end

--[[ Called when Aghanim's Scepter is sold or dropped. Removes the stock Aghanim's Scepter modifier if no other 
	Aghanim's Scepters exist in the player's inventory. ]]
function modifier_item_ultimate_scepter_on_destroy(keys)
	local num_scepters_in_inventory = 0
	
	local scepter_name = "item_ultimate_scepter"
	local scepter_modifier = "modifier_item_ultimate_scepter"
	-- local layout_modifier = scepter_modifier .. "_ability_layout_change"

	--Search for Aghanim's Scepters in the player's inventory.
	for i=0, 5, 1 do
		local current_item = keys.caster:GetItemInSlot(i)
		if current_item ~= nil then
			local item_name = current_item:GetName()
			
			if item_name == scepter_name then
				num_scepters_in_inventory = num_scepters_in_inventory + 1
			end
		end
	end

	--Remove the stock Aghanim's Scepter modifier if the player no longer has a scepter in their inventory.
	if num_scepters_in_inventory == 0 and keys.caster:HasModifier( scepter_modifier ) then
		keys.caster:RemoveModifierByName( scepter_modifier )
		-- if keys.caster:HasModifier( layout_modifier ) then
		-- 	keys.caster:RemoveModifierByName( layout_modifier )
		-- end
	end
end