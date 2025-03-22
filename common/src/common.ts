export type Player = {
  id: string,
  pos: [number, number]
};

export type InputAction = 'MoveUp' | 'MoveDown' | 'MoveLeft' | 'MoveRight';

export type InitEvent = {
  type: 'init',
  players: Player[]
};

export type AddEvent = {
  type: 'add',
  player: Player
};

export type UpdateEvent = {
  type: 'update',
  player: Player
};

export type RemoveEvent = {
  type: 'remove',
  id: string
};

export type ServerEvent = InitEvent | AddEvent | UpdateEvent | RemoveEvent;

export function removeById(array: Player[], idToRemove: string) {
  for (let i = array.length - 1; i >= 0; i--) {
    if (array[i].id === idToRemove) {
      array.splice(i, 1);
    }
  }
}