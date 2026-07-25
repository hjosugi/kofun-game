package main

import (
	"fmt"
	"image/color"
	"log"
	"math"
	"math/rand"

	"github.com/hajimehoshi/ebiten/v2"
	"github.com/hajimehoshi/ebiten/v2/ebitenutil"
	"github.com/hajimehoshi/ebiten/v2/inpututil"
	"github.com/hajimehoshi/ebiten/v2/text"
	"github.com/hajimehoshi/ebiten/v2/vector"
	"golang.org/x/image/font/basicfont"
)

const (
	screenWidth  = 960
	screenHeight = 540
	headerHeight = 70
	dt           = 1.0 / 60.0
)

var (
	bgColor    = color.RGBA{9, 12, 22, 255}
	panelColor = color.RGBA{19, 23, 41, 255}
	cyanColor  = color.RGBA{38, 230, 242, 255}
	pinkColor  = color.RGBA{255, 64, 148, 255}
	goldColor  = color.RGBA{255, 199, 51, 255}
	softColor  = color.RGBA{184, 199, 230, 255}
	whiteColor = color.RGBA{247, 250, 255, 255}
)

type mode int

const (
	menuMode mode = iota
	courierMode
	breakerMode
	tapMode
	skyMode
	dashMode
	orbitMode
	snakeMode
)

type resultState int

const (
	playing resultState = iota
	won
	lost
)

type vec struct {
	x float64
	y float64
}

func (v vec) add(other vec) vec          { return vec{v.x + other.x, v.y + other.y} }
func (v vec) sub(other vec) vec          { return vec{v.x - other.x, v.y - other.y} }
func (v vec) scale(n float64) vec        { return vec{v.x * n, v.y * n} }
func (v vec) length() float64            { return math.Hypot(v.x, v.y) }
func (v vec) distance(other vec) float64 { return v.sub(other).length() }
func (v vec) normalized() vec {
	length := v.length()
	if length == 0 {
		return vec{}
	}
	return v.scale(1 / length)
}

type rect struct {
	x float64
	y float64
	w float64
	h float64
}

func (r rect) overlaps(other rect) bool {
	return r.x < other.x+other.w && r.x+r.w > other.x &&
		r.y < other.y+other.h && r.y+r.h > other.y
}

func circleRect(center vec, radius float64, r rect) bool {
	x := clamp(center.x, r.x, r.x+r.w)
	y := clamp(center.y, r.y, r.y+r.h)
	return math.Hypot(center.x-x, center.y-y) < radius
}

func clamp(value, low, high float64) float64 {
	return math.Max(low, math.Min(high, value))
}

type courierGame struct {
	player  vec
	relics  []vec
	enemies []vec
	time    float64
	state   resultState
}

type breakerGame struct {
	paddleX float64
	ball    vec
	vel     vec
	bricks  []rect
	lives   int
	waiting bool
	state   resultState
}

type tapGame struct {
	target    vec
	decoys    []vec
	collected int
	time      float64
	flash     float64
	state     resultState
}

type gate struct {
	x      float64
	gapY   float64
	passed bool
}

type skyGame struct {
	birdY  float64
	vel    float64
	gates  []gate
	passed int
	state  resultState
}

type dashGame struct {
	y         float64
	vel       float64
	obstacles []rect
	spawn     float64
	elapsed   float64
	state     resultState
}

type orbitEnemy struct {
	pos   vec
	speed float64
}

type orbitGame struct {
	player  vec
	enemies []orbitEnemy
	spawn   float64
	elapsed float64
	pulseCD float64
	pulseFX float64
	state   resultState
}

type cell struct {
	x int
	y int
}

type snakeGame struct {
	body    []cell
	dir     cell
	nextDir cell
	food    cell
	timer   float64
	eaten   int
	state   resultState
}

type arcade struct {
	mode     mode
	selected int
	rng      *rand.Rand
	courier  courierGame
	breaker  breakerGame
	tap      tapGame
	sky      skyGame
	dash     dashGame
	orbit    orbitGame
	snake    snakeGame
}

