import assert from "node:assert/strict";
import test from "node:test";

import {
  GAME_COUNT,
  menuRowAt,
  simulationDelta,
  snakeHitsBody,
  swipeDirection,
} from "../src/game-logic.js";

test("all seven game slots remain part of the runtime", () => {
  assert.equal(GAME_COUNT, 7);
});

test("menu rows match their rendered hit areas", () => {
  assert.equal(menuRowAt(194), 0);
  assert.equal(menuRowAt(223), 0);
  assert.equal(menuRowAt(224), 1);
  assert.equal(menuRowAt(403), 6);
  assert.equal(menuRowAt(193), -1);
});

test("simulation delta is safe after tab suspension", () => {
  assert.equal(simulationDelta(16), 0.016);
  assert.equal(simulationDelta(1000), 0.05);
  assert.equal(simulationDelta(-5), 0);
});

test("snake tail cell is legal unless the snake grows", () => {
  const parts = [
    { x: 2, y: 1 },
    { x: 1, y: 1 },
    { x: 1, y: 2 },
  ];
  assert.equal(snakeHitsBody({ x: 1, y: 2 }, parts, false), false);
  assert.equal(snakeHitsBody({ x: 1, y: 2 }, parts, true), true);
  assert.equal(snakeHitsBody({ x: 1, y: 1 }, parts, false), true);
});

test("swipes resolve to one cardinal direction", () => {
  assert.deepEqual(swipeDirection({ x: 10, y: 10 }, { x: 80, y: 20 }), {
    x: 1,
    y: 0,
  });
  assert.deepEqual(swipeDirection({ x: 80, y: 80 }, { x: 75, y: 20 }), {
    x: 0,
    y: -1,
  });
  assert.equal(swipeDirection({ x: 10, y: 10 }, { x: 20, y: 20 }), null);
});
