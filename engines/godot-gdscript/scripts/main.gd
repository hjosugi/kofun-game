extends Node2D

const WIDTH := 960.0
const HEIGHT := 540.0
const PLAY := Rect2(28, 92, 904, 410)
const CYAN := Color("#48dff2")
const PINK := Color("#ff4f9a")
const GOLD := Color("#ffd166")
const BG := Color("#07111f")
const PANEL := Color("#10263a")
const WHITE := Color("#eaf7ff")

const GAME_NAMES := [
	"COURIER", "BREAKER", "TAP PATROL", "SKY DODGE",
	"NEON DASH", "KOFUN ORBIT", "SNAKE"
]
const GAME_TAGS := [
	"Collect 8 relics in 45 seconds",
	"Break a 5 x 10 wall with 3 lives",
	"Tag 12 signals in 30 seconds",
	"Flap through 10 gates",
	"Run the neon road for 30 seconds",
	"Pulse enemies away and survive 30 seconds",
	"Grow by eating 15 magatama"
]

var rng := RandomNumberGenerator.new()
var menu_index := 0
var game := -1
var phase := "menu"
var phase_message := ""
var elapsed := 0.0
var score := 0
var player := Vector2.ZERO
var velocity := Vector2.ZERO
var objects: Array = []
var hazards: Array = []
var aux: Dictionary = {}


func _ready() -> void:
	rng.seed = 0x4B4F4655
	queue_redraw()


func _process(delta: float) -> void:
	if phase == "playing":
		elapsed += delta
		match game:
			0: update_courier(delta)
			1: update_breaker(delta)
			2: update_tap(delta)
			3: update_sky(delta)
			4: update_dash(delta)
			5: update_orbit(delta)
			6: update_snake(delta)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			show_menu()
			return
		if phase == "menu":
			if event.keycode in [KEY_UP, KEY_W]:
				menu_index = wrapi(menu_index - 1, 0, GAME_NAMES.size())
			elif event.keycode in [KEY_DOWN, KEY_S]:
				menu_index = wrapi(menu_index + 1, 0, GAME_NAMES.size())
			elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				start_game(menu_index)
			elif event.keycode >= KEY_1 and event.keycode <= KEY_7:
				start_game(int(event.keycode - KEY_1))
		elif event.keycode == KEY_R:
			start_game(game)
		elif phase in ["won", "lost"] and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			start_game(game)
		elif phase == "playing":
			if game == 3 and event.keycode in [KEY_SPACE, KEY_UP, KEY_W]:
				velocity.y = -335.0
			elif game == 4 and event.keycode in [KEY_SPACE, KEY_UP, KEY_W]:
				dash_jump()
			elif game == 5 and event.keycode == KEY_SPACE:
				orbit_pulse()
			elif game == 6:
				snake_turn(event.keycode)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pointer_press(event.position)
	if event is InputEventScreenTouch and event.pressed:
		pointer_press(event.position)


func pointer_press(pos: Vector2) -> void:
	if phase != "playing":
		return
	if game == 2:
		tap_at(pos)
	elif game == 3:
		velocity.y = -335.0
	elif game == 4:
		dash_jump()


func show_menu() -> void:
	phase = "menu"
	game = -1
	phase_message = ""


func start_game(which: int) -> void:
	game = which
	phase = "playing"
	phase_message = ""
	elapsed = 0.0
	score = 0
	objects.clear()
	hazards.clear()
	aux.clear()
	match game:
		0: setup_courier()
		1: setup_breaker()
		2: setup_tap()
		3: setup_sky()
		4: setup_dash()
		5: setup_orbit()
		6: setup_snake()


func finish(won: bool, message: String) -> void:
	if phase != "playing":
		return
	phase = "won" if won else "lost"
	phase_message = message


func movement_vector() -> Vector2:
	var v := Vector2(
		float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) -
		float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)) -
		float(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W))
	)
	return v.normalized() if v.length_squared() > 0.0 else Vector2.ZERO