var menuItems = [7][2]string{
	{"KOFUN COURIER", "Collect 8 relics before time runs out"},
	{"MOUND BREAKER", "Clear a 5 x 10 neon wall"},
	{"HANIWA TAP PATROL", "Find targets, avoid time-stealing decoys"},
	{"DOCHICKEN SKY DODGE", "Flap through 10 shifting gates"},
	{"NEON KOFUN DASH", "Survive a 30 second obstacle run"},
	{"KOFUN ORBIT", "Repel the swarm and survive"},
	{"KOFUN SNAKE", "Collect 15 food on the grid"},
}

func newArcade() *arcade {
	a := &arcade{rng: rand.New(rand.NewSource(20260725))}
	a.courier = a.resetCourier()
	a.breaker = resetBreaker()
	a.tap = a.resetTap()
	a.sky = resetSky()
	a.dash = resetDash()
	a.orbit = resetOrbit()
	a.snake = a.resetSnake()
	return a
}

func (a *arcade) randomPoint(margin float64) vec {
	return vec{
		x: margin + a.rng.Float64()*(screenWidth-2*margin),
		y: headerHeight + margin + a.rng.Float64()*(screenHeight-headerHeight-2*margin),
	}
}

func (a *arcade) resetCourier() courierGame {
	relics := make([]vec, 8)
	for i := range relics {
		relics[i] = a.randomPoint(35)
	}
	return courierGame{
		player:  vec{screenWidth / 2, screenHeight / 2},
		relics:  relics,
		enemies: []vec{{780, 300}},
		time:    45,
	}
}

func resetBreaker() breakerGame {
	bricks := make([]rect, 0, 50)
	for row := 0; row < 5; row++ {
		for col := 0; col < 10; col++ {
			bricks = append(bricks, rect{
				x: 65 + float64(col)*84,
				y: 100 + float64(row)*35,
				w: 76,
				h: 25,
			})
		}
	}
	return breakerGame{
		paddleX: screenWidth/2 - 55,
		ball:    vec{screenWidth / 2, 440},
		vel:     vec{240, -270},
		bricks:  bricks,
		lives:   3,
		waiting: true,
	}
}

func (a *arcade) tapPositions() (vec, []vec) {
	target := a.randomPoint(55)
	decoys := make([]vec, 0, 3)
	for len(decoys) < 3 {
		candidate := a.randomPoint(55)
		valid := candidate.distance(target) > 100
		for _, existing := range decoys {
			valid = valid && candidate.distance(existing) > 75
		}
		if valid {
			decoys = append(decoys, candidate)
		}
	}
	return target, decoys
}

func (a *arcade) resetTap() tapGame {
	target, decoys := a.tapPositions()
	return tapGame{target: target, decoys: decoys, time: 30}
}

func resetSky() skyGame {
	return skyGame{
		birdY: screenHeight / 2,
		gates: []gate{
			{x: 700, gapY: 230},
			{x: 1030, gapY: 340},
			{x: 1360, gapY: 190},
		},
	}
}

func resetDash() dashGame {
	return dashGame{y: 425, spawn: 1.3}
}

func resetOrbit() orbitGame {
	return orbitGame{player: vec{screenWidth / 2, screenHeight / 2}, spawn: .7}
}

func containsCell(body []cell, wanted cell) bool {
	for _, part := range body {
		if part == wanted {
			return true
		}
	}
	return false
}

func (a *arcade) randomFood(body []cell) cell {
	for {
		food := cell{a.rng.Intn(30), a.rng.Intn(16)}
		if !containsCell(body, food) {
			return food
		}
	}
}

func (a *arcade) resetSnake() snakeGame {
	body := []cell{{10, 8}, {9, 8}, {8, 8}, {7, 8}}
	return snakeGame{
		body:    body,
		dir:     cell{1, 0},
		nextDir: cell{1, 0},
		food:    a.randomFood(body),
	}
}

func (a *arcade) start(index int) {
	a.selected = min(index, 6)
	switch a.selected {
	case 0:
		a.courier = a.resetCourier()
		a.mode = courierMode
	case 1:
		a.breaker = resetBreaker()
		a.mode = breakerMode
	case 2:
		a.tap = a.resetTap()
		a.mode = tapMode
	case 3:
		a.sky = resetSky()
		a.mode = skyMode
	case 4:
		a.dash = resetDash()
		a.mode = dashMode
	case 5:
		a.orbit = resetOrbit()
		a.mode = orbitMode
	default:
		a.snake = a.resetSnake()
		a.mode = snakeMode
	}
}

