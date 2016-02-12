-- This is the primary barebones gamemode script and should be used to assist in initializing your game mode

-- Set this to true if you want to see a complete debug output of all events/processes done by barebones
-- You can also change the cvar 'barebones_spew' at any time to 1 or 0 for output/no output
BAREBONES_DEBUG_SPEW = false

if GameMode == nil then
    DebugPrint( '[BAREBONES] creating barebones game mode' )
    _G.GameMode = class({})
end

-- This library allow for easily delayed/timed actions
require('libraries/timers')
-- This library can be used for advancted physics/motion/collision of units.  See PhysicsReadme.txt for more information.
require('libraries/physics')
-- This library can be used for advanced 3D projectile systems.
require('libraries/projectiles')
-- This library can be used for sending panorama notifications to the UIs of players/teams/everyone
require('libraries/notifications')
-- This library can be used for starting customized animations on units from lua
require('libraries/animations')
-- This library can be used for performing "Frankenstein" attachments on units
require('libraries/attachments')

-- These internal libraries set up barebones's events and processes.  Feel free to inspect them/change them if you need to.
require('internal/gamemode')
require('internal/events')

-- settings.lua is where you can specify many different properties for your game mode and is one of the core barebones files.
require('settings')
-- events.lua is where you can specify the actions to be taken when any event occurs and is one of the core barebones files.
require('events')

--[[
  This function should be used to set up Async precache calls at the beginning of the gameplay.

  In this function, place all of your PrecacheItemByNameAsync and PrecacheUnitByNameAsync.  These calls will be made
  after all players have loaded in, but before they have selected their heroes. PrecacheItemByNameAsync can also
  be used to precache dynamically-added datadriven abilities instead of items.  PrecacheUnitByNameAsync will 
  precache the precache{} block statement of the unit and all precache{} block statements for every Ability# 
  defined on the unit.

  This function should only be called once.  If you want to/need to precache more items/abilities/units at a later
  time, you can call the functions individually (for example if you want to precache units in a new wave of
  holdout).

  This function should generally only be used if the Precache() function in addon_game_mode.lua is not working.
]]
function GameMode:PostLoadPrecache()
  DebugPrint("[BAREBONES] Performing Post-Load precache")    
  --PrecacheItemByNameAsync("item_example_item", function(...) end)
  --PrecacheItemByNameAsync("example_ability", function(...) end)

  --PrecacheUnitByNameAsync("npc_dota_hero_viper", function(...) end)
end

--[[
  This function is called once and only once as soon as the first player (almost certain to be the server in local lobbies) loads in.
  It can be used to initialize state that isn't initializeable in InitGameMode() but needs to be done before everyone loads in.
]]
function GameMode:OnFirstPlayerLoaded()
  DebugPrint("[BAREBONES] First Player has loaded")
end

--[[
  This function is called once and only once after all players have loaded into the game, right as the hero selection time begins.
  It can be used to initialize non-hero player state or adjust the hero selection (i.e. force random etc)
]]
function GameMode:OnAllPlayersLoaded()
  DebugPrint("[BAREBONES] All Players have loaded into the game")
end

--[[
  This function is called once and only once for every player when they spawn into the game for the first time.  It is also called
  if the player's hero is replaced with a new hero for any reason.  This function is useful for initializing heroes, such as adding
  levels, changing the starting gold, removing/adding abilities, adding physics, etc.

  The hero parameter is the hero entity that just spawned in
]]
function GameMode:OnHeroInGame(hero)
    -- DebugPrint("[BAREBONES] Hero spawned in game for first time -- " .. hero:GetUnitName())

    -- This line for example will set the starting gold of every hero to 500 unreliable gold
    -- hero:SetGold(500, false)

    -- These lines will create an item and add it to the player, effectively ensuring they start with the item
    -- local item = CreateItem("item_example_item", hero, hero)
    -- hero:AddItem(item)

    --[[ --These lines if uncommented will replace the W ability of any hero that loads into the game
    --with the "example_ability" ability

    local abil = hero:GetAbilityByIndex(1)
    hero:RemoveAbility(abil:GetAbilityName())
    hero:AddAbility("example_ability")]]

    local team = hero:GetTeamNumber()
    local player = hero:GetPlayerOwner()
    local pID = player:GetPlayerID()

    if pID >= 0 then
        GameMode:CreateAbilitiesForHero( hero, pID )
    end
end

