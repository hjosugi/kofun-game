import Phaser from "phaser";

const WIDTH = 960;
const HEIGHT = 540;
const TOP = 66;
const BOTTOM = 520;

const GAMES = [
  {
    title: "KOFUN COURIER",
    subtitle: "Collect 8 haniwa. Avoid Dochicken.",
    controls: "MOVE  WASD / ARROWS",
  },
  {
    title: "MOUND BREAKER",
    subtitle: "Break all 50 burial mounds.",
    controls: "MOVE  A/D / LEFT/RIGHT",
  },
  {
    title: "HANIWA TAP PATROL",
    subtitle: "Tap 12 haniwa before time runs out.",
    controls: "TAP / CLICK",
  },
  {
    title: "DOCHICKEN SKY DODGE",
    subtitle: "Flap through 10 gates.",
    controls: "FLAP  SPACE / UP / TAP",
  },
  {
    title: "NEON KOFUN DASH",
    subtitle: "Jump and survive for 30 seconds.",
    controls: "JUMP  SPACE / UP / TAP",
  },
  {
    title: "KOFUN ORBIT",
    subtitle: "Pulse enemies away. Survive 30 seconds.",
    controls: "MOVE  WASD / ARROWS    PULSE  SPACE",
  },
  {
    title: "KOFUN SNAKE",
    subtitle: "Collect 15 haniwa without crashing.",
    controls: "TURN  WASD / ARROWS",
  },
] as const;

type Keys = {
  up: Phaser.Input.Keyboard.Key;
  down: Phaser.Input.Keyboard.Key;
  left: Phaser.Input.Keyboard.Key;
  right: Phaser.Input.Keyboard.Key;
  w: Phaser.Input.Keyboard.Key;
  a: Phaser.Input.Keyboard.Key;
  s: Phaser.Input.Keyboard.Key;
  d: Phaser.Input.Keyboard.Key;
  space: Phaser.Input.Keyboard.Key;
  enter: Phaser.Input.Keyboard.Key;
  escape: Phaser.Input.Keyboard.Key;
  one: Phaser.Input.Keyboard.Key;
  two: Phaser.Input.Keyboard.Key;
  three: Phaser.Input.Keyboard.Key;
  four: Phaser.Input.Keyboard.Key;
  five: Phaser.Input.Keyboard.Key;
  six: Phaser.Input.Keyboard.Key;
  seven: Phaser.Input.Keyboard.Key;
};

type Point = { x: number; y: number };
type Enemy = Point & { speed: number };
type Gate = { x: number; gapY: number; counted: boolean };
type Obstacle = { x: number; width: number; height: number };

class MatrixScene extends Phaser.Scene {
  private graphics!: Phaser.GameObjects.Graphics;
  private background!: Phaser.GameObjects.Image;
  private mascot!: Phaser.GameObjects.Image;
  private haniwa!: Phaser.GameObjects.Image;
  private titleText!: Phaser.GameObjects.Text;
  private bodyText!: Phaser.GameObjects.Text;
  private footerText!: Phaser.GameObjects.Text;
  private resultText!: Phaser.GameObjects.Text;
  private keys!: Keys;

  private selected = 0;
  private mode = -1;
  private ended = false;
  private won = false;
  private elapsed = 0;
  private pulseFlash = 0;

  private courier = {
    player: { x: 170, y: 300 },
    enemy: { x: 760, y: 300 },
    target: { x: 480, y: 280 },
    score: 0,
  };

  private breaker = {
    paddleX: 420,
    ball: { x: 480, y: 400 },
    velocity: { x: 240, y: -250 },
    bricks: [] as boolean[],
    score: 0,
    lives: 3,
  };

  private tap = {
    target: { x: 330, y: 280 },
    decoy: { x: 650, y: 280 },
    score: 0,
    timeLeft: 30,
    decoyClock: 0,
  };

  private flap = {
    playerY: 270,
    velocityY: 0,
    gates: [] as Gate[],
    score: 0,
    spawnClock: 0,
  };

  private dash = {
    playerY: 442,
    velocityY: 0,
    grounded: true,
    obstacles: [] as Obstacle[],
    spawnClock: 0,
  };

  private orbit = {
    player: { x: 480, y: 300 },
    enemies: [] as Enemy[],
    spawnClock: 0,
    pulseCooldown: 0,
    cleared: 0,
  };

  private snake = {
    parts: [] as Point[],
    direction: { x: 1, y: 0 },
    nextDirection: { x: 1, y: 0 },
    food: { x: 18, y: 8 },
    stepClock: 0,
    score: 0,
  };

  constructor() {
    super("matrix");
  }

  preload(): void {
    this.load.image("background", "assets/background.png");
    this.load.image("kofun", "assets/kofun.png");
    this.load.image("haniwa", "assets/haniwa.png");
  }