func (a *arcade) restart() {
	if a.mode != menuMode {
		a.start(int(a.mode) - 1)
	}
}

func pressed(key ebiten.Key) bool {
	return inpututil.IsKeyJustPressed(key)
}

func down(key ebiten.Key) bool {
	return ebiten.IsKeyPressed(key)
}

func movement() vec {
	direction := vec{}
	if down(ebiten.KeyArrowLeft) || down(ebiten.KeyA) {
		direction.x--
	}
	if down(ebiten.KeyArrowRight) || down(ebiten.KeyD) {
		direction.x++
	}
	if down(ebiten.KeyArrowUp) || down(ebiten.KeyW) {
		direction.y--
	}
	if down(ebiten.KeyArrowDown) || down(ebiten.KeyS) {
		direction.y++
	}
	return direction.normalized()
}

func pointerPositionPressed() (vec, bool) {
	if inpututil.IsMouseButtonJustPressed(ebiten.MouseButtonLeft) {
		x, y := ebiten.CursorPosition()
		return vec{float64(x), float64(y)}, true
	}
	touches := inpututil.AppendJustPressedTouchIDs(nil)
	if len(touches) > 0 {
		x, y := ebiten.TouchPosition(touches[0])
		return vec{float64(x), float64(y)}, true
	}
	return vec{}, false
}

func pointerPressed() bool {
	_, ok := pointerPositionPressed()
	return ok
}

func (a *arcade) isFinished() bool {
	switch a.mode {
	case courierMode:
		return a.courier.state != playing
	case breakerMode:
		return a.breaker.state != playing
	case tapMode:
		return a.tap.state != playing
	case skyMode:
		return a.sky.state != playing
	case dashMode:
		return a.dash.state != playing
	case orbitMode:
		return a.orbit.state != playing
	case snakeMode:
		return a.snake.state != playing
	default:
		return false
	}
}

func (a *arcade) Update() error {
	if pressed(ebiten.KeyEscape) {
		a.mode = menuMode
		return nil
	}
	if a.mode != menuMode &&
		(pressed(ebiten.KeyR) || (a.isFinished() && pressed(ebiten.KeyEnter))) {
		a.restart()
		return nil
	}
	switch a.mode {
	case menuMode:
		a.updateMenu()
	case courierMode:
		a.updateCourier()
	case breakerMode:
		a.updateBreaker()
	case tapMode:
		a.updateTap()
	case skyMode:
		a.updateSky()
	case dashMode:
		a.updateDash()
	case orbitMode:
		a.updateOrbit()
	case snakeMode:
		a.updateSnake()
	}
	return nil
}

func (a *arcade) updateMenu() {
	if pressed(ebiten.KeyArrowUp) || pressed(ebiten.KeyW) {
		a.selected = (a.selected + 6) % 7
	}
	if pressed(ebiten.KeyArrowDown) || pressed(ebiten.KeyS) {
		a.selected = (a.selected + 1) % 7
	}
	numberKeys := [...]ebiten.Key{
		ebiten.KeyDigit1, ebiten.KeyDigit2, ebiten.KeyDigit3, ebiten.KeyDigit4,
		ebiten.KeyDigit5, ebiten.KeyDigit6, ebiten.KeyDigit7,
	}
	for i, key := range numberKeys {
		if pressed(key) {
			a.start(i)
			return
		}
	}
	if pressed(ebiten.KeyEnter) || pressed(ebiten.KeySpace) {
		a.start(a.selected)
	}
}

func (a *arcade) updateCourier() {
	g := &a.courier
	if g.state != playing {
		return
	}
	g.time = math.Max(0, g.time-dt)
	g.player = g.player.add(movement().scale(235 * dt))
	g.player.x = clamp(g.player.x, 18, screenWidth-18)
	g.player.y = clamp(g.player.y, headerHeight+18, screenHeight-18)
	remaining := g.relics[:0]
	for _, relic := range g.relics {
		if relic.distance(g.player) > 28 {
			remaining = append(remaining, relic)
		}
	}
	g.relics = remaining
	enemySpeed := 105 + float64(8-len(g.relics))*8
	for i := range g.enemies {
		enemy := &g.enemies[i]
		*enemy = enemy.add(g.player.sub(*enemy).normalized().scale(enemySpeed * dt))
		if enemy.distance(g.player) < 30 {
			g.state = lost
		}
	}
	if g.state == playing && len(g.relics) == 0 {
		g.state = won
	} else if g.state == playing && g.time <= 0 {
		g.time = 0
		g.state = lost
	}
}

