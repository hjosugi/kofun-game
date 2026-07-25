local W, H, TOP = 960, 540, 76
local rules = require("rules")
local gameCount = 7
local names = {
  "COURIER", "BREAKER", "TAP PATROL", "SKY DODGE",
  "NEON DASH", "KOFUN ORBIT", "SNAKE",
}
local subtitles = {
  "Collect 8 relics in 45 seconds", "Clear the 5 x 10 wall",
  "Tag 12 targets in 30 seconds", "Flap through 10 gates",
  "Survive the skyline for 30 seconds", "Pulse back the swarm for 30 seconds",
  "Gather 15 golden fruit",
}
local accents = {
  { .26, .90, .74 }, { 1, .36, .52 }, { 1, .80, .36 }, { .41, .72, 1 },
  { .89, .37, 1 }, { .41, .96, .97 }, { .62, .95, .39 },
}
local bg, panel, ink, muted = { .04, .055, .115 }, { .08, .106, .192 },
  { .92, .95, 1 }, { .55, .62, .74 }
local app = { screen = "menu", selected = 1, current = 1, time = 0, flash = 0 }
local fonts = {}

local function setColor(c, a)
  love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1)
end
local function clamp(x, lo, hi) return math.max(lo, math.min(hi, x)) end
local function distance(a, b)
  local x, y = a.x - b.x, a.y - b.y
  return math.sqrt(x * x + y * y)
end
local function normalize(x, y)
  local length = math.sqrt(x * x + y * y)
  if length < .001 then return 0, 0 end
  return x / length, y / length
end
local function randomPoint(from, minimum)
  local p
  repeat
    p = { x = love.math.random(55, W - 55), y = love.math.random(TOP + 48, H - 52) }
  until distance(p, from) >= minimum
  return p
end
local function circleHit(a, ar, b, br) return distance(a, b) < ar + br end
local function rectHit(a, b)
  return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end
local function text(value, x, y, font, color)
  love.graphics.setFont(font)
  setColor(color or ink)
  love.graphics.print(value, math.floor(x), math.floor(y))
end
local function centered(value, y, font, color)
  love.graphics.setFont(font)
  setColor(color or ink)
  love.graphics.print(value, math.floor(W / 2 - font:getWidth(value) / 2), math.floor(y))
end
local function roundRect(mode, x, y, w, h, r)
  love.graphics.rectangle(mode, x, y, w, h, r or 8, r or 8)
end
local function card(x, y, w, h, color)
  setColor(panel); roundRect("fill", x, y, w, h, 12)
  setColor(color, .55); love.graphics.setLineWidth(2); roundRect("line", x, y, w, h, 12)
