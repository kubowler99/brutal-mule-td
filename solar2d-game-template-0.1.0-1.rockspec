package = "solar2d-game-template"
version = "0.1.0-1"
source = {
   url = "git://github.com/username/your-repo.git"
}
description = {
   summary = "A professional Solar2D game template.",
   detailed = [[
      This is a professional, production-ready scaffolding for Solar2D games,
      implementing best practices for project organization and management.
   ]],
   homepage = "https://github.com/username/your-repo",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
   "middleclass",
   "busted",   -- For unit testing
   "luacheck", -- For static analysis/linting
   -- "ldoc",     -- For documentation generation
   -- "penlight", -- For advanced data structures and utilities
}
build = {
   type = "builtin",
   modules = {
      -- Solar2D projects usually don't use LuaRocks for the build process,
      -- but you can list your modules here for reference or CLI tools.
   }
}