  create(): void {
    this.background = this.add
      .image(WIDTH / 2, HEIGHT / 2, "background")
      .setDisplaySize(WIDTH, HEIGHT)
      .setAlpha(0.2);
    this.graphics = this.add.graphics();
    this.mascot = this.add
      .image(840, 154, "kofun")
      .setDisplaySize(112, 112)
      .setAlpha(0.9);
    this.haniwa = this.add
      .image(120, 154, "haniwa")
      .setDisplaySize(72, 72)
      .setAlpha(0.9);

    this.titleText = this.add.text(28, 20, "", {
      color: "#fff3b0",
      fontFamily: "monospace",
      fontSize: "27px",
      fontStyle: "bold",
    });
    this.bodyText = this.add.text(92, 188, "", {
      color: "#f8f5ff",
      fontFamily: "monospace",
      fontSize: "21px",
      lineSpacing: 13,
    });
    this.footerText = this.add
      .text(WIDTH / 2, 510, "", {
        color: "#a8c7ff",
        fontFamily: "monospace",
        fontSize: "15px",
      })
      .setOrigin(0.5);
    this.resultText = this.add
      .text(WIDTH / 2, HEIGHT / 2, "", {
        align: "center",
        backgroundColor: "#090619ee",
        color: "#fff3b0",
        fontFamily: "monospace",
        fontSize: "31px",
        fontStyle: "bold",
        padding: { x: 36, y: 24 },
        stroke: "#321b4e",
        strokeThickness: 6,
      })
      .setOrigin(0.5)
      .setDepth(5)
      .setVisible(false);

    this.keys = this.input.keyboard!.addKeys({
      up: Phaser.Input.Keyboard.KeyCodes.UP,
      down: Phaser.Input.Keyboard.KeyCodes.DOWN,
      left: Phaser.Input.Keyboard.KeyCodes.LEFT,
      right: Phaser.Input.Keyboard.KeyCodes.RIGHT,
      w: Phaser.Input.Keyboard.KeyCodes.W,
      a: Phaser.Input.Keyboard.KeyCodes.A,
      s: Phaser.Input.Keyboard.KeyCodes.S,
      d: Phaser.Input.Keyboard.KeyCodes.D,
      space: Phaser.Input.Keyboard.KeyCodes.SPACE,
      enter: Phaser.Input.Keyboard.KeyCodes.ENTER,
      escape: Phaser.Input.Keyboard.KeyCodes.ESC,
      one: Phaser.Input.Keyboard.KeyCodes.ONE,
      two: Phaser.Input.Keyboard.KeyCodes.TWO,
      three: Phaser.Input.Keyboard.KeyCodes.THREE,
      four: Phaser.Input.Keyboard.KeyCodes.FOUR,
      five: Phaser.Input.Keyboard.KeyCodes.FIVE,
      six: Phaser.Input.Keyboard.KeyCodes.SIX,
      seven: Phaser.Input.Keyboard.KeyCodes.SEVEN,
    }) as Keys;

    this.input.on("pointerdown", (pointer: Phaser.Input.Pointer) => {
      if (this.mode < 0) {
        // Phaser Text uses roughly fontSize + lineSpacing for each menu row.
        const row = Math.floor((pointer.y - 194) / 30);
        if (row >= 0 && row < GAMES.length) this.startGame(row);
        return;
      }
      if (this.ended) {
        this.startGame(this.mode);
      } else if (this.mode === 2) {
        this.handleTap(pointer.x, pointer.y);
      } else if (this.mode === 3) {
        this.flapBird();
      } else if (this.mode === 4) {
        this.jump();
      }
    });

    this.showMenu();
    const requestedGame = Number.parseInt(
      new URLSearchParams(window.location.search).get("game") ?? "",
      10,
    );
    if (requestedGame >= 1 && requestedGame <= GAMES.length) {
      this.startGame(requestedGame - 1);
    }
  }

  update(_time: number, deltaMs: number): void {
    const delta = Math.min(deltaMs / 1000, 0.05);
    if (Phaser.Input.Keyboard.JustDown(this.keys.escape)) {
      this.showMenu();
      return;
    }

    if (this.mode < 0) {
      this.updateMenu();
      this.drawMenu();
      return;
    }

    if (
      this.ended &&
      (Phaser.Input.Keyboard.JustDown(this.keys.enter) ||
        Phaser.Input.Keyboard.JustDown(this.keys.space))
    ) {
      this.startGame(this.mode);
      return;
    }
    if (this.ended) {
      this.drawGame();
      return;
    }

    this.elapsed += delta;
    switch (this.mode) {
      case 0:
        this.updateCourier(delta);
        break;
      case 1:
        this.updateBreaker(delta);
        break;
      case 2:
        this.updateTap(delta);
        break;
      case 3:
        this.updateFlap(delta);
        break;
      case 4:
        this.updateDash(delta);
        break;
      case 5:
        this.updateOrbit(delta);
        break;
      case 6:
        this.updateSnake(delta);
        break;
    }
    this.drawGame();
  }