func (a *arcade) updateBreaker() {
	g := &a.breaker
	if g.state != playing {
		return
	}
	direction := 0.0
	if down(ebiten.KeyArrowLeft) || down(ebiten.KeyA) {
		direction--
	}
	if down(ebiten.KeyArrowRight) || down(ebiten.KeyD) {
		direction++
	}
	g.paddleX = clamp(g.paddleX+direction*430*dt, 0, screenWidth-110)
	if g.waiting {
		g.ball = vec{g.paddleX + 55, 440}
		if pressed(ebiten.KeySpace) {
			g.waiting = false
		}
		return
	}
	g.ball = g.ball.add(g.vel.scale(dt))
	if g.ball.x < 9 || g.ball.x > screenWidth-9 {
		g.vel.x *= -1
		g.ball.x = clamp(g.ball.x, 9, screenWidth-9)
	}
	if g.ball.y < headerHeight+9 {
		g.vel.y = math.Abs(g.vel.y)
	}
	paddle := rect{g.paddleX, 462, 110, 16}
	if g.vel.y > 0 && circleRect(g.ball, 9, paddle) {
		offset := (g.ball.x - (g.paddleX + 55)) / 55
		g.vel = vec{offset * 330, -math.Abs(g.vel.y)}.normalized().scale(370)
		g.ball.y = 451
	}
	for i, brick := range g.bricks {
		if circleRect(g.ball, 9, brick) {
			g.bricks[i] = g.bricks[len(g.bricks)-1]
			g.bricks = g.bricks[:len(g.bricks)-1]
			g.vel.y *= -1
			break
		}
	}
	if len(g.bricks) == 0 {
		g.state = won
	} else if g.ball.y > screenHeight+10 {
		g.lives--
		if g.lives <= 0 {
			g.state = lost
		} else {
			g.waiting = true
			g.vel = vec{240, -270}
		}
	}
}

func (a *arcade) updateTap() {
	g := &a.tap
	if g.state != playing {
		return
	}
	g.time -= dt
	g.flash = math.Max(0, g.flash-dt)
	if position, ok := pointerPositionPressed(); ok {
		a.tapAt(g, position)
	}
	if g.collected >= 12 {
		g.state = won
	} else if g.time <= 0 {
		g.time = 0
		g.state = lost
	}
}

func (a *arcade) tapAt(g *tapGame, position vec) {
	if position.distance(g.target) <= 31 {
		g.collected++
		g.target, g.decoys = a.tapPositions()
		return
	}
	for _, decoy := range g.decoys {
		if position.distance(decoy) <= 28 {
			g.time -= 3
			g.flash = .25
			g.target, g.decoys = a.tapPositions()
			return
		}
	}
}

func (a *arcade) updateSky() {
	g := &a.sky
	if g.state != playing {
		return
	}
	if pressed(ebiten.KeySpace) || pressed(ebiten.KeyArrowUp) || pressed(ebiten.KeyW) ||
		pointerPressed() {
		g.vel = -330
	}
	g.vel += 850 * dt
	g.birdY += g.vel * dt
	maxX := 0.0
	for i := range g.gates {
		current := &g.gates[i]
		current.x -= 190 * dt
		maxX = math.Max(maxX, current.x)
		if !current.passed && current.x+54 < 220 {
			current.passed = true
			g.passed++
		}
		top := rect{current.x, headerHeight, 54, current.gapY - 75 - headerHeight}
		bottom := rect{current.x, current.gapY + 75, 54, screenHeight}
		bird := vec{220, g.birdY}
		if circleRect(bird, 15, top) || circleRect(bird, 15, bottom) {
			g.state = lost
		}
	}
	for i := range g.gates {
		if g.gates[i].x < -60 {
			g.gates[i].x = maxX + 330
			g.gates[i].gapY = 170 + a.rng.Float64()*220
			g.gates[i].passed = false
		}
	}
	if g.birdY < headerHeight+10 || g.birdY > screenHeight-10 {
		g.state = lost
	}
	g.state = resolveSkyResult(g.state, g.passed)
}

