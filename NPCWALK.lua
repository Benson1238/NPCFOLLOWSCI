--[[
    XENO PATHFINDING BOT
    - Simple GUI
    - Auto-Follow with PathfindingService
    - "Stop" button kills the loop immediately
]]

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local LocalPlayer = Players.LocalPlayer

--// 1. GUI SETUP (Xeno Safe) //--
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "XenoFollower"
ScreenGui.ResetOnSpawn = false

-- Safe Parenting (CoreGui for hidden UI, fallback to PlayerGui)
if pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end) then
    -- Success
else
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 260, 0, 220)
MainFrame.Position = UDim2.new(0.1, 0, 0.1, 0) -- Top Left
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true -- Built-in Draggable for simplicity
MainFrame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Text = "AI FOLLOWER HUB"
Title.Size = UDim2.new(1, 0, 0, 26)
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 16
Title.Parent = MainFrame

local NameInput = Instance.new("TextBox")
NameInput.PlaceholderText = "Player Name (Partial)"
NameInput.Size = UDim2.new(0.9, 0, 0, 25)
NameInput.Position = UDim2.new(0.05, 0, 0.25, 0)
NameInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
NameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
NameInput.Text = ""
NameInput.Parent = MainFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Text = "Status: Idle"
StatusLabel.Size = UDim2.new(1, 0, 0, 18)
StatusLabel.Position = UDim2.new(0, 0, 0.52, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.TextSize = 12
StatusLabel.Parent = MainFrame

local StartBtn = Instance.new("TextButton")
StartBtn.Text = "START"
StartBtn.Size = UDim2.new(0.4, 0, 0, 25)
StartBtn.Position = UDim2.new(0.05, 0, 0.7, 0)
StartBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
StartBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StartBtn.Font = Enum.Font.SourceSansBold
StartBtn.Parent = MainFrame

local StopBtn = Instance.new("TextButton")
StopBtn.Text = "STOP"
StopBtn.Size = UDim2.new(0.4, 0, 0, 25)
StopBtn.Position = UDim2.new(0.55, 0, 0.7, 0)
StopBtn.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
StopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StopBtn.Font = Enum.Font.SourceSansBold
StopBtn.Parent = MainFrame

local PlayersLabel = Instance.new("TextLabel")
PlayersLabel.Text = "Players in server"
PlayersLabel.Size = UDim2.new(1, 0, 0, 16)
PlayersLabel.Position = UDim2.new(0, 0, 0.55, 0)
PlayersLabel.BackgroundTransparency = 1
PlayersLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
PlayersLabel.TextSize = 12
PlayersLabel.Parent = MainFrame

local PlayerList = Instance.new("ScrollingFrame")
PlayerList.Name = "PlayerList"
PlayerList.Size = UDim2.new(0.9, 0, 0, 60)
PlayerList.Position = UDim2.new(0.05, 0, 0.58, 0)
PlayerList.CanvasSize = UDim2.new(0, 0, 0, 0)
PlayerList.ScrollBarThickness = 4
PlayerList.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
PlayerList.BorderSizePixel = 0
PlayerList.Parent = MainFrame

local PlayerListLayout = Instance.new("UIListLayout")
PlayerListLayout.Padding = UDim.new(0, 4)
PlayerListLayout.FillDirection = Enum.FillDirection.Vertical
PlayerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
PlayerListLayout.Parent = PlayerList
PlayerListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    PlayerList.CanvasSize = UDim2.new(0, 0, 0, PlayerListLayout.AbsoluteContentSize.Y)
end)

--// 2. LOGIC //--
local Following = false
local CurrentTarget = nil
local LastTargetPosition = nil

local function GetPlayer(String)
    if not String or String == "" then return nil end
    String = String:lower()
    for _, Plr in pairs(Players:GetPlayers()) do
        if Plr ~= LocalPlayer then
            if Plr.Name:lower():match(String) or Plr.DisplayName:lower():match(String) then
                return Plr
            end
        end
    end
    return nil
end

local function MoveTo(Position)
    local Char = LocalPlayer.Character
    if Char then
        local Hum = Char:FindFirstChild("Humanoid")
        if Hum then
            Hum:MoveTo(Position)
        end
    end
end

