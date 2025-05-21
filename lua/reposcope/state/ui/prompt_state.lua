---@class PromptStateManager
---@field private prompt string Holds the state of the prompt input
---@field set_prompt_text fun(text: string): nil Sets the prompt text
---@field get_prompt_text fun(): string Returns the prompt text
---@field clear_prompt_text fun(): nil Clears the prompt text state
local M = {}

---@private
M.actual_text = ""



M.input = {}

function M.set_field_text(field, text)
  if type(field) == "string" and type(text) == "string" then
    M.input[field] = text
  end
end

function M.get_field_text(field)
  return M.input[field] or ""
end




---Sets the last prompt text
---@param text string The prompt text to set
---@return nil
function M.set_prompt_text(text)
  M.actual_text = text
end

--REF: This functions are not in use yet

---Returns the last prompt text
---@return string The last prompt input text
function M.get_prompt_text()
  return M.actual_text
end


---Clears the prompt text state
---@return nil
function M.clear_prompt_text()
  M.actual_text = ""
end

return M