func resolveSkyResult(state resultState, passed int) resultState {
	if state == playing && passed >= 10 {
		return won
	}
	return state
}

func (a *arcade) updateDash() {
	g := &a.dash
	if g.state != playing {
		return
	}
	g.elapsed += dt
	onGround := g.y >= 425
	if onGround && (pressed(ebiten.KeySpace) || pressed(ebiten.KeyArrowUp) ||
		pressed(ebiten.KeyW) || pointerPressed()) {
		g.vel = -510
	}
	g.vel += 1250 * dt
	g.y = math.Min(g.y+g.vel*dt, 425)
	if g.y >= 425 {
		g.vel = 0
	}
	g.spawn -= dt
	if g.spawn <= 0 {
		height := 35 + a.rng.Float64()*35
		g.obstacles = append(g.obstacles, rect{screenWidth + 20, 460 - height, 30, height})
		g.spawn = .85 + a.rng.Float64()*.65
	}
	speed := 275 + g.elapsed*3
	kept := g.obstacles[:0]
	player := rect{154, g.y, 35, 35}
	for _, obstacle := range g.obstacles {
		obstacle.x -= speed * dt
		if obstacle.x > -50 {
			kept = append(kept, obstacle)
		}
		if player.overlaps(obstacle) {
			g.state = lost
		}
	}
	g.obstacles = kept
	if g.elapsed >= 30 && g.state == playing {
		g.elapsed = 30
		g.state = won
	}
}

func (a *arcade) spawnOrbitEnemy() orbitEnemy {
	side := a.rng.Intn(4)
	position := vec{}
	switch side {
	case 0:
		position = vec{a.rng.Float64() * screenWidth, headerHeight}
	case 1:
		position = vec{screenWidth, headerHeight + a.rng.Float64()*(screenHeight-headerHeight)}
	case 2:
		position = vec{a.rng.Float64() * screenWidth, screenHeight}
	default:
		position = vec{0, headerHeight + a.rng.Float64()*(screenHeight-headerHeight)}
	}
	return orbitEnemy{position, 75 + a.rng.Float64()*50}
}

func (a *arcade) updateOrbit() {
	g := &a.orbit
	if g.state != playing {
		return
	}
	g.elapsed += dt
	g.spawn -= dt
	g.pulseCD = math.Max(0, g.pulseCD-dt)
	g.pulseFX = math.Max(0, g.pulseFX-dt)
	g.player = g.player.add(movement().scale(220 * dt))
	g.player.x = clamp(g.player.x, 20, screenWidth-20)
	g.player.y = clamp(g.player.y, headerHeight+20, screenHeight-20)
	if g.spawn <= 0 {
		g.enemies = append(g.enemies, a.spawnOrbitEnemy())
		g.spawn = math.Max(.3, .72-g.elapsed*.012)
	}
	if pressed(ebiten.KeySpace) && g.pulseCD <= 0 {
		g.pulseCD = 1.15
		g.pulseFX = .28
		kept := g.enemies[:0]
		for _, enemy := range g.enemies {
			delta := enemy.pos.sub(g.player)
			distance := delta.length()
			if distance <= 115 {
				continue
			}
			if distance < 210 {
				enemy.pos = enemy.pos.add(delta.normalized().scale(115))
			}
			kept = append(kept, enemy)
		}
		g.enemies = kept
	}
	for i := range g.enemies {
		enemy := &g.enemies[i]
		enemy.pos = enemy.pos.add(g.player.sub(enemy.pos).normalized().scale(enemy.speed * dt))
	}
	for _, enemy := range g.enemies {
		if enemy.pos.distance(g.player) < 27 {
			g.state = lost
			break
		}
	}
	if g.state == playing && g.elapsed >= 30 {
		g.elapsed = 30
		g.state = won
	}
}

