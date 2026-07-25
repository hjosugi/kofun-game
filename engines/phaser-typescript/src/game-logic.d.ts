export const GAME_COUNT: 7;

export type LogicPoint = { x: number; y: number };

export function menuRowAt(y: number): number;
export function simulationDelta(deltaMs: number): number;
export function snakeHitsBody(
  head: LogicPoint,
  parts: readonly LogicPoint[],
  willEat: boolean,
): boolean;
export function swipeDirection(
  start: LogicPoint,
  end: LogicPoint,
  threshold?: number,
): LogicPoint | null;