# 1. Courier -----------------------------------------------------------------
func setup_courier() -> void:
	player = Vector2(120, 300)
	for i in 8:
		objects.append(Vector2(210 + (i % 4) * 190, 155 + (i / 4) * 250))
	for i in 4:
		hazards.append({
			"p": Vector2(250 + i * 165, 260 + (i % 2) * 95),
			"v": Vector2.ZERO,
			"speed": 78.0 + i * 5.0
		})


func update_courier(delta: float) -> void:
	player += movement_vector() * 235.0 * delta
	player.x = clampf(player.x, PLAY.position.x + 14, PLAY.end.x - 14)
	player.y = clampf(player.y, PLAY.position.y + 14, PLAY.end.y - 14)
	for i in range(hazards.size()):
		var e: Dictionary = hazards[i]
		var desired: Vector2 = (player - e.p).normalized() * e.speed
		e.v = e.v.lerp(desired, minf(1.0, delta * 3.5))
		e.p += e.v * delta
		hazards[i] = e
		if player.distance_to(e.p) < 27:
			finish(false, "A guardian caught the courier")
			return
	for i in range(objects.size() - 1, -1, -1):
		if player.distance_to(objects[i]) < 27:
			objects.remove_at(i)
			score += 1
	if score == 8:
		finish(true, "All eight relics delivered!")
	elif elapsed >= 45:
		finish(false, "The 45 second route closed")


# 2. Breaker -----------------------------------------------------------------
func setup_breaker() -> void:
	player = Vector2(480, 470)
	velocity = Vector2(245, -245)
	aux = {"lives": 3}
	for row in 5:
		for col in 10:
			objects.append(Rect2(91 + col * 79, 128 + row * 38, 70, 24))


func update_breaker(delta: float) -> void:
	player.x += movement_vector().x * 390 * delta
	player.x = clampf(player.x, 93, 867)
	var ball: Vector2 = aux.get("ball", Vector2(480, 430))
	ball += velocity * delta
	if ball.x < 43:
		ball.x = 43
		velocity.x = absf(velocity.x)
	elif ball.x > 917:
		ball.x = 917
		velocity.x = -absf(velocity.x)
	if ball.y < 106:
		ball.y = 106
		velocity.y = absf(velocity.y)
	var paddle := Rect2(player.x - 65, 475, 130, 14)
	if velocity.y > 0 and paddle.grow(7).has_point(ball):
		ball.y = 466
		velocity.y = -absf(velocity.y)
		velocity.x += (ball.x - player.x) * 2.2
		velocity = velocity.normalized() * minf(410, velocity.length() + 8)
	for i in range(objects.size() - 1, -1, -1):
		if (objects[i] as Rect2).grow(7).has_point(ball):
			objects.remove_at(i)
			velocity.y *= -1
			score += 1
			break
	if objects.is_empty():
		finish(true, "The whole wall is history")
	elif ball.y > 530:
		aux.lives -= 1
		if aux.lives <= 0:
			finish(false, "No balls left")
		else:
			ball = Vector2(player.x, 445)
			velocity = Vector2(230 if aux.lives % 2 else -230, -250)
	aux.ball = ball


# 3. Tap Patrol ---------------------------------------------------------------
func setup_tap() -> void:
	place_tap_pair()


func update_tap(_delta: float) -> void:
	if score >= 12:
		finish(true, "Twelve true signals confirmed")
	elif elapsed >= 30:
		finish(false, "Patrol ended with %d / 12" % score)


func tap_at(pos: Vector2) -> void:
	if pos.distance_to(aux.target) < 37:
		score += 1
		place_tap_pair()
	elif pos.distance_to(aux.decoy) < 43:
		elapsed += 3.0
		aux.decoy = random_distant_point(aux.target, 65, 180)


func place_tap_pair() -> void:
	aux.target = random_play_point(65)
	aux.decoy = random_distant_point(aux.target, 65, 180)


func random_distant_point(origin: Vector2, margin: float, minimum_distance: float) -> Vector2:
	var candidate := random_play_point(margin)
	for _attempt in 24:
		if candidate.distance_to(origin) >= minimum_distance:
			return candidate
		candidate = random_play_point(margin)
	return Vector2(
		PLAY.end.x - margin if origin.x < PLAY.get_center().x else PLAY.position.x + margin,
		PLAY.end.y - margin if origin.y < PLAY.get_center().y else PLAY.position.y + margin
	)


