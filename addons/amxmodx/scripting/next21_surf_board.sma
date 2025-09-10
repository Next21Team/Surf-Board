#include <amxmodx>
#include <fakemeta>
#include <reapi>

#define PLUGIN  "Surf Board"
#define VERSION "0.1"
#define AUTHOR  "Psycrow"

#define SURFING_HOLD_TIME 3.0

new const MODEL_BOARD[] = "models/next21_surf/board_a01.mdl"
new const CLASSNAME_BOARD[] = "surf_board"

#define PLAYER_GAITSEQ_SURF        1
#define PLAYER_GAITSEQ_DUCK_SURF   2

enum _:BOARD_BODIES_NUM
{
    BOARD_BODY_IDLE,
    BOARD_BODY_SURFING
}

enum _:BOARD_SEQ_NUM
{
    BOARD_SEQ_IDLE,
    BOARD_SEQ_CROUCH
}

enum BoardState
{
    BS_REMOVED,
    BS_IDLE,
    BS_SURF
}

new g_iBoardEnt[MAX_PLAYERS + 1]
new BoardState:g_BoardState[MAX_PLAYERS + 1]

new HookChain:g_pHookPlayerSetAnimation

new g_pCvarBoardSpawnGive
new g_pCvarBackBoard
new g_pCvarPlayerAnimation


public plugin_natives()
{
	register_native("surf_board_give", "_surf_board_give")
	register_native("surf_board_remove", "_surf_board_remove")
	register_native("surf_board_get_entity", "_surf_board_get_entity")
}

public plugin_precache()
{
    precache_model(MODEL_BOARD)
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)

    RegisterHookChain(RG_CBasePlayer_Spawn, "RG_CBasePlayer_Spawn_Post", true)
    RegisterHookChain(RG_CBasePlayer_Killed, "RG_CBasePlayer_Killed_Post", true)
    RegisterHookChain(RG_CBasePlayer_PreThink, "RG_CBasePlayer_PreThink_Pre")

    g_pHookPlayerSetAnimation = RegisterHookChain(RG_CBasePlayer_SetAnimation, "RG_CBasePlayer_SetAnimation_Post", true)

    new pCvarBoardSpawnGive = register_cvar("surf_board_spawn_give", "1")
    new pCvarBackBoard = register_cvar("surf_board_back", "1")
    new pCvarPlayerAnimation = register_cvar("surf_board_player_animation", "1")

    bind_pcvar_num(pCvarBoardSpawnGive, g_pCvarBoardSpawnGive)
    bind_pcvar_num(pCvarBackBoard, g_pCvarBackBoard)
    bind_pcvar_num(pCvarPlayerAnimation, g_pCvarPlayerAnimation)

    hook_cvar_change(pCvarBackBoard, "on_cvar_back_board_changed")
    hook_cvar_change(pCvarPlayerAnimation, "on_cvar_player_animation_changed")

    if (!g_pCvarPlayerAnimation)
        DisableHookChain(g_pHookPlayerSetAnimation)
}

public client_disconnected(iPlayer)
{
    set_board_state(iPlayer, BS_REMOVED)
}

public RG_CBasePlayer_Spawn_Post(const iPlayer)
{
    if (g_pCvarBoardSpawnGive && is_user_alive(iPlayer))
        set_board_state(iPlayer, BS_IDLE)
}

public RG_CBasePlayer_Killed_Post(const iPlayer, iAttacker, iGib)
{
    set_board_state(iPlayer, BS_REMOVED)
}

public RG_CBasePlayer_PreThink_Pre(const iPlayer)
{
    static Float:fSurfingResetTime[MAX_PLAYERS + 1]

    if (g_BoardState[iPlayer] == BS_REMOVED)
        return HC_CONTINUE

    if (!is_surfing_available(iPlayer))
    {
        set_board_state(iPlayer, BS_IDLE)
        fSurfingResetTime[iPlayer] = 0.0
        return HC_CONTINUE
    }

    new Float:fGameTime = get_gametime()

    if (is_player_surfing(iPlayer))
    {
        set_board_state(iPlayer, BS_SURF)
        fSurfingResetTime[iPlayer] = fGameTime + SURFING_HOLD_TIME
    }
    else if (fSurfingResetTime[iPlayer] <= fGameTime)
    {
        set_board_state(iPlayer, BS_IDLE)
    }

    return HC_CONTINUE
}

public RG_CBasePlayer_SetAnimation_Post(const iPlayer, PLAYER_ANIM:playerAnim)
{
    if (g_BoardState[iPlayer] != BS_SURF)
        return HC_CONTINUE

    if (get_entvar(iPlayer, var_flags) & FL_DUCKING)
    {
        set_entvar(iPlayer, var_gaitsequence, PLAYER_GAITSEQ_DUCK_SURF)
        set_entvar(g_iBoardEnt[iPlayer], var_sequence, BOARD_SEQ_CROUCH)
    }
    else
    {
        set_entvar(iPlayer, var_gaitsequence, PLAYER_GAITSEQ_SURF)
        set_entvar(g_iBoardEnt[iPlayer], var_sequence, BOARD_SEQ_IDLE)
    }

    return HC_CONTINUE
}

public on_cvar_back_board_changed(pCvar, const szOldValue[], const szNewValue[])
{
    new bool:bBackBoardEnabled = bool:str_to_num(szNewValue)

    for (new iPlayer = 1, iBoardEnt; iPlayer <= MaxClients; iPlayer++)
    {
        iBoardEnt = g_iBoardEnt[iPlayer]
        if (is_nullent(iBoardEnt))
            continue

        if (g_BoardState[iPlayer] == BS_IDLE)
        {
            if (bBackBoardEnabled)
                show_entity(iBoardEnt)
            else
                hide_entity(iBoardEnt)
        }
    }
}

