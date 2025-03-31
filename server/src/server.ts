import express from 'express';
import * as http from 'http';
import * as https from 'https';
import * as fs from 'fs';
import { WebSocketServer } from 'ws';

import { AddEvent, InitEvent, Player, removeById, RemoveEvent, UpdateEvent } from 'web-game-common';

const port = 8080;

const app = express();

/**
 * Determine how we're going to serve the web client.
 * Run with NODE_ENV=development to access Vite dev server
 */
if (process.env.NODE_ENV === 'development') {
    console.log('Using Vite development server');
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
else {
    console.log('Using static file serving')
    app.use(express.static('../client/dist'));
}

// Determine if we're in a local or production environment
const isProduction = process.env.NODE_ENV === 'production';
const isLocalHTTPS = fs.existsSync('../certificates/cert.pem') && fs.existsSync('../certificates/key.pem');

// Choose server type based on environment
let server: http.Server | https.Server;
if (isLocalHTTPS) {
    // Local HTTPS setup using self-signed certificates
    const options = {
        key: fs.readFileSync('../certificates/key.pem'),
        cert: fs.readFileSync('../certificates/cert.pem')
    };
    server = https.createServer(options, app);
    console.log('Using HTTPS server with self-signed certificates');
} else {
    // HTTP server (for local dev without certs, or for production where HTTPS is handled by GKE Ingress)
    server = http.createServer(app);
    console.log(`Using HTTP server (${isProduction ? 'production uses HTTPS via GKE Ingress' : 'no certificates found'})`);
}

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
    const protocol = isLocalHTTPS ? 'https' : 'http';
    console.log(`Server listening at ${protocol}://localhost:${port}`)
});