# 4. Sky Dodge ---------------------------------------------------------------
func setup_sky() -> void:
	player = Vector2(190, 285)
	velocity = Vector2.ZERO
	for i in 3:
		hazards.append({"x": 560.0 + i * 310.0, "gap": 190.0 + (i % 3) * 75.0, "scored": false})


func update_sky(delta: float) -> void:
	velocity.y += 820 * delta
	player.y += velocity.y * delta
	for i in range(hazards.size()):
		var gate: Dictionary = hazards[i]
		gate.x -= 185 * delta
		if not gate.scored and gate.x + 34 < player.x:
			gate.scored = true
			score += 1
		if gate.x < -50:
			gate.x += 930
			gate.gap = rng.randf_range(185, 390)
			gate.scored = false
		hazards[i] = gate
		if absf(gate.x - player.x) < 42 and absf(player.y - gate.gap) > 54:
			finish(false, "The glider clipped a gate")
			return
	if player.y < PLAY.position.y + 14 or player.y > PLAY.end.y - 14:
		finish(false, "The glider left the air lane")
		return
	elif score >= 10:
		finish(true, "Ten gates cleared")


# 5. Neon Dash ---------------------------------------------------------------
func setup_dash() -> void:
	player = Vector2(190, 446)
	velocity = Vector2.ZERO
	aux.spawn = 1.2


func dash_jump() -> void:
	if player.y >= 445:
		velocity.y = -430


func update_dash(delta: float) -> void:
	velocity.y += 1050 * delta
	player.y = minf(446, player.y + velocity.y * delta)
	if player.y >= 446:
		velocity.y = 0
	aux.spawn -= delta
	if aux.spawn <= 0:
		hazards.append({"x": 970.0, "h": rng.randf_range(35, 76)})
		aux.spawn = rng.randf_range(1.05, 1.65) - minf(elapsed * .008, .25)
	var speed := 260.0 + elapsed * 5.0
	for i in range(hazards.size() - 1, -1, -1):
		hazards[i].x -= speed * delta
		if hazards[i].x < -30:
			hazards.remove_at(i)
			score += 1
		elif Rect2(hazards[i].x, 468 - hazards[i].h, 30, hazards[i].h).intersects(Rect2(player.x - 16, player.y - 28, 32, 48)):
			finish(false, "The runner hit a neon marker")
	if elapsed >= 30:
		finish(true, "Thirty seconds on the neon road")


# 6. Kofun Orbit -------------------------------------------------------------
func setup_orbit() -> void:
	player = Vector2(480, 300)
	aux.spawn = .3
	aux.pulse = 0.0
	aux.flash = 0.0


func orbit_pulse() -> void:
	if aux.pulse <= 0:
		aux.pulse = 1.15
		aux.flash = .22
		for i in range(hazards.size() - 1, -1, -1):
			var delta: Vector2 = hazards[i].p - player
			if delta.length() < 150:
				hazards[i].v = delta.normalized() * 410
				hazards[i].stun = .55
				score += 1