--[[
  This function is called once and only once when the game completely begins (about 0:00 on the clock).  At this point,
  gold will begin to go up in ticks if configured, creeps will spawn, towers will become damageable etc.  This function
  is useful for starting any game logic timers/thinkers, beginning the first round, etc.
]]
function GameMode:OnGameInProgress()
  DebugPrint("[BAREBONES] The game has officially begun")
end

-- This function initializes the game mode and is called before anyone loads into the game
-- It can be used to pre-initialize any values/tables that will be needed later
function GameMode:InitGameMode()
  GameMode = self
  DebugPrint('[BAREBONES] Starting to load Barebones gamemode...')

  -- Call the internal function to set up the rules/behaviors specified in constants.lua
  -- This also sets up event hooks for all event handlers in events.lua
  -- Check out internals/gamemode to see/modify the exact code
  GameMode:_InitGameMode()

  -- Commands can be registered for debugging purposes or as functions that can be called by the custom Scaleform UI
  -- Convars:RegisterCommand( "command_example", Dynamic_Wrap(GameMode, 'ExampleConsoleCommand'), "A console command example", FCVAR_CHEAT )

  -- KeyValues
  self.HeroesKV = LoadKeyValues("scripts/kv/adcm_herolist.txt")
  self.StatesKV = LoadKeyValues("scripts/kv/adcm_states.txt")
  self.AbilitiesKV = LoadKeyValues("scripts/kv/adcm_abilities.txt")
  self.SubAbilitiesKV = LoadKeyValues("scripts/kv/adcm_abilities_deps.txt")
  self.AbilitiesBashKV = LoadKeyValues("scripts/kv/adcm_abilities_bash.txt")
  self.Items = LoadKeyValues("scripts/items/items_game.txt")--default dota file

  -- Storage
  self.PlayersQueue = {}
  self.EnemyIsReady = 0
  self.PlayersCount = {}

  -- Timers
  ResetCmTimer()
  self.TimeCmReserve = { 110, 110 }
  self.TimeAp = 30
  self.TimeAd = 30

  -- Create custom net tables (SETTINGS)
  self:CreateNetTablesSettings()

  -- Register listeners for events from Panorama
  CustomGameEventManager:RegisterListener("CmButtonPressed", Dynamic_Wrap(GameMode, 'OnCmButtonPressed'))
  CustomGameEventManager:RegisterListener("ChooseAbility", Dynamic_Wrap(GameMode, 'OnChooseAbility'))

  LinkLuaModifier( "berserkers_rage_bonus_range_modifier", "heroes/troll_warlord/berserkers_rage_bonus_range_modifier", LUA_MODIFIER_MOTION_NONE)

  GameRules:GetGameModeEntity():SetExecuteOrderFilter( Dynamic_Wrap( GameMode, "FilterExecuteOrder" ), self )
  GameRules:GetGameModeEntity():SetModifyGoldFilter( Dynamic_Wrap( GameMode, "FilterModifyGold" ), self )

  DebugPrint('[BAREBONES] Done loading Barebones gamemode!\n\n')
end

-- This is an example console command
-- function GameMode:ExampleConsoleCommand()
--   print( '******* Example Console Command ***************' )
--   local cmdPlayer = Convars:GetCommandClient()
--   if cmdPlayer then
--     local playerID = cmdPlayer:GetPlayerID()
--     if playerID ~= nil and playerID ~= -1 then
--       -- Do something here for the player who called this command
--       PlayerResource:ReplaceHeroWith(playerID, "npc_dota_hero_viper", 1000, 1000)
--     end
--   end

--   print( '*********************************************' )
-- end

--------------------------------------------------------------------------------------

function ResetCmTimer()
    GameMode.TimeCmMain = { 30, 40 }
end

function ResetAdTimer()
    GameMode.TimeAd = 5
end

--------------------------------------------------------------------------------------

function GameMode:CreateNetTablesSettings()
    CustomNetTables:SetTableValue( "currentstate", "state", { 0, 0 } )

    -- CM queue pick/ban
    for key,value in pairs(self.StatesKV) do
        CustomNetTables:SetTableValue("gamestate", key, value)
    end

    -- Teams picks/bans
    local _ta = {}
    local _tb = {}

    for i=2,3 do --teams

        _ta = {}

        for j=1,2 do --phase

            _tb = {}

            for k=1,6 do --slot

                table.insert(_tb, {
                    heroName = "",
                    isEnabled = false
                })

            end

            table.insert(_ta, _tb)

        end

        CustomNetTables:SetTableValue("teams", tostring(i), _ta)

    end

    -- Are all players ready for AD?
    CustomNetTables:SetTableValue("settings", "adReadyCount", {0})
    CustomNetTables:SetTableValue("settings", "2", { freeHero = "" })
    CustomNetTables:SetTableValue("settings", "3", { freeHero = "" })

    -- Hero pool
    for group, heroes in pairs( self.HeroesKV ) do
        CustomNetTables:SetTableValue( "heroes", group, heroes )
    end

    -- Abilities for AD
    for heroName, abilityKV in pairs( self.AbilitiesKV ) do
        CustomNetTables:SetTableValue( "abilities", heroName, abilityKV )
    end
