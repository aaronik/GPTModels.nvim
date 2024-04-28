local job = require('plenary.job')
local util = require("gpt.util")

local M = {}

--- Make request
---@param prompt string
---@param model string
---@param on_response function
---@param on_end function
---@return nil
M.make_request = function(prompt, model, on_response, on_end)
    util.log("make_request, prompt: " .. prompt)
    local args = {
        "http://localhost:11434/api/generate",
        "-d",
        vim.fn.json_encode({ model = model, prompt = prompt, stream = true })
    }

    -- TODO Error handling
    job
        :new({
            command = "curl",
            args = args,
            on_stdout = vim.schedule_wrap(function(_, json)
                util.log(json)
                if json then
                    local data = vim.fn.json_decode(json)
                    -- data is large, data.resposne is the text we're looking for
                    on_response(data.response)
                end
            end),
            on_exit = vim.schedule_wrap(function()
                on_end()
            end)
        })
        :start()
end

return M