public on_cvar_player_animation_changed(pCvar, const szOldValue[], const szNewValue[])
{
    if (str_to_num(szNewValue))
        EnableHookChain(g_pHookPlayerSetAnimation)
    else
        DisableHookChain(g_pHookPlayerSetAnimation)
}

bool:is_surfing_available(iPlayer)
{
    if (get_entvar(iPlayer, var_flags) & FL_ONGROUND)
        return false

    if (get_entvar(iPlayer, var_movetype) == MOVETYPE_FLY)
        return false

    return true
}

bool:is_player_surfing(iPlayer)
{
    static bool:bCachedRes[MAX_PLAYERS + 1]
    static Float:fCheckDelayTime[MAX_PLAYERS + 1]
    static Float:vOrigin[3], Float:vTemp[3]

    if (!is_surfing_available(iPlayer))
        return false

    new Float:fGameTime = get_gametime()
    if (fGameTime < fCheckDelayTime[iPlayer])
        return bCachedRes[iPlayer]

    fCheckDelayTime[iPlayer] = fGameTime + 0.5

    get_entvar(iPlayer, var_origin, vOrigin)

    vTemp[0] = vOrigin[0]
    vTemp[1] = vOrigin[1]
    vTemp[2] = vOrigin[2] - 1.0

    new iFlags = get_entvar(iPlayer, var_flags)
    new pTrace = create_tr2()
    engfunc(EngFunc_TraceHull, vOrigin, vTemp, 0, iFlags & FL_DUCKING ? HULL_HEAD : HULL_HUMAN, iPlayer, pTrace)

    new bool:bRes

    new Float:fFraction
    get_tr2(pTrace, TR_flFraction, fFraction)
    if (fFraction < 1.0)
    {
        get_tr2(pTrace, TR_vecPlaneNormal, vTemp)
        bRes = vTemp[2] <= 0.7
    }
    else
    {
        bRes = false
    }

    free_tr2(pTrace)
    bCachedRes[iPlayer] = bRes
    return bRes
}

create_or_get_board(iPlayer)
{
    if (g_iBoardEnt[iPlayer])
        return g_iBoardEnt[iPlayer]

    new iBoardEnt = rg_create_entity("info_target", true)
    if (is_nullent(iBoardEnt))
        return 0

    engfunc(EngFunc_SetModel, iBoardEnt, MODEL_BOARD)
    set_entvar(iBoardEnt, var_classname, CLASSNAME_BOARD)
    set_entvar(iBoardEnt, var_movetype, MOVETYPE_FOLLOW)
    set_entvar(iBoardEnt, var_aiment, iPlayer)

    g_iBoardEnt[iPlayer] = iBoardEnt
    return iBoardEnt
}

remove_board(iPlayer)
{
    if (g_iBoardEnt[iPlayer])
    {
        new iBoardEnt = g_iBoardEnt[iPlayer]
        set_entvar(iBoardEnt, var_flags, FL_KILLME)
        g_iBoardEnt[iPlayer] = 0
    }
}

set_board_state(iPlayer, BoardState:boardState)
{
    if (g_BoardState[iPlayer] == boardState)
        return

    g_BoardState[iPlayer] = boardState

    switch (boardState)
    {
        case BS_REMOVED:
        {
            remove_board(iPlayer)

            if (g_pCvarPlayerAnimation && is_user_alive(iPlayer))
                rg_set_animation(iPlayer, PLAYER_JUMP)
        }
        case BS_IDLE:
        {
            new iBoardEnt = create_or_get_board(iPlayer)
            if (iBoardEnt)
            {
                if (!g_pCvarBackBoard)
                    hide_entity(iBoardEnt)

                set_entvar(iBoardEnt, var_sequence, BOARD_SEQ_IDLE)
                set_entvar(iBoardEnt, var_body, BOARD_BODY_IDLE)
            }

            if (g_pCvarPlayerAnimation)
                rg_set_animation(iPlayer, PLAYER_JUMP)
        }
        case BS_SURF:
        {
            new iBoardEnt = create_or_get_board(iPlayer)
            if (iBoardEnt)
            {
                show_entity(iBoardEnt)
                set_entvar(iBoardEnt, var_body, BOARD_BODY_SURFING)
            }

            if (g_pCvarPlayerAnimation)
                rg_set_animation(iPlayer, PLAYER_JUMP)
        }
    }
}

show_entity(iEnt)
{
    set_entvar(iEnt, var_effects, get_entvar(iEnt, var_effects) & ~EF_NODRAW)
}

hide_entity(iEnt)
{
    set_entvar(iEnt, var_effects, get_entvar(iEnt, var_effects) | EF_NODRAW)
}

public _surf_board_give(plugin, num_params)
{
    new iPlayer = get_param(1)
    if (is_user_alive(iPlayer))
        set_board_state(iPlayer, BS_IDLE)
    return g_iBoardEnt[iPlayer]
}

public _surf_board_remove(plugin, num_params)
{
    new iPlayer = get_param(1)
    set_board_state(iPlayer, BS_REMOVED)
}

public _surf_board_get_entity(plugin, num_params)
{
    new iPlayer = get_param(1)
    return g_iBoardEnt[iPlayer]
}
