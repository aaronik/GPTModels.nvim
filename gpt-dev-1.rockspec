package = "gpt"
version = "dev-1"
source = {
   url = "git+ssh://git@github.com/Aaronik/gpt.nvim.git"
}
description = {
   homepage = "*** please enter a project homepage ***",
   license = "*** please specify a license ***"
}
build = {
   type = "builtin",
   modules = {
      gpt = "lua/gpt.lua"
   },
   copy_directories = {
      "doc"
   }
}
