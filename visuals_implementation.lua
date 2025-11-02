-- ========================================
-- AURORA VISUALS IMPLEMENTATION
-- ========================================
-- Modern ESP and visual effects implementation
-- High-performance rendering system
-- Advanced features and customization

-- ========================================
-- CORE VISUAL SYSTEM
-- ========================================

local VisualsCore = {
    -- Drawing objects storage
    DrawingObjects = {},
    PlayerESP = {},
    WorldESP = {},
    
    -- Performance tracking
    LastUpdate = 0,
    UpdateRate = 1/60,
    
    -- Optimization settings
    MaxDistance = 1000,
    OptimizeDistance = true,
    
    -- ESP Components
    Components = {
        "Box", "BoxFilled", "HealthBar", "HealthText", "Name", 
        "Distance", "Weapon", "Armor", "Skeleton", "Tracer", 
        "OffScreen", "Chams", "Glow"
    }
}

-- ========================================
-- DRAWING UTILITIES
-- ========================================

local DrawingUtil = {
    -- Create optimized drawing object
    CreateDrawing = function(self, type, properties)
        local obj = Drawing.new(type)
        
        -- Apply default properties
        local defaults = {
            Visible = false,
            Transparency = 1,
            Color = Color3.fromRGB(255, 255, 255),
            Thickness = 1,
            Size = 13,
            Font = Drawing.Fonts.Plex,
            Center = true,
            Outline = true
        }
        
        -- Apply defaults first
        for prop, value in pairs(defaults) do
            if obj[prop] ~= nil then
                obj[prop] = value
            end
        end
        
        -- Apply custom properties
        if properties then
            for prop, value in pairs(properties) do
                if obj[prop] ~= nil then
                    obj[prop] = value
                end
            end
        end
        
        -- Store for cleanup
        table.insert(VisualsCore.DrawingObjects, obj)
        return obj
    end,
    
    -- Clean up drawing object
    CleanupDrawing = function(self, obj)
        if obj then
            obj.Visible = false
            obj:Remove()
        end
    end,
    
    -- Get screen position
    GetScreenPosition = function(self, worldPos)
        local screenPos, onScreen = camera:WorldToViewportPoint(worldPos)
        return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
    end,
    
    -- Calculate 2D bounding box
    Calculate2DBox = function(self, character)
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            return nil
        end
        
        local rootPart = character.HumanoidRootPart
        local humanoid = character:FindFirstChild("Humanoid")
        
        if not humanoid then return nil end
        
        -- Get character bounds
        local cf = rootPart.CFrame
        local size = rootPart.Size
        
        -- Calculate corners
        local corners = {
            cf * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2),
            cf * CFrame.new(size.X/2, -size.Y/2, -size.Z/2),
            cf * CFrame.new(-size.X/2, size.Y/2, -size.Z/2),
            cf * CFrame.new(size.X/2, size.Y/2, -size.Z/2),
            cf * CFrame.new(-size.X/2, -size.Y/2, size.Z/2),
            cf * CFrame.new(size.X/2, -size.Y/2, size.Z/2),
            cf * CFrame.new(-size.X/2, size.Y/2, size.Z/2),
            cf * CFrame.new(size.X/2, size.Y/2, size.Z/2)
        }
        
        -- Project to screen
        local screenCorners = {}
        local allOnScreen = true
        
        for i, corner in ipairs(corners) do
            local screenPos, onScreen = self:GetScreenPosition(corner.Position)
            screenCorners[i] = screenPos
            if not onScreen then
                allOnScreen = false
            end
        end
        
        if not allOnScreen then return nil end
        
        -- Find bounding box
        local minX, minY = math.huge, math.huge
        local maxX, maxY = -math.huge, -math.huge
        
        for _, pos in ipairs(screenCorners) do
            minX = math.min(minX, pos.X)
            minY = math.min(minY, pos.Y)
            maxX = math.max(maxX, pos.X)
            maxY = math.max(maxY, pos.Y)
        end
        
        return {
            TopLeft = Vector2.new(minX, minY),
            BottomRight = Vector2.new(maxX, maxY),
            Size = Vector2.new(maxX - minX, maxY - minY),
            Center = Vector2.new((minX + maxX) / 2, (minY + maxY) / 2)
        }
    end
}

