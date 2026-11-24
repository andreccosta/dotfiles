-- Swap the default shortcuts for creating sessions and app windows.
rex.bind("cmd+n", "session.new")
rex.bind("shift+cmd+n", "client.window.new")

-- Also open Go to Anything with Cmd+O.
rex.bind("cmd+o", "pane.go_to")