end

----------------------
-- Events for Panorama
----------------------
function GameMode:CreateAdcmData()
    self.PlayersCount = {
        radiant = PlayerResource:GetPlayerCountForTeam( DOTA_TEAM_GOODGUYS ),
        dire = PlayerResource:GetPlayerCountForTeam( DOTA_TEAM_BADGUYS ),
        all = ( PlayerResource:GetPlayerCountForTeam( DOTA_TEAM_GOODGUYS ) + PlayerResource:GetPlayerCountForTeam( DOTA_TEAM_BADGUYS ) )
    }

    -- Current state
    DebugPrint("Map name: " .. GetMapName())

    if GetMapName() == MAP_CM then

        EmitAnnouncerSound( "announcer_announcer_type_capt_mode" )

    elseif GetMapName() == MAP_AP then

        CustomNetTables:SetTableValue( "currentstate", "state", { ADCM_NUMBER_OF_STATES + 1, 0 } )

        EmitAnnouncerSound( "announcer_announcer_type_all_pick" )

        Timers:CreateTimer("StartApState", {
            useGameTime = false,
            endTime = 2.0,
            callback = function()

                EmitAnnouncerSound( "announcer_announcer_choose_hero" )
                StartApTimer()

            end
        })

    end

    -- Players data
    local tempID = 0
    for i=2,3 do
        for j=1,5 do
            tempID = PlayerResource:GetNthPlayerIDOnTeam(i, j)
            if tempID >= 0 then
                CustomNetTables:SetTableValue("players", tostring(tempID), {})
                AddToCustomNetTables("players", tempID, "isCaptain", 0) -- util.lua
                AddToCustomNetTables("players", tempID, "hero", "")

                for k=1,SUB_ABILITY_SLOTS do
                    AddToCustomNetTables("players", tempID, k, "")
                    AddToCustomNetTables("players", tempID, "sub" .. k, "")
                end
            end
        end
    end

    -- Players queue for AD
    for i=1,4 do
        if i==1 or i==3 then
            for j=1,5 do
                for k=2,3 do
                    AddPlayerIdToAdQueue( k, j )
                end
            end
        else
            for j=5,1,-1 do
                for k=3,2,-1 do
                    AddPlayerIdToAdQueue( k, j )
                end
            end
        end
    end

    for qId, qValue in pairs( self.PlayersQueue ) do
        CustomNetTables:SetTableValue( "adQueue", tostring( qId ), qValue )
    end
end

function AddPlayerIdToAdQueue( team, slot )
    local tempID = PlayerResource:GetNthPlayerIDOnTeam( team, slot )
    if ( tempID >= 0 ) then
        table.insert( GameMode.PlayersQueue, {
            playerID = tempID,
            finished = 1
        })
    end
end

function GameMode:OnCmButtonPressed( keys )
    -- DebugPrint("GameMode:OnCmButtonPressed")
    -- DebugPrintTable(keys)

    local currentState = GetFromCustomNetTables( "currentstate", "state", "1" )
    -- DebugPrint(currentState)

    local pID = keys.playerID
    local teamID = nil

    if pID then
        teamID = PlayerResource:GetTeam( pID )
    end

    local heroInfo = keys.heroInfo

    if currentState == 0 then

        -- if enemy is ready
        if GameMode.EnemyIsReady == 1 then
            AddToCustomNetTables( "players", pID, "isCaptain", 1 )
            StartNextState( currentState, heroInfo )
            return
        end

        -- if enemy is not ready
        AddToCustomNetTables( "players", pID, "isCaptain", 1 )

        GameMode.EnemyIsReady = 1

    elseif currentState > 0 and currentState <= ADCM_NUMBER_OF_STATES then

        StartNextState( currentState, heroInfo )

    elseif currentState > ADCM_NUMBER_OF_STATES then

        if not teamID then
            return
        end

        local adReadyCount = GetFromCustomNetTables( "settings", "adReadyCount", "1" )
        adReadyCount = adReadyCount + 1
        CustomNetTables:SetTableValue( "settings", "adReadyCount", { adReadyCount } )

        AddToCustomNetTables( "players", pID, "hero", heroInfo.heroName )

        if GetMapName() == MAP_CM then

            local position = tostring( heroInfo.heroPosition )
            local _table_phase = GetFromCustomNetTables( "teams", teamID, 2 )
            -- disable selected hero
            _table_phase[ position ].isEnabled = false
            AddToCustomNetTables( "teams", teamID, 2, _table_phase )

        elseif GetMapName() == MAP_AP then

            DisableHeroInHeroTable( heroInfo, GameMode.Context )

        end

        CustomGameEventManager:Send_ServerToAllClients( "UpdateCmHud", {} )

        if adReadyCount == GameMode.PlayersCount.all then
            Timers:CreateTimer( "start_AD", {
                useGameTime = false,
                endTime = 0.01,
                callback = function()
                    GameMode:StartAbilityDraft()
                end
            })
        end

        return

    end

    CustomGameEventManager:Send_ServerToAllClients( "ResetPossibleHero", {} )