  private updateMenu(): void {
    if (Phaser.Input.Keyboard.JustDown(this.keys.up)) {
      this.selected = (this.selected + GAMES.length - 1) % GAMES.length;
    }
    if (Phaser.Input.Keyboard.JustDown(this.keys.down)) {
      this.selected = (this.selected + 1) % GAMES.length;
    }
    if (Phaser.Input.Keyboard.JustDown(this.keys.enter)) {
      this.startGame(this.selected);
      return;
    }
    const numberKeys = [
      this.keys.one,
      this.keys.two,
      this.keys.three,
      this.keys.four,
      this.keys.five,
      this.keys.six,
      this.keys.seven,
    ];
    numberKeys.forEach((key, index) => {
      if (Phaser.Input.Keyboard.JustDown(key)) this.startGame(index);
    });
  }

  private showMenu(): void {
    this.mode = -1;
    this.ended = false;
    this.resultText.setVisible(false);
    this.mascot.setVisible(true);
    this.haniwa.setVisible(true);
    this.background.setAlpha(0.28);
    this.drawMenu();
  }

  private drawMenu(): void {
    this.graphics.clear();
    this.drawGrid(0.08);
    this.graphics.fillStyle(0x090619, 0.9);
    this.graphics.fillRoundedRect(64, 82, 832, 408, 18);
    this.graphics.lineStyle(2, 0x9f7aea, 0.8);
    this.graphics.strokeRoundedRect(64, 82, 832, 408, 18);
    this.titleText.setText("KOFUN GAME MATRIX   7 x 7 LAB");

    const lines = GAMES.map((game, index) => {
      const marker = index === this.selected ? ">" : " ";
      return `${marker} ${index + 1}  ${game.title.padEnd(24)} ${game.subtitle}`;
    });
    this.bodyText
      .setPosition(92, 198)
      .setFontSize(18)
      .setLineSpacing(11)
      .setText(lines)
      .setColor("#f8f5ff");
    this.footerText.setText(
      "UP/DOWN + ENTER / 1-7 / CLICK   |   Phaser 3.90 + TypeScript",
    );
  }

  private startGame(index: number): void {
    this.mode = index;
    this.selected = index;
    this.ended = false;
    this.won = false;
    this.elapsed = 0;
    this.pulseFlash = 0;
    this.resultText.setVisible(false);
    this.mascot.setVisible(false);
    this.haniwa.setVisible(false);
    this.background.setAlpha(0.13);

    switch (index) {
      case 0:
        this.courier = {
          player: { x: 150, y: 300 },
          enemy: { x: 800, y: 300 },
          target: this.randomArenaPoint(),
          score: 0,
        };
        break;
      case 1:
        this.breaker = {
          paddleX: 418,
          ball: { x: 480, y: 405 },
          velocity: { x: 235, y: -245 },
          bricks: Array(50).fill(true) as boolean[],
          score: 0,
          lives: 3,
        };
        break;
      case 2:
        this.tap = {
          target: this.randomArenaPoint(75),
          decoy: this.randomArenaPoint(75),
          score: 0,
          timeLeft: 30,
          decoyClock: 0,
        };
        this.separateTapTargets();
        break;
      case 3:
        this.flap = {
          playerY: 280,
          velocityY: 0,
          gates: [],
          score: 0,
          spawnClock: 0.6,
        };
        break;
      case 4:
        this.dash = {
          playerY: 442,
          velocityY: 0,
          grounded: true,
          obstacles: [],
          spawnClock: 0.7,
        };
        break;
      case 5:
        this.orbit = {
          player: { x: 480, y: 300 },
          enemies: [],
          spawnClock: 0.5,
          pulseCooldown: 0,
          cleared: 0,
        };
        break;
      case 6:
        this.snake = {
          parts: [
            { x: 7, y: 8 },
            { x: 6, y: 8 },
            { x: 5, y: 8 },
          ],
          direction: { x: 1, y: 0 },
          nextDirection: { x: 1, y: 0 },
          food: { x: 18, y: 8 },
          stepClock: 0,
          score: 0,
        };
        this.placeSnakeFood();
        break;
    }
    this.drawGame();
  }

  private finish(won: boolean): void {
    if (this.ended) return;
    this.ended = true;
    this.won = won;
    this.resultText
      .setText(
        `${won ? "MISSION COMPLETE!" : "TRY AGAIN!"}\n${GAMES[this.mode].title}\n\nENTER / TAP TO REPLAY   |   ESC MENU`,
      )
      .setVisible(true);
  }

  private movement(speed: number, delta: number): Point {
    let x = 0;
    let y = 0;
    if (this.keys.left.isDown || this.keys.a.isDown) x -= 1;
    if (this.keys.right.isDown || this.keys.d.isDown) x += 1;
    if (this.keys.up.isDown || this.keys.w.isDown) y -= 1;
    if (this.keys.down.isDown || this.keys.s.isDown) y += 1;
    const length = Math.hypot(x, y) || 1;
    return { x: (x / length) * speed * delta, y: (y / length) * speed * delta };
  }

