function love.conf(t)
  t.identity = "kofun-arcade-love"
  t.version = "11.5"
  t.window.title = "Kofun Arcade - LOVE"
  t.window.width = 960
  t.window.height = 540
  t.window.resizable = false
  t.window.vsync = 1
  t.modules.joystick = false
  t.modules.physics = false
end