func (a *arcade) updateSnake() {
	g := &a.snake
	if g.state != playing {
		return
	}
	var requested *cell
	switch {
	case pressed(ebiten.KeyArrowUp) || pressed(ebiten.KeyW):
		requested = &cell{0, -1}
	case pressed(ebiten.KeyArrowDown) || pressed(ebiten.KeyS):
		requested = &cell{0, 1}
	case pressed(ebiten.KeyArrowLeft) || pressed(ebiten.KeyA):
		requested = &cell{-1, 0}
	case pressed(ebiten.KeyArrowRight) || pressed(ebiten.KeyD):
		requested = &cell{1, 0}
	}
	if requested != nil && (requested.x != -g.dir.x || requested.y != -g.dir.y) {
		g.nextDir = *requested
	}
	g.timer += dt
	if g.timer < .105 {
		return
	}
	g.timer -= .105
	g.dir = g.nextDir
	head := g.body[0]
	newHead := cell{head.x + g.dir.x, head.y + g.dir.y}
	if newHead.x < 0 || newHead.x >= 30 || newHead.y < 0 || newHead.y >= 16 ||
		snakeHitsBody(g.body, newHead, g.food) {
		g.state = lost
		return
	}
	g.body = append([]cell{newHead}, g.body...)
	if newHead == g.food {
		g.eaten++
		g.food = a.randomFood(g.body)
		if g.eaten >= 15 {
			g.state = won
		}
	} else {
		g.body = g.body[:len(g.body)-1]
	}
}

func snakeHitsBody(body []cell, newHead, food cell) bool {
	checkedLength := len(body)
	if newHead != food && checkedLength > 0 {
		checkedLength--
	}
	return containsCell(body[:checkedLength], newHead)
}

func drawRect(screen *ebiten.Image, r rect, fill color.Color) {
	vector.DrawFilledRect(screen, float32(r.x), float32(r.y), float32(r.w), float32(r.h), fill, false)
}

func drawCircle(screen *ebiten.Image, point vec, radius float64, fill color.Color) {
	vector.DrawFilledCircle(screen, float32(point.x), float32(point.y), float32(radius), fill, false)
}

func drawStrokeCircle(screen *ebiten.Image, point vec, radius, width float64, stroke color.Color) {
	vector.StrokeCircle(screen, float32(point.x), float32(point.y), float32(radius), float32(width), stroke, false)
}

func label(screen *ebiten.Image, message string, x, y int, fill color.Color) {
	text.Draw(screen, message, basicfont.Face7x13, x, y, fill)
}

func titleBar(screen *ebiten.Image, title, status, help string) {
	drawRect(screen, rect{0, 0, screenWidth, headerHeight}, panelColor)
	label(screen, title, 24, 27, whiteColor)
	label(screen, status, 24, 53, goldColor)
	width := len(help) * 7
	label(screen, help, screenWidth-width-22, 40, softColor)
}

func finishOverlay(screen *ebiten.Image, state resultState) {
	if state == playing {
		return
	}
	ebitenutil.DrawRect(screen, 0, 0, screenWidth, screenHeight, color.RGBA{3, 3, 8, 210})
	message := "MISSION COMPLETE"
	fill := cyanColor
	if state == lost {
		message = "MISSION FAILED"
		fill = pinkColor
	}
	label(screen, message, screenWidth/2-len(message)*7/2, 250, fill)
	hint := "ENTER / R  RESTART       ESC  MENU"
	label(screen, hint, screenWidth/2-len(hint)*7/2, 285, whiteColor)
}

func (a *arcade) Draw(screen *ebiten.Image) {
	screen.Fill(bgColor)
	switch a.mode {
	case menuMode:
		a.drawMenu(screen)
	case courierMode:
		a.drawCourier(screen)
	case breakerMode:
		a.drawBreaker(screen)
	case tapMode:
		a.drawTap(screen)
	case skyMode:
		a.drawSky(screen)
	case dashMode:
		a.drawDash(screen)
	case orbitMode:
		a.drawOrbit(screen)
	case snakeMode:
		a.drawSnake(screen)
	}
}

