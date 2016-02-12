"use strict";

var debug = 0;

var adcm = 0;

var config = {
	"cmHeroesGroup" : "file://{resources}/layout/custom_game/hero_selection_cm_heroes_group.xml",
	"radiobutton" : "file://{resources}/layout/custom_game/hero_selection_radiobutton.xml",
	"cmSelectionTeam" : "file://{resources}/layout/custom_game/hero_selection_cm_selection_team.xml",
	"cmSelectionPlayer" : "file://{resources}/layout/custom_game/hero_selection_cm_selection_player.xml",
	"adPlayerLeft" : "file://{resources}/layout/custom_game/hero_selection_ad_player_left.xml",
	"adPlayerRight" : "file://{resources}/layout/custom_game/hero_selection_ad_player_right.xml",
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

var States_MaxNumber = 24;

var Titles_HeroesGroups = ["STRENGTH", "AGILITY", "INTELLIGENCE"];

var Text_StateAction = [ "CHOOSE", "BAN", "PICK" ];

var Time_Main = 0;
var Time_Reserve = 0;

var Hero_Possible = false;

//--------------------

var Time_AD = 0;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function GetCurrentState()
{
	return CustomNetTables.GetTableValue( "currentstate", "state" )[ "1" ];
}

function GetCurrentStateInfo()
{
	var currentState = GetCurrentState();
	var state = 0;
	var phase = 0;
	var team = 0;
	var slot = 1;

	if ( currentState <= States_MaxNumber )
	{
		state = CustomNetTables.GetTableValue( "gamestate", currentState );
		for ( var tempPhase in state )
		{
			phase = tempPhase;
			team = state[ tempPhase ];
		}
		slot = CustomNetTables.GetTableValue( "currentstate", "state" )[ "2" ];
	}

	var data = {
	    state: currentState,
	    phase: phase,
	    team: team,
	    slot: slot
	}
	return data;
}

function SetPanelText( parentPanel, childPanelId, text ) {
	if ( !parentPanel )
	{
		return;
	}

	var childPanel = parentPanel.FindChildInLayoutFile( childPanelId );
	if ( !childPanel )
	{
		return;
	}

	childPanel.text = text;
}


//====================================================================================================
//====================================================================================================
// CM HUD
//====================================================================================================
//====================================================================================================

function _cm_UpdateHud()
{
	var stateInfo = GetCurrentStateInfo();

	// _cm_Heroes_UpdateCover( stateInfo );
	_cm_Heroes_UpdateTable( stateInfo );

	_cm_Selection_UpdateCaptainBlock( stateInfo );
	_cm_Selection_UpdateTable( stateInfo );
}


//====================================================================================================
// Cover (mb replace with disabled radiobuttons?)
//====================================================================================================

// function _cm_Heroes_UpdateCover ( stateInfo )
// {
// 	var coverPanel = $( "#cmHeroesCover" );
// 	coverPanel.hittest = true;
// 	var isCover = "isCover";
// 	var isHidden = "hidden";

// 	var pID = Game.GetLocalPlayerInfo().player_id;

// 	if ( adcm )
// 	{
// 		if ( stateInfo.state == 0 || stateInfo.state > States_MaxNumber )
// 		{
// 			coverPanel.SetHasClass( isCover, true );
// 			coverPanel.SetHasClass( isHidden, false );
// 		}
// 		else
// 		{
// 			var isCaptain = CustomNetTables.GetTableValue( "players", pID )[ "isCaptain" ];

// 			var pTeam = Game.GetLocalPlayerInfo().player_team_id;
// 			var currentTeam = stateInfo.team;

// 			if ( debug )
// 			{
// 				isCaptain = 1;
// 				pTeam = 1;
// 				currentTeam = 1;
// 			}

// 			coverPanel.SetHasClass( isCover, false );
// 			if ( isCaptain == 1 && pTeam == currentTeam )
// 			{
// 				coverPanel.SetHasClass( isHidden, true );
// 			}
// 		}
// 	}
// 	else
// 	{
// 		coverPanel.SetHasClass( isCover, false );
// 		coverPanel.SetHasClass( isHidden, true );

// 		var playerInfo = CustomNetTables.GetTableValue( "players", pID );
// 		if ( playerInfo && playerInfo[ "hero" ] != "" )
// 		{
// 			coverPanel.SetHasClass( isCover, true );
// 			coverPanel.SetHasClass( isHidden, false );
// 		}
// 	}
// }


//====================================================================================================
// Heroes Table
//====================================================================================================

function _cm_Heroes_UpdateTable( stateInfo )
{
	var container = $( "#cmHeroesTable" );
	for (var row = 1; row <= 3; row++)
	{
		_cm_Heroes_UpdateRow( container, row, stateInfo );
	}
}

function _cm_Heroes_UpdateRow( container, row, stateInfo )
{
	var parentPanelId = "_heroes_row_" + row;
	var parentPanel = container.FindChild( parentPanelId );
	if ( !parentPanel )
	{
		parentPanel = $.CreatePanel( "Panel", container, parentPanelId );
		parentPanel.BLoadLayout( config.cmHeroesGroup, false, false );
		parentPanel.SetHasClass( "cmHeroesRow", true );
	}

	var className = "cmHeroesGroupTitle_" + row;
	var groupNamePanel = parentPanel.FindChildInLayoutFile( "GroupName" );
	// SetPanelText( parentPanel, "GroupName", Titles_HeroesGroups[ row - 1 ] );
	groupNamePanel.text = Titles_HeroesGroups[ row - 1 ];
	groupNamePanel.SetHasClass( className, true );

	var groupTable = parentPanel.FindChildInLayoutFile( "GroupTable" );

	for ( var i = 1; i <= 2; i++ )
	{
		var groupName = ( ( row - 1 ) * 2 ) + i;
		var groupKV = CustomNetTables.GetTableValue( "heroes", groupName );

		var groupPanelId = "_heroes_group_" + groupName;
		var groupPanel = groupTable.FindChild( groupPanelId );
		if ( !groupPanel )
		{
			groupPanel = $.CreatePanel( "Panel", groupTable, groupPanelId );
			groupPanel.SetHasClass( "cm_heroes_group", true );
		}

		_cm_Heroes_UpdateGroup( groupKV, groupPanel, groupName, stateInfo );
	}
}

function _cm_Heroes_UpdateGroup( groupKV, groupPanel, groupName, stateInfo )
{
	var groupContainerId = "_heroes_group_container_" + groupName;
	var groupContainer = groupPanel.FindChild( groupContainerId );
	if ( !groupContainer )
	{
		groupContainer = $.CreatePanel( "Panel", groupPanel, groupContainerId );
		groupContainer.SetHasClass( "cm_heroes_group_container", true );
		groupContainer.SetHasClass( "hBlock", true );
	}

	for ( var heroId in groupKV )
	{
		for ( var name in groupKV[ heroId ] )
		{
			var heroPanelId = "_heroes_hero_" + name;
			var heroPanel = groupContainer.FindChild( heroPanelId );
			if ( !heroPanel )
			{
				heroPanel = $.CreatePanel( "Panel", groupContainer, heroPanelId );
				heroPanel.BLoadLayout( config.radiobutton, false, false );
				heroPanel.SetHasClass( "cm_heroes_heropanel", true );
			}		

			_cm_Heroes_UpdateHero( groupKV, heroPanel, groupName, heroId, name, stateInfo );
	 	}
	}
}

function _cm_Heroes_UpdateHero( groupKV, heroPanel, groupName, heroId, name, stateInfo )
{
	var rButton = heroPanel.FindChildInLayoutFile( "RadioButton" );
	rButton.group = "Heroes";
	rButton.SetHasClass( "hBlock", true );

	var isEnabled = groupKV[ heroId ][ name ];
	if ( isEnabled == 0 )
	{
		rButton.enabled = false;
	}

	rButton.data = {
		heroName: name,
		heroId: heroId,
		heroGroup: groupName
		// heroRow: row
	};

	var pID = Game.GetLocalPlayerInfo().player_id;

	if ( adcm )
	{
		if ( !Hero_Possible )
		{
			rButton.checked = false;
		}

		if ( stateInfo.state == 0 || stateInfo.state > States_MaxNumber )
		{
			rButton.ClearPanelEvent( "onselect" );
		}
		else
		{
			var isCaptain = CustomNetTables.GetTableValue( "players", pID )[ "isCaptain" ];

			var teamID = Game.GetLocalPlayerInfo().player_team_id;
			var currentTeam = stateInfo.team;

			if ( debug )
			{
				isCaptain = 1;
				teamID = 1;
				currentTeam = 1;
			}

			if ( isCaptain == 1 && teamID == currentTeam )
			{
				rButton.SetPanelEvent( "onselect", PreviewHero( rButton.data ) );
			}
			else
			{
				rButton.ClearPanelEvent( "onselect" );
			}
		}
	}
	else
	{
		rButton.SetPanelEvent( "onselect", PreviewHero( rButton.data ) );

		var playerInfo = CustomNetTables.GetTableValue( "players", pID );
		if ( playerInfo && playerInfo[ "hero" ] != "" )
		{
			rButton.ClearPanelEvent( "onselect" );
		}
	}

	var childImage = heroPanel.FindChildInLayoutFile( "RadioImage" );
	childImage.heroname = "npc_dota_hero_" + name;
}


//====================================================================================================
// Become captain 's block
//====================================================================================================

function _cm_Selection_UpdateCaptainBlock( stateInfo )
{
	if ( stateInfo.state == 0 )
	{
		var pTeam = Game.GetLocalPlayerInfo().player_team_id;

		for ( var slot = 0; slot < 5; slot++ )
		{
			var pID = Game.GetPlayerIDsOnTeam( pTeam )[ slot ];

			var playerInfo = CustomNetTables.GetTableValue( "players", pID );

			if ( playerInfo && playerInfo[ "isCaptain" ] )
			{
				if ( !debug )
				{
					$( "#CaptainButton" ).SetHasClass( "hidden", true );
				}
				$( "#CaptainText" ).SetHasClass( "hidden", false );
				break;
			}
		}
	}
	else
	{
		$( "#bCaptain" ).SetHasClass( "hidden", true );
	}
}


//====================================================================================================
// Teams Table
//====================================================================================================

function _cm_Selection_UpdateTable( stateInfo )
{ 
	var container = $( "#cmSelectionTable" );
	for ( var team = DOTATeam_t.DOTA_TEAM_GOODGUYS; team <= DOTATeam_t.DOTA_TEAM_BADGUYS; team++ )
	{
		_cm_Selection_UpdateTeam( container, team, stateInfo );
	}

	if ( stateInfo.state == 0 )
	{
		container.SetHasClass( "hidden", true );
	}
	else
	{
		container.SetHasClass( "hidden", false );
	}
}

function _cm_Selection_UpdateTeam( container, team, stateInfo )
{
	var pID = Game.GetLocalPlayerInfo().player_id;
	var pTeam = Game.GetLocalPlayerInfo().player_team_id;

	var parentPanelId = "_selection_team_" + team;
	var parentPanel = container.FindChild( parentPanelId );
	if ( !parentPanel )
	{
		parentPanel = $.CreatePanel( "Panel", container, parentPanelId );
		parentPanel.BLoadLayout( config.cmSelectionTeam, false, false );
	}

	SetPanelText( parentPanel, "TeamName", $.Localize( Game.GetTeamDetails( team ).team_name ) );

	if ( adcm )
	{
		var currentText = " ";

		_cm_Selection_UpdateButtonBlockVisibility( parentPanel, false );

		if ( team == stateInfo.team )
		{
			SetPanelText( parentPanel, "MainTimer", Time_Main );
			SetPanelText( parentPanel, "ReserveTimer", Time_Reserve );

			currentText = Text_StateAction[ stateInfo.phase ] + " #" + stateInfo.slot;

			if (debug)
			{
				pTeam = team;
			}

			if ( team == pTeam && Hero_Possible )
			{
				_cm_Selection_UpdateButtonBlockVisibility( parentPanel, true, stateInfo );
			}
		}

		SetPanelText( parentPanel, "State", currentText );

		_cm_Selection_UpdatePick( parentPanel, team, stateInfo );
	}
	else
	{
		if ( team == pTeam )
		{
			var playerInfo = CustomNetTables.GetTableValue( "players", pID );
			if ( playerInfo )
			{
				var heroName = playerInfo[ "hero" ];
				if ( heroName == "" )
				{
					SetPanelText( parentPanel, "State", Time_Main );
				}
				else
				{
					SetPanelText( parentPanel, "State", "Waiting for other players" );
				}
			}
			else
			{
				SetPanelText( parentPanel, "State", "Choose your hero" );
			}
		}

		var timePanel = parentPanel.FindChildInLayoutFile( "Time" );
		timePanel.SetHasClass( "invisible", true );

		var heroes = parentPanel.FindChildInLayoutFile( "Heroes" );
		heroes.SetHasClass( "invisible", true );
	}

	if ( stateInfo.state > States_MaxNumber && team == pTeam && Hero_Possible )
	{
		_cm_Selection_UpdateButtonBlockVisibility( parentPanel, true, stateInfo );
	}

	var buttonPanel = parentPanel.FindChildInLayoutFile( "Button" );
	buttonPanel.SetPanelEvent( "onactivate", JustDoIt );

	_cm_Selection_UpdatePlayers( parentPanel, team );

	// config[ team ].parentPanel = parentPanel;
}

// Captains mode only ( pick/ban phase )
function _cm_Selection_UpdatePick( parentPanel, team, stateInfo )
{
	var teamTable = CustomNetTables.GetTableValue( "teams", team );

	var phasePanel = null;
	for ( var phase = 1; phase <= 2; phase++ )
	{
		if ( phase == 1 )
		{
			phasePanel = parentPanel.FindChildInLayoutFile( "Bans" );
		}
		else
		{
			phasePanel = parentPanel.FindChildInLayoutFile( "Picks" );
		}
		
		for ( var slot = 1; slot <= 6; slot++ )
		{
			var heroName = "";
			var isEnabled = false;
			
			if ( teamTable )
			{
				heroName = teamTable[ phase ][ slot ][ "heroName" ];
				isEnabled = teamTable[ phase ][ slot ][ "isEnabled" ];
			}

			var heroPanelId = "_selection_hero_" + team + "_" + phase + "_" + slot;
			var heroPanel = phasePanel.FindChild( heroPanelId );
			if ( !heroPanel )
			{
				heroPanel = $.CreatePanel( "Panel", phasePanel, heroPanelId );
				heroPanel.BLoadLayout( config.radiobutton, false, false );
				heroPanel.SetHasClass( "cm_selection_hero", true );
			}

			_cm_Selection_UpdatePickHero( heroPanel, heroName, isEnabled, team, phase, slot, stateInfo );
		}
	}
}

// Captains mode only ( pick/ban phase )
function _cm_Selection_UpdatePickHero( heroPanel, heroName, isEnabled, team, phase, slot, stateInfo )
{
	var pTeam = Game.GetLocalPlayerInfo().player_team_id;

	var rButton = heroPanel.FindChildInLayoutFile( "RadioButton" );
	rButton.group = "Hero_" + team + "_" + phase;
	rButton.enabled = false;
	rButton.SetHasClass( "hBlock", true );

	rButton.data = {
		heroName: heroName,
		heroPosition: slot
	}
	rButton.SetPanelEvent( "onselect", PreviewHero( rButton.data ) );

	if ( stateInfo.state > States_MaxNumber )
	{
		rButton.SetHasClass( "disableHero", true );
		if ( team == pTeam && isEnabled )
		{
			rButton.SetHasClass( "disableHero", false );
			rButton.enabled = true;
		}
	}

	var childImage = heroPanel.FindChildInLayoutFile( "RadioImage" );
	childImage.heroname = "";
	childImage.SetHasClass( "currentSelection", false );

	if ( heroName != "" )
	{
		childImage.heroname = "npc_dota_hero_" + heroName;
	}

	if ( team == stateInfo.team && phase == stateInfo.phase && slot == stateInfo.slot )
	{
		childImage.SetHasClass( "currentSelection", true );
	}
}

// Button block
function _cm_Selection_UpdateButtonBlockVisibility ( parentPanel, visible, stateInfo ) {
	var bButton = parentPanel.FindChildInLayoutFile( "bButton" );
	var currentHero = parentPanel.FindChildInLayoutFile( "CurrentHero" );

	bButton.SetHasClass( "invisible", true );
	currentHero.heroname = "";

	if ( visible && _cm_Selection_IsNotSameHero() )
	{
		bButton.SetHasClass( "invisible", false );
		currentHero.heroname = "npc_dota_hero_" + Hero_Possible.heroName;

		var buttonText = Text_StateAction[ stateInfo.phase ] + " HERO";
		SetPanelText( parentPanel, "ButtonLabel", buttonText );
	}
}

function _cm_Selection_IsNotSameHero()
{
	for ( var teamId = DOTATeam_t.DOTA_TEAM_GOODGUYS; teamId <= DOTATeam_t.DOTA_TEAM_BADGUYS; teamId++ )
	{
		var teamPlayers = Game.GetPlayerIDsOnTeam( teamId );

		for ( var playerId of teamPlayers )
		{
			var hero = CustomNetTables.GetTableValue( "players", playerId )[ "hero" ];

			if ( Hero_Possible.heroName == hero )
			{
				_cm_ResetPossibleHero();

				return false;
			}
		}
	}

	return true;
}

// Players
function _cm_Selection_UpdatePlayers( parentPanel, team )
{
	var players = parentPanel.FindChildInLayoutFile( "Players" );

	for ( var slot = 0; slot < 5; slot++ )
	{
		var pID = Game.GetPlayerIDsOnTeam( team )[ slot ];
		if ( pID >= 0 )
		{
			var playerPanelId = "_selection_player_" + pID;
			var playerPanel = players.FindChild( playerPanelId );
			if ( !playerPanel )
			{
				playerPanel = $.CreatePanel( "Panel", players, playerPanelId );
				playerPanel.AddClass( "player" );
				playerPanel.BLoadLayout( config.cmSelectionPlayer, false, false );
			}

			_cm_Selection_UpdatePlayerPanel( playerPanel, pID );
		}

	}
}

function _cm_Selection_UpdatePlayerPanel( playerPanel, pID ) {
	var heroName = "";
	var isCaptain = "";

	var playerTable = CustomNetTables.GetTableValue( "players", pID );
	if ( playerTable )
	{
		heroName = playerTable[ "hero" ];
		isCaptain = playerTable[ "isCaptain" ];
	}

	var childImage = playerPanel.FindChildInLayoutFile( "Image" );
	var playerGap = playerPanel.FindChildInLayoutFile( "PlayerGap" );

	if ( heroName != "" )
	{
		childImage.heroname = "npc_dota_hero_" + heroName;
		playerGap.SetHasClass( "hidden", true );
	}
	else
	{
		childImage.heroname = "";
	}

	var playerName = playerPanel.FindChildInLayoutFile( "PlayerName" );
	playerName.text = Game.GetPlayerInfo( pID ).player_name;

	if ( isCaptain )
	{
		var captainMark = playerPanel.FindChildInLayoutFile( "CaptainMark" );
		captainMark.SetHasClass( "hidden", false );
	}
}

var PreviewHero = ( function( heroInfo )
{
	return function()
	{
		Hero_Possible = heroInfo;

		_cm_UpdateHud();
	}
});

function _cm_UpdateTime( keys )
{
 	Time_Main = keys.mainTime;
	Time_Reserve = keys.reserveTime;
	
	_cm_UpdateHud();
}

function JustDoIt()
{
	var pID = Game.GetLocalPlayerInfo().player_id;

	var data = {
	    playerID: pID,
	    heroInfo: Hero_Possible
	};

	GameEvents.SendCustomGameEventToServer( "CmButtonPressed", data );
}

function _cm_ResetPossibleHero()
{
	Hero_Possible = false;
	_cm_UpdateHud();
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Transition
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function PlayStateTransition( panel )
{
	if ( !panel.id )
	{
		panel = $( "#cmWrapper" );
	}

	$.Schedule( 0, function()
	{
		panel.SetHasClass( "fadeOut", true );

		$.Schedule( 2.0, function()
		{
			panel.SetHasClass( "hidden", true );
		});
	});
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//AD
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function _ad_UpdateHud()
{
	$( "#adTime" ).text = Time_AD;

	_ad_UpdateQueue();
	_ad_UpdateTable();
}

// Timeline
function _ad_UpdateQueue()
{
	var container = $( "#adTimelineQueueHeroes" );

	var abilityQueue = CustomNetTables.GetAllTableValues("adQueue");

	for ( var i = 0; i < abilityQueue.length; i++ )
	{
		var childImageId = "_ad_queue_hero_" + i;
		var childImage = container.FindChild( childImageId );

		if ( !childImage )
		{
			var pID = abilityQueue[ i ].value.playerID;
			var heroName = CustomNetTables.GetTableValue( "players", pID )[ "hero" ];
		
			childImage = $.CreatePanel( "DOTAHeroImage", container, childImageId );
			childImage.heroname = "npc_dota_hero_" + heroName;

			if ( Game.GetLocalPlayerInfo().player_id == pID )
			{
				childImage.SetHasClass( "ad_player_local", true );
			}
		}
	}

	container.style.transform = "translate3d(" + ( ( GetCurrentState() - 1 ) * -100 ) + "px,0,0)";
}

// Main table
function _ad_UpdateTable()
{
	var stateInfo = CustomNetTables.GetTableValue( "adQueue", GetCurrentState() );

	var container = $( "#adTable" );

	for ( var teamId = DOTATeam_t.DOTA_TEAM_GOODGUYS; teamId <= DOTATeam_t.DOTA_TEAM_BADGUYS; teamId++ )
	{
		var parentContainerId = "_ad_container_team_" + teamId;
		var parentContainer = container.FindChild( parentContainerId );

		if ( !parentContainer )
		{
			parentContainer = $.CreatePanel( "Panel", container, parentContainerId );
			parentContainer.SetHasClass( "ad_container_team", true );
		}

		var parentPanelId = "_ad_team_" + teamId;
		var parentPanel = parentContainer.FindChild( parentPanelId );

		if ( !parentPanel )
		{
			parentPanel = $.CreatePanel( "Panel", parentContainer, parentPanelId );
			parentPanel.SetHasClass( "ad_team", true );
			parentPanel.SetHasClass( "hBlock", true );

			if ( teamId == DOTATeam_t.DOTA_TEAM_BADGUYS )
			{
				parentPanel.SetHasClass( "Dire", true );
			}
		}

		_ad_UpdateTeam( parentPanel, teamId, stateInfo );
	}
}

function _ad_UpdateTeam( parentPanel, teamId, stateInfo )
{
	for ( var slot = 0; slot <= 5; slot++ )
	{
		var playerId = null;
		var heroName = null;

		if ( slot < 5 )
		{
			playerId = Game.GetPlayerIDsOnTeam( teamId )[ slot ];
			if ( playerId >= 0 )
			{
				heroName = CustomNetTables.GetTableValue( "players", playerId )[ "hero" ];
			}
			else
			{
				continue;
			}
		}
		else
		{
			playerId = teamId + 100;
			if ( adcm )
			{
				var hero = CustomNetTables.GetTableValue( "teams", teamId )[ "2" ];
				for ( var j = 1; j <= 6; j++ )
				{
					var isEnabled = hero[ j ][ "isEnabled" ];
					if ( isEnabled )
					{
						heroName = hero[ j ][ "heroName" ];
						break;
					}
				}
			}
			else
			{
				heroName = CustomNetTables.GetTableValue( "settings", teamId )[ "freeHero" ];
			}
		}

		var playerPanelId = "_ad_player_" + playerId;
		var playerPanel = parentPanel.FindChild( playerPanelId );

		if ( !playerPanel )
		{
			playerPanel = $.CreatePanel( "Panel", parentPanel, playerPanelId );
			playerPanel.SetHasClass( "hBlock", true );

			var xml_config = config.adPlayerLeft;
			if ( teamId == DOTATeam_t.DOTA_TEAM_BADGUYS )
			{
				xml_config = config.adPlayerRight;
			}
			playerPanel.BLoadLayout( xml_config, false, false );

			if ( Game.GetLocalPlayerInfo().player_id == playerId )
			{
				playerPanel.SetHasClass( "player_local", true );
			}
		}

		_ad_UpdatePlayer( playerPanel, teamId, playerId, heroName, stateInfo );
	}
}

function _ad_UpdatePlayer( playerPanel, teamId, playerId, heroName, stateInfo )
{
	if ( Time_AD == 5 ) {
		playerPanel.SetHasClass( "player_current", false );
	
		if ( stateInfo && stateInfo[ "playerID" ] == playerId )
		{
			playerPanel.SetHasClass( "player_current", true );
		}
	}

	if ( playerId < 100 )
	{
		SetPanelText( playerPanel, "PlayerName", Game.GetPlayerInfo( playerId ).player_name );
	}

	var childImage = playerPanel.FindChildInLayoutFile( "HeroImage" );
	childImage.heroname = "npc_dota_hero_" + heroName;

	var ab_new_parentPanel = playerPanel.FindChildInLayoutFile( "bAbilities_New" );
	var ab_old_parentPanel = playerPanel.FindChildInLayoutFile( "bAbilities_Old" );

	for ( var slot = 1; slot <= 4; slot++ )
	{
		_ad_UpdateAbility_New( ab_new_parentPanel, playerId, slot );
		_ad_UpdateAbility_Old( ab_old_parentPanel, teamId, playerId, slot, heroName );
	}
}

function _ad_UpdateAbility_New( ab_new_parentPanel, playerId, slot ) {
	var abId = "_ability_new_" + playerId + slot;
	var abPanel = ab_new_parentPanel.FindChild( abId );
	if ( !abPanel )
	{
		abPanel = $.CreatePanel( "DOTAAbilityImage", ab_new_parentPanel, abId );
	}
	abPanel.abilityname = "";

	if ( playerId < 100 )
	{
		abPanel.abilityname = CustomNetTables.GetTableValue( "players", playerId )[ slot ];
	}

	if ( abPanel.abilityname )
	{
		abPanel.SetPanelEvent( "onmouseover", ShowAbilityTooltip( abPanel ) );
		abPanel.SetPanelEvent( "onmouseout", HideAbilityTooltip( abPanel ) );
	}
}

function _ad_UpdateAbility_Old( ab_old_parentPanel, teamId, playerId, slot, heroName )
{
	var abButtonId = "_ability_old_button_" + playerId + slot;
	var abButton = ab_old_parentPanel.FindChild( abButtonId );
	if ( !abButton )
	{
		abButton = $.CreatePanel( "RadioButton", ab_old_parentPanel, abButtonId );
		abButton.group = "Abilities";

		if ( slot == 4 )
		{
			abButton.SetHasClass( "isUltimate", true );
		}
	}
	abButton.enabled = CustomNetTables.GetTableValue( "abilitiesEnabled", playerId )[ slot ][ "isEnabled" ];
	abButton.checked = false;

	var abPanelId = "_ability_old_image_" + playerId + slot;
	var abPanel = abButton.FindChild( abPanelId );
	if ( !abPanel )
	{
		abPanel = $.CreatePanel( "DOTAAbilityImage", abButton, abPanelId );
		abPanel.abilityname = CustomNetTables.GetTableValue( "abilities", heroName )[ slot ];
		abPanel.SetHasClass( "hBlock", true );
		abPanel.SetHasClass( "vBlock", true );

		var isUltimate = 0;
		if ( slot == 4 )
		{
			// abPanel.SetHasClass( "isUltimate", true );
			isUltimate = 1;
		}

		abPanel.data = {
			name: abPanel.abilityname,
			position: slot,
			isUlt: isUltimate,
			ownerId: playerId,
			ownerTeam: teamId
		}

		abButton.SetPanelEvent( "onmouseover", ShowAbilityTooltip( abPanel ) );
		abButton.SetPanelEvent( "onmouseout", HideAbilityTooltip( abPanel ) );
		abButton.SetPanelEvent( "onselect", ChooseAbility( abPanel ) );
	}
}

var ChooseAbility = ( function( abPanel )
{
	return function()
	{
		$.DispatchEvent( "SetPanelSelected", abPanel.GetParent(), false );

		var player = CustomNetTables.GetTableValue( "adQueue", GetCurrentState() );
		if ( player == undefined )
		{
			return;
		}

		var playerId = Game.GetLocalPlayerInfo().player_id;
		if ( playerId == player[ "playerID" ] )
		{
			GameEvents.SendCustomGameEventToServer( "ChooseAbility", abPanel.data );
		}
	}
});

function _ad_UpdateTime( keys )
{
	Time_AD = keys.mainTime;
	_ad_UpdateHud();
}

//OnLoad

(function()
{
	if ( Game.GetMapInfo().map_display_name == "captains_mode" )
	{
		adcm = 1;
	}

	var Listener_UpdateCmHud = GameEvents.Subscribe( "UpdateCmHud", _cm_UpdateHud );
	var Listener_UpdateCmTime  = GameEvents.Subscribe( "UpdateCmTime", _cm_UpdateTime );
	var Listener_ResetPossibleHero = GameEvents.Subscribe( "ResetPossibleHero", _cm_ResetPossibleHero );

	GameEvents.Subscribe( "PlayStateTransition", PlayStateTransition );
	
	GameEvents.Subscribe( "UpdateAdHud", _ad_UpdateHud );
	GameEvents.Subscribe( "UpdateAdTime", _ad_UpdateTime );

	var initCoverPanel = $( "#cmInitializeCover" );

	var playersCount = Game.GetTeamDetails( DOTATeam_t.DOTA_TEAM_GOODGUYS ).team_num_players + Game.GetTeamDetails( DOTATeam_t.DOTA_TEAM_BADGUYS ).team_num_players;
	var playersReady = CustomNetTables.GetTableValue( "settings", "adReadyCount" )[ "1" ];
	if ( playersReady == playersCount )
	{
		GameEvents.Unsubscribe( Listener_UpdateCmHud );
		GameEvents.Unsubscribe( Listener_UpdateCmTime );
		GameEvents.Unsubscribe( Listener_ResetPossibleHero );

		initCoverPanel.SetHasClass( "hidden", true );
		$( "#cmWrapper" ).SetHasClass( "hidden", true );

		_ad_UpdateHud();
	}
	else
	{
		_cm_UpdateHud();
	}

	initCoverPanel.SetPanelEvent( "onload", function()
	{
		PlayStateTransition( initCoverPanel );
	});
})();