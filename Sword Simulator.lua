if game.PlaceId == 7026949294 then

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local PlayerGui, Worlds = game:GetService("Players").LocalPlayer.PlayerGui, game:GetService("Workspace").Worlds
	local Events, Remotes = ReplicatedStorage.Events, ReplicatedStorage.Remotes

	local HitEvent, EggEvent = Remotes.Gameplay.FireHit, Remotes.Gameplay.RequestPetPurchase
	local Mobs, HRP = Workspace.Mobs, game.Players.LocalPlayer.Character.HumanoidRootPart

	local PlayerData = require(ReplicatedStorage.Saturn.Modules.Client["PlayerData - Client"]).Replica.Data.Main
	local Zones = require(ReplicatedStorage.Saturn.Modules.GameDependent.Zones)

	_G.TARGET = "AutumnlandPaladin"
	_G.ZONE_TO_FARM = "22"
	_G.EGG = "Autumnland Egg 2"
	_G.MAX_ZONE = #Zones

	_G.FARM_EGGS = true
	_G.FARM_DUNGEON = true
	_G.FARM_SPECIFIC = false
	_G.FARM_BOSS = false
	_G.FARM_MAX = false
	_G.ACTIVE = true

	-- get current max zone
	for i=2, #Zones-1 do if Workspace.Worlds["Zone"..i]:FindFirstChild("PurchaseNewZone") then _G.MAX_ZONE = i;break end end

	-- creates a table of all teleports for ease of access
	local Zone_Mobs, Teleports = table.create(2*#Zones, ""), table.create(#Zones, "")
	for i,v in next, Zones do Teleports[i] = v.ZoneSpawn end    -- Teleport positions

	-- local table of all Zones and their respective Mobs
	for i,v in next, Zones do 
	    Zone_Mobs[2*i - 1] = i
	    Zone_Mobs[2*i] = {}
	    for _, c in next, v.Mobs do 
		if c.Quantity == 1 then 
		    table.insert(Zone_Mobs[2*i], "Boss"..tostring(c.Model))
		else 
		    table.insert(Zone_Mobs[2*i], tostring(c.Model))
		end
	    end
	end

	-- (1) grabs current Mob Folder
	local Folder, Boss = "Other", nil;
	if #Workspace.Mobs:GetChildren() > 1 then 
	    table.foreach(Workspace.Mobs:GetChildren(), function(_, v)
		if v.Name ~= "Other" then Folder = v.Name
		    for _,c in next, Zone_Mobs[2*tonumber(v.Name)] do
			if string.sub(c, 1, 4) == "Boss" then Boss = string.sub(c, 5) end
		    end 
		end
	    end)
	end

	-- (2) Signal function to update local variables "Folder" and "Boss" at detected Mob Folder changes
	Workspace.Mobs.ChildAdded:Connect(function(NewFolder) 
	    Folder = NewFolder.Name
	    for _,v in next, Zone_Mobs[2*tonumber(NewFolder.Name)] do
		if string.sub(v, 1, 4) == "Boss" then Boss = string.sub(v, 5);break end
	    end 
	end) 

	Workspace.Mobs.ChildRemoved:Connect(function() Folder = "Other";Boss = nil end)


	local function autosInit()

	    -- Initializing automatic playtime rewards
	    local Playtimes = PlayerGui.Rewards.Main.Frame
	    local P_Count = #Playtimes:GetChildren()

	    if P_Count > 1 then
		for i = 12 - P_Count, 10 do
		    local inst, connection = Playtimes[tostring(i)], nil
			    if inst.TimeLeft.Text ~= "CLICK TO CLAIM" then
				    connection = inst.TimeLeft:GetPropertyChangedSignal("Text"):Connect(function()
			    if inst.TimeLeft.Text == "CLICK TO CLAIM" then
				Events.GiveStayReward:FireServer(i);print("Claimed Playtime reward", i)
				delay(3, function() inst:Destroy() end)
				connection:Disconnect()
			    end
				    end)
		    else 
			Events.GiveStayReward:FireServer(i);print("Claimed Playtime reward", i)
			delay(3, function() inst:Destroy() end)
		    end
		end
	    end

	    Playtimes.ChildAdded:Connect(function(child)
		local connection
		connection = child.TimeLeft:GetPropertyChangedSignal("Text"):Connect(function()
			child:WaitForChild("TimeLeft")
		    if child.TimeLeft.Text == "CLICK TO CLAIM" then
			Events.GiveStayReward:FireServer(12 - #Playtimes:GetChildren());print("Claimed Playtime reward", 12 - #Playtimes:GetChildren())
			delay(3, function() child:Destroy() end)
			connection:Disconnect()
		    end
		end)
	    end)


	    -- Initializing automatic Daily rewards
	    local Daily = PlayerGui.Main.Top.DailyRewards.UnClaimed
	    if Daily.Visible then Events.ClaimDailyReward:InvokeServer();print("Collected Daily Rewards") end

	    Daily:GetPropertyChangedSignal("Visible"):Connect(function()
		if Daily.Visible then Events.ClaimDailyReward:InvokeServer();print("Collected Daily Rewards") end 
	    end)

	    -- Initializing automatic Rank and Group rewards
	    Events.ClaimGroupDailyReward:InvokeServer() -- attempt to force group rewards

	    delay(5, function()
		task.spawn(function()
			while wait(1) do
				if os.time() > PlayerData.LastClaimedRankReward+36000 then Events.ClaimRankReward:InvokeServer();print("Collected Rank Reward") end
				if PlayerData["LastClaimedGroupReward"] and os.time() > PlayerData.LastClaimedGroupReward+36000 then 
				    Events.ClaimGroupDailyReward:InvokeServer();print("Collected Group Rewards") 
				end
			end
		end)
	    end)

	    -- Initializing automatic Index rewards
	    local Index, Types = PlayerGui.PetIndex.Main, {"Weapon", "Pet"}

	    for _,v in next, Types do
		local Counter = Index[v.."IndexRewards"].Counter
		if Counter.Text ~= "Completed" then
		    local Button = Index[v.."IndexRewards"].Claim
		    while Button.Visible do 
			Events.IndexCompleted:FireServer(v);wait() 
			print("Claimed", v, "Index")
		    end
		    delay(1, function()
			if Counter.Text ~= "Completed" then
			    local connection
			    connection = Button:GetPropertyChangedSignal("Visible"):Connect(function()
				if Button.Visible then 
				    Events.IndexCompleted:FireServer(v)
				    print("Claimed", v, "Index")
				end
				delay(1, function() 
				    if Counter.Text == "Completed" then connection:Disconnect() end
				end)
			    end)
			end
		    end)
		end
	    end


	    -- Initializing automatic Achievement rewards
	    local Achieve, Types = PlayerGui.Achievements.Main.ListFrame, {"Defeat", "Eggs", "Coins"}
	    local Numerals = {"I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV"}

	    for _,v in next, Types do
		if Achieve[v].Progress.Text ~= "Completed" then
		    if Achieve[v].Use.Visible then 
			for i = table.find(Numerals, string.sub(Achieve[v].Title.Text, string.len(v) + 2)), 14 do
			    Events.AchievementCompleted:FireServer(v);print("Claimed", v, "Achievement");wait() 
			end
		    end Achieve[v].Use.Visible = false
		    delay(1, function()
			if Achieve[v].Progress.Text ~= "Completed" then
			    local connection
			    connection = Achieve[v].Use:GetPropertyChangedSignal("Visible"):Connect(function()
				if Achieve[v].Use.Visible then Events.AchievementCompleted:FireServer(v);print("Claimed", v, "Achievement") end
				Achieve[v].Use.Visible = false
				delay(1, function()
				     if Achieve[v].Progress.Text == "Completed" then connection:Disconnect() end
				end)
			    end)
			end
		    end)
		end
	    end

	    -- Automatic Zone and Teleport purchases
	    local TeleportButtons = game.Players.LocalPlayer.PlayerGui.Teleports.Main.ListFrame

	    if _G.MAX_ZONE < #Zones then

		-- set to false if you do not want the doors and teleports to be automatically purchased
		_G.PURCHASE_DOORS = true
		_G.PURCHASE_TELEPORTS = true

		task.spawn(function()
		    while wait(1) do
			for i=2, #Zones-1 do
			    if _G.PURCHASE_DOORS and Workspace.Worlds["Zone"..i]:FindFirstChild("PurchaseNewZone") then
				if PlayerData.Coins >= Zones[i + 1].Cost.Coins then 
				    Events.PurchaseZone:InvokeServer()
				    _G.MAX_ZONE = _G.MAX_ZONE + 1
				    if _G.FARM_MAX then _G.ZONE_TO_FARM = _G.MAX_ZONE end
				    if i == #Zones-1 then 
					_G.PURCHASE_DOORS = nil
					if not _G.PURCHASE_TELEPORTS then return end
				    end
				end
			    end

			    if _G.PURCHASE_TELEPORTS and TeleportButtons[i]:FindFirstChild("Cost") then
				if PlayerData.Gems >= Zones[i].TeleportCost.Gems then 
				    Events.PurchaseTeleport:InvokeServer(i) 
				    if i == #Zones-1 then 
					_G.PURCHASE_TELEPORTS = nil
					if not _G.PURCHASE_DOORS then return end
				    end
				end
			    end
			end
		    end
		end)
	    end
	end

	autosInit()

	-- Include Boss
	switch = false
	task.spawn(function()
	    while wait(0.1) do
		pcall(function()
		    if _G.ACTIVE and _G.FARM_BOSS and Boss and Mobs[Folder][Boss].Head.ExtraData.RedBar.Health.Text ~= "0 Health" then 
			_G.ACTIVE = false;local _,text = pcall(function() return Mobs[Folder][Boss].Head.ExtraData.RedBar.Health end)
			HRP.CFrame = Mobs[Folder][Boss].HumanoidRootPart.CFrame
			while _G.FARM_BOSS and text.Text ~= "0 Health" do
			    if (HRP.Position - Mobs[Folder][Boss].HumanoidRootPart.Position).Magnitude >= 8 then HRP.CFrame = Mobs[Folder][Boss].HumanoidRootPart.CFrame end
			    HitEvent:FireServer(nil, Mobs[Folder][Boss], Mobs[Folder][Boss].HumanoidRootPart.Position);wait(0.1)
			end _G.ACTIVE = true
		    end 
		end) 
	    end
	end)

	-- Auto Dungeon
	task.spawn(function()
		while wait(1) do
			while os.time() < PlayerData.LastDungeonEnter + 3600 do wait(1) end		-- waits until dungeon is ready
			print("Dungeon is ready")
			while not _G.FARM_DUNGEON do wait(1) end		-- when dungeon is ready, waits until dungeon farming is active

			    -- (1) Starts Dungeon
			Events.EnterDungeon:InvokeServer()

			    -- (2) Store current variable data
			local i = 0; table.foreach(PlayerData.AuraInventory, function() i = i + 1 end)
			local Currents = {i, _G.ZONE_TO_FARM, _G.FARM_BOSS, _G.FARM_SPECIFIC, _G.ACTIVE}

			    -- (3) disables potentially inflicting variables
			_G.ACTIVE, _G.FARM_BOSS, _G.FARM_SPECIFIC, _G.ZONE_TO_FARM = false, false, false, "Other"
			wait(1)

			    -- (4) teleport user to dungeon loading zone
			HRP.CFrame = CFrame.new(-3401, 136.290268, 468, 1, -3.82670748e-08, -3.79028059e-12, 3.82670748e-08, 1, 6.93830984e-08, 3.78762516e-12, -6.93830984e-08, 1)
			HRP.Anchored = true; wait(2) HRP.Anchored = false 

			    -- (5) enable farming
			_G.ACTIVE = true

			    -- (6) wait until user is rewarded an Aura (dungeon is complete)
			while Currents[1] == i do                               
			    i = 0; table.foreach(PlayerData.AuraInventory, function() i = i + 1 end)
			    wait(1) 
			end	

			    -- (7) re-assign variables
			task.delay(3, function()
			    _, _G.ZONE_TO_FARM, _G.FARM_BOSS, _G.FARM_SPECIFIC, _G.ACTIVE = table.unpack(Currents)
			end)
		end
	end)

	-- Auto Eggs
	task.spawn(function()
	    while wait(3) do if _G.FARM_EGGS then
		if not PlayerData.Gamepasses["40355989"] then
		    EggEvent:InvokeServer(_G.EGG, "Hatch")
		else break end end
	    end 
	    while wait(3) do if _G.FARM_EGGS then EggEvent:InvokeServer(_G.EGG, "Hatch3") end end
	end)

	-- Auto Farm Specific & General
	task.spawn(function()
	    while wait() do
		if not _G.ACTIVE then repeat wait() until _G.ACTIVE end
		if Folder ~= _G.ZONE_TO_FARM then   -- "Folder" is current zone
		    HRP.CFrame = CFrame.new(Teleports[tonumber(_G.ZONE_TO_FARM)])
		    HRP.Anchored = true;wait(1);HRP.Anchored = false
		end
		for _,c in pairs(Mobs[Folder]:GetChildren()) do 
		    local succ,text = pcall(function() return c.Head.ExtraData.RedBar.Health end)
		    if not succ or text.Text == "0 Health" or c.Name == Boss then continue else
			pcall(function()
			    if not _G.FARM_SPECIFIC then
				HRP.CFrame = c.HumanoidRootPart.CFrame
				while _G.ACTIVE and text.Text ~= "0 Health" do
				    if (HRP.Position - c.HumanoidRootPart.Position).Magnitude >= 8 then HRP.CFrame = c.HumanoidRootPart.CFrame end
				    for _, v in next, Mobs[Folder]:GetChildren() do
					if pcall(function() return (HRP.Position - v.HumanoidRootPart.Position).Magnitude <= 12 end) then
					    HitEvent:FireServer(nil, v, v.HumanoidRootPart.Position)
					end
				    end wait(0.1)
				end
			    else    
				if c.Name == _G.TARGET then
				    HRP.CFrame = c.HumanoidRootPart.CFrame
				    while _G.ACTIVE and _G.FARM_SPECIFIC and text.Text ~= "0 Health" do
					if (HRP.Position - c.HumanoidRootPart.Position).Magnitude >= 8 then HRP.CFrame = c.HumanoidRootPart.CFrame end
					for _, v in next, Mobs[Folder]:GetChildren() do
					    if v.Name == _G.TARGET and pcall(function() return (HRP.Position - v.HumanoidRootPart.Position).Magnitude <= 12 end) then
						HitEvent:FireServer(nil, v, v.HumanoidRootPart.Position)
					    end
					end wait(0.1)
				    end
				end 
			    end
			end)
			if not _G.ACTIVE then break end
		    end
		end
	    end
	end)

else
	print("Hello World")
end