func (a *arcade) drawMenu(screen *ebiten.Image) {
	label(screen, "KOFUN ARCADE", 60, 60, cyanColor)
	label(screen, "SEVEN SMALL GAMES / ONE LIGHTWEIGHT RUNTIME", 60, 90, softColor)
	for i, item := range menuItems {
		y := 128 + i*52
		fill := softColor
		if i == a.selected {
			drawRect(screen, rect{52, float64(y - 24), 856, 40}, panelColor)
			drawRect(screen, rect{52, float64(y - 24), 5, 40}, pinkColor)
			fill = whiteColor
		}
		label(screen, fmt.Sprintf("%d", i+1), 72, y, goldColor)
		label(screen, item[0], 112, y, fill)
		label(screen, item[1], 340, y, fill)
	}
	label(screen, "UP / DOWN + ENTER    or    NUMBER KEY", 60, 515, softColor)
}

func (a *arcade) drawCourier(screen *ebiten.Image) {
	g := &a.courier
	titleBar(screen, "KOFUN COURIER",
		fmt.Sprintf("RELICS  %d/8    TIME  %02d", 8-len(g.relics), int(math.Ceil(g.time))),
		"WASD / ARROWS move  |  contact ends run")
	for _, relic := range g.relics {
		drawCircle(screen, relic, 11, goldColor)
		drawStrokeCircle(screen, relic, 19, 2, cyanColor)
	}
	for _, enemy := range g.enemies {
		drawCircle(screen, enemy, 16, pinkColor)
		direction := g.player.sub(enemy).normalized()
		vector.StrokeLine(screen, float32(enemy.x), float32(enemy.y),
			float32(enemy.x+direction.x*22), float32(enemy.y+direction.y*22),
			3, whiteColor, false)
	}
	drawCircle(screen, g.player, 17, cyanColor)
	drawStrokeCircle(screen, g.player, 23, 3, cyanColor)
	finishOverlay(screen, g.state)
}

func (a *arcade) drawBreaker(screen *ebiten.Image) {
	g := &a.breaker
	titleBar(screen, "MOUND BREAKER",
		fmt.Sprintf("BRICKS  %02d/50    LIVES  %d", 50-len(g.bricks), g.lives),
		"A / D or arrows move  |  SPACE launch")
	palette := []color.Color{cyanColor, goldColor, pinkColor}
	for i, brick := range g.bricks {
		drawRect(screen, brick, palette[i%len(palette)])
		vector.StrokeRect(screen, float32(brick.x), float32(brick.y), float32(brick.w), float32(brick.h),
			2, whiteColor, false)
	}
	drawRect(screen, rect{g.paddleX, 462, 110, 16}, cyanColor)
	drawCircle(screen, g.ball, 9, whiteColor)
	if g.waiting {
		label(screen, "SPACE TO LAUNCH", 420, 420, softColor)
	}
	finishOverlay(screen, g.state)
}

func (a *arcade) drawTap(screen *ebiten.Image) {
	g := &a.tap
	if g.flash > 0 {
		drawRect(screen, rect{0, headerHeight, screenWidth, screenHeight - headerHeight},
			color.RGBA{128, 0, 30, 80})
	}
	titleBar(screen, "HANIWA TAP PATROL",
		fmt.Sprintf("TARGETS  %d/12    TIME  %02d", g.collected, int(math.Ceil(g.time))),
		"CLICK / TAP cyan target  |  pink decoy -3 sec")
	drawCircle(screen, g.target, 31, cyanColor)
	drawStrokeCircle(screen, g.target, 40, 3, whiteColor)
	drawCircle(screen, g.target, 7, whiteColor)
	for _, decoy := range g.decoys {
		drawCircle(screen, decoy, 28, pinkColor)
		vector.StrokeLine(screen, float32(decoy.x-10), float32(decoy.y-10),
			float32(decoy.x+10), float32(decoy.y+10), 3, whiteColor, false)
		vector.StrokeLine(screen, float32(decoy.x+10), float32(decoy.y-10),
			float32(decoy.x-10), float32(decoy.y+10), 3, whiteColor, false)
	}
	finishOverlay(screen, g.state)
}