  private updateCourier(delta: number): void {
    const move = this.movement(270, delta);
    this.courier.player.x = Phaser.Math.Clamp(
      this.courier.player.x + move.x,
      28,
      WIDTH - 28,
    );
    this.courier.player.y = Phaser.Math.Clamp(
      this.courier.player.y + move.y,
      TOP + 28,
      BOTTOM - 28,
    );

    const dx = this.courier.player.x - this.courier.enemy.x;
    const dy = this.courier.player.y - this.courier.enemy.y;
    const distance = Math.hypot(dx, dy) || 1;
    const enemySpeed = 105 + this.courier.score * 8;
    this.courier.enemy.x += (dx / distance) * enemySpeed * delta;
    this.courier.enemy.y += (dy / distance) * enemySpeed * delta;

    if (distance < 43) this.finish(false);
    if (this.distance(this.courier.player, this.courier.target) < 40) {
      this.courier.score += 1;
      if (this.courier.score >= 8) this.finish(true);
      else this.courier.target = this.randomArenaPoint();
    }
    if (this.elapsed >= 45) this.finish(false);
  }

  private updateBreaker(delta: number): void {
    let direction = 0;
    if (this.keys.left.isDown || this.keys.a.isDown) direction -= 1;
    if (this.keys.right.isDown || this.keys.d.isDown) direction += 1;
    this.breaker.paddleX = Phaser.Math.Clamp(
      this.breaker.paddleX + direction * 430 * delta,
      20,
      WIDTH - 144,
    );
    const ball = this.breaker.ball;
    const velocity = this.breaker.velocity;
    ball.x += velocity.x * delta;
    ball.y += velocity.y * delta;
    if (ball.x < 12 || ball.x > WIDTH - 12) {
      velocity.x *= -1;
      ball.x = Phaser.Math.Clamp(ball.x, 12, WIDTH - 12);
    }
    if (ball.y < TOP + 10) {
      velocity.y = Math.abs(velocity.y);
      ball.y = TOP + 10;
    }
    if (
      velocity.y > 0 &&
      ball.y + 12 >= 480 &&
      ball.y < 505 &&
      ball.x >= this.breaker.paddleX &&
      ball.x <= this.breaker.paddleX + 144
    ) {
      const offset = (ball.x - (this.breaker.paddleX + 72)) / 72;
      velocity.x = offset * 340;
      velocity.y = -Math.abs(velocity.y);
      ball.y = 468;
    }

    for (let index = 0; index < this.breaker.bricks.length; index += 1) {
      if (!this.breaker.bricks[index]) continue;
      const column = index % 10;
      const row = Math.floor(index / 10);
      const x = 45 + column * 88;
      const y = 90 + row * 36;
      if (
        ball.x + 11 > x &&
        ball.x - 11 < x + 78 &&
        ball.y + 11 > y &&
        ball.y - 11 < y + 25
      ) {
        this.breaker.bricks[index] = false;
        this.breaker.score += 1;
        velocity.y *= -1;
        if (this.breaker.score >= 50) this.finish(true);
        break;
      }
    }

    if (ball.y > HEIGHT + 20) {
      this.breaker.lives -= 1;
      if (this.breaker.lives <= 0) this.finish(false);
      else {
        ball.x = 480;
        ball.y = 405;
        velocity.x = 235;
        velocity.y = -245;
      }
    }
  }

  private updateTap(delta: number): void {
    this.tap.timeLeft = Math.max(0, this.tap.timeLeft - delta);
    this.tap.decoyClock += delta;
    if (this.tap.decoyClock >= 1.15) {
      this.tap.decoyClock = 0;
      this.tap.decoy = this.randomArenaPoint(76);
      this.separateTapTargets();
    }
    if (this.tap.timeLeft <= 0) this.finish(false);
  }

  private handleTap(x: number, y: number): void {
    if (this.distance({ x, y }, this.tap.target) <= 48) {
      this.tap.score += 1;
      if (this.tap.score >= 12) this.finish(true);
      else {
        this.tap.target = this.randomArenaPoint(76);
        this.separateTapTargets();
      }
    } else if (this.distance({ x, y }, this.tap.decoy) <= 51) {
      this.tap.timeLeft = Math.max(0, this.tap.timeLeft - 3);
      this.tap.decoy = this.randomArenaPoint(76);
      this.separateTapTargets();
    }
  }

  private separateTapTargets(): void {
    let attempts = 0;
    while (this.distance(this.tap.target, this.tap.decoy) < 170 && attempts < 20) {
      this.tap.decoy = this.randomArenaPoint(76);
      attempts += 1;
    }
  }

  private flapBird(): void {
    this.flap.velocityY = -390;
  }

