local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "AutoBuy Suite",
    LoadingTitle = "AutoBuy Suite",
    LoadingSubtitle = "by you",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "AutoBuy",
        FileName = "Config"
    },
    KeySystem = false,
})

local MiscTab = Window:CreateTab("Misc", "shopping-cart")

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local plr = localPlayer

local AutoKillActive = false
local AutoHealActive = false
local BuyingActive = false

local function NewConnection(signal, func)
    return signal:Connect(func)
end

local function cleanGunName(gun)
    return gun:gsub("[%[%]]", "")
end

local function GetInventoryAmmo(gunName)
    local inv = localPlayer:FindFirstChild("DataFolder")
        and localPlayer.DataFolder:FindFirstChild("Inventory")
    if not inv then return 0 end
    local cleanName = cleanGunName(gunName)
    local ammo = inv:FindFirstChild(cleanName .. " Ammo")
    return ammo and tonumber(ammo.Value) or 0
end

local function getAmmoKey(gun)
    return "[" .. cleanGunName(gun) .. " Ammo]"
end

local headshots = {}
headshots.AutoLoadout = {
    Enabled = false,
    Guns = {},
    Queue = {},
    CurrentBuying = nil,
}

local ShopTable = {}

local function BuildShopTable()
    ShopTable = {}
    local ok, shopFolder = pcall(function()
        return workspace:WaitForChild("Ignored", 5):WaitForChild("Shop", 5)
    end)
    if not ok or not shopFolder then return end

    for _, shop in pairs(shopFolder:GetChildren()) do
        if shop:FindFirstChild("Head") then
            local head = shop.Head
            local shopName = shop.Name

            local gui = head:FindFirstChildWhichIsA("BillboardGui")
                or head:FindFirstChildWhichIsA("SurfaceGui")
            if gui then
                local lbl = gui:FindFirstChildWhichIsA("TextLabel")
                if lbl and lbl.Text ~= "" then
                    shopName = lbl.Text
                end
            end

            local lbl2 = head:FindFirstChildWhichIsA("TextLabel")
            if lbl2 then
                shopName = lbl2.Text
            end

            local key = shopName:match("^(%[.-%])")
            if key then
                local ammoKey = shopName:match("(%[.-%sAmmo%])")
                if ammoKey then key = ammoKey end
                ShopTable[key] = { ShopName = shopName }
            else
                ShopTable[shopName] = { ShopName = shopName }
            end
        end
    end
end

BuildShopTable()

task.spawn(function()
    while task.wait(30) do
        BuildShopTable()
    end
end)

MiscTab:CreateSection("Auto Loadout")

MiscTab:CreateToggle({
    Name = "Autobuy Gun",
    CurrentValue = false,
    Flag = "AutoBuyGunAmmo",
    Callback = function(Value)
        headshots.AutoLoadout.Enabled = Value
        if not Value then
            headshots.AutoLoadout.Queue = {}
            headshots.AutoLoadout.CurrentBuying = nil
            BuyingActive = false
        end
    end,
})

MiscTab:CreateDropdown({
    Name = "Select Guns",
    Options = {
        "[Rifle]","[LMG]","[Flintlock]","[AK47]","[AUG]",
        "[Flamethrower]","[Double-Barrel SG]","[Drum-Shotgun]",
        "[DrumGun]","[Glock]","[P90]","[RPG]","[Revolver]",
        "[Silencer]","[SilencerAR]","[Shotgun]","[SMG]",
        "[TacticalShotgun]","[Taser]"
    },
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "AutoLoadoutGun",
    Callback = function(Value)
        headshots.AutoLoadout.Guns = Value
    end,
})

NewConnection(RunService.Heartbeat, function()
    local char = localPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not hrp then return end

    pcall(function()
        if headshots.AutoLoadout.Enabled then
            if not headshots.AutoLoadout.CurrentBuying then
                if #headshots.AutoLoadout.Queue == 0 then
                    for _, gun in ipairs(headshots.AutoLoadout.Guns) do
                        local hasGun = char:FindFirstChild(gun)
                            or localPlayer.Backpack:FindFirstChild(gun)

                        if not hasGun then
                            if ShopTable[gun] then
                                table.insert(headshots.AutoLoadout.Queue, {
                                    type = "gun",
                                    name = gun
                                })
                            end
                        else
                            local invAmmo = GetInventoryAmmo(gun)
                            if invAmmo < 30 then
                                local ammoKey = getAmmoKey(gun)
                                if ShopTable[ammoKey] then
                                    for i = 1, 3 do
                                        table.insert(headshots.AutoLoadout.Queue, {
                                            type = "ammo",
                                            gun = gun
                                        })
                                    end
                                end
                            end
                        end
                    end
                end

                if #headshots.AutoLoadout.Queue > 0 then
                    headshots.AutoLoadout.CurrentBuying =
                        table.remove(headshots.AutoLoadout.Queue, 1)
                    BuyingActive = true
                end
            end
        end

        if headshots.AutoLoadout.CurrentBuying then
            local item = headshots.AutoLoadout.CurrentBuying
            local lookupKey =
                item.type == "gun" and item.name or getAmmoKey(item.gun)

            local shopEntry = ShopTable[lookupKey]
            if not shopEntry then
                headshots.AutoLoadout.CurrentBuying = nil
                BuyingActive = false
                return
            end

            local shop = workspace.Ignored.Shop:FindFirstChild(shopEntry.ShopName)
            if shop and shop:FindFirstChild("Head") then
                local saved = hrp.CFrame
                hrp.CFrame = shop.Head.CFrame
                hrp.Velocity = Vector3.zero
                hrp.AssemblyLinearVelocity = Vector3.zero

                RunService:BindToRenderStep("RestoreAutoBuy", 199, function()
                    hrp.CFrame = saved
                    RunService:UnbindFromRenderStep("RestoreAutoBuy")
                end)

                local tool = char:FindFirstChildOfClass("Tool")
                if tool then tool.Parent = localPlayer.Backpack end

                local cd = shop:FindFirstChildOfClass("ClickDetector")
                if cd then fireclickdetector(cd) end
            end

            BuyingActive = false
            headshots.AutoLoadout.CurrentBuying = nil
        end
    end)
end)

