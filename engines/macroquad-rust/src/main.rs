use macroquad::prelude::*;
use std::collections::VecDeque;

const WIDTH: f32 = 960.0;
const HEIGHT: f32 = 540.0;
const HEADER: f32 = 70.0;
const BG: Color = Color::new(0.035, 0.045, 0.085, 1.0);
const PANEL: Color = Color::new(0.075, 0.09, 0.16, 1.0);
const CYAN: Color = Color::new(0.15, 0.9, 0.95, 1.0);
const PINK: Color = Color::new(1.0, 0.25, 0.58, 1.0);
const GOLD: Color = Color::new(1.0, 0.78, 0.2, 1.0);
const SOFT: Color = Color::new(0.72, 0.78, 0.9, 1.0);

fn window_conf() -> Conf {
    Conf {
        window_title: "Kofun Arcade - Macroquad".to_owned(),
        window_width: WIDTH as i32,
        window_height: HEIGHT as i32,
        high_dpi: false,
        window_resizable: false,
        ..Default::default()
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
enum ResultState {
    Playing,
    Won,
    Lost,
}

#[derive(Clone, Copy, PartialEq)]
enum Mode {
    Menu,
    Courier,
    Breaker,
    Tap,
    Sky,
    Dash,
    Orbit,
    Snake,
}

const MENU_ITEMS: [(&str, &str); 7] = [
    ("KOFUN COURIER", "Collect 8 relics before time runs out"),
    ("MOUND BREAKER", "Clear a 5 x 10 neon wall"),
    (
        "HANIWA TAP PATROL",
        "Find targets, avoid time-stealing decoys",
    ),
    ("DOCHICKEN SKY DODGE", "Flap through 10 shifting gates"),
    ("NEON KOFUN DASH", "Survive a 30 second obstacle run"),
    ("KOFUN ORBIT", "Repel the swarm and survive"),
    ("KOFUN SNAKE", "Collect 15 food on the grid"),
];

struct Courier {
    player: Vec2,
    relics: Vec<Vec2>,
    enemies: Vec<Vec2>,
    time: f32,
    state: ResultState,
}

struct Breaker {
    paddle_x: f32,
    ball: Vec2,
    velocity: Vec2,
    bricks: Vec<Rect>,
    lives: i32,
    waiting: bool,
    state: ResultState,
}

struct Tap {
    target: Vec2,
    decoys: Vec<Vec2>,
    collected: i32,
    time: f32,
    flash: f32,
    state: ResultState,
}

struct Gate {
    x: f32,
    gap_y: f32,
    passed: bool,
}

struct Sky {
    bird_y: f32,
    velocity: f32,
    gates: Vec<Gate>,
    passed: i32,
    state: ResultState,
}

struct Dash {
    y: f32,
    velocity: f32,
    obstacles: Vec<Rect>,
    spawn: f32,
    elapsed: f32,
    state: ResultState,
}

struct Enemy {
    pos: Vec2,
    speed: f32,
}

struct Orbit {
    player: Vec2,
    enemies: Vec<Enemy>,
    spawn: f32,
    elapsed: f32,
    pulse_cd: f32,
    pulse_fx: f32,
    state: ResultState,
}

struct Snake {
    body: VecDeque<(i32, i32)>,
    dir: (i32, i32),
    next_dir: (i32, i32),
    food: (i32, i32),
    timer: f32,
    eaten: i32,
    state: ResultState,
}

struct Arcade {
    mode: Mode,
    selected: usize,
    courier: Courier,
    breaker: Breaker,
    tap: Tap,
    sky: Sky,
    dash: Dash,
    orbit: Orbit,
    snake: Snake,
}

fn random_point(margin: f32) -> Vec2 {
    vec2(
        rand::gen_range(margin, WIDTH - margin),
        rand::gen_range(HEADER + margin, HEIGHT - margin),
    )
}

fn reset_courier() -> Courier {
    let mut relics = Vec::new();
    for _ in 0..8 {
        relics.push(random_point(35.0));
    }
    Courier {
        player: vec2(WIDTH / 2.0, HEIGHT / 2.0),
        relics,
        enemies: vec![vec2(780.0, 300.0)],
        time: 45.0,
        state: ResultState::Playing,
    }
}

fn reset_breaker() -> Breaker {
    let mut bricks = Vec::new();
    for row in 0..5 {
        for col in 0..10 {
            bricks.push(Rect::new(
                65.0 + col as f32 * 84.0,
                100.0 + row as f32 * 35.0,
                76.0,
                25.0,
            ));
        }
    }
    Breaker {
        paddle_x: WIDTH / 2.0 - 55.0,
        ball: vec2(WIDTH / 2.0, 440.0),
        velocity: vec2(240.0, -270.0),
        bricks,
        lives: 3,
        waiting: true,
        state: ResultState::Playing,
    }
}

fn new_tap_positions() -> (Vec2, Vec<Vec2>) {
    let target = random_point(55.0);
    let mut decoys = Vec::new();
    while decoys.len() < 3 {
        let candidate = random_point(55.0);
        if candidate.distance(target) > 100.0
            && decoys
                .iter()
                .all(|existing: &Vec2| existing.distance(candidate) > 75.0)
        {
            decoys.push(candidate);
        }
    }
    (target, decoys)
}

fn reset_tap() -> Tap {
    let (target, decoys) = new_tap_positions();
    Tap {
        target,
        decoys,
        collected: 0,
        time: 30.0,
        flash: 0.0,
        state: ResultState::Playing,
    }
}

fn reset_sky() -> Sky {
    Sky {
        bird_y: HEIGHT / 2.0,
        velocity: 0.0,
        gates: vec![
            Gate {
                x: 700.0,
                gap_y: 230.0,
                passed: false,
            },
            Gate {
                x: 1030.0,
                gap_y: 340.0,
                passed: false,
            },
            Gate {
                x: 1360.0,
                gap_y: 190.0,
                passed: false,
            },
        ],
        passed: 0,
        state: ResultState::Playing,
    }
}

fn reset_dash() -> Dash {
    Dash {
        y: 425.0,
        velocity: 0.0,
        obstacles: Vec::new(),
        spawn: 1.3,
        elapsed: 0.0,
        state: ResultState::Playing,
    }
}

fn reset_orbit() -> Orbit {
    Orbit {
        player: vec2(WIDTH / 2.0, HEIGHT / 2.0),
        enemies: Vec::new(),
        spawn: 0.7,
        elapsed: 0.0,
        pulse_cd: 0.0,
        pulse_fx: 0.0,
        state: ResultState::Playing,
    }
}

fn random_food(body: &VecDeque<(i32, i32)>) -> (i32, i32) {
    loop {
        let food = (rand::gen_range(0, 30), rand::gen_range(0, 16));
        if !body.contains(&food) {
            return food;
        }
    }
}

fn reset_snake() -> Snake {
    let body = VecDeque::from([(10, 8), (9, 8), (8, 8), (7, 8)]);
    let food = random_food(&body);
    Snake {
        body,
        dir: (1, 0),
        next_dir: (1, 0),
        food,
        timer: 0.0,
        eaten: 0,
        state: ResultState::Playing,
    }
}

impl Arcade {
    fn new() -> Self {
        Self {
            mode: Mode::Menu,
            selected: 0,
            courier: reset_courier(),
            breaker: reset_breaker(),
            tap: reset_tap(),
            sky: reset_sky(),
            dash: reset_dash(),
            orbit: reset_orbit(),
            snake: reset_snake(),
        }
    }

    fn start(&mut self, index: usize) {
        self.selected = index.min(6);
        self.mode = match self.selected {
            0 => {
                self.courier = reset_courier();
                Mode::Courier
            }
            1 => {
                self.breaker = reset_breaker();
                Mode::Breaker
            }
            2 => {
                self.tap = reset_tap();
                Mode::Tap
            }
            3 => {
                self.sky = reset_sky();
                Mode::Sky
            }
            4 => {
                self.dash = reset_dash();
                Mode::Dash
            }
            5 => {
                self.orbit = reset_orbit();
                Mode::Orbit
            }
            _ => {
                self.snake = reset_snake();
                Mode::Snake
            }
        };
    }

    fn restart(&mut self) {
        let index = match self.mode {
            Mode::Courier => 0,
            Mode::Breaker => 1,
            Mode::Tap => 2,
            Mode::Sky => 3,
            Mode::Dash => 4,
            Mode::Orbit => 5,
            Mode::Snake => 6,
            Mode::Menu => return,
        };
        self.start(index);
    }

    fn is_finished(&self) -> bool {
        match self.mode {
            Mode::Courier => self.courier.state != ResultState::Playing,
            Mode::Breaker => self.breaker.state != ResultState::Playing,
            Mode::Tap => self.tap.state != ResultState::Playing,
            Mode::Sky => self.sky.state != ResultState::Playing,
            Mode::Dash => self.dash.state != ResultState::Playing,
            Mode::Orbit => self.orbit.state != ResultState::Playing,
            Mode::Snake => self.snake.state != ResultState::Playing,
            Mode::Menu => false,
        }
    }

    fn update(&mut self, dt: f32) {
        if is_key_pressed(KeyCode::Escape) {
            self.mode = Mode::Menu;
            return;
        }
        if self.mode != Mode::Menu
            && (is_key_pressed(KeyCode::R)
                || (self.is_finished() && is_key_pressed(KeyCode::Enter)))
        {
            self.restart();
            return;
        }
        match self.mode {
            Mode::Menu => self.update_menu(),
            Mode::Courier => update_courier(&mut self.courier, dt),
            Mode::Breaker => update_breaker(&mut self.breaker, dt),
            Mode::Tap => update_tap(&mut self.tap, dt),
            Mode::Sky => update_sky(&mut self.sky, dt),
            Mode::Dash => update_dash(&mut self.dash, dt),
            Mode::Orbit => update_orbit(&mut self.orbit, dt),
            Mode::Snake => update_snake(&mut self.snake, dt),
        }
    }

    fn update_menu(&mut self) {
        if is_key_pressed(KeyCode::Up) || is_key_pressed(KeyCode::W) {
            self.selected = (self.selected + 6) % 7;
        }
        if is_key_pressed(KeyCode::Down) || is_key_pressed(KeyCode::S) {
            self.selected = (self.selected + 1) % 7;
        }
        let number_keys = [
            KeyCode::Key1,
            KeyCode::Key2,
            KeyCode::Key3,
            KeyCode::Key4,
            KeyCode::Key5,
            KeyCode::Key6,
            KeyCode::Key7,
        ];
        for (index, key) in number_keys.iter().enumerate() {
            if is_key_pressed(*key) {
                self.start(index);
                return;
            }
        }
        if is_key_pressed(KeyCode::Enter) || is_key_pressed(KeyCode::Space) {
            self.start(self.selected);
        }
    }

    fn draw(&self) {
        match self.mode {
            Mode::Menu => draw_menu(self.selected),
            Mode::Courier => draw_courier(&self.courier),
            Mode::Breaker => draw_breaker(&self.breaker),
            Mode::Tap => draw_tap(&self.tap),
            Mode::Sky => draw_sky(&self.sky),
            Mode::Dash => draw_dash(&self.dash),
            Mode::Orbit => draw_orbit(&self.orbit),
            Mode::Snake => draw_snake(&self.snake),
        }
    }
}

fn movement() -> Vec2 {
    let mut direction = Vec2::ZERO;
    if is_key_down(KeyCode::Left) || is_key_down(KeyCode::A) {
        direction.x -= 1.0;
    }
    if is_key_down(KeyCode::Right) || is_key_down(KeyCode::D) {
        direction.x += 1.0;
    }
    if is_key_down(KeyCode::Up) || is_key_down(KeyCode::W) {
        direction.y -= 1.0;
    }
    if is_key_down(KeyCode::Down) || is_key_down(KeyCode::S) {
        direction.y += 1.0;
    }
    direction.normalize_or_zero()
}

fn pointer_pressed() -> bool {
    is_mouse_button_pressed(MouseButton::Left)
        || touches()
            .iter()
            .any(|touch| touch.phase == TouchPhase::Started)
}

fn update_courier(game: &mut Courier, dt: f32) {
    if game.state != ResultState::Playing {
        return;
    }
    game.time = (game.time - dt).max(0.0);
    game.player += movement() * 235.0 * dt;
    game.player.x = game.player.x.clamp(18.0, WIDTH - 18.0);
    game.player.y = game.player.y.clamp(HEADER + 18.0, HEIGHT - 18.0);
    game.relics
        .retain(|relic| relic.distance(game.player) > 28.0);
    let enemy_speed = 105.0 + (8 - game.relics.len()) as f32 * 8.0;
    for position in &mut game.enemies {
        *position += (game.player - *position).normalize_or_zero() * enemy_speed * dt;
        if position.distance(game.player) < 30.0 {
            game.state = ResultState::Lost;
        }
    }
    if game.state == ResultState::Playing && game.relics.is_empty() {
        game.state = ResultState::Won;
    } else if game.state == ResultState::Playing && game.time <= 0.0 {
        game.time = 0.0;
        game.state = ResultState::Lost;
    }
}

fn update_breaker(game: &mut Breaker, dt: f32) {
    if game.state != ResultState::Playing {
        return;
    }
    let mut direction = 0.0;
    if is_key_down(KeyCode::Left) || is_key_down(KeyCode::A) {
        direction -= 1.0;
    }
    if is_key_down(KeyCode::Right) || is_key_down(KeyCode::D) {
        direction += 1.0;
    }
    game.paddle_x = (game.paddle_x + direction * 430.0 * dt).clamp(0.0, WIDTH - 110.0);
    if game.waiting {
        game.ball = vec2(game.paddle_x + 55.0, 440.0);
        if is_key_pressed(KeyCode::Space) {
            game.waiting = false;
        }
        return;
    }
    game.ball += game.velocity * dt;
    if game.ball.x < 9.0 || game.ball.x > WIDTH - 9.0 {
        game.velocity.x *= -1.0;
        game.ball.x = game.ball.x.clamp(9.0, WIDTH - 9.0);
    }
    if game.ball.y < HEADER + 9.0 {
        game.velocity.y = game.velocity.y.abs();
    }
    let paddle = Rect::new(game.paddle_x, 462.0, 110.0, 16.0);
    if game.velocity.y > 0.0 && circle_rect(game.ball, 9.0, paddle) {
        let offset = (game.ball.x - (game.paddle_x + 55.0)) / 55.0;
        game.velocity = vec2(offset * 330.0, -game.velocity.y.abs()).normalize() * 370.0;
        game.ball.y = 451.0;
    }
    if let Some(index) = game
        .bricks
        .iter()
        .position(|brick| circle_rect(game.ball, 9.0, *brick))
    {
        game.bricks.swap_remove(index);
        game.velocity.y *= -1.0;
    }
    if game.bricks.is_empty() {
        game.state = ResultState::Won;
    } else if game.ball.y > HEIGHT + 10.0 {
        game.lives -= 1;
        if game.lives <= 0 {
            game.state = ResultState::Lost;
        } else {
            game.waiting = true;
            game.velocity = vec2(240.0, -270.0);
        }
    }
}

fn circle_rect(center: Vec2, radius: f32, rect: Rect) -> bool {
    let closest = vec2(
        center.x.clamp(rect.x, rect.x + rect.w),
        center.y.clamp(rect.y, rect.y + rect.h),
    );
    center.distance_squared(closest) < radius * radius
}

fn update_tap(game: &mut Tap, dt: f32) {
    if game.state != ResultState::Playing {
        return;
    }
    game.time -= dt;
    game.flash = (game.flash - dt).max(0.0);
    if is_mouse_button_pressed(MouseButton::Left) {
        let mouse = Vec2::from(mouse_position());
        if mouse.distance(game.target) <= 31.0 {
            game.collected += 1;
            let (target, decoys) = new_tap_positions();
            game.target = target;
            game.decoys = decoys;
        } else if game
            .decoys
            .iter()
            .any(|decoy| mouse.distance(*decoy) <= 28.0)
        {
            game.time -= 3.0;
            game.flash = 0.25;
            let (target, decoys) = new_tap_positions();
            game.target = target;
            game.decoys = decoys;
        }
    }
    if game.collected >= 12 {
        game.state = ResultState::Won;
    } else if game.time <= 0.0 {
        game.time = 0.0;
        game.state = ResultState::Lost;
    }
}

fn update_sky(game: &mut Sky, dt: f32) {
    if game.state != ResultState::Playing {
        return;
    }
    if is_key_pressed(KeyCode::Space)
        || is_key_pressed(KeyCode::Up)
        || is_key_pressed(KeyCode::W)
        || pointer_pressed()
    {
        game.velocity = -330.0;
    }
    game.velocity += 850.0 * dt;
    game.bird_y += game.velocity * dt;
    let speed = 190.0;
    let mut max_x: f32 = 0.0;
    for gate in &mut game.gates {
        gate.x -= speed * dt;
        max_x = max_x.max(gate.x);
        if !gate.passed && gate.x + 54.0 < 220.0 {
            gate.passed = true;
            game.passed += 1;
        }
        let top = Rect::new(gate.x, HEADER, 54.0, gate.gap_y - 75.0 - HEADER);
        let bottom = Rect::new(gate.x, gate.gap_y + 75.0, 54.0, HEIGHT);
        if circle_rect(vec2(220.0, game.bird_y), 15.0, top)
            || circle_rect(vec2(220.0, game.bird_y), 15.0, bottom)
        {
            game.state = ResultState::Lost;
        }
    }
    for gate in &mut game.gates {
        if gate.x < -60.0 {
            gate.x = max_x + 330.0;
            gate.gap_y = rand::gen_range(170.0, 390.0);
            gate.passed = false;
        }
    }
    if game.bird_y < HEADER + 10.0 || game.bird_y > HEIGHT - 10.0 {
        game.state = ResultState::Lost;
    }
    game.state = resolve_sky_result(game.state, game.passed);
}

fn resolve_sky_result(state: ResultState, passed: i32) -> ResultState {
    if state == ResultState::Playing && passed >= 10 {
        ResultState::Won
    } else {
        state
    }
}

fn update_dash(game: &mut Dash, dt: f32) {
    if game.state != ResultState::Playing {
        return;
    }
    game.elapsed += dt;
    let on_ground = game.y >= 425.0;
    if on_ground
        && (is_key_pressed(KeyCode::Space)
            || is_key_pressed(KeyCode::Up)
            || is_key_pressed(KeyCode::W)
            || pointer_pressed())
    {
        game.velocity = -510.0;
    }
    game.velocity += 1_250.0 * dt;
    game.y = (game.y + game.velocity * dt).min(425.0);
    if game.y >= 425.0 {
        game.velocity = 0.0;
    }
    game.spawn -= dt;
    if game.spawn <= 0.0 {
        let height = rand::gen_range(35.0, 70.0);
        game.obstacles
            .push(Rect::new(WIDTH + 20.0, 460.0 - height, 30.0, height));
        game.spawn = rand::gen_range(0.85, 1.5);
    }
    let speed = 275.0 + game.elapsed * 3.0;
    for obstacle in &mut game.obstacles {
        obstacle.x -= speed * dt;
    }
    game.obstacles.retain(|obstacle| obstacle.x > -50.0);
    let player = Rect::new(154.0, game.y, 35.0, 35.0);
    if game
        .obstacles
        .iter()
        .any(|obstacle| player.overlaps(obstacle))
    {
        game.state = ResultState::Lost;
    } else if game.elapsed >= 30.0 {
        game.elapsed = 30.0;
        game.state = ResultState::Won;
    }
}

fn spawn_orbit_enemy() -> Enemy {
    let side = rand::gen_range(0, 4);
    let pos = match side {
        0 => vec2(rand::gen_range(0.0, WIDTH), HEADER),
        1 => vec2(WIDTH, rand::gen_range(HEADER, HEIGHT)),
        2 => vec2(rand::gen_range(0.0, WIDTH), HEIGHT),
        _ => vec2(0.0, rand::gen_range(HEADER, HEIGHT)),
    };
    Enemy {
        pos,
        speed: rand::gen_range(75.0, 125.0),
    }
}

fn update_orbit(game: &mut Orbit, dt: f32) {
    if game.state != ResultState::Playing {
        return;
    }
    game.elapsed += dt;
    game.spawn -= dt;
    game.pulse_cd = (game.pulse_cd - dt).max(0.0);
    game.pulse_fx = (game.pulse_fx - dt).max(0.0);
    game.player += movement() * 220.0 * dt;
    game.player.x = game.player.x.clamp(20.0, WIDTH - 20.0);
    game.player.y = game.player.y.clamp(HEADER + 20.0, HEIGHT - 20.0);
    if game.spawn <= 0.0 {
        game.enemies.push(spawn_orbit_enemy());
        game.spawn = (0.72 - game.elapsed * 0.012).max(0.3);
    }
    if is_key_pressed(KeyCode::Space) && game.pulse_cd <= 0.0 {
        game.pulse_cd = 1.15;
        game.pulse_fx = 0.28;
        game.enemies
            .retain(|enemy| enemy.pos.distance(game.player) > 115.0);
        for enemy in &mut game.enemies {
            let delta = enemy.pos - game.player;
            if delta.length() < 210.0 {
                enemy.pos += delta.normalize_or_zero() * 115.0;
            }
        }
    }
    for enemy in &mut game.enemies {
        enemy.pos += (game.player - enemy.pos).normalize_or_zero() * enemy.speed * dt;
    }
    if game
        .enemies
        .iter()
        .any(|enemy| enemy.pos.distance(game.player) < 27.0)
    {
        game.state = ResultState::Lost;
    } else if game.state == ResultState::Playing && game.elapsed >= 30.0 {
        game.elapsed = 30.0;
        game.state = ResultState::Won;
    }
}

fn update_snake(game: &mut Snake, dt: f32) {
    if game.state != ResultState::Playing {
        return;
    }
    let requested = if is_key_pressed(KeyCode::Up) || is_key_pressed(KeyCode::W) {
        Some((0, -1))
    } else if is_key_pressed(KeyCode::Down) || is_key_pressed(KeyCode::S) {
        Some((0, 1))
    } else if is_key_pressed(KeyCode::Left) || is_key_pressed(KeyCode::A) {
        Some((-1, 0))
    } else if is_key_pressed(KeyCode::Right) || is_key_pressed(KeyCode::D) {
        Some((1, 0))
    } else {
        None
    };
    if let Some(direction) = requested {
        if direction.0 != -game.dir.0 || direction.1 != -game.dir.1 {
            game.next_dir = direction;
        }
    }
    game.timer += dt;
    if game.timer < 0.105 {
        return;
    }
    game.timer -= 0.105;
    game.dir = game.next_dir;
    let head = game.body[0];
    let new_head = (head.0 + game.dir.0, head.1 + game.dir.1);
    let hits_body = snake_hits_body(&game.body, new_head, game.food);
    if new_head.0 < 0 || new_head.0 >= 30 || new_head.1 < 0 || new_head.1 >= 16 || hits_body {
        game.state = ResultState::Lost;
        return;
    }
    game.body.push_front(new_head);
    if new_head == game.food {
        game.eaten += 1;
        game.food = random_food(&game.body);
        if game.eaten >= 15 {
            game.state = ResultState::Won;
        }
    } else {
        game.body.pop_back();
    }
}

fn snake_hits_body(body: &VecDeque<(i32, i32)>, new_head: (i32, i32), food: (i32, i32)) -> bool {
    let checked_length = if new_head == food {
        body.len()
    } else {
        body.len().saturating_sub(1)
    };
    body.iter()
        .take(checked_length)
        .any(|part| *part == new_head)
}

fn title_bar(title: &str, status: &str, help: &str) {
    draw_rectangle(0.0, 0.0, WIDTH, HEADER, PANEL);
    draw_text(title, 24.0, 31.0, 27.0, WHITE);
    draw_text(status, 24.0, 57.0, 18.0, GOLD);
    let width = measure_text(help, None, 18, 1.0).width;
    draw_text(help, WIDTH - width - 22.0, 43.0, 18.0, SOFT);
}

fn finish_overlay(state: ResultState) {
    if state == ResultState::Playing {
        return;
    }
    draw_rectangle(0.0, 0.0, WIDTH, HEIGHT, Color::new(0.01, 0.01, 0.03, 0.72));
    let label = if state == ResultState::Won {
        "MISSION COMPLETE"
    } else {
        "MISSION FAILED"
    };
    let color = if state == ResultState::Won {
        CYAN
    } else {
        PINK
    };
    let size = 42;
    let width = measure_text(label, None, size, 1.0).width;
    draw_text(label, (WIDTH - width) / 2.0, 250.0, size as f32, color);
    let hint = "ENTER / R  RESTART       ESC  MENU";
    let hint_width = measure_text(hint, None, 22, 1.0).width;
    draw_text(hint, (WIDTH - hint_width) / 2.0, 295.0, 22.0, WHITE);
}

fn draw_menu(selected: usize) {
    draw_text("KOFUN ARCADE", 60.0, 70.0, 48.0, CYAN);
    draw_text(
        "SEVEN SMALL GAMES / ONE LIGHTWEIGHT RUNTIME",
        62.0,
        100.0,
        18.0,
        SOFT,
    );
    for (index, (name, description)) in MENU_ITEMS.iter().enumerate() {
        let y = 132.0 + index as f32 * 52.0;
        let selected_now = index == selected;
        if selected_now {
            draw_rectangle(52.0, y - 28.0, 856.0, 44.0, PANEL);
            draw_rectangle(52.0, y - 28.0, 5.0, 44.0, PINK);
        }
        let color = if selected_now { WHITE } else { SOFT };
        draw_text(format!("{}", index + 1), 72.0, y, 22.0, GOLD);
        draw_text(name, 112.0, y, 24.0, color);
        draw_text(description, 340.0, y, 18.0, color);
    }
    draw_text(
        "UP / DOWN + ENTER    or    NUMBER KEY",
        60.0,
        515.0,
        19.0,
        SOFT,
    );
}

fn draw_courier(game: &Courier) {
    title_bar(
        "KOFUN COURIER",
        &format!(
            "RELICS  {}/8    TIME  {:02}",
            8 - game.relics.len(),
            game.time.ceil() as i32
        ),
        "WASD / ARROWS move  |  contact ends run",
    );
    for relic in &game.relics {
        draw_poly(relic.x, relic.y, 6, 13.0, 0.0, GOLD);
        draw_circle_lines(relic.x, relic.y, 19.0, 2.0, CYAN);
    }
    for position in &game.enemies {
        draw_circle(position.x, position.y, 16.0, PINK);
        let direction = (game.player - *position).normalize_or_zero();
        draw_line(
            position.x,
            position.y,
            position.x + direction.x * 22.0,
            position.y + direction.y * 22.0,
            3.0,
            WHITE,
        );
    }
    draw_circle(game.player.x, game.player.y, 17.0, CYAN);
    draw_circle_lines(game.player.x, game.player.y, 23.0, 3.0, CYAN);
    finish_overlay(game.state);
}

fn draw_breaker(game: &Breaker) {
    title_bar(
        "MOUND BREAKER",
        &format!(
            "BRICKS  {:02}/50    LIVES  {}",
            50 - game.bricks.len(),
            game.lives
        ),
        "A / D or arrows move  |  SPACE launch",
    );
    for (index, brick) in game.bricks.iter().enumerate() {
        let palette = [CYAN, GOLD, PINK];
        draw_rectangle(brick.x, brick.y, brick.w, brick.h, palette[index % 3]);
        draw_rectangle_lines(brick.x, brick.y, brick.w, brick.h, 2.0, WHITE);
    }
    draw_rectangle(game.paddle_x, 462.0, 110.0, 16.0, CYAN);
    draw_circle(game.ball.x, game.ball.y, 9.0, WHITE);
    if game.waiting {
        draw_text("SPACE TO LAUNCH", 385.0, 420.0, 22.0, SOFT);
    }
    finish_overlay(game.state);
}

fn draw_tap(game: &Tap) {
    if game.flash > 0.0 {
        draw_rectangle(
            0.0,
            HEADER,
            WIDTH,
            HEIGHT - HEADER,
            Color::new(0.5, 0.0, 0.12, 0.3),
        );
    }
    title_bar(
        "HANIWA TAP PATROL",
        &format!(
            "TARGETS  {}/12    TIME  {:02}",
            game.collected,
            game.time.ceil() as i32
        ),
        "CLICK cyan target  |  pink decoy -3 sec",
    );
    draw_circle(game.target.x, game.target.y, 31.0, CYAN);
    draw_circle_lines(game.target.x, game.target.y, 40.0, 3.0, WHITE);
    draw_circle(game.target.x, game.target.y, 7.0, WHITE);
    for decoy in &game.decoys {
        draw_circle(decoy.x, decoy.y, 28.0, PINK);
        draw_line(
            decoy.x - 10.0,
            decoy.y - 10.0,
            decoy.x + 10.0,
            decoy.y + 10.0,
            3.0,
            WHITE,
        );
        draw_line(
            decoy.x + 10.0,
            decoy.y - 10.0,
            decoy.x - 10.0,
            decoy.y + 10.0,
            3.0,
            WHITE,
        );
    }
    finish_overlay(game.state);
}

fn draw_sky(game: &Sky) {
    title_bar(
        "DOCHICKEN SKY DODGE",
        &format!("GATES  {}/10", game.passed.min(10)),
        "SPACE / UP / CLICK to flap",
    );
    for gate in &game.gates {
        draw_rectangle(gate.x, HEADER, 54.0, gate.gap_y - 75.0 - HEADER, PINK);
        draw_rectangle(gate.x, gate.gap_y + 75.0, 54.0, HEIGHT, PINK);
        draw_rectangle_lines(gate.x, gate.gap_y - 75.0, 54.0, 150.0, 3.0, GOLD);
    }
    draw_circle(220.0, game.bird_y, 15.0, CYAN);
    draw_triangle(
        vec2(206.0, game.bird_y),
        vec2(186.0, game.bird_y + 8.0),
        vec2(205.0, game.bird_y + 13.0),
        GOLD,
    );
    finish_overlay(game.state);
}

fn draw_dash(game: &Dash) {
    title_bar(
        "NEON KOFUN DASH",
        &format!("SURVIVE  {:.1}/30.0 SEC", game.elapsed),
        "SPACE / UP / POINTER to jump",
    );
    draw_line(0.0, 460.0, WIDTH, 460.0, 4.0, CYAN);
    for index in 0..12 {
        let x = (index as f32 * 95.0 - game.elapsed * 170.0) % (WIDTH + 95.0);
        draw_line(x, 480.0, x + 45.0, 480.0, 3.0, PANEL);
    }
    for obstacle in &game.obstacles {
        draw_rectangle(obstacle.x, obstacle.y, obstacle.w, obstacle.h, PINK);
        draw_triangle(
            vec2(obstacle.x, obstacle.y),
            vec2(obstacle.x + obstacle.w / 2.0, obstacle.y - 13.0),
            vec2(obstacle.x + obstacle.w, obstacle.y),
            GOLD,
        );
    }
    draw_rectangle(154.0, game.y, 35.0, 35.0, CYAN);
    draw_circle(180.0, game.y + 10.0, 5.0, BG);
    finish_overlay(game.state);
}

fn draw_orbit(game: &Orbit) {
    title_bar(
        "KOFUN ORBIT",
        &format!(
            "TIME  {:02}    PULSE  {}",
            (30.0 - game.elapsed).max(0.0).ceil() as i32,
            if game.pulse_cd <= 0.0 {
                "READY"
            } else {
                "WAIT"
            }
        ),
        "WASD / ARROWS move  |  SPACE pulse",
    );
    for enemy in &game.enemies {
        draw_poly(enemy.pos.x, enemy.pos.y, 6, 14.0, 0.0, PINK);
    }
    if game.pulse_fx > 0.0 {
        let radius = 45.0 + (0.28 - game.pulse_fx) * 590.0;
        draw_circle_lines(game.player.x, game.player.y, radius, 5.0, GOLD);
    }
    draw_circle(game.player.x, game.player.y, 18.0, CYAN);
    draw_circle_lines(game.player.x, game.player.y, 28.0, 3.0, CYAN);
    finish_overlay(game.state);
}

fn draw_snake(game: &Snake) {
    title_bar(
        "KOFUN SNAKE",
        &format!("FOOD  {}/15", game.eaten),
        "WASD / ARROWS steer",
    );
    let origin = vec2(120.0, 105.0);
    let cell = 24.0;
    draw_rectangle(origin.x, origin.y, 30.0 * cell, 16.0 * cell, PANEL);
    for x in 0..=30 {
        draw_line(
            origin.x + x as f32 * cell,
            origin.y,
            origin.x + x as f32 * cell,
            origin.y + 16.0 * cell,
            1.0,
            BG,
        );
    }
    for y in 0..=16 {
        draw_line(
            origin.x,
            origin.y + y as f32 * cell,
            origin.x + 30.0 * cell,
            origin.y + y as f32 * cell,
            1.0,
            BG,
        );
    }
    for (index, segment) in game.body.iter().enumerate() {
        let color = if index == 0 { WHITE } else { CYAN };
        draw_rectangle(
            origin.x + segment.0 as f32 * cell + 2.0,
            origin.y + segment.1 as f32 * cell + 2.0,
            cell - 4.0,
            cell - 4.0,
            color,
        );
    }
    draw_circle(
        origin.x + (game.food.0 as f32 + 0.5) * cell,
        origin.y + (game.food.1 as f32 + 0.5) * cell,
        9.0,
        GOLD,
    );
    finish_overlay(game.state);
}

#[macroquad::main(window_conf)]
async fn main() {
    let mut arcade = Arcade::new();
    loop {
        clear_background(BG);
        let dt = get_frame_time().min(1.0 / 20.0);
        arcade.update(dt);
        arcade.draw();
        next_frame().await;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn circle_rectangle_collision_handles_near_and_far_points() {
        let rectangle = Rect::new(10.0, 10.0, 20.0, 20.0);
        assert!(circle_rect(vec2(8.0, 20.0), 3.0, rectangle));
        assert!(!circle_rect(vec2(0.0, 0.0), 3.0, rectangle));
    }

    #[test]
    fn breaker_starts_with_required_goal_and_lives() {
        let game = reset_breaker();
        assert_eq!(game.bricks.len(), 50);
        assert_eq!(game.lives, 3);
        assert!(game.waiting);
    }

    #[test]
    fn snake_food_never_spawns_on_its_body() {
        let body = VecDeque::from([(10, 8), (9, 8), (8, 8), (7, 8)]);
        for _ in 0..100 {
            assert!(!body.contains(&random_food(&body)));
        }
    }

    #[test]
    fn snake_can_move_into_tail_cell_when_tail_will_move() {
        let body = VecDeque::from([(2, 1), (2, 2), (1, 2), (1, 1)]);
        assert!(!snake_hits_body(&body, (1, 1), (8, 8)));
        assert!(snake_hits_body(&body, (1, 1), (1, 1)));
    }

    #[test]
    fn sky_loss_is_not_overwritten_by_tenth_gate() {
        assert_eq!(resolve_sky_result(ResultState::Lost, 10), ResultState::Lost);
        assert_eq!(
            resolve_sky_result(ResultState::Playing, 10),
            ResultState::Won
        );
    }

    #[test]
    fn finished_mode_is_available_to_restart_input() {
        let mut arcade = Arcade::new();
        assert!(!arcade.is_finished());
        arcade.mode = Mode::Courier;
        arcade.courier.state = ResultState::Lost;
        assert!(arcade.is_finished());
    }
}