  private updateFlap(delta: number): void {
    if (
      Phaser.Input.Keyboard.JustDown(this.keys.space) ||
      Phaser.Input.Keyboard.JustDown(this.keys.up) ||
      Phaser.Input.Keyboard.JustDown(this.keys.w)
    ) {
      this.flapBird();
    }
    this.flap.velocityY += 980 * delta;
    this.flap.playerY += this.flap.velocityY * delta;
    this.flap.spawnClock += delta;
    if (this.flap.spawnClock >= 1.5) {
      this.flap.spawnClock = 0;
      this.flap.gates.push({
        x: WIDTH + 45,
        gapY: Phaser.Math.Between(185, 390),
        counted: false,
      });
    }
    for (const gate of this.flap.gates) {
      gate.x -= 210 * delta;
      const withinX = 170 + 25 > gate.x - 30 && 170 - 25 < gate.x + 30;
      const outsideGap =
        this.flap.playerY - 23 < gate.gapY - 82 ||
        this.flap.playerY + 23 > gate.gapY + 82;
      if (withinX && outsideGap) {
        this.finish(false);
        return;
      }
      if (!gate.counted && gate.x + 30 < 170 - 25) {
        gate.counted = true;
        this.flap.score += 1;
        if (this.flap.score >= 10) this.finish(true);
      }
    }
    this.flap.gates = this.flap.gates.filter((gate) => gate.x > -60);
    if (this.flap.playerY < TOP + 22 || this.flap.playerY > BOTTOM - 22) {
      this.finish(false);
    }
  }

  private jump(): void {
    if (this.dash.grounded) {
      this.dash.velocityY = -520;
      this.dash.grounded = false;
    }
  }

  private updateDash(delta: number): void {
    if (
      Phaser.Input.Keyboard.JustDown(this.keys.space) ||
      Phaser.Input.Keyboard.JustDown(this.keys.up) ||
      Phaser.Input.Keyboard.JustDown(this.keys.w)
    ) {
      this.jump();
    }
    this.dash.velocityY += 1150 * delta;
    this.dash.playerY += this.dash.velocityY * delta;
    if (this.dash.playerY >= 442) {
      this.dash.playerY = 442;
      this.dash.velocityY = 0;
      this.dash.grounded = true;
    }
    this.dash.spawnClock += delta;
    const spawnDelay = Math.max(0.82, 1.32 - this.elapsed * 0.008);
    if (this.dash.spawnClock >= spawnDelay) {
      this.dash.spawnClock = 0;
      this.dash.obstacles.push({
        x: WIDTH + 50,
        width: Phaser.Math.Between(38, 58),
        height: Phaser.Math.Between(48, 82),
      });
    }
    const speed = 300 + this.elapsed * 5;
    for (const obstacle of this.dash.obstacles) {
      obstacle.x -= speed * delta;
      const playerLeft = 145;
      const playerRight = 195;
      const playerTop = this.dash.playerY - 52;
      const obstacleLeft = obstacle.x;
      const obstacleTop = 492 - obstacle.height;
      if (
        playerRight > obstacleLeft &&
        playerLeft < obstacleLeft + obstacle.width &&
        this.dash.playerY > obstacleTop &&
        playerTop < 492
      ) {
        this.finish(false);
      }
    }
    this.dash.obstacles = this.dash.obstacles.filter(
      (obstacle) => obstacle.x > -80,
    );
    if (this.elapsed >= 30) this.finish(true);
  }

  private updateOrbit(delta: number): void {
    const move = this.movement(265, delta);
    this.orbit.player.x = Phaser.Math.Clamp(
      this.orbit.player.x + move.x,
      45,
      WIDTH - 45,
    );
    this.orbit.player.y = Phaser.Math.Clamp(
      this.orbit.player.y + move.y,
      TOP + 45,
      BOTTOM - 45,
    );
    this.orbit.spawnClock += delta;
    this.orbit.pulseCooldown = Math.max(0, this.orbit.pulseCooldown - delta);
    this.pulseFlash = Math.max(0, this.pulseFlash - delta);

    if (this.orbit.spawnClock >= Math.max(0.38, 0.85 - this.elapsed * 0.012)) {
      this.orbit.spawnClock = 0;
      this.orbit.enemies.push(this.spawnEnemy());
    }
    if (
      Phaser.Input.Keyboard.JustDown(this.keys.space) &&
      this.orbit.pulseCooldown <= 0
    ) {
      this.orbit.pulseCooldown = 0.58;
      this.pulseFlash = 0.16;
      const before = this.orbit.enemies.length;
      this.orbit.enemies = this.orbit.enemies.filter(
        (enemy) => this.distance(enemy, this.orbit.player) > 118,
      );
      this.orbit.cleared += before - this.orbit.enemies.length;
    }

    for (const enemy of this.orbit.enemies) {
      const dx = this.orbit.player.x - enemy.x;
      const dy = this.orbit.player.y - enemy.y;
      const length = Math.hypot(dx, dy) || 1;
      enemy.x += (dx / length) * enemy.speed * delta;
      enemy.y += (dy / length) * enemy.speed * delta;
      if (length < 35) this.finish(false);
    }
    if (this.elapsed >= 30) this.finish(true);
  }

