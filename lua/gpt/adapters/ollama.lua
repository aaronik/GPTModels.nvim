local job = require('plenary.job')
local util = require("gpt.util")

local M = {}

M.make_request = function(prompt, model, on_response, on_end)
    local args = {
        "http://localhost:11434/api/generate",
        "-d",
        vim.fn.json_encode({ model = model, prompt = prompt, stream = true })
    }

    job
        :new({
            command = "curl",
            args = args,
            on_stdout = vim.schedule_wrap(function(_, data)
                if data then
                    local json = vim.fn.json_decode(data)
                    on_response(json.response)
                end
            end),
            on_exit = vim.schedule_wrap(function()
                on_end()
            end)
        })
        :start()
end

return M