local function refreshPlayerList()
    for _, child in ipairs(PlayerList:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(1, 0, 0, 22)
            button.Text = player.DisplayName .. " (@" .. player.Name .. ")"
            button.TextSize = 12
            button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            button.TextColor3 = Color3.fromRGB(255, 255, 255)
            button.BorderSizePixel = 0
            button.Parent = PlayerList

            button.MouseButton1Click:Connect(function()
                NameInput.Text = player.Name
                StatusLabel.Text = "Selected: " .. player.DisplayName
            end)
        end
    end

    PlayerList.CanvasSize = UDim2.new(0, 0, 0, PlayerListLayout.AbsoluteContentSize.Y)
end

local function computePath(startPos, goalPos)
    local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentJumpHeight = humanoid and humanoid.JumpHeight or 7.2,
        AgentMaxSlope = humanoid and humanoid.MaxSlopeAngle or 45,
    })

    local ok = pcall(function()
        path:ComputeAsync(startPos, goalPos)
    end)

    if not ok or path.Status ~= Enum.PathStatus.Success then
        return nil
    end

    return path
end

local function followWaypoints(path, myChar)
    local humanoid = myChar:FindFirstChild("Humanoid")
    local targetChar = CurrentTarget and CurrentTarget.Character
    if not humanoid or not targetChar then return false end

    local interrupted = false
    local connection
    connection = path.Blocked:Connect(function()
        interrupted = true
        LastTargetPosition = nil
    end)

    local waypoints = path:GetWaypoints()
    for i, waypoint in ipairs(waypoints) do
        if not Following or not CurrentTarget or interrupted then break end
        if i == 1 then continue end

        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
        end

        humanoid:MoveTo(waypoint.Position)

        local finished = humanoid.MoveToFinished:Wait()
        if not finished then
            interrupted = true
            break
        end
    end

    if connection then connection:Disconnect() end
    return interrupted
end

local function FollowLogic()
    while Following and CurrentTarget do
        local MyChar = LocalPlayer.Character
        local TargetChar = CurrentTarget.Character

        if MyChar and TargetChar and MyChar:FindFirstChild("HumanoidRootPart") and TargetChar:FindFirstChild("HumanoidRootPart") then
            local MyRoot = MyChar.HumanoidRootPart
            local TargetRoot = TargetChar.HumanoidRootPart
            local Dist = (MyRoot.Position - TargetRoot.Position).Magnitude

            if Dist > 4 then -- Only move if further than 4 studs
                StatusLabel.Text = "Computing Path..."
                local shouldRecompute = not LastTargetPosition or (TargetRoot.Position - LastTargetPosition).Magnitude > 5
                LastTargetPosition = TargetRoot.Position

                if shouldRecompute then
                    local path = computePath(MyRoot.Position, TargetRoot.Position)
                    if path then
                        StatusLabel.Text = "Moving..."
                        local interrupted = followWaypoints(path, MyChar)
                        if interrupted then
                            StatusLabel.Text = "Path blocked, recalculating..."
                        end
                    else
                        StatusLabel.Text = "Path failed, direct move"
                        MyChar.Humanoid:MoveTo(TargetRoot.Position)
                    end
                end
            else
                StatusLabel.Text = "Near Target"
                MyChar.Humanoid:MoveTo(MyRoot.Position) -- Stop
            end
        else
            StatusLabel.Text = "Target/Character Missing"
        end
        task.wait(0.25)
    end
end

--// 3. BUTTONS //--

StartBtn.MouseButton1Click:Connect(function()
    if Following then return end
    
    local TargetName = NameInput.Text
    local Plr = GetPlayer(TargetName)
    
    if Plr then
        CurrentTarget = Plr
        Following = true
        LastTargetPosition = nil
        StatusLabel.Text = "Locked: " .. Plr.DisplayName
        task.spawn(FollowLogic)
    else
        StatusLabel.Text = "Player not found!"
    end
end)

StopBtn.MouseButton1Click:Connect(function()
    Following = false
    CurrentTarget = nil
    StatusLabel.Text = "Stopped"
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position)
    end
end)

refreshPlayerList()
Players.PlayerAdded:Connect(refreshPlayerList)
Players.PlayerRemoving:Connect(refreshPlayerList)
