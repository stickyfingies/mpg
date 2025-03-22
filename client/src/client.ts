import './main.css';

import { InputAction, Player, removeById, ServerEvent } from 'web-game-common';

// TODO: global state
let players: Player[] = [];

function connectToWebSocketServer(): Promise<WebSocket> {
  return new Promise(function (resolve, reject) {
    var server = new WebSocket(`ws://${location.hostname}:8080`);
    server.onopen = function () {
      resolve(server);
    };
    server.onerror = function (err) {
      reject(err);
    };
  });
}

(async function () {
  const socket = await connectToWebSocketServer();

  socket.onmessage = function (event) {
    const data = JSON.parse(event.data) as ServerEvent;
    console.log('Socket received: ', data);

    if (data.type == 'init') {
      players = data.players;
    }
    if (data.type == 'add') {
      players.push(data.player);
    }
    if (data.type == 'update') {
      // id --> player index
      let index = 0;
      for (let i = 0; i < players.length; i++) {
        if (data.player.id == players[i].id) {
          index = i;
          break;
        }
      }
      players[index] = data.player;
    }
    if (data.type == 'remove') {
      removeById(players, data.id);
    }
  }

  // TODO: global variable
  const keyMap = new Map<string, InputAction>();
  keyMap.set('ArrowLeft', 'MoveLeft');
  keyMap.set('ArrowUp', 'MoveUp');
  keyMap.set('ArrowDown', 'MoveDown');
  keyMap.set('ArrowRight', 'MoveRight');
  keyMap.set('a', 'MoveLeft');
  keyMap.set('w', 'MoveUp');
  keyMap.set('s', 'MoveDown');
  keyMap.set('d', 'MoveRight');

  const keysDown = new Map<InputAction, boolean>();

  document.addEventListener('keydown', (ev) => {
    if (!keyMap.has(ev.key)) { return; }
    keysDown.set(keyMap.get(ev.key)!, true);
  });

  document.addEventListener('keyup', (ev) => {
    if (!keyMap.has(ev.key)) { return; }
    keysDown.set(keyMap.get(ev.key)!, false);
  });

  // TODO: global variables
  const CANVAS_WIDTH = 500;
  const CANVAS_HEIGHT = 500;
  const canvasElement = document.getElementById('canvas') as HTMLCanvasElement;
  canvasElement.width = CANVAS_WIDTH;
  canvasElement.height = CANVAS_HEIGHT;
  const ctx = canvasElement.getContext('2d')!;

  function render() {
    ctx.clearRect(0, 0, canvasElement.width, canvasElement.height);

    const PLAYER_WIDTH = 15;
    const PLAYER_HEIGHT = 15;

    for (const player of players) {
      ctx.fillStyle = 'blue';
      ctx.fillRect(player.pos[0], player.pos[1], PLAYER_WIDTH, PLAYER_HEIGHT);
    }
  }

  function update() {
    for (const [key, isDown] of keysDown.entries()) {
      if (isDown) socket.send(key as InputAction);
    }
    render();
    requestAnimationFrame(update);
  }

  requestAnimationFrame(update);
})();