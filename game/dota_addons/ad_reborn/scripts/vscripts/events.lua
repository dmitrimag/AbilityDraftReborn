-- This file contains all barebones-registered events and has already set up the passed-in parameters for your use.
-- Do not remove the GameMode:_Function calls in these events as it will mess with the internal barebones systems.


--/////////////////////////////////////////////////////////////////////////////////////////////
--ENABLED
--/////////////////////////////////////////////////////////////////////////////////////////////


-- The overall game state has changed
function GameMode:OnGameRulesStateChange(keys)
  -- DebugPrint("[BAREBONES] GameRules State Changed")
  -- DebugPrintTable(keys)
  -- This internal handling is used to set up main barebones functions
  GameMode:_OnGameRulesStateChange(keys)

  local newState = GameRules:State_Get()
  if newState == DOTA_GAMERULES_STATE_HERO_SELECTION then
    Timers:CreateTimer({
      useGameTime = false,
      endTime = 0,
      callback = function()
        GameMode:CreateAdcmData()
      end
    })
    PauseGame(true)
  elseif newState == DOTA_GAMERULES_STATE_PRE_GAME then
    GameMode:OnPreGame()
  end
end

-- A player picked a hero
function GameMode:OnPlayerPickHero(keys)
  -- DebugPrint('[BAREBONES] OnPlayerPickHero')
  -- DebugPrintTable(keys)

  local heroClass = keys.hero
  local heroEntity = EntIndexToHScript(keys.heroindex)
  local player = EntIndexToHScript(keys.player)

  GameMode:OnHeroInGame(heroEntity)
end

-- An entity somewhere has been hurt.  This event fires very often with many units so don't do too many expensive
-- operations here
function GameMode:OnEntityHurt(keys)
  --DebugPrint("[BAREBONES] Entity Hurt")
  --DebugPrintTable(keys)
  -- local damagebits = keys.damagebits -- This might always be 0 and therefore useless
  if keys.entindex_attacker ~= nil and keys.entindex_killed ~= nil then
    -- local entCause = EntIndexToHScript(keys.entindex_attacker)
    local entVictim = EntIndexToHScript(keys.entindex_killed)
    -- The ability/item used to damage, or nil if not damaged by an item/ability
    -- local damagingAbility = nil
    -- if keys.entindex_inflictor ~= nil then
    --   damagingAbility = EntIndexToHScript( keys.entindex_inflictor )
    -- end

    -- Abaddon's ult fix
    if entVictim and entVictim:IsRealHero() then
      local limitHP = 400
      if entVictim:GetHealth() <= limitHP then
        local ab = nil
        local abName = "abaddon_borrowed_time"
        if entVictim:HasAbility( abName ) then
          ab = entVictim:FindAbilityByName( abName )
        end

        if ab then
          if ab:IsCooldownReady() then

            local level = ab:GetLevel()

            if level > 0 then

              local modName = "modifier_" .. abName
              entVictim:SetHealth( 2 * limitHP - entVictim:GetHealth() )
              entVictim:AddNewModifier(entVictim, ab, modName, {
                  duration = ab:GetSpecialValueFor("duration"),
                  duration_scepter = ab:GetSpecialValueFor("duration_scepter"),
                  redirect = ab:GetSpecialValueFor("redirect"),
                  redirect_range_tooltip_scepter = ab:GetSpecialValueFor("redirect_range_tooltip_scepter")
              })

              if level == 1 then
                  ab:StartCooldown(60)
              elseif level == 2 then
                  ab:StartCooldown(50)
              else
                  ab:StartCooldown(40)
              end
            end
            
          end
        end
      end
    end
  end
end

-- This function is called whenever illusions are created and tells you which was/is the original entity
function GameMode:OnIllusionsCreated(keys)
  -- DebugPrint('[BAREBONES] OnIllusionsCreated')
  -- DebugPrintTable(keys)
  local originalEntity = EntIndexToHScript(keys.original_entindex)
  local player = originalEntity:GetPlayerOwner()
  local pID = player:GetPlayerID()

  local unitName = originalEntity:GetUnitName()
  -- local position = originalEntity:GetAbsOrigin()
  -- local maxRadius = 5000
  -- local illusions = Entities:FindAllByNameWithin( unitName, position, maxRadius )
  local illusions = Entities:FindAllByName( unitName )

  for _,hero in pairs(illusions) do
    if hero:IsIllusion() then
      GameMode:CreateAbilitiesForHero( hero, pID, originalEntity )
    end
  end
end

