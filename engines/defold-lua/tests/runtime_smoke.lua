-- Minimal Defold API doubles for exercising game state in a stock Lua runtime.
-- Bob remains the authoritative resource/compiler check; this catches update and
-- drawing-path errors without opening a window.
function hash(value) return value end

vmath = {
	vector3 = function(x, y, z) return { x = x, y = y, z = z } end,
	vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end,
	quat_rotation_z = function(angle) return { angle = angle } end,
}

gui = {
	PIVOT_CENTER = 0,
	PIVOT_W = 1,
	new_box_node = function() return {} end,
	new_text_node = function() return {} end,
	set_color = function() end,
	set_rotation = function() end,
	set_font = function() end,
	set_scale = function() end,
	set_pivot = function() end,
	delete_node = function() end,
}

msg = { post = function() end }

dofile("main/main.gui_script")

for mode = 1, 7 do
	local state = {}
	init(state)
	on_input(state, "game_" .. mode, { pressed = true })
	assert(state.game == mode and state.phase == "playing")

	if mode == 3 then
		on_input(state, "click", { pressed = true, x = state.target.x, y = state.target.y })
		assert(state.score == 1)
	elseif mode == 4 or mode == 5 then
		on_input(state, "action", { pressed = true })
		if mode == 5 then
			state.player.y, state.velocity.y = 72, 0
			on_input(state, "click", { pressed = true })
			assert(state.velocity.y > 0)
			state.player.y, state.velocity.y = 72, 0
			on_input(state, "touch", { touch = { { pressed = true } } })
			assert(state.velocity.y > 0)
		end
	elseif mode == 6 then
		for _ = 1, 30 do update(state, 0.016) end
		on_input(state, "action", { pressed = true })
	elseif mode == 7 then
		on_input(state, "up", { pressed = true })
	end

	for _ = 1, 220 do update(state, 0.016) end
	assert(state.phase == "playing" or state.phase == "won" or state.phase == "lost")
	on_input(state, "restart", { pressed = true })
	assert(state.phase == "playing" and state.score == 0)
	state.phase = "lost"
	on_input(state, "enter", { pressed = true })
	assert(state.phase == "playing" and state.score == 0)
	final(state)
end

local tail_state = {}
init(tail_state)
on_input(tail_state, "game_7", { pressed = true })
tail_state.snake = {
	{ x = 1, y = 1 }, { x = 1, y = 2 }, { x = 2, y = 2 }, { x = 2, y = 1 },
}
tail_state.direction = { x = 1, y = 0 }
tail_state.next_direction = { x = 1, y = 0 }
tail_state.food = { x = 20, y = 7 }
tail_state.tick = 0.2
update(tail_state, 0)
assert(tail_state.phase == "playing")
assert(tail_state.snake[1].x == 2 and tail_state.snake[1].y == 1)

local courier = {}
init(courier)
on_input(courier, "game_1", { pressed = true })
local before_dx = courier.player.x - courier.hazards[1].x
local before_dy = courier.player.y - courier.hazards[1].y
local before_distance = math.sqrt(before_dx * before_dx + before_dy * before_dy)
update(courier, 0.1)
local after_dx = courier.player.x - courier.hazards[1].x
local after_dy = courier.player.y - courier.hazards[1].y
assert(math.sqrt(after_dx * after_dx + after_dy * after_dy) < before_distance)

local tap = {}
init(tap)
on_input(tap, "game_3", { pressed = true })
local function tap_distance(state)
	local dx, dy = state.target.x - state.decoy.x, state.target.y - state.decoy.y
	return math.sqrt(dx * dx + dy * dy)
end
assert(tap_distance(tap) >= 180)
on_input(tap, "touch", {
	touch = { { pressed = true, x = tap.target.x, y = tap.target.y } },
})
assert(tap.score == 1 and tap_distance(tap) >= 180)

local sky = {}
init(sky)
on_input(sky, "game_4", { pressed = true })
sky.player, sky.velocity = { x = 190, y = 250 }, { x = 0, y = 0 }
sky.score = 9
sky.hazards = { { x = 155, gap = 190, scored = false } }
update(sky, 0)
assert(sky.score == 10 and sky.phase == "lost")
on_input(sky, "restart", { pressed = true })
sky.score, sky.hazards, sky.player.y = 10, {}, 48
update(sky, 0)
assert(sky.phase == "lost")

print("Defold smoke: menu, input, drawing, and all seven modes updated")
