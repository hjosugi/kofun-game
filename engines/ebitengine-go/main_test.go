package main

import "testing"

func TestCircleRect(t *testing.T) {
	box := rect{10, 10, 20, 20}
	if !circleRect(vec{8, 20}, 3, box) {
		t.Fatal("circle touching rectangle should collide")
	}
	if circleRect(vec{0, 0}, 3, box) {
		t.Fatal("distant circle should not collide")
	}
}

func TestGameGoalsAreInitialized(t *testing.T) {
	game := newArcade()
	if got := len(game.courier.relics); got != 8 {
		t.Fatalf("courier relic count = %d, want 8", got)
	}
	if got := len(game.breaker.bricks); got != 50 {
		t.Fatalf("breaker brick count = %d, want 50", got)
	}
	if game.breaker.lives != 3 {
		t.Fatalf("breaker lives = %d, want 3", game.breaker.lives)
	}
	if got := len(game.snake.body); got != 4 {
		t.Fatalf("snake starting length = %d, want 4", got)
	}
}

func TestRandomFoodAvoidsSnake(t *testing.T) {
	game := newArcade()
	for range 100 {
		food := game.randomFood(game.snake.body)
		if containsCell(game.snake.body, food) {
			t.Fatalf("food spawned on snake at %+v", food)
		}
	}
}

func TestSnakeCanMoveIntoDepartingTailCell(t *testing.T) {
	body := []cell{{2, 1}, {2, 2}, {1, 2}, {1, 1}}
	tail := cell{1, 1}
	if snakeHitsBody(body, tail, cell{8, 8}) {
		t.Fatal("departing tail cell must be legal without food")
	}
	if !snakeHitsBody(body, tail, tail) {
		t.Fatal("tail cell must collide when food prevents tail movement")
	}
}

func TestSkyLossWinsOverTenthGate(t *testing.T) {
	if got := resolveSkyResult(lost, 10); got != lost {
		t.Fatalf("resolveSkyResult(lost, 10) = %v, want lost", got)
	}
	if got := resolveSkyResult(playing, 10); got != won {
		t.Fatalf("resolveSkyResult(playing, 10) = %v, want won", got)
	}
}

func TestTapAtHandlesTargetAndDecoyBoundaries(t *testing.T) {
	game := newArcade()
	target := game.tap.target
	game.tapAt(&game.tap, target)
	if game.tap.collected != 1 {
		t.Fatalf("target press collected = %d, want 1", game.tap.collected)
	}

	decoy := game.tap.decoys[0]
	before := game.tap.time
	game.tapAt(&game.tap, decoy)
	if game.tap.time != before-3 {
		t.Fatalf("decoy press time = %v, want %v", game.tap.time, before-3)
	}
	if game.tap.flash != .25 {
		t.Fatalf("decoy press flash = %v, want .25", game.tap.flash)
	}
}

func TestFinishedModeIsAvailableToRestartInput(t *testing.T) {
	game := newArcade()
	if game.isFinished() {
		t.Fatal("menu must not be considered a finished game")
	}
	game.mode = courierMode
	game.courier.state = lost
	if !game.isFinished() {
		t.Fatal("lost courier must be available to restart")
	}
}
