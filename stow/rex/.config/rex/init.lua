-- Swap the default shortcuts for creating sessions and app windows.
rex.bind("cmd+n", "session.new")
rex.bind("shift+cmd+n", "client.window.new")

-- rexurrect
do
  local home = os.getenv("HOME")
  local r = rex.exec({ "/opt/homebrew/bin/rexurrect", "auto-restore" }, {
    env = {
      REXURRECT_STATE_DIR = home .. "/.local/state/rexurrect",
      REXURRECT_CONFIG = home .. "/.config/rexurrect/config.toml",
    },
  })
  if r then io.stderr:write(r.stderr) end
end
