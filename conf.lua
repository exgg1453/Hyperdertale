-- Hyperdertale - LOVE configuration.
function love.conf(t)
  t.identity = "hyperdertale"          -- save directory name
  t.version = "11.4"
  t.console = false

  t.window.title = "Hyperdertale"
  t.window.width = 960                 -- 320x240 logical, scaled 3x
  t.window.height = 720
  t.window.minwidth = 320
  t.window.minheight = 240
  t.window.resizable = true
  t.window.vsync = 1
  t.window.highdpi = true
  t.window.fullscreen = false

  -- Unused subsystems stay off so the Android build starts faster.
  t.modules.joystick = true
  t.modules.physics = false
  t.modules.video = false
  t.modules.touch = true
end