-- A player leveled up an ability
function GameMode:OnPlayerLearnedAbility( keys )
  -- DebugPrint('[BAREBONES] OnPlayerLearnedAbility')
  -- DebugPrintTable(keys)

  local player = EntIndexToHScript(keys.player)
  local abilityname = keys.abilityname

  local subUlt = GameMode.SubAbilitiesKV[ abilityname ]
  if subUlt then
    local subSkills = vlua.split( subUlt, "||" )
    if subSkills[1] == INCREASE_ABILITY_LAYOUT then
      local hero = player:GetAssignedHero()
      local ab = hero:FindAbilityByName( subSkills[2] )
      if ab:GetMaxLevel() > 1 then
        local ult = hero:FindAbilityByName( abilityname )
        local level = ult:GetLevel()
        
        ab:SetLevel( level )
      end
    end
  end
end

-- Cleanup a player when they leave
function GameMode:OnDisconnect(keys)
    DebugPrint('[BAREBONES] Player Disconnected ' .. tostring(keys.userid))
    -- DebugPrintTable(keys)
    -- local name = keys.name
    -- local networkid = keys.networkid
    -- local reason = keys.reason
    -- local userid = keys.userid
    if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
        GameMode:RecalculatePlayersCount()
    end
end

-- This function is called once when the player fully connects and becomes "Ready" during Loading
function GameMode:OnConnectFull(keys)
  DebugPrint('[BAREBONES] OnConnectFull')
  -- DebugPrintTable(keys)
  GameMode:_OnConnectFull(keys)
  -- local entIndex = keys.index+1
  -- The Player entity of the joining user
  -- local ply = EntIndexToHScript(entIndex)
  -- The Player ID of the joining player
  -- local playerID = ply:GetPlayerID()
  if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
        GameMode:RecalculatePlayersCount()
    end
end

-- This function is called 1 to 2 times as the player connects initially but before they 
-- have completely connected
function GameMode:PlayerConnect(keys)
  DebugPrint('[BAREBONES] PlayerConnect')
  -- DebugPrintTable(keys)
  if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
        GameMode:RecalculatePlayersCount()
    end
end

function GameMode:RecalculatePlayersCount()
    self.PlayersCount.radiant = 0
    self.PlayersCount.dire = 0

    for teamID = DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS do
        for slot = 1, 5 do
            local pID = PlayerResource:GetNthPlayerIDOnTeam( teamID, slot )

            if pID >= 0 then

                local connectionState = PlayerResource:GetConnectionState(pID)

                if connectionState == DOTA_CONNECTION_STATE_CONNECTED then

                    if teamID == DOTA_TEAM_GOODGUYS then
                        self.PlayersCount.radiant = self.PlayersCount.radiant + 1
                    elseif teamID == DOTA_TEAM_BADGUYS then
                        self.PlayersCount.dire = self.PlayersCount.dire + 1
                    end

                elseif connectionState == DOTA_CONNECTION_STATE_DISCONNECTED then

                    local timer_name = "timer_abandoned_player_"..pID
                    if Timers.timers[ timer_name ] == nil then
                        Timers:CreateTimer( timer_name, {
                            useGameTime = true,
                            endTime = 0,
                            callback = function( pID, args )
                                local connection_state = PlayerResource:GetConnectionState( pID )
                                local _timer_name_ = "timer_abandoned_player_"..pID

                                if connection_state == DOTA_CONNECTION_STATE_CONNECTED then
                                    Timers:RemoveTimer( _timer_name_ )
                                else

                                    if args.endTime > 300 then
                                        Timers:RemoveTimer( _timer_name_ )
                                        GameMode:ShareLeaverGold( pID )
                                        return
                                    end

                                    return 1
                                end
                            end
                        }, pID)
                    end

                end

            end

        end
    end

    for team, count in pairs( self.PlayersCount ) do
        if count <= 0 then
            self.PlayersCount[ team ] = 1
        end
    end
end

function GameMode:ShareLeaverGold( pID )
    local gold_shared = PlayerResource:GetGold( pID )

    local players_count = 0
    local teamID = PlayerResource:GetTeam( pID )

    if teamID == DOTA_TEAM_GOODGUYS then
        players_count = self.PlayersCount.radiant
    elseif teamID == DOTA_TEAM_BADGUYS then
        players_count = self.PlayersCount.dire
    end

    local gold = math.ceil( gold_shared / players_count )

    for slot = 1, 5 do
        local playerID = PlayerResource:GetNthPlayerIDOnTeam( teamID, slot )
        local connection_state = PlayerResource:GetConnectionState( playerID )
        if connection_state == DOTA_CONNECTION_STATE_CONNECTED then
            PlayerResource:ModifyGold( playerID, gold, false, DOTA_ModifyGold_AbandonedRedistribute )
        end
    end