  private updateSnake(delta: number): void {
    const current = this.snake.direction;
    if (
      (Phaser.Input.Keyboard.JustDown(this.keys.up) ||
        Phaser.Input.Keyboard.JustDown(this.keys.w)) &&
      current.y === 0
    ) {
      this.snake.nextDirection = { x: 0, y: -1 };
    } else if (
      (Phaser.Input.Keyboard.JustDown(this.keys.down) ||
        Phaser.Input.Keyboard.JustDown(this.keys.s)) &&
      current.y === 0
    ) {
      this.snake.nextDirection = { x: 0, y: 1 };
    } else if (
      (Phaser.Input.Keyboard.JustDown(this.keys.left) ||
        Phaser.Input.Keyboard.JustDown(this.keys.a)) &&
      current.x === 0
    ) {
      this.snake.nextDirection = { x: -1, y: 0 };
    } else if (
      (Phaser.Input.Keyboard.JustDown(this.keys.right) ||
        Phaser.Input.Keyboard.JustDown(this.keys.d)) &&
      current.x === 0
    ) {
      this.snake.nextDirection = { x: 1, y: 0 };
    }
    this.snake.stepClock += delta;
    const interval = this.snake.score >= 8 ? 0.095 : 0.125;
    if (this.snake.stepClock < interval) return;
    this.snake.stepClock = 0;
    this.snake.direction = this.snake.nextDirection;
    const head = {
      x: this.snake.parts[0].x + this.snake.direction.x,
      y: this.snake.parts[0].y + this.snake.direction.y,
    };
    const willEat = head.x === this.snake.food.x && head.y === this.snake.food.y;
    const collisionBody = willEat
      ? this.snake.parts
      : this.snake.parts.slice(0, -1);
    if (
      head.x < 0 ||
      head.x >= 25 ||
      head.y < 0 ||
      head.y >= 16 ||
      collisionBody.some((part) => part.x === head.x && part.y === head.y)
    ) {
      this.finish(false);
      return;
    }
    this.snake.parts.unshift(head);
    if (willEat) {
      this.snake.score += 1;
      if (this.snake.score >= 15) this.finish(true);
      else this.placeSnakeFood();
    } else {
      this.snake.parts.pop();
    }
  }

  private placeSnakeFood(): void {
    let candidate: Point;
    do {
      candidate = {
        x: Phaser.Math.Between(0, 24),
        y: Phaser.Math.Between(0, 15),
      };
    } while (
      this.snake.parts.some(
        (part) => part.x === candidate.x && part.y === candidate.y,
      )
    );
    this.snake.food = candidate;
  }

  private drawGame(): void {
    this.graphics.clear();
    this.drawGrid(0.05);
    this.graphics.fillStyle(0x080513, 0.88);
    this.graphics.fillRect(0, 0, WIDTH, TOP);
    this.graphics.lineStyle(2, 0xe879f9, 0.45);
    this.graphics.lineBetween(0, TOP, WIDTH, TOP);
    this.titleText
      .setPosition(22, 17)
      .setFontSize(23)
      .setText(this.gameHud())
      .setColor("#fff3b0");
    this.bodyText.setText("");
    this.footerText.setText(`${GAMES[this.mode].controls}   |   ESC MENU`);

    switch (this.mode) {
      case 0:
        this.drawCourier();
        break;
      case 1:
        this.drawBreaker();
        break;
      case 2:
        this.drawTap();
        break;
      case 3:
        this.drawFlap();
        break;
      case 4:
        this.drawDash();
        break;
      case 5:
        this.drawOrbit();
        break;
      case 6:
        this.drawSnake();
        break;
    }
  }

  private gameHud(): string {
    switch (this.mode) {
      case 0:
        return `KOFUN COURIER    HANIWA ${this.courier.score}/8    TIME ${Math.max(0, 45 - this.elapsed).toFixed(1)}`;
      case 1:
        return `MOUND BREAKER    BLOCKS ${this.breaker.score}/50    LIVES ${this.breaker.lives}`;
      case 2:
        return `HANIWA TAP PATROL    SCORE ${this.tap.score}/12    TIME ${this.tap.timeLeft.toFixed(1)}`;
      case 3:
        return `DOCHICKEN SKY DODGE    GATES ${this.flap.score}/10`;
      case 4:
        return `NEON KOFUN DASH    TIME ${Math.min(30, this.elapsed).toFixed(1)}/30.0`;
      case 5:
        return `KOFUN ORBIT    TIME ${Math.min(30, this.elapsed).toFixed(1)}/30.0    CLEARED ${this.orbit.cleared}`;
      case 6:
        return `KOFUN SNAKE    HANIWA ${this.snake.score}/15`;
      default:
        return "";
    }
  }