func (a *arcade) drawSky(screen *ebiten.Image) {
	g := &a.sky
	titleBar(screen, "DOCHICKEN SKY DODGE", fmt.Sprintf("GATES  %d/10", min(g.passed, 10)),
		"SPACE / UP / CLICK / TAP to flap")
	for _, gate := range g.gates {
		drawRect(screen, rect{gate.x, headerHeight, 54, gate.gapY - 75 - headerHeight}, pinkColor)
		drawRect(screen, rect{gate.x, gate.gapY + 75, 54, screenHeight}, pinkColor)
		vector.StrokeRect(screen, float32(gate.x), float32(gate.gapY-75), 54, 150, 3, goldColor, false)
	}
	drawCircle(screen, vec{220, g.birdY}, 15, cyanColor)
	finishOverlay(screen, g.state)
}

func (a *arcade) drawDash(screen *ebiten.Image) {
	g := &a.dash
	titleBar(screen, "NEON KOFUN DASH", fmt.Sprintf("SURVIVE  %.1f/30.0 SEC", g.elapsed),
		"SPACE / UP / POINTER to jump")
	vector.StrokeLine(screen, 0, 460, screenWidth, 460, 4, cyanColor, false)
	for i := 0; i < 12; i++ {
		x := math.Mod(float64(i*95)-g.elapsed*170+screenWidth+95, screenWidth+95)
		vector.StrokeLine(screen, float32(x), 480, float32(x+45), 480, 3, panelColor, false)
	}
	for _, obstacle := range g.obstacles {
		drawRect(screen, obstacle, pinkColor)
	}
	drawRect(screen, rect{154, g.y, 35, 35}, cyanColor)
	drawCircle(screen, vec{180, g.y + 10}, 5, bgColor)
	finishOverlay(screen, g.state)
}

func (a *arcade) drawOrbit(screen *ebiten.Image) {
	g := &a.orbit
	pulse := "WAIT"
	if g.pulseCD <= 0 {
		pulse = "READY"
	}
	titleBar(screen, "KOFUN ORBIT",
		fmt.Sprintf("TIME  %02d    PULSE  %s",
			int(math.Ceil(math.Max(0, 30-g.elapsed))), pulse),
		"WASD / ARROWS move  |  SPACE pulse")
	for _, enemy := range g.enemies {
		drawCircle(screen, enemy.pos, 14, pinkColor)
	}
	if g.pulseFX > 0 {
		radius := 45 + (.28-g.pulseFX)*590
		drawStrokeCircle(screen, g.player, radius, 5, goldColor)
	}
	drawCircle(screen, g.player, 18, cyanColor)
	drawStrokeCircle(screen, g.player, 28, 3, cyanColor)
	finishOverlay(screen, g.state)
}

func (a *arcade) drawSnake(screen *ebiten.Image) {
	g := &a.snake
	titleBar(screen, "KOFUN SNAKE", fmt.Sprintf("FOOD  %d/15", g.eaten), "WASD / ARROWS steer")
	const (
		originX  = 120
		originY  = 105
		cellSize = 24
	)
	drawRect(screen, rect{originX, originY, 30 * cellSize, 16 * cellSize}, panelColor)
	for x := 0; x <= 30; x++ {
		px := float32(originX + x*cellSize)
		vector.StrokeLine(screen, px, originY, px, originY+16*cellSize, 1, bgColor, false)
	}
	for y := 0; y <= 16; y++ {
		py := float32(originY + y*cellSize)
		vector.StrokeLine(screen, originX, py, originX+30*cellSize, py, 1, bgColor, false)
	}
	for i, part := range g.body {
		fill := cyanColor
		if i == 0 {
			fill = whiteColor
		}
		drawRect(screen, rect{
			float64(originX + part.x*cellSize + 2),
			float64(originY + part.y*cellSize + 2),
			cellSize - 4,
			cellSize - 4,
		}, fill)
	}
	drawCircle(screen, vec{
		float64(originX) + (float64(g.food.x)+.5)*cellSize,
		float64(originY) + (float64(g.food.y)+.5)*cellSize,
	}, 9, goldColor)
	finishOverlay(screen, g.state)
}

func (a *arcade) Layout(_, _ int) (int, int) {
	return screenWidth, screenHeight
}

func main() {
	ebiten.SetWindowSize(screenWidth, screenHeight)
	ebiten.SetWindowTitle("Kofun Arcade - Ebitengine")
	ebiten.SetWindowResizingMode(ebiten.WindowResizingModeDisabled)
	if err := ebiten.RunGame(newArcade()); err != nil {
		log.Fatal(err)
	}
}