func update_orbit(delta: float) -> void:
	player += movement_vector() * 220 * delta
	player.x = clampf(player.x, 46, 914)
	player.y = clampf(player.y, 112, 484)
	aux.spawn -= delta
	aux.pulse = maxf(0, aux.pulse - delta)
	aux.flash = maxf(0, aux.flash - delta)
	if aux.spawn <= 0:
		var side := rng.randi_range(0, 3)
		var p := Vector2.ZERO
		if side == 0: p = Vector2(30, rng.randf_range(110, 490))
		elif side == 1: p = Vector2(930, rng.randf_range(110, 490))
		elif side == 2: p = Vector2(rng.randf_range(35, 925), 100)
		else: p = Vector2(rng.randf_range(35, 925), 500)
		hazards.append({"p": p, "v": Vector2.ZERO, "stun": 0.0})
		aux.spawn = maxf(.42, 1.15 - elapsed * .018)
	for i in range(hazards.size() - 1, -1, -1):
		var e: Dictionary = hazards[i]
		e.stun = maxf(0, e.stun - delta)
		if e.stun <= 0:
			e.v = e.v.lerp((player - e.p).normalized() * (80 + elapsed * 2.1), minf(1, delta * 4))
		else:
			e.v *= pow(.18, delta)
		e.p += e.v * delta
		hazards[i] = e
		if e.p.distance_to(player) < 22:
			finish(false, "The orbit was breached")
			return
		if e.p.x < -90 or e.p.x > 1050 or e.p.y < 0 or e.p.y > 600:
			hazards.remove_at(i)
	if elapsed >= 30:
		finish(true, "Orbit held for thirty seconds")


# 7. Snake -------------------------------------------------------------------
func setup_snake() -> void:
	var snake: Array[Vector2i] = [Vector2i(11, 7), Vector2i(10, 7), Vector2i(9, 7)]
	aux = {"snake": snake, "dir": Vector2i.RIGHT, "next": Vector2i.RIGHT, "tick": 0.0, "food": Vector2i(20, 7)}


func snake_turn(keycode: int) -> void:
	var next: Vector2i = aux.next
	if keycode in [KEY_UP, KEY_W]: next = Vector2i.UP
	elif keycode in [KEY_DOWN, KEY_S]: next = Vector2i.DOWN
	elif keycode in [KEY_LEFT, KEY_A]: next = Vector2i.LEFT
	elif keycode in [KEY_RIGHT, KEY_D]: next = Vector2i.RIGHT
	if next + (aux.dir as Vector2i) != Vector2i.ZERO:
		aux.next = next


func update_snake(delta: float) -> void:
	aux.tick += delta
	if aux.tick < .115:
		return
	aux.tick -= .115
	aux.dir = aux.next
	var snake: Array = aux.snake
	var head: Vector2i = snake[0] + (aux.dir as Vector2i)
	var will_eat: bool = head == (aux.food as Vector2i)
	var hits_body: bool = head in snake and (will_eat or head != snake[-1])
	if head.x < 0 or head.x >= 28 or head.y < 0 or head.y >= 15 or hits_body:
		finish(false, "The trail folded into danger")
		return
	snake.push_front(head)
	if head == aux.food:
		score += 1
		place_snake_food(snake)
	else:
		snake.pop_back()
	aux.snake = snake
	if score >= 15:
		finish(true, "Fifteen magatama gathered")


func place_snake_food(snake: Array) -> void:
	for tries in 100:
		var candidate := Vector2i(rng.randi_range(0, 27), rng.randi_range(0, 14))
		if candidate not in snake:
			aux.food = candidate
			return


func random_play_point(margin: float) -> Vector2:
	return Vector2(
		rng.randf_range(PLAY.position.x + margin, PLAY.end.x - margin),
		rng.randf_range(PLAY.position.y + margin, PLAY.end.y - margin)
	)


# Drawing --------------------------------------------------------------------
func _draw() -> void:
	draw_rect(Rect2(0, 0, WIDTH, HEIGHT), BG)
	for x in range(0, 961, 48):
		draw_line(Vector2(x, 0), Vector2(x, HEIGHT), Color(0.08, .18, .27, .42), 1)
	for y in range(0, 541, 48):
		draw_line(Vector2(0, y), Vector2(WIDTH, y), Color(0.08, .18, .27, .42), 1)
	if phase == "menu":
		draw_menu()
	else:
		draw_game()
	if phase in ["won", "lost"]:
		draw_result()


