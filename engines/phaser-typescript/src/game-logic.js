export const GAME_COUNT = 7;

/**
 * Convert a pointer position into a zero-based menu row.
 *
 * @param {number} y
 * @returns {number}
 */
export function menuRowAt(y) {
  return Math.floor((y - 194) / 30);
}

/**
 * Keep simulation steps bounded after a suspended or backgrounded tab resumes.
 *
 * @param {number} deltaMs
 * @returns {number}
 */
export function simulationDelta(deltaMs) {
  return Math.min(Math.max(deltaMs, 0) / 1000, 0.05);
}

/**
 * A non-growing snake may move into the cell its tail is leaving.
 *
 * @param {{ x: number, y: number }} head
 * @param {readonly { x: number, y: number }[]} parts
 * @param {boolean} willEat
 * @returns {boolean}
 */
export function snakeHitsBody(head, parts, willEat) {
  const occupied = willEat ? parts : parts.slice(0, -1);
  return occupied.some((part) => part.x === head.x && part.y === head.y);
}

/**
 * Resolve a swipe to a cardinal direction, ignoring short accidental movement.
 *
 * @param {{ x: number, y: number }} start
 * @param {{ x: number, y: number }} end
 * @param {number} [threshold]
 * @returns {{ x: number, y: number } | null}
 */
export function swipeDirection(start, end, threshold = 24) {
  const dx = end.x - start.x;
  const dy = end.y - start.y;
  if (Math.max(Math.abs(dx), Math.abs(dy)) < threshold) return null;
  if (Math.abs(dx) > Math.abs(dy)) {
    return { x: Math.sign(dx), y: 0 };
  }
  return { x: 0, y: Math.sign(dy) };
}
