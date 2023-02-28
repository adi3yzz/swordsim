if game.PlaceId == 7026949294 then
		-- Frequently-Used Services
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local CollectionService = game:GetService("CollectionService")
		local GroupService = game:GetService("GroupService")
		local Workspace = game:GetService("Workspace")
		local Players = game:GetService("Players")
		
		-- Reference Variables for Auto Daily Rewards
		local GroupReward = CollectionService:GetTagged("DailyGroupRewardsZone")[1].Countdown.CountdownUI.Frame.Countdown
		local RankReward = CollectionService:GetTagged("RankRewardZone")[1].Countdown.CountdownUI.Frame.Countdown
		
		-- Frequently-Used Variables
		local Modules = ReplicatedStorage.Saturn.Modules
		local GameDependent = Modules.GameDependent
		local LocalPlayer = Players.LocalPlayer
		local PlayerGui = LocalPlayer.PlayerGui
		local Events = ReplicatedStorage.Events
		local HRP = LocalPlayer.Character.HumanoidRootPart
		local radius = 10.4
		
		-- Event Variables
		local CheckDungeon = Events.GetDungeonData
		local HitEvent = ReplicatedStorage.Remotes.Gameplay.FireHit
		local EggEvent = ReplicatedStorage.Remotes.Gameplay.RequestPetPurchase
		
		-- Important Folders
		local ItemMessageFolder = PlayerGui.MessagesUI.Frame
		local Worlds = Workspace.Worlds
		local Mobs = Workspace.Mobs
		
		-- Frequently Used Module Tables
		local PlayerData = require(Modules.Client["PlayerData - Client"]).Replica.Data.Main
		local PetsModule = require(GameDependent.Storage.PetsModule)
		local WeaponsModule = require(GameDependent.WeaponsModule)
		local Boosts = require(GameDependent.BoostsCalculator)
		local Zones = require(GameDependent.Zones)
		
		--[[ All the below values can be changed mid-game ]]
		
		-- Edit these variables here
		_G.MAX_ZONE = PlayerData.CurrentZone	-- not currently important
		_G.TARGET = "AutumnPaladin"		-- focus attacks to a specific target
		_G.ZONE_TO_FARM = "22"			-- farm a specific zone
		_G.EGG = "Autumn Egg 2"		-- Egg to automatically hatch
		
		-- Edit these toggles
		_G.IGNORE_ITEM_MESSAGES = true		-- will remove all weapons obtained from appearing on the screen
		_G.PRINT_REWARDS_DATA = false		-- will print any rewards claimed through any auto-rewards module
		_G.PRINT_DUNGEON_DATA = true  		-- prints when dungeons are ready and auras obtained from completed dungeons
		_G.PRINT_WEAPON_DATA = true		-- prints mythical weapons obtained from mobs
		
		_G.FARM_DUNGEON = false		-- auto farm dungon
		_G.JOIN_DUNGEON = false -- may only want to use in private servers
		
		_G.FARM_SPECIFIC = false	
		_G.FARM_EGGS = true
		_G.FARM_BOSS = false
		_G.FARM_MAX = true
		_G.ACTIVE = false	-- all mob-farming (not including dungeon-farming) is off when _G.ACTIVE = false
		
		-- creates a table of all teleports for ease of access
		local Zone_Mobs, Teleports = table.create(#Zones, ''), table.create(#Zones, "")
		for i,v in next, Zones do Teleports[i] = v.ZoneSpawn end    -- Teleport positions
		
		-- local table of all Zones and their respective Mobs
		for i,v in next, Zones do 
			Zone_Mobs[i] = {}
		    for _, c in next, v.Mobs do 
		        if c.Quantity == 1 and not table.find(Zone_Mobs[i], tostring(c.Model)) then 
		            table.insert(Zone_Mobs[i], "Boss"..tostring(c.Model))
		        else 
		            table.insert(Zone_Mobs[i], tostring(c.Model))
		        end
		    end
		end
		
		-- fills Zone_Mobs folders from EventMobs ModuleScript
		if Modules.Shared:FindFirstChild("EventMobs") then	
		--   EventZone = Vector3.new(2625.792236328125, 98.40699005126935, -154.94354248046875)	
			for _,v in next, require(Modules.Shared["EventMobs"]) do
				for _,c in next, v do 
					if c.Quantity == 1 and not table.find(Zone_Mobs[1], tostring(c.Model)) then 	
						table.insert(Zone_Mobs[1], "Boss"..tostring(c.Model))	
					else 	
						table.insert(Zone_Mobs[1], tostring(c.Model))	
					end	
				end
		    end	
		end
		
		-- (1) grabs current Mob Folder & current Boss
		local Folder,Boss = "Other",nil;
		if #Mobs:GetChildren() > 1 then 
		    for _, v in next, Mobs:GetChildren() do
		        if v.Name ~= "Other" then Folder = v.Name
		            for _,c in next, Zone_Mobs[tonumber(v.Name)] do
		                if string.sub(c, 1, 4) == "Boss" then Boss = string.sub(c, 5) end
		            end 
		        end
		    end
		end
		
		-- (1) makes all incoming item pop-ups on the screen invisible if indicated (_G.IGNORE_ITEM_MESSAGES is true)
		-- (2) prints the aura and its' percent gained from a completed dungeon if indicated (_G.PRINT_DUNGEON_DATA is true)
		ItemMessageFolder.ChildAdded:Connect(function(child)
		    if child.Name == "Frame" then
		        if _G.IGNORE_ITEM_MESSAGES then task.delay(0,function() child.Visible = false end) end
		        if _G.PRINT_WEAPON_DATA then
		            local WeaponName = child.ViewportFrame:FindFirstChildOfClass("Model").Name
		            if WeaponsModule[WeaponName].Rarity == "Mythical" then 
		                print("Obtained Mythical", WeaponName)
		            end
		        end
		    end
			if _G.PRINT_DUNGEON_DATA and child.Name == "TextLabel" then 
				for _,v in next, GameDependent.Elements:GetChildren() do
					if string.match(child.Text, "%)") and string.match(child.Text, v.Name) then
						print(child.Text) 
					end
				end
			end 
		end)
		
		-- Updates the boss found in NewFolder w.r.t Zone_Mobs
		local function updateBoss(NewFolder)
			Folder = NewFolder.Name
		    for _,v in next, Zone_Mobs[tonumber(NewFolder.Name)] do
		        if string.sub(v, 1, 4) == "Boss" then 
		            local BossName = string.sub(v, 5)
		            if Mobs:WaitForChild(NewFolder.Name):WaitForChild(BossName):WaitForChild("HumanoidRootPart", 15) then
		                Boss = BossName;break
		            end
				end
		    end	
		end
		
		-- Signals to update "Boss" as the player enters a new zone
		PlayerGui.ChildAdded:Connect(function(NewInstance)
			if NewInstance.Name == "Transition" then
			    local temp = _G.ACTIVE; _G.ACTIVE = false
			    repeat wait(1) until not PlayerGui:FindFirstChild("Transition") -- waits until transition is gone (zone is loaded)
		        if #Mobs:GetChildren() > 1 then                                 -- called third
		            for i,v in next, Mobs:GetChildren() do
		                if v.Name ~= "Other" then updateBoss(v);break end
		            end 
		        end _G.ACTIVE = temp
			end
		end)
		Mobs.ChildAdded:Connect(function(NewFolder)                             -- called second
		    if not PlayerGui:FindFirstChild("Transition") then updateBoss(NewFolder) end
		end)
		Mobs.ChildRemoved:Connect(function() Folder = "Other";Boss = nil end)   -- called first
		
		-- fills EventPets and EventWeapons with corresponding data
		local EventPets,EventWeapons = {},{}
		for i,v in next, PetsModule do if v["Tags"] then table.insert(EventPets, i) end end
		for i,v in next, WeaponsModule do if v["Tags"] then table.insert(EventWeapons, i) end end
		
		-- gathers bets items of Type - Pet,Weapon - and equips those items 
		-- only Event items are iterated upon is Event = true
		local function fillBest(Type, Event)
		    local Items,Values = table.create(PlayerData[Type.."Equips"], ''),table.create(PlayerData[Type.."Equips"], -1)
		    local Calculator,EventItems,EquippedItems,Index = Boosts["Calculate"..Type.."Boosts"],nil,{},1    
		    
			-- sets general variables based on input type
		    if Type == "Pet" then 
		        EquippedItems,EventItems = PlayerData.EquippedItems.Pets,EventPets	
		    else
		    	for i,_ in next, PlayerData.EquippedItems.Weapons do table.insert(EquippedItems, i) end 	-- gathers equipped weapons
		    	EventItems = EventWeapons
		    end
		    
			-- loops through storage of item "Type"
		    for i,v in next, PlayerData[Type..'s'] do 
		        if Event and not table.find(EventItems, v.Base) then continue end
			-- calculates relative power of item read ("a" is invalid for "Pet" Type, "num" is invalid for "Weapon" Type)
		        local num,a = Calculator(i,v);if a ~= 0 then num = a end	
				
			for x=1,Index do
		            if Values[x] < num then
		                if Values[Index] < Values[x] then 
					Values[Index],Items[Index] = Values[x],Items[x] 
				end Values[x],Items[x] = num,i
		                for c=1,#Values do
		                    if Values[c] < Values[Index] then 
		                        Index = c
		                    end
		                end
		                break
		            end
		        end
		    end
			
		    for _,v in next, Items do
		        if not table.find(EquippedItems, v) then 
		            Events.EquipItem:InvokeServer(Type..'s', EquippedItems)    -- unequip Current items
		            delay(2, function() Events.EquipItem:InvokeServer(Type..'s', Items) end)
		            return
		        end 
		    end
		end
		
		local function inGroup(GroupID)
			local Groups = GroupService:GetGroupsAsync(LocalPlayer.UserId)
			if #Groups == 0 then 
				return false
			else
				for _,v in next, Groups do
					if GroupID == v.Id then
						return true
					end
				end
			end
			return false
		end
		
		-- funciton for claiming 
		local function claimRewards(Text, Bool)
			if Bool then
				if not inGroup(11109344) then
					print("Not in Tachyon Roblox Group, so group rewards can not be claimed.")
					print("Group rewards will be claimed if you join mid-game.")
					repeat wait(1) until inGroup(11109344)
				end
				-- if not AutoClaimGroupRewards then repeat wait(1) until AutoClaimGroupRewards end
				delay(2, function() 
					Events.ClaimGroupDailyReward:InvokeServer() 
					if _G.PRINT_REWARDS_DATA then print("Claimed Group Rewards") end
				end)
			else
				-- if not AutoClaimRankReward then repeat wait(1) until AutoClaimRankReward end
				delay(2, function() 
					Events.ClaimRankReward:InvokeServer()
					if _G.PRINT_REWARDS_DATA then print("Claimed Rank Rewards") end
				end)
			end
		end
		
		local function autosInit()
		
		    -- Initializing automatic playtime rewards
		    local Playtimes = PlayerGui.Rewards.Main.Frame
		    local P_Count = #Playtimes:GetChildren()
		
		    if P_Count > 1 then
		        for i = 12 - P_Count, 10 do
		            local inst = Playtimes[tostring(i)], nil
			    if inst.TimeLeft.Text ~= "CLICK TO CLAIM" then
				inst.TimeLeft:GetPropertyChangedSignal("TextColor3"):Once(function()
		            if inst.TimeLeft.Text == "CLICK TO CLAIM" then
		    	        Events.GiveStayReward:FireServer(i)
						if _G.PRINT_REWARDS_DATA then print("Claimed Playtime reward", i) end
		    	        delay(3, function() inst:Destroy() end)
		            end
				end)
		            else 
		                Events.GiveStayReward:FireServer(i)
						if _G.PRINT_REWARDS_DATA then print("Claimed Playtime reward", i) end
		                delay(3, function() inst:Destroy() end)
		            end
		        end
		    end
		    
			-- for playtime rewards that are added mid-game
		    Playtimes.ChildAdded:Connect(function(child)
		        child.TimeLeft:GetPropertyChangedSignal("TextColor3"):Once(function()
			    child:WaitForChild("TimeLeft")
		            if child.TimeLeft.Text == "CLICK TO CLAIM" then
		                Events.GiveStayReward:FireServer(tonumber(child.Name))
						if _G.PRINT_REWARDS_DATA then print("Claimed Playtime reward", child.Name) end
		                delay(3, function() child:Destroy() end)
		            end
		        end)
		    end)
		
		    -- Initializing automatic Daily rewards
		    local Daily = PlayerGui.Main.Top.DailyRewards.UnClaimed
		    if Daily.Visible then Events.ClaimDailyReward:InvokeServer()
				if _G.PRINT_REWARDS_DATA then print("Collected Daily Rewards") end
			end
		    
		    Daily:GetPropertyChangedSignal("Visible"):Connect(function()
		        if Daily.Visible then Events.ClaimDailyReward:InvokeServer()
					if _G.PRINT_REWARDS_DATA then print("Collected Daily Rewards") end
				end 
		    end)
		
		    -- Initializing automatic Rank and Group rewards
			task.delay(1, function() 
				GroupReward:GetPropertyChangedSignal("Text"):Connect(function() 
					if GroupReward.Text == "Ready" then claimRewards(true) end 
				end)
			end)
			task.delay(1, function() 
				RankReward:GetPropertyChangedSignal("Text"):Connect(function() 
					if RankReward.Text == "Ready" then claimRewards() end
				end)
			end)
			
			if GroupReward.Text == "Ready" then claimRewards(true) end
			if RankReward.Text == "Ready" then claimRewards() end
		
		    -- Initializing automatic Index rewards
		    local Index, Types = PlayerGui.PetIndex.Main, {"Weapon", "Pet"}
		    
		    for _,v in next, Types do
		        local Counter = Index[v.."IndexRewards"].Counter
		        if Counter.Text ~= "Completed" then
		            local Button = Index[v.."IndexRewards"].Claim
		            for i = 1, 20 do  Events.IndexCompleted:FireServer(v);wait() end
		            delay(1, function()
		                if Counter.Text ~= "Completed" then
		                    local connection
		                    connection = Button:GetPropertyChangedSignal("Visible"):Connect(function()
		                        if Button.Visible then 
		                            Events.IndexCompleted:FireServer(v)
		                            if _G.PRINT_REWARDS_DATA then print("Claimed", v, "Index") end
					    Button.Visible = false
		                        end
		                        delay(1, function() 
		                            if Counter.Text == "Completed" then connection:Disconnect() end
		                        end)
		                    end)
		                end
		            end)
		        end
		    end
		    
		    -- Automatic Zone and Teleport purchases
		    local TeleportButtons = PlayerGui.Teleports.Main.ListFrame
		    
		    if _G.MAX_ZONE < #Zones then
		        
			-- set to false if you do not want the doors and teleports to be automatically purchased
		        _G.PURCHASE_DOORS = true
		        _G.PURCHASE_TELEPORTS = true
		        
		        task.spawn(function()
		            while wait(1) do
		                for i=2, #Zones-1 do
		                    if _G.PURCHASE_DOORS and Worlds["Zone"..i]:FindFirstChild("PurchaseNewZone") then
		                        if PlayerData.Coins >= Zones[i + 1].Cost.Coins then 
		                            Events.PurchaseZone:InvokeServer()
		                            _G.MAX_ZONE = _G.MAX_ZONE + 1
		                            if _G.FARM_MAX then _G.ZONE_TO_FARM = tostring(_G.MAX_ZONE) end
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
		
		-- gathers all elements (this is an efficient way to grab all player auras, but I dont think I have implemented any use yet)
		local ElementInventory = {}
		for _,v in next, GameDependent.Elements:GetChildren() do ElementInventory[v.Name] = 0 end
		for _,v in next, PlayerData.AuraInventory do ElementInventory[v.Base] = ElementInventory[v.Base] + 1 end
		
		-- sphere-part that attacks mobs when they are within the radius of the sphere
		local HitDetector = Instance.new('Part', game:GetService("Workspace"))
		HitDetector.Name = 'Cylinder'
		HitDetector.Shape = "Ball"
		HitDetector.Size = Vector3.new(radius, radius, radius)
		HitDetector.Color = Color3.fromRGB(0.6392157077789307, 0.6352941393852234, 0.6470588445663452)
		HitDetector.BrickColor = BrickColor.new(0.6392157077789307, 0.6352941393852234, 0.6470588445663452)
		HitDetector.Material = Enum.Material['Plastic']
		HitDetector.Transparency = 1
		HitDetector.Reflectance = 0
		HitDetector.CanCollide = false
		HitDetector.Anchored = false
		HitDetector.Locked = false
		
		-- module which deals the damage to the mobs when they touch the sphere-part
		HitDetector.Touched:Connect(function(Hit)
			if _G.ACTIVE then
				if Hit.Name == "HumanoidRootPart" and not table.find(game.Players:GetPlayers(), Hit.Parent.Name) then 
					local Succ,Text = pcall(function() return Hit.Parent.Head.ExtraData.RedBar.Health end)
					if Succ and Text.text ~= "0 Health" then 
						HitEvent:FireServer(nil, Hit.Parent, Hit.Position)
					end
				end
			end
		end)
		
		-- teleports HitDetector to the user as long as HitDetector is valid
		local signal = nil
		signal = game:GetService("RunService").RenderStepped:Connect(function()
		    if HitDetector then
		        HitDetector.Position = Vector3.new(HRP.Position.x, HRP.Position.y, HRP.Position.z)
		    else signal:Disconnect() end
		end)
		
		-- Auto Dungeon
		task.spawn(function()
			while wait(1) do
				while (os.time() < PlayerData.LastDungeonEnter + 3600) and not (_G.JOIN_DUNGEON and CheckDungeon:InvokeServer() == "Starting") or CheckDungeon:InvokeServer() == "Begun"  do wait(1) end		-- waits until dungeon is ready
				if _G.PRINT_DUNGEON_DATA then print("Dungeon is ready") end
				while not _G.FARM_DUNGEON do wait(1) end		-- when dungeon is ready, waits until dungeon farming is active
		        
		            	    -- (1) Starts Dungeon
		        	wait(2)    
		        	Events.EnterDungeon:InvokeServer()
				wait(2)
		    
		            	    -- (2) Store current variable data
		        	local Currents,CurrentWeps = {_G.FARM_MAX, _G.ZONE_TO_FARM, _G.FARM_BOSS, _G.FARM_SPECIFIC, _G.ACTIVE, HRP.CFrame, ElementInventory}, {}
				for i,_ in next, PlayerData.EquippedItems.Weapons do table.insert(CurrentWeps, i) end
				
				    -- (3) Equip best weapons for Dungeon
				fillBest("Weapon", false)
				
				    -- (4) Disable potentially inflicting variables
				_G.ACTIVE, _G.FARM_MAX, _G.FARM_BOSS, _G.FARM_SPECIFIC, _G.ZONE_TO_FARM = false, false, false, false, "Other"
				wait(4)
				
				    -- (5) Teleport user to dungeon loading zone
				HRP.CFrame = CFrame.new(-3401, 136.290268, 468, 1, -3.82670748e-08, -3.79028059e-12, 3.82670748e-08, 1, 6.93830984e-08, 3.78762516e-12, -6.93830984e-08, 1)
				HRP.Anchored = true; wait(2); HRP.Anchored = false
				
				    -- (6) enable farming
		        	_G.ACTIVE = true
				
				    -- (7) wait until dungeon is complete
				repeat wait(1) until CheckDungeon:InvokeServer() == "Ready"
		
				    -- (8) Disable farming and teleport user to previous location
				_G.ACTIVE = false;HRP.CFrame = Currents[6];HRP.Anchored = true
		
				    -- (9) Unequip current weapons then equip previous weapons
				local tables={}
				for i,_ in next, PlayerData.EquippedItems.Weapons do table.insert(tables, i) end
				Events.EquipItem:InvokeServer("Weapons", tables)	      -- unequip current weapons
				wait(1);Events.EquipItem:InvokeServer("Weapons", CurrentWeps) -- equip previous weapons
				HRP.Anchored = false
		        
			           -- (10) re-assign variables
				_G.FARM_MAX, _G.ZONE_TO_FARM, _G.FARM_BOSS, _G.FARM_SPECIFIC, _G.ACTIVE,_,_ = table.unpack(Currents)
			end
		end)
		
		-- Auto Eggs
		task.spawn(function()
		    while wait(3) do if _G.FARM_EGGS then
		        if not PlayerData.Gamepasses["40355989"] then 
		            EggEvent:InvokeServer(_G.EGG, "Hatch")
		        else break end end
		    end print("Hatching 3")
		    while wait(3) do if _G.FARM_EGGS then EggEvent:InvokeServer(_G.EGG, "Hatch3") end end
		end)
		
		-- Include Boss	
		switch = false	
		task.spawn(function()	
		    while wait(0.1) do	
		        pcall(function()	
		            if _G.ACTIVE and _G.FARM_BOSS and Boss and Mobs[Folder][Boss].Head.ExtraData.RedBar.Health.Text ~= "0 Health" then 	
				local BOSS = Mobs[Folder][Boss]; switch = true	
		                local _,text = pcall(function() return BOSS.Head.ExtraData.RedBar.Health end)
		                while _G.ACTIVE and _G.FARM_BOSS and text.Text ~= "0 Health" do	
		                    if (HRP.Position - BOSS.HumanoidRootPart.Position).Magnitude >= 8 then 
		                        HRP.CFrame = BOSS.HumanoidRootPart.CFrame 
		                    end wait(0.1)	
		                end switch = false	
		            end 	
		        end) 	
		    end	
		end)
		
		-- Auto Farm Specific & General
		task.spawn(function()
		    while wait() do
		        if not _G.ACTIVE or switch then repeat wait() until _G.ACTIVE and not switch end
		    	pcall(function()
		    		if Folder ~= _G.ZONE_TO_FARM then   -- "Folder" is current zone
		    		    HRP.CFrame = CFrame.new(Teleports[tonumber(_G.ZONE_TO_FARM)])
		    		    HRP.Anchored = true;wait(1);HRP.Anchored = false
		    		end
		    	end)
		        for _,c in ipairs(Mobs[Folder]:GetChildren()) do 
		            local succ,text = pcall(function() return c.Head.ExtraData.RedBar.Health end)
		            if not succ or switch or text.Text == "0 Health" or c.Name == Boss then continue else
		                pcall(function()
		                    if not _G.FARM_SPECIFIC then
		                        while _G.ACTIVE and not switch and text.Text ~= "0 Health" do
		                            if (HRP.Position - c.HumanoidRootPart.Position).Magnitude >= 5 then 
		                                HRP.CFrame = c.HumanoidRootPart.CFrame 
		                            end wait(0.1)
		                        end 
		                    else    
		                        if c.Name == _G.TARGET then
		                            while _G.ACTIVE and _G.FARM_SPECIFIC and not switch and text.Text ~= "0 Health" do
		                                if (HRP.Position - c.HumanoidRootPart.Position).Magnitude >= 5 then 
		                                    HRP.CFrame = c.HumanoidRootPart.CFrame 
		                                end wait(0.1)
		                            end
		                        end 
		                    end
		                end) 
		                if not _G.ACTIVE or switch then break end
		            end
		        end
		    end
		end)
else
	print("Hello World")
end