end

function StartNextState( currentState, heroInfo )
    -- DebugPrint("StartNextState")

    local nextState = currentState + 1
    local slot = 1

    if type( heroInfo ) == "table" then

        local stateInfo = GetStateInfo( currentState )
        local _table_phase = GetFromCustomNetTables( "teams", stateInfo.team, stateInfo.phase )

        for _slot_number = 1, 6 do
            if _table_phase[ tostring( _slot_number ) ].heroName == "" then
                _table_phase[ tostring( _slot_number ) ].heroName = heroInfo.heroName
                AddToCustomNetTables( "teams", stateInfo.team, stateInfo.phase, _table_phase )
                break
            end
        end

        if stateInfo.phase == 1 then
            DisableHeroInHeroTable( heroInfo )
        else
            DisableHeroInHeroTable( heroInfo, GameMode.Context )
        end

    end

    if currentState == ADCM_NUMBER_OF_STATES then
        for team = DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS do
            local _table_phase = GetFromCustomNetTables( "teams", team, 2 )
            for _slot_number = 1, 6 do
                _table_phase[ tostring( _slot_number ) ].isEnabled = true --enable selected heroes for pick
                AddToCustomNetTables( "teams", team, 2, _table_phase )
            end
        end
     end

    if nextState < ( ADCM_NUMBER_OF_STATES + 1 ) then

        local nextStateInfo = GetStateInfo( nextState )

        local _table_phase_next = GetFromCustomNetTables( "teams", nextStateInfo.team, nextStateInfo.phase )
        for _slot_number = 1, 6 do
            if _table_phase_next[ tostring( _slot_number ) ].heroName == "" then
                slot = _slot_number
                break
            end
        end

        StartTimer( nextStateInfo )

        EmitAnnouncerSoundForState( nextStateInfo )

    else

        Timers:RemoveTimer("cmTimer")

        EmitAnnouncerSound( "announcer_announcer_now_select" )

    end

    CustomNetTables:SetTableValue( "currentstate", "state", { nextState, slot } )
end

function GetStateInfo( state )
    local data = {}
    local _table_gamestate = CustomNetTables:GetTableValue( "gamestate", tostring( state ) )
    for _phase, _team in pairs( _table_gamestate ) do
        data = {
            phase = tonumber( _phase ),
            team = tonumber( _team )
        }
    end
    return data
end

function DisableHeroInHeroTable( heroInfo, context )
    local _table_hero = GetFromCustomNetTables( "heroes", heroInfo.heroGroup, heroInfo.heroId )

    for name, isEnabled in pairs( _table_hero ) do

        _table_hero[ name ] = 0

        if context then
            local heroName = "npc_dota_hero_" .. name
            PrecacheHeroItems( heroName, GameMode.Items, context )
        end

    end

    AddToCustomNetTables( "heroes", heroInfo.heroGroup, heroInfo.heroId, _table_hero )
end

function EmitAnnouncerSoundForState( stateInfo )
    local phases = { "ban", "pick" }
    local teams = { 0, "rad", "dire" }

    local sound_phase = phases[ stateInfo.phase ]
    local sound_team = teams[ stateInfo.team ]

    local sound = "announcer_announcer_" .. sound_phase .. "_" .. sound_team

    EmitAnnouncerSound( sound )
end