  private drawCourier(): void {
    this.drawArenaBorder();
    this.drawHaniwa(this.courier.target.x, this.courier.target.y, 25);
    this.drawKofun(this.courier.player.x, this.courier.player.y, 27);
    this.drawDochicken(this.courier.enemy.x, this.courier.enemy.y, 28);
  }

  private drawBreaker(): void {
    const colors = [0xf472b6, 0xfb923c, 0xfacc15, 0x4ade80, 0x60a5fa];
    this.breaker.bricks.forEach((active, index) => {
      if (!active) return;
      const column = index % 10;
      const row = Math.floor(index / 10);
      this.graphics.fillStyle(colors[row], 0.92);
      this.graphics.fillRoundedRect(45 + column * 88, 90 + row * 36, 78, 25, 5);
    });
    this.graphics.fillStyle(0x5b376f, 1);
    this.graphics.fillRoundedRect(this.breaker.paddleX, 480, 144, 22, 9);
    this.drawKofun(this.breaker.paddleX + 72, 474, 23);
    this.graphics.fillStyle(0xfff3b0, 1);
    this.graphics.fillCircle(this.breaker.ball.x, this.breaker.ball.y, 11);
  }

  private drawTap(): void {
    this.drawArenaBorder();
    this.graphics.lineStyle(3, 0x34d399, 0.45);
    this.graphics.strokeCircle(this.tap.target.x, this.tap.target.y, 50);
    this.drawHaniwa(this.tap.target.x, this.tap.target.y, 35);
    this.graphics.lineStyle(3, 0xfb7185, 0.4);
    this.graphics.strokeCircle(this.tap.decoy.x, this.tap.decoy.y, 52);
    this.drawDochicken(this.tap.decoy.x, this.tap.decoy.y, 37);
  }

  private drawFlap(): void {
    for (const gate of this.flap.gates) {
      this.graphics.fillStyle(0x8b5cf6, 0.88);
      this.graphics.fillRoundedRect(gate.x - 30, TOP, 60, gate.gapY - 82 - TOP, 8);
      this.graphics.fillRoundedRect(
        gate.x - 30,
        gate.gapY + 82,
        60,
        BOTTOM - gate.gapY - 82,
        8,
      );
      this.graphics.fillStyle(0xc4b5fd, 0.9);
      this.graphics.fillRect(gate.x - 38, gate.gapY - 92, 76, 12);
      this.graphics.fillRect(gate.x - 38, gate.gapY + 80, 76, 12);
    }
    this.drawKofun(170, this.flap.playerY, 27);
  }

  private drawDash(): void {
    this.graphics.fillStyle(0x100724, 0.95);
    this.graphics.fillRect(0, 492, WIDTH, 48);
    this.graphics.lineStyle(4, 0xec4899, 0.85);
    this.graphics.lineBetween(0, 492, WIDTH, 492);
    for (const obstacle of this.dash.obstacles) {
      this.graphics.fillStyle(0xfb7185, 0.88);
      this.graphics.fillRoundedRect(
        obstacle.x,
        492 - obstacle.height,
        obstacle.width,
        obstacle.height,
        5,
      );
      this.drawDochicken(
        obstacle.x + obstacle.width / 2,
        482 - obstacle.height,
        Math.min(20, obstacle.width / 2),
      );
    }
    this.drawKofun(170, this.dash.playerY, 28);
  }

  private drawOrbit(): void {
    this.drawArenaBorder();
    if (this.pulseFlash > 0) {
      this.graphics.lineStyle(8, 0x67e8f9, this.pulseFlash / 0.16);
      this.graphics.strokeCircle(
        this.orbit.player.x,
        this.orbit.player.y,
        118 * (1 - this.pulseFlash / 0.32),
      );
    }
    for (const enemy of this.orbit.enemies) {
      this.drawDochicken(enemy.x, enemy.y, 20);
    }
    this.drawKofun(this.orbit.player.x, this.orbit.player.y, 27);
    const ready = 1 - this.orbit.pulseCooldown / 0.58;
    this.graphics.fillStyle(0x172554, 0.9);
    this.graphics.fillRoundedRect(380, 75, 200, 9, 4);
    this.graphics.fillStyle(0x67e8f9, 0.9);
    this.graphics.fillRoundedRect(380, 75, 200 * ready, 9, 4);
  }