end

--/////////////////////////////////////////////////////////////////////////////////////////////
--DISABLED
--/////////////////////////////////////////////////////////////////////////////////////////////

-- An ability was used by a player
function GameMode:OnAbilityUsed(keys)
  DebugPrint('[BAREBONES] AbilityUsed')
  DebugPrintTable(keys)

  local player = PlayerResource:GetPlayer(keys.PlayerID)
  local abilityname = keys.abilityname
end

-- This function is called whenever an ability begins its PhaseStart phase (but before it is actually cast)
function GameMode:OnAbilityCastBegins(keys)
  DebugPrint('[BAREBONES] OnAbilityCastBegins')
  DebugPrintTable(keys)

  local player = PlayerResource:GetPlayer(keys.PlayerID)
  local abilityName = keys.abilityname
end

-- A player has reconnected to the game.  This function can be used to repaint Player-based particles or change
-- state as necessary
function GameMode:OnPlayerReconnect(keys)
  DebugPrint( '[BAREBONES] OnPlayerReconnect' )
  DebugPrintTable(keys)

  local newState = GameRules:State_Get()
end

-- An item was picked up off the ground
function GameMode:OnItemPickedUp(keys)
  DebugPrint( '[BAREBONES] OnItemPickedUp' )
  DebugPrintTable(keys)

  local heroEntity = EntIndexToHScript(keys.HeroEntityIndex)
  local itemEntity = EntIndexToHScript(keys.ItemEntityIndex)
  local player = PlayerResource:GetPlayer(keys.PlayerID)
  local itemname = keys.itemname
end

-- This function is called whenever an item is combined to create a new item
function GameMode:OnItemCombined(keys)
  DebugPrint('[BAREBONES] OnItemCombined')
  DebugPrintTable(keys)

  -- The playerID of the hero who is buying something
  local plyID = keys.PlayerID
  if not plyID then return end
  local player = PlayerResource:GetPlayer(plyID)

  -- The name of the item purchased
  local itemName = keys.itemname 
  
  -- The cost of the item purchased
  local itemcost = keys.itemcost
end



-- An NPC has spawned somewhere in game.  This includes heroes
function GameMode:OnNPCSpawned(keys)
  -- DebugPrint("[BAREBONES] NPC Spawned")
  -- DebugPrintTable(keys)
  -- This internal handling is used to set up main barebones functions
  -- GameMode:_OnNPCSpawned(keys)
  -- local npc = EntIndexToHScript(keys.entindex)
end

-- An item was purchased by a player
function GameMode:OnItemPurchased( keys )
  DebugPrint( '[BAREBONES] OnItemPurchased' )
  DebugPrintTable(keys)

  -- The playerID of the hero who is buying something
  local plyID = keys.PlayerID
  if not plyID then return end

  -- The name of the item purchased
  local itemName = keys.itemname
  
  -- The cost of the item purchased
  local itemcost = keys.itemcost
end



-- A non-player entity (necro-book, chen creep, etc) used an ability
function GameMode:OnNonPlayerUsedAbility(keys)
  DebugPrint('[BAREBONES] OnNonPlayerUsedAbility')
  DebugPrintTable(keys)

  local abilityname=  keys.abilityname
end

-- A player changed their name
function GameMode:OnPlayerChangedName(keys)
  DebugPrint('[BAREBONES] OnPlayerChangedName')
  DebugPrintTable(keys)

  local newName = keys.newname
  local oldName = keys.oldName
end

-- A channelled ability finished by either completing or being interrupted
function GameMode:OnAbilityChannelFinished(keys)
  DebugPrint('[BAREBONES] OnAbilityChannelFinished')
  DebugPrintTable(keys)

  local abilityname = keys.abilityname
  local interrupted = keys.interrupted == 1
end

-- A player leveled up
function GameMode:OnPlayerLevelUp(keys)
  DebugPrint('[BAREBONES] OnPlayerLevelUp')
  DebugPrintTable(keys)

  local player = EntIndexToHScript(keys.player)
  local level = keys.level
end

