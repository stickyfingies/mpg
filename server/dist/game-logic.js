import { removeById } from 'web-game-common';
/**
 * Handles all game state and logic, separate from networking code
 */
export class GameLogic {
    constructor() {
        this.players = [];
    }
    /**
     * Add a new player to the game
     * @param id Player's unique identifier
     * @returns The newly created player
     */
    addPlayer(id) {
        const player = { id, pos: [25, 25] };
        this.players.push(player);
        return player;
    }
    /**
     * Remove a player from the game
     * @param id Player's unique identifier
     */
    removePlayer(id) {
        removeById(this.players, id);
    }
    /**
     * Get player by ID
     * @param id Player's unique identifier
     * @returns The player object or undefined if not found
     */
    getPlayer(id) {
        return this.players.find(player => player.id === id);
    }
    /**
     * Get all players in the game
     * @returns Array of all players
     */
    getAllPlayers() {
        return [...this.players]; // Return a copy to prevent direct modification
    }
    /**
     * Handle a player action (movement)
     * @param id Player's unique identifier
     * @param action Action to perform ('MoveUp', 'MoveDown', 'MoveLeft', 'MoveRight')
     * @returns The updated player object or undefined if player not found
     */
    handlePlayerAction(id, action) {
        const playerIndex = this.players.findIndex(player => player.id === id);
        if (playerIndex === -1) {
            return undefined;
        }
        // Get a reference to the player (not a copy)
        const player = this.players[playerIndex];
        // Apply movement logic
        switch (action) {
            case 'MoveUp':
                player.pos[1]--;
                break;
            case 'MoveDown':
                player.pos[1]++;
                break;
            case 'MoveLeft':
                player.pos[0]--;
                break;
            case 'MoveRight':
                player.pos[0]++;
                break;
            default:
                // Unknown action, do nothing
                return undefined;
        }
        // Could add boundary checking, collision detection, etc. here
        return player;
    }
}