MiscTab:CreateSection("Auto Ammo")

local AutoAmmoEnabled = false

MiscTab:CreateToggle({
    Name = "Auto Ammo",
    CurrentValue = false,
    Flag = "AutoAmmoEnabled",
    Callback = function(Value)
        AutoAmmoEnabled = Value
    end,
})

local function getCurrentGun()
    local tool = localPlayer.Character
        and localPlayer.Character:FindFirstChildOfClass("Tool")
    return tool and tool.Name or nil
end

local function findAmmoItemInShop(gunName)
    local ok, shopFolder = pcall(function()
        return workspace:WaitForChild("Ignored", 5):WaitForChild("Shop", 5)
    end)
    if not ok or not shopFolder then return nil end

    local clean = cleanGunName(gunName)

    for _, item in ipairs(shopFolder:GetChildren()) do
        if item:IsA("Model")
            and item:FindFirstChild("Head")
            and item.Name:find(clean .. " Ammo", 1, true) then
            return item
        end
    end
    return nil
end

local function buyAmmoForGun(gunName)
    local ammoItem = findAmmoItemInShop(gunName)
    if not ammoItem then return end

    local hrp = localPlayer.Character
        and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local savedPos = hrp.CFrame
    local currentTool =
        localPlayer.Character:FindFirstChildOfClass("Tool")
    if currentTool then currentTool.Parent = localPlayer.Backpack end

    hrp.CFrame = ammoItem.Head.CFrame
    hrp.Velocity = Vector3.zero
    hrp.AssemblyLinearVelocity = Vector3.zero

    local cd = ammoItem:FindFirstChild("ClickDetector")
    if cd then fireclickdetector(cd) end

    hrp.CFrame = savedPos
    if currentTool then currentTool.Parent = localPlayer.Character end
end

local function checkAmmoAndBuy()
    if not AutoAmmoEnabled then return end
    local gunName = getCurrentGun()
    if not gunName then return end

    local ammoCount = GetInventoryAmmo(gunName)
    if ammoCount <= 0 then
        buyAmmoForGun(gunName)
    end
end

NewConnection(RunService.Heartbeat, function()
    pcall(checkAmmoAndBuy)
end)

MiscTab:CreateButton({
    Name = "Buy Ammo for All Guns",
    Callback = function()
        local guns = {}
        local char = plr.Character

        local function collectGuns(parent)
            for _, item in ipairs(parent:GetChildren()) do
                if item:IsA("Tool") and item.Name:match("%[.+%]") then
                    local g = cleanGunName(item.Name)
                    if g ~= "" and not table.find(guns, g) then
                        table.insert(guns, g)
                    end
                end
            end
        end

        collectGuns(plr.Backpack)
        if char then collectGuns(char) end

        if #guns == 0 then
            Rayfield:Notify({
                Title = "Auto Ammo",
                Content = "No guns found in backpack!",
                Duration = 5
            })
            return
        end

        local shopFolder = workspace.Ignored:FindFirstChild("Shop")
        if not shopFolder then return end

        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local savedPos = hrp.CFrame

        for _, gunName in ipairs(guns) do
            for _, item in ipairs(shopFolder:GetChildren()) do
                if item.Name:find(gunName .. " Ammo", 1, true)
                    and item:FindFirstChild("ClickDetector")
                    and item:FindFirstChild("Head") then

                    hrp.CFrame = item.Head.CFrame
                    hrp.Velocity = Vector3.zero
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    task.wait(0.2)
                    fireclickdetector(item.ClickDetector)

                    RunService:BindToRenderStep("RestoreAutoBuyAmmo", 199, function()
                        hrp.CFrame = savedPos
                        RunService:UnbindFromRenderStep("RestoreAutoBuyAmmo")
                    end)

                    task.wait(0.2)
                    break
                end
            end
        end

        Rayfield:Notify({
            Title = "Auto Ammo",
            Content = "Ammo buying complete!",
            Duration = 5
        })
    end,
})

Rayfield:Notify({
    Title = "AutoBuy Suite",
    Content = "Loaded successfully!",
    Duration = 5,
})