end
local function polygonCircle(sides, x, y, radius, rotation)
  local points = {}
  for i = 0, sides - 1 do
    local angle = rotation + i * math.pi * 2 / sides
    points[#points + 1] = x + math.cos(angle) * radius
    points[#points + 1] = y + math.sin(angle) * radius
  end
  love.graphics.polygon("fill", points)
end
local function endGame(won)
  app.won, app.screen, app.flash = won, "result", .25
end
local function backdrop()
  setColor(bg); love.graphics.rectangle("fill", 0, 0, W, H)
  for i = 1, 22 do
    local x = (i * 157 + app.time * (9 + i % 3)) % (W + 60) - 30
    local y = 24 + (i * 83) % (H - 42)
    setColor(muted, .35)
    love.graphics.circle("fill", x, y, i % 5 == 0 and 2 or 1)
  end
  setColor(muted, .055)
  for y = TOP, H, 32 do love.graphics.line(0, y, W, y) end
  setColor(muted, .04)
  for x = 0, W, 32 do love.graphics.line(x, TOP, x, H) end
end
local function header(left, right)
  setColor({ .055, .078, .15 }); love.graphics.rectangle("fill", 0, 0, W, TOP)
  setColor(accents[app.current]); love.graphics.rectangle("fill", 0, TOP - 3, W, 3)
  text(names[app.current], 24, 14, fonts.h2)
  text(left, 25, 48, fonts.small, accents[app.current])
  love.graphics.setFont(fonts.body)
  text(right, W - fonts.body:getWidth(right) - 24, 26, fonts.body)
end
local function help(value)
  love.graphics.setFont(fonts.tiny)
  local width = fonts.tiny:getWidth(value)
  setColor(panel, .92); roundRect("fill", W / 2 - width / 2 - 12, H - 32, width + 24, 24, 11)
  text(value, W / 2 - width / 2, H - 27, fonts.tiny, muted)
end

-- Courier --------------------------------------------------------------------
local function resetCourier()
  local s = { player = { x = W / 2, y = H / 2 }, relic = {}, enemy = {},
    score = 0, remaining = 45 }
  for i = 1, 8 do s.relic[i] = { p = randomPoint(s.player, 100), got = false } end
  for i = 1, 4 do
    local angle = love.math.random() * math.pi * 2
    s.enemy[i] = { p = randomPoint(s.player, 190),
      vx = math.cos(angle) * (85 + i * 10), vy = math.sin(angle) * (85 + i * 10) }
  end
  return s
end
local function updateCourier(s, dt)
  local x = (love.keyboard.isDown("d", "right") and 1 or 0) -
    (love.keyboard.isDown("a", "left") and 1 or 0)
  local y = (love.keyboard.isDown("s", "down") and 1 or 0) -
    (love.keyboard.isDown("w", "up") and 1 or 0)
  x, y = normalize(x, y)
  s.player.x = clamp(s.player.x + x * 235 * dt, 20, W - 20)
  s.player.y = clamp(s.player.y + y * 235 * dt, TOP + 20, H - 40)
  s.remaining = s.remaining - dt
  for _, relic in ipairs(s.relic) do
    if not relic.got and circleHit(s.player, 14, relic.p, 11) then
      relic.got, s.score = true, s.score + 1
    end
  end
  local caught = false
  for _, enemy in ipairs(s.enemy) do
    local nx, ny = normalize(s.player.x - enemy.p.x, s.player.y - enemy.p.y)
    local speed = math.sqrt(enemy.vx * enemy.vx + enemy.vy * enemy.vy)
    enemy.vx, enemy.vy = normalize(enemy.vx + nx * 34 * dt, enemy.vy + ny * 34 * dt)
    enemy.vx, enemy.vy = enemy.vx * speed, enemy.vy * speed
    enemy.p.x, enemy.p.y = enemy.p.x + enemy.vx * dt, enemy.p.y + enemy.vy * dt
    if enemy.p.x < 16 or enemy.p.x > W - 16 then enemy.vx = -enemy.vx end
    if enemy.p.y < TOP + 16 or enemy.p.y > H - 38 then enemy.vy = -enemy.vy end
    if circleHit(s.player, 14, enemy.p, 16) then caught = true; break end
  end
  local outcome = rules.goal_after_hazard(caught, s.score == 8)
  if outcome ~= nil then endGame(outcome)
  elseif s.remaining <= 0 then endGame(false) end
end
local function drawCourier(s)
  header("Collect every gold relic",
    ("RELICS %d/8    %02d"):format(s.score, math.ceil(math.max(0, s.remaining))))
  for i, relic in ipairs(s.relic) do
    if not relic.got then
      setColor(accents[1]); polygonCircle(6, relic.p.x, relic.p.y, 11, app.time + i)
      setColor(accents[1], .4); love.graphics.circle("line", relic.p.x, relic.p.y, 17 + math.sin(app.time * 4 + i) * 2)
    end
  end
  for _, enemy in ipairs(s.enemy) do
    setColor(accents[2]); polygonCircle(4, enemy.p.x, enemy.p.y, 17, math.pi / 4 + app.time * .4)
    setColor(bg); love.graphics.circle("fill", enemy.p.x, enemy.p.y, 5)
  end
  setColor(ink); love.graphics.circle("fill", s.player.x, s.player.y, 15)
  setColor(accents[1]); love.graphics.circle("fill", s.player.x, s.player.y, 9)
  setColor(ink); love.graphics.setLineWidth(3); love.graphics.line(s.player.x, s.player.y, s.player.x, s.player.y - 23)
  help("WASD / ARROWS move  |  R restart  |  ESC menu")
end

-- Breaker --------------------------------------------------------------------
local function resetBreaker()
  local bricks = {}
  for i = 1, 50 do bricks[i] = true end
  return { paddle = { x = W / 2 - 55, y = H - 58, w = 110, h = 13 },
    ball = { x = W / 2, y = H - 76 }, vx = 210, vy = -260,
    launched = false, bricks = bricks, remaining = 50, lives = 3 }
end
local function brickRect(i)
  local n = i - 1
  return { x = 56 + n % 10 * 85, y = TOP + 34 + math.floor(n / 10) * 31, w = 76, h = 20 }
end
local function updateBreaker(s, dt)
  local move = ((love.keyboard.isDown("d", "right") and 1 or 0) -
    (love.keyboard.isDown("a", "left") and 1 or 0)) * 390 * dt
  s.paddle.x = clamp(s.paddle.x + move, 16, W - s.paddle.w - 16)
  if not s.launched then
    s.ball.x, s.ball.y = s.paddle.x + s.paddle.w / 2, s.paddle.y - 11
    return
  end
  local oldX, oldY = s.ball.x, s.ball.y
  s.ball.x, s.ball.y = s.ball.x + s.vx * dt, s.ball.y + s.vy * dt
  if s.ball.x < 10 then s.ball.x, s.vx = 10, math.abs(s.vx) end
  if s.ball.x > W - 10 then s.ball.x, s.vx = W - 10, -math.abs(s.vx) end
  if s.ball.y < TOP + 8 then s.ball.y, s.vy = TOP + 8, math.abs(s.vy) end
  local ball = { x = s.ball.x - 7, y = s.ball.y - 7, w = 14, h = 14 }
  if s.vy > 0 and rectHit(ball, s.paddle) then
    local ratio = (s.ball.x - (s.paddle.x + s.paddle.w / 2)) / (s.paddle.w / 2)
    s.vx, s.vy, s.ball.y = ratio * 340, -math.abs(s.vy), s.paddle.y - 9
  end
  for i, exists in ipairs(s.bricks) do
    if exists then
      local b = brickRect(i)
      if rectHit(ball, b) then
        s.bricks[i], s.remaining = false, s.remaining - 1
        if oldY <= b.y or oldY >= b.y + b.h then s.vy = -s.vy else s.vx = -s.vx end
        local nx, ny = normalize(s.vx, s.vy)
        local speed = math.min(430, math.sqrt(s.vx * s.vx + s.vy * s.vy) + 4)
        s.vx, s.vy = nx * speed, ny * speed
        if s.remaining == 0 then endGame(true); return end
        break
      end
    end
  end
  if s.ball.y > H + 15 then
    s.lives, app.flash = s.lives - 1, .15
    if s.lives == 0 then endGame(false); return end
    s.launched, s.vx, s.vy = false, love.math.random(-220, 220), -280
  end
end
local function drawBreaker(s)
  header("Break the complete wall", ("BLOCKS %d/50    LIVES %d"):format(50 - s.remaining, s.lives))
  for i, exists in ipairs(s.bricks) do
    if exists then
      local b, row = brickRect(i), math.floor((i - 1) / 10)
      local t = row / 5
      setColor({ accents[2][1] * (1 - t) + accents[3][1] * t,
        accents[2][2] * (1 - t) + accents[3][2] * t,
        accents[2][3] * (1 - t) + accents[3][3] * t })
      roundRect("fill", b.x, b.y, b.w, b.h, 4)
      love.graphics.setColor(1, 1, 1, .28); love.graphics.rectangle("fill", b.x + 4, b.y + 3, b.w - 8, 3)
    end
  end
  setColor(ink); roundRect("fill", s.paddle.x, s.paddle.y, s.paddle.w, s.paddle.h, 7)
  setColor(accents[2]); love.graphics.circle("fill", s.ball.x, s.ball.y, 8)
  setColor(ink); love.graphics.circle("fill", s.ball.x, s.ball.y, 3)
  if not s.launched then centered("SPACE TO LAUNCH", H - 112, fonts.small, accents[2]) end
  help("A / D or ARROWS paddle  |  SPACE launch  |  R restart  |  ESC menu")
end

-- Tap Patrol -----------------------------------------------------------------
local function tapPair(s)
  s.target = { x = love.math.random(80, W - 80), y = love.math.random(TOP + 80, H - 70) }
  repeat
    s.decoy = { x = love.math.random(80, W - 80), y = love.math.random(TOP + 80, H - 70) }
  until distance(s.target, s.decoy) >= 150
  s.targetR, s.decoyR, s.pulse = love.math.random(24, 36), love.math.random(24, 38), 0
end
local function resetTap()
  local s = { score = 0, misses = 0, remaining = 30 }
  tapPair(s); return s
end
local function updateTap(s, dt)
  s.remaining, s.pulse = s.remaining - dt, s.pulse + dt
  if s.remaining <= 0 then endGame(false) end
end
local function clickTap(s, x, y)
  local p = { x = x, y = y }
  if circleHit(p, 1, s.target, s.targetR) then
    s.score = s.score + 1
    if s.score >= 12 then endGame(true) else tapPair(s) end
  elseif circleHit(p, 1, s.decoy, s.decoyR) then
    s.remaining, s.misses, app.flash = s.remaining - 3, s.misses + 1, .16
    tapPair(s)
  end
end
local function drawTap(s)
  header("Click solid targets - striped decoys cost 3 seconds",
    ("TARGETS %d/12    PENALTIES %d    %02d"):format(s.score, s.misses, math.ceil(s.remaining)))
  local pulse = math.sin(s.pulse * 6) * 3
  setColor(accents[3]); love.graphics.circle("fill", s.target.x, s.target.y, s.targetR + pulse)
  setColor(panel); love.graphics.circle("fill", s.target.x, s.target.y, s.targetR * .56)
  setColor(accents[3]); love.graphics.circle("fill", s.target.x, s.target.y, s.targetR * .3)
  love.graphics.setLineWidth(2); setColor(ink, .3)
  love.graphics.circle("line", s.target.x, s.target.y, s.targetR + 9 + pulse)
  setColor(accents[2]); love.graphics.circle("fill", s.decoy.x, s.decoy.y, s.decoyR)
  setColor(bg); love.graphics.setLineWidth(3)
  for yy = s.decoy.y - s.decoyR, s.decoy.y + s.decoyR, 8 do
    local dy = yy - s.decoy.y
    local half = math.sqrt(math.max(0, s.decoyR * s.decoyR - dy * dy))
    love.graphics.line(s.decoy.x - half, yy, s.decoy.x + half, yy)
  end
  text("TARGET", s.target.x - 27, s.target.y + s.targetR + 13, fonts.micro, muted)
  text("-3 SEC", s.decoy.x - 23, s.decoy.y + s.decoyR + 13, fonts.micro, accents[2])
  help("CLICK / TAP solid target  |  R restart  |  ESC menu")
end

-- Sky Dodge ------------------------------------------------------------------
local function resetSky()
  local s = { birdY = H / 2, birdV = 0, gates = {}, passed = 0 }
  for i = 1, 4 do s.gates[i] = { x = W + 90 + (i - 1) * 245,
    gap = love.math.random(175, H - 150), counted = false } end
  return s
end
local function flap(s) s.birdV = -330 end
local function updateSky(s, dt)
  s.birdV, s.birdY = s.birdV + 890 * dt, s.birdY + s.birdV * dt
  local bird, hit = { x = 165, y = s.birdY - 12, w = 28, h = 24 },
    s.birdY < TOP + 12 or s.birdY > H - 48
  for _, gate in ipairs(s.gates) do
    gate.x = gate.x - 180 * dt
    if not gate.counted and gate.x + 62 < 165 then
      gate.counted, s.passed = true, s.passed + 1
    end
    if gate.x < -80 then
      local maxX = gate.x
      for _, other in ipairs(s.gates) do maxX = math.max(maxX, other.x) end
      gate.x, gate.gap, gate.counted = maxX + 245, love.math.random(175, H - 150), false
    end
    local top = { x = gate.x, y = TOP, w = 62, h = gate.gap - 67 - TOP }
    local bottom = { x = gate.x, y = gate.gap + 67, w = 62, h = H - gate.gap - 102 }
    if rectHit(bird, top) or rectHit(bird, bottom) then hit = true end
  end
  local outcome = rules.goal_after_hazard(hit, s.passed >= 10)
  if outcome ~= nil then endGame(outcome) end
end
local function drawSky(s)
  header("Thread the glowing gates", ("GATES %d/10"):format(s.passed))
  for _, gate in ipairs(s.gates) do
    setColor({ .15, .35, .52 })
    love.graphics.rectangle("fill", gate.x, TOP, 62, gate.gap - 67 - TOP)
    love.graphics.rectangle("fill", gate.x, gate.gap + 67, 62, H - gate.gap - 102)
    setColor(accents[4])
    love.graphics.rectangle("fill", gate.x - 6, gate.gap - 75, 74, 10)
    love.graphics.rectangle("fill", gate.x - 6, gate.gap + 65, 74, 10)
  end
  setColor(accents[4]); polygonCircle(3, 179, s.birdY, 19, math.pi / 2)
  setColor(ink); love.graphics.circle("fill", 172, s.birdY - 2, 7)
  setColor(bg); love.graphics.circle("fill", 174, s.birdY - 3, 2)
  help("SPACE / UP / CLICK / TAP flap  |  R restart  |  ESC menu")
end

-- Neon Dash ------------------------------------------------------------------
local function resetDash()
  return { y = H - 73, vy = 0, remaining = 30, spawn = .8,
    obstacles = {}, dodged = 0 }
end
local function spawnDash(s)
  local height = love.math.random(34, 70)
  s.obstacles[#s.obstacles + 1] = { x = W + 20, y = H - 45 - height,
    w = love.math.random(25, 42), h = height }
end
local function dashJump(s)
  if s.y >= H - 74 then s.vy = -430 end
end
local function updateDash(s, dt)
  s.vy, s.y = s.vy + 1100 * dt, s.y + s.vy * dt
  if s.y > H - 73 then s.y, s.vy = H - 73, 0 end
  s.remaining, s.spawn = s.remaining - dt, s.spawn - dt
  if s.spawn <= 0 then spawnDash(s); s.spawn = love.math.random(75, 135) / 100 end
  local player = { x = 150, y = s.y - 31, w = 30, h = 31 }
  for i = #s.obstacles, 1, -1 do
    local obstacle = s.obstacles[i]
    obstacle.x = obstacle.x - (260 + (30 - s.remaining) * 2.4) * dt
    if obstacle.x + obstacle.w < 0 then
      table.remove(s.obstacles, i); s.dodged = s.dodged + 1
    elseif rectHit(player, obstacle) then endGame(false); return end
  end
  if s.remaining <= 0 then endGame(true) end
end
local function drawDash(s)
  header("Keep running until the clock expires",
    ("DODGED %d    %02d"):format(s.dodged, math.ceil(math.max(0, s.remaining))))
  for x = -80, W + 80, 120 do
    local px = (x - app.time * 120) % (W + 160) - 80
    local height = 60 + ((x + 400) * 7) % 90
    setColor({ .095, .137, .25 }); love.graphics.rectangle("fill", px, H - 45 - height, 75, height)
    setColor(accents[5]); love.graphics.rectangle("fill", px + 12, H - 62 - height / 2, 7, 7)
  end
  setColor(accents[5]); love.graphics.rectangle("fill", 0, H - 45, W, 4)
  for _, obstacle in ipairs(s.obstacles) do
    setColor(accents[2]); roundRect("fill", obstacle.x, obstacle.y, obstacle.w, obstacle.h, 4)
    love.graphics.polygon("fill", obstacle.x, obstacle.y,
      obstacle.x + obstacle.w / 2, obstacle.y - 12, obstacle.x + obstacle.w, obstacle.y)
  end
  setColor(ink); roundRect("fill", 150, s.y - 31, 30, 31, 8)
  setColor(accents[5]); love.graphics.circle("fill", 158, s.y, 6); love.graphics.circle("fill", 174, s.y, 6)
  help("SPACE / UP / CLICK / TAP jump  |  R restart  |  ESC menu")
end

-- Kofun Orbit ----------------------------------------------------------------
local function resetOrbit()
  return { player = { x = W / 2, y = H / 2 }, enemies = {},
    pulses = 0, remaining = 30, cooldown = 0, spawn = .2 }
end
local function spawnOrbit(s)
  if #s.enemies >= 10 then return end
  local edge, x, y = love.math.random(1, 4)
  if edge == 1 then x, y = -20, love.math.random(TOP + 20, H - 30)
  elseif edge == 2 then x, y = W + 20, love.math.random(TOP + 20, H - 30)
  elseif edge == 3 then x, y = love.math.random(20, W - 20), TOP - 20
  else x, y = love.math.random(20, W - 20), H + 20 end
  s.enemies[#s.enemies + 1] = { x = x, y = y, vx = 0, vy = 0 }
end
local function orbitPulse(s)
  if s.cooldown > 0 then return end
  s.cooldown, s.pulses = 1.05, s.pulses + 1
  for _, enemy in ipairs(s.enemies) do
    local dx, dy = enemy.x - s.player.x, enemy.y - s.player.y
    local nx, ny = normalize(dx, dy)
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 155 then
      enemy.vx, enemy.vy = enemy.vx + nx * (170 - d) * 3.5, enemy.vy + ny * (170 - d) * 3.5
    end
  end
end
local function updateOrbit(s, dt)
  local x = (love.keyboard.isDown("d", "right") and 1 or 0) -
    (love.keyboard.isDown("a", "left") and 1 or 0)
  local y = (love.keyboard.isDown("s", "down") and 1 or 0) -
    (love.keyboard.isDown("w", "up") and 1 or 0)
  x, y = normalize(x, y)
  s.player.x, s.player.y = clamp(s.player.x + x * 220 * dt, 24, W - 24),
    clamp(s.player.y + y * 220 * dt, TOP + 24, H - 40)
  s.remaining, s.spawn = s.remaining - dt, s.spawn - dt
  s.cooldown = s.cooldown - dt
  if s.spawn <= 0 then
    spawnOrbit(s); s.spawn = math.max(.38, .85 - (30 - s.remaining) * .012)
  end
  for _, enemy in ipairs(s.enemies) do
    local nx, ny = normalize(s.player.x - enemy.x, s.player.y - enemy.y)
    local decay = .16 ^ dt
    enemy.vx, enemy.vy = enemy.vx * decay, enemy.vy * decay
    local speed = 65 + (30 - s.remaining) * 1.8
    enemy.x, enemy.y = enemy.x + (nx * speed + enemy.vx) * dt,
      enemy.y + (ny * speed + enemy.vy) * dt
    if circleHit(s.player, 15, enemy, 13) then endGame(false); return end
  end
  if s.remaining <= 0 then endGame(true) end
end
local function drawOrbit(s)
  header("Survive - pulse nearby enemies away",
    ("PULSES %d    %02d"):format(s.pulses, math.ceil(math.max(0, s.remaining))))
  local ready = clamp(1 - s.cooldown / 1.05, 0, 1)
  setColor(accents[6], .35); love.graphics.circle("line", s.player.x, s.player.y, 32 + ready * 10)
  if s.cooldown > .72 then
    setColor(accents[6]); love.graphics.setLineWidth(2)
    love.graphics.circle("line", s.player.x, s.player.y, 40 + (1.05 - s.cooldown) * 380)
  end
  for _, enemy in ipairs(s.enemies) do
    setColor(accents[2])
    polygonCircle(3, enemy.x, enemy.y, 16, math.atan2(s.player.y - enemy.y, s.player.x - enemy.x))
    setColor(bg); love.graphics.circle("fill", enemy.x, enemy.y, 4)
  end
  setColor(ink); love.graphics.circle("fill", s.player.x, s.player.y, 17)
  setColor(accents[6]); love.graphics.circle("fill", s.player.x, s.player.y, 10)
  setColor(bg); love.graphics.circle("fill", s.player.x, s.player.y, 4)
  setColor(panel); roundRect("fill", 24, H - 63, 150, 10, 5)
  setColor(accents[6]); roundRect("fill", 24, H - 63, 150 * ready, 10, 5)
  help("WASD / ARROWS move  |  SPACE pulse  |  R restart  |  ESC menu")
end

-- Snake ----------------------------------------------------------------------
local GX, GY, CELL, COLS, ROWS = 120, 105, 24, 30, 16
local function sameCell(a, b) return a.x == b.x and a.y == b.y end
local function snakeFood(s)
  local occupied
  repeat
    occupied = false
    s.food = { x = love.math.random(0, COLS - 1), y = love.math.random(0, ROWS - 1) }
    for _, cell in ipairs(s.body) do if sameCell(s.food, cell) then occupied = true end end
  until not occupied
end
local function resetSnake()
  local s = { body = {}, dir = { x = 1, y = 0 }, nextDir = { x = 1, y = 0 }, tick = .12, score = 0 }
  for i = 1, 4 do s.body[i] = { x = math.floor(COLS / 2) - i + 1, y = math.floor(ROWS / 2) } end
  snakeFood(s); return s
end
local function turnSnake(s, x, y)
  if x ~= 0 and s.dir.x == 0 then s.nextDir = { x = x, y = 0 }
  elseif y ~= 0 and s.dir.y == 0 then s.nextDir = { x = 0, y = y } end
end
local function updateSnake(s, dt)
  s.tick = s.tick - dt
  if s.tick > 0 then return end
  s.tick, s.dir = s.tick + math.max(.062, .115 - s.score * .0025), s.nextDir
  local head = { x = s.body[1].x + s.dir.x, y = s.body[1].y + s.dir.y }
  if head.x < 0 or head.x >= COLS or head.y < 0 or head.y >= ROWS then endGame(false); return end
  local eat = sameCell(head, s.food)
  local solidLength = eat and #s.body or #s.body - 1
  for i = 1, solidLength do if sameCell(head, s.body[i]) then endGame(false); return end end
  table.insert(s.body, 1, head)
  if eat then
    s.score = s.score + 1
    if s.score >= 15 then endGame(true); return end
    snakeFood(s)
  else table.remove(s.body) end
end
local function drawSnake(s)
  header("Fill the grid without biting your tail", ("FRUIT %d/15    LENGTH %d"):format(s.score, #s.body))
  setColor(accents[7], .35); love.graphics.rectangle("fill", GX - 3, GY - 3, COLS * CELL + 6, ROWS * CELL + 6)
  setColor({ .047, .078, .125 }); love.graphics.rectangle("fill", GX, GY, COLS * CELL, ROWS * CELL)
  setColor(muted, .08)
  for x = 0, COLS do love.graphics.line(GX + x * CELL, GY, GX + x * CELL, GY + ROWS * CELL) end
  for y = 0, ROWS do love.graphics.line(GX, GY + y * CELL, GX + COLS * CELL, GY + y * CELL) end
  setColor(accents[3])
  polygonCircle(6, GX + s.food.x * CELL + CELL / 2, GY + s.food.y * CELL + CELL / 2,
    9 + math.sin(app.time * 5) * 2, app.time)
  for i = #s.body, 1, -1 do
    local cell = s.body[i]
    if i == 1 then setColor(ink) else setColor(accents[7], .95 - i / #s.body * .35) end
    roundRect("fill", GX + cell.x * CELL + 2, GY + cell.y * CELL + 2, CELL - 4, CELL - 4, 5)
  end
  help("WASD / ARROWS steer  |  R restart  |  ESC menu")
end

local resets = { resetCourier, resetBreaker, resetTap, resetSky, resetDash, resetOrbit, resetSnake }
local updates = { updateCourier, updateBreaker, updateTap, updateSky, updateDash, updateOrbit, updateSnake }
local draws = { drawCourier, drawBreaker, drawTap, drawSky, drawDash, drawOrbit, drawSnake }

local function resetCurrent()
  app.state, app.screen, app.won, app.flash = resets[app.current](), "play", false, 0
end
local function drawMenu()
  centered("KOFUN ARCADE", 38, fonts.title)
  centered("LOVE / LUA  |  SEVEN-GAME LAB", 91, fonts.small, muted)
  for i = 1, gameCount do
    local x, y, w, h = 154, 133 + (i - 1) * 51, 652, 42
    if app.selected == i then
      setColor(panel); roundRect("fill", x, y, w, h, 10)
      setColor(accents[i]); love.graphics.setLineWidth(2); roundRect("line", x, y, w, h, 10)
      roundRect("fill", x, y, 6, h, 3)
    end
    text(tostring(i), 175, y + 9, fonts.body, app.selected == i and accents[i] or muted)
    text(names[i], 218, y + 7, fonts.h2, app.selected == i and ink or { .72, .77, .86 })
    love.graphics.setFont(fonts.tiny)
    text(subtitles[i], 785 - fonts.tiny:getWidth(subtitles[i]), y + 13, fonts.tiny, muted)
  end
  centered("1-7 SELECT  |  UP/DOWN BROWSE  |  ENTER PLAY", 503, fonts.small, muted)
end
local function drawResult()
  draws[app.current](app.state)
  setColor(bg, .79); love.graphics.rectangle("fill", 0, 0, W, H)
  local color = app.won and accents[app.current] or accents[2]
  card(W / 2 - 250, 142, 500, 250, color)
  centered(app.won and "MISSION COMPLETE" or "RUN ENDED", 188, fonts.big, color)
  centered(names[app.current], 240, fonts.body)
  centered(app.won and "Nice run. The kofun remembers." or "Read the pattern, then try again.", 282, fonts.small, muted)
  centered("ENTER / R  RETRY", 330, fonts.small)
  centered("ESC  BACK TO ARCADE", 358, fonts.tiny, muted)
end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  fonts = {
    title = love.graphics.newFont(46), big = love.graphics.newFont(34),
    h2 = love.graphics.newFont(22), body = love.graphics.newFont(20),
    small = love.graphics.newFont(16), tiny = love.graphics.newFont(14),
    micro = love.graphics.newFont(12),
  }
  love.keyboard.setKeyRepeat(false)
end

function love.update(dt)
  dt = math.min(dt, 1 / 20)
  app.time, app.flash = app.time + dt, app.flash - dt
  if app.screen == "play" then updates[app.current](app.state, dt) end
end

function love.draw()
  backdrop()
  if app.screen == "menu" then drawMenu()
  elseif app.screen == "play" then draws[app.current](app.state)
  else drawResult() end
  if app.flash > 0 then love.graphics.setColor(1, 1, 1, app.flash * 1.8); love.graphics.rectangle("fill", 0, 0, W, H) end
end

function love.keypressed(key)
  if app.screen == "menu" then
    local number = tonumber(key)
    if number and number >= 1 and number <= gameCount then
      app.selected, app.current = number, number; resetCurrent()
    elseif key == "up" then app.selected = (app.selected - 2) % gameCount + 1
    elseif key == "down" then app.selected = app.selected % gameCount + 1
    elseif key == "return" or key == "space" then app.current = app.selected; resetCurrent() end
    return
  end
  if key == "escape" then app.screen = "menu"; return end
  if key == "r" or (app.screen == "result" and (key == "return" or key == "space")) then resetCurrent(); return end
  if app.screen ~= "play" then return end
  if app.current == 2 and (key == "space" or key == "return") then app.state.launched = true
  elseif app.current == 4 and (key == "space" or key == "up") then flap(app.state)
  elseif app.current == 5 and (key == "space" or key == "up") then dashJump(app.state)
  elseif app.current == 6 and key == "space" then orbitPulse(app.state)
  elseif app.current == 7 then
    if key == "up" or key == "w" then turnSnake(app.state, 0, -1)
    elseif key == "down" or key == "s" then turnSnake(app.state, 0, 1)
    elseif key == "left" or key == "a" then turnSnake(app.state, -1, 0)
    elseif key == "right" or key == "d" then turnSnake(app.state, 1, 0) end
  end
end

function love.mousepressed(x, y, button)
  if app.screen ~= "play" or button ~= 1 then return end
  if app.current == 3 then clickTap(app.state, x, y)
  elseif app.current == 4 then flap(app.state)
  elseif app.current == 5 then dashJump(app.state) end
end

function love.touchpressed(_, x, y)
  if app.screen ~= "play" then return end
  if app.current == 3 then clickTap(app.state, x, y)
  elseif app.current == 4 then flap(app.state)
  elseif app.current == 5 then dashJump(app.state) end
end