func text(value: String, pos: Vector2, size := 20, color := WHITE, centered := false) -> void:
	var font := ThemeDB.fallback_font
	if centered:
		var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		pos.x -= width / 2
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func draw_menu() -> void:
	text("KOFUN // SEVEN", Vector2(480, 62), 34, CYAN, true)
	text("Seven small games. One lightweight Godot build.", Vector2(480, 90), 16, Color("#91aec2"), true)
	for i in GAME_NAMES.size():
		var y := 130 + i * 51
		var selected := i == menu_index
		draw_rect(Rect2(155, y - 25, 650, 42), Color("#173b50") if selected else Color("#0d2031"))
		if selected:
			draw_rect(Rect2(155, y - 25, 7, 42), PINK)
		text("%d" % (i + 1), Vector2(181, y + 3), 18, GOLD)
		text(GAME_NAMES[i], Vector2(221, y + 3), 21, WHITE if selected else Color("#a9c0cf"))
		text(GAME_TAGS[i], Vector2(420, y + 1), 15, Color("#7fa5bb"))
	text("UP/DOWN / W/S SELECT     ENTER / 1-7 START", Vector2(480, 510), 16, GOLD, true)


func draw_header() -> void:
	text("%d  %s" % [game + 1, GAME_NAMES[game]], Vector2(30, 39), 27, CYAN)
	text(GAME_TAGS[game], Vector2(30, 68), 15, Color("#91aec2"))
	text("ESC MENU   |   R RESTART", Vector2(930, 42), 15, Color("#91aec2"), true)
	draw_rect(PLAY, PANEL, true)
	draw_rect(PLAY, Color("#28526a"), false, 2)


func draw_game() -> void:
	draw_header()
	match game:
		0: draw_courier()
		1: draw_breaker()
		2: draw_tap()
		3: draw_sky()
		4: draw_dash()
		5: draw_orbit()
		6: draw_snake()


func draw_courier() -> void:
	for p in objects:
		draw_circle(p, 12, GOLD)
		draw_circle(p, 5, BG)
	for e in hazards:
		draw_circle(e.p, 15, PINK)
		draw_line(e.p - Vector2(8, 0), e.p + Vector2(8, 0), WHITE, 3)
	draw_circle(player, 15, CYAN)
	draw_circle(player, 6, WHITE)
	text("RELICS %d / 8" % score, Vector2(45, 120), 18, GOLD)
	text("TIME %02d" % maxf(0, 45 - elapsed), Vector2(820, 120), 18, WHITE)
	text("MOVE  WASD / ARROWS", Vector2(480, 525), 15, Color("#91aec2"), true)


func draw_breaker() -> void:
	for i in objects.size():
		var colors := [PINK, Color("#ff875e"), GOLD, CYAN, Color("#9775fa")]
		draw_rect(objects[i], colors[int((objects[i] as Rect2).position.y / 38) % colors.size()])
	draw_rect(Rect2(player.x - 65, 475, 130, 14), CYAN)
	draw_circle(aux.get("ball", Vector2(480, 430)), 7, WHITE)
	text("LIVES %d" % aux.lives, Vector2(45, 120), 18, GOLD)
	text("BRICKS %d / 50" % score, Vector2(805, 120), 18, WHITE)
	text("MOVE PADDLE  A/D / LEFT/RIGHT", Vector2(480, 525), 15, Color("#91aec2"), true)


func draw_tap() -> void:
	var pulse := 4 + sin(elapsed * 8) * 3
	draw_circle(aux.target, 28 + pulse, Color(CYAN, .18))
	draw_circle(aux.target, 25, CYAN)
	draw_circle(aux.target, 9, WHITE)
	draw_circle(aux.decoy, 31, Color(PINK, .22))
	draw_circle(aux.decoy, 23, PINK)
	draw_line(aux.decoy - Vector2(10, 10), aux.decoy + Vector2(10, 10), BG, 4)
	draw_line(aux.decoy + Vector2(-10, 10), aux.decoy + Vector2(10, -10), BG, 4)
	text("TARGETS %d / 12" % score, Vector2(45, 120), 18, GOLD)
	text("TIME %02d" % maxf(0, 30 - elapsed), Vector2(820, 120), 18, WHITE)
	text("CLICK / TAP CYAN | DECOY COSTS 3 SECONDS", Vector2(480, 525), 15, Color("#91aec2"), true)