-- ========================================
-- ESP SYSTEM
-- ========================================

local ESPSystem = {
    -- Create ESP for player
    CreatePlayerESP = function(self, player)
        if VisualsCore.PlayerESP[player] then
            return VisualsCore.PlayerESP[player]
        end
        
        local esp = {
            Player = player,
            Objects = {},
            LastUpdate = 0,
            
            -- Drawing objects
            Box = DrawingUtil:CreateDrawing("Square"),
            BoxFilled = DrawingUtil:CreateDrawing("Square", {Filled = true}),
            BoxOutline = DrawingUtil:CreateDrawing("Square", {Color = Color3.fromRGB(0, 0, 0), Thickness = 3}),
            
            HealthBarBG = DrawingUtil:CreateDrawing("Square", {Filled = true, Color = Color3.fromRGB(0, 0, 0)}),
            HealthBar = DrawingUtil:CreateDrawing("Square", {Filled = true, Color = Color3.fromRGB(0, 255, 0)}),
            HealthText = DrawingUtil:CreateDrawing("Text"),
            
            NameText = DrawingUtil:CreateDrawing("Text"),
            DistanceText = DrawingUtil:CreateDrawing("Text"),
            WeaponText = DrawingUtil:CreateDrawing("Text"),
            ArmorText = DrawingUtil:CreateDrawing("Text"),
            
            Tracer = DrawingUtil:CreateDrawing("Line"),
            
            -- Skeleton parts
            Skeleton = {},
            
            -- Off-screen indicator
            OffScreenArrow = DrawingUtil:CreateDrawing("Triangle", {Filled = true}),
            
            -- Update function
            Update = function(self)
                if not self.Player or not self.Player.Character then
                    self:SetVisible(false)
                    return
                end
                
                local character = self.Player.Character
                local humanoid = character:FindFirstChild("Humanoid")
                local rootPart = character:FindFirstChild("HumanoidRootPart")
                
                if not humanoid or not rootPart then
                    self:SetVisible(false)
                    return
                end
                
                -- Check distance
                local distance = (rootPart.Position - camera.CFrame.Position).Magnitude
                if distance > Flags["ESP_MaxDistance"] then
                    self:SetVisible(false)
                    return
                end
                
                -- Check team
                if Flags["ESP_TeamCheck"] and self.Player.Team == LocalPlayer.Team then
                    local isTeam = true
                    self:UpdateESP(character, humanoid, rootPart, distance, isTeam)
                else
                    local isTeam = false
                    self:UpdateESP(character, humanoid, rootPart, distance, isTeam)
                end
            end,
            
            -- Update ESP elements
            UpdateESP = function(self, character, humanoid, rootPart, distance, isTeam)
                local prefix = isTeam and "Team_" or "Enemy_"
                
                -- Calculate 2D box
                local box = DrawingUtil:Calculate2DBox(character)
                if not box then
                    self:SetVisible(false)
                    return
                end
                
                -- Update box
                if Flags[prefix .. "Boxes"] then
                    self:UpdateBox(box, prefix)
                else
                    self.Box.Visible = false
                    self.BoxOutline.Visible = false
                end
                
                -- Update filled box
                if Flags[prefix .. "BoxFilled"] then
                    self:UpdateFilledBox(box, prefix)
                else
                    self.BoxFilled.Visible = false
                end
                
                -- Update health bar
                if Flags[prefix .. "HealthBar"] then
                    self:UpdateHealthBar(box, humanoid, prefix)
                else
                    self.HealthBar.Visible = false
                    self.HealthBarBG.Visible = false
                end
                
                -- Update health text
                if Flags[prefix .. "HealthText"] then
                    self:UpdateHealthText(box, humanoid, prefix)
                else
                    self.HealthText.Visible = false
                end
                
                -- Update name
                if Flags[prefix .. "Names"] then
                    self:UpdateName(box, self.Player, prefix)
                else
                    self.NameText.Visible = false
                end
                
                -- Update distance
                if Flags[prefix .. "Distance"] then
                    self:UpdateDistance(box, distance, prefix)
                else
                    self.DistanceText.Visible = false
                end
                
                -- Update weapon
                if Flags[prefix .. "Weapon"] then
                    self:UpdateWeapon(box, character, prefix)
                else
                    self.WeaponText.Visible = false
                end
                
                -- Update tracer
                if Flags[prefix .. "Tracers"] then
                    self:UpdateTracer(rootPart, prefix)
                else
                    self.Tracer.Visible = false
                end
                
                -- Update skeleton
                if Flags[prefix .. "Skeleton"] then
                    self:UpdateSkeleton(character, prefix)
                else
                    self:HideSkeleton()
                end
            end,
            
            -- Update box
            UpdateBox = function(self, box, prefix)
                self.BoxOutline.Visible = Flags["ESP_BoxOutline"]
                self.BoxOutline.Position = box.TopLeft
                self.BoxOutline.Size = box.Size
                
                self.Box.Visible = true
                self.Box.Position = box.TopLeft
                self.Box.Size = box.Size
                self.Box.Color = Flags[prefix .. "BoxColor"]
                self.Box.Thickness = Flags["ESP_BoxThickness"]
                self.Box.Transparency = Flags["ESP_BoxTransparency"]
            end,
            
            -- Update filled box
            UpdateFilledBox = function(self, box, prefix)
                self.BoxFilled.Visible = true
                self.BoxFilled.Position = box.TopLeft
                self.BoxFilled.Size = box.Size
                self.BoxFilled.Color = Flags[prefix .. "BoxFilledColor"]
                self.BoxFilled.Transparency = Flags[prefix .. "BoxFilledTransparency"] or 0.8
            end,
            
            -- Update health bar
            UpdateHealthBar = function(self, box, humanoid, prefix)
                local healthPercent = humanoid.Health / humanoid.MaxHealth
                local barWidth = 4
                local barHeight = box.Size.Y
                
                -- Background
                self.HealthBarBG.Visible = true
                self.HealthBarBG.Position = Vector2.new(box.TopLeft.X - barWidth - 2, box.TopLeft.Y)
                self.HealthBarBG.Size = Vector2.new(barWidth, barHeight)
                self.HealthBarBG.Color = Color3.fromRGB(0, 0, 0)
                self.HealthBarBG.Transparency = 0.5
                
                -- Health bar
                self.HealthBar.Visible = true
                self.HealthBar.Position = Vector2.new(box.TopLeft.X - barWidth - 2, box.TopLeft.Y + barHeight * (1 - healthPercent))
                self.HealthBar.Size = Vector2.new(barWidth, barHeight * healthPercent)
                
                -- Color based on health
                if Flags[prefix .. "HealthGradient"] then
                    local r = math.floor(255 * (1 - healthPercent))
                    local g = math.floor(255 * healthPercent)
                    self.HealthBar.Color = Color3.fromRGB(r, g, 0)
                else
                    self.HealthBar.Color = healthPercent > 0.5 and Flags[prefix .. "HealthHigh"] or Flags[prefix .. "HealthLow"]
                end
            end,
            
            -- Update health text
            UpdateHealthText = function(self, box, humanoid, prefix)
                self.HealthText.Visible = true
                self.HealthText.Position = Vector2.new(box.TopLeft.X - 20, box.Center.Y)
                self.HealthText.Text = tostring(math.floor(humanoid.Health))
                self.HealthText.Size = Flags["ESP_TextSize"]
                self.HealthText.Font = Drawing.Fonts[Flags["ESP_TextFont"]]
                self.HealthText.Color = Color3.fromRGB(255, 255, 255)
                self.HealthText.Outline = Flags["ESP_TextOutline"]
            end,
            
            -- Update name
            UpdateName = function(self, box, player, prefix)
                self.NameText.Visible = true
                self.NameText.Position = Vector2.new(box.Center.X, box.TopLeft.Y - 20)
                
                local name = player.DisplayName ~= player.Name and player.DisplayName or player.Name
                if Flags["ESP_TextCase"] == "UPPERCASE" then
                    name = string.upper(name)
                elseif Flags["ESP_TextCase"] == "lowercase" then
                    name = string.lower(name)
                end
                
                self.NameText.Text = name
                self.NameText.Size = Flags["ESP_TextSize"]
                self.NameText.Font = Drawing.Fonts[Flags["ESP_TextFont"]]
                self.NameText.Color = Flags[prefix .. "NameColor"]
                self.NameText.Outline = Flags["ESP_TextOutline"]
            end,
            
            -- Update distance
            UpdateDistance = function(self, box, distance, prefix)
                self.DistanceText.Visible = true
                self.DistanceText.Position = Vector2.new(box.Center.X, box.BottomRight.Y + 5)
                self.DistanceText.Text = tostring(math.floor(distance)) .. "m"
                self.DistanceText.Size = Flags["ESP_TextSize"]
                self.DistanceText.Font = Drawing.Fonts[Flags["ESP_TextFont"]]
                self.DistanceText.Color = Flags[prefix .. "DistanceColor"]
                self.DistanceText.Outline = Flags["ESP_TextOutline"]
            end,
            
            -- Update weapon
            UpdateWeapon = function(self, box, character, prefix)
                local weapon = character:FindFirstChild("Gun")
                if weapon then
                    self.WeaponText.Visible = true
                    self.WeaponText.Position = Vector2.new(box.Center.X, box.BottomRight.Y + 20)
                    self.WeaponText.Text = weapon.Name
                    self.WeaponText.Size = Flags["ESP_TextSize"]
                    self.WeaponText.Font = Drawing.Fonts[Flags["ESP_TextFont"]]
                    self.WeaponText.Color = Flags[prefix .. "WeaponColor"]
                    self.WeaponText.Outline = Flags["ESP_TextOutline"]
                else
                    self.WeaponText.Visible = false
                end
            end,
            
            -- Update tracer
            UpdateTracer = function(self, rootPart, prefix)
                local screenPos, onScreen = DrawingUtil:GetScreenPosition(rootPart.Position)
                if not onScreen then
                    self.Tracer.Visible = false
                    return
                end
                
                local origin
                local tracerOrigin = Flags[prefix .. "TracerOrigin"] or "Bottom"
                
                if tracerOrigin == "Bottom" then
                    origin = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
                elseif tracerOrigin == "Center" then
                    origin = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
                elseif tracerOrigin == "Top" then
                    origin = Vector2.new(camera.ViewportSize.X / 2, 0)
                elseif tracerOrigin == "Mouse" then
                    origin = Vector2.new(Mouse.X, Mouse.Y)
                else
                    origin = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
                end
                
                self.Tracer.Visible = true
                self.Tracer.From = origin
                self.Tracer.To = screenPos
                self.Tracer.Color = Flags[prefix .. "TracerColor"]
                self.Tracer.Thickness = 1
                self.Tracer.Transparency = 1
            end,
            
            -- Update skeleton
            UpdateSkeleton = function(self, character, prefix)
                -- Skeleton implementation would go here
                -- This is a simplified version
                local connections = {
                    {"Head", "UpperTorso"},
                    {"UpperTorso", "LowerTorso"},
                    {"UpperTorso", "LeftUpperArm"},
                    {"UpperTorso", "RightUpperArm"},
                    {"LeftUpperArm", "LeftLowerArm"},
                    {"RightUpperArm", "RightLowerArm"},
                    {"LowerTorso", "LeftUpperLeg"},
                    {"LowerTorso", "RightUpperLeg"},
                    {"LeftUpperLeg", "LeftLowerLeg"},
                    {"RightUpperLeg", "RightLowerLeg"}
                }
                
                -- Create skeleton lines if they don't exist
                while #self.Skeleton < #connections do
                    table.insert(self.Skeleton, DrawingUtil:CreateDrawing("Line"))
                end
                
                -- Update skeleton lines
                for i, connection in ipairs(connections) do
                    local part1 = character:FindFirstChild(connection[1])
                    local part2 = character:FindFirstChild(connection[2])
                    
                    if part1 and part2 and self.Skeleton[i] then
                        local pos1, onScreen1 = DrawingUtil:GetScreenPosition(part1.Position)
                        local pos2, onScreen2 = DrawingUtil:GetScreenPosition(part2.Position)
                        
                        if onScreen1 and onScreen2 then
                            self.Skeleton[i].Visible = true
                            self.Skeleton[i].From = pos1
                            self.Skeleton[i].To = pos2
                            self.Skeleton[i].Color = Flags[prefix .. "SkeletonColor"]
                            self.Skeleton[i].Thickness = 1
                            self.Skeleton[i].Transparency = 1
                        else
                            self.Skeleton[i].Visible = false
                        end
                    else
                        if self.Skeleton[i] then
                            self.Skeleton[i].Visible = false
                        end
                    end
                end
            end,
            
            -- Hide skeleton
            HideSkeleton = function(self)
                for _, line in ipairs(self.Skeleton) do
                    line.Visible = false
                end
            end,
            
            -- Set all objects visible/invisible
            SetVisible = function(self, visible)
                for _, obj in pairs(self.Objects) do
                    if obj and obj.Visible ~= nil then
                        obj.Visible = visible
                    end
                end
                
                -- Individual objects
                self.Box.Visible = visible
                self.BoxFilled.Visible = visible
                self.BoxOutline.Visible = visible
                self.HealthBar.Visible = visible
                self.HealthBarBG.Visible = visible
                self.HealthText.Visible = visible
                self.NameText.Visible = visible
                self.DistanceText.Visible = visible
                self.WeaponText.Visible = visible
                self.ArmorText.Visible = visible
                self.Tracer.Visible = visible
                self.OffScreenArrow.Visible = visible
                
                for _, line in ipairs(self.Skeleton) do
                    line.Visible = visible
                end
            end,
            
            -- Cleanup
            Destroy = function(self)
                self:SetVisible(false)
                
                -- Clean up all drawing objects
                for _, obj in pairs(self.Objects) do
                    DrawingUtil:CleanupDrawing(obj)
                end
                
                DrawingUtil:CleanupDrawing(self.Box)
                DrawingUtil:CleanupDrawing(self.BoxFilled)
                DrawingUtil:CleanupDrawing(self.BoxOutline)
                DrawingUtil:CleanupDrawing(self.HealthBar)
                DrawingUtil:CleanupDrawing(self.HealthBarBG)
                DrawingUtil:CleanupDrawing(self.HealthText)
                DrawingUtil:CleanupDrawing(self.NameText)
                DrawingUtil:CleanupDrawing(self.DistanceText)
                DrawingUtil:CleanupDrawing(self.WeaponText)
                DrawingUtil:CleanupDrawing(self.ArmorText)
                DrawingUtil:CleanupDrawing(self.Tracer)
                DrawingUtil:CleanupDrawing(self.OffScreenArrow)
                
                for _, line in ipairs(self.Skeleton) do
                    DrawingUtil:CleanupDrawing(line)
                end
            end
        }
        
        VisualsCore.PlayerESP[player] = esp
        return esp
    end,
    
    -- Remove ESP for player
    RemovePlayerESP = function(self, player)
        local esp = VisualsCore.PlayerESP[player]
        if esp then
            esp:Destroy()
            VisualsCore.PlayerESP[player] = nil
        end
    end,
    
    -- Update all ESP
    UpdateAll = function(self)
        if not Flags["ESP_Master"] then
            -- Hide all ESP
            for player, esp in pairs(VisualsCore.PlayerESP) do
                esp:SetVisible(false)
            end
            return
        end
        
        -- Update existing ESP
        for player, esp in pairs(VisualsCore.PlayerESP) do
            if player and player.Parent then
                esp:Update()
            else
                self:RemovePlayerESP(player)
            end
        end
        
        -- Create ESP for new players
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and not VisualsCore.PlayerESP[player] then
                self:CreatePlayerESP(player)
            end
        end
    end
}

