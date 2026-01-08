--!strict
--[[
    DevConsole.luau - In-game Developer Console
    
    Press ` (backtick) or F9 to toggle console.
    Type commands to execute dev actions.
    Drag the header to move the console.
    
    Commands:
    - coins [amount]     : Give coins (default 1000)
    - gems [amount]      : Give gems (default 100)
    - level [number]     : Set player level
    - xp [amount]        : Give XP
    - unlock [plant]     : Unlock specific plant
    - unlockall          : Unlock all plants
    - mutation [plant:type] : Add mutation (e.g. "Peashooter:Fire")
    - max                : Max coins, gems, level
    - reset              : Reset all data
    - help               : Show commands
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Import Zap network
local ZapClient = require(script.Parent:WaitForChild("network"):WaitForChild("generated"))

-- State
local isVisible = false
local commandHistory: {string} = {}
local historyIndex = 0
local outputLines: {string} = {}

-- UI References
local consoleGui: ScreenGui
local consolePanel: Frame
local outputFrame: ScrollingFrame
local inputBox: TextBox

-- Drag state
local isDragging = false
local dragStart: Vector3
local startPos: UDim2

-- Command aliases to DevCommandType
local COMMAND_MAP: {[string]: {command: string, needsStringArg: boolean, needsNumberArg: boolean}} = {
    coins = {command = "GiveCoins", needsStringArg = false, needsNumberArg = true},
    gems = {command = "GiveGems", needsStringArg = false, needsNumberArg = true},
    level = {command = "SetLevel", needsStringArg = false, needsNumberArg = true},
    xp = {command = "GiveXP", needsStringArg = false, needsNumberArg = true},
    unlock = {command = "UnlockPlant", needsStringArg = true, needsNumberArg = false},
    unlockall = {command = "UnlockAllPlants", needsStringArg = false, needsNumberArg = false},
    mutation = {command = "AddMutation", needsStringArg = true, needsNumberArg = false},
    max = {command = "MaxResources", needsStringArg = false, needsNumberArg = false},
    reset = {command = "ResetData", needsStringArg = false, needsNumberArg = false},
}

-- Add line to output
local function addOutput(text: string, isError: boolean?)
    local prefix = isError and "❌ " or "✅ "
    table.insert(outputLines, prefix .. text)
    
    -- Keep last 20 lines
    while #outputLines > 20 do
        table.remove(outputLines, 1)
    end
    
    -- Update UI
    if outputFrame then
        -- Clear existing
        for _, child in outputFrame:GetChildren() do
            if child:IsA("TextLabel") then
                child:Destroy()
            end
        end
        
        -- Add lines
        for i, line in outputLines do
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 0, 16)
            label.BackgroundTransparency = 1
            label.Text = line
            label.TextColor3 = if string.sub(line, 1, 3) == "❌ " 
                then Color3.fromRGB(255, 100, 100)
                else Color3.fromRGB(200, 255, 200)
            label.TextSize = 12
            label.Font = Enum.Font.Code
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.LayoutOrder = i
            label.Parent = outputFrame
        end
        
        -- Scroll to bottom
        outputFrame.CanvasPosition = Vector2.new(0, outputFrame.AbsoluteCanvasSize.Y)
    end
end

-- Parse and execute command
local function executeCommand(input: string)
    local parts = string.split(string.lower(input), " ")
    local cmd = parts[1]
    local arg1 = parts[2]
    
    -- Add to history
    table.insert(commandHistory, input)
    historyIndex = #commandHistory + 1
    
    -- Help command (local)
    if cmd == "help" or cmd == "?" then
        addOutput("Available commands:")
        addOutput("  coins [amount] - Give coins")
        addOutput("  gems [amount] - Give gems")
        addOutput("  level [num] - Set level")
        addOutput("  xp [amount] - Give XP")
        addOutput("  unlock [PlantName] - Unlock plant")
        addOutput("  unlockall - Unlock all plants")
        addOutput("  mutation [Plant:Type] - Add mutation")
        addOutput("  max - Max resources")
        addOutput("  reset - Reset data")
        addOutput("  clear - Clear console")
        return
    end
    
    -- Clear command (local)
    if cmd == "clear" then
        outputLines = {}
        if outputFrame then
            for _, child in outputFrame:GetChildren() do
                if child:IsA("TextLabel") then
                    child:Destroy()
                end
            end
        end
        return
    end
    
    -- Find command mapping
    local mapping = COMMAND_MAP[cmd]
    if not mapping then
        addOutput(`Unknown command: {cmd}. Type 'help' for list.`, true)
        return
    end
    
    -- Build args
    local stringArg: string? = nil
    local numberArg: number? = nil
    
    if mapping.needsStringArg then
        -- For mutations, capitalize properly: "peashooter:fire" -> "Peashooter:Fire"
        if arg1 then
            local argParts = string.split(arg1, ":")
            for i, part in argParts do
                argParts[i] = string.upper(string.sub(part, 1, 1)) .. string.sub(part, 2)
            end
            stringArg = table.concat(argParts, ":")
        end
    elseif mapping.needsNumberArg then
        numberArg = tonumber(arg1)
    end
    
    addOutput(`> {input}`)
    
    -- Send to server
    ZapClient.DevCommand.Fire({
        Command = mapping.command :: any,
        StringArg = stringArg,
        NumberArg = numberArg,
    })
end

-- Create UI
local function createConsoleUI()
    -- ScreenGui
    consoleGui = Instance.new("ScreenGui")
    consoleGui.Name = "DevConsole"
    consoleGui.ResetOnSpawn = false
    consoleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    consoleGui.DisplayOrder = 100
    
    -- Main Panel
    consolePanel = Instance.new("Frame")
    consolePanel.Name = "ConsolePanel"
    consolePanel.Size = UDim2.new(0, 500, 0, 300)
    consolePanel.Position = UDim2.new(0.5, -250, 0, 10)
    consolePanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    consolePanel.BackgroundTransparency = 0.1
    consolePanel.Visible = false
    consolePanel.Parent = consoleGui
    
    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 12)
    panelCorner.Parent = consolePanel
    
    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = Color3.fromRGB(100, 200, 100)
    panelStroke.Thickness = 2
    panelStroke.Parent = consolePanel
    
    -- Header (draggable)
    local header = Instance.new("TextButton")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 30)
    header.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
    header.Text = "🛠️ Dev Console (drag to move, ` to toggle)"
    header.TextColor3 = Color3.new(1, 1, 1)
    header.TextSize = 14
    header.Font = Enum.Font.GothamBold
    header.AutoButtonColor = false
    header.Parent = consolePanel
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 12)
    headerCorner.Parent = header
    
    -- Drag functionality
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            dragStart = input.Position
            startPos = consolePanel.Position
        end
    end)
    
    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            consolePanel.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    -- Output area
    outputFrame = Instance.new("ScrollingFrame")
    outputFrame.Name = "Output"
    outputFrame.Size = UDim2.new(1, -20, 1, -80)
    outputFrame.Position = UDim2.fromOffset(10, 35)
    outputFrame.BackgroundTransparency = 1
    outputFrame.ScrollBarThickness = 6
    outputFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 200, 100)
    outputFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    outputFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    outputFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    outputFrame.Parent = consolePanel
    
    local outputLayout = Instance.new("UIListLayout")
    outputLayout.Padding = UDim.new(0, 2)
    outputLayout.SortOrder = Enum.SortOrder.LayoutOrder
    outputLayout.Parent = outputFrame
    
    -- Input box
    inputBox = Instance.new("TextBox")
    inputBox.Name = "Input"
    inputBox.Size = UDim2.new(1, -20, 0, 30)
    inputBox.Position = UDim2.new(0, 10, 1, -40)
    inputBox.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    inputBox.Text = ""
    inputBox.PlaceholderText = "Type command (e.g. 'coins 1000', 'help')"
    inputBox.TextColor3 = Color3.new(1, 1, 1)
    inputBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
    inputBox.TextSize = 14
    inputBox.Font = Enum.Font.Code
    inputBox.TextXAlignment = Enum.TextXAlignment.Left
    inputBox.ClearTextOnFocus = false
    inputBox.Parent = consolePanel
    
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 8)
    inputCorner.Parent = inputBox
    
    local inputStroke = Instance.new("UIStroke")
    inputStroke.Color = Color3.fromRGB(60, 60, 70)
    inputStroke.Parent = inputBox
    
    local inputPadding = Instance.new("UIPadding")
    inputPadding.PaddingLeft = UDim.new(0, 10)
    inputPadding.Parent = inputBox
    
    -- Handle Enter key
    inputBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local text = inputBox.Text
            if text ~= "" then
                executeCommand(text)
                inputBox.Text = ""
            end
            -- Re-focus for continuous input
            task.defer(function()
                if isVisible then
                    inputBox:CaptureFocus()
                end
            end)
        end
    end)
    
    -- History navigation
    inputBox.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Up then
            -- Previous command
            if historyIndex > 1 then
                historyIndex -= 1
                inputBox.Text = commandHistory[historyIndex] or ""
                inputBox.CursorPosition = #inputBox.Text + 1
            end
        elseif input.KeyCode == Enum.KeyCode.Down then
            -- Next command
            if historyIndex < #commandHistory then
                historyIndex += 1
                inputBox.Text = commandHistory[historyIndex] or ""
                inputBox.CursorPosition = #inputBox.Text + 1
            elseif historyIndex == #commandHistory then
                historyIndex += 1
                inputBox.Text = ""
            end
        end
    end)
    
    consoleGui.Parent = PlayerGui
end

-- Toggle visibility
local function toggleConsole()
    isVisible = not isVisible
    consolePanel.Visible = isVisible
    
    if isVisible then
        task.defer(function()
            inputBox:CaptureFocus()
        end)
    end
end

-- Initialize
local function initialize()
    createConsoleUI()
    
    -- Toggle console with ` or F9
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.Backquote or input.KeyCode == Enum.KeyCode.F9 then
            toggleConsole()
        end
    end)
    
    -- Listen for server responses
    ZapClient.DevCommandResponse.On(function(data)
        if data.Success then
            addOutput(data.Message)
        else
            addOutput(data.Message, true)
        end
    end)
    
    -- Welcome message
    addOutput("Dev Console ready. Type 'help' for commands.")
end

-- Auto-initialize
initialize()

return {}
