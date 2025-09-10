#if defined _surf_board_included
    #endinput
#endif
#define _surf_board_included

/**
 * Give the surf board to a alive player
 *
 * @param iPlayer           - Client index
 * @return                  - Board entity index
 */
native surf_board_give(iPlayer);

/**
 * Remove the surf board from the player
 *
 * @param iPlayer           - Client index
 * @noreturn
 */
native surf_board_remove(iPlayer);

/**
 * Get the player's surf board entity index
 *
 * @param iPlayer           - Client index
 * @return                  - Board entity index
 */
native surf_board_get_entity(iPlayer);