function EmitAnnouncerSoundCountdown( iTimer )
    if iTimer == 10 then
        EmitAnnouncerSound( "announcer_announcer_count_pick_10" )
    elseif iTimer == 5 then
        EmitAnnouncerSound( "announcer_announcer_count_pick_5" )
    end
end

function StartTimer( stateInfo )
    ResetCmTimer()

    Timers:CreateTimer( "cmTimer", {
        useGameTime = false,
        endTime = 0.01,
        callback = function()

            local phase = stateInfo.phase
            local team = stateInfo.team - 1
            local isOutOfTime = false

            if GameMode.TimeCmMain[ phase ] > 0 then

                GameMode.TimeCmMain[ phase ] = GameMode.TimeCmMain[ phase ] - 1

                EmitAnnouncerSoundCountdown( GameMode.TimeCmMain[ phase ] )

                if GameMode.TimeCmMain[ phase ] == 0 then
                    Timers:CreateTimer( "_timer_reserve_time", {
                        useGameTime = false,
                        endTime = 1.0,
                        callback = function()
                            EmitAnnouncerSound( "announcer_announcer_time_reserve" )
                        end
                    })
                end

            else

                if GameMode.TimeCmReserve[ team ] > 0 then

                    GameMode.TimeCmReserve[ team ] = GameMode.TimeCmReserve[ team ] - 1
                    EmitAnnouncerSoundCountdown( GameMode.TimeCmReserve[ team ] )

                else

                    isOutOfTime = true
                    local heroInfo = GetRandomHero()
                    GameMode:OnCmButtonPressed( { heroInfo = heroInfo } )

                end

            end

            local data = {
                mainTime = GameMode.TimeCmMain[ phase ],
                reserveTime = GameMode.TimeCmReserve[ team ]
            }

            CustomGameEventManager:Send_ServerToAllClients( "UpdateCmTime", data )

            if not isOutOfTime then
                return 1
            end

        end
    })
end

function StartApTimer()
    -- DebugPrint("StartApTimer")

    Timers:CreateTimer( "apTimer", {
        useGameTime = false,
        endTime = 0.01,
        callback = function()

            local isOutOfTime = false

            if GameMode.TimeAp > 0 then
                GameMode.TimeAp = GameMode.TimeAp - 1
                EmitAnnouncerSoundCountdown( GameMode.TimeAp )
            else
                isOutOfTime = true

                for team = DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS do
                    for slot = 1, 5 do
                        local pID = PlayerResource:GetNthPlayerIDOnTeam( team, slot )
                        if pID >= 0 then
                            local hero = GetFromCustomNetTables( "players", pID, "hero" )
                            if hero == "" then
                                local heroInfo = GetRandomHero()
                                GameMode:OnCmButtonPressed( {
                                    playerID = pID,
                                    heroInfo = heroInfo
                                } )
                            end
                        end
                    end
                end

            end

            local data = {
                mainTime = GameMode.TimeAp
            }

            CustomGameEventManager:Send_ServerToAllClients( "UpdateCmTime", data )

            if not isOutOfTime then
                return 1
            end
        end
    })
end

function GetRandomHero()
    local heroList = GameMode.HeroesKV
    local group = RandomInt( 1, GetLength( heroList ) ) --util.lua
    local groupKV = heroList[ tostring( group ) ]
    local heroId = RandomInt( 1, GetLength( groupKV ) )
    -- local heroIdKV = groupKV[ heroId ]

    local data = {}

    local hero = GetFromCustomNetTables( "heroes", group, heroId )

    for heroName, isEnabled in pairs( hero ) do

        if isEnabled == 0 then
            return GetRandomHero()
        else
            hero[ heroName ] = 0 --disable
            AddToCustomNetTables( "heroes", group, heroId, hero )

            data = {
                heroName = heroName,
                heroGroup = group,
                heroId = heroId
            }

            return data
        end
    end
end

--Ability Draft --

