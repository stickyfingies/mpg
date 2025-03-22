import { WebSocketServer } from 'ws';
import { removeById } from 'web-game-common';
const wss = new WebSocketServer({ port: 8080 });
/// Reference: https://stackoverflow.com/questions/13364243/websocketserver-node-js-how-to-differentiate-clients
function generateUniqueID() {
    function s4() {
        return Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1);
    }
    return s4() + s4() + '-' + s4();
}
;
const players = [];
wss.on('connection', function connection(ws) {
    ws.on('error', console.error);
    const id = generateUniqueID();
    console.log('%s connected', id);
    ws.send(JSON.stringify({ type: 'init', players }));
    const player = { id, pos: [25, 25] };
    players.push(player);
    wss.clients.forEach(function each(client) {
        if (client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify({ type: 'add', player }));
        }
    });
    ws.on('close', () => {
        removeById(players, id);
        wss.clients.forEach(function each(client) {
            if (client.readyState === WebSocket.OPEN) {
                client.send(JSON.stringify({ type: 'remove', id }));
            }
        });
        console.log('%s disconnected', id);
    });
    ws.on('message', function message(data) {
        let index = 0;
        for (let i = 0; i < players.length; i++) {
            if (players[i].id == id) {
                index = i;
                break;
            }
        }
        const action = data.toString();
        console.log('%s received: %s', id, action);
        if (action == 'MoveUp') {
            players[index].pos[1]--;
        }
        if (action == 'MoveLeft') {
            players[index].pos[0]--;
        }
        if (action == 'MoveRight') {
            players[index].pos[0]++;
        }
        if (action == 'MoveDown') {
            players[index].pos[1]++;
        }
        wss.clients.forEach(function each(client) {
            if (client.readyState === WebSocket.OPEN) {
                client.send(JSON.stringify({ type: 'update', player: players[index] }));
            }
        });
    });
});