func draw_sky() -> void:
	for gate in hazards:
		var gy: float = gate.gap
		draw_rect(Rect2(gate.x - 22, PLAY.position.y, 44, gy - 68 - PLAY.position.y), PINK)
		draw_rect(Rect2(gate.x - 22, gy + 68, 44, PLAY.end.y - gy - 68), PINK)
		draw_rect(Rect2(gate.x - 29, gy - 80, 58, 12), GOLD)
		draw_rect(Rect2(gate.x - 29, gy + 68, 58, 12), GOLD)
	draw_colored_polygon(PackedVector2Array([player + Vector2(-19, 12), player + Vector2(20, 0), player + Vector2(-19, -12)]), CYAN)
	text("GATES %d / 10" % score, Vector2(45, 120), 18, GOLD)
	text("FLAP  SPACE / CLICK", Vector2(480, 525), 15, Color("#91aec2"), true)


func draw_dash() -> void:
	draw_line(Vector2(28, 470), Vector2(932, 470), CYAN, 3)
	for x in range(0, 11):
		var px := fmod(x * 110.0 - elapsed * 260, 1100.0)
		draw_line(Vector2(px, 485), Vector2(px + 42, 485), Color("#28526a"), 3)
	for obstacle in hazards:
		draw_rect(Rect2(obstacle.x, 468 - obstacle.h, 30, obstacle.h), PINK)
	draw_rect(Rect2(player.x - 15, player.y - 28, 30, 48), CYAN)
	draw_rect(Rect2(player.x + 10, player.y - 22, 12, 8), GOLD)
	text("TIME %04.1f / 30" % elapsed, Vector2(45, 120), 18, GOLD)
	text("CLEARED %d" % score, Vector2(815, 120), 18, WHITE)
	text("JUMP  SPACE / W / UP / CLICK / TAP", Vector2(480, 525), 15, Color("#91aec2"), true)


func draw_orbit() -> void:
	if aux.flash > 0:
		draw_circle(player, 150 * (1 - aux.flash / .22), Color(CYAN, aux.flash / .44), false, 5)
	for e in hazards:
		draw_circle(e.p, 13, PINK)
		draw_circle(e.p, 4, WHITE)
	draw_circle(player, 17, CYAN)
	draw_circle(player, 7, WHITE)
	var cooldown: float = aux.pulse
	text("SURVIVE %04.1f / 30" % elapsed, Vector2(45, 120), 18, GOLD)
	text("PULSE %s" % ("READY" if cooldown <= 0 else "%0.1f" % cooldown), Vector2(805, 120), 18, CYAN if cooldown <= 0 else WHITE)
	text("MOVE WASD / ARROWS | SPACE PULSE", Vector2(480, 525), 15, Color("#91aec2"), true)


func draw_snake() -> void:
	var origin := Vector2(144, 120)
	var cell := Vector2(24, 24)
	draw_rect(Rect2(origin, Vector2(28, 15) * cell), Color("#091621"))
	for p in aux.snake:
		var r := Rect2(origin + Vector2(p) * cell + Vector2(2, 2), cell - Vector2(4, 4))
		draw_rect(r, CYAN if p == aux.snake[0] else Color("#238da4"))
	var food_pos: Vector2 = origin + Vector2(aux.food) * cell + cell / 2
	draw_circle(food_pos, 9, GOLD)
	draw_circle(food_pos, 3, BG)
	text("FOOD %d / 15" % score, Vector2(45, 120), 18, GOLD)
	text("STEER  WASD / ARROWS", Vector2(480, 525), 15, Color("#91aec2"), true)


func draw_result() -> void:
	draw_rect(Rect2(190, 190, 580, 170), Color(0.02, .055, .09, .95))
	draw_rect(Rect2(190, 190, 580, 170), CYAN if phase == "won" else PINK, false, 3)
	text("MISSION COMPLETE" if phase == "won" else "MISSION FAILED", Vector2(480, 241), 30, CYAN if phase == "won" else PINK, true)
	text(phase_message, Vector2(480, 284), 19, WHITE, true)
	text("ENTER / R  RETRY     ESC  MENU", Vector2(480, 329), 16, GOLD, true)
