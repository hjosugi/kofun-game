extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null)
	var app := packed.instantiate()
	root.add_child(app)
	await process_frame
	for mode in range(7):
		app.start_game(mode)
		for frame in range(220):
			app._process(0.016)
		await process_frame
		assert(app.game == mode)
		assert(app.phase in ["playing", "won", "lost"])

	app.start_game(0)
	var enemy_distance: float = float(app.player.distance_to(app.hazards[0].p))
	app.update_courier(0.1)
	assert(app.player.distance_to(app.hazards[0].p) < enemy_distance)

	app.start_game(2)
	assert(app.aux.target.distance_to(app.aux.decoy) >= 180)
	app.tap_at(app.aux.target)
	assert(app.score == 1)
	assert(app.aux.target.distance_to(app.aux.decoy) >= 180)
	var tap_touch := InputEventScreenTouch.new()
	tap_touch.position = app.aux.target
	tap_touch.pressed = true
	app._input(tap_touch)
	assert(app.score == 2)

	app.start_game(3)
	app.player = Vector2(190, 250)
	app.velocity = Vector2.ZERO
	app.score = 9
	app.hazards = [{"x": 155.0, "gap": 190.0, "scored": false}]
	app.update_sky(0)
	assert(app.score == 10)
	assert(app.phase == "lost")
	app.start_game(3)
	app.score = 10
	app.hazards.clear()
	app.player.y = 102
	app.update_sky(0)
	assert(app.phase == "lost")

	app.start_game(4)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	app._input(click)
	assert(app.velocity.y < 0)
	app.velocity.y = 0
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	app._input(touch)
	assert(app.velocity.y < 0)

	app.start_game(6)
	app.aux.snake = [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 1)]
	app.aux.dir = Vector2i.RIGHT
	app.aux.next = Vector2i.RIGHT
	app.aux.food = Vector2i(20, 7)
	app.aux.tick = 0.2
	app.update_snake(0)
	assert(app.phase == "playing")
	assert(app.aux.snake[0] == Vector2i(2, 1))

	app.finish(false, "test result")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	app._input(enter)
	assert(app.phase == "playing")
	print("Godot smoke: menu and all seven modes initialized and updated")
	quit()