-- ========================================
-- CHAMS SYSTEM
-- ========================================

local ChamsSystem = {
    ChamsObjects = {},
    
    -- Create chams for player
    CreateChams = function(self, player)
        if self.ChamsObjects[player] then
            return
        end
        
        local chams = {
            Player = player,
            Objects = {},
            
            Update = function(self)
                if not self.Player or not self.Player.Character then
                    self:SetVisible(false)
                    return
                end
                
                local character = self.Player.Character
                local isTeam = self.Player.Team == LocalPlayer.Team
                local prefix = isTeam and "Team_" or "Enemy_"
                
                if Flags[prefix .. "Chams"] then
                    self:UpdateChams(character, prefix)
                else
                    self:SetVisible(false)
                end
            end,
            
            UpdateChams = function(self, character, prefix)
                for _, part in ipairs(character:GetChildren()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        local chamsObj = self.Objects[part]
                        
                        if not chamsObj then
                            chamsObj = Instance.new("BoxHandleAdornment")
                            chamsObj.Adornee = part
                            chamsObj.AlwaysOnTop = true
                            chamsObj.ZIndex = 1
                            chamsObj.Size = part.Size
                            chamsObj.Parent = part
                            
                            self.Objects[part] = chamsObj
                        end
                        
                        -- Update properties
                        chamsObj.Visible = true
                        chamsObj.Color3 = Flags[prefix .. "ChamsVisible"]
                        chamsObj.Transparency = Flags[prefix .. "ChamsTransparency"] or 0.3
                        
                        -- Material effect (simplified)
                        local material = Flags[prefix .. "ChamsMaterial"]
                        if material == "Neon" then
                            chamsObj.Color3 = chamsObj.Color3:lerp(Color3.fromRGB(255, 255, 255), 0.3)
                        end
                    end
                end
            end,
            
            SetVisible = function(self, visible)
                for _, obj in pairs(self.Objects) do
                    if obj then
                        obj.Visible = visible
                    end
                end
            end,
            
            Destroy = function(self)
                for _, obj in pairs(self.Objects) do
                    if obj then
                        obj:Destroy()
                    end
                end
                self.Objects = {}
            end
        }
        
        self.ChamsObjects[player] = chams
    end,
    
    -- Update all chams
    UpdateAll = function(self)
        for player, chams in pairs(self.ChamsObjects) do
            if player and player.Parent then
                chams:Update()
            else
                chams:Destroy()
                self.ChamsObjects[player] = nil
            end
        end
        
        -- Create chams for new players
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and not self.ChamsObjects[player] then
                self:CreateChams(player)
            end
        end
    end
}

-- ========================================
-- MAIN UPDATE LOOP
-- ========================================

local function UpdateVisuals()
    local currentTime = tick()
    
    -- Check if we should update based on update rate
    if currentTime - VisualsCore.LastUpdate < VisualsCore.UpdateRate then
        return
    end
    
    VisualsCore.LastUpdate = currentTime
    
    -- Update ESP
    ESPSystem:UpdateAll()
    
    -- Update Chams
    ChamsSystem:UpdateAll()
    
    -- Update other visual effects here
    -- (Glow, bullet tracers, etc.)
end

-- Connect to render loop
RunService.Heartbeat:Connect(UpdateVisuals)

-- ========================================
-- CLEANUP ON PLAYER LEAVE
-- ========================================

Players.PlayerRemoving:Connect(function(player)
    ESPSystem:RemovePlayerESP(player)
    
    if ChamsSystem.ChamsObjects[player] then
        ChamsSystem.ChamsObjects[player]:Destroy()
        ChamsSystem.ChamsObjects[player] = nil
    end
end)

-- ========================================
-- INITIALIZATION
-- ========================================

print("Aurora Visuals Implementation Loaded")
print("ESP System: Active")
print("Chams System: Active")
print("Performance: Optimized rendering enabled")

-- Initialize ESP for existing players
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        ESPSystem:CreatePlayerESP(player)
        ChamsSystem:CreateChams(player)
    end
end