function GameMode:StartAbilityDraft()
    Timers:RemoveTimer( "apTimer" )

    for team = DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS do

        for slot = 1, 6 do

            local tempID = ""
            local heroName = ""
            local _t = {}

            if slot < 6 then

                tempID = PlayerResource:GetNthPlayerIDOnTeam( team, slot )
                if tempID >= 0 then
                    heroName = GetFromCustomNetTables( "players", tempID, "hero" )
                end

            else

                tempID = team + 100

                if GetMapName() == MAP_CM then

                    local pickTable = GetFromCustomNetTables( "teams", team, 2 )

                    for position = 1, 6 do
                        local isEnabled = pickTable[ tostring(position) ].isEnabled
                        if isEnabled then
                            heroName = pickTable[ tostring(position) ].heroName
                            break
                        end
                    end

                elseif GetMapName() == MAP_AP then

                    local heroInfo = GetRandomHero()
                    heroName = heroInfo.heroName
                    SetFreeHero( team, heroName )

                end

            end

            if tempID >= 0 then

                for abSlot = 1, 4 do
                    local ab = GetFromCustomNetTables( "abilities", heroName, abSlot )
                    table.insert(_t, {
                        abName = ab,
                        isEnabled = 1
                    })
                end

                CustomNetTables:SetTableValue("abilitiesEnabled", tostring(tempID), _t)

            end

        end

    end

    CustomNetTables:SetTableValue( "currentstate", "state", { 0, 0 } )

    CustomGameEventManager:Send_ServerToAllClients( "PlayStateTransition", {} )

    CustomGameEventManager:Send_ServerToAllClients( "UpdateAdHud", {} )

    StartAdTimer()
end

function SetFreeHero( team, heroName )
    local _table = GetFromCustomNetTables( "teams", team, 2 )
    _table[ "1" ].heroName = heroName
    _table[ "1" ].isEnabled = true

    AddToCustomNetTables( "teams", team, 2, _table )
    AddToCustomNetTables( "settings", team, "freeHero", heroName )
    PrecacheUnitByNameAsync( "npc_dota_hero_" .. heroName, function()
        CreateUnitByName( "npc_dota_hero_" .. heroName, Vector(-10000, -10000, 0), false, nil, nil, 0)
    end )
end

function GameMode:OnChooseAbility( keys )
  -- print("GameMode:OnChooseAbility")
    local currentState = GetFromCustomNetTables("currentstate", "state", "1")
    
    local pID = GetFromCustomNetTables( "adQueue", currentState, "playerID" )
    local finished = GetFromCustomNetTables( "adQueue", currentState, "finished" )

    if finished ~= 0 then
        return
    end

    local spells = {}

    for i = 1, 4 do
        table.insert( spells, GetFromCustomNetTables( "players", pID, i ) )
    end

    if not keys then
        if spells[4] ~= "" then
            keys = GetRandomAbility()
        else
            keys = GetRandomAbility(1)
        end
    end

    local abName = keys.name
    local abPosition = keys.position
    local abIsUlt = keys.isUlt

    local slot = math.ceil( currentState / GameMode.PlayersCount.all )

    if abIsUlt == 1 then
        slot = abPosition
    end

    if spells[4] ~= "" then
        slot = slot - 1
        if abIsUlt == 1 then
            return
        end
    else
        if spells[1] ~= "" and spells[2] ~= "" and spells[3] ~= "" and abIsUlt ~= 1 then
            return
        end
    end

    AddToCustomNetTables("players", pID, slot, abName)

    local ab = GameMode.SubAbilitiesKV[ abName ]
    if ab then
        local subSkills = vlua.split( ab, "||" ) -- source 2 engine
        for _,subAb in ipairs( subSkills ) do
            for i = 1, SUB_ABILITY_SLOTS do
                if GetFromCustomNetTables("players", pID, "sub" .. i) == "" then
                    AddToCustomNetTables("players", pID, "sub" .. i, subAb)
                    break
                end
            end

        end
    end

    local _t = GetFromCustomNetTables( "abilitiesEnabled", keys.ownerId, abPosition )
    _t.isEnabled = 0
    AddToCustomNetTables("abilitiesEnabled", keys.ownerId, abPosition, _t)

    AddToCustomNetTables("adQueue", currentState, "finished", 1)

    CustomGameEventManager:Send_ServerToAllClients( "UpdateAdHud", {} )
end

