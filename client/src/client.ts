import './main.css';

import { InputAction, Player, removeById, ServerEvent } from 'web-game-common';

// TODO: global state
let players: Player[] = [];

function connectToWebSocketServer(): Promise<WebSocket> {
  return new Promise(function (resolve, reject) {
    // Use the same port as the website (80 in production, location.port elsewhere)
    const wsPort = location.port || (location.protocol === 'https:' ? '443' : '80');
    var server = new WebSocket(`${location.protocol === 'https:' ? 'wss:' : 'ws:'}//${location.hostname}${wsPort !== '80' && wsPort !== '443' ? ':' + wsPort : ''}`);
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
  
  // Get WebGL2 context
  const gl = canvasElement.getContext('webgl2')!;
  
  // Set up WebGL2 shader program
  const vertexShaderSource = `#version 300 es
    in vec2 a_position;
    uniform vec2 u_resolution;
    
    void main() {
      // Convert pixel coordinates to clip space
      vec2 clipSpace = (a_position / u_resolution) * 2.0 - 1.0;
      gl_Position = vec4(clipSpace * vec2(1, -1), 0, 1);
    }
  `;
  
  const fragmentShaderSource = `#version 300 es
    precision mediump float;
    out vec4 outColor;
    uniform vec4 u_color;
    
    void main() {
      outColor = u_color;
    }
  `;
  
  // Create and compile shaders
  function createShader(gl: WebGL2RenderingContext, type: number, source: string) {
    const shader = gl.createShader(type)!;
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
      console.error('Shader compile error:', gl.getShaderInfoLog(shader));
      gl.deleteShader(shader);
      return null;
    }
    return shader;
  }
  
  const vertexShader = createShader(gl, gl.VERTEX_SHADER, vertexShaderSource)!;
  const fragmentShader = createShader(gl, gl.FRAGMENT_SHADER, fragmentShaderSource)!;
  
  // Create program
  const program = gl.createProgram()!;
  gl.attachShader(program, vertexShader);
  gl.attachShader(program, fragmentShader);
  gl.linkProgram(program);
  
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    console.error('Program link error:', gl.getProgramInfoLog(program));
  }
  
  // Look up attribute and uniform locations
  const positionAttributeLocation = gl.getAttribLocation(program, 'a_position');
  const resolutionUniformLocation = gl.getUniformLocation(program, 'u_resolution');
  const colorUniformLocation = gl.getUniformLocation(program, 'u_color');
  
  // Create a buffer for positions
  const positionBuffer = gl.createBuffer();
  
  // Create and set up the vertex array object
  const vao = gl.createVertexArray();
  gl.bindVertexArray(vao);
  
  // Set up position attribute
  gl.enableVertexAttribArray(positionAttributeLocation);
  gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
  gl.vertexAttribPointer(positionAttributeLocation, 2, gl.FLOAT, false, 0, 0);
  
  function render() {
    // Clear canvas with white
    gl.clearColor(1, 1, 1, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);
    
    // Use our program
    gl.useProgram(program);
    gl.bindVertexArray(vao);
    
    // Set uniforms
    gl.uniform2f(resolutionUniformLocation, CANVAS_WIDTH, CANVAS_HEIGHT);
    
    const PLAYER_WIDTH = 15;
    const PLAYER_HEIGHT = 15;
    
    // Draw each player as a blue rectangle
    for (const player of players) {
      // Set position buffer data for a rectangle
      const x1 = player.pos[0];
      const y1 = player.pos[1];
      const x2 = player.pos[0] + PLAYER_WIDTH;
      const y2 = player.pos[1] + PLAYER_HEIGHT;
      
      // Two triangles to form a rectangle
      const positions = [
        x1, y1,
        x2, y1,
        x1, y2,
        x1, y2,
        x2, y1,
        x2, y2,
      ];
      
      gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
      gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(positions), gl.STATIC_DRAW);
      
      // Set blue color
      gl.uniform4f(colorUniformLocation, 0, 0, 1, 1);
      
      // Draw the triangles
      gl.drawArrays(gl.TRIANGLES, 0, 6);
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