-- A player last hit a creep, a tower, or a hero
function GameMode:OnLastHit(keys)
  DebugPrint('[BAREBONES] OnLastHit')
  DebugPrintTable(keys)

  local isFirstBlood = keys.FirstBlood == 1
  local isHeroKill = keys.HeroKill == 1
  local isTowerKill = keys.TowerKill == 1
  local player = PlayerResource:GetPlayer(keys.PlayerID)
  local killedEnt = EntIndexToHScript(keys.EntKilled)
end

-- A tree was cut down by tango, quelling blade, etc
function GameMode:OnTreeCut(keys)
  DebugPrint('[BAREBONES] OnTreeCut')
  DebugPrintTable(keys)

  local treeX = keys.tree_x
  local treeY = keys.tree_y
end

-- A rune was activated by a player
function GameMode:OnRuneActivated (keys)
  DebugPrint('[BAREBONES] OnRuneActivated')
  DebugPrintTable(keys)

  local player = PlayerResource:GetPlayer(keys.PlayerID)
  local rune = keys.rune

  --[[ Rune Can be one of the following types
  DOTA_RUNE_DOUBLEDAMAGE
  DOTA_RUNE_HASTE
  DOTA_RUNE_HAUNTED
  DOTA_RUNE_ILLUSION
  DOTA_RUNE_INVISIBILITY
  DOTA_RUNE_BOUNTY
  DOTA_RUNE_MYSTERY
  DOTA_RUNE_RAPIER
  DOTA_RUNE_REGENERATION
  DOTA_RUNE_SPOOKY
  DOTA_RUNE_TURBO
  ]]
end

-- A player took damage from a tower
function GameMode:OnPlayerTakeTowerDamage(keys)
  DebugPrint('[BAREBONES] OnPlayerTakeTowerDamage')
  DebugPrintTable(keys)

  local player = PlayerResource:GetPlayer(keys.PlayerID)
  local damage = keys.damage
end

-- A player killed another player in a multi-team context
function GameMode:OnTeamKillCredit(keys)
  DebugPrint('[BAREBONES] OnTeamKillCredit')
  DebugPrintTable(keys)

  local killerPlayer = PlayerResource:GetPlayer(keys.killer_userid)
  local victimPlayer = PlayerResource:GetPlayer(keys.victim_userid)
  local numKills = keys.herokills
  local killerTeamNumber = keys.teamnumber
end

-- An entity died
function GameMode:OnEntityKilled( keys )
  DebugPrint( '[BAREBONES] OnEntityKilled Called' )
  DebugPrintTable( keys )

  GameMode:_OnEntityKilled( keys )

  -- The Unit that was Killed
  local killedUnit = EntIndexToHScript( keys.entindex_killed )
  -- The Killing entity
  local killerEntity = nil

  if keys.entindex_attacker ~= nil then
    killerEntity = EntIndexToHScript( keys.entindex_attacker )
  end

  -- The ability/item used to kill, or nil if not killed by an item/ability
  local killerAbility = nil

  if keys.entindex_inflictor ~= nil then
    killerAbility = EntIndexToHScript( keys.entindex_inflictor )
  end

  local damagebits = keys.damagebits -- This might always be 0 and therefore useless

  -- Put code here to handle when an entity gets killed
end


-- This function is called whenever a tower is killed
function GameMode:OnTowerKill(keys)
  DebugPrint('[BAREBONES] OnTowerKill')
  DebugPrintTable(keys)

  local gold = keys.gold
  local killerPlayer = PlayerResource:GetPlayer(keys.killer_userid)
  local team = keys.teamnumber
end

-- This function is called whenever a player changes there custom team selection during Game Setup 
function GameMode:OnPlayerSelectedCustomTeam(keys)
  DebugPrint('[BAREBONES] OnPlayerSelectedCustomTeam')
  DebugPrintTable(keys)

  local player = PlayerResource:GetPlayer(keys.player_id)
  local success = (keys.success == 1)
  local team = keys.team_id
end

-- This function is called whenever an NPC reaches its goal position/target
function GameMode:OnNPCGoalReached(keys)
  DebugPrint('[BAREBONES] OnNPCGoalReached')
  DebugPrintTable(keys)

  local goalEntity = EntIndexToHScript(keys.goal_entindex)
  local nextGoalEntity = EntIndexToHScript(keys.next_goal_entindex)
  local npc = EntIndexToHScript(keys.npc_entindex)
end

-- This function is called whenever any player sends a chat message to team or All
function GameMode:OnPlayerChat(keys)
  local teamonly = keys.teamonly
  local userID = keys.userid
  local playerID = self.vUserIds[userID]:GetPlayerID()

  local text = keys.text
end