function GetRandomAbility( bIsUlt )
  -- print("GetRandomAbility")
    local maxSlots = 6
    local team = RandomInt( DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS )
    local teamIDs = {}
    local id = nil
    for slot = 1, maxSlots do
        if slot < maxSlots then
            id = PlayerResource:GetNthPlayerIDOnTeam( team, slot )
        else
            id = team + 100
        end
        if id >= 0 then
            table.insert( teamIDs, id )
        end
    end

    local pID = teamIDs[ RandomInt( 1, #teamIDs ) ]
    local position = RandomInt( 1, 3 )
    if bIsUlt then
        position = 4
    end

    local _table = GetFromCustomNetTables( "abilitiesEnabled", pID, position )
    if _table.isEnabled == 0 then
        return GetRandomAbility( bIsUlt )
    else
        return {
            name = _table.abName,
            position = position,
            isUlt = bIsUlt,
            ownerId = pID,
            ownerTeam = team
        }
    end
end

function StartAdTimer()
    Timers:CreateTimer("adTimer", {
        useGameTime = false,
        endTime = 2.0,
        callback = function()
            local isOutOfTime = 0
            local currentState = GetFromCustomNetTables( "currentstate", "state", "1" )

            if GameMode.TimeAd > 0 then

                GameMode.TimeAd = GameMode.TimeAd - 1

                if GameMode.TimeAd == 0 then
                    isOutOfTime = 1
                    if currentState > 0 then
                        local finished = GetFromCustomNetTables("adQueue", currentState, "finished")
                        if finished == 0 then
                            GameMode:OnChooseAbility()
                        end
                    end
                end

            else

                currentState = currentState + 1
                if currentState > #GameMode.PlayersQueue then
                    Timers:RemoveTimer("adTimer")
                    PauseGame(false)
                    return
                end

                local playerID = GetFromCustomNetTables("adQueue", currentState, "playerID")
                if playerID >= 0 then
                    EmitAnnouncerSoundForPlayer( "announcer_announcer_count_pick_5", playerID )
                end

                CustomNetTables:SetTableValue("currentstate", "state", {currentState,0})
                AddToCustomNetTables("adQueue", currentState, "finished", 0)
                ResetAdTimer()

            end

            data = {
                mainTime = GameMode.TimeAd
            }

            CustomGameEventManager:Send_ServerToAllClients("UpdateAdTime", data)
            return 1
        end
    })
end

function GameMode:OnPreGame()
    for team = DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS do
        for slot = 1, 5 do
            local pID = PlayerResource:GetNthPlayerIDOnTeam( team, slot )
            if pID >= 0 then
                local heroName = "npc_dota_hero_" .. GetFromCustomNetTables( "players", pID, "hero" )
                local player = PlayerResource:GetPlayer( pID )
                CreateHeroForPlayer( heroName, player )
            end
        end
    end
end

function GameMode:CreateAbilitiesForHero( hero, pID, originalEntity )
    RemoveAbilitiesFromHero( hero )

    local abs = GetAbilitiesForPlayer( pID )
    local absHidden = {}

    local abSibling = "troll_warlord_whirling_axes_melee"
    table.insert( absHidden, abSibling )
    table.insert( absHidden, INCREASE_ABILITY_LAYOUT )

    if #abs > 4 then
        for slot = 5, #abs do
            table.insert( absHidden, abs[ slot ] )
        end
    end

    for slot = 1, #abs do
        if abs[ slot - 1 ] and abs[ slot - 1 ] == INCREASE_ABILITY_LAYOUT then
            table.insert( abs, 4, abs[ slot ] )
            table.remove( abs, slot + 1 )
            break
        end
    end

    for slot = 1, #abs do
        local abSub = GameMode.SubAbilitiesKV[ abs[ slot ] ]
        if abSub and abSub == abSibling then
            for _i, spell in ipairs( abs ) do
                if spell == abSibling then
                    table.insert( abs, slot + 1, spell)
                    table.remove( abs, _i + 1 )
                    break
                end
            end
        end
    end

    for i, ab in ipairs( abs ) do
        local isHidden = false

        for _i, spell in ipairs( absHidden ) do
            if ab == spell then
                isHidden = true
            end
        end

        AddAbilityToHero( hero, originalEntity, ab, isHidden )
    end

    FixAbilities( hero, originalEntity )
end

function RemoveAbilitiesFromHero( hero )
    local abCount = hero:GetAbilityCount() - 1
    for i = 0, abCount do
        local ab = hero:GetAbilityByIndex( i )
        if ab and not ab:IsAttributeBonus() then
            hero:RemoveAbility( ab:GetAbilityName() )
        end
    end
end

function GetAbilitiesForPlayer( pID )
    local abs = {}

    for i = 1, 4 do
        table.insert( abs, GetFromCustomNetTables( "players", pID, i ) )
    end

    for j = 1, SUB_ABILITY_SLOTS do
        local abSub = GetFromCustomNetTables( "players", pID, "sub" .. j )
        if abSub ~= "" then
            table.insert( abs, GetFromCustomNetTables( "players", pID, "sub" .. j ) )
        else
            break
        end
    end

    return abs
end

function AddAbilityToHero( hero, originalEntity, abName, isHidden )
    -- DebugPrint(abName)
    local abNew = hero:AddAbility( abName )

    local level = 0
    if originalEntity then
        level = originalEntity:FindAbilityByName( abName ):GetLevel()
    end

    if abNew:GetMaxLevel() == 1 then
        level = 1
    end

    abNew:SetLevel( level )

    if level == 0 then
        FixModifiers( hero, abName )
    end

    abNew:SetHidden( isHidden )
end

function FixModifiers( hero, ability )
    local modName = "modifier_" .. ability
    local auraName = "modifier_" .. ability .. "_aura"

    if hero:HasModifier( modName ) then
        hero:RemoveModifierByName( modName )
    end

    if hero:HasModifier( auraName ) then
        hero:RemoveModifierByName( auraName )
    end
end

function FixAbilities( hero, originalEntity )
    local int_steal = nil
    local modifier_int_steal = "modifier_silencer_int_steal"
    local ability_glaives = "silencer_glaives_of_wisdom"
  
    Timers:CreateTimer(0, function()

        local abCount = hero:GetAbilityCount() - 1

        for i = 0, abCount do

            local ab = hero:GetAbilityByIndex( i )

            if ab then

                local abName = ab:GetAbilityName()
                local subAb = GameMode.SubAbilitiesKV[ abName ]

                --fix wtf auto upgrade ancient apparation ice blast
                if not originalEntity and subAb and ab:GetLevel() > 0 then
                    ab:SetLevel( 0 )
                end

                --fix silencer's int steal
                if abName == ability_glaives then
                    int_steal = true
                end

            end
        end

        if hero:HasModifier( modifier_int_steal ) then
            hero:RemoveModifierByName( modifier_int_steal )
        end

        if int_steal and not hero:HasModifier( modifier_int_steal ) then
            hero:AddNewModifier( hero, nil, modifier_int_steal, { duration = -1 } )
        end

    end)

end

function GameMode:FilterExecuteOrder( filterTable )
    -- for k, v in pairs(filterTable) do
    --   print(k, v)
    --   DebugPrintTable(v)
    -- end

    local ability = filterTable[ "entindex_ability" ]

    if ability > 0 then

        local order = filterTable[ "order_type" ]

        if order == DOTA_UNIT_ORDER_DROP_ITEM or order == DOTA_UNIT_ORDER_GIVE_ITEM or order == DOTA_UNIT_ORDER_SELL_ITEM then

            local ab = EntIndexToHScript( ability )
            local scepter_name = "item_ultimate_scepter"

            -- for _, hero in pairs(units_table) do
            if ab:GetAbilityName() == scepter_name then
                local hero = EntIndexToHScript( filterTable[ "units" ][ "0" ] )
                local _ab = hero:FindAbilityByName( INCREASE_ABILITY_LAYOUT )
                if _ab then
                    return nil
                end
            end
            -- end

        elseif order == DOTA_UNIT_ORDER_CAST_TOGGLE then

            local ab = EntIndexToHScript( ability )
            local ability_name = "troll_warlord_berserkers_rage"
            if ab:GetAbilityName() == ability_name then

                local hero = EntIndexToHScript( filterTable[ "units" ][ "0" ] )

                local modifier_name = "modifier_" .. ability_name
                local modifier_name_fix = "berserkers_rage_bonus_range_modifier"

                if not hero:HasModifier( modifier_name ) then
                    local attack_range = hero:GetAttackRange()
                    hero:AddNewModifier( hero, nil, modifier_name_fix, { range = attack_range } )
                else
                    hero:RemoveModifierByName( modifier_name_fix )
                end

            end

        end

    end

    return true
end

function GameMode:FilterModifyGold( filterTable )
    -- for k, v in pairs(filterTable) do
    --     print(k, v)
    -- end

    local playerID = filterTable.player_id_const
    local teamID = PlayerResource:GetTeam( playerID )

    if PlayerResource:GetConnectionState( playerID ) == DOTA_CONNECTION_STATE_ABANDONED then
        return
    end

    local myTeam = 1
    local enemyTeam = 1

    if teamID == DOTA_TEAM_GOODGUYS then

        myTeam = self.PlayersCount.radiant
        enemyTeam = self.PlayersCount.dire

    elseif teamID == DOTA_TEAM_BADGUYS then

        myTeam = self.PlayersCount.dire
        enemyTeam = self.PlayersCount.radiant

    end

    local ratio = enemyTeam / myTeam

    if ratio < 1 then
        ratio = 1 - ( 1 - ratio ) / 2
        filterTable.gold = math.ceil( filterTable.gold * ratio )
    end

    return true
end