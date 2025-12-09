-- Roblox follower script with simple GUI and pathfinding for Xeno Executor
-- Place in your executor; creates a small draggable UI to follow a player by name

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- UI setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FollowHelper"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Parent to CoreGui (preferred for executor scripts) and fall back to PlayerGui
local function safeParent(gui)
    pcall(function()
        gui.Parent = game:GetService("CoreGui")
    end)
    if not gui.Parent then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 220, 0, 120)
frame.Position = UDim2.new(1, -230, 1, -130)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
frame.BorderColor3 = Color3.fromRGB(80, 80, 90)
frame.Active = true
frame.Draggable = true
frame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -10, 0, 20)
title.Position = UDim2.new(0, 5, 0, 5)
title.Text = "Follow Bot"
title.TextColor3 = Color3.new(1, 1, 1)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = frame

local input = Instance.new("TextBox")
input.Size = UDim2.new(1, -10, 0, 30)
input.Position = UDim2.new(0, 5, 0, 30)
input.PlaceholderText = "Spielername oder Teil"
input.Text = ""
input.TextColor3 = Color3.new(1, 1, 1)
input.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
input.BorderColor3 = Color3.fromRGB(80, 80, 90)
input.ClearTextOnFocus = false
input.Font = Enum.Font.Gotham
input.TextSize = 14
input.Parent = frame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -10, 0, 16)
statusLabel.Position = UDim2.new(0, 5, 1, -21)
statusLabel.Text = "Bereit"
statusLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
statusLabel.BackgroundTransparency = 1
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.Parent = frame

local startButton = Instance.new("TextButton")
startButton.Size = UDim2.new(0.48, -10, 0, 30)
startButton.Position = UDim2.new(0, 5, 0, 70)
startButton.Text = "Start/Resume"
startButton.TextColor3 = Color3.new(1, 1, 1)
startButton.BackgroundColor3 = Color3.fromRGB(50, 120, 70)
startButton.BorderColor3 = Color3.fromRGB(80, 80, 90)
startButton.Font = Enum.Font.GothamBold
startButton.TextSize = 14
startButton.Parent = frame

local stopButton = Instance.new("TextButton")
stopButton.Size = UDim2.new(0.48, -10, 0, 30)
stopButton.Position = UDim2.new(0.52, 5, 0, 70)
stopButton.Text = "Stop"
stopButton.TextColor3 = Color3.new(1, 1, 1)
stopButton.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
stopButton.BorderColor3 = Color3.fromRGB(80, 80, 90)
stopButton.Font = Enum.Font.GothamBold
stopButton.TextSize = 14
stopButton.Parent = frame

safeParent(screenGui)

-- Follow logic
local running = false
local currentThread

local function setStatus(text)
    statusLabel.Text = text
end

local function getHumanoidRoot(character)
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart")
end

local function findTarget(query)
    if not query or query == "" then
        return nil
    end
    query = query:lower()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local name = plr.Name:lower()
            local display = (plr.DisplayName or ""):lower()
            if name:find(query, 1, true) or display:find(query, 1, true) then
                return plr
            end
        end
    end
    return nil
end

local function stopFollowing()
    running = false
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:Move(Vector3.zero)
        humanoid:ChangeState(Enum.HumanoidStateType.Idle)
    end
    setStatus("Gestoppt")
end

local function followTargetLoop(query)
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")

    running = true
    setStatus("Suche...")

    while running do
        local targetPlayer = findTarget(query)
        local targetRoot = targetPlayer and getHumanoidRoot(targetPlayer.Character)

        if not targetPlayer or not targetRoot then
            setStatus("Ziel nicht gefunden")
            RunService.Heartbeat:Wait()
            continue
        end

        setStatus("Folge " .. targetPlayer.DisplayName)

        local path = PathfindingService:CreatePath({
            AgentCanJump = true,
            AgentHeight = humanoid.HipHeight + humanoid.HipWidth,
        })

        path:ComputeAsync(rootPart.Position, targetRoot.Position)

        if path.Status == Enum.PathStatus.Success then
            local waypoints = path:GetWaypoints()
            for index = 2, #waypoints do
                if not running then
                    break
                end

                local waypoint = waypoints[index]
                if waypoint.Action == Enum.PathWaypointAction.Jump then
                    humanoid.Jump = true
                end

                humanoid:MoveTo(waypoint.Position)

                local reached = false
                local connection
                connection = humanoid.MoveToFinished:Connect(function(result)
                    reached = result
                end)

                while running and not reached do
                    -- Recompute if target moved significantly
                    if (targetRoot.Position - waypoint.Position).Magnitude > 12 then
                        connection:Disconnect()
                        break
                    end
                    RunService.Heartbeat:Wait()
                end

                if connection.Connected then
                    connection:Disconnect()
                end

                if not reached then
                    break
                end

                if not running then
                    break
                end
            end
        else
            setStatus("Pfad fehlgeschlagen")
            task.wait(0.3)
        end

        task.wait(0.25)
    end
    currentThread = nil
end

startButton.MouseButton1Click:Connect(function()
    if running then
        setStatus("Läuft bereits")
        return
    end

    local query = input.Text
    if not query or query == "" then
        setStatus("Bitte Namen eingeben")
        return
    end

    currentThread = coroutine.create(function()
        followTargetLoop(query)
    end)
    coroutine.resume(currentThread)
end)

stopButton.MouseButton1Click:Connect(stopFollowing)

LocalPlayer.CharacterRemoving:Connect(function()
    stopFollowing()
end)

setStatus("Bereit")