  private drawSnake(): void {
    const left = 55;
    const top = 79;
    const cell = 34;
    for (let y = 0; y < 16; y += 1) {
      for (let x = 0; x < 25; x += 1) {
        this.graphics.fillStyle((x + y) % 2 ? 0x160d2d : 0x1c1237, 0.95);
        this.graphics.fillRect(left + x * cell, top + y * 27, cell - 1, 26);
      }
    }
    this.snake.parts.forEach((part, index) => {
      const x = left + part.x * cell + cell / 2;
      const y = top + part.y * 27 + 13;
      if (index === 0) this.drawKofun(x, y, 15);
      else {
        this.graphics.fillStyle(index % 2 ? 0xa78bfa : 0xc084fc, 0.95);
        this.graphics.fillRoundedRect(x - 12, y - 10, 24, 20, 6);
      }
    });
    this.drawHaniwa(
      left + this.snake.food.x * cell + cell / 2,
      top + this.snake.food.y * 27 + 13,
      13,
    );
  }

  private drawGrid(alpha: number): void {
    this.graphics.lineStyle(1, 0x8b5cf6, alpha);
    for (let x = 0; x <= WIDTH; x += 40) this.graphics.lineBetween(x, 0, x, HEIGHT);
    for (let y = 0; y <= HEIGHT; y += 40) this.graphics.lineBetween(0, y, WIDTH, y);
  }

  private drawArenaBorder(): void {
    this.graphics.fillStyle(0x110a25, 0.55);
    this.graphics.fillRoundedRect(20, TOP + 15, WIDTH - 40, BOTTOM - TOP - 30, 16);
    this.graphics.lineStyle(2, 0xa78bfa, 0.55);
    this.graphics.strokeRoundedRect(20, TOP + 15, WIDTH - 40, BOTTOM - TOP - 30, 16);
  }

  private drawKofun(x: number, y: number, radius: number): void {
    this.graphics.fillStyle(0x8b5a3c, 1);
    this.graphics.fillCircle(x, y, radius);
    this.graphics.fillStyle(0xc08457, 1);
    this.graphics.fillCircle(x, y - radius * 0.18, radius * 0.72);
    this.graphics.fillStyle(0x1f1726, 1);
    this.graphics.fillCircle(x - radius * 0.28, y - radius * 0.2, radius * 0.09);
    this.graphics.fillCircle(x + radius * 0.28, y - radius * 0.2, radius * 0.09);
    this.graphics.lineStyle(2, 0x1f1726, 1);
    this.graphics.arc(x, y + radius * 0.02, radius * 0.28, 0.15, Math.PI - 0.15);
  }

  private drawDochicken(x: number, y: number, radius: number): void {
    this.graphics.fillStyle(0xf8fafc, 1);
    this.graphics.fillCircle(x, y, radius);
    this.graphics.fillStyle(0xfb7185, 1);
    this.graphics.fillTriangle(
      x + radius * 0.65,
      y - 3,
      x + radius * 1.2,
      y + 3,
      x + radius * 0.65,
      y + 9,
    );
    this.graphics.fillStyle(0x111827, 1);
    this.graphics.fillCircle(x + radius * 0.25, y - radius * 0.25, radius * 0.09);
    this.graphics.fillStyle(0xef4444, 1);
    this.graphics.fillCircle(x - radius * 0.15, y - radius * 0.88, radius * 0.22);
  }

  private drawHaniwa(x: number, y: number, radius: number): void {
    this.graphics.fillStyle(0xf5d0a9, 1);
    this.graphics.fillRoundedRect(
      x - radius * 0.62,
      y - radius,
      radius * 1.24,
      radius * 2,
      radius * 0.4,
    );
    this.graphics.fillStyle(0x4b2e2a, 1);
    this.graphics.fillCircle(x - radius * 0.23, y - radius * 0.28, radius * 0.1);
    this.graphics.fillCircle(x + radius * 0.23, y - radius * 0.28, radius * 0.1);
    this.graphics.fillRect(x - radius * 0.13, y + radius * 0.05, radius * 0.26, 3);
  }

  private randomArenaPoint(margin = 45): Point {
    return {
      x: Phaser.Math.Between(40 + margin, WIDTH - 40 - margin),
      y: Phaser.Math.Between(TOP + margin, BOTTOM - margin),
    };
  }

  private spawnEnemy(): Enemy {
    const side = Phaser.Math.Between(0, 3);
    if (side === 0)
      return { x: 10, y: Phaser.Math.Between(90, 500), speed: 110 };
    if (side === 1)
      return { x: 950, y: Phaser.Math.Between(90, 500), speed: 110 };
    if (side === 2)
      return { x: Phaser.Math.Between(30, 930), y: 75, speed: 110 };
    return { x: Phaser.Math.Between(30, 930), y: 515, speed: 110 };
  }

  private distance(a: Point, b: Point): number {
    return Math.hypot(a.x - b.x, a.y - b.y);
  }
}

new Phaser.Game({
  // Canvas keeps the browser build usable on older integrated GPUs and in
  // headless smoke tests; none of the seven modes needs WebGL-only effects.
  type: Phaser.CANVAS,
  parent: "game",
  width: WIDTH,
  height: HEIGHT,
  backgroundColor: "#070510",
  pixelArt: true,
  render: {
    antialias: false,
    roundPixels: true,
  },
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
  },
  scene: MatrixScene,
});
