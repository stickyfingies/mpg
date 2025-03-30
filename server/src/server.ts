import express from 'express';
import * as http from 'http';
import { WebSocketServer } from 'ws';

import { AddEvent, InitEvent, Player, removeById, RemoveEvent, UpdateEvent } from 'web-game-common';

const port = 8080;

const app = express();

/**
 * Run with NODE_ENV=development to access Vite dev server
 */
if (process.env.NODE_ENV === 'development') {
    console.log('Using Vite development server.');
    const vite = await import('vite');
    const viteDevServer = await vite.createServer({
        server: {
            middlewareMode: true
        },
        root: '../client',
        base: '/'
    });
    app.use(viteDevServer.middlewares);
}
/**
 * Serve client/dist if not running in development mode
 */
else {
    app.use(express.static('../client/dist'));
}

const server = http.createServer(app);

const wss = new WebSocketServer({ server });

/// Reference: https://stackoverflow.com/questions/13364243/websocketserver-node-js-how-to-differentiate-clients
function generateUniqueID() {
    function s4() {
        return Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1);
    }
    return s4() + s4() + '-' + s4();
};

const players: Player[] = [];

wss.on('connection', function connection(ws) {

    ws.on('error', console.error);

    const id = generateUniqueID();

    console.log('%s connected', id);

    ws.send(JSON.stringify({ type: 'init', players } as InitEvent));

    const player: Player = { id, pos: [25, 25] };

    players.push(player);

    wss.clients.forEach(function each(client) {
        if (client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify({ type: 'add', player } as AddEvent));
        }
    });

    ws.on('close', () => {
        removeById(players, id);
        wss.clients.forEach(function each(client) {
            if (client.readyState === WebSocket.OPEN) {
                client.send(JSON.stringify({ type: 'remove', id } as RemoveEvent));
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
                client.send(JSON.stringify({ type: 'update', player: players[index] } as UpdateEvent));
            }
        });
    });
});

server.listen(port, () => {
    console.log(`Server listening at http://localhost:${port}`)
});