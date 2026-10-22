-- ============================================
-- LIBRARY SOURCE
-- ============================================
-- Put your own raw URL here if you host library.lua yourself, for example:
--   local MyLibraryURL = "https://raw.githubusercontent.com/you/repo/main/library.lua"
-- It is tried first. If it fails (HTTP error, HTML page instead of raw Lua,
-- compile error), the next entry is tried, so the menu still starts.
local MyLibraryURL = nil

local LibraryURLs = {}

if type(MyLibraryURL) == "string" and #MyLibraryURL > 0 then
    LibraryURLs[#LibraryURLs + 1] = MyLibraryURL
end

LibraryURLs[#LibraryURLs + 1] = "https://raw.githubusercontent.com/BUSDANSTETE/lua/main/library.lua"

local LibraryCode = nil
local LastError = "no source"

for i = 1, #LibraryURLs do
    local url = LibraryURLs[i]
    local called, httpStatus, body = pcall(Susano.HttpGet, url)

    if not called then
        LastError = "HttpGet unavailable: " .. tostring(httpStatus)
        print("[Menu] " .. LastError)
    elseif httpStatus ~= 200 then
        LastError = ("HTTP %s on %s"):format(tostring(httpStatus), url)
        print("[Menu] " .. LastError)
    elseif type(body) ~= "string" or #body < 1000 then
        LastError = ("empty body (%s bytes) from %s"):format(tostring(body and #body), url)
        print("[Menu] " .. LastError)
    else
        body = string.gsub(body, "^\239\187\191", "")

        local testChunk, testErr = load(body)
        local looksLikeLibrary = string.find(body, "Menu.ItemsPerPage", 1, true)
            or string.find(body, "Menu.DrawItem", 1, true)

        if testChunk and looksLikeLibrary then
            LibraryCode = body
            print(("[Menu] library OK: %s (%d bytes)"):format(url, #body))
            break
        elseif not testChunk then
            LastError = ("compile error from %s: %s"):format(url, tostring(testErr))
            print("[Menu] " .. LastError)
        else
            LastError = ("not the menu library: %s"):format(url)
            print("[Menu] " .. LastError)
        end
    end
end

if not LibraryCode then
    print("[Menu] no usable library: " .. LastError)

    -- Show the reason on screen instead of dying silently.
    if type(Susano) == "table" and Susano.BeginFrame and Susano.DrawText then
        CreateThread(function()
            while true do
                Wait(0)
                Susano.BeginFrame()
                Susano.DrawRectFilled(40, 40, 780, 66, 0.05, 0.05, 0.06, 0.92, 6)
                Susano.DrawText(56, 56, "[Menu] library not loaded", 18, 1.0, 0.28, 0.28, 1.0)
                Susano.DrawText(56, 78, tostring(LastError):sub(1, 110), 14, 0.95, 0.95, 0.95, 1.0)
                Susano.SubmitFrame()
            end
        end)
    end

    return
end

-- Patch OnRender
if not string.find(LibraryCode, "Menu.OnRender") then
    LibraryCode = string.gsub(LibraryCode, "if Susano%.SubmitFrame then", [[
    if Menu.OnRender then
        local success, err = pcall(Menu.OnRender)
        if not success then end
    end
    if Susano.SubmitFrame then]])
end

-- Patch ResetFrame
if string.find(LibraryCode, "Susano%.ResetFrame") then
    LibraryCode = string.gsub(LibraryCode, "if Susano%.ResetFrame then", "if Susano.ResetFrame and not Menu.PreventResetFrame then")
end

-- Strip \r from HTTP content for consistent pattern matching
LibraryCode = string.gsub(LibraryCode, "\r", "")

-- Patch tag display [RISK] (red) / [DYNASTY] (purple) (item name rendering)
LibraryCode = string.gsub(
    LibraryCode,
    'Menu%.DrawText%(textX, textY, item%.name, 19, Menu%.Colors%.TextWhite%.r / 255%.0, Menu%.Colors%.TextWhite%.g / 255%.0, Menu%.Colors%.TextWhite%.b / 255%.0, 1%.0%)',
    'Menu.DrawText(textX, textY, item.name, 19, Menu.Colors.TextWhite.r / 255.0, Menu.Colors.TextWhite.g / 255.0, Menu.Colors.TextWhite.b / 255.0, 1.0); if (item.risk or item.dynasty) and Susano and Susano.GetTextWidth then local _sc = 19 * (Menu.Scale or 1.0); local _ox = Susano.GetTextWidth(item.name, _sc); if item.risk then Menu.DrawText(textX + _ox, textY, "  [RISK]", 19, 1.0, 0.15, 0.15, 1.0); _ox = _ox + Susano.GetTextWidth("  [RISK]", _sc) end; if item.dynasty then Menu.DrawText(textX + _ox, textY, "  [DYNASTY]", 19, 0.6, 0.2, 1.0, 1.0) end end'
)

-- ============================================
-- PATCH: Category icon image + bold text shadow
-- ============================================
-- Replaces category name rendering to:
--   1. Draw icon texture (from iconUrl) left of text
--   2. Add 1px shadow for bold effect
--   3. Shift text right to make room for icon
LibraryCode = string.gsub(
    LibraryCode,
    'Menu%.DrawText%(textX, textY, category%.name, 19, Menu%.Colors%.TextWhite%.r / 255%.0, Menu%.Colors%.TextWhite%.g / 255%.0, Menu%.Colors%.TextWhite%.b / 255%.0, 1%.0%)',
    [[do
                local _iSz = itemHeight * 0.4
                local _iOk = false
                if category.iconUrl and Menu.IconTextures and Menu.IconTextures[category.name] then
                    local _t = Menu.IconTextures[category.name]
                    if _t and _t > 0 and Susano and Susano.DrawImage then
                        Susano.DrawImage(_t, x + 14, itemY + (itemHeight - _iSz) / 2, _iSz, _iSz, 1, 1, 1, 1, 0)
                        _iOk = true
                    end
                end
                local _offX = _iOk and (14 + _iSz + 8) or 16
                textX = x + _offX
                local _wr = Menu.Colors.TextWhite.r / 255.0
                local _wg = Menu.Colors.TextWhite.g / 255.0
                local _wb = Menu.Colors.TextWhite.b / 255.0
                Menu.DrawText(textX, textY, category.name, 19, _wr, _wg, _wb, 1.0)
            end]]
)

-- Chevron now uses image icon (embedded directly in library.lua)

-- ============================================
-- PATCH: Footer text + centered logo image
-- Footer text + logo are now embedded directly in library.lua

local chunk, err = load(LibraryCode)
if not chunk then
    print("[Menu] Erreur compilation: " .. tostring(err))
    return
end

local Menu = chunk()

-- ============================================
-- BOLD TEXT: Override DrawText with shadow pass
-- ============================================
-- Wraps Menu.DrawText to always draw a 1px dark shadow behind text
-- This simulates bold/weight since Susano has no font-weight API
Menu._OrigDrawText = Menu.DrawText
Menu.BoldText = false -- bold disabled for cleaner readability

function Menu.DrawText(x, y, text, size_px, r, g, b, a)
    if Menu.BoldText and a and a > 0.1 then
        -- Shadow pass: 1px right, black, 30% of original alpha
        Menu._OrigDrawText(x + 1, y, text, size_px, 0, 0, 0, (a or 1.0) * 0.3)
    end
    Menu._OrigDrawText(x, y, text, size_px, r, g, b, a)
end

-- ============================================
-- ICON TEXTURE SYSTEM
-- ============================================
-- Cache for category icon textures loaded from URLs
Menu.IconTextures = {}
Menu.FooterLogoTex = nil
Menu.FooterText = "" -- <<< CHANGE THIS to your menu name

-- Footer logo URL (small square image, ideally 64x64 or 128x128 PNG)
Menu.FooterLogoUrl = "https://i.imgur.com/jY5oSqw.png" -- <<< REPLACE with your logo URL

Menu.ArrowUpUrl = "https://i.imgur.com/CefzPfK.png"
Menu.ArrowDownUrl = "https://i.imgur.com/cEtkALw.png"
Menu.ChevronUrl = "https://i.imgur.com/qPVyVP3.png"

-- Load a single icon texture from URL, store in Menu.IconTextures[name]
function Menu.LoadIconTexture(name, url)
    if not url or url == "" then return end
    if not Susano or not Susano.HttpGet or not Susano.LoadTextureFromBuffer then return end
    if Menu.IconTextures[name] and Menu.IconTextures[name] > 0 then return end -- already loaded

    CreateThread(function()
        local ok, result = pcall(function()
            local status, body = Susano.HttpGet(url)
            if status == 200 and body and #body > 100 then
                local texId, w, h = Susano.LoadTextureFromBuffer(body)
                if texId and texId ~= 0 then
                    Menu.IconTextures[name] = texId
                    print("[Icons] Loaded: " .. name .. " (tex=" .. tostring(texId) .. ")")
                end
            else
                print("[Icons] HTTP " .. tostring(status) .. " for " .. name)
            end
        end)
        if not ok then
            print("[Icons] Error loading " .. name .. ": " .. tostring(result))
        end
    end)
end

-- Load footer logo texture
function Menu.LoadFooterLogo(url)
    if not url or url == "" or url:find("PLACEHOLDER") then return end
    if not Susano or not Susano.HttpGet or not Susano.LoadTextureFromBuffer then return end

    CreateThread(function()
        local ok, result = pcall(function()
            local status, body = Susano.HttpGet(url)
            if status == 200 and body and #body > 100 then
                local texId, w, h = Susano.LoadTextureFromBuffer(body)
                if texId and texId ~= 0 then
                    Menu.FooterLogoTex = texId
                    print("[Footer] Logo loaded (tex=" .. tostring(texId) .. ")")
                end
            end
        end)
    end)
end

-- Init: load all icon textures at startup
function Menu.LoadAllIcons()
    if not Menu.Categories then return end
    for _, cat in ipairs(Menu.Categories) do
        if cat.iconUrl and cat.iconUrl ~= "" and not cat.iconUrl:find("PLACEHOLDER") then
            Menu.LoadIconTexture(cat.name, cat.iconUrl)
        end
    end
    Menu.LoadFooterLogo(Menu.FooterLogoUrl)
    if Menu.ArrowUpUrl and Menu.ArrowUpUrl ~= "" then
        Menu.LoadIconTexture("_arrowUp", Menu.ArrowUpUrl)
    end
    if Menu.ArrowDownUrl and Menu.ArrowDownUrl ~= "" then
        Menu.LoadIconTexture("_arrowDown", Menu.ArrowDownUrl)
    end
    if Menu.ChevronUrl and Menu.ChevronUrl ~= "" then
        Menu.LoadIconTexture("_chevron", Menu.ChevronUrl)
    end
end

Menu.DrawWatermark = function() end
Menu.UpdatePlayerCount = function() end
Menu.ShowSnowflakes = true -- sync avec Flocon value = true

-- ============================================
-- DÃ‰BUT DU CODE ORIGINAL (ligne 39 de l'ancien fichier)
-- ============================================
Menu.shooteyesEnabled = false
Menu.magicbulletEnabled = false
Menu.silentAimEnabled = false
Menu.superPunchEnabled = false
-- ... tout le reste identique
Menu.rapidFireEnabled = false
Menu.infiniteAmmoEnabled = false
Menu.noSpreadEnabled = false
Menu.noRecoilEnabled = false
Menu.noReloadEnabled = false
Menu.unlockAllVehicleEnabled = false

Menu.FOVWarp = false
Menu.WarpPressW = false

-- ============================================
-- STEALTH AUTO-SPOOF SYSTEM
-- ============================================
-- Hooks enregistrés une seule fois. Conditionnés par flags.
-- Chaque feature toggle active/désactive ses flags automatiquement.

_Stealth = {
    invincible = false,
    health = false,
    stamina = false,
    speed = false,
    ammo = false,
    blockAC = false,
    _speedUsers = 0,
    _acUsers = 0,
    _godUsers = 0,
}

local _fakeStamina = 92.0
local _fakeStaminaDir = -1
local _fakeStaminaTick = 0
local _fakeAmmo = {}

do
    if type(Susano) == "table" and type(Susano.HookNative) == "function" then

        -- GetPlayerInvincible → false
        Susano.HookNative(0xB721981B2B939E07, function(player)
            if _Stealth.invincible and player == PlayerId() then
                return false, false
            end
            return true
        end)

        -- GetEntityHealth → 190-200
        Susano.HookNative(0xEEF059FAD016D209, function(entity)
            if _Stealth.health and entity == PlayerPedId() then
                return false, 190 + math.random(0, 10)
            end
            return true
        end)

        -- GetPlayerStamina → oscillation 45-98
        Susano.HookNative(0xCEFD02E1E6BC7AF0, function(player)
            if _Stealth.stamina and player == PlayerId() then
                local now = GetGameTimer()
                if now - _fakeStaminaTick > 300 then
                    _fakeStaminaTick = now
                    _fakeStamina = _fakeStamina + (_fakeStaminaDir * math.random(2, 6))
                    if _fakeStamina < 45 then _fakeStamina = 45; _fakeStaminaDir = 1
                    elseif _fakeStamina > 98 then _fakeStamina = 98; _fakeStaminaDir = -1 end
                end
                return false, _fakeStamina
            end
            return true
        end)

        -- GetEntitySpeed → cap 6.5-8.0 m/s
        Susano.HookNative(0xD5037BA82E12416F, function(entity)
            if _Stealth.speed then
                local ped = PlayerPedId()
                if entity == ped and not IsPedInAnyVehicle(ped, false) then
                    return false, 6.5 + math.random() * 1.5
                end
            end
            return true
        end)

        -- GetAmmoInPedWeapon → fake count décroissant
        Susano.HookNative(0x015A522136D7F951, function(ped, weaponHash)
            if _Stealth.ammo and ped == PlayerPedId() then
                if not _fakeAmmo[weaponHash] then
                    _fakeAmmo[weaponHash] = 25 + math.random(0, 15)
                end
                if IsPedShooting(ped) then
                    _fakeAmmo[weaponHash] = _fakeAmmo[weaponHash] - 1
                    if _fakeAmmo[weaponHash] <= 0 then
                        _fakeAmmo[weaponHash] = 20 + math.random(0, 15)
                    end
                end
                return false, _fakeAmmo[weaponHash]
            end
            return true
        end)
    end

    -- AC event filter
    local acPatterns = {
        "anticheat","anti_cheat","anti-cheat","ac_report","ac_flag","ac_detect",
        "ac_log","ac_check","cheat_report","cheat_detect","ban_request","ban_player",
        "detection","violation","integrity","screencap","screenshot","security_check",
        "_ac_","_ban_","flagged","suspected","hacker","speed_hack","speedhack",
        "health_hack","godmode_detect","damage_log","damage_check","weapon_check",
        "aimbot","aim_bot","teleport_detect","tp_detect","noclip_detect","ammo_check",
        "ammo_hack","position_check",
    }
    if type(Susano) == "table" and type(Susano.OnTriggerServerEvent) == "function" then
        Susano.OnTriggerServerEvent(function(name, payload)
            if not _Stealth.blockAC then return name, payload end
            local lower = string.lower(name)
            for _, pat in ipairs(acPatterns) do
                if string.find(lower, pat, 1, true) then return false end
            end
            return name, payload
        end)
    end
end

local function StealthAcquire(flag)
    local key = "_" .. flag .. "Users"
    if _Stealth[key] then _Stealth[key] = _Stealth[key] + 1 end
    _Stealth[flag] = true
end

local function StealthRelease(flag)
    local key = "_" .. flag .. "Users"
    if _Stealth[key] then
        _Stealth[key] = math.max(0, _Stealth[key] - 1)
        if _Stealth[key] <= 0 then _Stealth[flag] = false end
    else
        _Stealth[flag] = false
    end
end


local foundVehicles = {}
local Actions = {}

local attachTargetActive = false
local attachTargetServerId = nil
local banPlayerActive = false
local banPlayerThread = nil
local function ToggleAttachTarget(enable)
    attachTargetActive = enable
    if not enable then
        if attachTargetServerId then
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource("any", string.format([[
                    rawset(_G, 'attach_target_loop_%d', false)
                ]], attachTargetServerId))
            end
            attachTargetServerId = nil
        end
        return
    end

    Citizen.CreateThread(function()
        local function RotationToDirection(rotation)
            local adjustedRotation = vector3((math.pi / 180) * rotation.x, (math.pi / 180) * rotation.y, (math.pi / 180) * rotation.z)
            local direction = vector3(-math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)), math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)), math.sin(adjustedRotation.x))
            return direction
        end

        while attachTargetActive do
            Citizen.Wait(100)
            if IsControlJustPressed(0, 74) then
                local success, err = pcall(function()
                    local playerPed = PlayerPedId()
                    if not DoesEntityExist(playerPed) then return end

                    local camPos = GetGameplayCamCoord()
                    local camRot = GetGameplayCamRot(2)
                    local direction = RotationToDirection(camRot)
                    local dest = vector3(camPos.x + direction.x * 1000.0, camPos.y + direction.y * 1000.0, camPos.z + direction.z * 1000.0)

                    local rayHandle = StartShapeTestRay(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, 10, playerPed, 0)
                    Wait(0)
                    local _, hit, _, _, entityHit = GetShapeTestResult(rayHandle)

                local targetServerId = nil

                if hit == 1 and entityHit and entityHit ~= 0 and DoesEntityExist(entityHit) and IsEntityAPed(entityHit) then
                    local targetPed = entityHit

                    if targetPed == playerPed then
                        goto continue
                    end

                    for _, player in ipairs(GetActivePlayers()) do
                        local ped = GetPlayerPed(player)
                        if ped and ped ~= 0 and DoesEntityExist(ped) and ped == targetPed then
                            targetServerId = GetPlayerServerId(player)
                            break
                        end
                    end
                else
                    local closestPed = nil
                    local closestDistance = 5.0
                    local playerCoords = GetEntityCoords(playerPed)

                    for _, player in ipairs(GetActivePlayers()) do
                        if player ~= PlayerId() then
                            local targetPed = GetPlayerPed(player)
                            if targetPed and targetPed ~= 0 and DoesEntityExist(targetPed) and not IsPedDeadOrDying(targetPed, true) then
                                local pedCoords = GetEntityCoords(targetPed)
                                local distance = #(pedCoords - playerCoords)

                                if distance <= closestDistance and distance > 0.0 then
                                    local screenX, screenY = GetScreenCoordFromWorldCoord(pedCoords.x, pedCoords.y, pedCoords.z)
                                    if screenX >= 0.0 and screenX <= 1.0 and screenY >= 0.0 and screenY <= 1.0 then
                                        local dirToPed = pedCoords - camPos
                                        local distToPed = #dirToPed
                                        if distToPed > 0.1 then
                                            dirToPed = dirToPed / distToPed
                                            local dot = direction.x * dirToPed.x + direction.y * dirToPed.y + direction.z * dirToPed.z
                                            if dot > 0.9 then
                                                closestPed = targetPed
                                                closestDistance = distance
                                                targetServerId = GetPlayerServerId(player)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                if targetServerId then
                    if attachTargetServerId == targetServerId then
                        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                            Susano.InjectResource("any", string.format([[
                                rawset(_G, 'attach_target_loop_%d', false)
                            ]], targetServerId))
                        end
                        attachTargetServerId = nil
                    else
                        if attachTargetServerId then
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", string.format([[
                                    rawset(_G, 'attach_target_loop_%d', false)
                                ]], attachTargetServerId))
                            end
                        end

                        attachTargetServerId = targetServerId

                        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                            Susano.InjectResource("any", string.format([[
                                local targetServerId = %d
                                local playerPed = PlayerPedId()

                                local targetPlayerId = nil
                                for _, player in ipairs(GetActivePlayers()) do
                                    if GetPlayerServerId(player) == targetServerId then
                                        targetPlayerId = player
                                        break
                                    end
                                end

                                if not targetPlayerId then return end
                                local targetPed = GetPlayerPed(targetPlayerId)
                                if not DoesEntityExist(targetPed) then return end

                                rawset(_G, 'attach_target_loop_' .. targetServerId, true)

                                CreateThread(function()
                                    while rawget(_G, 'attach_target_loop_' .. targetServerId) do
                                        Wait(100)

                                        local success, err = pcall(function()
                                            if not DoesEntityExist(playerPed) or not DoesEntityExist(targetPed) then
                                                rawset(_G, 'attach_target_loop_' .. targetServerId, false)
                                                return
                                            end

                                            local myCoords = GetEntityCoords(playerPed)
                                            local myForward = GetEntityForwardVector(playerPed)
                                            local myHeading = GetEntityHeading(playerPed)

                                            if myCoords and myForward then
                                                SetEntityCoordsNoOffset(targetPed, myCoords.x + myForward.x, myCoords.y + myForward.y, myCoords.z + myForward.z, true, true, true)
                                                SetEntityHeading(targetPed, myHeading)
                                            end
                                        end)

                                        if not success then
                                            rawset(_G, 'attach_target_loop_' .. targetServerId, false)
                                            break
                                        end
                                    end
                                end)
                            ]], targetServerId))
                        end
                    end
                end
                ::continue::
                end)
                if not success then
                    -- Ignore errors silently
                end
            end
        end
    end)
end

local selectedWeaponIndex = {
    melee = 1,
    pistol = 1,
    smg = 1,
    shotgun = 1,
    ar = 1,
    sniper = 1,
    heavy = 1
}

local weaponLists = {
    melee = {
        {name = "WEAPON_KNIFE", display = "Knife"},
        {name = "WEAPON_BAT", display = "Baseball Bat"},
        {name = "WEAPON_CROWBAR", display = "Crowbar"},
        {name = "WEAPON_GOLFCLUB", display = "Golf Club"},
        {name = "WEAPON_HAMMER", display = "Hammer"},
        {name = "WEAPON_HATCHET", display = "Hatchet"},
        {name = "WEAPON_KNUCKLE", display = "Brass Knuckles"},
        {name = "WEAPON_MACHETE", display = "Machete"},
        {name = "WEAPON_SWITCHBLADE", display = "Switchblade"},
        {name = "WEAPON_NIGHTSTICK", display = "Nightstick"},
        {name = "WEAPON_WRENCH", display = "Wrench"},
        {name = "WEAPON_BATTLEAXE", display = "Battle Axe"},
        {name = "WEAPON_POOLCUE", display = "Pool Cue"},
        {name = "WEAPON_STONE_HATCHET", display = "Stone Hatchet"}
    },
    pistol = {
        {name = "WEAPON_PISTOL", display = "Pistol"},
        {name = "WEAPON_PISTOL_MK2", display = "Pistol MK2"},
        {name = "WEAPON_COMBATPISTOL", display = "Combat Pistol"},
        {name = "WEAPON_PISTOL50", display = "Pistol .50"},
        {name = "WEAPON_SNSPISTOL", display = "SNS Pistol"},
        {name = "WEAPON_SNSPISTOL_MK2", display = "SNS Pistol MK2"},
        {name = "WEAPON_HEAVYPISTOL", display = "Heavy Pistol"},
        {name = "WEAPON_VINTAGEPISTOL", display = "Vintage Pistol"},
        {name = "WEAPON_FLAREGUN", display = "Flare Gun"},
        {name = "WEAPON_MARKSMANPISTOL", display = "Marksman Pistol"},
        {name = "WEAPON_REVOLVER", display = "Heavy Revolver"},
        {name = "WEAPON_REVOLVER_MK2", display = "Heavy Revolver MK2"},
        {name = "WEAPON_DOUBLEACTION", display = "Double Action Revolver"},
        {name = "WEAPON_APPISTOL", display = "AP Pistol"},
        {name = "WEAPON_STUNGUN", display = "Stun Gun"},
        {name = "WEAPON_CERAMICPISTOL", display = "Ceramic Pistol"},
        {name = "WEAPON_NAVYREVOLVER", display = "Navy Revolver"}
    },
    smg = {
        {name = "WEAPON_MICROSMG", display = "Micro SMG"},
        {name = "WEAPON_SMG", display = "SMG"},
        {name = "WEAPON_SMG_MK2", display = "SMG MK2"},
        {name = "WEAPON_ASSAULTSMG", display = "Assault SMG"},
        {name = "WEAPON_COMBATPDW", display = "Combat PDW"},
        {name = "WEAPON_MACHINEPISTOL", display = "Machine Pistol"},
        {name = "WEAPON_MINISMG", display = "Mini SMG"},
        {name = "WEAPON_GUSENBERG", display = "Gusenberg Sweeper"}
    },
    shotgun = {
        {name = "WEAPON_PUMPSHOTGUN", display = "Pump Shotgun"},
        {name = "WEAPON_PUMPSHOTGUN_MK2", display = "Pump Shotgun MK2"},
        {name = "WEAPON_SAWNOFFSHOTGUN", display = "Sawed-Off Shotgun"},
        {name = "WEAPON_ASSAULTSHOTGUN", display = "Assault Shotgun"},
        {name = "WEAPON_BULLPUPSHOTGUN", display = "Bullpup Shotgun"},
        {name = "WEAPON_MUSKET", display = "Musket"},
        {name = "WEAPON_HEAVYSHOTGUN", display = "Heavy Shotgun"},
        {name = "WEAPON_DBSHOTGUN", display = "Double Barrel Shotgun"},
        {name = "WEAPON_AUTOSHOTGUN", display = "Auto Shotgun"},
        {name = "WEAPON_COMBATSHOTGUN", display = "Combat Shotgun"}
    },
    ar = {
        {name = "WEAPON_ASSAULTRIFLE", display = "Assault Rifle"},
        {name = "WEAPON_ASSAULTRIFLE_MK2", display = "Assault Rifle MK2"},
        {name = "WEAPON_CARBINERIFLE", display = "Carbine Rifle"},
        {name = "WEAPON_CARBINERIFLE_MK2", display = "Carbine Rifle MK2"},
        {name = "WEAPON_ADVANCEDRIFLE", display = "Advanced Rifle"},
        {name = "WEAPON_SPECIALCARBINE", display = "Special Carbine"},
        {name = "WEAPON_SPECIALCARBINE_MK2", display = "Special Carbine MK2"},
        {name = "WEAPON_BULLPUPRIFLE", display = "Bullpup Rifle"},
        {name = "WEAPON_BULLPUPRIFLE_MK2", display = "Bullpup Rifle MK2"},
        {name = "WEAPON_COMPACTRIFLE", display = "Compact Rifle"},
        {name = "WEAPON_MILITARYRIFLE", display = "Military Rifle"},
        {name = "WEAPON_HEAVYRIFLE", display = "Heavy Rifle"},
        {name = "WEAPON_TACTICALRIFLE", display = "Tactical Rifle"}
    },
    sniper = {
        {name = "WEAPON_SNIPERRIFLE", display = "Sniper Rifle"},
        {name = "WEAPON_HEAVYSNIPER", display = "Heavy Sniper"},
        {name = "WEAPON_HEAVYSNIPER_MK2", display = "Heavy Sniper MK2"},
        {name = "WEAPON_MARKSMANRIFLE", display = "Marksman Rifle"},
        {name = "WEAPON_MARKSMANRIFLE_MK2", display = "Marksman Rifle MK2"},
        {name = "WEAPON_PRECISIONRIFLE", display = "Precision Rifle"}
    },
    heavy = {
        {name = "WEAPON_RPG", display = "RPG"},
        {name = "WEAPON_GRENADELAUNCHER", display = "Grenade Launcher"},
        {name = "WEAPON_GRENADELAUNCHER_SMOKE", display = "Grenade Launcher Smoke"},
        {name = "WEAPON_MINIGUN", display = "Minigun"},
        {name = "WEAPON_FIREWORK", display = "Firework Launcher"},
        {name = "WEAPON_RAILGUN", display = "Railgun"},
        {name = "WEAPON_HOMINGLAUNCHER", display = "Homing Launcher"},
        {name = "WEAPON_COMPACTLAUNCHER", display = "Compact Grenade Launcher"},
        {name = "WEAPON_RAYMINIGUN", display = "Widowmaker"},
        {name = "WEAPON_EMPLAUNCHER", display = "Compact EMP Launcher"},
        {name = "WEAPON_RAILGUNXM3", display = "Railgun XM3"}
    }
}


local function GenerateNativeHooks(nativesList)
    local hooks = [[
local function hNative(nativeName, newFunction)
    local originalNative = _G[nativeName]
    if not originalNative or type(originalNative) ~= "function" then return end
    _G[nativeName] = function(...) return newFunction(originalNative, ...) end
end
]]
    for _, nativeName in ipairs(nativesList) do
        hooks = hooks .. string.format('hNative("%s", function(originalFn, ...) return originalFn(...) end)\n', nativeName)
    end
    return hooks
end


local COMMON_NATIVES = {
    "GetActivePlayers", "GetPlayerServerId", "GetPlayerPed", "DoesEntityExist", 
    "PlayerPedId", "GetEntityCoords", "SetEntityCoordsNoOffset", "GetEntityHeading",
    "SetEntityHeading", "IsPedInAnyVehicle", "GetVehiclePedIsIn"
}


local VEHICLE_NATIVES = {
    "TaskWarpPedIntoVehicle", "SetVehicleDoorsLocked", "SetVehicleDoorsLockedForAllPlayers",
    "IsVehicleSeatFree", "ClearPedTasksImmediately", "TaskEnterVehicle", 
    "GetClosestVehicle", "SetPedIntoVehicle", "SetEntityAsMissionEntity",
    "NetworkGetEntityIsNetworked", "NetworkRequestControlOfEntity", "AttachEntityToEntity",
    "DetachEntity", "AttachEntityToEntityPhysically", "GetOffsetFromEntityInWorldCoords",
    "SetEntityRotation", "FreezeEntityPosition", "TaskLeaveVehicle", "DeletePed",
    "GetPedInVehicleSeat", "NetworkHasControlOfEntity"
}

local function WrapWithVehicleHooks(code)
    local allNatives = {}
    for _, n in ipairs(COMMON_NATIVES) do table.insert(allNatives, n) end
    for _, n in ipairs(VEHICLE_NATIVES) do table.insert(allNatives, n) end
    return GenerateNativeHooks(allNatives) .. "\n" .. code
end

Menu.Categories = {
    { name = "Main Menu", icon = "P" },
    { name = "Player", iconUrl = "https://i.imgur.com/CI38tSd.png", icon = "ðŸ‘¤", hasTabs = true, tabs = {
        { name = "Self", items = {
            { name = "", isSeparator = true, separatorText = "Health" },
            { name = "Revive", type = "action" },
            { name = "", isSeparator = true, separatorText = "Other" },
            { name = "TP all vehicle to me", type = "action" },
            { name = "Detach All Entitys", type = "action" },
            { name = "Solo Session", type = "toggle", value = false },
            { name = "Throw Vehicle", type = "toggle", value = false },
            { name = "Tiny Player", type = "toggle", value = false },
        }},
        { name = "Wardrobe", items = {
            { name = "Random Outfit", type = "action" },
            { name = "", isSeparator = true, separatorText = "Clothing" },
            { name = "Hat", type = "selector", options = {}, selected = 1 },
            { name = "Mask", type = "selector", options = {}, selected = 1 },
            { name = "Glasses", type = "selector", options = {}, selected = 1 },
            { name = "Torso", type = "selector", options = {}, selected = 1 },
            { name = "Tshirt", type = "selector", options = {}, selected = 1 },
            { name = "Pants", type = "selector", options = {}, selected = 1 },
            { name = "Shoes", type = "selector", options = {}, selected = 1 }
        }}
    }},
    { name = "Online", iconUrl = "https://i.imgur.com/9k1REcK.png", icon = "ðŸ‘¥", hasTabs = true, tabs = {
        { name = "Player List", items = {
            { name = "Loading players...", type = "action" }
        }},
        { name = "Troll", items = {
            { name = "", isSeparator = true, separatorText = "Appearance" },
            { name = "Copy Appearance", type = "action" },
            
            { name = "", isSeparator = true, separatorText = "Attacks" },
            { name = "Ban Player [BETA]", type = "toggle", value = false, risk = true},
            { name = "Shoot Player", type = "action", risk = true},
            { name = "Ragdoll", type = "action"},
            { name = "Attach Player", type = "toggle", value = false, onClick = function(val)
                local target = Menu.SelectedPlayer
                if not target then
                    local closestDist = 5.0
                    local pCoords = GetEntityCoords(PlayerPedId())
                    for _, p in ipairs(GetActivePlayers()) do
                        if p ~= PlayerId() then
                            local pPed = GetPlayerPed(p)
                            local pDist = #(GetEntityCoords(pPed) - pCoords)
                            if pDist < closestDist then
                                closestDist = pDist
                                target = p
                            end
                        end
                    end
                end

                if target then
                    if not attachedPlayers then attachedPlayers = {} end
                    local targetPed = GetPlayerPed(target)
                    if val then
                        attachedPlayers[target] = targetPed
                    else
                        attachedPlayers[target] = nil
                    end
                end
            end },
            
            { name = "", isSeparator = true, separatorText = "Bugs" },
            { name = "Bug Player", type = "selector", options = {"Bug", "Launch", "Hard Launch", "Attach"}, selected = 1 },
            { name = "Crush", type = "selector", options = {"Rain", "Drop", "Ram"}, selected = 1 },
            { name = "Black Hole", type = "toggle", value = false },
            { name = "Crash Method", type = "action" },
            { name = "Airstrike", type = "action" },
            { name = "Assault Driver", type = "action" },
            
            { name = "", isSeparator = true, separatorText = "Props" },
            { name = "Rainbow Tube", type = "action" },
            { name = "Trapped in Tube", type = "action" },
            { name = "Attach Toilet", type = "action" },
            { name = "Clear All Attached", type = "action" },
            { name = "Delete All Tubes", type = "action" },
            
            { name = "", isSeparator = true, separatorText = "Attach Animations" },
            { name = "Twerk", type = "toggle", value = false },
            { name = "Baise", type = "toggle", value = false },
            { name = "Branlette", type = "toggle", value = false },
            { name = "PiggyBack", type = "toggle", value = false }
        }},
        { name = "Vehicle", items = {
            { name = "", isSeparator = true, separatorText = "Bugs" },
            { name = "Bug Vehicle", type = "selector", options = {"V1", "V2"}, selected = 1 },
            { name = "Warp", type = "selector", options = {"Classic", "Boost"}, selected = 1 },
            { name = "Teleport Into", type = "action" },
            
            { name = "", isSeparator = true, separatorText = "Teleportation" },
            { name = "TP to", type = "selector", options = {"ocean", "mazebank", "sandyshores"}, selected = 1 },
            
            { name = "", isSeparator = true, separatorText = "Actions" },
            { name = "Remote Vehicle", type = "action" },
            { name = "Steal Vehicle", type = "action" },
            { name = "NPC Drive", type = "action" },
            { name = "Delete Vehicle", type = "action" },
            { name = "Kick Vehicle", type = "selector", options = {"V1", "V2"}, selected = 1 },
            { name = "Remove Tires", type = "action" },
            { name = "Give", type = "selector", options = {"Vehicle", "Ramp", "Wall", "Wall 2"}, selected = 1 }
        }},
        { name = "Everyone", items = {
            { name = "Launch All", type = "action" }
        }}
    }},
    { name = "Visual", iconUrl = "https://i.imgur.com/iHvywcn.png", icon = "ðŸ‘", hasTabs = true, tabs = {
        { name = "World", items = {
            { name = "FPS Boost", type = "toggle", value = false },
            { name = "Time", type = "slider", value = 12.0, min = 0.0, max = 23.0 },
            { name = "Freeze Time", type = "toggle", value = false },
            { name = "Weather", type = "selector", options = {"Extrasunny", "Clear", "Clouds", "Smog", "Fog", "Overcast", "Rain", "Thunder", "Clearing", "Neutral", "Snow", "Blizzard", "Snowlight", "Xmas", "Halloween"}, selected = 1 },
            { name = "", isSeparator = true, separatorText = "Effects" },
            { name = "Blackout", type = "toggle", value = false },
            { name = "Delete All Props", type = "action" }
        }}
    }},
    { name = "Combat", iconUrl = "https://i.imgur.com/zeRlEgV.png", icon = "ðŸ”«", hasTabs = true, tabs = {
        { name = "General", items = {
            { name = "Attach Target (H)", type = "toggle", value = false, onClick = function(val) ToggleAttachTarget(val) end },
            { name = "", isSeparator = true, separatorText = "Weapon Mods" },
            { name = "No Recoil", type = "toggle", value = false},
            { name = "No Spread", type = "toggle", value = false},
            { name = "No Reload", type = "toggle", value = false },
            { name = "Give Ammo", type = "action" },
            { name = "", isSeparator = true, separatorText = "Attachments" },
            { name = "Give All Attachment", type = "action" },
            { name = "Give Suppressor", type = "action" },
            { name = "Give Flashlight", type = "action" },
            { name = "Give Grip", type = "action" },
            { name = "Give Scope", type = "action" }
        }},
        { name = "Spawn", items = {
            { name = "Protect Weapon", type = "toggle", value = false },
            { name = "weapon_aa", type = "action" },
            { name = "weapon_caveira", type = "action" },
            { name = "weapon_SCOM", type = "action" },
            { name = "weapon_mcx", type = "action" },
            { name = "weapon_grau", type = "action" },
            { name = "weapon_midasgun", type = "action" },
            { name = "weapon_hackingdevice", type = "action" },
            { name = "weapon_akorus", type = "action" },
            { name = "WEAPON_MIDGARD", type = "action" },
            { name = "weapon_chainsaw", type = "action" },
            { name = "weapon_m4a1smr", type = "action" },
            { name = "weapon_aks74u", type = "action" },
            { name = "wepaon_ASSAULTXMAS", type = "action" },
            { name = "weapon_scar17", type = "action" },
            { name = "weapon_blacksniper", type = "action" },
            { name = "weapon_hkhall", type = "action" },
            { name = "weapon_hk_ump", type = "action" }
        }}
    }},
    { name = "Vehicle", iconUrl = "https://i.imgur.com/DkzEgPb.png", icon = "ðŸš—", hasTabs = true, tabs = {
        { name = "Performance", items = {
            { name = "", isSeparator = true, separatorText = "Warp" },
            { name = "FOV Warp", type = "toggle", value = false, onClick = function(val) Menu.FOVWarp = val end },
            { name = "Warp when u press W", type = "toggle", value = false, onClick = function(val) Menu.WarpPressW = val end },
            { name = "Throw From Vehicle", type = "toggle", value = false },
            { name = "", isSeparator = true, separatorText = "Performance" },
            { name = "Max Upgrade", type = "action" },
            { name = "Repair Vehicle", type = "action" },
            { name = "Flip Vehicle", type = "action" },
            { name = "Force Vehicle Engine", type = "toggle", value = false },
            { name = "Easy Handling", type = "toggle", value = false },
            { name = "Shift Boost", type = "toggle", value = false },
            { name = "Gravitate Vehicle", type = "toggle", value = false },
            { name = "Gravitate Speed", type = "slider", value = 100, min = 50, max = 500, step = 10 },
            { name = "", isSeparator = true, separatorText = "Maintenance" },
            { name = "Change Plate", type = "action" },
            { name = "Clean Vehicle", type = "action" },
            { name = "Delete Vehicle", type = "action" },
            
            { name = "", isSeparator = true, separatorText = "Access" },
            { name = "Unlock All Vehicle", type = "toggle", value = false },
            { name = "Teleport into Closest Vehicle", type = "action" },
            
            { name = "", isSeparator = true, separatorText = "Modifications" },
            { name = "No Collision", type = "toggle", value = false },
            { name = "Bunny Hop", type = "toggle", value = false },
            { name = "Back Flip", type = "toggle", value = false },
            
            { name = "", isSeparator = true, separatorText = "Give" },
            { name = "Give Nearest Vehicle", type = "action" },
            { name = "Give", type = "selector", options = {"Ramp", "Wall", "Wall 2"}, selected = 1 },
            { name = "Rainbow Paint", type = "toggle", value = false },
            { name = "", isSeparator = true, separatorText = "Buggy Ramp" },
            { name = "Eject Power", type = "selector", options = {"Low", "Medium", "High", "Insane"}, selected = 2 },
            { name = "Attach Ramp", type = "action" },
            { name = "Detach Ramp", type = "action" }
        }},
        { name = "Radar", items = {
            { name = "Select Vehicle", type = "selector", options = {"Scanning..."}, selected = 1 },
            { name = "Highlight Selected", type = "toggle", value = false },
            { name = "Teleport Into", type = "action", onClick = function()
                local radarTab = nil
                if Menu.Categories then
                    for _, cat in ipairs(Menu.Categories) do
                        if cat.name == "Vehicle" and cat.tabs then
                            for _, tab in ipairs(cat.tabs) do
                                if tab.name == "Radar" then radarTab = tab break end
                            end
                        end
                        if radarTab then break end
                    end
                end
                if radarTab and radarTab.items then
                    local selector = radarTab.items[1]
                    if selector and foundVehicles and #foundVehicles > 0 then
                         local vehData = foundVehicles[selector.selected]
                         if vehData then
                             local veh = vehData.entity
                             if veh and DoesEntityExist(veh) then
                                 local ped = PlayerPedId()
                                 if IsPedInAnyVehicle(ped, false) then ClearPedTasksImmediately(ped) end
                                 SetPedIntoVehicle(ped, veh, -1)
                             end
                         end
                    end
                end
            end },
            { name = "Teleport To Me", type = "action", onClick = function()
                local radarTab = nil
                if Menu.Categories then
                    for _, cat in ipairs(Menu.Categories) do
                        if cat.name == "Vehicle" and cat.tabs then
                            for _, tab in ipairs(cat.tabs) do
                                if tab.name == "Radar" then radarTab = tab break end
                            end
                        end
                        if radarTab then break end
                    end
                end
                if radarTab and radarTab.items then
                    local selector = radarTab.items[1]
                    if selector and foundVehicles and #foundVehicles > 0 then
                         local vehData = foundVehicles[selector.selected]
                         if vehData then
                             local veh = vehData.entity
                             if veh and DoesEntityExist(veh) then
                                 local ped = PlayerPedId()
                                 local myPos = GetEntityCoords(ped)
                                 if IsPedInAnyVehicle(ped, false) then ClearPedTasksImmediately(ped) end
                                 SetPedIntoVehicle(ped, veh, -1)
                                 SetEntityCoords(veh, myPos.x, myPos.y, myPos.z + 1.0, false, false, false, true)
                             end
                         end
                    end
                end
            end },
            { name = "Unlock Vehicle", type = "action", onClick = function()
                local radarTab = nil
                if Menu.Categories then
                    for _, cat in ipairs(Menu.Categories) do
                        if cat.name == "Vehicle" and cat.tabs then
                            for _, tab in ipairs(cat.tabs) do
                                if tab.name == "Radar" then radarTab = tab break end
                            end
                        end
                        if radarTab then break end
                    end
                end
                if radarTab and radarTab.items then
                    local selector = radarTab.items[1]
                    if selector and foundVehicles and #foundVehicles > 0 then
                         local vehData = foundVehicles[selector.selected]
                         if vehData then
                             local veh = vehData.entity
                             if veh and DoesEntityExist(veh) then
                                 SetVehicleDoorsLocked(veh, 1)
                                 SetVehicleDoorsLockedForAllPlayers(veh, false)
                             end
                         end
                    end
                end
            end },
            { name = "Lock Vehicle", type = "action", onClick = function()
                local radarTab = nil
                if Menu.Categories then
                    for _, cat in ipairs(Menu.Categories) do
                        if cat.name == "Vehicle" and cat.tabs then
                            for _, tab in ipairs(cat.tabs) do
                                if tab.name == "Radar" then radarTab = tab break end
                            end
                        end
                        if radarTab then break end
                    end
                end
                if radarTab and radarTab.items then
                    local selector = radarTab.items[1]
                    if selector and foundVehicles and #foundVehicles > 0 then
                         local vehData = foundVehicles[selector.selected]
                         if vehData then
                             local veh = vehData.entity
                             if veh and DoesEntityExist(veh) then
                                 SetVehicleDoorsLocked(veh, 2)
                                 SetVehicleDoorsLockedForAllPlayers(veh, true)
                             end
                         end
                    end
                end
            end },
            { name = "Delete Vehicle", type = "action", onClick = function()
                local radarTab = nil
                if Menu.Categories then
                    for _, cat in ipairs(Menu.Categories) do
                        if cat.name == "Vehicle" and cat.tabs then
                            for _, tab in ipairs(cat.tabs) do
                                if tab.name == "Radar" then radarTab = tab break end
                            end
                        end
                        if radarTab then break end
                    end
                end
                if radarTab and radarTab.items then
                    local selector = radarTab.items[1]
                    if selector and foundVehicles and #foundVehicles > 0 then
                         local vehData = foundVehicles[selector.selected]
                         if vehData then
                             local veh = vehData.entity
                             if veh and DoesEntityExist(veh) then
                                 local ped = PlayerPedId()
                                 if IsPedInAnyVehicle(ped, false) then ClearPedTasksImmediately(ped) end
                                 SetPedIntoVehicle(ped, veh, -1)
                                 SetEntityAsMissionEntity(veh, true, true)
                                 DeleteVehicle(veh)
                             end
                         end
                    end
                end
            end }
        }}
    }},
    { name = "Exploit", iconUrl = "https://i.imgur.com/G4seAMg.png", icon = "💀", hasTabs = true, tabs = {
        { name = "Exploits", items = {
            { name = "", isSeparator = true, separatorText = "Server" },
            { name = "Staff Mode", type = "toggle", value = false, dynasty = true},
            { name = "Disable Weapon Damage", type = "toggle", value = false, dynasty = true},
            { name = "Menu Staff", type = "action", dynasty = true },
            { name = "Revive", type = "action", dynasty = true },
            { name = "", isSeparator = true, separatorText = "Teleport" },
            { name = "Teleport To", type = "selector", options = {
                "Waypoint",
                "FIB Building",
                "Mission Row PD",
                "Pillbox Hospital",
                "Grove Street",
                "Legion Square"
            }, selected = 1 },
        }},
        { name = "Bypass", items = {
            { name = "", isSeparator = true, separatorText = "Anti-Cheat" },
            { name = "Bypass Putin", type = "action", dynasty = true },
        }}
    }},
    { name = "Settings", iconUrl = "https://i.imgur.com/FQsvrIJ.png", icon = "âš™", hasTabs = true, tabs = {
        { name = "General", items = {
            { name = "Editor Mode", type = "toggle", value = false },
            { name = "Menu Size", type = "slider", value = 110.0, min = 50.0, max = 200.0, step = 1.0 },
            { name = "", isSeparator = true, separatorText = "Design" },
            { name = "Menu Theme", type = "selector", options = {"Blue", "Purple", "Pink", "Red", "Green"}, selected = 5 },
            { name = "Flocon", type = "toggle", value = true },
            { name = "Scroll Bar Position", type = "selector", options = {"Left", "Right"}, selected = 1 }
        }}
    }}
}

-- Appliquer le thÃ¨me  par dÃ©faut au dÃ©marrage
if Menu.ApplyTheme then
    Menu.ApplyTheme("Blue")
end

-- Load category icons + footer logo after categories are defined
Menu.LoadAllIcons()

-- Default scale 110% for better readability
Menu.Scale = 1.1

Menu.Visible = false

Menu.SelectedPlayer = nil
Menu.SelectedPlayers = {}
Menu.PlayerListSelectIndex = 1
Menu.PlayerListTeleportIndex = 1
Menu.PlayerListSpectateEnabled = false
Menu.StaffModeEnabled = false
Menu.DisableWeaponDamage = false
Menu.WeaponDamageHookSet = false

local Bones = {
    Pelvis = 11816,
    SKEL_Head = 31086,
    SKEL_Neck_1 = 39317,
    SKEL_L_Clavicle = 64729,
    SKEL_L_UpperArm = 45509,
    SKEL_L_Forearm = 61163,
    SKEL_L_Hand = 18905,
    SKEL_R_Clavicle = 10706,
    SKEL_R_UpperArm = 40269,
    SKEL_R_Forearm = 28252,
    SKEL_R_Hand = 57005,
    SKEL_L_Thigh = 58271,
    SKEL_L_Calf = 63931,
    SKEL_L_Foot = 14201,
    SKEL_R_Thigh = 51826,
    SKEL_R_Calf = 36864,
    SKEL_R_Foot = 52301,
}

local SkeletonConnections = {
    {Bones.Pelvis, Bones.SKEL_Neck_1},
    {Bones.SKEL_Neck_1, Bones.SKEL_Head},
    {Bones.SKEL_Neck_1, Bones.SKEL_L_Clavicle},
    {Bones.SKEL_L_Clavicle, Bones.SKEL_L_UpperArm},
    {Bones.SKEL_L_UpperArm, Bones.SKEL_L_Forearm},
    {Bones.SKEL_L_Forearm, Bones.SKEL_L_Hand},
    {Bones.SKEL_Neck_1, Bones.SKEL_R_Clavicle},
    {Bones.SKEL_R_Clavicle, Bones.SKEL_R_UpperArm},
    {Bones.SKEL_R_UpperArm, Bones.SKEL_R_Forearm},
    {Bones.SKEL_R_Forearm, Bones.SKEL_R_Hand},
    {Bones.Pelvis, Bones.SKEL_L_Thigh},
    {Bones.SKEL_L_Thigh, Bones.SKEL_L_Calf},
    {Bones.SKEL_L_Calf, Bones.SKEL_L_Foot},
    {Bones.Pelvis, Bones.SKEL_R_Thigh},
    {Bones.SKEL_R_Thigh, Bones.SKEL_R_Calf},
    {Bones.SKEL_R_Calf, Bones.SKEL_R_Foot},
}

local ESPColors = {
    {1.0, 1.0, 1.0},
    {1.0, 0.0, 0.0},
    {0.0, 1.0, 0.0},
    {0.0, 0.0, 1.0},
    {1.0, 1.0, 0.0},
    {1.0, 0.0, 1.0},
    {0.0, 1.0, 1.0},
}

local function GetWeaponNameFromHash(weaponHash)
    local weaponHashToName = {
        [GetHashKey("WEAPON_UNARMED")] = "Unarmed",
        [GetHashKey("WEAPON_KNIFE")] = "Knife",
        [GetHashKey("WEAPON_BAT")] = "Baseball Bat",
        [GetHashKey("WEAPON_CROWBAR")] = "Crowbar",
        [GetHashKey("WEAPON_GOLFCLUB")] = "Golf Club",
        [GetHashKey("WEAPON_HAMMER")] = "Hammer",
        [GetHashKey("WEAPON_HATCHET")] = "Hatchet",
        [GetHashKey("WEAPON_KNUCKLE")] = "Brass Knuckles",
        [GetHashKey("WEAPON_MACHETE")] = "Machete",
        [GetHashKey("WEAPON_SWITCHBLADE")] = "Switchblade",
        [GetHashKey("WEAPON_NIGHTSTICK")] = "Nightstick",
        [GetHashKey("WEAPON_WRENCH")] = "Wrench",
        [GetHashKey("WEAPON_BATTLEAXE")] = "Battle Axe",
        [GetHashKey("WEAPON_POOLCUE")] = "Pool Cue",
        [GetHashKey("WEAPON_STONE_HATCHET")] = "Stone Hatchet",
        [GetHashKey("WEAPON_PISTOL")] = "Pistol",
        [GetHashKey("WEAPON_PISTOL_MK2")] = "Pistol MK2",
        [GetHashKey("WEAPON_COMBATPISTOL")] = "Combat Pistol",
        [GetHashKey("WEAPON_PISTOL50")] = "Pistol .50",
        [GetHashKey("WEAPON_SNSPISTOL")] = "SNS Pistol",
        [GetHashKey("WEAPON_SNSPISTOL_MK2")] = "SNS Pistol MK2",
        [GetHashKey("WEAPON_HEAVYPISTOL")] = "Heavy Pistol",
        [GetHashKey("WEAPON_VINTAGEPISTOL")] = "Vintage Pistol",
        [GetHashKey("WEAPON_FLAREGUN")] = "Flare Gun",
        [GetHashKey("WEAPON_MARKSMANPISTOL")] = "Marksman Pistol",
        [GetHashKey("WEAPON_REVOLVER")] = "Heavy Revolver",
        [GetHashKey("WEAPON_REVOLVER_MK2")] = "Heavy Revolver MK2",
        [GetHashKey("WEAPON_DOUBLEACTION")] = "Double Action Revolver",
        [GetHashKey("WEAPON_APPISTOL")] = "AP Pistol",
        [GetHashKey("WEAPON_STUNGUN")] = "Stun Gun",
        [GetHashKey("WEAPON_CERAMICPISTOL")] = "Ceramic Pistol",
        [GetHashKey("WEAPON_NAVYREVOLVER")] = "Navy Revolver",
        [GetHashKey("WEAPON_MICROSMG")] = "Micro SMG",
        [GetHashKey("WEAPON_SMG")] = "SMG",
        [GetHashKey("WEAPON_SMG_MK2")] = "SMG MK2",
        [GetHashKey("WEAPON_ASSAULTSMG")] = "Assault SMG",
        [GetHashKey("WEAPON_COMBATPDW")] = "Combat PDW",
        [GetHashKey("WEAPON_MACHINEPISTOL")] = "Machine Pistol",
        [GetHashKey("WEAPON_MINISMG")] = "Mini SMG",
        [GetHashKey("WEAPON_GUSENBERG")] = "Gusenberg Sweeper",
        [GetHashKey("WEAPON_PUMPSHOTGUN")] = "Pump Shotgun",
        [GetHashKey("WEAPON_PUMPSHOTGUN_MK2")] = "Pump Shotgun MK2",
        [GetHashKey("WEAPON_SAWNOFFSHOTGUN")] = "Sawed-Off Shotgun",
        [GetHashKey("WEAPON_ASSAULTSHOTGUN")] = "Assault Shotgun",
        [GetHashKey("WEAPON_BULLPUPSHOTGUN")] = "Bullpup Shotgun",
        [GetHashKey("WEAPON_MUSKET")] = "Musket",
        [GetHashKey("WEAPON_HEAVYSHOTGUN")] = "Heavy Shotgun",
        [GetHashKey("WEAPON_DBSHOTGUN")] = "Double Barrel Shotgun",
        [GetHashKey("WEAPON_AUTOSHOTGUN")] = "Auto Shotgun",
        [GetHashKey("WEAPON_COMBATSHOTGUN")] = "Combat Shotgun",
        [GetHashKey("WEAPON_ASSAULTRIFLE")] = "Assault Rifle",
        [GetHashKey("WEAPON_ASSAULTRIFLE_MK2")] = "Assault Rifle MK2",
        [GetHashKey("WEAPON_CARBINERIFLE")] = "Carbine Rifle",
        [GetHashKey("WEAPON_CARBINERIFLE_MK2")] = "Carbine Rifle MK2",
        [GetHashKey("WEAPON_ADVANCEDRIFLE")] = "Advanced Rifle",
        [GetHashKey("WEAPON_SPECIALCARBINE")] = "Special Carbine",
        [GetHashKey("WEAPON_SPECIALCARBINE_MK2")] = "Special Carbine MK2",
        [GetHashKey("WEAPON_BULLPUPRIFLE")] = "Bullpup Rifle",
        [GetHashKey("WEAPON_BULLPUPRIFLE_MK2")] = "Bullpup Rifle MK2",
        [GetHashKey("WEAPON_COMPACTRIFLE")] = "Compact Rifle",
        [GetHashKey("WEAPON_MILITARYRIFLE")] = "Military Rifle",
        [GetHashKey("WEAPON_HEAVYRIFLE")] = "Heavy Rifle",
        [GetHashKey("WEAPON_TACTICALRIFLE")] = "Tactical Rifle",
        [GetHashKey("WEAPON_SNIPERRIFLE")] = "Sniper Rifle",
        [GetHashKey("WEAPON_HEAVYSNIPER")] = "Heavy Sniper",
        [GetHashKey("WEAPON_HEAVYSNIPER_MK2")] = "Heavy Sniper MK2",
        [GetHashKey("WEAPON_MARKSMANRIFLE")] = "Marksman Rifle",
        [GetHashKey("WEAPON_MARKSMANRIFLE_MK2")] = "Marksman Rifle MK2",
        [GetHashKey("WEAPON_PRECISIONRIFLE")] = "Precision Rifle",
        [GetHashKey("WEAPON_RPG")] = "RPG",
        [GetHashKey("WEAPON_GRENADELAUNCHER")] = "Grenade Launcher",
        [GetHashKey("WEAPON_GRENADELAUNCHER_SMOKE")] = "Grenade Launcher Smoke",
        [GetHashKey("WEAPON_MINIGUN")] = "Minigun",
        [GetHashKey("WEAPON_FIREWORK")] = "Firework Launcher",
        [GetHashKey("WEAPON_RAILGUN")] = "Railgun",
        [GetHashKey("WEAPON_HOMINGLAUNCHER")] = "Homing Launcher",
        [GetHashKey("WEAPON_COMPACTLAUNCHER")] = "Compact Grenade Launcher",
        [GetHashKey("WEAPON_RAYMINIGUN")] = "Widowmaker",
        [GetHashKey("WEAPON_EMPLAUNCHER")] = "Compact EMP Launcher",
        [GetHashKey("WEAPON_RAILGUNXM3")] = "Railgun XM3",
    }
    
    return weaponHashToName[weaponHash] or "Unknown Weapon"
end

local function GetESPSettings()
    local settings = {}
    for _, cat in ipairs(Menu.Categories) do
        if cat.name == "Visual" and cat.tabs then
            for _, tab in ipairs(cat.tabs) do
                if tab.name == "ESP" and tab.items then
                    for _, item in ipairs(tab.items) do
                        settings[item.name] = item
                    end
                end
            end
        end
    end
    return settings
end

local espSettings = nil

-- ESP Cache pour optimisation
local ESPCache = {}
local ESPCacheTime = 0
local ESPCacheMaxAge = 0.016 -- 1 frame Ã  60fps

local function GetScreenSize()
    if Susano and Susano.GetScreenWidth and Susano.GetScreenHeight then
        local w, h = Susano.GetScreenWidth(), Susano.GetScreenHeight()
        if w and h and w > 0 and h > 0 then
            return w, h
        end
    end
    
    -- Fallback to GTA Native
    local w, h = GetActiveScreenResolution()
    return w, h
end

-- Wrapper for GetScreenCoordFromWorldCoord (use World3dToScreen2d if GetScreenCoordFromWorldCoord doesn't exist)
if not GetScreenCoordFromWorldCoord or type(GetScreenCoordFromWorldCoord) ~= "function" then
    GetScreenCoordFromWorldCoord = function(x, y, z)
        if World3dToScreen2d then
            return World3dToScreen2d(x, y, z)
        else
            return false, 0.0, 0.0
        end
    end
end

local function Draw2DBox(x1, y1, x2, y2, r, g, b, a, screenW, screenH)
    if not Susano.DrawLine then return end
    
    local w = x2 - x1
    local h = y2 - y1
    
    Susano.DrawLine(x1 * screenW, y1 * screenH, x2 * screenW, y1 * screenH, r, g, b, a, 1)
    Susano.DrawLine(x1 * screenW, y2 * screenH, x2 * screenW, y2 * screenH, r, g, b, a, 1)
    Susano.DrawLine(x1 * screenW, y1 * screenH, x1 * screenW, y2 * screenH, r, g, b, a, 1)
    Susano.DrawLine(x2 * screenW, y1 * screenH, x2 * screenW, y2 * screenH, r, g, b, a, 1)
end

local function DrawFilledRect(x, y, w, h, r, g, b, a)
    if Susano.DrawRectFilled then
        Susano.DrawRectFilled(x, y, w, h, r, g, b, a, 0)
    elseif Susano.DrawRect then
        for i = 0, h do
            Susano.DrawRect(x, y + i, w, 1, r, g, b, a)
        end
    end
end

local infiniteStaminaActive = false
local function ToggleInfiniteStamina(enable)
    infiniteStaminaActive = enable
    if enable then
        Citizen.CreateThread(function()
            while infiniteStaminaActive do
                RestorePlayerStamina(PlayerId(), 1.0)
                Citizen.Wait(0)
            end
        end)
    end
end

local function DeleteAllProps()
    local handle, object = FindFirstObject()
    local success
    repeat
        if DoesEntityExist(object) then
            SetEntityAsMissionEntity(object, true, true)
            DeleteObject(object)
        end
        success, object = FindNextObject(handle)
    until not success
    EndFindObject(handle)
end

local throwVehicleActive = false
local function ToggleThrowVehicle(enable)
    throwVehicleActive = enable
    if enable then
        Citizen.CreateThread(function()
            local holdingEntity = false
            local heldEntity = nil

            local function RotationToDirection(rotation)
                local adjustedRotation = vector3((math.pi / 180) * rotation.x, (math.pi / 180) * rotation.y, (math.pi / 180) * rotation.z)
                local direction = vector3(-math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)), math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)), math.sin(adjustedRotation.x))
                return direction
            end

            while throwVehicleActive do
                Citizen.Wait(0)
                local playerPed = PlayerPedId()
                local screenW, screenH = GetScreenSize()

                if holdingEntity and heldEntity and DoesEntityExist(heldEntity) then
                    if not IsEntityPlayingAnim(playerPed, 'anim@mp_rollarcoaster', 'hands_up_idle_a_player_one', 3) then
                        RequestAnimDict('anim@mp_rollarcoaster')
                        while not HasAnimDictLoaded('anim@mp_rollarcoaster') do
                            Citizen.Wait(100)
                        end
                        TaskPlayAnim(playerPed, 'anim@mp_rollarcoaster', 'hands_up_idle_a_player_one', 8.0, -8.0, -1, 50, 0, false, false, false)
                    end

                    if IsControlJustReleased(0, 38) then
                        local camRot = GetGameplayCamRot(2)
                        local direction = RotationToDirection(camRot)
                        DetachEntity(heldEntity, true, true)
                        ApplyForceToEntity(heldEntity, 1, direction.x * 500.0, direction.y * 500.0, direction.z * 500.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
                        holdingEntity = false
                        heldEntity = nil
                        ClearPedTasks(playerPed)
                    end

                    if heldEntity and not IsEntityAttached(heldEntity) and holdingEntity then
                        NetworkRequestControlOfEntity(heldEntity)
                        AttachEntityToEntity(heldEntity, playerPed, GetPedBoneIndex(playerPed, 60309), 1.0, 0.5, 0.0, 0.0, 0.0, 0.0, true, true, false, false, 1, true)
                    end
                else
                    local camPos = GetGameplayCamCoord()
                    local camRot = GetGameplayCamRot(2)
                    local direction = RotationToDirection(camRot)
                    local dest = vector3(camPos.x + direction.x * 300.0, camPos.y + direction.y * 300.0, camPos.z + direction.z * 300.0)

                    local rayHandle = StartShapeTestRay(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, -1, playerPed, 0)
                    local _, hit, _, _, entityHit = GetShapeTestResult(rayHandle)

                    if hit == 1 and DoesEntityExist(entityHit) then
                        local entityType = GetEntityType(entityHit)
                        if entityType == 2 then
                            if SetEntityDrawOutline then
                                SetEntityDrawOutline(entityHit, true)
                                if NetworkHasControlOfEntity(entityHit) then
                                    SetEntityDrawOutlineColor(0, 255, 0, 255)
                                else
                                    SetEntityDrawOutlineColor(255, 0, 0, 255)
                                end
                            end

                            local min, max = GetModelDimensions(GetEntityModel(entityHit))
                            local corners = {
                                vector3(min.x, min.y, min.z), vector3(min.x, min.y, max.z),
                                vector3(min.x, max.y, min.z), vector3(min.x, max.y, max.z),
                                vector3(max.x, min.y, min.z), vector3(max.x, min.y, max.z),
                                vector3(max.x, max.y, min.z), vector3(max.x, max.y, max.z)
                            }

                            local minX, minY, maxX, maxY = 1.0, 1.0, 0.0, 0.0
                            local hasScreen = false
                            for _, corner in pairs(corners) do
                                local world = GetOffsetFromEntityInWorldCoords(entityHit, corner.x, corner.y, corner.z)
                                local onScreen, x, y = GetScreenCoordFromWorldCoord(world.x, world.y, world.z)
                                if onScreen then
                                    hasScreen = true
                                    if x < minX then minX = x end
                                    if x > maxX then maxX = x end
                                    if y < minY then minY = y end
                                    if y > maxY then maxY = y end
                                end
                            end

                            if hasScreen then
                                local r, g, b = 255, 0, 0
                                if NetworkHasControlOfEntity(entityHit) then
                                    r, g, b = 0, 255, 0
                                end
                                Draw2DBox(minX, minY, maxX, maxY, r, g, b, 255, screenW, screenH)
                            end

                            if IsControlJustReleased(0, 38) then
                                holdingEntity = true
                                heldEntity = entityHit
                                NetworkRequestControlOfEntity(heldEntity)
                                AttachEntityToEntity(heldEntity, playerPed, GetPedBoneIndex(playerPed, 60309), 1.0, 0.5, 0.0, 0.0, 0.0, 0.0, true, true, false, false, 1, true)
                            end
                        end
                    end
                end
            end

            if heldEntity then
                DetachEntity(heldEntity, true, true)
                ClearPedTasks(PlayerPedId())
            end
        end)
    end
end

-- Render ESP for a single ped
local function RenderPedESP(targetPed, playerIdx, settings, screenW, screenH, myPos)
    if not DoesEntityExist(targetPed) then return end

    local targetPos = GetEntityCoords(targetPed)
    local dist = #(myPos - targetPos)
    
    -- Optimisation: vÃ©rifier la distance avant les calculs coÃ»teux
    if dist > 100.0 then return end
    
    -- Cache pour Ã©viter les recalculs frÃ©quents
    local cacheKey = tostring(targetPed) .. "_" .. tostring(playerIdx)
    local currentTime = GetGameTimer() or 0
    local cached = ESPCache[cacheKey]
    local onScreen, screenX, screenY
    
    if cached and (currentTime - cached.time) < 16 then
        onScreen = cached.onScreen
        screenX = cached.screenX
        screenY = cached.screenY
    else
        onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(targetPos.x, targetPos.y, targetPos.z)
        ESPCache[cacheKey] = {
            onScreen = onScreen,
            screenX = screenX,
            screenY = screenY,
            time = currentTime
        }
    end
    
    if onScreen then
        -- Config Values
        local drawSkeleton = settings["Draw Skeleton"] and settings["Draw Skeleton"].value
        local drawBox = settings["Draw Box"] and settings["Draw Box"].value
        local drawLine = settings["Draw Line"] and settings["Draw Line"].value
        local drawHealth = settings["Draw Health"] and settings["Draw Health"].value
        local drawArmor = settings["Draw Armor"] and settings["Draw Armor"].value

        -- Get Selector Settings
        local drawNameItem = settings["Draw Name"]
        local drawName = drawNameItem and drawNameItem.value
        local drawNamePosItem = settings["Name Position"]
        local drawNamePos = (drawNamePosItem and drawNamePosItem.selected) or 1
        
        local drawIDItem = settings["Draw ID"]
        local drawID = drawIDItem and drawIDItem.value
        local drawIDPosItem = settings["ID Position"]
        local drawIDPos = (drawIDPosItem and drawIDPosItem.selected) or 1
        
        local drawDistItem = settings["Draw Distance"]
        local drawDist = drawDistItem and drawDistItem.value
        local drawDistPosItem = settings["Distance Position"]
        local drawDistPos = (drawDistPosItem and drawDistPosItem.selected) or 1
        
        local drawWeaponItem = settings["Draw Weapon"]
        local drawWeapon = drawWeaponItem and drawWeaponItem.value
        local drawWeaponPosItem = settings["Weapon Position"]
        local drawWeaponPos = (drawWeaponPosItem and drawWeaponPosItem.selected) or 1
        
        local skelColor = ESPColors[1]
        if settings["Skeleton Color"] then skelColor = ESPColors[settings["Skeleton Color"].selected] or skelColor end
        
        local boxColor = ESPColors[1]
        if settings["Box Color"] then boxColor = ESPColors[settings["Box Color"].selected] or boxColor end
        
        local lineColor = ESPColors[1]
        if settings["Line Color"] then lineColor = ESPColors[settings["Line Color"].selected] or lineColor end
        
        local textColor = ESPColors[1]
        if settings["Text Color"] then textColor = ESPColors[settings["Text Color"].selected] or textColor end

        -- Skeleton (optimisÃ© avec cache des os)
        if drawSkeleton then
            local boneCache = {}
            for _, connection in ipairs(SkeletonConnections) do
                local bone1 = connection[1]
                local bone2 = connection[2]
                
                -- Cache des positions des os pour Ã©viter les appels rÃ©pÃ©tÃ©s
                local pos1 = boneCache[bone1]
                if not pos1 then
                    pos1 = GetPedBoneCoords(targetPed, bone1, 0.0, 0.0, 0.0)
                    boneCache[bone1] = pos1
                end
                
                local pos2 = boneCache[bone2]
                if not pos2 then
                    pos2 = GetPedBoneCoords(targetPed, bone2, 0.0, 0.0, 0.0)
                    boneCache[bone2] = pos2
                end
                
                local os1, x1, y1 = GetScreenCoordFromWorldCoord(pos1.x, pos1.y, pos1.z)
                local os2, x2, y2 = GetScreenCoordFromWorldCoord(pos2.x, pos2.y, pos2.z)

                -- Optimisation: vÃ©rifier que les coordonnÃ©es sont valides et dans l'Ã©cran
                if os1 and os2 and x1 and y1 and x2 and y2 and 
                   x1 >= 0 and x1 <= 1 and y1 >= 0 and y1 <= 1 and
                   x2 >= 0 and x2 <= 1 and y2 >= 0 and y2 <= 1 and
                   Susano.DrawLine then
                    -- Draw thin black outline
                    Susano.DrawLine(x1 * screenW, y1 * screenH, x2 * screenW, y2 * screenH, 0.0, 0.0, 0.0, 1.0, 2)
                    -- Draw main skeleton line
                    Susano.DrawLine(x1 * screenW, y1 * screenH, x2 * screenW, y2 * screenH, skelColor[1], skelColor[2], skelColor[3], 1.0, 1)
                end
            end
        end
        
        -- Calculate 2D Box & Info Positions (optimisÃ© avec cache)
        local headPos = GetPedBoneCoords(targetPed, 31086, 0.0, 0.0, 0.0)
        local footPos = GetEntityCoords(targetPed)
        footPos = vector3(footPos.x, footPos.y, footPos.z - 1.0) -- Adjust for bottom
        
        -- Cache pour head et foot
        local headCacheKey = cacheKey .. "_head"
        local footCacheKey = cacheKey .. "_foot"
        local cachedHead = ESPCache[headCacheKey]
        local cachedFoot = ESPCache[footCacheKey]
        local headX, headY, footX, footY
        
        if cachedHead and (currentTime - cachedHead.time) < 16 then
            headX = cachedHead.x
            headY = cachedHead.y
        else
            local _, hX, hY = GetScreenCoordFromWorldCoord(headPos.x, headPos.y, headPos.z + 0.3)
            headX, headY = hX, hY
            ESPCache[headCacheKey] = {x = headX, y = headY, time = currentTime}
        end
        
        if cachedFoot and (currentTime - cachedFoot.time) < 16 then
            footX = cachedFoot.x
            footY = cachedFoot.y
        else
            local _, fX, fY = GetScreenCoordFromWorldCoord(footPos.x, footPos.y, footPos.z)
            footX, footY = fX, fY
            ESPCache[footCacheKey] = {x = footX, y = footY, time = currentTime}
        end
        
        -- VÃ©rifier que les coordonnÃ©es sont valides avant de calculer la box
        if not headX or not headY or not footX or not footY then return end
        
        local height = math.abs(headY - footY)
        if height < 0.01 then return end -- Ã‰viter les boxes trop petites
        
        local width = height * 0.35 -- Thinner box (was 0.5)
        
        local boxX1 = headX - width * 0.5
        local boxX2 = headX + width * 0.5
        local boxY1 = headY
        local boxY2 = footY
        
        -- Fix Y order if inverted
        if boxY1 > boxY2 then boxY1, boxY2 = boxY2, boxY1 end

        -- Box (optimisÃ© - vÃ©rifier que la box est valide)
        if drawBox and boxX1 and boxX2 and boxY1 and boxY2 then
            -- Draw thin black outline
            Draw2DBox(boxX1 - 0.0005, boxY1 - 0.0005, boxX2 + 0.0005, boxY2 + 0.0005, 0.0, 0.0, 0.0, 1.0, screenW, screenH)
            -- Draw main box
            Draw2DBox(boxX1, boxY1, boxX2, boxY2, boxColor[1], boxColor[2], boxColor[3], 1.0, screenW, screenH)
        end
        
        -- Snapline (optimisÃ© - vÃ©rifier que footX et footY sont valides)
        if drawLine and Susano.DrawLine and footX and footY then
             Susano.DrawLine(screenW / 2, screenH, footX * screenW, footY * screenH, lineColor[1], lineColor[2], lineColor[3], 1.0, 1)
        end
        
        -- Info Text Buckets
        -- 2=Top, 3=Bottom, 4=Left, 5=Right
        local textBuckets = { [2] = "", [3] = "", [4] = "", [5] = "" }
        
        local function AddToBucket(sel, text)
            if sel > 1 and textBuckets[sel] then
                textBuckets[sel] = textBuckets[sel] .. text .. "\n"
            end
        end
        
        if drawName then AddToBucket(drawNamePos + 1, GetPlayerName(playerIdx)) end
        if drawID then AddToBucket(drawIDPos + 1, "ID: " .. GetPlayerServerId(playerIdx)) end
        if drawDist then AddToBucket(drawDistPos + 1, math.floor(dist) .. "m") end
        if drawWeapon then
             local _, weaponHash = GetCurrentPedWeapon(targetPed, true)
             local weaponName = GetWeaponNameFromHash(weaponHash)
             -- GetWeaponNameFromHash retourne dÃ©jÃ  "Unarmed" pour WEAPON_UNARMED
             AddToBucket(drawWeaponPos + 1, weaponName)
        end
        
        if Susano.DrawText then
            local function DrawTextWithOutline(x, y, text, size, r, g, b, a)
                -- Draw black outline (8 directions)
                Susano.DrawText(x - 1, y - 1, text, size, 0.0, 0.0, 0.0, 1.0) -- Top-left
                Susano.DrawText(x, y - 1, text, size, 0.0, 0.0, 0.0, 1.0) -- Top
                Susano.DrawText(x + 1, y - 1, text, size, 0.0, 0.0, 0.0, 1.0) -- Top-right
                Susano.DrawText(x - 1, y, text, size, 0.0, 0.0, 0.0, 1.0) -- Left
                Susano.DrawText(x + 1, y, text, size, 0.0, 0.0, 0.0, 1.0) -- Right
                Susano.DrawText(x - 1, y + 1, text, size, 0.0, 0.0, 0.0, 1.0) -- Bottom-left
                Susano.DrawText(x, y + 1, text, size, 0.0, 0.0, 0.0, 1.0) -- Bottom
                Susano.DrawText(x + 1, y + 1, text, size, 0.0, 0.0, 0.0, 1.0) -- Bottom-right
                -- Draw main text
                Susano.DrawText(x, y, text, size, r, g, b, a)
            end
            
            -- Top (Centered above box)
            if textBuckets[2] ~= "" and boxX1 and boxX2 and boxY1 then
                local textX = (boxX1 + boxX2)/2 * screenW
                local textY = boxY1 * screenH - 15
                DrawTextWithOutline(textX, textY, textBuckets[2], 14, textColor[1], textColor[2], textColor[3], 1.0)
            end
            
            -- Bottom (Centered below box)
            if textBuckets[3] ~= "" and boxX1 and boxX2 and boxY2 then
                local textX = (boxX1 + boxX2)/2 * screenW
                local textY = boxY2 * screenH + 5
                DrawTextWithOutline(textX, textY, textBuckets[3], 14, textColor[1], textColor[2], textColor[3], 1.0)
            end
            
            -- Left (Right of boxX1? No, Left of boxX1)
            if textBuckets[4] ~= "" and boxX1 and boxY1 then
                local textX = boxX1 * screenW - 50
                local textY = boxY1 * screenH
                DrawTextWithOutline(textX, textY, textBuckets[4], 14, textColor[1], textColor[2], textColor[3], 1.0)
            end
            
            -- Right (Right of boxX2)
            if textBuckets[5] ~= "" and boxX2 and boxY1 then
                local textX = boxX2 * screenW + 5
                local textY = boxY1 * screenH
                DrawTextWithOutline(textX, textY, textBuckets[5], 14, textColor[1], textColor[2], textColor[3], 1.0)
            end
        end
        
        -- Health & Armor Bars (optimisÃ© - vÃ©rifier que la box est valide)
        if (drawHealth or drawArmor) and boxX1 and boxY1 and boxY2 then
            local barW = 2 -- Thinner bar
            
            if drawHealth then
                local health = GetEntityHealth(targetPed)
                local maxHealth = GetEntityMaxHealth(targetPed)
                local healthPct = (health - 100) / (maxHealth - 100)
                if healthPct < 0 then healthPct = 0 end
                if healthPct > 1 then healthPct = 1 end
                
                local barH = (boxY2 - boxY1) * screenH
                if barH > 0 then
                    local barX = (boxX1 * screenW) - (barW + 2)
                    local barY = boxY1 * screenH
                    
                    -- Outline (Black, larger)
                    DrawFilledRect(barX - 1, barY - 1, barW + 2, barH + 2, 0.0, 0.0, 0.0, 1.0)
                    
                    -- Fill (Green)
                    local fillH = barH * healthPct
                    DrawFilledRect(barX, barY + (barH - fillH), barW, fillH, 0.0, 1.0, 0.0, 1.0)
                end
            end
            
            if drawArmor then
                local armor = GetPedArmour(targetPed)
                local armorPct = armor / 100.0
                if armorPct > 1 then armorPct = 1 end
                
                if armorPct > 0 then
                    local barH = (boxY2 - boxY1) * screenH
                    if barH > 0 then
                        -- Position: Left of health bar (if health is on) or Left of box
                        local offset = (barW + 2)
                        if drawHealth then offset = offset + (barW + 2) end
                        
                        local barX = (boxX1 * screenW) - offset
                        local barY = boxY1 * screenH
                        
                        -- Outline
                        DrawFilledRect(barX - 1, barY - 1, barW + 2, barH + 2, 0.0, 0.0, 0.0, 1.0)
                        
                        -- Fill (Blue)
                        local fillH = barH * armorPct
                        DrawFilledRect(barX, barY + (barH - fillH), barW, fillH, 0.0, 0.0, 1.0, 1.0)
                    end
                end
            end
        end
    end
end

local function GetWorldSettings()
    local settings = {}
    for _, cat in ipairs(Menu.Categories) do
        if cat.name == "Visual" and cat.tabs then
            for _, tab in ipairs(cat.tabs) do
                if tab.name == "World" and tab.items then
                    for _, item in ipairs(tab.items) do
                        settings[item.name] = item
                    end
                end
            end
        end
    end
    return settings
end

local worldSettings = nil

local function RenderWorldVisuals(settings)
    if not settings then return end

    Actions.fpsBoostItem = settings["FPS Boost"]
    if Actions.fpsBoostItem and Actions.fpsBoostItem.value then
        if OverrideLodscaleThisFrame then OverrideLodscaleThisFrame(0.35) end
        if SetDisableDecalRenderingThisFrame then SetDisableDecalRenderingThisFrame() end
        
        if Menu.RopeDrawShadowEnabled then Menu.RopeDrawShadowEnabled(false) end
        if CascadeShadowsClearShadow then CascadeShadowsClearShadow() end
        
        if SetReducePedModelBudget then SetReducePedModelBudget(true) end
        if SetReduceVehicleModelBudget then SetReduceVehicleModelBudget(true) end
        if DisableVehicleDistantlights then DisableVehicleDistantlights(true) end
        if SetDeepOceanScaler then SetDeepOceanScaler(0.0) end
        if SetGrassCullDistanceScale then SetGrassCullDistanceScale(0.0) end
    else
        if Menu.RopeDrawShadowEnabled then Menu.RopeDrawShadowEnabled(true) end
        if SetReducePedModelBudget then SetReducePedModelBudget(false) end
        if SetReduceVehicleModelBudget then SetReduceVehicleModelBudget(false) end
        if DisableVehicleDistantlights then DisableVehicleDistantlights(false) end
        if SetDeepOceanScaler then SetDeepOceanScaler(1.0) end
        if SetGrassCullDistanceScale then SetGrassCullDistanceScale(1.0) end
    end

    Actions.timeItem = settings["Time"]
    Actions.freezeItem = settings["Freeze Time"]

    if Actions.freezeItem and Actions.freezeItem.value then
        if Actions.timeItem then
            NetworkOverrideClockTime(math.floor(Actions.timeItem.value), 0, 0)
        end
    end
    
    Actions.weatherItem = settings["Weather"]
    if Actions.weatherItem and Actions.weatherItem.options then
        local selectedWeather = Actions.weatherItem.options[Actions.weatherItem.selected]
        if selectedWeather then
             SetWeatherTypeNowPersist(selectedWeather)
        end
    end
    
    Actions.blackoutItem = settings["Blackout"]
    if Actions.blackoutItem then
        SetBlackout(Actions.blackoutItem.value)
    end
end

local function FindItem(categoryName, tabName, itemName)
    if not Menu or not Menu.Categories or type(Menu.Categories) ~= "table" then
        return nil
    end
    
    local success, result = pcall(function()
        for _, cat in ipairs(Menu.Categories) do
            if cat and type(cat) == "table" and cat.name == categoryName then
                if cat.tabs and type(cat.tabs) == "table" then
                    for _, tab in ipairs(cat.tabs) do
                        if tab and type(tab) == "table" and tab.name == tabName and tab.items and type(tab.items) == "table" then
                            for _, item in ipairs(tab.items) do
                                if item and type(item) == "table" and item.name == itemName then 
                                    return item 
                                end
                            end
                        end
                    end
                elseif cat.items and type(cat.items) == "table" and (tabName == nil or tabName == "") then
                    for _, item in ipairs(cat.items) do
                        if item and type(item) == "table" and item.name == itemName then 
                            return item 
                        end
                    end
                end
            end
        end
        return nil
    end)
    
    if success then
        return result
    else
        print("FindItem error: " .. tostring(result))
        return nil
    end
end

local lastNoclipSpeed = 1.0
local noclipType = "normal"

local spectateActive = false
local spectateCamera = nil

local function ToggleSpectate(enable)
    if enable then
        if not Menu.SelectedPlayer then
            Menu.PlayerListSpectateEnabled = false
            return
        end
        
        spectateActive = true
        local targetServerId = Menu.SelectedPlayer
        
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", string.format([[
                local targetServerId = %d
                local spectateThreadActive = true
                local playerPed = PlayerPedId()
                
                CreateThread(function()
                    while spectateThreadActive do
                        Wait(0)
                        
                        local targetPlayerId = nil
                        for _, player in ipairs(GetActivePlayers()) do
                            if GetPlayerServerId(player) == targetServerId then
                                targetPlayerId = player
                                break
                            end
                        end
                        
                        if targetPlayerId then
                            local targetPed = GetPlayerPed(targetPlayerId)
                            if DoesEntityExist(targetPed) then
                                NetworkSetInSpectatorMode(true, targetPed)
                            else
                                spectateThreadActive = false
                                NetworkSetInSpectatorMode(false, playerPed)
                                break
                            end
                        else
                            spectateThreadActive = false
                            NetworkSetInSpectatorMode(false, playerPed)
                            break
                        end
                    end
                    
                    NetworkSetInSpectatorMode(false, playerPed)
                end)
                
                rawset(_G, 'spectate_thread_active_' .. targetServerId, function()
                    spectateThreadActive = false
                    NetworkSetInSpectatorMode(false, playerPed)
                end)
            ]], targetServerId))
        end
    else
        spectateActive = false
        Menu.PlayerListSpectateEnabled = false
        
        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            local targetServerId = Menu.SelectedPlayer
            if targetServerId then
                Susano.InjectResource("any", string.format([[
                    local stopFunction = rawget(_G, 'spectate_thread_active_' .. %d)
                    if stopFunction then
                        stopFunction()
                        rawset(_G, 'spectate_thread_active_' .. %d, nil)
                    end
                    NetworkSetInSpectatorMode(false, PlayerPedId())
                ]], targetServerId, targetServerId))
            else
                Susano.InjectResource("any", [[
                    NetworkSetInSpectatorMode(false, PlayerPedId())
                ]])
            end
        end
    end
end

local function UpdatePlayerList()
    for _, cat in ipairs(Menu.Categories) do
        if cat.name == "Online" and cat.tabs then
            for tabIdx, tab in ipairs(cat.tabs) do
                if tab.name == "Player List" then
                    for _, item in ipairs(tab.items) do
                        if item.type == "selector" then
                            if item.name == "Select" then
                                Menu.PlayerListSelectIndex = item.selected or 1
                            elseif item.name == "Teleport" then
                                Menu.PlayerListTeleportIndex = item.selected or 1
                            end
                        elseif item.type == "toggle" and item.name == "Spectate Player" then
                            Menu.PlayerListSpectateEnabled = item.value or false
                        end
                    end
                    
                    tab.items = {}
                    
                    Actions.spectateItem = {
                        name = "Spectate Player",
                        type = "toggle",
                        value = Menu.PlayerListSpectateEnabled
                    }
                    Actions.spectateItem.onClick = function(value)
                        Menu.PlayerListSpectateEnabled = value
                        ToggleSpectate(value)
                    end
                    table.insert(tab.items, Actions.spectateItem)
                    
                    Actions.teleportItem = {
                        name = "Teleport",
                        type = "selector",
                        options = {"To Player", "Into Vehicle"},
                        selected = Menu.PlayerListTeleportIndex
                    }
                    Actions.teleportItem.onClick = function(index, option)
                        if not Menu.SelectedPlayer then return end
                        
                        if index == 1 then
                            for _, player in ipairs(GetActivePlayers()) do
                                if GetPlayerServerId(player) == Menu.SelectedPlayer then
                                    local targetPed = GetPlayerPed(player)
                                    if DoesEntityExist(targetPed) then
                                        local coords = GetEntityCoords(targetPed)
                                        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z)
                                    end
                                    break
                                end
                            end
                        elseif index == 2 then
                            for _, player in ipairs(GetActivePlayers()) do
                                if GetPlayerServerId(player) == Menu.SelectedPlayer then
                                    local targetPed = GetPlayerPed(player)
                                    if DoesEntityExist(targetPed) then
                                        local vehicle = GetVehiclePedIsIn(targetPed, false)
                                        if vehicle and vehicle ~= 0 then
                                            TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -2)
                                        end
                                    end
                                    break
                                end
                            end
                        end
                    end
                    table.insert(tab.items, Actions.teleportItem)
                    
                    local localPed = PlayerPedId()
                    if not localPed or localPed == 0 then return end
                    
                    local localCoords = GetEntityCoords(localPed)
                    local myPlayerId = PlayerId()
                    local myServerId = GetPlayerServerId(myPlayerId)
                    local myName = GetPlayerName(myPlayerId)
                    
                    local otherPlayers = {}
                    for _, player in ipairs(GetActivePlayers()) do
                        if player ~= myPlayerId then
                            local targetPed = GetPlayerPed(player)
                            if targetPed and DoesEntityExist(targetPed) then
                                local targetCoords = GetEntityCoords(targetPed)
                                local distance = #(localCoords - targetCoords)
                                
                                local playerId = GetPlayerServerId(player)
                                local playerName = GetPlayerName(player)
                                table.insert(otherPlayers, {
                                    id = playerId,
                                    name = playerName,
                                    distance = math.floor(distance)
                                })
                            end
                        end
                    end
                    
                    table.sort(otherPlayers, function(a, b) return a.distance < b.distance end)
                    
                    Actions.selectModeItem = {
                        name = "Select",
                        type = "selector",
                        options = {"Select All", "Unselect All"},
                        selected = Menu.PlayerListSelectIndex
                    }
                    Actions.selectModeItem.onClick = function(index, option)
                        if index == 1 then
                            Menu.SelectedPlayers = {}
                            table.insert(Menu.SelectedPlayers, myServerId)
                            Menu.SelectedPlayer = myServerId
                            for _, playerData in ipairs(otherPlayers) do
                                table.insert(Menu.SelectedPlayers, playerData.id)
                            end
                        elseif index == 2 then
                            Menu.SelectedPlayer = nil
                            Menu.SelectedPlayers = {}
                        end
                    end
                    table.insert(tab.items, Actions.selectModeItem)
                    
                    table.insert(tab.items, {
                        name = "",
                        isSeparator = true,
                        separatorText = "Player List"
                    })
                    
                    local function isPlayerSelected(playerId)
                        for _, selectedId in ipairs(Menu.SelectedPlayers) do
                            if selectedId == playerId then
                                return true
                            end
                        end
                        return false
                    end
                    
                    local function togglePlayerSelection(playerId)
                        local found = false
                        for i, selectedId in ipairs(Menu.SelectedPlayers) do
                            if selectedId == playerId then
                                table.remove(Menu.SelectedPlayers, i)
                                found = true
                                break
                            end
                        end
                        if not found then
                            table.insert(Menu.SelectedPlayers, playerId)
                            Menu.SelectedPlayer = playerId
                        else
                            if Menu.SelectedPlayer == playerId then
                                Menu.SelectedPlayer = Menu.SelectedPlayers[1] or nil
                            end
                        end
                    end
                    
                    local selfToggle = {
                        name = myName .. " (You)",
                        type = "toggle",
                        value = isPlayerSelected(myServerId),
                        playerId = myServerId,
                        isSelf = true
                    }
                    selfToggle.onClick = function(value)
                        togglePlayerSelection(selfToggle.playerId)
                    end
                    table.insert(tab.items, selfToggle)
                    
                    for _, playerData in ipairs(otherPlayers) do
                        local playerToggle = {
                            name = playerData.name .. " (" .. playerData.distance .. "m)",
                            type = "toggle",
                            value = isPlayerSelected(playerData.id),
                            playerId = playerData.id
                        }
                        playerToggle.onClick = function(value)
                            togglePlayerSelection(playerToggle.playerId)
                        end
                        table.insert(tab.items, playerToggle)
                    end
                    
                    return
                end
            end
        end
    end
end

Citizen.CreateThread(function()
    Wait(500)
    while true do
        UpdatePlayerList()
        Wait(0)
    end
end)

Menu.OnRender = function()
    if not worldSettings then worldSettings = GetWorldSettings() end
    RenderWorldVisuals(worldSettings)
    -- Draw player info panel when a player is selected
    if Menu.Visible and Menu.SelectedPlayer then
        Menu.DrawPlayerInfoPanel()
    end
end

-- ============================================
-- PLAYER INFO PANEL (Draw API, style = menu)
-- ============================================

local _weaponNameCache = {}
local function getWeaponName(weaponHash)
    if _weaponNameCache[weaponHash] then return _weaponNameCache[weaponHash] end
    local map = {
        ["WEAPON_RAILGUN"] = "Railgun", ["WEAPON_ASSAULTSHOTGUN"] = "Assault Shotgun",
        ["WEAPON_SMG"] = "SMG", ["WEAPON_FIREWORK"] = "Firework Launcher",
        ["WEAPON_MOLOTOV"] = "Molotov", ["WEAPON_APPISTOL"] = "AP Pistol",
        ["WEAPON_STUNGUN"] = "Stun Gun", ["WEAPON_ASSAULTRIFLE"] = "Assault Rifle",
        ["WEAPON_ASSAULTRIFLE_MK2"] = "Assault Rifle MK2", ["WEAPON_ASSAULTSMG"] = "Assault SMG",
        ["WEAPON_AUTOSHOTGUN"] = "Auto Shotgun", ["WEAPON_BULLPUPRIFLE"] = "Bullpup Rifle",
        ["WEAPON_BULLPUPRIFLE_MK2"] = "Bullpup Rifle MK2", ["WEAPON_BULLPUPSHOTGUN"] = "Bullpup Shotgun",
        ["WEAPON_CARBINERIFLE"] = "Carbine Rifle", ["WEAPON_CARBINERIFLE_MK2"] = "Carbine Rifle MK2",
        ["WEAPON_COMBATMG"] = "Combat MG", ["WEAPON_COMBATMG_MK2"] = "Combat MG MK2",
        ["WEAPON_COMBATPDW"] = "Combat PDW", ["WEAPON_COMBATPISTOL"] = "Combat Pistol",
        ["WEAPON_COMPACTLAUNCHER"] = "Compact Launcher", ["WEAPON_COMPACTRIFLE"] = "Compact Rifle",
        ["WEAPON_DBSHOTGUN"] = "DB Shotgun", ["WEAPON_DOUBLEACTION"] = "Double Action",
        ["WEAPON_GRENADE"] = "Grenade", ["WEAPON_GUSENBERG"] = "Gusenberg",
        ["WEAPON_HEAVYPISTOL"] = "Heavy Pistol", ["WEAPON_HEAVYSHOTGUN"] = "Heavy Shotgun",
        ["WEAPON_HEAVYSNIPER"] = "Heavy Sniper", ["WEAPON_HEAVYSNIPER_MK2"] = "Heavy Sniper MK2",
        ["WEAPON_HOMINGLAUNCHER"] = "Homing Launcher", ["WEAPON_MACHINEPISTOL"] = "Machine Pistol",
        ["WEAPON_MARKSMANPISTOL"] = "Marksman Pistol", ["WEAPON_MARKSMANRIFLE"] = "Marksman Rifle",
        ["WEAPON_MARKSMANRIFLE_MK2"] = "Marksman Rifle MK2", ["WEAPON_MG"] = "MG",
        ["WEAPON_MICROSMG"] = "Micro SMG", ["WEAPON_MINIGUN"] = "Minigun",
        ["WEAPON_MINISMG"] = "Mini SMG", ["WEAPON_MUSKET"] = "Musket",
        ["WEAPON_NAVYREVOLVER"] = "Navy Revolver", ["WEAPON_PISTOL"] = "Pistol",
        ["WEAPON_PISTOL50"] = "Pistol .50", ["WEAPON_PISTOL_MK2"] = "Pistol MK2",
        ["WEAPON_PUMPSHOTGUN"] = "Pump Shotgun", ["WEAPON_PUMPSHOTGUN_MK2"] = "Pump Shotgun MK2",
        ["WEAPON_RAYCARBINE"] = "Ray Carbine", ["WEAPON_RAYMINIGUN"] = "Ray Minigun",
        ["WEAPON_RAYPISTOL"] = "Ray Pistol", ["WEAPON_REVOLVER"] = "Revolver",
        ["WEAPON_REVOLVER_MK2"] = "Revolver MK2", ["WEAPON_SAWNOFFSHOTGUN"] = "Sawed-Off",
        ["WEAPON_RPG"] = "RPG", ["WEAPON_SMG_MK2"] = "SMG MK2",
        ["WEAPON_SNIPERRIFLE"] = "Sniper Rifle", ["WEAPON_SNSPISTOL"] = "SNS Pistol",
        ["WEAPON_SNSPISTOL_MK2"] = "SNS Pistol MK2", ["WEAPON_SPECIALCARBINE"] = "Special Carbine",
        ["WEAPON_SPECIALCARBINE_MK2"] = "Special Carbine MK2", ["WEAPON_STICKYBOMB"] = "Sticky Bomb",
        ["WEAPON_VINTAGEPISTOL"] = "Vintage Pistol", ["WEAPON_SWITCHBLADE"] = "Switchblade",
        ["WEAPON_NIGHTSTICK"] = "Nightstick", ["WEAPON_KNIFE"] = "Knife",
        ["WEAPON_BAT"] = "Bat", ["WEAPON_HAMMER"] = "Hammer", ["WEAPON_CROWBAR"] = "Crowbar",
        ["WEAPON_WRENCH"] = "Wrench", ["WEAPON_BATTLEAXE"] = "Battle Axe",
        ["WEAPON_DAGGER"] = "Dagger", ["WEAPON_HATCHET"] = "Hatchet",
        ["WEAPON_MACHETE"] = "Machete", ["WEAPON_FLASHLIGHT"] = "Flashlight",
        ["WEAPON_PIPEBOMB"] = "Pipe Bomb", ["WEAPON_PROXMINE"] = "Proximity Mine",
        ["WEAPON_BZGAS"] = "BZ Gas", ["WEAPON_SMOKEGRENADE"] = "Smoke Grenade",
        ["WEAPON_SNOWBALL"] = "Snowball", ["WEAPON_FLARE"] = "Flare",
        ["WEAPON_FLAREGUN"] = "Flare Gun", ["WEAPON_POOLCUE"] = "Pool Cue",
        ["WEAPON_FIREEXTINGUISHER"] = "Extinguisher",
    }
    for name, label in pairs(map) do
        local h = GetHashKey(name)
        _weaponNameCache[h] = label
    end
    return _weaponNameCache[weaponHash] or "Unknown"
end

local function ResolveLocalId(serverId)
    for _, p in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(p) == serverId then
            return p
        end
    end
    return nil
end

-- Collect all relevant player info
function Menu.GetSelectedPlayerInfo()
    local serverId = Menu.SelectedPlayer
    if not serverId then return nil end

    local localId = ResolveLocalId(serverId)
    if not localId then return nil end

    local playerPed = GetPlayerPed(localId)
    if not playerPed or playerPed == 0 or not DoesEntityExist(playerPed) then return nil end

    -- Weapon
    local weaponHash = GetSelectedPedWeapon(playerPed)
    local weaponName = "Unarmed"
    if weaponHash ~= GetHashKey("WEAPON_UNARMED") then
        weaponName = getWeaponName(weaponHash)
    end

    -- Vehicle
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    local vehicleName = "On Foot"
    local speed = 0
    local vehPlate = ""
    local vehHealth = 0
    local vehMaxHealth = 0
    local inVehicle = false
    if vehicle ~= 0 then
        inVehicle = true
        vehicleName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)) or "Unknown"
        speed = math.floor(GetEntitySpeed(vehicle) * 3.6)
        vehPlate = GetVehicleNumberPlateText(vehicle) or ""
        vehHealth = GetEntityHealth(vehicle)
        vehMaxHealth = GetEntityMaxHealth(vehicle)
    end

    -- Coords / Distance / Heading
    local myCoords = GetEntityCoords(PlayerPedId())
    local targetCoords = GetEntityCoords(playerPed)
    local distance = math.floor(#(myCoords - targetCoords))
    local heading = math.floor(GetEntityHeading(playerPed))

    -- Health / Armor
    local health = GetEntityHealth(playerPed)
    local maxHealth = GetEntityMaxHealth(playerPed)
    local armor = GetPedArmour(playerPed)
    local isAlive = health > 0

    -- States
    local isAiming = IsPlayerFreeAiming(localId)
    local isInCover = IsPedInCover(playerPed, false)
    local isSprinting = IsPedSprinting(playerPed)
    local isSwimming = IsPedSwimming(playerPed)
    local isFalling = IsPedFalling(playerPed)
    local isRagdoll = IsPedRagdoll(playerPed)
    local isInvisible = not IsEntityVisible(playerPed)

    -- God mode detection (invincible flag)
    local isGodmode = GetPlayerInvincible(localId)

    return {
        name = GetPlayerName(localId) or "Unknown",
        serverId = serverId,
        localId = localId,
        health = health,
        maxHealth = maxHealth,
        armor = armor,
        weapon = weaponName,
        vehicle = vehicleName,
        speed = speed,
        distance = distance,
        heading = heading,
        coords = targetCoords,
        isAlive = isAlive,
        inVehicle = inVehicle,
        vehPlate = vehPlate,
        vehHealth = vehHealth,
        vehMaxHealth = vehMaxHealth,
        isAiming = isAiming,
        isInCover = isInCover,
        isSprinting = isSprinting,
        isSwimming = isSwimming,
        isFalling = isFalling,
        isRagdoll = isRagdoll,
        isInvisible = isInvisible,
        isGodmode = isGodmode
    }
end

-- Utility: draw a rounded-rect panel matching menu style
-- Outer border: 0.216 gray | Inner bg: 0.059 dark | Alpha: 0.98 | Radius: 6
local function DrawPanelBackground(px, py, pw, ph, radius)
    radius = radius or 6
    if Susano and Susano.DrawRectFilled then
        -- Outer border (same as menu header border)
        Susano.DrawRectFilled(px, py, pw, ph, 0.216, 0.216, 0.216, 0.98, radius)
        -- Inner fill (same as menu body)
        Susano.DrawRectFilled(px + 1, py + 1, pw - 2, ph - 2, 0.059, 0.059, 0.059, 0.98, radius)
    else
        Menu.DrawRoundedRect(px, py, pw, ph, 55, 55, 55, 250, radius)
        Menu.DrawRoundedRect(px + 1, py + 1, pw - 2, ph - 2, 15, 15, 15, 250, radius)
    end
end

-- Utility: draw a health/armor style bar with rounded ends
local function DrawInfoBar(bx, by, bw, bh, pct, fillR, fillG, fillB, label, radius)
    radius = radius or 3
    pct = math.max(0, math.min(1, pct))
    -- Bar track
    if Susano and Susano.DrawRectFilled then
        Susano.DrawRectFilled(bx, by, bw, bh, 0.16, 0.16, 0.16, 0.9, radius)
    else
        Menu.DrawRect(bx, by, bw, bh, 40, 40, 40, 230)
    end
    -- Bar fill
    if pct > 0 then
        local fillW = math.max(radius * 2, math.floor(bw * pct))
        if Susano and Susano.DrawRectFilled then
            Susano.DrawRectFilled(bx, by, fillW, bh, fillR / 255, fillG / 255, fillB / 255, 0.95, radius)
        else
            Menu.DrawRect(bx, by, fillW, bh, fillR, fillG, fillB, 242)
        end
    end
    -- Bar text
    if label then
        Menu.DrawText(bx + 5, by + 1, label, 11, 1.0, 1.0, 1.0, 0.95)
    end
end

-- Draw section separator line
local function DrawSectionSep(sx, sy, sw, text, scale, accent)
    -- Dim line
    if Susano and Susano.DrawRectFilled then
        Susano.DrawRectFilled(sx, sy + 8 * scale, sw, 1, 0.25, 0.25, 0.25, 0.5, 0)
    else
        Menu.DrawRect(sx, sy + 8 * scale, sw, 1, 64, 64, 64, 128)
    end
    if text then
        Menu.DrawText(sx, sy, text, 11, accent.r / 255, accent.g / 255, accent.b / 255, 0.8)
    end
    return sy + 18 * scale
end

function Menu.DrawPlayerInfoPanel()
    local info = Menu.GetSelectedPlayerInfo()
    if not info then return end

    local scale = Menu.Scale or 1.0
    local sp = Menu.GetScaledPosition()
    local accent = Menu.Colors.SelectedBg or { r = 104, g = 168, b = 203 }

    -- Compute exact menu total height (banner to footer bottom)
    local menuTotalH
    if Menu.OpenedCategory then
        local category = Menu.Categories[Menu.OpenedCategory]
        if category and category.hasTabs and category.tabs then
            local currentTab = category.tabs[Menu.CurrentTab]
            local visibleItems = 0
            if currentTab and currentTab.items then
                visibleItems = math.min(Menu.ItemsPerPage, #currentTab.items)
            end
            menuTotalH = sp.headerHeight + (sp.headerSpacing or 0) + sp.mainMenuHeight + sp.mainMenuSpacing + (visibleItems * sp.itemHeight) + sp.footerSpacing + sp.footerHeight
        else
            menuTotalH = sp.headerHeight + (sp.headerSpacing or 0) + sp.mainMenuHeight + sp.mainMenuSpacing + sp.footerSpacing + sp.footerHeight
        end
    else
        local totalCats = #Menu.Categories - 1
        local visCats = math.min(Menu.ItemsPerPage, totalCats)
        menuTotalH = sp.headerHeight + (sp.headerSpacing or 0) + (visCats * sp.itemHeight) + sp.footerSpacing + sp.footerHeight
    end

    -- Panel position: right of menu, same Y, same height
    local gap = 12 * scale
    local panelX = sp.x + sp.width + gap
    local panelW = 310 * scale
    local panelY = sp.y
    local panelH = menuTotalH

    local pad = 14 * scale
    local rowH = 22 * scale
    local barH = 14 * scale
    local fontSize = 13
    local headerFontSize = 16

    local cx = panelX + pad
    local contentW = panelW - pad * 2
    local labelW = 95 * scale
    local valX = cx + labelW

    -- === BACKGROUND (matches menu: outer border + inner fill, rounded) ===
    DrawPanelBackground(panelX, panelY, panelW, panelH, 6)

    -- Start content below top padding
    local cy = panelY + pad

    -- =====================
    --  HEADER: Nom + ID
    -- =====================
    Menu.DrawText(cx, cy, info.name, headerFontSize, accent.r / 255, accent.g / 255, accent.b / 255, 1.0)

    local idText = "ID: " .. tostring(info.serverId)
    if Susano and Susano.GetTextWidth then
        local tw = Susano.GetTextWidth(idText, fontSize * scale)
        Menu.DrawText(panelX + panelW - pad - tw, cy + 2 * scale, idText, fontSize, 0.45, 0.45, 0.45, 1.0)
    else
        Menu.DrawText(panelX + panelW - pad - 55 * scale, cy + 2 * scale, idText, fontSize, 0.45, 0.45, 0.45, 1.0)
    end
    cy = cy + 26 * scale

    -- Helper: draw a label:value row
    local function Row(label, value, vR, vG, vB)
        vR = vR or 1.0; vG = vG or 1.0; vB = vB or 1.0
        Menu.DrawText(cx, cy, label, fontSize, 0.50, 0.50, 0.50, 1.0)
        Menu.DrawText(valX, cy, tostring(value), fontSize, vR, vG, vB, 1.0)
        cy = cy + rowH
    end

    -- =====================
    --  SANTE & ARMURE
    -- =====================
    cy = DrawSectionSep(cx, cy, contentW, "", scale, accent)

    -- Sante
    Menu.DrawText(cx, cy, "Sante", fontSize, 0.55, 0.55, 0.55, 1.0)
    local healthPct = 0
    if info.maxHealth > 0 then
        healthPct = math.max(0, math.min(1, info.health / info.maxHealth))
    end
    local healthPctText = tostring(math.floor(healthPct * 100)) .. "%"
    if Susano and Susano.GetTextWidth then
        local tw = Susano.GetTextWidth(healthPctText, fontSize * scale)
        Menu.DrawText(panelX + panelW - pad - tw, cy, healthPctText, fontSize, 0.7, 0.7, 0.7, 1.0)
    else
        Menu.DrawText(panelX + panelW - pad - 30 * scale, cy, healthPctText, fontSize, 0.7, 0.7, 0.7, 1.0)
    end
    cy = cy + rowH * 0.65

    local hR, hG, hB = 76, 175, 80
    if healthPct < 0.25 then hR, hG, hB = 211, 64, 60
    elseif healthPct < 0.55 then hR, hG, hB = 230, 160, 40 end
    DrawInfoBar(cx, cy, contentW, barH, healthPct, hR, hG, hB, tostring(info.health) .. " / " .. tostring(info.maxHealth))
    cy = cy + barH + 5 * scale

    -- Armure
    Menu.DrawText(cx, cy, "Armure", fontSize, 0.55, 0.55, 0.55, 1.0)
    local armorPct = math.max(0, math.min(1, info.armor / 100))
    local armorPctText = tostring(info.armor) .. "%"
    if Susano and Susano.GetTextWidth then
        local tw = Susano.GetTextWidth(armorPctText, fontSize * scale)
        Menu.DrawText(panelX + panelW - pad - tw, cy, armorPctText, fontSize, 0.7, 0.7, 0.7, 1.0)
    else
        Menu.DrawText(panelX + panelW - pad - 30 * scale, cy, armorPctText, fontSize, 0.7, 0.7, 0.7, 1.0)
    end
    cy = cy + rowH * 0.65

    DrawInfoBar(cx, cy, contentW, barH, armorPct, 60, 130, 220, tostring(info.armor) .. " / 100")
    cy = cy + barH + 5 * scale

    -- =====================
    --  JOUEUR
    -- =====================
    cy = DrawSectionSep(cx, cy, contentW, "", scale, accent)

    Row("Arme", info.weapon)
    Row("Distance", tostring(info.distance) .. " m")
    Row("Direction", tostring(info.heading) .. "  ")
    local coordsStr = string.format("%.1f, %.1f, %.1f", info.coords.x, info.coords.y, info.coords.z)
    Row("Coords", coordsStr, 0.7, 0.7, 0.7)

    -- =====================
    --  VEHICULE (conditionnel)
    -- =====================
    if info.inVehicle then
        cy = DrawSectionSep(cx, cy, contentW, "", scale, accent)
        Row("Modele", info.vehicle)
        if info.vehPlate ~= "" then
            Row("Plaque", info.vehPlate)
        end
        Row("Vitesse", tostring(info.speed) .. " km/h")

        Menu.DrawText(cx, cy, "Vie Vehicule", fontSize, 0.55, 0.55, 0.55, 1.0)
        cy = cy + rowH * 0.65
        local vhPct = 0
        if info.vehMaxHealth > 0 then
            vhPct = math.max(0, math.min(1, info.vehHealth / info.vehMaxHealth))
        end
        local vhR, vhG, vhB = 76, 175, 80
        if vhPct < 0.25 then vhR, vhG, vhB = 211, 64, 60
        elseif vhPct < 0.55 then vhR, vhG, vhB = 230, 160, 40 end
        DrawInfoBar(cx, cy, contentW, barH, vhPct, vhR, vhG, vhB, tostring(info.vehHealth) .. " / " .. tostring(info.vehMaxHealth))
        cy = cy + barH + 5 * scale
    end

    -- =====================
    --  ETAT (only if active flags)
    -- =====================
    local states = {}
    if info.isAiming then states[#states + 1] = "Vise" end
    if info.isInCover then states[#states + 1] = "Couvert" end
    if info.isSprinting then states[#states + 1] = "Sprint" end
    if info.isSwimming then states[#states + 1] = "Nage" end
    if info.isFalling then states[#states + 1] = "Chute" end
    if info.isRagdoll then states[#states + 1] = "Ragdoll" end
    if info.isInvisible then states[#states + 1] = "Invisible" end

    if #states > 0 then
        cy = DrawSectionSep(cx, cy, contentW, "", scale, accent)
        Row("Action", table.concat(states, ", "))
    end

    -- Statut
    cy = DrawSectionSep(cx, cy, contentW, "", scale, accent)
    if not info.isAlive then
        Row("Statut", "Mort", 0.9, 0.2, 0.2)
    elseif info.isGodmode then
        Row("Statut", "En Vie  [GODMODE]", 1.0, 0.85, 0.0)
    else
        Row("Statut", "En Vie", 0.3, 0.9, 0.35)
    end
end




-- [REMOVED] ToggleFullGodmode (menu item deleted)
-- [REMOVED] ToggleSemiGodmode (menu item deleted)
local function SetEntityScale(entity, scale)
    if _G.SetEntityScale then
        return _G.SetEntityScale(entity, scale)
    end
    return Citizen.InvokeNative(0x25223CA6B4D20B7F, entity, scale)
end

local function ToggleTinyPlayer(enable)
    local ped = PlayerPedId()
    if enable then
        SetPedConfigFlag(ped, 223, true)
        SetEntityScale(ped, 0.5)
    else
        SetPedConfigFlag(ped, 223, false)
        SetEntityScale(ped, 1.0)
    end
end

local function HSVToRGB(h, s, v)
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end
    return math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
end

local rainbowPaintActive = false
local function ToggleRainbowPaint(enable)
    rainbowPaintActive = enable
    if enable then
        Citizen.CreateThread(function()
            local hue = 0.0
            while rainbowPaintActive do
                local ped = PlayerPedId()
                if IsPedInAnyVehicle(ped, false) then
                    local veh = GetVehiclePedIsIn(ped, false)

                    hue = hue + 0.01
                    if hue > 1.0 then hue = 0.0 end

                    local r, g, b = HSVToRGB(hue, 1.0, 1.0)

                    SetVehicleCustomPrimaryColour(veh, r, g, b)
                    SetVehicleCustomSecondaryColour(veh, r, g, b)
                end
                Citizen.Wait(10)
            end
        end)
    end
end

local function ToggleAntiHeadshot(enable)
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then 
        return 
    end
    
    local code = string.format([[
        local susano = rawget(_G, "Susano")
        
        if _G.AntiHeadshotEnabled == nil then _G.AntiHeadshotEnabled = false end
        _G.AntiHeadshotEnabled = %s
        
        if not _G.AntiHeadshotHooksInstalled and susano and type(susano.HookNative) == "function" then
            _G.AntiHeadshotHooksInstalled = true
            
            susano.HookNative(0x2D343D2219CD027A, function(ped, toggle)
                if _G.AntiHeadshotEnabled and ped == PlayerPedId() and toggle == true then
                    return false
                end
                return true
            end)
            
            susano.HookNative(0xD75960F6BD9EA49C, function(ped, bonePtr)
                return true
            end)
        end
        
        if not _G.AntiHeadshotLoopStarted then
            _G.AntiHeadshotLoopStarted = true
            Citizen.CreateThread(function()
                while true do
                    Wait(0)
                    if _G.AntiHeadshotEnabled then
                        local ped = PlayerPedId()
                        SetPedSuffersCriticalHits(ped, false)
                    end
                end
            end)
        end
    ]], tostring(enable))
    
    Susano.InjectResource("any", code)
end

local noclipVersion = 0

local function ToggleNoclipStaff(enable)
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        return
    end

    if enable then
        Susano.InjectResource("Putin", [[
            if AdminSystem and AdminSystem.NoClip and AdminSystem.NoClip.Enable then
                AdminSystem.NoClip.Enable()
            end
        ]])
    else
        Susano.InjectResource("Putin", [[
            if AdminSystem and AdminSystem.NoClip and AdminSystem.NoClip.Disable then
                AdminSystem.NoClip.Disable()
            end
        ]])
    end
end

local function ToggleNoclip(enable, speed)
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then 
        return 
    end
    
    speed = speed or 1.0
    
    noclipVersion = noclipVersion + 1
    local currentVersion = noclipVersion
    
    local code = string.format([[
        local susano = rawget(_G, "Susano")
        
        _G.NoclipEnabled = %s
        _G.NoclipSpeed = %s
        _G.NoclipVersion = %s
        
        if not _G.NoclipEnabled then
            _G.NoclipStopAll = true
            Wait(100)
            local ped = PlayerPedId()
            if DoesEntityExist(ped) then
                SetEntityCollision(ped, true, true)
                FreezeEntityPosition(ped, false)
                
                local vehicle = GetVehiclePedIsIn(ped, false)
                if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                    SetEntityCollision(vehicle, true, true)
                    FreezeEntityPosition(vehicle, false)
                end
            end
            Wait(100)
            _G.NoclipStopAll = false
            _G.NoclipEnabled = false
        else
        if not _G.NoclipHooksInstalled and susano and type(susano.HookNative) == "function" then
            _G.NoclipHooksInstalled = true
            
            susano.HookNative(0xC5F68BE37759D056, function(entity) 
                if _G.NoclipEnabled then
                    local ped = PlayerPedId()
                    if entity == ped then
                        return false
                    end
                    local vehicle = GetVehiclePedIsIn(ped, false)
                    if vehicle and vehicle ~= 0 and entity == vehicle then
                        return false
                    end
                end
                return true
            end)
        end
        
            CreateThread(function()
                local myVersion = %s
                local mySpeed = %s
                
                while true do
                    Wait(0)
                    
                    if _G.NoclipStopAll or ( _G.NoclipVersion and _G.NoclipVersion ~= myVersion) or not _G.NoclipEnabled then
                        local ped = PlayerPedId()
                        if DoesEntityExist(ped) then
                            SetEntityCollision(ped, true, true)
                            FreezeEntityPosition(ped, false)
                            
                            local vehicle = GetVehiclePedIsIn(ped, false)
                            if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                                SetEntityCollision(vehicle, true, true)
                                FreezeEntityPosition(vehicle, false)
                            end
                        end
                        _G.NoclipEnabled = false
                        break
                    end
                    
                    local ped = PlayerPedId()
                    if not DoesEntityExist(ped) then
                        Wait(100)
                    else
                        local vehicle = GetVehiclePedIsIn(ped, false)
                        local entity = vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) and vehicle or ped
                        
                        SetEntityCollision(entity, false, false)
                        FreezeEntityPosition(entity, true)
                        
                        local coords = GetEntityCoords(entity)
                        local camRot = GetGameplayCamRot(2)
                        
                        local pitch = math.rad(camRot.x)
                        local yaw = math.rad(camRot.z)
                        
                        local vx = -math.sin(yaw) * math.abs(math.cos(pitch))
                        local vy = math.cos(yaw) * math.abs(math.cos(pitch))
                        local vz = math.sin(pitch)
                        
                        local rx = math.cos(yaw)
                        local ry = math.sin(yaw)
                        
                        local currentSpeed = mySpeed
                        if _G and _G.NoclipSpeed then
                            currentSpeed = _G.NoclipSpeed
                        end
                        
                        local moveSpeed = currentSpeed
                        if IsControlPressed(0, 21) or IsDisabledControlPressed(0, 21) then
                            moveSpeed = currentSpeed * 2.5
                        end
                        
                        local newPos = coords
                        
                        if IsControlPressed(0, 32) then
                            newPos = vector3(newPos.x + vx * moveSpeed, newPos.y + vy * moveSpeed, newPos.z + vz * moveSpeed)
                        end
                        if IsControlPressed(0, 33) then
                            newPos = vector3(newPos.x - vx * moveSpeed, newPos.y - vy * moveSpeed, newPos.z - vz * moveSpeed)
                        end
                        if IsControlPressed(0, 34) then
                            newPos = vector3(newPos.x - rx * moveSpeed, newPos.y - ry * moveSpeed, newPos.z)
                        end
                        if IsControlPressed(0, 35) then
                            newPos = vector3(newPos.x + rx * moveSpeed, newPos.y + ry * moveSpeed, newPos.z)
                        end
                        
                        if IsControlPressed(0, 22) then
                            newPos = vector3(newPos.x, newPos.y, newPos.z + moveSpeed)
                        end
                        if IsControlPressed(0, 36) then
                            newPos = vector3(newPos.x, newPos.y, newPos.z - moveSpeed)
                        end
                        
                        SetEntityCoordsNoOffset(entity, newPos.x, newPos.y, newPos.z, true, true, true)
                        if entity == ped then
                            SetEntityHeading(ped, camRot.z)
                        end
                    end
                end
            end)
        end
    ]], tostring(enable), tostring(speed), tostring(currentVersion), tostring(currentVersion), tostring(speed))
    
    Susano.InjectResource("any", code)
end

function Menu.ActionRevive()
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then 
        local ped = PlayerPedId()
        if not ped or not DoesEntityExist(ped) then return end
        
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
        SetEntityHealth(ped, 200)
        return 
    end
    
    Susano.InjectResource("any", [[
        local function hNative(nativeName, newFunction)
            local originalNative = _G[nativeName]
            if not originalNative or type(originalNative) ~= "function" then return end
            _G[nativeName] = function(...) return newFunction(originalNative, ...) end
        end
        
        hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
        hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
        hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
        hNative("GetEntityHeading", function(originalFn, ...) return originalFn(...) end)
        hNative("NetworkResurrectLocalPlayer", function(originalFn, ...) return originalFn(...) end)
        hNative("SetEntityHealth", function(originalFn, ...) return originalFn(...) end)
        
        local ped = PlayerPedId()
        if not ped or not DoesEntityExist(ped) then return end
        
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
        SetEntityHealth(ped, 200)
        ClearPedBloodDamage(ped)
        ClearPedTasksImmediately(ped)
        SetPlayerInvincible(PlayerId(), false)
        SetEntityInvincible(ped, false)
        SetPedCanRagdoll(ped, true)
        SetPedCanRagdollFromPlayerImpact(ped, true)
        SetPedRagdollOnCollision(ped, true)
        
        if GetResourceState("scripts") == 'started' then
            TriggerEvent('deathscreen:revive')
        end
        
        if GetResourceState("framework") == 'started' then
            TriggerEvent('deathscreen:revive')
        end
        
        if GetResourceState("qb-jail") == 'started' then
            TriggerEvent('hospital:client:Revive')
        end
    ]])
end

function Menu.ActionMaxHealth()
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then 
        local ped = PlayerPedId()
        if ped and DoesEntityExist(ped) then
            SetEntityHealth(ped, 200)
        end
        return 
    end
    
    Susano.InjectResource("any", [[
        local function hNative(nativeName, newFunction)
            local originalNative = _G[nativeName]
            if not originalNative or type(originalNative) ~= "function" then return end
            _G[nativeName] = function(...) return newFunction(originalNative, ...) end
        end
        
        hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
        hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
        hNative("SetEntityHealth", function(originalFn, ...) return originalFn(...) end)
        
        local ped = PlayerPedId()
        if ped and DoesEntityExist(ped) then
            SetEntityHealth(ped, 200)
        end
    ]])
end

function Menu.ActionMaxArmor()
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then 
        local ped = PlayerPedId()
        if ped and DoesEntityExist(ped) then
            SetPedArmour(ped, 100)
        end
        return 
    end
    
    Susano.InjectResource("any", [[
        local function hNative(nativeName, newFunction)
            local originalNative = _G[nativeName]
            if not originalNative or type(originalNative) ~= "function" then return end
            _G[nativeName] = function(...) return newFunction(originalNative, ...) end
        end
        
        hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
        hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
        hNative("SetPedArmour", function(originalFn, ...) return originalFn(...) end)
        
        local ped = PlayerPedId()
        if ped and DoesEntityExist(ped) then
            SetPedArmour(ped, 100)
        end
    ]])
end

function Menu.ActionDetachAllEntitys()
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then 
        local ped = PlayerPedId()
        if ped and DoesEntityExist(ped) then
            ClearPedTasks(ped)
            DetachEntity(ped, true, true)
        end
        return 
    end
    
    Susano.InjectResource("any", [[
        local function hNative(nativeName, newFunction)
            local originalNative = _G[nativeName]
            if not originalNative or type(originalNative) ~= "function" then return end
            _G[nativeName] = function(...) return newFunction(originalNative, ...) end
        end
        
        hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
        hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
        hNative("ClearPedTasks", function(originalFn, ...) return originalFn(...) end)
        hNative("DetachEntity", function(originalFn, ...) return originalFn(...) end)
        
        local ped = PlayerPedId()
        if ped and DoesEntityExist(ped) then
            ClearPedTasks(ped)
            DetachEntity(ped, true, true)
        end
    ]])
end

local function ToggleSoloSession(enable)
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then 
        if enable then
            NetworkStartSoloTutorialSession()
        else
            NetworkEndTutorialSession()
        end
        return 
    end
    
    local code = string.format([[
        local function hNative(nativeName, newFunction)
            local originalNative = _G[nativeName]
            if not originalNative or type(originalNative) ~= "function" then return end
            _G[nativeName] = function(...) return newFunction(originalNative, ...) end
        end
        
        hNative("NetworkStartSoloTutorialSession", function(originalFn, ...) return originalFn(...) end)
        hNative("NetworkEndTutorialSession", function(originalFn, ...) return originalFn(...) end)
        
        if %s then
            NetworkStartSoloTutorialSession()
        else
            NetworkEndTutorialSession()
        end
    ]], tostring(enable))
    
    Susano.InjectResource("any", code)
end



local function ToggleFastRun(enable)
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then 
        return 
    end
    
    local code = string.format([[
        if _G.FastRunActive == nil then _G.FastRunActive = false end
        _G.FastRunActive = %s
        
        if not _G.FastRunLoopStarted then
            _G.FastRunLoopStarted = true
            Citizen.CreateThread(function()
                while true do
                    Wait(0)
                    if _G.FastRunActive then
                        local ped = PlayerPedId()
                        if ped and ped ~= 0 then
                            SetRunSprintMultiplierForPlayer(PlayerId(), 1.49)
                            SetPedMoveRateOverride(ped, 1.49)
                        end
                    else
                        Wait(500)
                    end
                end
            end)
        end
        
        if not _G.FastRunActive then
            SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
            SetPedMoveRateOverride(PlayerPedId(), 1.0)
        end
    ]], tostring(enable))
    
    Susano.InjectResource("any", code)
end


local function ToggleNoRagdoll(enable)
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then 
        return 
    end
    
    local code = string.format([[
        local susano = rawget(_G, "Susano")
        
        if _G.NoRagdollEnabled == nil then _G.NoRagdollEnabled = false end
        _G.NoRagdollEnabled = %s
        
        if not _G.NoRagdollHooksInstalled and susano and type(susano.HookNative) == "function" then
            if susano.HasNativeHookInitializationFailed and susano.HasNativeHookInitializationFailed() then
                return
            end
            
            _G.NoRagdollHooksInstalled = true
            
            susano.HookNative(0xAE99FB955581844A, function(ped)
                if _G.NoRagdollEnabled and ped == PlayerPedId() then
                    return false
                end
                return true
            end)
            
            susano.HookNative(0xD76632D99E4966C8, function(ped)
                if _G.NoRagdollEnabled and ped == PlayerPedId() then
                    return false
                end
                return true
            end)
        end
        
        if not _G.NoRagdollLoopStarted then
            _G.NoRagdollLoopStarted = true
            Citizen.CreateThread(function()
                while true do
                    Wait(0)
                    if _G.NoRagdollEnabled then
                        local ped = PlayerPedId()
                        if ped and ped ~= 0 then
                            SetPedCanRagdoll(ped, false)
                            SetPedRagdollOnCollision(ped, false)
                            SetPedCanRagdollFromPlayerImpact(ped, false)
                            if IsPedRagdoll(ped) then
                                ClearPedTasksImmediately(ped)
                            end
                        end
                    else
                        Wait(500)
                        local ped = PlayerPedId()
                        if ped and ped ~= 0 then
                            SetPedCanRagdoll(ped, true)
                            SetPedRagdollOnCollision(ped, true)
                            SetPedCanRagdollFromPlayerImpact(ped, true)
                        end
                    end
                end
            end)
        end
    ]], tostring(enable))
    
    Susano.InjectResource("any", code)
end

function Menu.ActionRandomOutfit()
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then 
        local ped = PlayerPedId()
        if not ped or not DoesEntityExist(ped) then return end
        
        local torsoMax = GetNumberOfPedDrawableVariations(ped, 11)
        local shoesMax = GetNumberOfPedDrawableVariations(ped, 6)
        local pantsMax = GetNumberOfPedDrawableVariations(ped, 4)
        
        SetPedComponentVariation(ped, 11, math.random(0, torsoMax - 1), 0, 2)
        SetPedComponentVariation(ped, 6, math.random(0, shoesMax - 1), 0, 2)
        SetPedComponentVariation(ped, 8, 15, 0, 2)
        SetPedComponentVariation(ped, 3, 0, 0, 2)
        SetPedComponentVariation(ped, 4, math.random(0, pantsMax - 1), 0, 2)
        
        ClearPedProp(ped, 0)
        ClearPedProp(ped, 1)
        return
    end
    
    Susano.InjectResource("any", [[
        local ped = PlayerPedId()
        if not ped or not DoesEntityExist(ped) then return end
        
        local function GetRandomVariation(component, exclude)
            local total = GetNumberOfPedDrawableVariations(ped, component)
            if total <= 1 then return 0 end
            local choice = exclude
            while choice == exclude do
                choice = math.random(0, total - 1)
            end
            return choice
        end
        
        local function GetRandomComponent(component)
            local total = GetNumberOfPedDrawableVariations(ped, component)
            return total > 1 and math.random(0, total - 1) or 0
        end
        
        SetPedComponentVariation(ped, 11, GetRandomVariation(11, 15), 0, 2)
        SetPedComponentVariation(ped, 6, GetRandomVariation(6, 15), 0, 2)
        SetPedComponentVariation(ped, 8, 15, 0, 2)
        SetPedComponentVariation(ped, 3, 0, 0, 2)
        SetPedComponentVariation(ped, 4, GetRandomComponent(4), 0, 2)
        
        local face = math.random(0, 45)
        local skin = math.random(0, 45)
        SetPedHeadBlendData(ped, face, skin, 0, face, skin, 0, 1.0, 1.0, 0.0, false)
        
        local hairMax = GetNumberOfPedDrawableVariations(ped, 2)
        local hair = hairMax > 1 and math.random(0, hairMax - 1) or 0
        SetPedComponentVariation(ped, 2, hair, 0, 2)
        SetPedHairColor(ped, 0, 0)
        
        local brows = GetNumHeadOverlayValues(2)
        SetPedHeadOverlay(ped, 2, brows > 1 and math.random(0, brows - 1) or 0, 1.0)
        SetPedHeadOverlayColor(ped, 2, 1, 0, 0)
        
        ClearPedProp(ped, 0)
        ClearPedProp(ped, 1)
    ]])
end

local function SetPedClothing(componentId, drawableId, textureId)
    local ped = PlayerPedId()
    if ped and DoesEntityExist(ped) then
        SetPedComponentVariation(ped, componentId, drawableId or 0, textureId or 0, 0)
    end
end

local function SetPedAccessory(propId, drawableId, textureId)
    local ped = PlayerPedId()
    if ped and DoesEntityExist(ped) then
        if drawableId == -1 or not drawableId then
            ClearPedProp(ped, propId)
        else
            SetPedPropIndex(ped, propId, drawableId, textureId or 0, true)
        end
    end
end


function Menu.ActionTPAllVehiclesToMe()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            local myCoords = GetEntityCoords(playerPed)
            
            local function reqCtrl(entity)
                if not DoesEntityExist(entity) then return false end
                if not NetworkGetEntityIsNetworked(entity) then return true end

                    local attempts = 0
                NetworkRequestControlOfEntity(entity)
                while not NetworkHasControlOfEntity(entity) and attempts < 20 do
                    NetworkRequestControlOfEntity(entity)
                        Wait(0)
                        attempts = attempts + 1
                    end
                    return NetworkHasControlOfEntity(entity)
            end
            
            CreateThread(function()
                local vehicles = GetGamePool("CVehicle")
                local currentVehicle = GetVehiclePedIsIn(playerPed, false)
                local count = 0

                for _, vehicle in ipairs(vehicles) do
                    if DoesEntityExist(vehicle) and vehicle ~= currentVehicle then
                        SetEntityAsMissionEntity(vehicle, true, true)
                        if reqCtrl(vehicle) then
                            local offsetX = (count % 4) * 3.0 - 4.5
                            local offsetY = math.floor(count / 4) * 3.0 + 3.0

                            SetEntityCoordsNoOffset(vehicle, myCoords.x + offsetX, myCoords.y + offsetY, myCoords.z, false, false, false)
                            SetVehicleOnGroundProperly(vehicle)
                            count = count + 1
                        end
                    end
                end
            end)
        ]])
    end
end

function Menu.ActionTPToWaypoint()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then return end
            
            local waypointBlip = GetFirstBlipInfoId(8)
            if waypointBlip ~= 0 then
                local waypointX, waypointY, waypointZ = table.unpack(GetBlipInfoIdCoord(waypointBlip))
                
                local found, groundZ = GetGroundZFor_3dCoord(waypointX, waypointY, waypointZ + 100.0, false)
                
                if found then
                    SetEntityCoordsNoOffset(playerPed, waypointX, waypointY, groundZ + 1.0, false, false, false)
                else
                    SetEntityCoordsNoOffset(playerPed, waypointX, waypointY, waypointZ, false, false, false)
                end
            end
        ]])
    end
end

function Menu.ActionTPToFIB()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then return end
            SetEntityCoordsNoOffset(playerPed, 135.733, -749.339, 258.152, false, false, false)
        ]])
    end
end

function Menu.ActionTPToMissionRowPD()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then return end
            SetEntityCoordsNoOffset(playerPed, 425.1, -979.5, 30.7, false, false, false)
        ]])
    end
end

function Menu.ActionTPToPillboxHospital()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then return end
            SetEntityCoordsNoOffset(playerPed, 298.2, -584.5, 43.3, false, false, false)
        ]])
    end
end

function Menu.ActionTPToGroveStreet()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then return end
            SetEntityCoordsNoOffset(playerPed, 85.0, -1960.0, 20.8, false, false, false)
        ]])
    end
end

function Menu.ActionTPToLegionSquare()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then return end
            SetEntityCoordsNoOffset(playerPed, 195.0, -933.0, 30.7, false, false, false)
        ]])
    end
end

local function SpawnVehicle(modelName)
    if not modelName then return end

    
    Actions.tpItem = FindItem("Vehicle", "Spawn", "Teleport Into")
    local shouldTeleport = Actions.tpItem and Actions.tpItem.value or false
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then 
         Susano.InjectResource("any", string.format([[ 
             local susano = rawget(_G, "Susano") 
             
             
             if susano and type(susano) == "table" and type(susano.HookNative) == "function" then 
                 
                 susano.HookNative(0x2B40A976, function(entity) return true end) 
                 
                 susano.HookNative(0x5324A0E3E4CE3570, function(entity) return true end) 
                 
                 susano.HookNative(0x8DE82BC774F3B862, function() return true end) 
                 
                 susano.HookNative(0x2B1813BA58063D36, function() return true end) 
                 
                 
                 susano.HookNative(0x35FB78DC42B7BD21, function(modelHash) return false, true end) 
                 
                 susano.HookNative(0x392C8D8E07B70EFC, function(modelHash) return false, true end) 
                  
                 susano.HookNative(0x98A4EB5D89A0C952, function(modelHash) return false, true end) 
                 
                 susano.HookNative(0x963D27A58DF860AC, function(modelHash) return false end) 
                  
                 susano.HookNative(0xEA386986E786A54F, function(vehicle) return false end) 
                 
                  
                 susano.HookNative(0xAE3CBE5BF394C9C9, function(entity) 
                     local entityType = GetEntityType(entity) 
                     if entityType == 2 then 
                         return false 
                     end 
                     return true 
                 end) 
                 
                 
                 susano.HookNative(0x7D9EFB7AD6B19754, function(vehicle, toggle) return false end) 
                  
                 susano.HookNative(0x1CF38D529D7441D9, function(vehicle, toggle) return false end) 
                 
                 susano.HookNative(0x99AD4CCCB128CBC9, function(vehicle) return false end) 
                  
                 susano.HookNative(0xE5810AC70602F2F5, function(vehicle, speed) return false end) 
             end 
             
             
             Citizen.CreateThread(function() 
                 Wait(1000) 
                 
                 local ped = PlayerPedId() 
                 local coords = GetEntityCoords(ped) 
                 local heading = GetEntityHeading(ped) 
                 local offsetX = coords.x + math.sin(math.rad(heading)) * 3.0 
                 local offsetY = coords.y + math.cos(math.rad(heading)) * 3.0 
                 local offsetZ = coords.z 
                 
                 local modelHash = GetHashKey("%s") 
                 if modelHash == 0 then 
                     return 
                 end 
                 
                 RequestModel(modelHash) 
                 local timeout = 0 
                 while not HasModelLoaded(modelHash) and timeout < 200 do 
                     Citizen.Wait(10) 
                     timeout = timeout + 1 
                 end 
                 
                 if HasModelLoaded(modelHash) then 
                     Citizen.Wait(200) 
                     
                     local groundZ = offsetZ 
                     local found, ground = GetGroundZFor_3dCoord(offsetX, offsetY, offsetZ + 10.0, groundZ, false) 
                     if found then 
                         offsetZ = groundZ + 0.5 
                     end 
                     
                     local vehicle = Susano.CreateSpoofedVehicle(modelHash, offsetX, offsetY, offsetZ, heading, true, true, false) 
                     if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then 
                         local netId = NetworkGetNetworkIdFromEntity(vehicle) 
                         if netId and netId ~= 0 then 
                             SetNetworkIdCanMigrate(netId, false) 
                             SetNetworkIdExistsOnAllMachines(netId, true) 
                         end 
                         SetEntityAsMissionEntity(vehicle, true, true) 
                         SetVehicleHasBeenOwnedByPlayer(vehicle, true) 
                         SetVehicleNeedsToBeHotwired(vehicle, false) 
                         SetVehicleEngineOn(vehicle, true, true, false) 
                         SetVehicleOnGroundProperly(vehicle) 
                         
                         if %s then
                             Citizen.Wait(300) 
                             TaskWarpPedIntoVehicle(ped, vehicle, -1) 
                         end
                         
                         SetModelAsNoLongerNeeded(modelHash) 
                     end 
                 end 
             end) 
         ]], modelName, tostring(shouldTeleport))) 
     end
end


local function MaxUpgrade()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local susano = rawget(_G, "Susano")
            
            if susano and type(susano) == "table" and type(susano.HookNative) == "function" and not _max_upgrade_hooks_applied then
                _max_upgrade_hooks_applied = true
                
                susano.HookNative(0x8DE82BC774F3B862, function(entity)
                    return true
                end)
                
                susano.HookNative(0x4CEBC1ED31E8925E, function(entity)
                    return true
                end)
                
                susano.HookNative(0xAE3CBE5BF394C9C9, function(entity)
                    return true
                end)
                
                susano.HookNative(0x2B40A976, function(entity)
                    return true
                end)
                
                susano.HookNative(0xAD738C3085FE7E11, function(entity, p1, p2)
                    return true
                end)
            end
            
            CreateThread(function()
                Wait(100)
                
                local ped = PlayerPedId()
                local vehicle = GetVehiclePedIsIn(ped, false)
                
                if not vehicle or vehicle == 0 then
                    return
                end
                
                if not NetworkHasControlOfEntity(vehicle) then
                    NetworkRequestControlOfEntity(vehicle)
                    local timeout = 0
                    while not NetworkHasControlOfEntity(vehicle) and timeout < 200 do
                        Wait(10)
                        timeout = timeout + 1
                        NetworkRequestControlOfEntity(vehicle)
                    end
                end
                
                SetEntityAsMissionEntity(vehicle, true, true)
                
                SetVehicleModKit(vehicle, 0)
                
                SetVehicleWheelType(vehicle, 7)
                
                for modType = 0, 16 do
                    local numMods = GetNumVehicleMods(vehicle, modType)
                    if numMods and numMods > 0 then
                        SetVehicleMod(vehicle, modType, numMods - 1, false)
                    end
                end
                
                SetVehicleMod(vehicle, 14, 16, false)
                
                local numLivery = GetNumVehicleMods(vehicle, 15)
                if numLivery and numLivery > 1 then
                    SetVehicleMod(vehicle, 15, numLivery - 2, false)
                end
                
                for modType = 17, 22 do
                    ToggleVehicleMod(vehicle, modType, true)
                end
                
                SetVehicleMod(vehicle, 23, 1, false)
                SetVehicleMod(vehicle, 24, 1, false)
                
                for extra = 1, 12 do
                    if DoesExtraExist(vehicle, extra) then
                        SetVehicleExtra(vehicle, extra, false)
                    end
                end
                
                SetVehicleWindowTint(vehicle, 1)
                
                SetVehicleTyresCanBurst(vehicle, false)
                
                Wait(100)
                
                SetEntityAsMissionEntity(vehicle, false, true)
            end)
        ]])
    end
end


local function RepairVehicle()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local susano = rawget(_G, "Susano")
            
            if susano and type(susano) == "table" and type(susano.HookNative) == "function" and not _repair_vehicle_hooks_applied then
                _repair_vehicle_hooks_applied = true
                
                susano.HookNative(0x8DE82BC774F3B862, function(entity)
                    return true
                end)
                
                susano.HookNative(0x4CEBC1ED31E8925E, function(entity)
                    return true
                end)
                
                susano.HookNative(0xAE3CBE5BF394C9C9, function(entity)
                    return true
                end)
                
                susano.HookNative(0x2B40A976, function(entity)
                    return true
                end)
                
                susano.HookNative(0xAD738C3085FE7E11, function(entity, p1, p2)
                    return true
                end)
                
                susano.HookNative(0x115722B1B9C14C1C, function(vehicle)
                    return true
                end)
            end
            
            CreateThread(function()
                Wait(100)
                
                local ped = PlayerPedId()
                local vehicle = GetVehiclePedIsIn(ped, false)
                
                if not vehicle or vehicle == 0 then
                    return
                end
                
                if not NetworkHasControlOfEntity(vehicle) then
                    NetworkRequestControlOfEntity(vehicle)
                    local timeout = 0
                    while not NetworkHasControlOfEntity(vehicle) and timeout < 200 do
                        Wait(10)
                        timeout = timeout + 1
                        NetworkRequestControlOfEntity(vehicle)
                    end
                end
                
                SetEntityAsMissionEntity(vehicle, true, true)
                
                SetVehicleFixed(vehicle)
                SetVehicleDeformationFixed(vehicle)
                SetVehicleUndriveable(vehicle, false)
                SetVehicleEngineOn(vehicle, true, true, false)
                
                SetVehicleTyresCanBurst(vehicle, true)
                for i = 0, 3 do
                    SetVehicleTyreFixed(vehicle, i)
                end
                
                SetVehicleDoorsLocked(vehicle, 1)
                SetVehicleDoorsLockedForAllPlayers(vehicle, false)
                
                SetVehicleEngineHealth(vehicle, 1000.0)
                SetVehicleBodyHealth(vehicle, 1000.0)
                SetVehiclePetrolTankHealth(vehicle, 1000.0)
                
                SetVehicleDirtLevel(vehicle, 0.0)
                WashDecalsFromVehicle(vehicle, 1.0)
                
                Wait(100)
                
                SetEntityAsMissionEntity(vehicle, false, true)
            end)
        ]])
    end
end


local function RampVehicle()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            function hNative(nativeName, newFunction)
                local originalNative = _G[nativeName]
                if not originalNative or type(originalNative) ~= "function" then
                    return
                end
                _G[nativeName] = function(...)
                    return newFunction(originalNative, ...)
                end
            end
            hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
            hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
            hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedInVehicleSeat", function(originalFn, ...) return originalFn(...) end)
            hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
            hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
            hNative("GetEntityHeading", function(originalFn, ...) return originalFn(...) end)
            hNative("FindFirstVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("FindNextVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("EndFindVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("GetVehicleClass", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedIntoVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("Wait", function(originalFn, ...) return originalFn(...) end)
            hNative("SetEntityAsMissionEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkGetEntityIsNetworked", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkRequestControlOfEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("GetEntityForwardVector", function(originalFn, ...) return originalFn(...) end)
            hNative("AttachEntityToEntity", function(originalFn, ...) return originalFn(...) end)
            
            local playerPed = PlayerPedId()
            if not IsPedInAnyVehicle(playerPed, false) then
                return
            end
            
            local myVehicle = GetVehiclePedIsIn(playerPed, false)
            if not DoesEntityExist(myVehicle) or GetPedInVehicleSeat(myVehicle, -1) ~= playerPed then
                return
            end
            
            CreateThread(function()
                local myCoords = GetEntityCoords(myVehicle)
                local myHeading = GetEntityHeading(myVehicle)
                local vehicles = {}
                local searchRadius = 100.0
                local vehHandle, veh = FindFirstVehicle()
                local success
                
                repeat
                    local vehCoords = GetEntityCoords(veh)
                    local distance = #(myCoords - vehCoords)
                    local vehClass = GetVehicleClass(veh)
                    if distance <= searchRadius and veh ~= myVehicle and vehClass ~= 8 and vehClass ~= 13 then
                        table.insert(vehicles, {handle = veh, distance = distance})
                    end
                    success, veh = FindNextVehicle(vehHandle)
                until not success
                EndFindVehicle(vehHandle)
                
                if #vehicles < 3 then
                    return
                end
                
                table.sort(vehicles, function(a, b) return a.distance < b.distance end)
                local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle}
                
                local function takeControl(veh)
                    SetPedIntoVehicle(playerPed, veh, -1)
                    Wait(150)
                    SetEntityAsMissionEntity(veh, true, true)
                    if NetworkGetEntityIsNetworked(veh) then
                        NetworkRequestControlOfEntity(veh)
                        local timeout = 0
                        while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                            NetworkRequestControlOfEntity(veh)
                            Wait(10)
                            timeout = timeout + 1
                        end
                    end
                end
                
                for i = 1, 3 do
                    if DoesEntityExist(selectedVehicles[i]) then
                        takeControl(selectedVehicles[i])
                    end
                end
                
                SetPedIntoVehicle(playerPed, myVehicle, -1)
                Wait(100)
                
                local heading = GetEntityHeading(myVehicle)
                local forwardVector = GetEntityForwardVector(myVehicle)
                local vehCoords = GetEntityCoords(myVehicle)
                local rampPositions = {
                    {offsetX = -2.0, offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
                    {offsetX = 0.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
                    {offsetX = 2.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
                }
                
                for i = 1, 3 do
                    if DoesEntityExist(selectedVehicles[i]) then
                        local pos = rampPositions[i]
                        AttachEntityToEntity(selectedVehicles[i], myVehicle, 0, pos.offsetX, pos.offsetY, pos.offsetZ, pos.rotX, pos.rotY, pos.rotZ, false, false, true, false, 2, true)
                    end
                end
            end)
        ]])
    else
        local playerPed = PlayerPedId()
        if not IsPedInAnyVehicle(playerPed, false) then
            return
        end
        
        local myVehicle = GetVehiclePedIsIn(playerPed, false)
        if not DoesEntityExist(myVehicle) or GetPedInVehicleSeat(myVehicle, -1) ~= playerPed then
            return
        end
        
        CreateThread(function()
            local myCoords = GetEntityCoords(myVehicle)
            local myHeading = GetEntityHeading(myVehicle)
            local vehicles = {}
            local searchRadius = 100.0
            local vehHandle, veh = FindFirstVehicle()
            local success
            
            repeat
                local vehCoords = GetEntityCoords(veh)
                local distance = #(myCoords - vehCoords)
                local vehClass = GetVehicleClass(veh)
                if distance <= searchRadius and veh ~= myVehicle and vehClass ~= 8 and vehClass ~= 13 then
                    table.insert(vehicles, {handle = veh, distance = distance})
                end
                success, veh = FindNextVehicle(vehHandle)
            until not success
            EndFindVehicle(vehHandle)
            
            if #vehicles < 3 then
                return
            end
            
            table.sort(vehicles, function(a, b) return a.distance < b.distance end)
            local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle}
            
            local function takeControl(veh)
                SetPedIntoVehicle(playerPed, veh, -1)
                Wait(150)
                SetEntityAsMissionEntity(veh, true, true)
                if NetworkGetEntityIsNetworked(veh) then
                    NetworkRequestControlOfEntity(veh)
                    local timeout = 0
                    while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                        NetworkRequestControlOfEntity(veh)
                        Wait(10)
                        timeout = timeout + 1
                    end
                end
            end
            
            for i = 1, 3 do
                if DoesEntityExist(selectedVehicles[i]) then
                    takeControl(selectedVehicles[i])
                end
            end
            
            SetPedIntoVehicle(playerPed, myVehicle, -1)
            Wait(100)
            
            local heading = GetEntityHeading(myVehicle)
            local forwardVector = GetEntityForwardVector(myVehicle)
            local vehCoords = GetEntityCoords(myVehicle)
            local rampPositions = {
                {offsetX = -2.0, offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
                {offsetX = 0.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
                {offsetX = 2.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
            }
            
            for i = 1, 3 do
                if DoesEntityExist(selectedVehicles[i]) then
                    local pos = rampPositions[i]
                    AttachEntityToEntity(selectedVehicles[i], myVehicle, 0, pos.offsetX, pos.offsetY, pos.offsetZ, pos.rotX, pos.rotY, pos.rotZ, false, false, true, false, 2, true)
                end
            end
        end)
    end
end

local function WallVehicle()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            function hNative(nativeName, newFunction)
                local originalNative = _G[nativeName]
                if not originalNative or type(originalNative) ~= "function" then
                    return
                end
                _G[nativeName] = function(...)
                    return newFunction(originalNative, ...)
                end
            end
            hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
            hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
            hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedInVehicleSeat", function(originalFn, ...) return originalFn(...) end)
            hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
            hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
            hNative("GetEntityHeading", function(originalFn, ...) return originalFn(...) end)
            hNative("FindFirstVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("FindNextVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("EndFindVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("GetVehicleClass", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedIntoVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("Wait", function(originalFn, ...) return originalFn(...) end)
            hNative("SetEntityAsMissionEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkGetEntityIsNetworked", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkRequestControlOfEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("AttachEntityToEntity", function(originalFn, ...) return originalFn(...) end)

            local playerPed = PlayerPedId()
            if not IsPedInAnyVehicle(playerPed, false) then
                return
            end

            local myVehicle = GetVehiclePedIsIn(playerPed, false)
            if not DoesEntityExist(myVehicle) or GetPedInVehicleSeat(myVehicle, -1) ~= playerPed then
                return
            end

            CreateThread(function()
                local myCoords = GetEntityCoords(myVehicle)
                local vehicles = {}
                local searchRadius = 100.0
                local vehHandle, veh = FindFirstVehicle()
                local success

                repeat
                    local vehCoords = GetEntityCoords(veh)
                    local distance = #(myCoords - vehCoords)
                    local vehClass = GetVehicleClass(veh)
                    if distance <= searchRadius and veh ~= myVehicle and vehClass ~= 8 and vehClass ~= 13 then
                        table.insert(vehicles, {handle = veh, distance = distance})
                    end
                    success, veh = FindNextVehicle(vehHandle)
                until not success
                EndFindVehicle(vehHandle)

                if #vehicles < 3 then
                    return
                end

                table.sort(vehicles, function(a, b) return a.distance < b.distance end)
                local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle}

                local function takeControl(veh)
                    SetPedIntoVehicle(playerPed, veh, -1)
                    Wait(150)
                    SetEntityAsMissionEntity(veh, true, true)
                    if NetworkGetEntityIsNetworked(veh) then
                        NetworkRequestControlOfEntity(veh)
                        local timeout = 0
                        while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                            NetworkRequestControlOfEntity(veh)
                            Wait(10)
                            timeout = timeout + 1
                        end
                    end
                end

                for i = 1, 3 do
                    if DoesEntityExist(selectedVehicles[i]) then
                        takeControl(selectedVehicles[i])
                    end
                end

                SetPedIntoVehicle(playerPed, myVehicle, -1)
                Wait(100)

                local wallPositions = {
                    {offsetX = -2.0, offsetY = 2.5, offsetZ = 0.2, rotX = 0.0, rotY = 0.0, rotZ = 0.0},
                    {offsetX = 0.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 0.0, rotY = 0.0, rotZ = 0.0},
                    {offsetX = 2.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 0.0, rotY = 0.0, rotZ = 0.0},
                }

                for i = 1, 3 do
                    if DoesEntityExist(selectedVehicles[i]) then
                        local pos = wallPositions[i]
                        AttachEntityToEntity(selectedVehicles[i], myVehicle, 0, pos.offsetX, pos.offsetY, pos.offsetZ, pos.rotX, pos.rotY, pos.rotZ, false, false, true, false, 2, true)
                    end
                end
            end)
        ]])
    else
        local playerPed = PlayerPedId()
        if not IsPedInAnyVehicle(playerPed, false) then
            return
        end

        local myVehicle = GetVehiclePedIsIn(playerPed, false)
        if not DoesEntityExist(myVehicle) or GetPedInVehicleSeat(myVehicle, -1) ~= playerPed then
            return
        end

        CreateThread(function()
            local myCoords = GetEntityCoords(myVehicle)
            local vehicles = {}
            local searchRadius = 100.0
            local vehHandle, veh = FindFirstVehicle()
            local success

            repeat
                local vehCoords = GetEntityCoords(veh)
                local distance = #(myCoords - vehCoords)
                local vehClass = GetVehicleClass(veh)
                if distance <= searchRadius and veh ~= myVehicle and vehClass ~= 8 and vehClass ~= 13 then
                    table.insert(vehicles, {handle = veh, distance = distance})
                end
                success, veh = FindNextVehicle(vehHandle)
            until not success
            EndFindVehicle(vehHandle)

            if #vehicles < 3 then
                return
            end

            table.sort(vehicles, function(a, b) return a.distance < b.distance end)
            local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle}

            local function takeControl(veh)
                SetPedIntoVehicle(playerPed, veh, -1)
                Wait(150)
                SetEntityAsMissionEntity(veh, true, true)
                if NetworkGetEntityIsNetworked(veh) then
                    NetworkRequestControlOfEntity(veh)
                    local timeout = 0
                    while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                        NetworkRequestControlOfEntity(veh)
                        Wait(10)
                        timeout = timeout + 1
                    end
                end
            end

            for i = 1, 3 do
                if DoesEntityExist(selectedVehicles[i]) then
                    takeControl(selectedVehicles[i])
                end
            end

            SetPedIntoVehicle(playerPed, myVehicle, -1)
            Wait(100)

            local wallPositions = {
                {offsetX = -2.0, offsetY = 2.5, offsetZ = 0.2, rotX = 0.0, rotY = 0.0, rotZ = 0.0},
                {offsetX = 0.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 0.0, rotY = 0.0, rotZ = 0.0},
                {offsetX = 2.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 0.0, rotY = 0.0, rotZ = 0.0},
            }

            for i = 1, 3 do
                if DoesEntityExist(selectedVehicles[i]) then
                    local pos = wallPositions[i]
                    AttachEntityToEntity(selectedVehicles[i], myVehicle, 0, pos.offsetX, pos.offsetY, pos.offsetZ, pos.rotX, pos.rotY, pos.rotZ, false, false, true, false, 2, true)
                end
            end
        end)
    end
end

local function Wall2Vehicle()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            function hNative(nativeName, newFunction)
                local originalNative = _G[nativeName]
                if not originalNative or type(originalNative) ~= "function" then
                    return
                end
                _G[nativeName] = function(...)
                    return newFunction(originalNative, ...)
                end
            end
            hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
            hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
            hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedInVehicleSeat", function(originalFn, ...) return originalFn(...) end)
            hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
            hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
            hNative("FindFirstVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("FindNextVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("EndFindVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("GetVehicleClass", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedIntoVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("Wait", function(originalFn, ...) return originalFn(...) end)
            hNative("SetEntityAsMissionEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkGetEntityIsNetworked", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkRequestControlOfEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("AttachEntityToEntity", function(originalFn, ...) return originalFn(...) end)

            local playerPed = PlayerPedId()
            if not IsPedInAnyVehicle(playerPed, false) then
                return
            end

            local myVehicle = GetVehiclePedIsIn(playerPed, false)
            if not DoesEntityExist(myVehicle) or GetPedInVehicleSeat(myVehicle, -1) ~= playerPed then
                return
            end

            CreateThread(function()
                local myCoords = GetEntityCoords(myVehicle)
                local vehicles = {}
                local searchRadius = 100.0
                local vehHandle, veh = FindFirstVehicle()
                local success

                repeat
                    local vehCoords = GetEntityCoords(veh)
                    local distance = #(myCoords - vehCoords)
                    local vehClass = GetVehicleClass(veh)
                    if distance <= searchRadius and veh ~= myVehicle and vehClass ~= 8 and vehClass ~= 13 then
                        table.insert(vehicles, {handle = veh, distance = distance})
                    end
                    success, veh = FindNextVehicle(vehHandle)
                until not success
                EndFindVehicle(vehHandle)

                if #vehicles < 3 then
                    return
                end

                table.sort(vehicles, function(a, b) return a.distance < b.distance end)
                local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle}

                local function takeControl(veh)
                    SetPedIntoVehicle(playerPed, veh, -1)
                    Wait(150)
                    SetEntityAsMissionEntity(veh, true, true)
                    if NetworkGetEntityIsNetworked(veh) then
                        NetworkRequestControlOfEntity(veh)
                        local timeout = 0
                        while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                            NetworkRequestControlOfEntity(veh)
                            Wait(10)
                            timeout = timeout + 1
                        end
                    end
                end

                for i = 1, 3 do
                    if DoesEntityExist(selectedVehicles[i]) then
                        takeControl(selectedVehicles[i])
                    end
                end

                SetPedIntoVehicle(playerPed, myVehicle, -1)
                Wait(100)

                local wall2Positions = {
                    {offsetX = -2.0, offsetY = 2.5, offsetZ = 0.6, rotX = 90.0, rotY = 0.0, rotZ = 0.0},
                    {offsetX = 0.0,  offsetY = 2.5, offsetZ = 0.6, rotX = 90.0, rotY = 0.0, rotZ = 0.0},
                    {offsetX = 2.0,  offsetY = 2.5, offsetZ = 0.6, rotX = 90.0, rotY = 0.0, rotZ = 0.0},
                }

                for i = 1, 3 do
                    if DoesEntityExist(selectedVehicles[i]) then
                        local pos = wall2Positions[i]
                        AttachEntityToEntity(selectedVehicles[i], myVehicle, 0, pos.offsetX, pos.offsetY, pos.offsetZ, pos.rotX, pos.rotY, pos.rotZ, false, false, true, false, 2, true)
                    end
                end
            end)
        ]])
    else
        local playerPed = PlayerPedId()
        if not IsPedInAnyVehicle(playerPed, false) then
            return
        end

        local myVehicle = GetVehiclePedIsIn(playerPed, false)
        if not DoesEntityExist(myVehicle) or GetPedInVehicleSeat(myVehicle, -1) ~= playerPed then
            return
        end

        CreateThread(function()
            local myCoords = GetEntityCoords(myVehicle)
            local vehicles = {}
            local searchRadius = 100.0
            local vehHandle, veh = FindFirstVehicle()
            local success

            repeat
                local vehCoords = GetEntityCoords(veh)
                local distance = #(myCoords - vehCoords)
                local vehClass = GetVehicleClass(veh)
                if distance <= searchRadius and veh ~= myVehicle and vehClass ~= 8 and vehClass ~= 13 then
                    table.insert(vehicles, {handle = veh, distance = distance})
                end
                success, veh = FindNextVehicle(vehHandle)
            until not success
            EndFindVehicle(vehHandle)

            if #vehicles < 3 then
                return
            end

            table.sort(vehicles, function(a, b) return a.distance < b.distance end)
            local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle}

            local function takeControl(veh)
                SetPedIntoVehicle(playerPed, veh, -1)
                Wait(150)
                SetEntityAsMissionEntity(veh, true, true)
                if NetworkGetEntityIsNetworked(veh) then
                    NetworkRequestControlOfEntity(veh)
                    local timeout = 0
                    while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                        NetworkRequestControlOfEntity(veh)
                        Wait(10)
                        timeout = timeout + 1
                    end
                end
            end

            for i = 1, 3 do
                if DoesEntityExist(selectedVehicles[i]) then
                    takeControl(selectedVehicles[i])
                end
            end

            SetPedIntoVehicle(playerPed, myVehicle, -1)
            Wait(100)

            local wall2Positions = {
                {offsetX = -2.0, offsetY = 2.5, offsetZ = 0.6, rotX = 90.0, rotY = 0.0, rotZ = 0.0},
                {offsetX = 0.0,  offsetY = 2.5, offsetZ = 0.6, rotX = 90.0, rotY = 0.0, rotZ = 0.0},
                {offsetX = 2.0,  offsetY = 2.5, offsetZ = 0.6, rotX = 90.0, rotY = 0.0, rotZ = 0.0},
            }

            for i = 1, 3 do
                if DoesEntityExist(selectedVehicles[i]) then
                    local pos = wall2Positions[i]
                    AttachEntityToEntity(selectedVehicles[i], myVehicle, 0, pos.offsetX, pos.offsetY, pos.offsetZ, pos.rotX, pos.rotY, pos.rotZ, false, false, true, false, 2, true)
                end
            end
        end)
    end
end


local function ToggleForceVehicleEngine(enable)
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local susano = rawget(_G, "Susano")
            
            if susano and type(susano) == "table" and type(susano.HookNative) == "function" and not _force_engine_hooks_applied then
                _force_engine_hooks_applied = true
                
                susano.HookNative(0x8DE82BC774F3B862, function(entity)
                    return true
                end)
                
                susano.HookNative(0x4CEBC1ED31E8925E, function(entity)
                    return true
                end)
                
                susano.HookNative(0xAE3CBE5BF394C9C9, function(entity)
                    return true
                end)
                
                susano.HookNative(0x2B40A976, function(entity)
                    return true
                end)
                
                susano.HookNative(0xAD738C3085FE7E11, function(entity, p1, p2)
                    return true
                end)
            end
            
            _G.ForceVehicleEngineEnabled = %s
            
            if _G.ForceVehicleEngineThread then
            end
            
            _G.ForceVehicleEngineThread = CreateThread(function()
                while _G.ForceVehicleEngineEnabled do
                    Wait(0)
                    
                    local ped = PlayerPedId()
                    local vehicle = GetVehiclePedIsIn(ped, false)
                    
                    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                        if not NetworkHasControlOfEntity(vehicle) then
                            NetworkRequestControlOfEntity(vehicle)
                        end
                        
                        SetVehicleEngineOn(vehicle, true, true, false)
                        
                        SetVehicleEngineHealth(vehicle, 1000.0)
                        
                        SetVehicleUndriveable(vehicle, false)
                    end
                end
                
                _G.ForceVehicleEngineThread = nil
            end)
        ]], tostring(enable)))
    end
end


local function ToggleShiftBoost(enable)
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            if QwErTyUiOpSh == nil then QwErTyUiOpSh = false end
            QwErTyUiOpSh = %s
            
            if QwErTyUiOpSh then
                local function ZxCvBnMmLl()
                    CreateThread(function()
                        while QwErTyUiOpSh and not Unloaded do
                            local ped = PlayerPedId()
                            if IsPedInAnyVehicle(ped, false) then
                                local veh = GetVehiclePedIsIn(ped, false)
                                if veh ~= 0 and IsDisabledControlJustPressed(0, 21) then
                                    SetVehicleForwardSpeed(veh, 150.0)
                                end
                            end
                            Wait(0)
                        end
                    end)
                end
                ZxCvBnMmLl()
            end
        ]], tostring(enable)))
    end
end


local spawnItems = {"Car", "Moto", "Plane", "Boat"}
for _, itemName in ipairs(spawnItems) do
    local item = FindItem("Vehicle", "Spawn", itemName)
    if item then
        item.onClick = function(index, option)
            SpawnVehicle(option)
        end
    end
end


Actions.maxUpgradeItem = FindItem("Vehicle", "Performance", "Max Upgrade")
if Actions.maxUpgradeItem then
    Actions.maxUpgradeItem.onClick = function()
        MaxUpgrade()
    end
end


Actions.repairVehicleItem = FindItem("Vehicle", "Performance", "Repair Vehicle")
if Actions.repairVehicleItem then
    Actions.repairVehicleItem.onClick = function()
        RepairVehicle()
    end
end

Actions.throwFromVehicleItem = FindItem("Vehicle", "Performance", "Throw From Vehicle")
if Actions.throwFromVehicleItem then
    Actions.throwFromVehicleItem.onClick = function()
        local isEnabled = Actions.throwFromVehicleItem.value
        
        if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
            return
        end
        
        if isEnabled then
            Susano.InjectResource("any", [[
                rawset(_G, 'ThrowFromVehicleEnabled', true)
                
                if not rawget(_G, 'ThrowFromVehicleThread') then
                    rawset(_G, 'ThrowFromVehicleThread', true)
                    
                    CreateThread(function()
                        while not Unloaded do
                            if rawget(_G, 'ThrowFromVehicleEnabled') then
                                SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), GetHashKey('PLAYER'))
                            else
                                SetRelationshipBetweenGroups(1, GetHashKey('PLAYER'), GetHashKey('PLAYER'))
                                SetRelationshipBetweenGroups(0, GetHashKey('PLAYER'), GetHashKey('PLAYER'))
                            end
                            Wait(0)
                        end
                        
                        SetRelationshipBetweenGroups(1, GetHashKey('PLAYER'), GetHashKey('PLAYER'))
                        SetRelationshipBetweenGroups(0, GetHashKey('PLAYER'), GetHashKey('PLAYER'))
                    end)
                end
            ]])
        else
            Susano.InjectResource("any", [[
                rawset(_G, 'ThrowFromVehicleEnabled', false)
                SetRelationshipBetweenGroups(1, GetHashKey('PLAYER'), GetHashKey('PLAYER'))
                SetRelationshipBetweenGroups(0, GetHashKey('PLAYER'), GetHashKey('PLAYER'))
                ClearRelationshipBetweenGroups(5, GetHashKey('PLAYER'), GetHashKey('PLAYER'))
            ]])
        end
    end
end


local function ToggleEasyHandling(enable)
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            if _G.EasyHandlingEnabled == nil then _G.EasyHandlingEnabled = false end
            _G.EasyHandlingEnabled = %s

            if _G.EasyHandlingEnabled then
                local function StartEasyHandling()
                    CreateThread(function()
                        while _G.EasyHandlingEnabled and not Unloaded do
                            Wait(0)
                            local ped = PlayerPedId()
                            if ped and ped ~= 0 then
                                local veh = GetVehiclePedIsIn(ped, false)
                                if veh and veh ~= 0 and DoesEntityExist(veh) then
                                    SetVehicleGravityAmount(veh, 73.0)
                                    SetVehicleHandlingFloat(veh, "CHandlingData", "fMass", 500.0)
                                    SetVehicleHandlingFloat(veh, "CHandlingData", "fInitialDragCoeff", 5.0)
                                    SetVehicleHandlingFloat(veh, "CHandlingData", "fTractionLossMult", 0.0)
                                    SetVehicleHandlingFloat(veh, "CHandlingData", "fLowSpeedTractionLossMult", 0.0)
                                    SetVehicleHandlingFloat(veh, "CHandlingData", "fSteeringLock", 40.0)
                                    ModifyVehicleTopSpeed(veh, 1.5)
                                end
                            end
                        end
                    end)
                end
                StartEasyHandling()
            else
                local ped = PlayerPedId()
                if ped and ped ~= 0 then
                    local veh = GetVehiclePedIsIn(ped, false)
                    if veh and veh ~= 0 and DoesEntityExist(veh) then
                        SetVehicleGravityAmount(veh, 9.8)
                        SetVehicleHandlingFloat(veh, "CHandlingData", "fMass", 1500.0)
                        SetVehicleHandlingFloat(veh, "CHandlingData", "fInitialDragCoeff", 10.0)
                        ModifyVehicleTopSpeed(veh, 1.0)
                    end
                end
            end
        ]], tostring(enable)))
    end
end

Actions.forceEngineItem = FindItem("Vehicle", "Performance", "Force Vehicle Engine")
if Actions.forceEngineItem then
    Actions.forceEngineItem.onClick = function(value)
        ToggleForceVehicleEngine(value)
    end
end

Actions.easyHandlingItem = FindItem("Vehicle", "Performance", "Easy Handling")
if Actions.easyHandlingItem then
    Actions.easyHandlingItem.onClick = function(value)
        ToggleEasyHandling(value)
    end
end

local function ToggleNoCollision(enable)
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            function hNative(nativeName, newFunction)
                local originalNative = _G[nativeName]
                if not originalNative or type(originalNative) ~= "function" then
                    return
                end
                _G[nativeName] = function(...)
                    return newFunction(originalNative, ...)
                end
            end
            hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
            hNative("Wait", function(originalFn, ...) return originalFn(...) end)
            hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
            hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
            hNative("SetEntityNoCollisionEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
            hNative("FindFirstVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("FindNextVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("EndFindVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
            
            if not _G.no_vehicle_collision_active then
                _G.no_vehicle_collision_active = false
            end
            _G.no_vehicle_collision_active = %s
            
            if _G.no_vehicle_collision_active then
                CreateThread(function()
                    while _G.no_vehicle_collision_active do
                        Wait(0)
                        
                        local ped = PlayerPedId()
                        if IsPedInAnyVehicle(ped, false) then
                            local veh = GetVehiclePedIsIn(ped, false)
                            if veh and veh ~= 0 then
                                SetEntityNoCollisionEntity(veh, veh, false)
                                
                                local myCoords = GetEntityCoords(veh)
                                local vehHandle, otherVeh = FindFirstVehicle()
                                local success
                                
                                repeat
                                    if otherVeh ~= veh and DoesEntityExist(otherVeh) then
                                        local otherCoords = GetEntityCoords(otherVeh)
                                        local distance = #(myCoords - otherCoords)
                                        
                                        if distance < 50.0 then
                                            SetEntityNoCollisionEntity(veh, otherVeh, true)
                                            SetEntityNoCollisionEntity(otherVeh, veh, true)
                                        end
                                    end
                                    
                                    success, otherVeh = FindNextVehicle(vehHandle)
                                until not success
                                
                                EndFindVehicle(vehHandle)
                            end
                        end
                    end
                end)
            end
        ]], tostring(enable)))
    else
        if enable then
            rawset(_G, 'no_vehicle_collision_active', true)
            
            CreateThread(function()
                while rawget(_G, 'no_vehicle_collision_active') do
                    Wait(0)
                    
                    local ped = PlayerPedId()
                    if IsPedInAnyVehicle(ped, false) then
                        local veh = GetVehiclePedIsIn(ped, false)
                        if veh and veh ~= 0 then
                            SetEntityNoCollisionEntity(veh, veh, false)
                            
                            local myCoords = GetEntityCoords(veh)
                            local vehHandle, otherVeh = FindFirstVehicle()
                            local success
                            
                            repeat
                                if otherVeh ~= veh and DoesEntityExist(otherVeh) then
                                    local otherCoords = GetEntityCoords(otherVeh)
                                    local distance = #(myCoords - otherCoords)
                                    
                                    if distance < 50.0 then
                                        SetEntityNoCollisionEntity(veh, otherVeh, true)
                                        SetEntityNoCollisionEntity(otherVeh, veh, true)
                                    end
                                end
                                
                                success, otherVeh = FindNextVehicle(vehHandle)
                            until not success
                            
                            EndFindVehicle(vehHandle)
                        end
                    end
                end
            end)
        else
            rawset(_G, 'no_vehicle_collision_active', false)
        end
    end
end

local function ToggleBunnyHop(enable)
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            function hNative(nativeName, newFunction)
                local originalNative = _G[nativeName]
                if not originalNative or type(originalNative) ~= "function" then
                    return
                end
                _G[nativeName] = function(...)
                    return newFunction(originalNative, ...)
                end
            end
            hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
            hNative("Wait", function(originalFn, ...) return originalFn(...) end)
            hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
            hNative("IsPedInAnyVehicle", function(originalFn, ...) return originalFn(...) end)
            hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
            hNative("ApplyForceToEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("IsControlJustPressed", function(originalFn, ...) return originalFn(...) end)
            hNative("IsControlPressed", function(originalFn, ...) return originalFn(...) end)
            hNative("IsDisabledControlPressed", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("NetworkRequestControlOfEntity", function(originalFn, ...) return originalFn(...) end)
            hNative("GetGameTimer", function(originalFn, ...) return originalFn(...) end)
            
            if not _G.bunny_hop_active then
                _G.bunny_hop_active = false
            end
            _G.bunny_hop_active = %s
            
            if _G.bunny_hop_active then
                CreateThread(function()
                    local lastJumpTime = 0
                    while _G.bunny_hop_active do
                        Wait(0)
                        
                        local ped = PlayerPedId()
                        if IsPedInAnyVehicle(ped, false) then
                            local veh = GetVehiclePedIsIn(ped, false)
                            if veh and veh ~= 0 then
                                local currentTime = GetGameTimer()
                                if IsControlJustPressed(0, 22) and (currentTime - lastJumpTime) > 200 then
                                    if not NetworkHasControlOfEntity(veh) then
                                        NetworkRequestControlOfEntity(veh)
                                    end
                                    
                                    ApplyForceToEntity(veh, 1, 0.0, 0.0, 12.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
                                    lastJumpTime = currentTime
                                end
                            end
                        end
                    end
                end)
            end
        ]], tostring(enable)))
    else
        if enable then
            rawset(_G, 'bunny_hop_active', true)
            
            CreateThread(function()
                local lastJumpTime = 0
                while rawget(_G, 'bunny_hop_active') do
                    Wait(0)
                    
                    local ped = PlayerPedId()
                    if IsPedInAnyVehicle(ped, false) then
                        local veh = GetVehiclePedIsIn(ped, false)
                        if veh and veh ~= 0 then
                            local currentTime = GetGameTimer()
                            if IsControlJustPressed(0, 22) and (currentTime - lastJumpTime) > 200 then
                                if not NetworkHasControlOfEntity(veh) then
                                    NetworkRequestControlOfEntity(veh)
                                end
                                
                                ApplyForceToEntity(veh, 1, 0.0, 0.0, 12.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
                                lastJumpTime = currentTime
                            end
                        end
                    end
                end
            end)
        else
            rawset(_G, 'bunny_hop_active', false)
        end
    end
end


function Menu.ActionChangePlate()
    if Menu and Menu.OpenInput then
        Menu.OpenInput("Change Plate", "Entrez le texte de la plaque (max 8 caractÃ¨res):", function(input)
            if input and input ~= "" then
                local plateText = string.sub(input, 1, 8)
                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                    Susano.InjectResource("any", string.format([[
                        local playerPed = PlayerPedId()
                        if not playerPed or not DoesEntityExist(playerPed) then return end

                        local vehicle = GetVehiclePedIsIn(playerPed, false)
                        if vehicle == 0 or not DoesEntityExist(vehicle) then
                            local coords = GetEntityCoords(playerPed)
                            vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 10.0, 0, 70)
                        end

                        if vehicle ~= 0 and DoesEntityExist(vehicle) then
                            SetVehicleNumberPlateText(vehicle, "%s")
                            SetVehicleNumberPlateTextIndex(vehicle, 0)
                        end
                    ]], plateText))
                end
            end
        end)
    end
end


function Menu.ActionCleanVehicle()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then return end
            
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            if vehicle == 0 or not DoesEntityExist(vehicle) then
                local coords = GetEntityCoords(playerPed)
                vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 10.0, 0, 70)
            end
            
            if vehicle ~= 0 and DoesEntityExist(vehicle) then
                SetVehicleDirtLevel(vehicle, 0.0)
                WashDecalsFromVehicle(vehicle, 1.0)
                SetVehicleFixed(vehicle)
                SetVehicleDeformationFixed(vehicle)
                SetVehicleUndriveable(vehicle, false)
                SetVehicleEngineOn(vehicle, true, true, false)
            end
        ]])
    end
end

function Menu.ActionFlipVehicle()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local function vXmYLT9pq2()
                local a = PlayerPedId
                local b = GetVehiclePedIsIn
                local c = GetEntityHeading
                local d = SetEntityRotation

                local ped = a()
                local veh = b(ped, false)
                if veh and veh ~= 0 then
                    d(veh, 0.0, 0.0, c(veh))
                end
            end

            vXmYLT9pq2()
        ]])
    end
end

local function ToggleBackFlip(enable)
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            if BackFlipEnabled == nil then BackFlipEnabled = false end
            BackFlipEnabled = %s

            if BackFlipEnabled then
                CreateThread(function()
                    while BackFlipEnabled and not Unloaded do
                        Wait(0)

                        if IsControlJustPressed(0, 22) then 
                            local playerPed = PlayerPedId()
                            local playerVeh = GetVehiclePedIsIn(playerPed, true)

                            if DoesEntityExist(playerVeh) then
                                ApplyForceToEntity(
                                    playerVeh,
                                    1,
                                    0.0, 0.0, 15.0,   
                                    0.0, 60.0, 0.0,   
                                    0,
                                    false, true, true, false, true
                                )
                            end
                        end
                    end
                end)
            end
        ]], tostring(enable)))
    end
end

function Menu.ActionNPCDrive()
    if not Menu.SelectedPlayer then return end

    local targetServerId = Menu.SelectedPlayer

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
CreateThread(function()
    if rawget(_G, 'warp_boost_busy') then return end
    rawset(_G, 'warp_boost_busy', true)

    local targetServerId = %d

    local targetPlayerId = nil
    for _, player in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(player) == targetServerId then
            targetPlayerId = player
            break
        end
    end

    if not targetPlayerId then
        rawset(_G, 'warp_boost_busy', false)
        return
    end

    local targetPed = GetPlayerPed(targetPlayerId)
    if not DoesEntityExist(targetPed) then
        rawset(_G, 'warp_boost_busy', false)
        return
    end

    if not IsPedInAnyVehicle(targetPed, false) then
        rawset(_G, 'warp_boost_busy', false)
        return
    end

    local targetVehicle = GetVehiclePedIsIn(targetPed, false)
    if not DoesEntityExist(targetVehicle) then
        rawset(_G, 'warp_boost_busy', false)
        return
    end

    local playerPed = PlayerPedId()
    local initialCoords = GetEntityCoords(playerPed)
    local initialHeading = GetEntityHeading(playerPed)

    local function RequestControl(entity, timeoutMs)
        if not entity or not DoesEntityExist(entity) then return false end
        local start = GetGameTimer()
        NetworkRequestControlOfEntity(entity)
        while not NetworkHasControlOfEntity(entity) do
            Wait(0)
            if GetGameTimer() - start > (timeoutMs or 500) then
                return false
            end
            NetworkRequestControlOfEntity(entity)
        end
        return true
    end

    RequestControl(targetVehicle, 800)
    SetVehicleDoorsLocked(targetVehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

    local function tryEnterSeat(seatIndex)
        SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
        Wait(0)
        return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
    end

    local function getFirstFreeSeat(v)
        local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
        if not numSeats or numSeats <= 0 then return -1 end
        for seat = 0, (numSeats - 2) do
            if IsVehicleSeatFree(v, seat) then return seat end
        end
        return -1
    end

    ClearPedTasksImmediately(playerPed)
    SetVehicleDoorsLocked(targetVehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

    local takeoverSuccess = false
    local tStart = GetGameTimer()

    while (GetGameTimer() - tStart) < 1000 do
        RequestControl(targetVehicle, 400)

        if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
            takeoverSuccess = true
            break
        end

        if not IsPedInVehicle(playerPed, targetVehicle, false) then
            local fs = getFirstFreeSeat(targetVehicle)
            if fs ~= -1 then
                tryEnterSeat(fs)
            end
        end

        local drv = GetPedInVehicleSeat(targetVehicle, -1)
        if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
            RequestControl(drv, 400)
            ClearPedTasksImmediately(drv)
            SetEntityAsMissionEntity(drv, true, true)
            SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
            Wait(20)
            DeleteEntity(drv)
        end

        local t0 = GetGameTimer()
        while (GetGameTimer() - t0) < 400 do
            local occ = GetPedInVehicleSeat(targetVehicle, -1)
            if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
            Wait(0)
        end

        local t1 = GetGameTimer()
        while (GetGameTimer() - t1) < 500 do
            if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                takeoverSuccess = true
                break
            end
            Wait(0)
        end
        if takeoverSuccess then break end
        Wait(0)
    end

    if takeoverSuccess then
        Wait(500)
        SetEntityCoordsNoOffset(playerPed, initialCoords.x, initialCoords.y, initialCoords.z, false, false, false, false)
        SetEntityHeading(playerPed, initialHeading)

        if DoesEntityExist(targetVehicle) then
            RequestControl(targetVehicle, 1000)

            local model = GetHashKey("s_m_y_marine_01")
            RequestModel(model)
            local tModel = GetGameTimer()
            while not HasModelLoaded(model) and (GetGameTimer() - tModel) < 2000 do Wait(0) end

            if HasModelLoaded(model) then
                local npc = CreatePedInsideVehicle(targetVehicle, 4, model, -1, false, false)

                if not DoesEntityExist(npc) then
                    local vehCoords = GetEntityCoords(targetVehicle)
                    npc = CreatePed(4, model, vehCoords.x, vehCoords.y, vehCoords.z + 2.0, 0.0, false, false)
                    if DoesEntityExist(npc) then
                        SetPedIntoVehicle(npc, targetVehicle, -1)
                    end
                end

                if DoesEntityExist(npc) then
                    SetEntityAsMissionEntity(npc, true, false)
                    SetBlockingOfNonTemporaryEvents(npc, true)
                    SetPedRandomComponentVariation(npc, 0)

                    Wait(200)
                    TaskVehicleDriveWander(npc, targetVehicle, 30.0, 786603)
                end
            end
        end
    else
        local dist = #(GetEntityCoords(playerPed) - initialCoords)
        if dist > 10.0 then
            SetEntityCoordsNoOffset(playerPed, initialCoords.x, initialCoords.y, initialCoords.z, false, false, false, false)
        end
    end

    rawset(_G, 'warp_boost_busy', false)
end)
        ]], targetServerId)

        Susano.InjectResource("any", WrapWithVehicleHooks(code))
    end
end

function Menu.ActionDeleteVehicle()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then return end
            
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            if vehicle == 0 or not DoesEntityExist(vehicle) then
                local coords = GetEntityCoords(playerPed)
                vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 10.0, 0, 70)
            end
            
            if vehicle ~= 0 and DoesEntityExist(vehicle) then
                SetEntityAsMissionEntity(vehicle, true, true)
                if NetworkGetEntityIsNetworked(vehicle) then
                    NetworkRequestControlOfEntity(vehicle)
                    local attempts = 0
                    while not NetworkHasControlOfEntity(vehicle) and attempts < 50 do
                        Wait(0)
                        attempts = attempts + 1
                        NetworkRequestControlOfEntity(vehicle)
                    end
                end
                DeleteEntity(vehicle)
            end
        ]])
    end
end

CreateThread(function()
    while true do
        Wait(500)
        if Menu.unlockAllVehicleEnabled then
            local ped = PlayerPedId()
            if IsPedOnFoot(ped) then
                local pos = GetEntityCoords(ped)
                local veh = GetClosestVehicle(pos, 3.5, 0, 70)

                if veh ~= 0 then
                    local locked = GetVehicleDoorLockStatus(veh)

                    if locked > 1 then
                        SetVehicleDoorsLocked(veh, 1)
                        SetVehicleDoorsLockedForAllPlayers(veh, false)
                        SetVehicleDoorsLockedForPlayer(veh, PlayerId(), false)
                    end
                end
            end
    end
end
end)

function Menu.ActionTeleportIntoClosestVehicle()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then return end
            
            if IsPedInAnyVehicle(playerPed, false) then return end
            
            local coords = GetEntityCoords(playerPed)
            local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 200.0, 0, 70)
            
            if vehicle ~= 0 and DoesEntityExist(vehicle) then
                SetEntityAsMissionEntity(vehicle, true, true)
                if NetworkGetEntityIsNetworked(vehicle) then
                    NetworkRequestControlOfEntity(vehicle)
                    local attempts = 0
                    while not NetworkHasControlOfEntity(vehicle) and attempts < 100 do
                        Wait(0)
                        attempts = attempts + 1
                        NetworkRequestControlOfEntity(vehicle)
                    end
                end
                
                SetVehicleDoorsLocked(vehicle, 1)
                SetVehicleDoorsLockedForAllPlayers(vehicle, false)
                
                local freeSeat = -1
                local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
                
                if GetPedInVehicleSeat(vehicle, -1) == 0 then
                    freeSeat = -1
                else
                    for i = 0, maxSeats - 1 do
                        if GetPedInVehicleSeat(vehicle, i) == 0 then
                            freeSeat = i
                            break
                        end
                    end
                end
                
                if freeSeat ~= -1 then
                    ClearPedTasksImmediately(playerPed)
                    Wait(50)
                    SetPedIntoVehicle(playerPed, vehicle, freeSeat)
                    Wait(100)
                    
                    if not IsPedInVehicle(playerPed, vehicle, false) then
                        local vehicleCoords = GetEntityCoords(vehicle)
                        SetEntityCoords(playerPed, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 1.0, false, false, false, false)
                        Wait(50)
                        SetPedIntoVehicle(playerPed, vehicle, freeSeat)
                    end
                    
                else
                end
            else
            end
        ]])
    end
end

function Menu.ActionGiveNearestVehicle()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            local playerPed = PlayerPedId()
            if not playerPed or not DoesEntityExist(playerPed) then return end
            
            local playerCoords = GetEntityCoords(playerPed)
            local playerHeading = GetEntityHeading(playerPed)
            
            local coords = GetEntityCoords(playerPed)
            local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 200.0, 0, 70)
            
            if vehicle ~= 0 and DoesEntityExist(vehicle) then
                SetEntityAsMissionEntity(vehicle, true, true)
                if NetworkGetEntityIsNetworked(vehicle) then
                    NetworkRequestControlOfEntity(vehicle)
                    local attempts = 0
                    while not NetworkHasControlOfEntity(vehicle) and attempts < 100 do
                        Wait(0)
                        attempts = attempts + 1
                        NetworkRequestControlOfEntity(vehicle)
                    end
                end
                
                SetVehicleDoorsLocked(vehicle, 1)
                SetVehicleDoorsLockedForAllPlayers(vehicle, false)
                
                local freeSeat = -1
                local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
                
                if GetPedInVehicleSeat(vehicle, -1) == 0 then
                    freeSeat = -1
                else
                    for i = 0, maxSeats - 1 do
                        if GetPedInVehicleSeat(vehicle, i) == 0 then
                            freeSeat = i
                            break
                        end
                    end
                end
                
                if freeSeat ~= -1 then
                    ClearPedTasksImmediately(playerPed)
                    Wait(50)
                    SetPedIntoVehicle(playerPed, vehicle, freeSeat)
                    Wait(100)
                    
                    if not IsPedInVehicle(playerPed, vehicle, false) then
                        local vehicleCoords = GetEntityCoords(vehicle)
                        SetEntityCoords(playerPed, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 1.0, false, false, false, false)
                        Wait(50)
                        SetPedIntoVehicle(playerPed, vehicle, freeSeat)
                    end
                    
                    Wait(200)
                    if IsPedInVehicle(playerPed, vehicle, false) then
                        SetEntityCoordsNoOffset(vehicle, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false)
                        SetEntityHeading(vehicle, playerHeading)
                        SetVehicleOnGroundProperly(vehicle)
                        SetVehicleEngineOn(vehicle, true, true, false)
                        
                        local networkId = NetworkGetNetworkIdFromEntity(vehicle)
                        if networkId ~= 0 then
                            SetNetworkIdCanMigrate(networkId, true)
                            SetNetworkIdExistsOnAllMachines(networkId, true)
                        end
                        
                    end
                else
                end
            else
            end
        ]])
    end
end


Actions.changePlateItem = FindItem("Vehicle", "Performance", "Change Plate")
if Actions.changePlateItem then
    Actions.changePlateItem.onClick = function()
        Menu.ActionChangePlate()
    end
end

Actions.cleanVehicleItem = FindItem("Vehicle", "Performance", "Clean Vehicle")
if Actions.cleanVehicleItem then
    Actions.cleanVehicleItem.onClick = function()
        Menu.ActionCleanVehicle()
    end
end

Actions.flipVehicleItem = FindItem("Vehicle", "Performance", "Flip Vehicle")
if Actions.flipVehicleItem then
    Actions.flipVehicleItem.onClick = function()
        Menu.ActionFlipVehicle()
    end
end

Actions.deleteVehicleItem = FindItem("Vehicle", "Performance", "Delete Vehicle")
if Actions.deleteVehicleItem then
    Actions.deleteVehicleItem.onClick = function()
        Menu.ActionDeleteVehicle()
    end
end

Actions.unlockAllVehicleItem = FindItem("Vehicle", "Performance", "Unlock All Vehicle")
if Actions.unlockAllVehicleItem then
    Actions.unlockAllVehicleItem.onClick = function(value)
        Menu.unlockAllVehicleEnabled = value
    end
end

Actions.teleportIntoItem = FindItem("Vehicle", "Performance", "Teleport into Closest Vehicle")
if Actions.teleportIntoItem then
    Actions.teleportIntoItem.onClick = function()
        Menu.ActionTeleportIntoClosestVehicle()
    end
end

Actions.giveNearestItem = FindItem("Vehicle", "Performance", "Give Nearest Vehicle")
if Actions.giveNearestItem then
    Actions.giveNearestItem.onClick = function()
        Menu.ActionGiveNearestVehicle()
    end
end


Actions.giveRampWallItem = FindItem("Vehicle", "Performance", "Give")
if Actions.giveRampWallItem and Actions.giveRampWallItem.type == "selector" then
    Actions.giveRampWallItem.onClick = function(index, option)
        if index == 1 then
            RampVehicle()
        elseif index == 2 then
            WallVehicle()
        elseif index == 3 then
            Wall2Vehicle()
        end
    end
end

Actions.rainbowPaintItem = FindItem("Vehicle", "Performance", "Rainbow Paint")
if Actions.rainbowPaintItem then
    Actions.rainbowPaintItem.onClick = function(value)
        ToggleRainbowPaint(value)
    end
end


Actions.noCollisionItem = FindItem("Vehicle", "Performance", "No Collision")
if Actions.noCollisionItem then
    Actions.noCollisionItem.onClick = function(value)
        ToggleNoCollision(value)
    end
end

Actions.bunnyHopItem = FindItem("Vehicle", "Performance", "Bunny Hop")
if Actions.bunnyHopItem then
    Actions.bunnyHopItem.onClick = function(value)
        ToggleBunnyHop(value)
    end
end

Actions.backFlipItem = FindItem("Vehicle", "Performance", "Back Flip")
if Actions.backFlipItem then
    Actions.backFlipItem.onClick = function(value)
        ToggleBackFlip(value)
    end
end

Actions.shiftBoostItem = FindItem("Vehicle", "Performance", "Shift Boost")
if Actions.shiftBoostItem then
    Actions.shiftBoostItem.onClick = function(value)
        ToggleShiftBoost(value)
    end
end

local function ToggleGravitateVehicle(enable, speed)
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        return
    end
    
    if enable then
        speed = speed or 100
        local injectionCode = [[
            if PqLmYgZxWvTrHs == nil then PqLmYgZxWvTrHs = false end
            PqLmYgZxWvTrHs = true
            
            VehicleSpeed = 0.0
            VehicleMaxSpeed = ]] .. tostring(speed) .. [[.0
            VehicleMinSpeed = 1.0
            VehicleSpeedMultiplier = 1.0
            VehicleBaseSpeed = ]] .. tostring(speed) .. [[.0
            VehicleAcceleration = ]] .. tostring(math.max(1.0, speed / 100.0)) .. [[
            VehicleFollowCamera = true
            VerticalFlyingEnabled = true
            
            local player = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(player, false)
            if vehicle and vehicle ~= 0 then
                SetVehicleGravityAmount(vehicle, 9.8)
                if IsEntityPositionFrozen(vehicle) then
                    FreezeEntityPosition(vehicle, false)
                end
                SetVehicleFixed(vehicle)
            end
            
            local function NormalizeVector(x, y, z)
                local length = math.sqrt(x*x + y*y + z*z)
                if length > 0 then
                    return x/length, y/length, z/length
                else
                    return 0.0, 0.0, 0.0
                end
            end

            local function DegToRad(deg)
                return deg * math.pi / 180.0
            end

            local function VkEyTrXpZdQl()
                SetTextEntry = function() end
                AddTextComponentString = function() end
                DrawNotification = function() return false end
                BeginTextCommandDisplayText = function() end
                EndTextCommandDisplayText = function() end
                AddTextComponentSubstringPlayerName = function() end
                
                CreateThread(function()
                    local lastKeyPress = 0
                    local helpShown = false
                    local activeControls = false
                    local lastVehicle = nil
                    
                    while PqLmYgZxWvTrHs do
                        local PlayerPedIdFunc = PlayerPedId
                        local GetVehiclePedIsInFunc = GetVehiclePedIsIn
                        local SetVehicleGravityAmountFunc = SetVehicleGravityAmount
                        local SetEntityRotationFunc = SetEntityRotation
                        local GetEntityRotationFunc = GetEntityRotation
                        local FreezeEntityPositionFunc = FreezeEntityPosition
                        local GetGameCamRotFunc = GetGameplayCamRot
                        local SetEntityVelocityFunc = SetEntityVelocity

                        local player = PlayerPedIdFunc()
                        local vehicle = GetVehiclePedIsInFunc(player, false)
                        
                        if vehicle ~= lastVehicle then
                            if lastVehicle and lastVehicle ~= 0 then
                                SetVehicleGravityAmountFunc(lastVehicle, 9.8)
                                SetVehicleFixed(lastVehicle)
                                NetworkRequestControlOfEntity(lastVehicle)
                                if IsEntityPositionFrozen(lastVehicle) then
                                    FreezeEntityPosition(lastVehicle, false)
                                end
                                ModifyVehicleTopSpeed(lastVehicle, 1.0)
                                SetVehicleHandlingFloat(lastVehicle, "CHandlingData", "fMass", 1500.0)
                                SetVehicleHandlingFloat(lastVehicle, "CHandlingData", "fInitialDragCoeff", 10.0)
                                SetVehicleHandlingFloat(lastVehicle, "CHandlingData", "fDriveBiasFront", 0.5)
                                SetVehicleOnGroundProperly(lastVehicle)
                                SetEntityVelocity(lastVehicle, 0.0, 0.0, 0.0)
                            end
                            
                            if vehicle and vehicle ~= 0 then
                                SetVehicleGravityAmountFunc(vehicle, 9.8)
                                SetVehicleFixed(vehicle)
                                NetworkRequestControlOfEntity(vehicle)
                                if not activeControls then
                                    ModifyVehicleTopSpeed(vehicle, 1.0)
                                    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fMass", 1500.0)
                                    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDragCoeff", 10.0)
                                    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveBiasFront", 0.5)
                                end
                            end
                            
                            lastVehicle = vehicle
                        end
                        
                        if vehicle and vehicle ~= 0 then
                            local shiftPressed = IsControlPressed(0, 21)
                            if shiftPressed and not activeControls then
                                activeControls = true
                            elseif not shiftPressed and activeControls then
                                activeControls = false
                                SetVehicleGravityAmountFunc(vehicle, 9.8)
                                SetEntityVelocityFunc(vehicle, 0.0, 0.0, 0.0)
                                SetVehicleFixed(vehicle)
                                SetVehicleEngineOn(vehicle, true, true, false)
                                ModifyVehicleTopSpeed(vehicle, 1.0)
                                SetVehicleHandlingFloat(vehicle, "CHandlingData", "fMass", 1500.0)
                                SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDragCoeff", 10.0)
                                SetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveBiasFront", 0.5)
                                if not IsVehicleOnAllWheels(vehicle) and GetEntitySpeed(vehicle) < 0.5 then
                                    SetVehicleOnGroundProperly(vehicle)
                                end
                                lastKeyPress = GetGameTimer()
                            end
                            
                            if IsControlJustPressed(0, 15) then
                                VehicleSpeedMultiplier = math.min(VehicleSpeedMultiplier + 0.5, 10.0)
                                lastKeyPress = GetGameTimer()
                            end
                            
                            if IsControlJustPressed(0, 14) then
                                VehicleSpeedMultiplier = math.max(VehicleSpeedMultiplier - 0.5, 0.1)
                                lastKeyPress = GetGameTimer()
                            end
                            
                            for i = 1, 9 do
                                if IsControlJustPressed(0, 48 + i) then
                                    VehicleMaxSpeed = (VehicleBaseSpeed / 10.0) * i * VehicleSpeedMultiplier
                                    lastKeyPress = GetGameTimer()
                                end
                            end
                            
                            if IsControlJustPressed(0, 48) then
                                VehicleMaxSpeed = 0.0
                                VehicleSpeed = 0.0
                                lastKeyPress = GetGameTimer()
                            end
                            
                            if IsControlJustPressed(0, 19) then
                                SetVehicleGravityAmountFunc(vehicle, 9.8)
                                SetVehicleFixed(vehicle)
                                SetEntityVelocityFunc(vehicle, 0.0, 0.0, 0.0)
                                SetVehicleOnGroundProperly(vehicle)
                                SetEntityRotationFunc(vehicle, 0.0, 0.0, GetEntityHeading(vehicle), 2, true)
                                ModifyVehicleTopSpeed(vehicle, 1.0)
                                SetVehicleHandlingFloat(vehicle, "CHandlingData", "fMass", 1500.0)
                                SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDragCoeff", 10.0)
                                SetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveBiasFront", 0.5)
                                SetVehicleEngineHealth(vehicle, 1000.0)
                                SetVehicleEngineOn(vehicle, true, true, false)
                                SetVehicleUndriveable(vehicle, false)
                                activeControls = false
                                VehicleSpeed = 0.0
                                lastKeyPress = GetGameTimer()
                            end
                            
                            if not helpShown then
                                lastKeyPress = GetGameTimer()
                                helpShown = true
                            end
                            
                            local camRotation = GetGameCamRotFunc(0)
                            local camPitch = DegToRad(camRotation.x)
                            local camYaw = DegToRad(camRotation.z)
                            
                            local lookDirection = {
                                x = -math.sin(camYaw) * math.cos(camPitch),
                                y = math.cos(camYaw) * math.cos(camPitch),
                                z = math.sin(camPitch)
                            }
                            
                            if activeControls then
                                if IsControlPressed(0, 32) then
                                    VehicleSpeed = math.min(VehicleSpeed + VehicleAcceleration, VehicleMaxSpeed)
                                elseif IsControlPressed(0, 33) then
                                    VehicleSpeed = math.max(VehicleSpeed - VehicleAcceleration * 2, -VehicleMaxSpeed / 2)
                                else
                                    if VehicleSpeed > 0 then
                                        VehicleSpeed = math.max(0, VehicleSpeed - VehicleAcceleration * 0.5)
                                    elseif VehicleSpeed < 0 then
                                        VehicleSpeed = math.min(0, VehicleSpeed + VehicleAcceleration * 0.5)
                                    end
                                end
                            else
                                if IsControlPressed(0, 32) then
                                    VehicleSpeed = math.min(VehicleSpeed + VehicleAcceleration * 0.5, VehicleMaxSpeed / 2)
                                elseif IsControlPressed(0, 33) then
                                    VehicleSpeed = math.max(VehicleSpeed - VehicleAcceleration, -VehicleMaxSpeed / 4)
                                else
                                    if VehicleSpeed > 0 then
                                        VehicleSpeed = math.max(0, VehicleSpeed - VehicleAcceleration * 0.75)
                                    elseif VehicleSpeed < 0 then
                                        VehicleSpeed = math.min(0, VehicleSpeed + VehicleAcceleration * 0.75)
                                    end
                                end
                                SetVehicleGravityAmountFunc(vehicle, 9.8)
                                SetVehicleHandlingFloat(vehicle, "CHandlingData", "fMass", 1500.0)
                                SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDragCoeff", 10.0)
                            end
                            
                            local directionX, directionY, directionZ
                            
                            if VehicleFollowCamera then
                                directionX = lookDirection.x
                                directionY = lookDirection.y
                                directionZ = lookDirection.z
                                
                                if activeControls then
                                    local camRot = GetGameCamRotFunc(0)
                                    local targetHeading = camRot.z
                                    SetEntityHeading(vehicle, targetHeading)
                                end
                            else
                                local camRotation = GetGameCamRotFunc(0)
                                local camYaw = DegToRad(camRotation.z)
                                directionX = -math.sin(camYaw)
                                directionY = math.cos(camYaw)
                                directionZ = 0.0
                            end
                            
                            if activeControls then
                                if IsControlPressed(0, 44) then
                                    directionZ = directionZ + 0.5
                                end
                            end
                            
                            if IsControlJustPressed(0, 45) then
                                local coords = GetEntityCoords(player)
                                SetEntityCoords(vehicle, coords.x, coords.y, coords.z + 1.0, false, false, false, false)
                                SetEntityRotationFunc(vehicle, 0.0, 0.0, 0.0, 2, true)
                                SetEntityVelocityFunc(vehicle, 0.0, 0.0, 0.0)
                                VehicleSpeed = 0.0
                                lastKeyPress = GetGameTimer()
                            end
                            
                            if IsControlJustPressed(0, 23) then
                                if IsPedInAnyVehicle(player, false) then
                                    SetVehicleGravityAmountFunc(vehicle, 9.8)
                                    TaskLeaveVehicle(player, vehicle, 16)
                                else
                                    if not activeControls then
                                        SetVehicleGravityAmountFunc(vehicle, 9.8)
                                        SetVehicleFixed(vehicle)
                                    end
                                    TaskWarpPedIntoVehicle(player, vehicle, -1)
                                end
                                lastKeyPress = GetGameTimer()
                            end
                            
                            if IsControlJustPressed(0, 29) then
                                VerticalFlyingEnabled = not VerticalFlyingEnabled
                                if VerticalFlyingEnabled then
                                    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                                else
                                    PlaySoundFrontend(-1, "BACK", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                                end
                                lastKeyPress = GetGameTimer()
                            end
                            
                            if IsEntityPositionFrozen(vehicle) then
                                FreezeEntityPositionFunc(vehicle, false)
                            end
                            
                            if activeControls then
                                SetVehicleGravityAmountFunc(vehicle, 0.0)
                                
                                local camRot = GetGameplayCamRot(0)
                                local camYaw = camRot.z
                                
                                local currentRot = GetEntityRotationFunc(vehicle, 2)
                                local angleDiff = ((camYaw - currentRot.z + 180) % 360) - 180
                                local newHeading = currentRot.z + (angleDiff * 0.1)
                                SetEntityRotationFunc(vehicle, 0.0, 0.0, newHeading, 2, true)
                                
                                if VehicleSpeed ~= 0 then
                                    local camRadians = math.rad(camYaw)
                                    local dirX = -math.sin(camRadians)
                                    local dirY = math.cos(camRadians)
                                    local dirZ = 0.0
                                    
                                    if VerticalFlyingEnabled then
                                        dirZ = lookDirection.z * 1.5
                                    end
                                    
                                    if IsControlPressed(0, 44) then
                                        dirZ = 1.0
                                    end
                                    
                                    local dx, dy, dz = NormalizeVector(dirX, dirY, dirZ)
                                    
                                    if VerticalFlyingEnabled then
                                        dz = dz * 1.5
                                        local magnitude = math.sqrt(dx*dx + dy*dy + dz*dz)
                                        if magnitude > 0 then
                                            dx = dx / magnitude
                                            dy = dy / magnitude
                                            dz = dz / magnitude
                                        end
                                    end
                                    
                                    local speedMult = VehicleSpeedMultiplier or 1.0
                                    
                                    SetEntityVelocityFunc(vehicle, 
                                        dx * VehicleSpeed * speedMult,
                                        dy * VehicleSpeed * speedMult,
                                        dz * VehicleSpeed * speedMult
                                    )
                                end
                            else
                                SetVehicleGravityAmountFunc(vehicle, 9.8)
                                local handlingNeedsReset = false
                                
                                local currentMass = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fMass")
                                local currentDrag = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDragCoeff")
                                
                                if currentMass < 100.0 or currentMass > 3000.0 or 
                                   currentDrag < 1.0 or currentDrag > 20.0 then
                                    handlingNeedsReset = true
                                end
                                
                                if handlingNeedsReset then
                                    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fMass", 1500.0)
                                    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDragCoeff", 10.0)
                                    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveBiasFront", 0.5)
                                    ModifyVehicleTopSpeed(vehicle, 1.0)
                                end
                            end
                        end
                        Wait(0)
                    end
                end)
            end

            VkEyTrXpZdQl()
        ]]
        
        Susano.InjectResource("any", injectionCode)
    else
        local injectionCode = [[
            PqLmYgZxWvTrHs = false
            
            local player = PlayerPedId()
            local playerPos = GetEntityCoords(player)
            
            local vehicle = GetVehiclePedIsIn(player, false)
            if vehicle and vehicle ~= 0 then
                SetVehicleGravityAmount(vehicle, 9.8)
                if IsEntityPositionFrozen(vehicle) then
                    FreezeEntityPosition(vehicle, false)
                end
                SetVehicleFixed(vehicle)
                SetVehicleEngineOn(vehicle, true, true, false)
                local speed = GetEntitySpeed(vehicle)
                if speed < 0.1 then
                    SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
                end
            end
            
            local vehicles = GetGamePool('CVehicle')
            for _, veh in ipairs(vehicles) do
                if veh ~= 0 and veh ~= vehicle then
                    local vehPos = GetEntityCoords(veh)
                    local dist = #(playerPos - vehPos)
                    if dist < 100.0 then
                        SetVehicleGravityAmount(veh, 9.8)
                        if IsEntityPositionFrozen(veh) then
                            FreezeEntityPosition(veh, false)
                        end
                        SetVehicleFixed(veh)
                    end
                end
            end
        ]]
        
        Susano.InjectResource("any", injectionCode)
    end
end

Actions.gravitateVehicleItem = FindItem("Vehicle", "Performance", "Gravitate Vehicle")
Actions.gravitateSpeedItem = FindItem("Vehicle", "Performance", "Gravitate Speed")

if Actions.gravitateVehicleItem then
    Actions.gravitateVehicleItem.onClick = function(value)
        local speed = 100
        if Actions.gravitateSpeedItem and Actions.gravitateSpeedItem.value then
            speed = Actions.gravitateSpeedItem.value
        end
        ToggleGravitateVehicle(value, speed)
    end
end

if Actions.gravitateSpeedItem then
    Actions.gravitateSpeedItem.onClick = function(value)
        if Actions.gravitateVehicleItem and Actions.gravitateVehicleItem.value then
            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                Susano.InjectResource("any", [[
                    if PqLmYgZxWvTrHs then
                        VehicleMaxSpeed = ]] .. tostring(value) .. [[.0
                        VehicleBaseSpeed = ]] .. tostring(value) .. [[.0
                        VehicleAcceleration = ]] .. tostring(math.max(1.0, value / 100.0)) .. [[
                    end
                ]])
            end
        end
    end
end



-- [REMOVED] Actions.godmodeItem handler (menu item deleted)
-- [REMOVED] Actions.semiGodmodeItem handler (menu item deleted)
-- [REMOVED] Actions.antiHeadshotItem handler (menu item deleted)


-- [REMOVED] Noclip + NoclipType handlers (Movement tab deleted)

Actions.tpAllVehiclesItem = FindItem("Player", "Self", "TP all vehicle to me")
if Actions.tpAllVehiclesItem then
    Actions.tpAllVehiclesItem.onClick = function()
        Menu.ActionTPAllVehiclesToMe()
    end
end

Actions.reviveItem = FindItem("Player", "Self", "Revive")
if Actions.reviveItem then
    Actions.reviveItem.onClick = function()
        Menu.ActionRevive()
    end
end

-- [REMOVED] Actions.maxHealthItem + maxArmorItem handlers (menu items deleted)
Actions.detachItem = FindItem("Player", "Self", "Detach All Entitys")
if Actions.detachItem then
    Actions.detachItem.onClick = function()
        Menu.ActionDetachAllEntitys()
    end
end

Actions.soloSessionItem = FindItem("Player", "Self", "Solo Session")
if Actions.soloSessionItem then
    Actions.soloSessionItem.onClick = function(value)
        ToggleSoloSession(value)
    end
end

Actions.throwVehicleItem = FindItem("Player", "Self", "Throw Vehicle")
if Actions.throwVehicleItem then
    Actions.throwVehicleItem.onClick = function(value)
        ToggleThrowVehicle(value)
    end
end



-- [REMOVED] Actions.fastRunItem handler (menu item deleted)
-- [REMOVED] Actions.noRagdollItem handler (menu item deleted)


Actions.tinyPlayerItem = FindItem("Player", "Self", "Tiny Player")
if Actions.tinyPlayerItem then
    Actions.tinyPlayerItem.onClick = function(value)
        ToggleTinyPlayer(value)
    end
end

-- [REMOVED] Actions.infiniteStaminaItem handler (menu item deleted)


Actions.deleteAllPropsItem = FindItem("Visual", "World", "Delete All Props")
if Actions.deleteAllPropsItem then
    Actions.deleteAllPropsItem.onClick = function()
        DeleteAllProps()
    end
end

Actions.randomOutfitItem = FindItem("Player", "Wardrobe", "Random Outfit")
if Actions.randomOutfitItem then
    Actions.randomOutfitItem.onClick = function()
        Menu.ActionRandomOutfit()
    end
end

-- Simple JSON encoder function (local copy for outfit saving)
local function SimpleJsonEncodeOutfit(tbl, indent)
    indent = indent or 0
    local result = {}
    local isArray = true
    local maxIndex = 0
    
    for k, v in pairs(tbl) do
        if type(k) ~= "number" then
            isArray = false
            break
        end
        if k > maxIndex then maxIndex = k end
    end
    
    if maxIndex ~= #tbl then isArray = false end
    
    for k, v in pairs(tbl) do
        local key
        if isArray then
            key = ""
        else
            key = type(k) == "string" and '"' .. string.gsub(k, '"', '\\"') .. '"' or tostring(k)
        end
        
        local value
        if type(v) == "table" then
            value = SimpleJsonEncodeOutfit(v, indent + 1)
        elseif type(v) == "string" then
            value = '"' .. string.gsub(v, '"', '\\"') .. '"'
        elseif type(v) == "boolean" then
            value = v and "true" or "false"
        elseif type(v) == "number" then
            value = tostring(v)
        else
            value = '"' .. tostring(v) .. '"'
        end
        
        if isArray then
            table.insert(result, value)
        else
            table.insert(result, key .. ":" .. value)
        end
    end
    
    if isArray then
        return "[" .. table.concat(result, ",") .. "]"
    else
        return "{" .. table.concat(result, ",") .. "}"
    end
end

local function CollectCurrentOutfit()
    local ped = PlayerPedId()
    if not ped or not DoesEntityExist(ped) then
        return nil
    end
    
    local outfit = {}
    
    -- Get head blend data
    local shapeFirst, shapeSecond, shapeThird, skinFirst, skinSecond, skinThird, shapeMix, skinMix, thirdMix = GetPedHeadBlendData(ped)
    outfit.sex = shapeFirst or 0
    outfit.face = shapeFirst or 0
    outfit.skin = skinFirst or 0
    
    -- Get hair
    outfit.hair_1 = GetPedDrawableVariation(ped, 2) or 0
    outfit.hair_2 = GetPedTextureVariation(ped, 2) or 0
    local hairColor, highlightColor = GetPedHairColor(ped)
    outfit.hair_color_1 = hairColor or 0
    outfit.hair_color_2 = highlightColor or 0
    
    -- Get components (0-11)
    outfit.decals_1 = GetPedDrawableVariation(ped, 10) or 0
    outfit.decals_2 = GetPedTextureVariation(ped, 10) or 0
    outfit.tshirt_1 = GetPedDrawableVariation(ped, 8) or 0
    outfit.tshirt_2 = GetPedTextureVariation(ped, 8) or 0
    outfit.torso_1 = GetPedDrawableVariation(ped, 11) or 0
    outfit.torso_2 = GetPedTextureVariation(ped, 11) or 0
    outfit.arms = GetPedDrawableVariation(ped, 3) or 0
    outfit.pants_1 = GetPedDrawableVariation(ped, 4) or 0
    outfit.pants_2 = GetPedTextureVariation(ped, 4) or 0
    outfit.shoes_1 = GetPedDrawableVariation(ped, 6) or 0
    outfit.shoes_2 = GetPedTextureVariation(ped, 6) or 0
    outfit.mask_1 = GetPedDrawableVariation(ped, 1) or 0
    outfit.mask_2 = GetPedTextureVariation(ped, 1) or 0
    outfit.bproof_1 = GetPedDrawableVariation(ped, 9) or 0
    outfit.bproof_2 = GetPedTextureVariation(ped, 9) or 0
    outfit.bags_1 = GetPedDrawableVariation(ped, 5) or 0
    outfit.bags_2 = GetPedTextureVariation(ped, 5) or 0
    
    -- Get props (0-7)
    local helmetProp = GetPedPropIndex(ped, 0)
    outfit.helmet_1 = (helmetProp ~= -1) and helmetProp or 0
    outfit.helmet_2 = (helmetProp ~= -1) and GetPedPropTextureIndex(ped, 0) or 0
    
    local glassesProp = GetPedPropIndex(ped, 1)
    outfit.glasses_1 = (glassesProp ~= -1) and glassesProp or 0
    outfit.glasses_2 = (glassesProp ~= -1) and GetPedPropTextureIndex(ped, 1) or 0
    
    -- Get beard/overlay (set default values as this native may not be available)
    outfit.beard_1 = 0
    outfit.beard_2 = 0
    outfit.beard_3 = 0
    outfit.beard_4 = 0
    
    -- Get chain/accessory
    outfit.chain_1 = GetPedDrawableVariation(ped, 7) or 0
    outfit.chain_2 = GetPedTextureVariation(ped, 7) or 0
    
    return outfit
end

Actions.saveOutfitItem = FindItem("Player", "Wardrobe", "Save Outfit")
if Actions.saveOutfitItem then
    Actions.saveOutfitItem.onClick = function()
        if Menu and Menu.OpenInput then
            Menu.OpenInput("Save Outfit", "Enter a code for your outfit:", function(code)
                if not code or code == "" then return end
                
                code = string.lower(string.gsub(code, "%s+", ""))
                
                local outfit = CollectCurrentOutfit()
                
                if not outfit then
                    if Menu and Menu.OpenInput then
                        Menu.OpenInput("Error", "Failed to collect outfit data", function() end)
                    end
                    return
                end
                
                CreateThread(function()
                    local jsonData = SimpleJsonEncodeOutfit({ code = code, outfit = outfit })
                    local baseUrl = "http://82.22.7.19:25010"
                    
                    if type(Susano) == "table" and type(Susano.HttpGet) == "function" then
                        local encodedData = ""
                        for i = 1, #jsonData do
                            local byte = string.byte(jsonData, i)
                            if (byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122) or byte == 45 or byte == 95 or byte == 46 or byte == 126 then
                                encodedData = encodedData .. string.char(byte)
                            else
                                encodedData = encodedData .. string.format("%%%02X", byte)
                            end
                        end
                        
                        local getUrl = baseUrl .. "/outfit/save?data=" .. encodedData
                        local status, response = Susano.HttpGet(getUrl)
                        
                        if status == 200 then
                            if Menu and Menu.OpenInput then
                                Menu.OpenInput("Success", "Outfit saved successfully!", function() end)
                            end
                        else
                            if Menu and Menu.OpenInput then
                                Menu.OpenInput("Error", "Failed to save outfit. Status: " .. tostring(status), function() end)
                            end
                        end
                    else
                        if Menu and Menu.OpenInput then
                            Menu.OpenInput("Error", "HTTP functions not available", function() end)
                        end
                    end
                end)
            end)
        end
    end
end

local function ApplyOutfit(outfit)
    if not outfit then return false end
    
    local ped = PlayerPedId()
    if not ped or not DoesEntityExist(ped) then
        return false
    end
    
    -- Apply outfit using skinchanger event if available
    if TriggerEvent then
        TriggerEvent('skinchanger:loadSkin', outfit)
    end
    
    -- Also apply directly using natives as fallback
    CreateThread(function()
        Wait(100)
        
        -- Set head blend data
        if outfit.face and outfit.skin then
            SetPedHeadBlendData(ped, outfit.face or 0, outfit.face or 0, 0, outfit.skin or 0, outfit.skin or 0, 0, 1.0, 1.0, 0.0, false)
        end
        
        -- Set hair
        if outfit.hair_1 then
            SetPedComponentVariation(ped, 2, outfit.hair_1, outfit.hair_2 or 0, 0)
        end
        if outfit.hair_color_1 then
            SetPedHairColor(ped, outfit.hair_color_1 or 0, outfit.hair_color_2 or 0)
        end
        
        -- Set components
        if outfit.decals_1 then SetPedComponentVariation(ped, 10, outfit.decals_1, outfit.decals_2 or 0, 0) end
        if outfit.tshirt_1 then SetPedComponentVariation(ped, 8, outfit.tshirt_1, outfit.tshirt_2 or 0, 0) end
        if outfit.torso_1 then SetPedComponentVariation(ped, 11, outfit.torso_1, outfit.torso_2 or 0, 0) end
        if outfit.arms then SetPedComponentVariation(ped, 3, outfit.arms, 0, 0) end
        if outfit.pants_1 then SetPedComponentVariation(ped, 4, outfit.pants_1, outfit.pants_2 or 0, 0) end
        if outfit.shoes_1 then SetPedComponentVariation(ped, 6, outfit.shoes_1, outfit.shoes_2 or 0, 0) end
        if outfit.mask_1 then SetPedComponentVariation(ped, 1, outfit.mask_1, outfit.mask_2 or 0, 0) end
        if outfit.bproof_1 then SetPedComponentVariation(ped, 9, outfit.bproof_1, outfit.bproof_2 or 0, 0) end
        if outfit.bags_1 then SetPedComponentVariation(ped, 5, outfit.bags_1, outfit.bags_2 or 0, 0) end
        if outfit.chain_1 then SetPedComponentVariation(ped, 7, outfit.chain_1, outfit.chain_2 or 0, 0) end
        
        -- Set props
        if outfit.helmet_1 and outfit.helmet_1 > 0 then
            SetPedPropIndex(ped, 0, outfit.helmet_1, outfit.helmet_2 or 0, true)
        else
            ClearPedProp(ped, 0)
        end
        
        if outfit.glasses_1 and outfit.glasses_1 > 0 then
            SetPedPropIndex(ped, 1, outfit.glasses_1, outfit.glasses_2 or 0, true)
        else
            ClearPedProp(ped, 1)
        end
    end)
    
    return true
end

Actions.loadOutfitItem = FindItem("Player", "Wardrobe", "Load Outfit")
if Actions.loadOutfitItem then
    Actions.loadOutfitItem.onClick = function()
        if Menu and Menu.OpenInput then
            Menu.OpenInput("Load Outfit", "Enter outfit code:", function(code)
                if not code or code == "" then return end
                
                code = string.lower(string.gsub(code, "%s+", ""))
                
                if type(Susano) == "table" and type(Susano.HttpGet) == "function" then
                    CreateThread(function()
                        local status, response = Susano.HttpGet("http://82.22.7.19:25010/outfit/load?code=" .. code)
                        
                        if status == 200 and response then
                            if type(response) ~= "string" then
                                response = tostring(response)
                            end
                            
                            local success, data, parseErr = pcall(function()
                                if json and type(json.decode) == "function" then
                                    return json.decode(response)
                                elseif loadstring then
                                    local func = loadstring("return " .. response)
                                    if func then
                                        return func()
                                    end
                                end
                                return nil
                            end)
                            
                            if not success then
                                parseErr = data
                                data = nil
                            end
                            
                            if success and data then
                                local outfitToApply = data.outfit or data
                                if outfitToApply and type(outfitToApply) == "table" then
                                    Wait(100)
                                    
                                    local applySuccess = ApplyOutfit(outfitToApply)
                                    
                                    if not applySuccess then
                                        if Menu and Menu.OpenInput then
                                            Menu.OpenInput("Error", "Failed to apply outfit", function() end)
                                        end
                                    end
                                else
                                    if Menu and Menu.OpenInput then
                                        Menu.OpenInput("Error", "Invalid outfit format", function() end)
                                    end
                                end
                            else
                                if Menu and Menu.OpenInput then
                                    Menu.OpenInput("Error", "Failed to parse outfit: " .. tostring(parseErr or "Unknown error"), function() end)
                                end
                            end
                        elseif status == 404 then
                            if Menu and Menu.OpenInput then
                                Menu.OpenInput("Error", "Outfit not found!", function() end)
                            end
                        else
                            if Menu and Menu.OpenInput then
                                Menu.OpenInput("Error", "Failed to load outfit. Status: " .. tostring(status), function() end)
                            end
                        end
                    end)
                else
                    if Menu and Menu.OpenInput then
                        Menu.OpenInput("Error", "HTTP functions not available", function() end)
                    end
                end
            end)
        end
    end
end

function Menu.ActionHitlerOutfit()
    TriggerEvent('skinchanger:loadSkin', {
        sex          = 0,
        face         = 13,
        skin         = 1,
        hair_1       = 18,
        hair_2       = 0,
        hair_color_1 = 0,
        hair_color_2 = 0,
        decals_1     = 0,
        decals_2     = 0,
        tshirt_1     = 10,
        tshirt_2     = 0,
        torso_1      = 72,
        torso_2      = 1,
        arms         = 33,
        pants_1      = 24,
        pants_2      = 1,
        shoes_1      = 38,
        shoes_2      = 0,
        mask_1       = 0,
        mask_2       = 0,
        helmet_1     = 113,
        helmet_2     = 0,
        bproof_1     = 0,
        bproof_2     = 0,
        bags_1       = 0,
        bags_2       = 0,
        beard_1      = 9,
        beard_2      = 10,
        beard_3      = 0,
        beard_4      = 0,
        chain_1      = 38,
        chain_2      = 0,
        glasses_1    = 0,
        glasses_2    = 0,
    })
end

function Menu.ActionStaffOutfit()
    TriggerEvent('skinchanger:loadSkin', {
        sex          = 0,
        face         = 1,
        skin         = 1,
        hair_1       = 1,
        hair_2       = 0,
        hair_color_1 = 0,
        hair_color_2 = 0,
        decals_1     = 0,
        decals_2     = 0,
        tshirt_1     = 15,
        tshirt_2     = 0,
        torso_1      = 178,
        torso_2      = 0,
        arms         = 1,
        pants_1      = 77,
        pants_2      = 0,
        shoes_1      = 55,
        shoes_2      = 0,
        mask_1       = 0,
        mask_2       = 0,
        helmet_1       = 151,
        helmet_2       = 0,
        bproof_1     = 0,
        bproof_2     = 0,
        bags_1         = 0,
        bags_2         = 0,
        beard_1      = 9,
        beard_2      = 10,
        beard_3      = 0,
        beard_4      = 0,
        chain_1      = 3,
        chain_2      = 0,
        glasses_1    = 0,
        glasses_2    = 0,
    })
end

function Menu.ActionBnzOutfit()
    TriggerEvent('skinchanger:loadSkin', {
        sex          = 0,
        face         = 43,
        skin         = 1,
        hair_1       = 0,
        hair_2       = 0,
        hair_color_1 = 0,
        hair_color_2 = 0,
        decals_1     = 0,
        decals_2     = 0,
        tshirt_1     = 200,
        tshirt_2     = 0,
        torso_1      = 496,
        torso_2      = 0,
        arms         = 17,
        pants_1      = 457,
        pants_2      = 0,
        shoes_1      = 275,
        shoes_2      = 0,
        mask_1       = 214,
        mask_2       = 1,
        helmet_1     = -1,
        helmet_2     = -1,
        bproof_1     = 163,
        bproof_2     = 0,
        bags_1       = 133,
        bags_2       = 0,
        beard_1      = 0,
        beard_2      = 10,
        beard_3      = 0,
        beard_4      = 0,
        chain_1      = 330,
        chain_2      = 0,
        glasses_1    = 0,
        glasses_2    = 0,
    })
end

function Menu.ActionJyOutfit()
    local Config = {
        Outfit = {
            sex          = 0,
            face         = 42,
            skin         = 1,
            hair_1       = 0,
            hair_2       = 0,
            hair_color_1 = 0,
            hair_color_2 = 0,
            decals_1     = 0,
            decals_2     = 0,
            tshirt_1     = 15,
            tshirt_2     = 0,
            torso_1      = 924,
            torso_2      = 0,
            arms         = 78,
            pants_1      = 16,
            pants_2      = 3,
            shoes_1      = 208,
            shoes_2      = 5,
            mask_1       = 256,
            mask_2       = 0,
            helmet_1     = 244,
            helmet_2     = 0,
            bproof_1     = 0,
            bproof_2     = 0,
            bags_1       = 152,
            bags_2       = 0,
            beard_1      = 0,
            beard_2      = 10,
            beard_3      = 0,
            beard_4      = 0,
            chain_1      = 180,
            chain_2      = 0,
            glasses_1    = 71,
            glasses_2    = 0
        }
    }
    
    TriggerEvent('skinchanger:loadSkin', Config.Outfit)
    
    CreateThread(function()
        while true do
            Wait(3000)
            
            local ped = PlayerPedId()
            
            if GetPlayerPedPropIndex(ped, 0) ~= Config.Outfit.helmet_1 then
                SetPedPropIndex(ped, 0, Config.Outfit.helmet_1, Config.Outfit.helmet_2, true)
            end
            
            if GetPlayerPedPropIndex(ped, 1) ~= Config.Outfit.glasses_1 then
                SetPedPropIndex(ped, 1, Config.Outfit.glasses_1, Config.Outfit.glasses_2, true)
            end
            
            if GetPedDrawableVariation(ped, 1) ~= Config.Outfit.mask_1 then
                SetPedComponentVariation(ped, 1, Config.Outfit.mask_1, Config.Outfit.mask_2, 0)
            end
        end
    end)
end

function Menu.ActionWOutfit()
    TriggerEvent('skinchanger:loadSkin', {
        sex          = 0,
        face         = 0,
        skin         = 0,
        hair_1       = 0,
        hair_2       = 0,
        hair_color_1 = 0,
        hair_color_2 = 0,
        decals_1     = 0,
        decals_2     = 0,
        tshirt_1     = 15,
        tshirt_2     = 0,
        torso_1      = 271,
        torso_2      = 3,
        arms         = 2,
        pants_1      = 258,
        pants_2      = 0,
        shoes_1      = 149,
        shoes_2      = 0,
        mask_1       = 95,
        mask_2       = 0,
        helmet_1     = -1,
        helmet_2     = -1,
        bproof_1     = 0,
        bproof_2     = 0,
        bags_1       = 0,
        bags_2       = 0,
        beard_1      = 0,
        beard_2      = 0,
        beard_3      = 0,
        beard_4      = 0,
        chain_1      = 0,
        chain_2      = 0,
        glasses_1    = 0,
        glasses_2    = 0,
    })
end

Actions.outfitItem = FindItem("Player", "Wardrobe", "Outfit")
if Actions.outfitItem then
    Actions.outfitItem.onClick = function(index, option)
        if option == "bnz outfit" then
            Menu.ActionBnzOutfit()
        elseif option == "Staff Outfit" then
            Menu.ActionStaffOutfit()
        elseif option == "Hitler Outfit" then
            Menu.ActionHitlerOutfit()
        elseif option == "jy" then
            Menu.ActionJyOutfit()
        elseif option == "w outfit" then
            Menu.ActionWOutfit()
        end
    end
end

local function _clampInt(v, mn, mx)
    v = tonumber(v) or mn
    if v < mn then return mn end
    if v > mx then return mx end
    return math.floor(v)
end

local function _applyWardrobeSelection(itemName, selectedIndex)
    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return selectedIndex
    end

    selectedIndex = tonumber(selectedIndex) or 1
    if selectedIndex < 1 then selectedIndex = 1 end

    if itemName == "Hat" or itemName == "Glasses" then
        local propId = (itemName == "Hat") and 0 or 1
        local count = GetNumberOfPedPropDrawableVariations(ped, propId) or 0
        if count <= 0 then
            ClearPedProp(ped, propId)
            return 1
        end

        local clamped = _clampInt(selectedIndex, 1, count)
        local drawable = clamped - 1
        local texCount = GetNumberOfPedPropTextureVariations(ped, propId, drawable) or 0
        local texture = (texCount > 0) and 0 or 0

        ClearPedProp(ped, propId)
        SetPedPropIndex(ped, propId, drawable, texture, true)
        return clamped
    end

    local componentId = nil
    if itemName == "Mask" then componentId = 1
    elseif itemName == "Torso" then componentId = 11
    elseif itemName == "Tshirt" then componentId = 8
    elseif itemName == "Pants" then componentId = 4
    elseif itemName == "Shoes" then componentId = 6
    end

    if componentId ~= nil then
        local count = GetNumberOfPedDrawableVariations(ped, componentId) or 0
        if count <= 0 then
            return 1
        end

        local clamped = _clampInt(selectedIndex, 1, count)
        local drawable = clamped - 1
        local texCount = GetNumberOfPedTextureVariations(ped, componentId, drawable) or 0
        local texture = (texCount > 0) and 0 or 0

        SetPedComponentVariation(ped, componentId, drawable, texture, 0)
        return clamped
    end

    return selectedIndex
end

local function _bindWardrobeSelector(itemName)
    local item = FindItem("Player", "Wardrobe", itemName)
    if not item then return end

    item.onClick = function(index, _)
        local clamped = _applyWardrobeSelection(itemName, index)
        if clamped and item.selected ~= clamped then
            item.selected = clamped
        end
    end
end

_bindWardrobeSelector("Hat")
_bindWardrobeSelector("Mask")
_bindWardrobeSelector("Glasses")
_bindWardrobeSelector("Torso")
_bindWardrobeSelector("Tshirt")
_bindWardrobeSelector("Pants")
_bindWardrobeSelector("Shoes")

Menu.freecamEnabled = false
local freecamSpeed = 0.5
local freecamFov = 50.0

local freecam_active = false
local cam_pos = vector3(0, 0, 0)
local cam_rot = vector3(0, 0, 0)
local original_pos = vector3(0, 0, 0)
local freecam_just_started = false
local last_click_time = 0
local freecam_mode = 1
local freecam_max_mode = 2

local FreecamOptions = {"Teleport", "Warp Vehicle", "Shoot Bullet", "Kick Vehicle", "Fuck Vehicle", "Steal Vehicle", "Delete Vehicle"}
local FreecamSelectedOption = 1
local FreecamScrollOffset = 0

local lastScrollTime = 0
local lastScrollValue = 0.0

local VK_W = 0x57
local VK_A = 0x41
local VK_S = 0x53
local VK_D = 0x44
local VK_Q = 0x51
local VK_E = 0x45
local VK_Z = 0x5A
local VK_SHIFT = 0x10
local VK_SPACE = 0x20
local VK_CONTROL = 0x11
local VK_LBUTTON = 0x01
local VK_RBUTTON = 0x02

local normal_speed = 0.5
local fast_speed = 2.5

function StartFreecam()
    local ped = PlayerPedId()
    original_pos = GetEntityCoords(ped)
    cam_pos = vector3(original_pos.x, original_pos.y, original_pos.z)
    
    local currentRot = GetGameplayCamRot(2)
    cam_rot = vector3(currentRot.x, currentRot.y, currentRot.z)
    
    FreezeEntityPosition(ped, true)
    ClearPedTasksImmediately(ped)
    SetEntityInvincible(ped, true)
    Susano.LockCameraPos(true)
    
    freecam_active = true
    freecam_just_started = true
    last_click_time = GetGameTimer()
    
    
    Citizen.CreateThread(function()
        Citizen.Wait(500)
        freecam_just_started = false
    end)
end

function StopFreecam()
    local ped = PlayerPedId()
    
    Susano.LockCameraPos(false)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    ClearFocus()
    
    freecam_active = false
end

function TeleportToFreecam()
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        return
    end
    
    local ped = PlayerPedId()
    local currentCamCoords = cam_pos
    local currentCamRot = cam_rot
    
    local pitch = math.rad(currentCamRot.x)
    local yaw = math.rad(currentCamRot.z)
    
    local dirX = -math.sin(yaw) * math.cos(pitch)
    local dirY = math.cos(yaw) * math.cos(pitch)
    local dirZ = math.sin(pitch)
    
    local direction = vector3(dirX, dirY, dirZ)
    
    Susano.InjectResource("any", string.format([[
        local ped = PlayerPedId()
        local camCoords = vector3(%f, %f, %f)
        local direction = vector3(%f, %f, %f)
        
        local raycastStart = camCoords
        local raycastEnd = vector3(
            camCoords.x + direction.x * 1000.0,
            camCoords.y + direction.y * 1000.0,
            camCoords.z + direction.z * 1000.0
        )
        
        local raycast = StartExpensiveSynchronousShapeTestLosProbe(
            raycastStart.x, raycastStart.y, raycastStart.z,
            raycastEnd.x, raycastEnd.y, raycastEnd.z,
            -1, ped, 7
        )
        
        local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(raycast)
        
        if hit and entityHit and DoesEntityExist(entityHit) and GetEntityType(entityHit) == 2 then
            local targetVehicle = entityHit
            local playerPed = ped
            
            SetEntityAsMissionEntity(targetVehicle, true, true)
            if NetworkGetEntityIsNetworked(targetVehicle) then
                NetworkRequestControlOfEntity(targetVehicle)
                local attempts = 0
                while not NetworkHasControlOfEntity(targetVehicle) and attempts < 100 do
                    Wait(0)
                    attempts = attempts + 1
                    NetworkRequestControlOfEntity(targetVehicle)
                end
            end
            
            SetVehicleDoorsLocked(targetVehicle, 1)
            SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)
            
            local freeSeat = -1
            local maxSeats = GetVehicleMaxNumberOfPassengers(targetVehicle)
            
            local driverSeat = GetPedInVehicleSeat(targetVehicle, -1)
            if driverSeat == 0 or not DoesEntityExist(driverSeat) then
                freeSeat = -1
            else
                for i = 0, maxSeats - 1 do
                    local seatPed = GetPedInVehicleSeat(targetVehicle, i)
                    if seatPed == 0 or not DoesEntityExist(seatPed) then
                        freeSeat = i
                        break
                    end
                end
            end
            
            if freeSeat ~= -1 then
                ClearPedTasksImmediately(playerPed)
                Wait(50)
                SetPedIntoVehicle(playerPed, targetVehicle, freeSeat)
                Wait(100)
                
                if not IsPedInVehicle(playerPed, targetVehicle, false) then
                    local vehicleCoords = GetEntityCoords(targetVehicle)
                    SetEntityCoords(playerPed, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 1.0, false, false, false, false)
                    Wait(50)
                    SetPedIntoVehicle(playerPed, targetVehicle, freeSeat)
                end
            else
                ClearPedTasksImmediately(playerPed)
                Wait(50)
                SetPedIntoVehicle(playerPed, targetVehicle, -1)
                Wait(100)
                
                if not IsPedInVehicle(playerPed, targetVehicle, false) then
                    local vehicleCoords = GetEntityCoords(targetVehicle)
                    SetEntityCoords(ped, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 1.0, false, false, false, false)
                end
            end
        elseif hit and endCoords and endCoords.x ~= 0.0 and endCoords.y ~= 0.0 and endCoords.z ~= 0.0 then
            SetEntityCoords(ped, endCoords.x, endCoords.y, endCoords.z, false, false, false, false)
        else
            local teleportPos = vector3(
                camCoords.x + direction.x * 5.0,
                camCoords.y + direction.y * 5.0,
                camCoords.z + direction.z * 5.0
            )
            SetEntityCoords(ped, teleportPos.x, teleportPos.y, teleportPos.z, false, false, false, false)
        end
    ]], currentCamCoords.x, currentCamCoords.y, currentCamCoords.z, direction.x, direction.y, direction.z))
end

function ForceWorldLoad()
    RequestCollisionAtCoord(cam_pos.x, cam_pos.y, cam_pos.z)
    SetFocusPosAndVel(cam_pos.x, cam_pos.y, cam_pos.z, 0.0, 0.0, 0.0)
    NewLoadSceneStart(cam_pos.x, cam_pos.y, cam_pos.z, cam_pos.x, cam_pos.y, cam_pos.z, 150.0, 0)
end

function DrawFreecamMenu()
    if not freecam_active then 
        Susano.BeginFrame()
        Susano.SubmitFrame()
        return 
    end
    
    Susano.BeginFrame()
    
    local screen_width, screen_height = GetActiveScreenResolution()
    
    
    local options = FreecamOptions
    local selectedIndex = FreecamSelectedOption or 1
    
    local maxVisibleOptions = 4
    
    if selectedIndex <= FreecamScrollOffset then
        FreecamScrollOffset = math.max(0, selectedIndex - 1)
    elseif selectedIndex > FreecamScrollOffset + maxVisibleOptions then
        FreecamScrollOffset = selectedIndex - maxVisibleOptions
    end
    
    local visibleOptions = {}
    local visibleIndices = {}
    local startIndex = FreecamScrollOffset + 1
    local endIndex = math.min(startIndex + maxVisibleOptions - 1, #options)
    
    for i = startIndex, endIndex do
        table.insert(visibleOptions, options[i])
        table.insert(visibleIndices, i)
    end
    
    local selectedR, selectedG, selectedB = 148.0 / 255.0, 0.0 / 255.0, 211.0 / 255.0
    local normalR, normalG, normalB = 200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0
    
    local selectedSize = 24.0
    local normalSize = 18.0
    
    local spacing = 35.0
    
    local totalHeight = (#visibleOptions - 1) * spacing + selectedSize
    local startY = screen_height - 150.0
    
    local maxTextWidth = 0
    for i = 1, #visibleOptions do
        local textWidth = string.len(visibleOptions[i]) * 10
        if textWidth > maxTextWidth then
            maxTextWidth = textWidth
        end
    end
    
    local centerX = screen_width / 2
    
    local indicatorText = string.format("%d / %d", selectedIndex, #options)
    local indicatorSize = 14.0
    local indicatorY = startY - 25.0
    local indicatorX = centerX
    
    local indicatorOutlineOffset = 1.0
    local indicatorOutlineAlpha = 0.5
    Susano.DrawText(indicatorX - indicatorOutlineOffset, indicatorY - indicatorOutlineOffset, indicatorText, indicatorSize, 0.0, 0.0, 0.0, indicatorOutlineAlpha)
    Susano.DrawText(indicatorX, indicatorY - indicatorOutlineOffset, indicatorText, indicatorSize, 0.0, 0.0, 0.0, indicatorOutlineAlpha)
    Susano.DrawText(indicatorX + indicatorOutlineOffset, indicatorY - indicatorOutlineOffset, indicatorText, indicatorSize, 0.0, 0.0, 0.0, indicatorOutlineAlpha)
    Susano.DrawText(indicatorX - indicatorOutlineOffset, indicatorY, indicatorText, indicatorSize, 0.0, 0.0, 0.0, indicatorOutlineAlpha)
    Susano.DrawText(indicatorX + indicatorOutlineOffset, indicatorY, indicatorText, indicatorSize, 0.0, 0.0, 0.0, indicatorOutlineAlpha)
    Susano.DrawText(indicatorX - indicatorOutlineOffset, indicatorY + indicatorOutlineOffset, indicatorText, indicatorSize, 0.0, 0.0, 0.0, indicatorOutlineAlpha)
    Susano.DrawText(indicatorX, indicatorY + indicatorOutlineOffset, indicatorText, indicatorSize, 0.0, 0.0, 0.0, indicatorOutlineAlpha)
    Susano.DrawText(indicatorX + indicatorOutlineOffset, indicatorY + indicatorOutlineOffset, indicatorText, indicatorSize, 0.0, 0.0, 0.0, indicatorOutlineAlpha)
    
    Susano.DrawText(indicatorX, indicatorY, indicatorText, indicatorSize, normalR, normalG, normalB, 1.0)
    
    for i = 1, #visibleOptions do
        local actualIndex = visibleIndices[i]
        local isSelected = (actualIndex == selectedIndex)
        local textSize = isSelected and selectedSize or normalSize
        local r, g, b = normalR, normalG, normalB
        
        if isSelected then
            r, g, b = selectedR, selectedG, selectedB
        end
        
        local yPos = startY + (i - 1) * spacing
        local xPos = centerX - (maxTextWidth / 2)
        
        local outlineOffset = 1.0
        local outlineAlpha = 0.5
        Susano.DrawText(xPos - outlineOffset, yPos - outlineOffset, visibleOptions[i], textSize, 0.0, 0.0, 0.0, outlineAlpha)
        Susano.DrawText(xPos, yPos - outlineOffset, visibleOptions[i], textSize, 0.0, 0.0, 0.0, outlineAlpha)
        Susano.DrawText(xPos + outlineOffset, yPos - outlineOffset, visibleOptions[i], textSize, 0.0, 0.0, 0.0, outlineAlpha)
        Susano.DrawText(xPos - outlineOffset, yPos, visibleOptions[i], textSize, 0.0, 0.0, 0.0, outlineAlpha)
        Susano.DrawText(xPos + outlineOffset, yPos, visibleOptions[i], textSize, 0.0, 0.0, 0.0, outlineAlpha)
        Susano.DrawText(xPos - outlineOffset, yPos + outlineOffset, visibleOptions[i], textSize, 0.0, 0.0, 0.0, outlineAlpha)
        Susano.DrawText(xPos, yPos + outlineOffset, visibleOptions[i], textSize, 0.0, 0.0, 0.0, outlineAlpha)
        Susano.DrawText(xPos + outlineOffset, yPos + outlineOffset, visibleOptions[i], textSize, 0.0, 0.0, 0.0, outlineAlpha)
        
        Susano.DrawText(xPos, yPos, visibleOptions[i], textSize, r, g, b, 1.0)
    end
    
    Susano.SubmitFrame()
end

function WarpVehicleToFreecam()
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        return
    end
    
    local ped = PlayerPedId()
    local currentCamCoords = cam_pos
    local currentCamRot = cam_rot
    
    local pitch = math.rad(currentCamRot.x)
    local yaw = math.rad(currentCamRot.z)
    
    local dirX = -math.sin(yaw) * math.cos(pitch)
    local dirY = math.cos(yaw) * math.cos(pitch)
    local dirZ = math.sin(pitch)
    
    local direction = vector3(dirX, dirY, dirZ)
    
    Susano.InjectResource("any", string.format([[
        local ped = PlayerPedId()
        local camCoords = vector3(%f, %f, %f)
        local direction = vector3(%f, %f, %f)
        
        local raycastStart = camCoords
        local raycastEnd = vector3(
            camCoords.x + direction.x * 1000.0,
            camCoords.y + direction.y * 1000.0,
            camCoords.z + direction.z * 1000.0
        )
        
        local raycast = StartExpensiveSynchronousShapeTestLosProbe(
            raycastStart.x, raycastStart.y, raycastStart.z,
            raycastEnd.x, raycastEnd.y, raycastEnd.z,
            -1, ped, 7
        )
        
        local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(raycast)
        
        if hit and entityHit and DoesEntityExist(entityHit) and GetEntityType(entityHit) == 2 then
            local targetVehicle = entityHit
            
            local hasPlayerInside = false
            local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(targetVehicle))
            if numSeats and numSeats > 0 then
                for seat = -1, (numSeats - 2) do
                    local seatPed = GetPedInVehicleSeat(targetVehicle, seat)
                    if seatPed and seatPed ~= 0 and DoesEntityExist(seatPed) then
                        for _, player in ipairs(GetActivePlayers()) do
                            if GetPlayerPed(player) == seatPed then
                                hasPlayerInside = true
                                break
                            end
                        end
                        if hasPlayerInside then break end
                    end
                end
            end
            
            if hasPlayerInside then
                local playerPed = ped
                
                local function RequestControl(entity, timeoutMs)
                    if not entity or not DoesEntityExist(entity) then return false end
                    local start = GetGameTimer()
                    NetworkRequestControlOfEntity(entity)
                    while not NetworkHasControlOfEntity(entity) do
                        Wait(0)
                        if GetGameTimer() - start > (timeoutMs or 750) then
                            return false
                        end
                        NetworkRequestControlOfEntity(entity)
                    end
                    return true
                end
                
                local function tryEnterSeat(seatIndex)
                    SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
                    Wait(0)
                    return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
                end
                
                local function getFirstFreeSeat(v)
                    local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
                    if not numSeats or numSeats <= 0 then return -1 end
                    for seat = 0, (numSeats - 2) do
                        if IsVehicleSeatFree(v, seat) then return seat end
                    end
                    return -1
                end
                
                if RequestControl(targetVehicle, 750) then
                    ClearPedTasksImmediately(playerPed)
                    SetVehicleDoorsLocked(targetVehicle, 1)
                    SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)
                    
                    local success = false
                    if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                        success = true
                    end
                    
                    if not success and GetPedInVehicleSeat(targetVehicle, -1) == playerPed then
                        success = true
                    end
                    
                    if not success then
                        local fallbackSeat = getFirstFreeSeat(targetVehicle)
                        if fallbackSeat ~= -1 and tryEnterSeat(fallbackSeat) then
                            local drv = GetPedInVehicleSeat(targetVehicle, -1)
                            if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
                                RequestControl(drv, 750)
                                ClearPedTasksImmediately(drv)
                                SetEntityAsMissionEntity(drv, true, true)
                                SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
                                Wait(50)
                                DeleteEntity(drv)
                                
                                for i=1,80 do
                                    local occ = GetPedInVehicleSeat(targetVehicle, -1)
                                    if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
                                    Wait(0)
                                end
                            end
                            
                            for attempt = 1, 30 do
                                if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                                    break
                                end
                                Wait(0)
                            end
                        end
                    end
                end
            end
        end
    ]], currentCamCoords.x, currentCamCoords.y, currentCamCoords.z, direction.x, direction.y, direction.z))
end

function ShootBulletFromFreecam()
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        return
    end
    
    local ped = PlayerPedId()
    local currentCamCoords = cam_pos
    local currentCamRot = cam_rot
    
    local pitch = math.rad(currentCamRot.x)
    local yaw = math.rad(currentCamRot.z)
    
    local dirX = -math.sin(yaw) * math.cos(pitch)
    local dirY = math.cos(yaw) * math.cos(pitch)
    local dirZ = math.sin(pitch)
    
    local direction = vector3(dirX, dirY, dirZ)
    
    Susano.InjectResource("any", string.format([[
        local ped = PlayerPedId()
        local camCoords = vector3(%f, %f, %f)
        local direction = vector3(%f, %f, %f)
        
        local currentWeapon = GetSelectedPedWeapon(ped)
        local hasValidWeapon = false
        
        if currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 0 then
            if HasPedGotWeapon(ped, currentWeapon, false) then
                hasValidWeapon = true
            else
                currentWeapon = GetHashKey("WEAPON_UNARMED")
            end
        end
        
        if not hasValidWeapon then
            local weapons = {
                "WEAPON_PISTOL", "WEAPON_PISTOL_MK2", "WEAPON_COMBATPISTOL", "WEAPON_APPISTOL",
                "WEAPON_PISTOL50", "WEAPON_SNSPISTOL", "WEAPON_HEAVYPISTOL", "WEAPON_VINTAGEPISTOL",
                "WEAPON_MICROSMG", "WEAPON_SMG", "WEAPON_SMG_MK2", "WEAPON_ASSAULTSMG",
                "WEAPON_ASSAULTRIFLE", "WEAPON_ASSAULTRIFLE_MK2", "WEAPON_CARBINERIFLE", "WEAPON_CARBINERIFLE_MK2",
                "WEAPON_ADVANCEDRIFLE", "WEAPON_SPECIALCARBINE", "WEAPON_BULLPUPRIFLE", "WEAPON_COMPACTRIFLE",
                "WEAPON_SNIPERRIFLE", "WEAPON_HEAVYSNIPER", "WEAPON_HEAVYSNIPER_MK2", "WEAPON_MARKSMANRIFLE",
                "WEAPON_PUMPSHOTGUN", "WEAPON_PUMPSHOTGUN_MK2", "WEAPON_SAWNOFFSHOTGUN", "WEAPON_ASSAULTSHOTGUN",
                "WEAPON_MG", "WEAPON_COMBATMG", "WEAPON_COMBATMG_MK2", "WEAPON_GUSENBERG",
                "WEAPON_RPG", "WEAPON_GRENADELAUNCHER", "WEAPON_MINIGUN", "WEAPON_RAILGUN"
            }
            for _, weaponName in ipairs(weapons) do
                local weaponHash = GetHashKey(weaponName)
                if HasPedGotWeapon(ped, weaponHash, false) then
                    currentWeapon = weaponHash
                    hasValidWeapon = true
                    break
                end
            end
        end
        
        if hasValidWeapon and currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 0 then
            local startCoords = vector3(
                camCoords.x + direction.x * 0.1,
                camCoords.y + direction.y * 0.1,
                camCoords.z + direction.z * 0.1
            )
            
            local distance = 1000.0
            local endX = camCoords.x + direction.x * distance
            local endY = camCoords.y + direction.y * distance
            local endZ = camCoords.z + direction.z * distance
            local targetCoords = vector3(endX, endY, endZ)
            
            local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, endX, endY, endZ, -1, ped, 0)
            local retval, hit, hitCoords = GetShapeTestResult(rayHandle)
            
            if hit and hitCoords then
                targetCoords = hitCoords
            end
            
            ShootSingleBulletBetweenCoords(
                startCoords.x, startCoords.y, startCoords.z,
                targetCoords.x, targetCoords.y, targetCoords.z,
                40, true, currentWeapon, ped, true, false, 1000.0
            )
        end
    ]], currentCamCoords.x, currentCamCoords.y, currentCamCoords.z, direction.x, direction.y, direction.z))
end

function UnusableVehicleFromFreecam()
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        return
    end
    
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local playerHeading = GetEntityHeading(ped)
    local currentCamCoords = cam_pos
    local currentCamRot = cam_rot
    
    local pitch = math.rad(currentCamRot.x)
    local yaw = math.rad(currentCamRot.z)
    
    local dirX = -math.sin(yaw) * math.cos(pitch)
    local dirY = math.cos(yaw) * math.cos(pitch)
    local dirZ = math.sin(pitch)
    
    local direction = vector3(dirX, dirY, dirZ)
    
    Susano.InjectResource("any", string.format([[
        local ped = PlayerPedId()
        local playerCoords = vector3(%f, %f, %f)
        local playerHeading = %f
        local camCoords = vector3(%f, %f, %f)
        local direction = vector3(%f, %f, %f)
        
        local raycastStart = camCoords
        local raycastEnd = vector3(
            camCoords.x + direction.x * 1000.0,
            camCoords.y + direction.y * 1000.0,
            camCoords.z + direction.z * 1000.0
        )
        
        local raycast = StartExpensiveSynchronousShapeTestLosProbe(
            raycastStart.x, raycastStart.y, raycastStart.z,
            raycastEnd.x, raycastEnd.y, raycastEnd.z,
            -1, ped, 7
        )
        
        local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(raycast)
        
        if hit and entityHit and DoesEntityExist(entityHit) and GetEntityType(entityHit) == 2 then
            local targetVehicle = entityHit
            local playerPed = ped
            
            local hasPlayerInside = false
            local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(targetVehicle))
            if numSeats and numSeats > 0 then
                for seat = -1, (numSeats - 2) do
                    local seatPed = GetPedInVehicleSeat(targetVehicle, seat)
                    if seatPed and seatPed ~= 0 and DoesEntityExist(seatPed) then
                        for _, player in ipairs(GetActivePlayers()) do
                            if GetPlayerPed(player) == seatPed then
                                hasPlayerInside = true
                                break
                            end
                        end
                        if hasPlayerInside then break end
                    end
                end
            end
            
            if hasPlayerInside then
                local function RequestControl(entity, timeoutMs)
                    if not entity or not DoesEntityExist(entity) then return false end
                    local start = GetGameTimer()
                    NetworkRequestControlOfEntity(entity)
                    while not NetworkHasControlOfEntity(entity) do
                        Wait(0)
                        if GetGameTimer() - start > (timeoutMs or 750) then
                            return false
                        end
                        NetworkRequestControlOfEntity(entity)
                    end
                    return true
                end
                
                local function tryEnterSeat(seatIndex)
                    SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
                    Wait(0)
                    return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
                end
                
                local function getFirstFreeSeat(v)
                    local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
                    if not numSeats or numSeats <= 0 then return -1 end
                    for seat = 0, (numSeats - 2) do
                        if IsVehicleSeatFree(v, seat) then return seat end
                    end
                    return -1
                end
                
                if RequestControl(targetVehicle, 750) then
                    ClearPedTasksImmediately(playerPed)
                    SetVehicleDoorsLocked(targetVehicle, 1)
                    SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)
                    
                    local success = false
                    if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                        success = true
                    end
                    
                    if not success and GetPedInVehicleSeat(targetVehicle, -1) == playerPed then
                        success = true
                    end
                    
                    if not success then
                        local fallbackSeat = getFirstFreeSeat(targetVehicle)
                        if fallbackSeat ~= -1 and tryEnterSeat(fallbackSeat) then
                            local drv = GetPedInVehicleSeat(targetVehicle, -1)
                            if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
                                RequestControl(drv, 750)
                                ClearPedTasksImmediately(drv)
                                SetEntityAsMissionEntity(drv, true, true)
                                SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
                                Wait(50)
                                DeleteEntity(drv)
                                
                                for i=1,80 do
                                    local occ = GetPedInVehicleSeat(targetVehicle, -1)
                                    if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
                                    Wait(0)
                                end
                            end
                            
                            for attempt = 1, 30 do
                                if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                                    break
                                end
                                Wait(0)
                            end
                        end
                    end
                    
                    Wait(200)
                    
                    SetEntityCoordsNoOffset(playerPed, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false)
                    SetEntityHeading(playerPed, playerHeading)
                    
                end
            end
        else
            SetEntityCoordsNoOffset(ped, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false)
            SetEntityHeading(ped, playerHeading)
        end
    ]], playerCoords.x, playerCoords.y, playerCoords.z, playerHeading, currentCamCoords.x, currentCamCoords.y, currentCamCoords.z, direction.x, direction.y, direction.z))
end

function FuckVehicleFromFreecam()
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        return
    end
    
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local playerHeading = GetEntityHeading(ped)
    local currentCamCoords = cam_pos
    local currentCamRot = cam_rot
    
    local pitch = math.rad(currentCamRot.x)
    local yaw = math.rad(currentCamRot.z)
    
    local dirX = -math.sin(yaw) * math.cos(pitch)
    local dirY = math.cos(yaw) * math.cos(pitch)
    local dirZ = math.sin(pitch)
    
    local direction = vector3(dirX, dirY, dirZ)
    
    Susano.InjectResource("any", string.format([[
        local ped = PlayerPedId()
        local playerCoords = vector3(%f, %f, %f)
        local playerHeading = %f
        local camCoords = vector3(%f, %f, %f)
        local direction = vector3(%f, %f, %f)
        
        local raycastStart = camCoords
        local raycastEnd = vector3(
            camCoords.x + direction.x * 1000.0,
            camCoords.y + direction.y * 1000.0,
            camCoords.z + direction.z * 1000.0
        )
        
        local raycast = StartExpensiveSynchronousShapeTestLosProbe(
            raycastStart.x, raycastStart.y, raycastStart.z,
            raycastEnd.x, raycastEnd.y, raycastEnd.z,
            -1, ped, 7
        )
        
        local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(raycast)
        
        if hit and entityHit and DoesEntityExist(entityHit) and GetEntityType(entityHit) == 2 then
            local targetVehicle = entityHit
            local playerPed = ped
            
            local hasPlayerInside = false
            local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(targetVehicle))
            if numSeats and numSeats > 0 then
                for seat = -1, (numSeats - 2) do
                    local seatPed = GetPedInVehicleSeat(targetVehicle, seat)
                    if seatPed and seatPed ~= 0 and DoesEntityExist(seatPed) then
                        for _, player in ipairs(GetActivePlayers()) do
                            if GetPlayerPed(player) == seatPed then
                                hasPlayerInside = true
                                break
                            end
                        end
                        if hasPlayerInside then break end
                    end
                end
            end
            
            local function RequestControl(entity, timeoutMs)
                if not entity or not DoesEntityExist(entity) then return false end
                local start = GetGameTimer()
                NetworkRequestControlOfEntity(entity)
                while not NetworkHasControlOfEntity(entity) do
                    Wait(0)
                    if GetGameTimer() - start > (timeoutMs or 750) then
                        return false
                    end
                    NetworkRequestControlOfEntity(entity)
                end
                return true
            end
            
            local function tryEnterSeat(seatIndex)
                SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
                Wait(0)
                return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
            end
            
            local function getFirstFreeSeat(v)
                local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
                if not numSeats or numSeats <= 0 then return -1 end
                for seat = 0, (numSeats - 2) do
                    if IsVehicleSeatFree(v, seat) then return seat end
                end
                return -1
            end
            
            if RequestControl(targetVehicle, 750) then
                ClearPedTasksImmediately(playerPed)
                SetVehicleDoorsLocked(targetVehicle, 1)
                SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)
                
                local success = false
                if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                    success = true
                end
                
                if not success and GetPedInVehicleSeat(targetVehicle, -1) == playerPed then
                    success = true
                end
                
                if not success then
                    local fallbackSeat = getFirstFreeSeat(targetVehicle)
                    if fallbackSeat ~= -1 and tryEnterSeat(fallbackSeat) then
                        local drv = GetPedInVehicleSeat(targetVehicle, -1)
                        if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
                            RequestControl(drv, 750)
                            ClearPedTasksImmediately(drv)
                            SetEntityAsMissionEntity(drv, true, true)
                            SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
                            Wait(50)
                            DeleteEntity(drv)
                            
                            for i=1,80 do
                                local occ = GetPedInVehicleSeat(targetVehicle, -1)
                                if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
                                Wait(0)
                            end
                        end
                        
                        for attempt = 1, 30 do
                            if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                                break
                            end
                            Wait(0)
                        end
                    end
                end
                
                Wait(200)
                
                SetVehicleEngineHealth(targetVehicle, -4000.0)
                SetVehicleBodyHealth(targetVehicle, -4000.0)
                SetVehiclePetrolTankHealth(targetVehicle, -4000.0)
                
                for door = 0, 5 do
                    SetVehicleDoorBroken(targetVehicle, door, true)
                    RemoveVehicleDoor(targetVehicle, door, false)
                end
                
                for wheel = 0, 3 do
                    SetVehicleTyreBurst(targetVehicle, wheel, true, 1000.0)
                    SetVehicleWheelHealth(targetVehicle, wheel, -1000.0)
                    SetVehicleTyreBurst(targetVehicle, wheel, true, 1000.0)
                end
                SetVehicleWheelType(targetVehicle, 7)
                Wait(50)
                for wheel = 0, 3 do
                    SetVehicleTyreBurst(targetVehicle, wheel, true, 1000.0)
                    SetVehicleWheelHealth(targetVehicle, wheel, -1000.0)
                end
                
                for window = 0, 5 do
                    SmashVehicleWindow(targetVehicle, window)
                end
                
                SetVehicleDoorOpen(targetVehicle, 4, false, false)
                SetVehicleDoorOpen(targetVehicle, 5, false, false)
                SetVehicleDoorBroken(targetVehicle, 4, true)
                SetVehicleDoorBroken(targetVehicle, 5, true)
                RemoveVehicleDoor(targetVehicle, 4, false)
                RemoveVehicleDoor(targetVehicle, 5, false)
                
                Wait(100)
                
                if IsPedInAnyVehicle(playerPed, false) then
                    ClearPedTasksImmediately(playerPed)
                    TaskLeaveVehicle(playerPed, targetVehicle, 0)
                    Wait(100)
                end
            end
            
            if IsPedInAnyVehicle(playerPed, false) then
                ClearPedTasksImmediately(playerPed)
                TaskLeaveVehicle(playerPed, targetVehicle, 0)
                Wait(100)
            end
            SetEntityCoordsNoOffset(playerPed, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false)
            SetEntityHeading(playerPed, playerHeading)
            Wait(50)
            SetEntityCoordsNoOffset(playerPed, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false)
            SetEntityHeading(playerPed, playerHeading)
        else
            SetEntityCoordsNoOffset(ped, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false)
            SetEntityHeading(ped, playerHeading)
        end
    ]], playerCoords.x, playerCoords.y, playerCoords.z, playerHeading, currentCamCoords.x, currentCamCoords.y, currentCamCoords.z, direction.x, direction.y, direction.z))
end

function StealVehicleFromFreecam()
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        return
    end
    
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local playerHeading = GetEntityHeading(ped)
    local currentCamCoords = cam_pos
    local currentCamRot = cam_rot
    
    local pitch = math.rad(currentCamRot.x)
    local yaw = math.rad(currentCamRot.z)
    
    local dirX = -math.sin(yaw) * math.cos(pitch)
    local dirY = math.cos(yaw) * math.cos(pitch)
    local dirZ = math.sin(pitch)
    
    local direction = vector3(dirX, dirY, dirZ)
    
    Susano.InjectResource("any", string.format([[
        local ped = PlayerPedId()
        local playerCoords = vector3(%f, %f, %f)
        local playerHeading = %f
        local camCoords = vector3(%f, %f, %f)
        local direction = vector3(%f, %f, %f)
        
        local raycastStart = camCoords
        local raycastEnd = vector3(
            camCoords.x + direction.x * 1000.0,
            camCoords.y + direction.y * 1000.0,
            camCoords.z + direction.z * 1000.0
        )
        
        local raycast = StartExpensiveSynchronousShapeTestLosProbe(
            raycastStart.x, raycastStart.y, raycastStart.z,
            raycastEnd.x, raycastEnd.y, raycastEnd.z,
            -1, ped, 7
        )
        
        local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(raycast)
        
        if hit and entityHit and DoesEntityExist(entityHit) and GetEntityType(entityHit) == 2 then
            local targetVehicle = entityHit
            local playerPed = ped
            
            local function RequestControl(entity, timeoutMs)
                if not entity or not DoesEntityExist(entity) then return false end
                local start = GetGameTimer()
                NetworkRequestControlOfEntity(entity)
                while not NetworkHasControlOfEntity(entity) do
                    Wait(0)
                    if GetGameTimer() - start > (timeoutMs or 500) then
                        return false
                    end
                    NetworkRequestControlOfEntity(entity)
                end
                return true
            end
            
            RequestControl(targetVehicle, 800)
            SetVehicleDoorsLocked(targetVehicle, 1)
            SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)
            
            local function tryEnterSeat(seatIndex)
                SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
                Wait(0)
                return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
            end
            
            local function getFirstFreeSeat(v)
                local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
                if not numSeats or numSeats <= 0 then return -1 end
                for seat = 0, (numSeats - 2) do
                    if IsVehicleSeatFree(v, seat) then return seat end
                end
                return -1
            end
            
            ClearPedTasksImmediately(playerPed)
            SetVehicleDoorsLocked(targetVehicle, 1)
            SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)
            
            local takeoverSuccess = false
            local tStart = GetGameTimer()
            
            while (GetGameTimer() - tStart) < 1000 do
                RequestControl(targetVehicle, 400)
                
                if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                    takeoverSuccess = true
                    break
                end
                
                if not IsPedInVehicle(playerPed, targetVehicle, false) then
                    local fs = getFirstFreeSeat(targetVehicle)
                    if fs ~= -1 then
                        tryEnterSeat(fs)
                    end
                end
                
                local drv = GetPedInVehicleSeat(targetVehicle, -1)
                if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
                    RequestControl(drv, 400)
                    ClearPedTasksImmediately(drv)
                    SetEntityAsMissionEntity(drv, true, true)
                    SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
                    Wait(20)
                    DeleteEntity(drv)
                end
                
                local t0 = GetGameTimer()
                while (GetGameTimer() - t0) < 400 do
                    local occ = GetPedInVehicleSeat(targetVehicle, -1)
                    if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
                    Wait(0)
                end
                
                local t1 = GetGameTimer()
                while (GetGameTimer() - t1) < 500 do
                    if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                        takeoverSuccess = true
                        break
                    end
                    Wait(0)
                end
                if takeoverSuccess then break end
                Wait(0)
            end
            
            if takeoverSuccess then
                if DoesEntityExist(targetVehicle) and IsPedInVehicle(playerPed, targetVehicle, false) then
                    RequestControl(targetVehicle, 1000)
                    if NetworkHasControlOfEntity(targetVehicle) then
                        FreezeEntityPosition(targetVehicle, true)
                        SetVehicleEngineOn(targetVehicle, true, true, false)
                        SetEntityCoordsNoOffset(targetVehicle, playerCoords.x, playerCoords.y, playerCoords.z + 1.0, false, false, false, false)
                        SetEntityHeading(targetVehicle, playerHeading)
                        SetEntityVelocity(targetVehicle, 0.0, 0.0, 0.0)
                        Wait(100)
                        FreezeEntityPosition(targetVehicle, false)
                        SetVehicleOnGroundProperly(targetVehicle)
                    end
                end
            end
        end
    ]], playerCoords.x, playerCoords.y, playerCoords.z, playerHeading, currentCamCoords.x, currentCamCoords.y, currentCamCoords.z, direction.x, direction.y, direction.z))
end

function DeleteVehicleFromFreecam()
    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        return
    end
    
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local playerHeading = GetEntityHeading(ped)
    local currentCamCoords = cam_pos
    local currentCamRot = cam_rot
    
    local pitch = math.rad(currentCamRot.x)
    local yaw = math.rad(currentCamRot.z)
    
    local dirX = -math.sin(yaw) * math.cos(pitch)
    local dirY = math.cos(yaw) * math.cos(pitch)
    local dirZ = math.sin(pitch)
    
    local direction = vector3(dirX, dirY, dirZ)
    
    Susano.InjectResource("any", string.format([[
        local ped = PlayerPedId()
        local playerCoords = vector3(%f, %f, %f)
        local playerHeading = %f
        local camCoords = vector3(%f, %f, %f)
        local direction = vector3(%f, %f, %f)
        
        local raycastStart = camCoords
        local raycastEnd = vector3(
            camCoords.x + direction.x * 1000.0,
            camCoords.y + direction.y * 1000.0,
            camCoords.z + direction.z * 1000.0
        )
        
        local raycast = StartExpensiveSynchronousShapeTestLosProbe(
            raycastStart.x, raycastStart.y, raycastStart.z,
            raycastEnd.x, raycastEnd.y, raycastEnd.z,
            -1, ped, 7
        )
        
        local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(raycast)
        
        if hit and entityHit and DoesEntityExist(entityHit) and GetEntityType(entityHit) == 2 then
            local targetVehicle = entityHit
            local playerPed = ped
            
            local function RequestControl(entity, timeoutMs)
                if not entity or not DoesEntityExist(entity) then return false end
                local start = GetGameTimer()
                NetworkRequestControlOfEntity(entity)
                while not NetworkHasControlOfEntity(entity) do
                    Wait(0)
                    if GetGameTimer() - start > (timeoutMs or 750) then
                        return false
                    end
                    NetworkRequestControlOfEntity(entity)
                end
                return true
            end
            
            local function tryEnterSeat(seatIndex)
                SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
                Wait(0)
                return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
            end
            
            local function getFirstFreeSeat(v)
                local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
                if not numSeats or numSeats <= 0 then return -1 end
                for seat = 0, (numSeats - 2) do
                    if IsVehicleSeatFree(v, seat) then return seat end
                end
                return -1
            end
            
            if RequestControl(targetVehicle, 750) then
                ClearPedTasksImmediately(playerPed)
                SetVehicleDoorsLocked(targetVehicle, 1)
                SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)
                
                local success = false
                if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                    success = true
                end
                
                if not success and GetPedInVehicleSeat(targetVehicle, -1) == playerPed then
                    success = true
                end
                
                if not success then
                    local fallbackSeat = getFirstFreeSeat(targetVehicle)
                    if fallbackSeat ~= -1 and tryEnterSeat(fallbackSeat) then
                        local drv = GetPedInVehicleSeat(targetVehicle, -1)
                        if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
                            RequestControl(drv, 750)
                            ClearPedTasksImmediately(drv)
                            SetEntityAsMissionEntity(drv, true, true)
                            SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
                            Wait(50)
                            DeleteEntity(drv)
                            
                            for i=1,80 do
                                local occ = GetPedInVehicleSeat(targetVehicle, -1)
                                if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
                                Wait(0)
                            end
                        end
                        
                        for attempt = 1, 30 do
                            if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                                break
                            end
                            Wait(0)
                        end
                    end
                end
                
                Wait(200)
                
                SetEntityAsMissionEntity(targetVehicle, true, true)
                RequestControl(targetVehicle, 1000)
                if NetworkHasControlOfEntity(targetVehicle) then
                    DeleteEntity(targetVehicle)
                end
            end
            
            SetEntityCoordsNoOffset(playerPed, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false)
            SetEntityHeading(playerPed, playerHeading)
        else
            SetEntityCoordsNoOffset(ped, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false)
            SetEntityHeading(ped, playerHeading)
        end
    ]], playerCoords.x, playerCoords.y, playerCoords.z, playerHeading, currentCamCoords.x, currentCamCoords.y, currentCamCoords.z, direction.x, direction.y, direction.z))
end

function HandleInput()
    local scrollValue = GetDisabledControlNormal(0, 14)
    local currentTime = GetGameTimer()
    
    if lastScrollTime == 0 then
        lastScrollTime = currentTime
        lastScrollValue = scrollValue
    end
    
    local scrollDelta = scrollValue - lastScrollValue
    if (currentTime - lastScrollTime) > 100 then
        if scrollDelta > 0.1 then
            FreecamSelectedOption = FreecamSelectedOption + 1
            if FreecamSelectedOption > #FreecamOptions then
                FreecamSelectedOption = 1
            end
            lastScrollTime = currentTime
            lastScrollValue = scrollValue
        elseif scrollDelta < -0.1 then
            FreecamSelectedOption = FreecamSelectedOption - 1
            if FreecamSelectedOption < 1 then
                FreecamSelectedOption = #FreecamOptions
            end
            lastScrollTime = currentTime
            lastScrollValue = scrollValue
        end
    end
    
    if math.abs(scrollValue) < 0.05 then
        lastScrollValue = scrollValue
    end
    
    local click_pressed = IsDisabledControlJustPressed(0, 24)
    local current_time = GetGameTimer()
    
    if click_pressed and not freecam_just_started and (current_time - last_click_time) > 200 then
        local selectedOptionName = FreecamOptions[FreecamSelectedOption]
        if selectedOptionName == "Teleport" then
            TeleportToFreecam()
        elseif selectedOptionName == "Warp Vehicle" then
            WarpVehicleToFreecam()
        elseif selectedOptionName == "Shoot Bullet" then
            ShootBulletFromFreecam()
        elseif selectedOptionName == "Kick Vehicle" then
            UnusableVehicleFromFreecam()
        elseif selectedOptionName == "Fuck Vehicle" then
            FuckVehicleFromFreecam()
        elseif selectedOptionName == "Steal Vehicle" then
            StealVehicleFromFreecam()
        elseif selectedOptionName == "Delete Vehicle" then
            DeleteVehicleFromFreecam()
        end
        last_click_time = current_time
    end
end
            
function UpdateFreecam()
    if not freecam_active then return end
    
    
    HandleInput()
    
    
    local forward = 0.0
    local sideways = 0.0
    local vertical = 0.0
    
    if Susano.GetAsyncKeyState(VK_Z) then forward = 1.0 end
    if Susano.GetAsyncKeyState(VK_S) then forward = -1.0 end
    if Susano.GetAsyncKeyState(VK_D) then sideways = 1.0 end
    if Susano.GetAsyncKeyState(VK_Q) then sideways = -1.0 end
    if Susano.GetAsyncKeyState(VK_SPACE) then vertical = 1.0 end
    if Susano.GetAsyncKeyState(VK_CONTROL) then vertical = -1.0 end
    
    
    local speed = normal_speed
    if Susano.GetAsyncKeyState(VK_SHIFT) then
        speed = fast_speed
    end
    
    
    local currentRot = GetGameplayCamRot(2)
    cam_rot = vector3(currentRot.x, currentRot.y, currentRot.z)
    
    local rad_pitch = math.rad(cam_rot.x)
    local rad_yaw = math.rad(cam_rot.z)
    
    
    cam_pos = vector3(
        cam_pos.x + forward * (-math.sin(rad_yaw)) * math.cos(rad_pitch) * speed,
        cam_pos.y + forward * (math.cos(rad_yaw)) * math.cos(rad_pitch) * speed,
        cam_pos.z + forward * (math.sin(rad_pitch)) * speed
    )
    
    
    cam_pos = vector3(
        cam_pos.x + sideways * (math.cos(rad_yaw)) * speed,
        cam_pos.y + sideways * (math.sin(rad_yaw)) * speed,
        cam_pos.z
    )
    
    
    cam_pos = vector3(cam_pos.x, cam_pos.y, cam_pos.z + vertical * speed)
    
    
    ForceWorldLoad()
    
    
    Susano.SetCameraPos(cam_pos.x, cam_pos.y, cam_pos.z)
end

local function ToggleFreecam(enable, speed)
    Menu.freecamEnabled = enable
    if speed then
        freecamSpeed = speed
        normal_speed = speed
        fast_speed = speed * 5.0
    end
    if Menu.freecamEnabled then
        StartFreecam()
    else
        StopFreecam()
    end
end

-- [REMOVED] Freecam handler (Movement tab deleted)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if freecam_active then
            DisableAllControlActions(0)
            
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            EnableControlAction(0, 14, true)
            EnableControlAction(0, 15, true)
            EnableControlAction(0, 24, true)
            
            UpdateFreecam()
        end
        
        
        DrawFreecamMenu()
    end
end)



                    do
                        Actions.shootEyesItem = FindItem("Combat", "General", "Shoot Eyes")
                        if Actions.shootEyesItem then
                            Actions.shootEyesItem.onClick = function(value)
                                Menu.shooteyesEnabled = value
                                if value then StealthAcquire("ac") else StealthRelease("ac") end
                            end
                        end
                    end

                    do
                        Actions.superPunchItem = FindItem("Combat", "General", "Super Punch")
                        if Actions.superPunchItem then
                            Actions.superPunchItem.onClick = function(value)
                                Menu.superPunchEnabled = value
                                if value then StealthAcquire("ac") else StealthRelease("ac") end
                            end
                        end
                    end

                    CreateThread(function()
                        while true do
                            Wait(0)
                            if Menu.superPunchEnabled then
                                SetWeaponDamageModifier(GetHashKey("WEAPON_UNARMED"), 100.0)
                                SetWeaponDamageModifier(GetHashKey("WEAPON_KNUCKLE"), 100.0)
                            else
                                SetWeaponDamageModifier(GetHashKey("WEAPON_UNARMED"), 1.0)
                                SetWeaponDamageModifier(GetHashKey("WEAPON_KNUCKLE"), 1.0)
                            end
                        end
                    end)

                    do
                        local weaponOptions = {
                            {name = "give weapon_aa", weapon = "weapon_aa"},
                            {name = "give weapon_caveira", weapon = "weapon_caveira"},
                            {name = "give weapon_SCOM", weapon = "weapon_SCOM"},
                            {name = "give weapon_mcx", weapon = "weapon_mcx"},
                            {name = "give weapon_grau", weapon = "weapon_grau"},
                            {name = "give weapon_midasgun", weapon = "weapon_midasgun"},
                            {name = "give weapon_hackingdevice", weapon = "weapon_hackingdevice"},
                            {name = "give weapon_akorus", weapon = "weapon_akorus"},
                            {name = "give WEAPON_MIDGARD", weapon = "WEAPON_MIDGARD"},
                            {name = "give weapon_chainsaw", weapon = "weapon_chainsaw"},
                            {name = "give weapon_m4a1smr", weapon = "weapon_m4a1smr"},
                            {name = "give weapon_aks74u", weapon = "weapon_aks74u"},
                            {name = "give WEAPON_ASSAULTXMAS", weapon = "WEAPON_ASSAULTXMAS"},
                            {name = "give weapon_scar17", weapon = "weapon_scar17"},
                            {name = "give weapon_blacksniper", weapon = "weapon_blacksniper"},
                            {name = "give weapon_hkhall", weapon = "weapon_hkhall"},
                            {name = "give weapon_hk_ump", weapon = "weapon_hk_ump"}
                        }
                        
                        local weaponHashMap = {
                            ["weapon_aa"] = GetHashKey("weapon_aa"),
                            ["weapon_caveira"] = GetHashKey("weapon_caveira"),
                            ["weapon_SCOM"] = GetHashKey("weapon_SCOM"),
                            ["weapon_mcx"] = GetHashKey("weapon_mcx"),
                            ["weapon_grau"] = GetHashKey("weapon_grau"),
                            ["weapon_midasgun"] = GetHashKey("weapon_midasgun"),
                            ["weapon_hackingdevice"] = GetHashKey("weapon_hackingdevice"),
                            ["weapon_akorus"] = GetHashKey("weapon_akorus"),
                            ["WEAPON_MIDGARD"] = GetHashKey("WEAPON_MIDGARD"),
                            ["weapon_chainsaw"] = GetHashKey("weapon_chainsaw"),
                            ["weapon_m4a1smr"] = GetHashKey("weapon_m4a1smr"),
                            ["weapon_aks74u"] = GetHashKey("weapon_aks74u"),
                            ["WEAPON_ASSAULTXMAS"] = GetHashKey("WEAPON_ASSAULTXMAS"),
                            ["weapon_scar17"] = GetHashKey("weapon_scar17"),
                            ["weapon_blacksniper"] = GetHashKey("weapon_blacksniper"),
                            ["weapon_hkhall"] = GetHashKey("weapon_hkhall"),
                            ["weapon_hk_ump"] = GetHashKey("weapon_hk_ump"),
                        }

                        local function GiveWeaponByHash(hash, ammo)
                            local weaponHash = nil
                            local hashString = tostring(hash)
                            
                            if type(hash) == "number" then
                                weaponHash = hash
                            else
                                weaponHash = GetHashKey(hashString)
                            end
                            
                            local weaponAA = GetHashKey("weapon_aa")
                            local weaponCaveira = GetHashKey("weapon_caveira")
                            ammo = ammo or 250

                            local ped = PlayerPedId()
                            
                            local function ForceGiveWeapon(weaponName)
                                local testHash = GetHashKey(weaponName)
                                if testHash and testHash ~= 0 then
                                    if HasWeaponAssetLoaded and HasWeaponAssetLoaded(testHash) == 0 then
                                        RequestWeaponAsset(testHash, 31, 0)
                                        local timeout = 0
                                        while HasWeaponAssetLoaded and HasWeaponAssetLoaded(testHash) == 0 and timeout < 50 do
                                            Wait(10)
                                            timeout = timeout + 1
                                        end
                                    end
                                    
                                    GiveWeaponToPed(ped, testHash, ammo, false, true)
                                    SetPedAmmo(ped, testHash, ammo)
                                    SetCurrentPedWeapon(ped, testHash, true)
                                    SetPedInfiniteAmmoClip(ped, true)
                                    Wait(100)
                                    if HasPedGotWeapon(ped, testHash, false) then
                                        return true
                                    end
                                end
                                return false
                            end

                            if weaponHash == weaponAA or (hashString and (hashString:lower() == "weapon_aa")) then
                                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                    Susano.InjectResource("any", string.format([[
                                        local susano = rawget(_G, "Susano")
                                        if susano and type(susano) == "table" and type(susano.HookNative) == "function" then
                                            susano.HookNative(0x3A87E44BB9A01D54, function(ped, weaponHash) return true, -1569615261 end)

                                            susano.HookNative(0xADF692B254977C0C, function(ped, weapon, equipNow)
                                                if weapon == -1569615261 then
                                                    return true
                                                end
                                                return true
                                            end)

                                            susano.HookNative(0xF25DF915FA38C5F3, function(ped, p1) return end)

                                            susano.HookNative(0x4899CB088EDF3BCC, function(ped, weaponHash, p2) return end)

                                            susano.HookNative(0x3795688A307E1EB6, function(ped) return false end)
                                            susano.HookNative(0x0A6DB4965674D243, function(ped) return -1569615261 end)
                                            susano.HookNative(0xC3287EE3050FB74C, function(weaponHash) return -1569615261 end)
                                            susano.HookNative(0x475768A975D5AD17, function(ped, p1) return false end)
                                            susano.HookNative(0x8DECB02F88F428BC, function(ped, weaponHash, p2) return false end)
                                            susano.HookNative(0x34616828CD07F1A1, function(ped) return false end)
                                            susano.HookNative(0x3A50753042A63901, function(ped) return false end)
                                            susano.HookNative(0xB2A38826EAB6BCF1, function(ped) return false end)
                                            susano.HookNative(0xED958C9C056BF401, function(ped) return false end)
                                            susano.HookNative(0x8483E98E8B888A2D, function(ped, p1) return -1569615261 end)
                                            susano.HookNative(0xA38DCFFCE89696FA, function(ped, weaponHash) return 0 end)
                                            susano.HookNative(0x7FEAD38B326B9F74, function(ped, weaponHash) return 0 end)
                                            susano.HookNative(0x3B390A939AF0B5FC, function(ped) return -1 end)
                                            susano.HookNative(0x59DE03442B6C9598, function(weaponHash) return -1569615261 end)
                                            susano.HookNative(0x3133B907D8B32053, function(weaponHash, componentHash) return 0.3 end)
                                            susano.HookNative(0x97A790315D3831FD, function(entity) return 0 end)
                                            susano.HookNative(0x48C2BED9180FE123, function(entity) return false end)
                                            susano.HookNative(0x89CF5FF3D310A0DB, function(weaponHash) return -1569615261 end)
                                            susano.HookNative(0x24B600C29F7F8A9E, function(ped) return false end)
                                            susano.HookNative(0x8483E98E8B888AE2, function(ped, p1) return -1569615261 end)
                                            susano.HookNative(0xCAE1DC9A0E22A16D, function(ped) return 0 end)
                                            susano.HookNative(0x4899CB088EDF59B8, function(ped, weaponHash) return end)
                                            susano.HookNative(0x2E1202248937775C, function(ped, weaponHash, ammo) return true, 9999 end)
                                            susano.HookNative(0x2B9EEDC07BD06B9F, function(ped, weaponHash) return 0 end)
                                        end

                                        local _GetCurrentPedWeapon = GetCurrentPedWeapon
                                        local _RemoveAllPedWeapons = RemoveAllPedWeapons
                                        local _RemoveWeaponFromPed = RemoveWeaponFromPed
                                        local _SetCurrentPedWeapon = SetCurrentPedWeapon

                                        GetCurrentPedWeapon = function(ped, ...)
                                            return true, GetHashKey("WEAPON_UNARMED")
                                        end

                                        RemoveAllPedWeapons = function(ped, ...) return end

                                        RemoveWeaponFromPed = function(ped, weapon) return end

                                        SetCurrentPedWeapon = function(ped, weapon, ...)
                                            if weapon == GetHashKey("WEAPON_UNARMED") then
                                                return _SetCurrentPedWeapon(ped, weapon, ...)
                                            end
                                            return
                                        end

                                        local weaponAAHash = GetHashKey("weapon_aa")
                                        local weaponCaveiraHash = GetHashKey("weapon_caveira")
                                        local weaponPenisHash = GetHashKey("weapon_penis")
                                        local weaponPenisHash = GetHashKey("weapon_grau")
                                        local weaponPenisHash = GetHashKey("weapon_mcx")
                                        local weaponPenisHash = GetHashKey("weapon_midasgun")
                                        local weaponPenisHash = GetHashKey("weapon_hackingdevice")
                                        local weaponPenisHash = GetHashKey("weapon_akorus")
                                        local weaponPenisHash = GetHashKey("weapon_midgard")
                                        local weaponPenisHash = GetHashKey("weapon_chainsaw")
                                        local selfPed = PlayerPedId()

                                        GiveWeaponToPed(selfPed, weaponAAHash, 999, false, true)
                                        SetPedAmmo(selfPed, weaponAAHash, 999)

                                        GiveWeaponToPed(selfPed, weaponCaveiraHash, 999, false, true)
                                        SetPedAmmo(selfPed, weaponCaveiraHash, 999)

                                        GiveWeaponToPed(selfPed, weaponPenisHash, 999, false, true)
                                        SetPedAmmo(selfPed, weaponPenisHash, 999)

                                        _SetCurrentPedWeapon(selfPed, weaponAAHash, true)
                                    ]]))
                                end
                            else
                                local mappedHash = weaponHashMap[hashString]
                                if mappedHash and mappedHash ~= 0 then
                                    if ForceGiveWeapon(hashString) then
                                        return
                                    end
                                end
                                
                                local variants = {
                                    hashString,
                                    hashString:upper(),
                                    hashString:lower(),
                                    "WEAPON_" .. hashString:upper(),
                                    "WEAPON_" .. hashString:gsub("WEAPON_", ""):upper(),
                                    hashString:gsub("WEAPON_", ""):upper(),
                                    hashString:gsub("weapon_", ""):upper(),
                                    hashString:gsub("weapon_", "WEAPON_"),
                                    hashString:gsub("WEAPON_", "weapon_"),
                                }
                                
                                local given = false
                                for _, variant in ipairs(variants) do
                                    if ForceGiveWeapon(variant) then
                                        given = true
                                        break
                                    end
                                end
                                
                                if not given then
                                    local allHashes = {
                                        weaponHash,
                                        mappedHash,
                                        GetHashKey(hashString),
                                        GetHashKey(hashString:upper()),
                                        GetHashKey(hashString:lower()),
                                    }
                                    
                                    for _, testHash in ipairs(allHashes) do
                                        if testHash then
                                            GiveWeaponToPed(ped, testHash, ammo, false, true)
                                            SetPedAmmo(ped, testHash, ammo)
                                            SetCurrentPedWeapon(ped, testHash, true)
                                            SetPedInfiniteAmmoClip(ped, true)
                                            Wait(100)
                                            if HasPedGotWeapon(ped, testHash, false) then
                                                given = true
                                                break
                                            end
                                        end
                                    end
                                    
                                    if not given then
                                        local finalHash = GetHashKey(hashString)
                                        GiveWeaponToPed(ped, finalHash, ammo, false, true)
                                        SetPedAmmo(ped, finalHash, ammo)
                                        SetCurrentPedWeapon(ped, finalHash, true)
                                        SetPedInfiniteAmmoClip(ped, true)
                                        
                                        Wait(100)
                                        if not HasPedGotWeapon(ped, finalHash, false) then
                                            TriggerServerEvent("giveWeapon", hashString, ammo)
                                        end
                                    end
                                end
                            end
                        end

                        for _, weaponData in ipairs(weaponOptions) do
                            local weaponItem = FindItem("Combat", "Spawn", weaponData.name)
                            if weaponItem then
                                weaponItem.onClick = function()
                                    GiveWeaponByHash(weaponData.weapon, 250)
                                end
                            end
                        end
                    end

                    Actions.protectWeaponItem = FindItem("Combat", "Spawn", "Protect Weapon")
                    if Actions.protectWeaponItem then
                        Actions.protectWeaponItem.onClick = function(value)
                            if value then
                                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                    Susano.InjectResource("any", [[
                                        local susano = rawget(_G, "Susano")
                                        if susano and type(susano) == "table" and type(susano.HookNative) == "function" then
                                            if not rawget(_G, 'weapon_protect_hooks_active') then
                                                rawset(_G, 'weapon_protect_hooks_active', true)
                                                
                                                susano.HookNative(0x3A87E44BB9A01D54, function(ped, weaponHash) return -1569615261 end)
                                                susano.HookNative(0x3795688A307E1EB6, function(ped) return false end)
                                                susano.HookNative(0x0A6DB4965674D243, function(ped) return -1569615261 end)
                                                susano.HookNative(0xC3287EE3050FB74C, function(weaponHash) return -1569615261 end)
                                                susano.HookNative(0x475768A975D5AD17, function(ped, p1) return false end)
                                                susano.HookNative(0x8DECB02F88F428BC, function(ped, weaponHash, p2) return false end)
                                                susano.HookNative(0x34616828CD07F1A1, function(ped) return false end)
                                                susano.HookNative(0x3A50753042A63901, function(ped) return false end)
                                                susano.HookNative(0xF25DF915FA38C5F3, function(ped, p1) return end)
                                                susano.HookNative(0x4899CB088EDF3BCC, function(ped, weaponHash, p2) return end)
                                                susano.HookNative(0xB2A38826EAB6BCF1, function(ped) return false end)
                                                susano.HookNative(0xED958C9C056BF401, function(ped) return false end)
                                                susano.HookNative(0x8483E98E8B888A2D, function(ped, p1) return -1569615261 end)
                                                susano.HookNative(0xA38DCFFCE89696FA, function(ped, weaponHash) return 0 end)
                                                susano.HookNative(0x7FEAD38B326B9F74, function(ped, weaponHash) return 0 end)
                                                susano.HookNative(0x3B390A939AF0B5FC, function(ped) return -1 end)
                                                susano.HookNative(0x59DE03442B6C9598, function(weaponHash) return -1569615261 end)
                                                susano.HookNative(0x3133B907D8B32053, function(weaponHash, componentHash) return 0.3 end)
                                                susano.HookNative(0x97A790315D3831FD, function(entity) return 0 end)
                                                susano.HookNative(0x48C2BED9180FE123, function(entity) return false end)
                                                susano.HookNative(0x89CF5FF3D310A0DB, function(weaponHash) return -1569615261 end)
                                                susano.HookNative(0x24B600C29F7F8A9E, function(ped) return false end)
                                                susano.HookNative(0x8483E98E8B888AE2, function(ped, p1) return -1569615261 end)
                                                susano.HookNative(0xCAE1DC9A0E22A16D, function(ped) return 0 end)
                                                susano.HookNative(0x4899CB088EDF59B8, function(ped, weaponHash) return end)
                                                susano.HookNative(0x2E1202248937775C, function(ped, weaponHash, ammo) return true, 9999 end)
                                                susano.HookNative(0x2B9EEDC07BD06B9F, function(ped, weaponHash) return 0 end)
                                                
                                                susano.HookNative(0xB0237302, function()
                                                    local selfPed = PlayerPedId()
                                                    local selfCurrentWeapon = SetCurrentPedWeapon
                                                    return selfCurrentWeapon(selfPed, GetHashKey("WEAPON_UNARMED"), true)
                                                end)
                                                
                                                susano.HookNative(0xC4D88A85, function(ped, weaponHash, ammo, ...)
                                                    return ped, weaponHash, ammo, ...
                                                end)
                                                
                                                local _GetCurrentPedWeapon = GetCurrentPedWeapon
                                                local _RemoveAllPedWeapons = RemoveAllPedWeapons
                                                local _RemoveWeaponFromPed = RemoveWeaponFromPed
                                                local _SetCurrentPedWeapon = SetCurrentPedWeapon
                                                
                                                GetCurrentPedWeapon = function(ped, ...)
                                                    return true, GetHashKey("WEAPON_UNARMED")
                                                end
                                                
                                                RemoveAllPedWeapons = function(ped, ...) return end
                                                
                                                RemoveWeaponFromPed = function(ped, weapon) return end
                                                
                                                SetCurrentPedWeapon = function(ped, weapon, ...)
                                                    if weapon == GetHashKey("WEAPON_UNARMED") then
                                                        return _SetCurrentPedWeapon(ped, weapon, ...)
                                                    end
                                                    return
                                                end
                                            end
                                        end
                                    ]])
                                end
                            else
                                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                    Susano.InjectResource("any", [[
                                        rawset(_G, 'weapon_protect_hooks_active', false)
                                    ]])
                                end
                            end
                        end
                    end

                    CreateThread(function()
                        while true do
                            Wait(0)

                            if Menu.shooteyesEnabled then
                                DrawRect(0.5, 0.5, 0.002, 0.003, 157, 0, 255, 255)
                                if IsControlPressed(0, 38) then 
                                    local playerPed = PlayerPedId()
                                    local currentWeapon = GetSelectedPedWeapon(playerPed)
                                    
                                    if currentWeapon == GetHashKey("WEAPON_UNARMED") or currentWeapon == 0 then
                                        local weapons = {
                                            "WEAPON_PISTOL", "WEAPON_PISTOL_MK2", "WEAPON_COMBATPISTOL", "WEAPON_APPISTOL",
                                            "WEAPON_PISTOL50", "WEAPON_SNSPISTOL", "WEAPON_HEAVYPISTOL", "WEAPON_VINTAGEPISTOL",
                                            "WEAPON_MICROSMG", "WEAPON_SMG", "WEAPON_SMG_MK2", "WEAPON_ASSAULTSMG",
                                            "WEAPON_ASSAULTRIFLE", "WEAPON_ASSAULTRIFLE_MK2", "WEAPON_CARBINERIFLE", "WEAPON_CARBINERIFLE_MK2",
                                            "WEAPON_ADVANCEDRIFLE", "WEAPON_SPECIALCARBINE", "WEAPON_BULLPUPRIFLE", "WEAPON_COMPACTRIFLE",
                                            "WEAPON_SNIPERRIFLE", "WEAPON_HEAVYSNIPER", "WEAPON_HEAVYSNIPER_MK2", "WEAPON_MARKSMANRIFLE",
                                            "WEAPON_PUMPSHOTGUN", "WEAPON_PUMPSHOTGUN_MK2", "WEAPON_SAWNOFFSHOTGUN", "WEAPON_ASSAULTSHOTGUN",
                                            "WEAPON_MG", "WEAPON_COMBATMG", "WEAPON_COMBATMG_MK2", "WEAPON_GUSENBERG",
                                            "WEAPON_RPG", "WEAPON_GRENADELAUNCHER", "WEAPON_MINIGUN", "WEAPON_RAILGUN"
                                        }
                                        
                                        for _, weaponName in ipairs(weapons) do
                                            local weaponHash = GetHashKey(weaponName)
                                            if HasPedGotWeapon(playerPed, weaponHash, false) then
                                                currentWeapon = weaponHash
                                                break
                                            end
                                        end
                                    end
                                    
                                    if currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 0 then
                                        if not rawget(_G, 'shoot_eyes_cooldown') or GetGameTimer() > rawget(_G, 'shoot_eyes_cooldown') then
                                            local camCoords = GetGameplayCamCoord()
                                            local camRot = GetGameplayCamRot(0)
                                            
                                            local z = math.rad(camRot.z)
                                            local x = math.rad(camRot.x)
                                            local num = math.abs(math.cos(x))
                                            local dirX = -math.sin(z) * num
                                            local dirY = math.cos(z) * num
                                            local dirZ = math.sin(x)
                                            
                                            local distance = 1000.0
                                            local endX = camCoords.x + dirX * distance
                                            local endY = camCoords.y + dirY * distance
                                            local endZ = camCoords.z + dirZ * distance
                                            
                                            local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, endX, endY, endZ, -1, playerPed, 0)
                                            local retval, hit, hitCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)
                                            
                                            local weaponCoords = GetOffsetFromEntityInWorldCoords(playerPed, 0.5, 1.0, 0.5)
                                            local targetCoords = vector3(endX, endY, endZ)
                                            
                                            if hit and hitCoords then
                                                targetCoords = hitCoords
                                            end
                                            
                                            ShootSingleBulletBetweenCoords(
                                                weaponCoords.x, weaponCoords.y, weaponCoords.z,
                                                targetCoords.x, targetCoords.y, targetCoords.z,
                                                25, true, currentWeapon, playerPed, true, false, 1000.0
                                            )
                                            
                                            rawset(_G, 'shoot_eyes_cooldown', GetGameTimer() + 350)
                                        end
                                    end
                                end
                            end
                        end
                    end)

                    do
                        Actions.silentAimItem = FindItem("Combat", "General", "Silent Aim")
                        if Actions.silentAimItem then
                            Actions.silentAimItem.onClick = function(value)
                                Menu.silentAimEnabled = value
                                if value then StealthAcquire("ac") else StealthRelease("ac") end
                            end
                        end
                    end



                    CreateThread(function()
                        while true do
                            Wait(0)
                            
                            if Menu.silentAimEnabled then
                                local playerPed = PlayerPedId()
                                if IsPedShooting(playerPed) then
                                    if not rawget(_G, 'silent_aim_cooldown') or GetGameTimer() > rawget(_G, 'silent_aim_cooldown') then
                                        local currentWeapon = GetSelectedPedWeapon(playerPed)
                                        if currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 0 then
                                            local playerCoords = GetEntityCoords(playerPed)
                                            local peds = GetGamePool('CPed')
                                            local targetPed = nil
                                            local bestDist = 999999.0
                                            
                                            for _, ped in ipairs(peds) do
                                                if ped ~= playerPed and DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then
                                                    local pedCoords = GetEntityCoords(ped)
                                                    local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(pedCoords.x, pedCoords.y, pedCoords.z)
                                                    if onScreen then
                                                        local dist = #(pedCoords - playerCoords)
                                                        if dist < bestDist then
                                                            bestDist = dist
                                                                        targetPed = ped
                                                        end
                                                    end
                                                end
                                            end
                                            
                                            if targetPed then
                                                local boneIndex = 31086
                                                local targetBone = GetPedBoneIndex(targetPed, boneIndex)
                                                local targetCoords = GetWorldPositionOfEntityBone(targetPed, targetBone)
                                                    
                                                    ShootSingleBulletBetweenCoords(
                                                    targetCoords.x, targetCoords.y, targetCoords.z + 0.1,
                                                        targetCoords.x, targetCoords.y, targetCoords.z,
                                                    25, true, currentWeapon, playerPed, true, false, 1000.0
                                                    )
                                                rawset(_G, 'silent_aim_cooldown', GetGameTimer() + 100)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                    end)

                    Actions.magicBulletItem = FindItem("Combat", "General", "Magic Bullet")
                    if Actions.magicBulletItem then
                        Actions.magicBulletItem.onClick = function(value)
                            Menu.magicbulletEnabled = value
                            if value then StealthAcquire("ac") else StealthRelease("ac") end
                        end
                    end

                    CreateThread(function()
                        while true do
                            Wait(0)

                            if Menu.magicbulletEnabled then
                                local playerPed = PlayerPedId()
                                if IsPedShooting(playerPed) then
                                    if not rawget(_G, 'magic_bullet_cooldown') or GetGameTimer() > rawget(_G, 'magic_bullet_cooldown') then
                                        
                                        local currentWeapon = GetSelectedPedWeapon(playerPed)
                                        
                                        if currentWeapon == GetHashKey("WEAPON_UNARMED") or currentWeapon == 0 then
                                            local weapons = {
                                                "WEAPON_PISTOL", "WEAPON_PISTOL_MK2", "WEAPON_COMBATPISTOL", "WEAPON_APPISTOL",
                                                "WEAPON_PISTOL50", "WEAPON_SNSPISTOL", "WEAPON_HEAVYPISTOL", "WEAPON_VINTAGEPISTOL",
                                                "WEAPON_MICROSMG", "WEAPON_SMG", "WEAPON_SMG_MK2", "WEAPON_ASSAULTSMG",
                                                "WEAPON_ASSAULTRIFLE", "WEAPON_ASSAULTRIFLE_MK2", "WEAPON_CARBINERIFLE", "WEAPON_CARBINERIFLE_MK2",
                                                "WEAPON_ADVANCEDRIFLE", "WEAPON_SPECIALCARBINE", "WEAPON_BULLPUPRIFLE", "WEAPON_COMPACTRIFLE",
                                                "WEAPON_SNIPERRIFLE", "WEAPON_HEAVYSNIPER", "WEAPON_HEAVYSNIPER_MK2", "WEAPON_MARKSMANRIFLE",
                                                "WEAPON_PUMPSHOTGUN", "WEAPON_PUMPSHOTGUN_MK2", "WEAPON_SAWNOFFSHOTGUN", "WEAPON_ASSAULTSHOTGUN",
                                                "WEAPON_MG", "WEAPON_COMBATMG", "WEAPON_COMBATMG_MK2", "WEAPON_GUSENBERG",
                                                "WEAPON_RPG", "WEAPON_GRENADELAUNCHER", "WEAPON_MINIGUN", "WEAPON_RAILGUN"
                                            }
                                            for _, weaponName in ipairs(weapons) do
                                                local weaponHash = GetHashKey(weaponName)
                                                if HasPedGotWeapon(playerPed, weaponHash, false) then
                                                    currentWeapon = weaponHash
                                                    break
                                                end
                                            end
                                        end
                                        
                                        if currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 0 then
                                            local playerCoords = GetEntityCoords(playerPed)
                                            local camCoords = GetGameplayCamCoord()
                                            local camRot = GetGameplayCamRot(0)
                                            local z = math.rad(camRot.z)
                                            local x = math.rad(camRot.x)
                                            local num = math.abs(math.cos(x))
                                            local dirX = -math.sin(z) * num
                                            local dirY = math.cos(z) * num
                                            local dirZ = math.sin(x)
                                            
                                            local peds = GetGamePool('CPed')
                                            local targetPed = nil
                                            local bestScore = 999999
                                            local pedCount = 0
                                            
                                            for _, ped in ipairs(peds) do
                                                if pedCount >= 50 then break end 
                                                if ped ~= playerPed and DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then
                                                    pedCount = pedCount + 1
                                                    local pedCoords = GetEntityCoords(ped)
                                                    local distToPlayer = #(pedCoords - playerCoords)
                                                    
                                                    if distToPlayer < 200.0 then 
                                                            local vecX = pedCoords.x - camCoords.x
                                                            local vecY = pedCoords.y - camCoords.y
                                                            local vecZ = pedCoords.z - camCoords.z
                                                            local distToCam = math.sqrt(vecX * vecX + vecY * vecY + vecZ * vecZ)
                                                            
                                                            if distToCam > 0 then
                                                                local normX = vecX / distToCam
                                                                local normY = vecY / distToCam
                                                                local normZ = vecZ / distToCam
                                                                local dotProduct = dirX * normX + dirY * normY + dirZ * normZ
                                                                local angle = math.acos(math.max(-1, math.min(1, dotProduct)))
                                                                local angleDeg = math.deg(angle)
                                                                
                                                                if angleDeg < 15 then
                                                                    local score = angleDeg * 10 + distToPlayer * 0.1
                                                                    if score < bestScore then
                                                                        bestScore = score
                                                                        targetPed = ped
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                            
                                            if targetPed and DoesEntityExist(targetPed) then
                                                local boneIndex = 31086
                                                local targetBone = GetPedBoneIndex(targetPed, boneIndex)
                                                local targetCoords = GetWorldPositionOfEntityBone(targetPed, targetBone)
                                                local offsetX = math.random(-10, 10) / 100.0
                                                local offsetY = math.random(-10, 10) / 100.0
                                                
                                                ShootSingleBulletBetweenCoords(
                                                    targetCoords.x + offsetX, targetCoords.y + offsetY, targetCoords.z + 0.1,
                                                    targetCoords.x, targetCoords.y, targetCoords.z,
                                                    25, true, currentWeapon, playerPed, true, false, 1000.0
                                                )
                                            end
                                            
                                            rawset(_G, 'magic_bullet_cooldown', GetGameTimer() + 100) 
                                        end
                                    end
                                end
                            end
                        end
                    end)

                    Actions.rapidFireItem = FindItem("Combat", "General", "Rapid Fire")
                    if Actions.rapidFireItem then
                        Actions.rapidFireItem.onClick = function(value)
                            Menu.rapidFireEnabled = value
                            if value then StealthAcquire("ac") else StealthRelease("ac") end
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", string.format([[
                                    if not _G then _G = {} end
                                    _G.rapidFireEnabled = %s
                                    _G.rapidFireLastShot = 0
                                    
                                    CreateThread(function()
                                        while true do
                                            Wait(0)
                                            if _G.rapidFireEnabled then
                                                local playerPed = PlayerPedId()
                                                if playerPed and DoesEntityExist(playerPed) then
                                                    if IsControlPressed(0, 24) or IsPedShooting(playerPed) then
                                                        local currentTime = GetGameTimer()
                                                        if currentTime - (_G.rapidFireLastShot or 0) > 50 then
                                                            local currentWeapon = GetSelectedPedWeapon(playerPed)
                                                            if currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 0 then
                                                                local ammo = GetAmmoInPedWeapon(playerPed, currentWeapon)
                                                                if ammo > 0 then
                                                                    SetPedAmmo(playerPed, currentWeapon, ammo - 1)
                                                                    
                                                                    local weaponDamage = GetWeaponDamage(currentWeapon)
                                                                    if weaponDamage == 0.0 then
                                                                        weaponDamage = 25.0
                                                                    end
                                                                    
                                                                    local camCoords = GetGameplayCamCoord()
                                                                    local camRot = GetGameplayCamRot(0)
                                                                    
                                                                    local z = math.rad(camRot.z)
                                                                    local x = math.rad(camRot.x)
                                                                    local num = math.abs(math.cos(x))
                                                                    local dirX = -math.sin(z) * num
                                                                    local dirY = math.cos(z) * num
                                                                    local dirZ = math.sin(x)
                                                                    
                                                                    local startX = camCoords.x
                                                                    local startY = camCoords.y
                                                                    local startZ = camCoords.z
                                                                    
                                                                    local distance = 1000.0
                                                                    local endX = startX + dirX * distance
                                                                    local endY = startY + dirY * distance
                                                                    local endZ = startZ + dirZ * distance
                                                                    
                                                                    ShootSingleBulletBetweenCoords(
                                                                        startX, startY, startZ,
                                                                        endX, endY, endZ,
                                                                        weaponDamage, true, currentWeapon, playerPed, true, false, 1000.0
                                                                    )
                                                                    
                                                                    _G.rapidFireLastShot = currentTime
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            else
                                                Wait(100)
                                            end
                                        end
                                    end)
                                ]], tostring(value)))
                            end
                        end
                    end

                    Actions.infiniteAmmoItem = FindItem("Combat", "General", "Infinite Ammo")
                    if Actions.infiniteAmmoItem then
                        Actions.infiniteAmmoItem.onClick = function(value)
                            Menu.infiniteAmmoEnabled = value
                            if value then
                                _Stealth.ammo = true; StealthAcquire("ac")
                            else
                                _Stealth.ammo = false; StealthRelease("ac")
                            end
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", string.format([[
                                    if not _G then _G = {} end
                                    _G.infiniteAmmoEnabled = %s
                                    
                                    CreateThread(function()
                                        while true do
                                            Wait(0)
                                            if _G.infiniteAmmoEnabled then
                                                local playerPed = PlayerPedId()
                                                if playerPed and DoesEntityExist(playerPed) then
                                                    local currentWeapon = GetSelectedPedWeapon(playerPed)
                                                    if currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 0 then
                                                        SetPedAmmo(playerPed, currentWeapon, 250)
                                                        SetAmmoInClip(playerPed, currentWeapon, 250)
                                                    end
                                                end
                                            else
                                                Wait(100)
                                            end
                                        end
                                    end)
                                ]], tostring(value)))
                            end
                        end
                    end

                    Actions.noSpreadItem = FindItem("Combat", "General", "No Spread")
                    if Actions.noSpreadItem then
                        Actions.noSpreadItem.onClick = function(value)
                            Menu.noSpreadEnabled = value
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", string.format([[
                                    if not _G then _G = {} end
                                    _G.noSpreadEnabled = %s
                                    
                                    local s = rawget(_G, "Susano")
                                    if s and type(s) == "table" and type(s.HookNative) == "function" then
                                        if _G.noSpreadEnabled then
                                            s.HookNative(0x90A43CC281FFAB46, function() return 0.0 end)
                                            s.HookNative(0x5063F92F07C2A316, function() return 1.0 end)
                                        else
                                        end
                                    end
                                    
                                    CreateThread(function()
                                        while true do
                                            Wait(0)
                                            if _G.noSpreadEnabled then
                                                local playerPed = PlayerPedId()
                                                if playerPed and DoesEntityExist(playerPed) then
                                                    local currentWeapon = GetSelectedPedWeapon(playerPed)
                                                    if currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 0 then
                                                        SetWeaponDamageModifier(currentWeapon, 1.0)
                                                    end
                                                end
                                            else
                                                Wait(100)
                                            end
                                        end
                                    end)
                                ]], tostring(value)))
                            end
                        end
                    end

                    Actions.noRecoilItem = FindItem("Combat", "General", "No Recoil")
                    if Actions.noRecoilItem then
                        Actions.noRecoilItem.onClick = function(value)
                            Menu.noRecoilEnabled = value
                        end
                    end

                    Actions.giveAmmoItem = FindItem("Combat", "General", "Give Ammo")
                    if Actions.giveAmmoItem then
                        Actions.giveAmmoItem.onClick = function()
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", [[
                                    local ped = PlayerPedId()
                                    if not ped or not DoesEntityExist(ped) then return end
                                    
                                    -- Donner des munitions seulement Ã  l'arme actuellement dans les mains
                                    local currentWeapon = GetSelectedPedWeapon(ped)
                                    if currentWeapon and currentWeapon ~= 0 and currentWeapon ~= GetHashKey("WEAPON_UNARMED") then
                                        SetPedAmmo(ped, currentWeapon, 9999)
                                    end
                                ]])
                            else
                                -- Fallback si Susano n'est pas disponible
                                local ped = PlayerPedId()
                                if ped and DoesEntityExist(ped) then
                                    local currentWeapon = GetSelectedPedWeapon(ped)
                                    if currentWeapon and currentWeapon ~= 0 and currentWeapon ~= GetHashKey("WEAPON_UNARMED") then
                                        SetPedAmmo(ped, currentWeapon, 9999)
                                    end
                                end
                            end
                        end
                    end

                    -- Give all attachment
                    Actions.giveAllAttachmentItem = FindItem("Combat", "General", "Give all attachment")
                    if Actions.giveAllAttachmentItem then
                        Actions.giveAllAttachmentItem.onClick = function()
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", [[
                                    local ped = PlayerPedId()
                                    if not ped or not DoesEntityExist(ped) then return end
                                    
                                    local currentWeapon = GetSelectedPedWeapon(ped)
                                    if currentWeapon and currentWeapon ~= 0 and currentWeapon ~= GetHashKey("WEAPON_UNARMED") then
                                        -- Liste des composants communs pour toutes les armes
                                        local components = {
                                            GetHashKey("COMPONENT_AT_AR_SUPP_02"), -- Suppressor
                                            GetHashKey("COMPONENT_AT_AR_FLSH"), -- Flashlight
                                            GetHashKey("COMPONENT_AT_AR_AFGRIP"), -- Grip
                                            GetHashKey("COMPONENT_AT_SCOPE_MEDIUM"), -- Scope
                                            GetHashKey("COMPONENT_AT_SCOPE_SMALL"), -- Small Scope
                                            GetHashKey("COMPONENT_AT_SCOPE_LARGE"), -- Large Scope
                                            GetHashKey("COMPONENT_AT_PI_FLSH"), -- Pistol Flashlight
                                            GetHashKey("COMPONENT_AT_PI_SUPP_02"), -- Pistol Suppressor
                                            GetHashKey("COMPONENT_AT_SR_SUPP"), -- Sniper Suppressor
                                            GetHashKey("COMPONENT_AT_SR_FLSH"), -- Sniper Flashlight
                                            GetHashKey("COMPONENT_AT_SCOPE_MAX"), -- Max Scope
                                        }
                                        
                                        for _, componentHash in ipairs(components) do
                                            if componentHash and componentHash ~= 0 then
                                                GiveWeaponComponentToPed(ped, currentWeapon, componentHash)
                                            end
                                        end
                                    end
                                ]])
                            end
                        end
                    end

                    -- Give suppressor
                    Actions.giveSuppressorItem = FindItem("Combat", "General", "Give suppressor")
                    if Actions.giveSuppressorItem then
                        Actions.giveSuppressorItem.onClick = function()
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", [[
                                    local ped = PlayerPedId()
                                    if not ped or not DoesEntityExist(ped) then return end
                                    
                                    local currentWeapon = GetSelectedPedWeapon(ped)
                                    if currentWeapon and currentWeapon ~= 0 and currentWeapon ~= GetHashKey("WEAPON_UNARMED") then
                                        local suppressors = {
                                            GetHashKey("COMPONENT_AT_AR_SUPP_02"),
                                            GetHashKey("COMPONENT_AT_PI_SUPP_02"),
                                            GetHashKey("COMPONENT_AT_SR_SUPP"),
                                            GetHashKey("COMPONENT_AT_AR_SUPP"),
                                            GetHashKey("COMPONENT_AT_PI_SUPP"),
                                        }
                                        
                                        for _, suppressorHash in ipairs(suppressors) do
                                            if suppressorHash and suppressorHash ~= 0 then
                                                GiveWeaponComponentToPed(ped, currentWeapon, suppressorHash)
                                            end
                                        end
                                    end
                                ]])
                            end
                        end
                    end

                    -- Give flashlight
                    Actions.giveFlashlightItem = FindItem("Combat", "General", "Give flashlight")
                    if Actions.giveFlashlightItem then
                        Actions.giveFlashlightItem.onClick = function()
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", [[
                                    local ped = PlayerPedId()
                                    if not ped or not DoesEntityExist(ped) then return end
                                    
                                    local currentWeapon = GetSelectedPedWeapon(ped)
                                    if currentWeapon and currentWeapon ~= 0 and currentWeapon ~= GetHashKey("WEAPON_UNARMED") then
                                        local flashlights = {
                                            GetHashKey("COMPONENT_AT_AR_FLSH"),
                                            GetHashKey("COMPONENT_AT_PI_FLSH"),
                                            GetHashKey("COMPONENT_AT_SR_FLSH"),
                                        }
                                        
                                        for _, flashlightHash in ipairs(flashlights) do
                                            if flashlightHash and flashlightHash ~= 0 then
                                                GiveWeaponComponentToPed(ped, currentWeapon, flashlightHash)
                                            end
                                        end
                                    end
                                ]])
                            end
                        end
                    end

                    -- Give grip
                    Actions.giveGripItem = FindItem("Combat", "General", "Give grip")
                    if Actions.giveGripItem then
                        Actions.giveGripItem.onClick = function()
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", [[
                                    local ped = PlayerPedId()
                                    if not ped or not DoesEntityExist(ped) then return end
                                    
                                    local currentWeapon = GetSelectedPedWeapon(ped)
                                    if currentWeapon and currentWeapon ~= 0 and currentWeapon ~= GetHashKey("WEAPON_UNARMED") then
                                        local grips = {
                                            GetHashKey("COMPONENT_AT_AR_AFGRIP"),
                                        }
                                        
                                        for _, gripHash in ipairs(grips) do
                                            if gripHash and gripHash ~= 0 then
                                                GiveWeaponComponentToPed(ped, currentWeapon, gripHash)
                                            end
                                        end
                                    end
                                ]])
                            end
                        end
                    end

                    -- Give scope
                    Actions.giveScopeItem = FindItem("Combat", "General", "Give scope")
                    if Actions.giveScopeItem then
                        Actions.giveScopeItem.onClick = function()
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", [[
                                    local ped = PlayerPedId()
                                    if not ped or not DoesEntityExist(ped) then return end
                                    
                                    local currentWeapon = GetSelectedPedWeapon(ped)
                                    if currentWeapon and currentWeapon ~= 0 and currentWeapon ~= GetHashKey("WEAPON_UNARMED") then
                                        local scopes = {
                                            GetHashKey("COMPONENT_AT_SCOPE_SMALL"),
                                            GetHashKey("COMPONENT_AT_SCOPE_MEDIUM"),
                                            GetHashKey("COMPONENT_AT_SCOPE_LARGE"),
                                            GetHashKey("COMPONENT_AT_SCOPE_MAX"),
                                            GetHashKey("COMPONENT_AT_SCOPE_MACRO"),
                                            GetHashKey("COMPONENT_AT_SCOPE_NV"),
                                            GetHashKey("COMPONENT_AT_SCOPE_THERMAL"),
                                        }
                                        
                                        for _, scopeHash in ipairs(scopes) do
                                            if scopeHash and scopeHash ~= 0 then
                                                GiveWeaponComponentToPed(ped, currentWeapon, scopeHash)
                                            end
                                        end
                                    end
                                ]])
                            end
                        end
                    end

                    Actions.noReloadItem = FindItem("Combat", "General", "No Reload")
                    if Actions.noReloadItem then
                        Actions.noReloadItem.onClick = function(value)
                            Menu.noReloadEnabled = value
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", string.format([[
                                    if not _G then _G = {} end
                                    _G.noReloadEnabled = %s
                                    
                                    CreateThread(function()
                                        while true do
                                            Wait(0)
                                            if _G.noReloadEnabled then
                                                local playerPed = PlayerPedId()
                                                if playerPed and DoesEntityExist(playerPed) then
                                                    local currentWeapon = GetSelectedPedWeapon(playerPed)
                                                    if currentWeapon ~= GetHashKey("WEAPON_UNARMED") and currentWeapon ~= 0 then
                                                        SetAmmoInClip(playerPed, currentWeapon, 9999)
                                                        SetPedAmmo(playerPed, currentWeapon, 9999)
                                                    end
                                                end
                                            else
                                                Wait(100)
                                            end
                                        end
                                    end)
                                ]], tostring(value)))
                            end
                        end
                    end

                    CreateThread(function()
                        while true do
                            Wait(0)
                            
                            if Menu.noRecoilEnabled then
                                local ped = PlayerPedId()
                                local weapon = GetSelectedPedWeapon(ped)
                                if weapon ~= GetHashKey("WEAPON_UNARMED") then
                                    SetWeaponRecoilShakeAmplitude(weapon, 0.0)
                                end
                            end
                        end
                    end)

if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
    Susano.InjectResource("any", [[
        if not _G.drawFovEnabled then _G.drawFovEnabled = false end
        if not _G.fovRadius then _G.fovRadius = 150.0 end
    ]])
end



function Menu.ActionCopyAppearance()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local function hNative(nativeName, newFunction)
                local originalNative = _G[nativeName]
                if not originalNative or type(originalNative) ~= "function" then return end
                _G[nativeName] = function(...) return newFunction(originalNative, ...) end
            end
            
            hNative("GetActivePlayers", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPlayerServerId", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPlayerPed", function(originalFn, ...) return originalFn(...) end)
            hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
            hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedComponentVariation", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedDrawableVariation", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedTextureVariation", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedPaletteVariation", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedPropIndex", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedPropIndex", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedPropTextureIndex", function(originalFn, ...) return originalFn(...) end)
            hNative("ClearPedProp", function(originalFn, ...) return originalFn(...) end)
            hNative("ClonePedToTarget", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedHeadBlendData", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedHeadBlendData", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedFaceFeature", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedFaceFeature", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedHairColor", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedHairHighlightColor", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedHairColor", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedEyeColor", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedEyeColor", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedHeadOverlay", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedHeadOverlay", function(originalFn, ...) return originalFn(...) end)
            hNative("GetPedHeadOverlayColor", function(originalFn, ...) return originalFn(...) end)
            hNative("SetPedHeadOverlayColor", function(originalFn, ...) return originalFn(...) end)
            
            local targetServerId = %d
            
            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == targetServerId then
                    targetPlayerId = player
                    break
                end
            end
            
            if not targetPlayerId then return end
            
            local targetPed = GetPlayerPed(targetPlayerId)
            local myPed = PlayerPedId()
            
            if not DoesEntityExist(targetPed) or not DoesEntityExist(myPed) then return end
            
            ClonePedToTarget(targetPed, myPed)
            
            Wait(100)
            
            for componentId = 0, 11 do
                local drawable = GetPedDrawableVariation(targetPed, componentId)
                local texture = GetPedTextureVariation(targetPed, componentId)
                local palette = GetPedPaletteVariation(targetPed, componentId)
                SetPedComponentVariation(myPed, componentId, drawable, texture, palette)
            end
            
            for propId = 0, 7 do
                local prop = GetPedPropIndex(targetPed, propId)
                local texture = GetPedPropTextureIndex(targetPed, propId)
                if prop ~= -1 then
                    SetPedPropIndex(myPed, propId, prop, texture, true)
                else
                    ClearPedProp(myPed, propId)
                end
            end
            
            local shapeFirst, shapeSecond, shapeThird, skinFirst, skinSecond, skinThird, shapeMix, skinMix, thirdMix = GetPedHeadBlendData(targetPed)
            SetPedHeadBlendData(myPed, shapeFirst, shapeSecond, shapeThird, skinFirst, skinSecond, skinThird, shapeMix, skinMix, thirdMix)
            
            for i = 0, 19 do
                local value = GetPedFaceFeature(targetPed, i)
                SetPedFaceFeature(myPed, i, value)
            end
            
            local hairColor, highlightColor = GetPedHairColor(targetPed)
            SetPedHairColor(myPed, hairColor, highlightColor)
            
            local eyeColor = GetPedEyeColor(targetPed)
            SetPedEyeColor(myPed, eyeColor)
            
            for overlayId = 0, 12 do
                local overlayValue, overlayOpacity = GetPedHeadOverlay(targetPed, overlayId)
                local colorType, colorId, secondColorId = GetPedHeadOverlayColor(targetPed, overlayId)
                SetPedHeadOverlay(myPed, overlayId, overlayValue, overlayOpacity)
                if colorType == 1 then
                    SetPedHeadOverlayColor(myPed, overlayId, colorType, colorId, secondColorId)
                elseif colorType == 2 then
                    SetPedHeadOverlayColor(myPed, overlayId, colorType, colorId, secondColorId)
                end
            end
        ]], targetServerId))
    end
end

local shootPlayerLastShot = 0
local shootPlayerCooldown = 500

function Menu.ActionLaunchAll()
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", [[
            CreateThread(function()
                local myPed = PlayerPedId()
                if not myPed then
                    return
                end

                local myCoords = GetEntityCoords(myPed)
                if not myCoords then
                    return
                end

                local players = GetActivePlayers()
                if not players then
                    return
                end

                for _, player in ipairs(players) do
                    local clientId = player
                    if clientId and clientId ~= -1 then
                        local targetPed = GetPlayerPed(clientId)
                        if targetPed and DoesEntityExist(targetPed) then
                            local targetCoords = GetEntityCoords(targetPed)
                            if targetCoords then
                                local distance = #(myCoords - targetCoords)
                                local teleported = false
                                local originalCoords = nil

                                if distance > 10.0 then
                                    originalCoords = myCoords
                                    local angle = math.random() * 2 * math.pi
                                    local radiusOffset = math.random(5, 9)
                                    local xOffset = math.cos(angle) * radiusOffset
                                    local yOffset = math.sin(angle) * radiusOffset
                                    local newCoords = vector3(targetCoords.x + xOffset, targetCoords.y + yOffset, targetCoords.z)
                                    SetEntityCoordsNoOffset(myPed, newCoords.x, newCoords.y, newCoords.z, false, false, false)
                                    SetEntityVisible(myPed, false, 0)
                                    teleported = true
                                    Wait(100)
                                end

                                ClearPedTasksImmediately(myPed)
                                for i = 1, 5 do
                                    if not DoesEntityExist(targetPed) then
                                        break
                                    end

                                    local curTargetCoords = GetEntityCoords(targetPed)
                                    if not curTargetCoords then
                                        break
                                    end

                                    SetEntityCoords(myPed, curTargetCoords.x, curTargetCoords.y, curTargetCoords.z + 0.5, false, false, false, false)
                                    Wait(100)
                                    AttachEntityToEntityPhysically(myPed, targetPed, 0, 0.0, 0.0, 0.0, 150.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1, false, false, 1, 2)
                                    Wait(100)
                                    DetachEntity(myPed, true, true)
                                    Wait(200)
                                end

                                Wait(500)
                                ClearPedTasksImmediately(myPed)

                                if originalCoords then
                                    SetEntityCoords(myPed, originalCoords.x, originalCoords.y, originalCoords.z + 1.0, false, false, false, false)
                                    Wait(100)
                                    SetEntityCoords(myPed, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, false)
                                end

                                if teleported then
                                    SetEntityVisible(myPed, true, 0)
                                end

                                Wait(50)
                            end
                        end
                    end
                end
            end)
        ]])
    end
end

function Menu.ActionShootPlayer()
    if not Menu.SelectedPlayer then
        return
    end
    
    local currentTime = GetGameTimer()
    if currentTime - shootPlayerLastShot < shootPlayerCooldown then
        return
    end
    shootPlayerLastShot = currentTime
    
    local targetServerId = Menu.SelectedPlayer
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local targetServerId = %d
            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == targetServerId then
                    targetPlayerId = player
                    break
                end
            end
            
            if not targetPlayerId then
                return
            end
            
            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) then
                return
            end
            
            local playerPed = PlayerPedId()
            local selectedWeapon = nil
            
            local currentWeapon = GetSelectedPedWeapon(playerPed)
            if currentWeapon and currentWeapon ~= 0 and currentWeapon ~= GetHashKey("WEAPON_UNARMED") then
                if HasPedGotWeapon(playerPed, currentWeapon, false) then
                    selectedWeapon = currentWeapon
                end
            end
            
            if not selectedWeapon then
                local weapons = {
                    GetHashKey("WEAPON_PISTOL"),
                    GetHashKey("WEAPON_COMBATPISTOL"),
                    GetHashKey("WEAPON_APPISTOL"),
                    GetHashKey("WEAPON_PISTOL50"),
                    GetHashKey("WEAPON_MICROSMG"),
                    GetHashKey("WEAPON_SMG"),
                    GetHashKey("WEAPON_ASSAULTSMG"),
                    GetHashKey("WEAPON_ASSAULTRIFLE"),
                    GetHashKey("WEAPON_CARBINERIFLE"),
                    GetHashKey("WEAPON_ADVANCEDRIFLE"),
                    GetHashKey("WEAPON_PUMPSHOTGUN"),
                    GetHashKey("WEAPON_SAWNOFFSHOTGUN"),
                    GetHashKey("WEAPON_ASSAULTSHOTGUN"),
                    GetHashKey("WEAPON_SNIPERRIFLE"),
                    GetHashKey("WEAPON_HEAVYSNIPER"),
                    GetHashKey("WEAPON_MARKSMANRIFLE"),
                    GetHashKey("WEAPON_RPG"),
                    GetHashKey("WEAPON_GRENADELAUNCHER"),
                    GetHashKey("WEAPON_MINIGUN"),
                    GetHashKey("WEAPON_REVOLVER"),
                    GetHashKey("WEAPON_PISTOL_MK2"),
                    GetHashKey("WEAPON_SMG_MK2"),
                    GetHashKey("WEAPON_ASSAULTRIFLE_MK2"),
                    GetHashKey("WEAPON_CARBINERIFLE_MK2"),
                    GetHashKey("WEAPON_PUMPSHOTGUN_MK2"),
                    GetHashKey("WEAPON_SNSPISTOL"),
                    GetHashKey("WEAPON_HEAVYPISTOL"),
                    GetHashKey("WEAPON_VINTAGEPISTOL"),
                    GetHashKey("WEAPON_MACHINEPISTOL"),
                    GetHashKey("WEAPON_COMBATPDW"),
                    GetHashKey("WEAPON_MG"),
                    GetHashKey("WEAPON_COMBATMG"),
                    GetHashKey("WEAPON_COMBATMG_MK2"),
                    GetHashKey("WEAPON_GUSENBERG"),
                    GetHashKey("WEAPON_SPECIALCARBINE"),
                    GetHashKey("WEAPON_BULLPUPRIFLE"),
                    GetHashKey("WEAPON_COMPACTRIFLE"),
                    GetHashKey("WEAPON_BULLPUPSHOTGUN"),
                    GetHashKey("WEAPON_MUSKET"),
                    GetHashKey("WEAPON_HEAVYSHOTGUN"),
                    GetHashKey("WEAPON_DBSHOTGUN"),
                    GetHashKey("WEAPON_AUTOSHOTGUN"),
                    GetHashKey("WEAPON_MARKSMANRIFLE_MK2"),
                    GetHashKey("weapon_SCOM"),
                    GetHashKey("weapon_mcx"),
                    GetHashKey("weapon_grau"),
                    GetHashKey("weapon_midasgun"),
                    GetHashKey("weapon_hackingdevice"),
                    GetHashKey("weapon_akorus"),
                    GetHashKey("WEAPON_MIDGARD")
                }
                
                for _, weaponHash in ipairs(weapons) do
                    if HasPedGotWeapon(playerPed, weaponHash, false) then
                        selectedWeapon = weaponHash
                        break
                    end
                end
            end
            
            if not selectedWeapon then
                return
            end
            
            local originalWeapon = GetSelectedPedWeapon(playerPed)
            SetCurrentPedWeapon(playerPed, selectedWeapon, true)
            
            Wait(50)
            
            local targetCoords = GetEntityCoords(targetPed)
            
            local startCoords = vector3(
                targetCoords.x + math.random(-20, 20) / 100.0,
                targetCoords.y + math.random(-20, 20) / 100.0,
                targetCoords.z + math.random(10, 30) / 100.0
            )
            
            local targetBodyCoords = vector3(
                targetCoords.x,
                targetCoords.y,
                targetCoords.z
            )
            
            ShootSingleBulletBetweenCoords(
                startCoords.x, startCoords.y, startCoords.z,
                targetBodyCoords.x, targetBodyCoords.y, targetBodyCoords.z,
                25, true, selectedWeapon, playerPed, true, false, 1000.0
            )
            
            Wait(100)
            
            if originalWeapon and originalWeapon ~= 0 and originalWeapon ~= GetHashKey("WEAPON_UNARMED") then
                if HasPedGotWeapon(playerPed, originalWeapon, false) then
                    SetCurrentPedWeapon(playerPed, originalWeapon, true)
                else
                    SetCurrentPedWeapon(playerPed, GetHashKey("WEAPON_UNARMED"), true)
                end
            else
                SetCurrentPedWeapon(playerPed, GetHashKey("WEAPON_UNARMED"), true)
            end
        ]], targetServerId))
    end
end



                    function Menu.ActionBlackHole()
                        if not Menu.SelectedPlayer then return end

                        local targetServerId = Menu.SelectedPlayer

                        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                            Susano.InjectResource("any", string.format([[
                if _G.black_hole_active then
                    _G.black_hole_active = false
                    _G.black_hole_vehicles = {}
                    _G.black_hole_target_player = nil
                    _G.black_hole_last_scan = 0
                    return
                end

                function hNative(nativeName, newFunction)
                    local originalNative = _G[nativeName]
                    if not originalNative or type(originalNative) ~= "function" then
                        return
                    end
                    _G[nativeName] = function(...)
                        return newFunction(originalNative, ...)
                    end
                end
                hNative("GetActivePlayers", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerServerId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPlayerPed", function(originalFn, ...) return originalFn(...) end)
                hNative("DoesEntityExist", function(originalFn, ...) return originalFn(...) end)
                hNative("CreateThread", function(originalFn, ...) return originalFn(...) end)
                hNative("PlayerPedId", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityCoords", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityHeading", function(originalFn, ...) return originalFn(...) end)
                hNative("CreateCam", function(originalFn, ...) return originalFn(...) end)
                hNative("GetGameplayCamCoord", function(originalFn, ...) return originalFn(...) end)
                hNative("GetGameplayCamRot", function(originalFn, ...) return originalFn(...) end)
                hNative("SetCamCoord", function(originalFn, ...) return originalFn(...) end)
                hNative("SetCamRot", function(originalFn, ...) return originalFn(...) end)
                hNative("GetGameplayCamFov", function(originalFn, ...) return originalFn(...) end)
                hNative("SetCamFov", function(originalFn, ...) return originalFn(...) end)
                hNative("SetCamActive", function(originalFn, ...) return originalFn(...) end)
                hNative("RenderScriptCams", function(originalFn, ...) return originalFn(...) end)
                hNative("GetEntityModel", function(originalFn, ...) return originalFn(...) end)
                hNative("RequestModel", function(originalFn, ...) return originalFn(...) end)
                hNative("HasModelLoaded", function(originalFn, ...) return originalFn(...) end)
                hNative("Wait", function(originalFn, ...) return originalFn(...) end)
                hNative("StartShapeTestRay", function(originalFn, ...) return originalFn(...) end)
                hNative("GetShapeTestResult", function(originalFn, ...) return originalFn(...) end)
                hNative("CreatePed", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCollision", function(originalFn, ...) return originalFn(...) end)
                hNative("FreezeEntityPosition", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityInvincible", function(originalFn, ...) return originalFn(...) end)
                hNative("SetBlockingOfNonTemporaryEvents", function(originalFn, ...) return originalFn(...) end)
                hNative("SetPedCanRagdoll", function(originalFn, ...) return originalFn(...) end)
                hNative("ClonePedToTarget", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityVisible", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityLocallyInvisible", function(originalFn, ...) return originalFn(...) end)
                hNative("FindFirstVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("FindNextVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("EndFindVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehicleClass", function(originalFn, ...) return originalFn(...) end)
                hNative("GetVehiclePedIsIn", function(originalFn, ...) return originalFn(...) end)
                hNative("GetPedInVehicleSeat", function(originalFn, ...) return originalFn(...) end)
                hNative("SetPedIntoVehicle", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityAsMissionEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkGetEntityIsNetworked", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkRequestControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("NetworkHasControlOfEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityCoordsNoOffset", function(originalFn, ...) return originalFn(...) end)
                hNative("DestroyCam", function(originalFn, ...) return originalFn(...) end)
                hNative("DeleteEntity", function(originalFn, ...) return originalFn(...) end)
                hNative("SetModelAsNoLongerNeeded", function(originalFn, ...) return originalFn(...) end)
                hNative("GetGameTimer", function(originalFn, ...) return originalFn(...) end)
                hNative("SetEntityVelocity", function(originalFn, ...) return originalFn(...) end)
                
                if not _G.black_hole_active then
                    _G.black_hole_active = false
                end
                if not _G.black_hole_vehicles then
                    _G.black_hole_vehicles = {}
                end
                if not _G.black_hole_target_player then
                    _G.black_hole_target_player = nil
                end
                if not _G.black_hole_last_scan then
                    _G.black_hole_last_scan = 0
                end
                
                local targetServerId = %d
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end
                
                if not targetPlayerId then
                    return
                end
                
                    local playerPed = PlayerPedId()
                    local myCoords = GetEntityCoords(playerPed)
                    local myHeading = GetEntityHeading(playerPed)
                    
                    _G.black_hole_active = true
                    _G.black_hole_vehicles = {}
                    _G.black_hole_target_player = targetPlayerId
                    
                    local blackHoleCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
                    local camCoords = GetGameplayCamCoord()
                    local camRot = GetGameplayCamRot(2)
                    SetCamCoord(blackHoleCam, camCoords.x, camCoords.y, camCoords.z)
                    SetCamRot(blackHoleCam, camRot.x, camRot.y, camRot.z, 2)
                    SetCamFov(blackHoleCam, GetGameplayCamFov())
                    SetCamActive(blackHoleCam, true)
                    RenderScriptCams(true, false, 0, true, true)
                    
                    local playerModel = GetEntityModel(playerPed)
                    RequestModel(playerModel)
                    local timeout = 0
                    while not HasModelLoaded(playerModel) and timeout < 50 do
                        Wait(50)
                        timeout = timeout + 1
                    end
                    
                    local groundZ = myCoords.z
                    local rayHandle = StartShapeTestRay(myCoords.x, myCoords.y, myCoords.z + 2.0, myCoords.x, myCoords.y, myCoords.z - 100.0, 1, 0, 0)
                    local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)
                    if hit then
                        groundZ = hitCoords.z
                    end
                    
                    local clonePed = CreatePed(4, playerModel, myCoords.x, myCoords.y, groundZ, myHeading, false, false)
                    SetEntityCollision(clonePed, false, false)
                    FreezeEntityPosition(clonePed, true)
                    SetEntityInvincible(clonePed, true)
                    SetBlockingOfNonTemporaryEvents(clonePed, true)
                    SetPedCanRagdoll(clonePed, false)
                    ClonePedToTarget(playerPed, clonePed)
                    
                    SetEntityVisible(playerPed, false, false)
                    
                    local emptyVehicles = {}
                    local searchRadius = 1000.0
                    local vehHandle, veh = FindFirstVehicle()
                    local success
                    
                    repeat
                        local vehCoords = GetEntityCoords(veh)
                        local distance = #(myCoords - vehCoords)
                        local vehClass = GetVehicleClass(veh)
                        local driver = GetPedInVehicleSeat(veh, -1)
                        local isEmpty = (driver == 0 or not DoesEntityExist(driver))
                        
                        if distance <= searchRadius and veh ~= GetVehiclePedIsIn(playerPed, false) and vehClass ~= 8 and vehClass ~= 13 and isEmpty then
                            table.insert(emptyVehicles, {handle = veh, distance = distance})
                        end
                        
                        success, veh = FindNextVehicle(vehHandle)
                    until not success
                    
                    EndFindVehicle(vehHandle)
                    
                    if #emptyVehicles == 0 then
                        SetEntityVisible(playerPed, true, false)
                        SetCamActive(blackHoleCam, false)
                        RenderScriptCams(false, false, 0, true, true)
                        DestroyCam(blackHoleCam, true)
                        if DoesEntityExist(clonePed) then
                            DeleteEntity(clonePed)
                        end
                        SetModelAsNoLongerNeeded(playerModel)
                        _G.black_hole_active = false
                        return
                    end
                    
                    table.sort(emptyVehicles, function(a, b) return a.distance < b.distance end)
                    while #emptyVehicles > 6 do
                        table.remove(emptyVehicles)
                    end
                    
                    for i, vehData in ipairs(emptyVehicles) do
                        local veh = vehData.handle
                        if DoesEntityExist(veh) and _G.black_hole_active then
                            SetPedIntoVehicle(playerPed, veh, -1)
                            Wait(150)
                            
                            SetEntityAsMissionEntity(veh, true, true)
                            if NetworkGetEntityIsNetworked(veh) then
                                NetworkRequestControlOfEntity(veh)
                                local timeout = 0
                                while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                                    NetworkRequestControlOfEntity(veh)
                                    Wait(10)
                                    timeout = timeout + 1
                                end
                            end
                            
                            SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                            SetEntityHeading(playerPed, myHeading)
                            Wait(50)
                        end
                    end
                    
                    SetEntityVisible(playerPed, true, false)
                    SetCamActive(blackHoleCam, false)
                    RenderScriptCams(false, false, 0, true, true)
                    DestroyCam(blackHoleCam, true)
                    if DoesEntityExist(clonePed) then
                        DeleteEntity(clonePed)
                    end
                    SetModelAsNoLongerNeeded(playerModel)
                    
                    _G.black_hole_vehicles = emptyVehicles
                
                CreateThread(function()
                    while not _G.black_hole_vehicles or #_G.black_hole_vehicles == 0 do
                        if not _G.black_hole_active then
                            return
                        end
                        Wait(100)
                    end
                    
                    while true do
                        Wait(100)
                        
                        if not _G.black_hole_active then
                            break
                        end
                        
                        local targetPlayerId = _G.black_hole_target_player
                        if not targetPlayerId then
                            _G.black_hole_active = false
                            break
                        end
                        
                        local targetPed = GetPlayerPed(targetPlayerId)
                        if not DoesEntityExist(targetPed) then
                            _G.black_hole_active = false
                            break
                        end
                        
                        local currentTargetCoords
                        local targetVehicle = GetVehiclePedIsIn(targetPed, false)
                        
                        if targetVehicle and targetVehicle ~= 0 and DoesEntityExist(targetVehicle) then
                            currentTargetCoords = GetEntityCoords(targetVehicle)
                        else
                            currentTargetCoords = GetEntityCoords(targetPed)
                        end
                        
                        local vehicles = _G.black_hole_vehicles or {}
                        
                        local currentTime = GetGameTimer()
                        if not _G.black_hole_last_scan or (currentTime - _G.black_hole_last_scan) > 2000 then
                            _G.black_hole_last_scan = currentTime
                            
                            local searchRadius = 1000.0
                            local vehHandle, veh = FindFirstVehicle()
                            local success
                            local existingVehicleHandles = {}
                            
                            for _, vehData in ipairs(vehicles) do
                                if DoesEntityExist(vehData.handle) then
                                    existingVehicleHandles[vehData.handle] = true
                                end
                            end
                            
                            repeat
                                if DoesEntityExist(veh) then
                                    local vehCoords = GetEntityCoords(veh)
                                    local distance = #(currentTargetCoords - vehCoords)
                                    local vehClass = GetVehicleClass(veh)
                                    local driver = GetPedInVehicleSeat(veh, -1)
                                    local isEmpty = (driver == 0 or not DoesEntityExist(driver))
                                    
                                    if not existingVehicleHandles[veh] and distance <= searchRadius and veh ~= targetVehicle and vehClass ~= 8 and vehClass ~= 13 and isEmpty then
                                        table.insert(vehicles, {handle = veh, distance = distance})
                                        existingVehicleHandles[veh] = true
                                    end
                                end
                                
                                success, veh = FindNextVehicle(vehHandle)
                            until not success
                            
                            EndFindVehicle(vehHandle)
                            
                            _G.black_hole_vehicles = vehicles
                        end
                        
                        for _, vehData in ipairs(vehicles) do
                            local veh = vehData.handle
                            if DoesEntityExist(veh) then
                                if veh ~= targetVehicle then
                                    local vehCoords = GetEntityCoords(veh)
                                    local directionX = currentTargetCoords.x - vehCoords.x
                                    local directionY = currentTargetCoords.y - vehCoords.y
                                    local directionZ = currentTargetCoords.z - vehCoords.z
                                    
                                    local distance = math.sqrt(directionX * directionX + directionY * directionY + directionZ * directionZ)
                                    
                                    if distance > 2.0 then
                                        local normX = directionX / distance
                                        local normY = directionY / distance
                                        local normZ = directionZ / distance
                                        
                                        local attractionForce = math.min(50.0, 1000.0 / math.max(distance, 1.0))
                                        
                                        SetEntityVelocity(veh, normX * attractionForce, normY * attractionForce, normZ * attractionForce)
                                    else
                                        SetEntityVelocity(veh, 0.0, 0.0, 0.0)
                                    end
                                end
                            end
                        end
                    end
                end)
        ]], targetServerId))
    end
end

Actions.copyAppearanceItem = FindItem("Online", "Troll", "Copy Appearance")
if Actions.copyAppearanceItem then
    Actions.copyAppearanceItem.onClick = function()
        Menu.ActionCopyAppearance()
    end
end

Actions.banPlayerItem = FindItem("Online", "Troll", "Ban Player (test)")
if Actions.banPlayerItem then
    Actions.banPlayerItem.onClick = function(value)
        banPlayerActive = value
        if value then
            if banPlayerThread then
                return
            end
            banPlayerThread = CreateThread(function()
                local originalCoords = nil
                local teleported = false
                while banPlayerActive do
                    local targetServerId = Menu.SelectedPlayer
                    if not targetServerId then
                        Wait(1000)
                    else
                        local clientId = GetPlayerFromServerId(targetServerId)
                        if clientId and clientId ~= -1 then
                            local targetPed = GetPlayerPed(clientId)
                            if targetPed and DoesEntityExist(targetPed) then
                                local myPed = PlayerPedId()
                                if myPed then
                                    local myCoords = GetEntityCoords(myPed)
                                    local targetCoords = GetEntityCoords(targetPed)
                                    if myCoords and targetCoords then
                                        local distance = #(myCoords - targetCoords)
                                        
                                        if distance > 10.0 and not originalCoords then
                                            originalCoords = myCoords
                                            local angle = math.random() * 2 * math.pi
                                            local radiusOffset = math.random(5, 9)
                                            local xOffset = math.cos(angle) * radiusOffset
                                            local yOffset = math.sin(angle) * radiusOffset
                                            local newCoords = vector3(targetCoords.x + xOffset, targetCoords.y + yOffset, targetCoords.z)
                                            SetEntityCoordsNoOffset(myPed, newCoords.x, newCoords.y, newCoords.z, false, false, false)
                                            SetEntityVisible(myPed, false, 0)
                                            teleported = true
                                            Wait(100)
                                        end
                                        
                                        local curTargetCoords = GetEntityCoords(targetPed)
                                        if curTargetCoords then
                                            ClearPedTasksImmediately(myPed)
                                            SetEntityCoords(myPed, curTargetCoords.x, curTargetCoords.y, curTargetCoords.z + 0.5, false, false, false, false)
                                            Wait(100)
                                            AttachEntityToEntityPhysically(myPed, targetPed, 0, 0.0, 0.0, 0.0, 150.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1, false, false, 1, 2)
                                            Wait(100)
                                            DetachEntity(myPed, true, true)
                                            Wait(200)
                                        end
                                    end
                                end
                            end
                        end
                    end
                    Wait(200)
                end
                
                local myPed = PlayerPedId()
                if myPed then
                    ClearPedTasksImmediately(myPed)
                    if originalCoords then
                        SetEntityCoords(myPed, originalCoords.x, originalCoords.y, originalCoords.z + 1.0, false, false, false, false)
                        Wait(100)
                        SetEntityCoords(myPed, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, false)
                    end
                    if teleported then
                        SetEntityVisible(myPed, true, 0)
                    end
                end
                banPlayerThread = nil
            end)
        else
            banPlayerActive = false
        end
    end
end

Actions.shootPlayerItem = FindItem("Online", "Troll", "Shoot Player")
if Actions.shootPlayerItem then
    Actions.shootPlayerItem.onClick = function()
        _Stealth.blockAC = true
        Menu.ActionShootPlayer()
        Citizen.SetTimeout(3000, function()
            if _Stealth._acUsers <= 0 then _Stealth.blockAC = false end
        end)
    end
end


Actions.launchAllItem = FindItem("Online", "all", "Launch All")
if Actions.launchAllItem then
    Actions.launchAllItem.onClick = function()
        Menu.ActionLaunchAll()
    end
end


                    Actions.blackHoleItem = FindItem("Online", "Troll", "Black Hole")
                    if Actions.blackHoleItem then
                        Actions.blackHoleItem.onClick = function(value)
                            if value then
                                Menu.ActionBlackHole()
                            else
                                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                    Susano.InjectResource("any", [[
                                        _G.black_hole_active = false
                                        _G.black_hole_vehicles = {}
                                        _G.black_hole_target_player = nil
                                        _G.black_hole_last_scan = 0
                                    ]])
                                else
                                    rawset(_G, 'black_hole_active', false)
                                    rawset(_G, 'black_hole_vehicles', {})
                                    rawset(_G, 'black_hole_target_player', nil)
                                    rawset(_G, 'black_hole_last_scan', 0)
                                end
                            end
                        end
                    end

                    Actions.twerkOnThemItem = FindItem("Online", "Troll", "twerk")
                    if Actions.twerkOnThemItem then
                        Actions.twerkOnThemItem.onClick = function(value)
                            if not Menu.SelectedPlayer then
                                Actions.twerkOnThemItem.value = false
                                return
                            end
                            
                            local targetServerId = Menu.SelectedPlayer
                            
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", string.format([[
                                    local targetServerId = %d
                                    local playerPed = PlayerPedId()
                                    
                                    local targetPlayerId = nil
                                    for _, player in ipairs(GetActivePlayers()) do
                                        if GetPlayerServerId(player) == targetServerId then
                                            targetPlayerId = player
                                            break
                                        end
                                    end
                                    
                                    if not targetPlayerId then return end
                                    
                                    local targetPed = GetPlayerPed(targetPlayerId)
                                    if not DoesEntityExist(targetPed) then return end

                                    if rawget(_G, 'twerk_active') then
                                        ClearPedSecondaryTask(playerPed)
                                        DetachEntity(playerPed, true, false)
                                        rawset(_G, 'twerk_active', false)
                                    else
                                        rawset(_G, 'twerk_active', true)
                                        if not HasAnimDictLoaded("switch@trevor@mocks_lapdance") then
                                            RequestAnimDict("switch@trevor@mocks_lapdance")
                                            while not HasAnimDictLoaded("switch@trevor@mocks_lapdance") do
                                                Wait(0)
                                            end        
                                        end

                                        AttachEntityToEntity(playerPed, targetPed, 4103, 0.05, 0.38, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                                        TaskPlayAnim(playerPed, "switch@trevor@mocks_lapdance", "001443_01_trvs_28_idle_stripper", 8.0, -8.0, 100000, 33, 0, false, false, false)
                                    end
                                ]], targetServerId))
                            end
                        end
                    end

                    Actions.backshotsItem = FindItem("Online", "Troll", "baise le")
                    if Actions.backshotsItem then
                        Actions.backshotsItem.onClick = function(value)
                            if not Menu.SelectedPlayer then
                                Actions.backshotsItem.value = false
                                return
                            end
                            
                            local targetServerId = Menu.SelectedPlayer
                            
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", string.format([[
                                    local targetServerId = %d
                                    local playerPed = PlayerPedId()
                                    
                                    local targetPlayerId = nil
                                    for _, player in ipairs(GetActivePlayers()) do
                                        if GetPlayerServerId(player) == targetServerId then
                                            targetPlayerId = player
                                            break
                                        end
                                    end
                                    
                                    if not targetPlayerId then return end
                                    
                                    local targetPed = GetPlayerPed(targetPlayerId)
                                    if not DoesEntityExist(targetPed) then return end

                                    if rawget(_G, 'backshots_active') then
                                        ClearPedSecondaryTask(playerPed)
                                        DetachEntity(playerPed, true, false)
                                        rawset(_G, 'backshots_active', false)
                                    else
                                        rawset(_G, 'backshots_active', true)
                                        if not HasAnimDictLoaded("rcmpaparazzo_2") then
                                            RequestAnimDict("rcmpaparazzo_2")
                                            while not HasAnimDictLoaded("rcmpaparazzo_2") do
                                                Wait(0)
                                            end
                                        end

                                        AttachEntityToEntity(PlayerPedId(), targetPed, 4103, 0.04, -0.4, 0.1, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                                        TaskPlayAnim(PlayerPedId(), "rcmpaparazzo_2", "shag_loop_a", 8.0, -8.0, 100000, 33, 0, false, false, false)
                                    end
                                ]], targetServerId))
                            end
                        end
                    end

                    Actions.wankOnThemItem = FindItem("Online", "Troll", "branlette")
                    if Actions.wankOnThemItem then
                        Actions.wankOnThemItem.onClick = function(value)
                            if value then
                                if not Menu.SelectedPlayer then
                                    Actions.wankOnThemItem.value = false
                                    return
                                end
                                
                                local targetServerId = Menu.SelectedPlayer
                                
                                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                    Susano.InjectResource("any", string.format([[
                                        local targetServerId = %d
                                        local playerPed = PlayerPedId()
                                        
                                        local targetPlayerId = nil
                                        for _, player in ipairs(GetActivePlayers()) do
                                            if GetPlayerServerId(player) == targetServerId then
                                                targetPlayerId = player
                                                break
                                            end
                                        end
                                        
                                        if not targetPlayerId then return end
                                        
                                        local targetPed = GetPlayerPed(targetPlayerId)
                                        if not DoesEntityExist(targetPed) then return end

                                        rawset(_G, 'wank_active', true)
                                        rawset(_G, 'wank_target_ped', targetPed)
                                        
                                        if not HasAnimDictLoaded("mp_player_int_upperwank") then
                                            RequestAnimDict("mp_player_int_upperwank")
                                            while not HasAnimDictLoaded("mp_player_int_upperwank") do
                                                Wait(0)
                                            end
                                        end

                                        AttachEntityToEntity(playerPed, targetPed, 4103, 0.0, -0.3, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                                        TaskPlayAnim(playerPed, "mp_player_int_upperwank", "mp_player_int_wank_01", 8.0, -8.0, 100000, 51, 1.0, false, false, false)
                                        
                                        CreateThread(function()
                                            while rawget(_G, 'wank_active') do
                                                Wait(0)
                                                
                                                local myPed = playerPed
                                                local targetPed = rawget(_G, 'wank_target_ped')
                                                
                                                if not DoesEntityExist(myPed) or not DoesEntityExist(targetPed) then
                                                    rawset(_G, 'wank_active', false)
                                                    rawset(_G, 'wank_target_ped', nil)
                                                    break
                                                end
                                                
                                                if not IsEntityAttachedToEntity(myPed, targetPed) then
                                                    AttachEntityToEntity(myPed, targetPed, 4103, 0.0, -0.3, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                                                end
                                                
                                                if not IsEntityPlayingAnim(myPed, "mp_player_int_upperwank", "mp_player_int_wank_01", 3) then
                                                    TaskPlayAnim(myPed, "mp_player_int_upperwank", "mp_player_int_wank_01", 8.0, -8.0, 100000, 51, 1.0, false, false, false)
                                                end
                                            end
                                            
                                            if DoesEntityExist(playerPed) then
                                                if IsEntityAttached(playerPed) then
                                                    DetachEntity(playerPed, true, false)
                                                end
                                                ClearPedTasksImmediately(playerPed)
                                            end
                                        end)
                                    ]], targetServerId))
                                end
                            else
                                if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                    Susano.InjectResource("any", [[
                                        rawset(_G, 'wank_active', false)
                                        rawset(_G, 'wank_target_ped', nil)
                                        
                                        local playerPed = PlayerPedId()
                                        if DoesEntityExist(playerPed) then
                                            if IsEntityAttached(playerPed) then
                                                DetachEntity(playerPed, true, false)
                                            end
                                            ClearPedTasksImmediately(playerPed)
                                        end
                                    ]])
                                end
                            end
                        end
                    end

                    Actions.piggybackItem = FindItem("Online", "Troll", "piggyback")
                    if Actions.piggybackItem then
                        Actions.piggybackItem.onClick = function(value)
                            if not Menu.SelectedPlayer then
                                Actions.piggybackItem.value = false
                                return
                            end
                            
                            local targetServerId = Menu.SelectedPlayer
                            
                            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                                Susano.InjectResource("any", string.format([[
                                    local targetServerId = %d
                                    local playerPed = PlayerPedId()
                                    
                                    local targetPlayerId = nil
                                    for _, player in ipairs(GetActivePlayers()) do
                                        if GetPlayerServerId(player) == targetServerId then
                                            targetPlayerId = player
                                            break
                                        end
                                    end
                                    
                                    if not targetPlayerId then return end
                                    
                                    local targetPed = GetPlayerPed(targetPlayerId)
                                    if not DoesEntityExist(targetPed) then return end

                                    if rawget(_G, 'piggyback_active') then
                                        ClearPedSecondaryTask(playerPed)
                                        DetachEntity(playerPed, true, false)
                                        rawset(_G, 'piggyback_active', false)
                                    else
                                        rawset(_G, 'piggyback_active', true)
                                        if not HasAnimDictLoaded("anim@arena@celeb@flat@paired@no_props@") then
                                            RequestAnimDict("anim@arena@celeb@flat@paired@no_props@")
                                            while not HasAnimDictLoaded("anim@arena@celeb@flat@paired@no_props@") do
                                                Wait(0)
                                            end
                                        end

                                        AttachEntityToEntity(PlayerPedId(), targetPed, 0, 0.0, -0.25, 0.45, 0.5, 0.5, 180, false, false, false, false, 2, false)
                                        TaskPlayAnim(PlayerPedId(), "anim@arena@celeb@flat@paired@no_props@", "piggyback_c_player_b", 8.0, -8.0, 1000000, 33, 0, false, false, false)
                                    end
                                ]], targetServerId))
                            end
                        end
                    end


Menu.BugPlayerMode = "Bug"

function Menu.ActionBugPlayer()
    if not Menu.SelectedPlayer then return end
    
    local bugPlayerMode = Menu.BugPlayerMode or "Bug"
    local targetServerId = Menu.SelectedPlayer
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local targetServerId = %d
            local bugPlayerMode = string.lower("%s")
            
            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == targetServerId then
                    targetPlayerId = player
                    break
                end
            end
            
            if not targetPlayerId then return end
            
            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) then return end
            
            if bugPlayerMode == "bug" then
                CreateThread(function()
                    local playerPed = PlayerPedId()
                    local myCoords = GetEntityCoords(playerPed)
                    local myHeading = GetEntityHeading(playerPed)
                    
                    local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 100.0, 0, 70)
                    if not closestVeh or closestVeh == 0 then return end
                    
                    SetPedIntoVehicle(playerPed, closestVeh, -1)
                    Wait(150)
                    
                    SetEntityAsMissionEntity(closestVeh, true, true)
                    if NetworkGetEntityIsNetworked(closestVeh) then
                        NetworkRequestControlOfEntity(closestVeh)
                    end
                    
                    SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                    Wait(100)
                    
                    for i = 1, 30 do
                        DetachEntity(closestVeh, true, true)
                        Wait(5)
                        AttachEntityToEntityPhysically(closestVeh, targetPed, 0, 0, 0, 1800.0, 1600.0, 1200.0, 300.0, 300.0, 300.0, true, true, true, false, 0)
                        Wait(5)
                    end
                end)
            elseif bugPlayerMode == "launch" then
                CreateThread(function()
                    local clientId = GetPlayerFromServerId(targetServerId)
                    if not clientId or clientId == -1 then
                        return
                    end
                    
                    local targetPed = GetPlayerPed(clientId)
                    if not targetPed or not DoesEntityExist(targetPed) then
                        return
                    end
                    
                    local myPed = PlayerPedId()
                    if not myPed then
                        return
                    end
                    
                    local myCoords = GetEntityCoords(myPed)
                    local targetCoords = GetEntityCoords(targetPed)
                    if not myCoords or not targetCoords then
                        return
                    end
                    
                    local distance = #(myCoords - targetCoords)
                    local teleported = false
                    local originalCoords = nil
                    
                    if distance > 10.0 then
                        originalCoords = myCoords
                        local angle = math.random() * 2 * math.pi
                        local radiusOffset = math.random(5, 9)
                        local xOffset = math.cos(angle) * radiusOffset
                        local yOffset = math.sin(angle) * radiusOffset
                        local newCoords = vector3(targetCoords.x + xOffset, targetCoords.y + yOffset, targetCoords.z)
                        SetEntityCoordsNoOffset(myPed, newCoords.x, newCoords.y, newCoords.z, false, false, false)
                        SetEntityVisible(myPed, false, 0)
                        teleported = true
                        Wait(100)
                    end
                    
                    ClearPedTasksImmediately(myPed)
                    for i = 1, 5 do
                        if not DoesEntityExist(targetPed) then
                            break
                        end
                        
                        local curTargetCoords = GetEntityCoords(targetPed)
                        if not curTargetCoords then
                            break
                        end
                        
                        SetEntityCoords(myPed, curTargetCoords.x, curTargetCoords.y, curTargetCoords.z + 0.5, false, false, false, false)
                        Wait(100)
                        AttachEntityToEntityPhysically(myPed, targetPed, 0, 0.0, 0.0, 0.0, 150.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1, false, false, 1, 2)
                        Wait(100)
                        DetachEntity(myPed, true, true)
                        Wait(200)
                    end
                    
                    Wait(500)
                    ClearPedTasksImmediately(myPed)
                    
                    if originalCoords then
                        SetEntityCoords(myPed, originalCoords.x, originalCoords.y, originalCoords.z + 1.0, false, false, false, false)
                        Wait(100)
                        SetEntityCoords(myPed, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, false)
                    end
                    
                    if teleported then
                        SetEntityVisible(myPed, true, 0)
                    end
                end)
            elseif bugPlayerMode == "hard launch" then
                CreateThread(function()
                    local clientId = GetPlayerFromServerId(targetServerId)
                    if not clientId or clientId == -1 then
                        return
                    end
                    
                    local targetPed = GetPlayerPed(clientId)
                    if not targetPed or not DoesEntityExist(targetPed) then
                        return
                    end
                    
                    local myPed = PlayerPedId()
                    if not myPed then
                        return
                    end
                    
                    local myCoords = GetEntityCoords(myPed)
                    local targetCoords = GetEntityCoords(targetPed)
                    if not myCoords or not targetCoords then
                        return
                    end
                    
                    local distance = #(myCoords - targetCoords)
                    local teleported = false
                    local originalCoords = nil
                    
                    if distance > 10.0 then
                        originalCoords = myCoords
                        local angle = math.random() * 2 * math.pi
                        local radiusOffset = math.random(5, 9)
                        local xOffset = math.cos(angle) * radiusOffset
                        local yOffset = math.sin(angle) * radiusOffset
                        local newCoords = vector3(targetCoords.x + xOffset, targetCoords.y + yOffset, targetCoords.z)
                        SetEntityCoordsNoOffset(myPed, newCoords.x, newCoords.y, newCoords.z, false, false, false)
                        SetEntityVisible(myPed, false, 0)
                        teleported = true
                        Wait(100)
                    end
                    
                    for cycle = 1, 4 do
                        ClearPedTasksImmediately(myPed)
                        for i = 1, 5 do
                            if not DoesEntityExist(targetPed) then
                                break
                            end
                            
                            local curTargetCoords = GetEntityCoords(targetPed)
                            if not curTargetCoords then
                                break
                            end
                            
                            SetEntityCoords(myPed, curTargetCoords.x, curTargetCoords.y, curTargetCoords.z + 0.5, false, false, false, false)
                            Wait(100)
                            AttachEntityToEntityPhysically(myPed, targetPed, 0, 0.0, 0.0, 0.0, 150.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1, false, false, 1, 2)
                            Wait(100)
                            DetachEntity(myPed, true, true)
                            Wait(200)
                        end
                        
                        if cycle < 4 then
                            Wait(1000)
                        end
                    end
                    
                    Wait(500)
                    ClearPedTasksImmediately(myPed)
                    
                    if originalCoords then
                        SetEntityCoords(myPed, originalCoords.x, originalCoords.y, originalCoords.z + 1.0, false, false, false, false)
                        Wait(100)
                        SetEntityCoords(myPed, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, false)
                    end
                    
                    if teleported then
                        SetEntityVisible(myPed, true, 0)
                    end
                end)
            elseif bugPlayerMode == "attach" then
                CreateThread(function()
                    local function reqCtrl(entity)
                        if not entity or entity == 0 then return false end
                        if not NetworkGetEntityIsNetworked(entity) then
                            NetworkRegisterEntityAsNetworked(entity)
                        end
                        if NetworkGetEntityIsNetworked(entity) then
                            NetworkRequestControlOfEntity(entity)
                            local attempts = 0
                            while not NetworkHasControlOfEntity(entity) and attempts < 30 do
                                Wait(10)
                                attempts = attempts + 1
                                NetworkRequestControlOfEntity(entity)
                            end
                            return NetworkHasControlOfEntity(entity)
                        end
                        return false
                    end

                    local targetPlayerId = nil
                    for _, player in ipairs(GetActivePlayers()) do
                        if GetPlayerServerId(player) == targetServerId then
                            targetPlayerId = player
                            break
                        end
                    end
                    if not targetPlayerId then return end

                    local targetPed = GetPlayerPed(targetPlayerId)
                    if not DoesEntityExist(targetPed) then return end

                    local playerPed = PlayerPedId()
                    local myCoords = GetEntityCoords(playerPed)
                    local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 120.0, 0, 70)
                    if not closestVeh or closestVeh == 0 then return end

                    SetEntityAsMissionEntity(closestVeh, true, true)
                    if not reqCtrl(closestVeh) then return end

                    SetPedIntoVehicle(playerPed, closestVeh, -1)
                    Wait(120)

                    SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                    Wait(50)

                    local targetVeh = GetVehiclePedIsIn(targetPed, false)
                    local targetEntity = targetVeh ~= 0 and DoesEntityExist(targetVeh) and targetVeh or targetPed
                    
                    AttachEntityToEntityPhysically(
                        closestVeh, targetEntity,
                        0, 0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        500.0, false, false, 1, 2
                    )
                    
                    Wait(100)
                    
                    AttachEntityToEntityPhysically(
                        closestVeh, targetEntity,
                        0, 0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        500.0, false, false, 1, 2
                    )
                end)
            end
        ]], targetServerId, bugPlayerMode))
    end
end

function Menu.ActionCagePlayer()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local targetServerId = %d
            
            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == targetServerId then
                    targetPlayerId = player
                    break
                end
            end
            
            if not targetPlayerId then return end
            
            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) then return end
            
            CreateThread(function()
                local playerPed = PlayerPedId()
                local myCoords = GetEntityCoords(playerPed)
                local myHeading = GetEntityHeading(playerPed)
                
                local vehicles = {}
                local searchRadius = 150.0
                local vehHandle, veh = FindFirstVehicle()
                local success
                
                repeat
                    local vehCoords = GetEntityCoords(veh)
                    local distance = #(myCoords - vehCoords)
                    local vehClass = GetVehicleClass(veh)
                    if distance <= searchRadius and veh ~= GetVehiclePedIsIn(playerPed, false) and vehClass ~= 8 and vehClass ~= 13 then
                        table.insert(vehicles, {handle = veh, distance = distance})
                    end
                    success, veh = FindNextVehicle(vehHandle)
                until not success
                
                EndFindVehicle(vehHandle)
                
                if #vehicles < 4 then return end
                
                table.sort(vehicles, function(a, b) return a.distance < b.distance end)
                local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle, vehicles[4].handle}
                
                local function takeControl(veh)
                    SetPedIntoVehicle(playerPed, veh, -1)
                    Wait(150)
                    SetEntityAsMissionEntity(veh, true, true)
                    if NetworkGetEntityIsNetworked(veh) then
                        NetworkRequestControlOfEntity(veh)
                    end
                    SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                    Wait(100)
                end
                
                for i = 1, 4 do
                    if DoesEntityExist(selectedVehicles[i]) then
                        takeControl(selectedVehicles[i])
                    end
                end
                
                local targetCoords = GetEntityCoords(targetPed)
                local positions = {
                    {x = targetCoords.x + 1.2, y = targetCoords.y, z = targetCoords.z, rotX = 90.0, rotY = 0.0, rotZ = 90.0},
                    {x = targetCoords.x - 1.2, y = targetCoords.y, z = targetCoords.z, rotX = 90.0, rotY = 0.0, rotZ = -90.0},
                    {x = targetCoords.x, y = targetCoords.y + 1.2, z = targetCoords.z, rotX = 90.0, rotY = 0.0, rotZ = 0.0},
                    {x = targetCoords.x, y = targetCoords.y - 1.2, z = targetCoords.z, rotX = 90.0, rotY = 0.0, rotZ = 180.0},
                }
                
                for i = 1, 4 do
                    if DoesEntityExist(selectedVehicles[i]) then
                        local pos = positions[i]
                        SetEntityCoordsNoOffset(selectedVehicles[i], pos.x, pos.y, pos.z, false, false, false)
                        SetEntityRotation(selectedVehicles[i], pos.rotX, pos.rotY, pos.rotZ, 2, true)
                        FreezeEntityPosition(selectedVehicles[i], true)
                    end
                end
            end)
        ]], targetServerId))
    end
end

                    function Menu.ActionRamPlayer()
                        if not Menu.SelectedPlayer then return end
                        
                        local targetServerId = Menu.SelectedPlayer
                        
                        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                            Susano.InjectResource("any", string.format([[
                                local targetServerId = %d
                                
                                local function ramPlayer(ped)
                                    if not ped or not DoesEntityExist(ped) then return end
                                    
                                    local playerPed = PlayerPedId()
                                    local myCoords = GetEntityCoords(playerPed)
                                    
                                    -- Trouver le vÃ©hicule le plus proche
                                    local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 100.0, 0, 70)
                                    if not closestVeh or closestVeh == 0 then return end
                                    
                                    -- Sauvegarder ma position actuelle
                                    local savedCoords = GetEntityCoords(playerPed)
                                    local savedHeading = GetEntityHeading(playerPed)
                                    
                                    -- Obtenir le contrÃ´le du vÃ©hicule
                                    SetEntityAsMissionEntity(closestVeh, true, true)
                                    local timeout = 1000
                                    NetworkRequestControlOfEntity(closestVeh)
                                    while not NetworkHasControlOfEntity(closestVeh) and timeout > 0 do
                                        Wait(10)
                                        timeout = timeout - 10
                                        NetworkRequestControlOfEntity(closestVeh)
                                    end
                                    
                                    -- Me tÃ©lÃ©porter dans le vÃ©hicule
                                    SetPedIntoVehicle(playerPed, closestVeh, -1)
                                    Wait(100)
                                    
                                    -- Me remettre Ã  ma position originale
                                    SetEntityCoordsNoOffset(playerPed, savedCoords.x, savedCoords.y, savedCoords.z, false, false, false)
                                    SetEntityHeading(playerPed, savedHeading)
                                    Wait(50)
                                    
                                    -- Positionner le vÃ©hicule derriÃ¨re le joueur cible (comme dans Luxor)
                                    local targetCoords = GetEntityCoords(ped)
                                    local spawnPos = GetOffsetFromEntityInWorldCoords(ped, 0.0, -10.0, 0.0)
                                    local heading = GetEntityHeading(ped)
                                    
                                    SetEntityCoordsNoOffset(closestVeh, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false)
                                    SetEntityHeading(closestVeh, heading)
                                    
                                    -- Configurer le vÃ©hicule pour le ram
                                    SetVehicleForwardSpeed(closestVeh, 100.0)
                                    SetEntityVisible(closestVeh, true, false)
                                    SetVehicleDoorsLocked(closestVeh, 4)
                                    SetVehicleEngineOn(closestVeh, true, true, false)
                                    
                                    -- Nettoyage automatique aprÃ¨s 15 secondes
                                    Citizen.SetTimeout(15000, function()
                                        if DoesEntityExist(closestVeh) then
                                            DeleteVehicle(closestVeh)
                                        end
                                    end)
                                end
                                
                                local targetPlayerId = nil
                                for _, player in ipairs(GetActivePlayers()) do
                                    if GetPlayerServerId(player) == targetServerId then
                                        targetPlayerId = player
                                        break
                                    end
                                end
                                
                                if not targetPlayerId then return end
                                
                                local ped = GetPlayerPed(targetPlayerId)
                                if ped and ped ~= 0 then
                                    ramPlayer(ped)
                                end
                            ]], targetServerId))
                        end
                    end

function Menu.ActionRainVehicle()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local targetServerId = %d
            
            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == targetServerId then
                    targetPlayerId = player
                    break
                end
            end
            
            if not targetPlayerId then return end
            
            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) then return end
            
            CreateThread(function()
                local playerPed = PlayerPedId()
                local myCoords = GetEntityCoords(playerPed)
                
                local nearbyVehicles = {}
                local vehHandle, veh = FindFirstVehicle()
                local success
                
                repeat
                    if DoesEntityExist(veh) then
                        local vehCoords = GetEntityCoords(veh)
                        local distance = #(myCoords - vehCoords)
                        if distance <= 200.0 and distance > 5.0 and veh ~= GetVehiclePedIsIn(playerPed, false) then
                            table.insert(nearbyVehicles, veh)
                        end
                    end
                    success, veh = FindNextVehicle(vehHandle)
                until not success
                
                EndFindVehicle(vehHandle)
                
                if #nearbyVehicles == 0 then return end
                
                for i, veh in ipairs(nearbyVehicles) do
                    if DoesEntityExist(veh) then
                        SetPedIntoVehicle(playerPed, veh, -1)
                        Wait(50)
                        SetEntityAsMissionEntity(veh, true, true)
                        if NetworkGetEntityIsNetworked(veh) then
                            NetworkRequestControlOfEntity(veh)
                        end
                        local targetCoords = GetEntityCoords(targetPed)
                        SetEntityCoordsNoOffset(veh, targetCoords.x, targetCoords.y, targetCoords.z + 50.0, false, false, false)
                        SetEntityHasGravity(veh, true)
                        Wait(10)
                    end
                end
            end)
        ]], targetServerId))
    end
end

function Menu.ActionDropVehicle()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local targetServerId = %d
            
            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == targetServerId then
                    targetPlayerId = player
                    break
                end
            end
            
            if not targetPlayerId then return end
            
            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) then return end
            
            CreateThread(function()
                local playerPed = PlayerPedId()
                local myCoords = GetEntityCoords(playerPed)
                local myHeading = GetEntityHeading(playerPed)
                
                local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 100.0, 0, 70)
                if not closestVeh or closestVeh == 0 then return end
                
                SetPedIntoVehicle(playerPed, closestVeh, -1)
                Wait(150)
                
                SetEntityAsMissionEntity(closestVeh, true, true)
                if NetworkGetEntityIsNetworked(closestVeh) then
                    NetworkRequestControlOfEntity(closestVeh)
                end
                
                SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                Wait(100)
                
                local targetCoords = GetEntityCoords(targetPed)
                SetEntityCoordsNoOffset(closestVeh, targetCoords.x, targetCoords.y, targetCoords.z + 15.0, false, false, false)
                SetEntityRotation(closestVeh, 0.0, -90.0, 0.0, 2, true)
                SetEntityVelocity(closestVeh, 0.0, 0.0, -100.0)
            end)
        ]], targetServerId))
    end
end

-- Airstrike : Volatus en feu sur la cible
-- Cooldown global pour éviter le spam InjectResource
_G._airstrikeLastUse = 0
_G._airstrikeCD = 5000 -- 5s entre chaque

function Menu.ActionAirstrike()
    if not Menu.SelectedPlayer then return end

    -- Cooldown check (côté overlay)
    local now = GetGameTimer()
    if now - (_G._airstrikeLastUse or 0) < _G._airstrikeCD then return end
    _G._airstrikeLastUse = now

    local targetServerId = Menu.SelectedPlayer

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            CreateThread(function()
                local targetServerId = %d

                -- Resolve target
                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end
                if not targetPlayerId then return end

                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then return end

                -- Kill any previous airstrike thread
                rawset(_G, '_airstrike_active', false)
                Wait(100)
                rawset(_G, '_airstrike_active', true)

                -- Load model
                local modelHash = GetHashKey("volatus")
                RequestModel(modelHash)
                local t = 100
                while not HasModelLoaded(modelHash) and t > 0 do Wait(10); t = t - 1 end
                if not HasModelLoaded(modelHash) then return end

                local tc = GetEntityCoords(targetPed)
                local spawnX = tc.x + math.random(-3, 3) + 0.0
                local spawnY = tc.y + math.random(-3, 3) + 0.0
                local spawnZ = tc.z + 65.0

                -- Spawn via Susano si dispo, sinon fallback CreateVehicle
                local susano = rawget(_G, "Susano")
                local heli = nil
                if susano and type(susano.CreateSpoofedVehicle) == "function" then
                    heli = susano.CreateSpoofedVehicle(modelHash, spawnX, spawnY, spawnZ, math.random(0, 360) + 0.0, false, false, false)
                else
                    heli = CreateVehicle(modelHash, spawnX, spawnY, spawnZ, math.random(0, 360) + 0.0, false, false)
                end

                SetModelAsNoLongerNeeded(modelHash)
                if not heli or heli == 0 then return end

                -- Stocker le handle pour cleanup
                rawset(_G, '_airstrike_heli', heli)

                SetEntityAsMissionEntity(heli, true, true)
                SetEntityRotation(heli, -70.0, 0.0, math.random(0, 360) + 0.0, 2, true)

                -- NE PAS tuer le véhicule immédiatement
                -- On dégrade progressivement pour que RAGE ne le GC pas
                SetVehicleEngineHealth(heli, 100.0)
                SetVehicleBodyHealth(heli, 200.0)
                -- Vélocité de chute
                SetEntityVelocity(heli, 0.0, 0.0, -35.0)

                -- Thread fumée/feu progressif pendant la chute
                CreateThread(function()
                    Wait(300)
                    if DoesEntityExist(heli) then
                        SetVehicleEngineHealth(heli, -1000.0)
                    end
                    Wait(500)
                    if DoesEntityExist(heli) then
                        SetVehicleEngineHealth(heli, -4000.0)
                        SetVehicleBodyHealth(heli, 0.0)
                    end
                end)

                -- Thread principal : tracking altitude → explosion
                local exploded = false
                local timeout = 100 -- 5s max (100 × 50ms)
                while timeout > 0 and not exploded and rawget(_G, '_airstrike_active') do
                    Wait(50)
                    timeout = timeout - 1

                    if not DoesEntityExist(heli) then break end

                    local heliCoords = GetEntityCoords(heli)
                    -- Maintenir la vélocité de chute (RAGE ralentit les épaves)
                    SetEntityVelocity(heli, 0.0, 0.0, -35.0)

                    -- Quand l'heli est à ~12m de la cible
                    if heliCoords.z <= tc.z + 12.0 then
                        -- Impact principal
                        AddExplosion(heliCoords.x, heliCoords.y, heliCoords.z, 7, 5.0, true, false, 1.0)
                        Wait(50)
                        -- Secondaires décalées
                        for i = 1, 3 do
                            local ox = math.random(-3, 3) + 0.0
                            local oy = math.random(-3, 3) + 0.0
                            AddExplosion(heliCoords.x + ox, heliCoords.y + oy, heliCoords.z, 2, 3.0, true, false, 0.8)
                            Wait(80)
                        end
                        -- Napalm sur coords live de la cible
                        Wait(150)
                        if DoesEntityExist(targetPed) then
                            local tc2 = GetEntityCoords(targetPed)
                            for i = 1, 3 do
                                AddExplosion(tc2.x + math.random(-2, 2), tc2.y + math.random(-2, 2), tc2.z, 5, 2.0, true, false, 0.6)
                                Wait(100)
                            end
                        end
                        exploded = true
                    end
                end

                -- Timeout sans impact → forcer explosion
                if not exploded and DoesEntityExist(heli) then
                    local ec = GetEntityCoords(heli)
                    AddExplosion(ec.x, ec.y, ec.z, 7, 5.0, true, false, 1.0)
                end

                -- Cleanup entité après un délai (laisser le temps au FX)
                Wait(2000)
                if DoesEntityExist(heli) then
                    SetEntityAsMissionEntity(heli, true, true)
                    DeleteEntity(heli)
                end
                rawset(_G, '_airstrike_heli', nil)
                rawset(_G, '_airstrike_active', false)
            end)
        ]], targetServerId))
    end
end

                    Menu.CrushMode = "Rain"

                    function Menu.ActionCrush()
                        local crushMode = Menu.CrushMode or "Rain"
                        if crushMode == "Rain" then
                            Menu.ActionRainVehicle()
                        elseif crushMode == "Drop" then
                            Menu.ActionDropVehicle()
                        elseif crushMode == "Ram" then
                            Menu.ActionRamPlayer()
                        end
                    end

                    function Menu.ActionBugAttach()
                        if not Menu.SelectedPlayer then return end

                        local targetServerId = Menu.SelectedPlayer

                        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                            Susano.InjectResource("any", string.format([[
                                local targetServerId = %d

                                local function reqCtrl(entity)
                                    if not entity or entity == 0 then return false end
                                    if not NetworkGetEntityIsNetworked(entity) then
                                        NetworkRegisterEntityAsNetworked(entity)
                                    end
                                    if NetworkGetEntityIsNetworked(entity) then
                                        NetworkRequestControlOfEntity(entity)
                                        local attempts = 0
                                        while not NetworkHasControlOfEntity(entity) and attempts < 50 do
                                            Wait(0)
                                            attempts = attempts + 1
                                            NetworkRequestControlOfEntity(entity)
                                        end
                                        return NetworkHasControlOfEntity(entity)
                                    end
                                    return false
                                end

                                local targetPlayerId = nil
                                for _, player in ipairs(GetActivePlayers()) do
                                    if GetPlayerServerId(player) == targetServerId then
                                        targetPlayerId = player
                                        break
                                    end
                                end
                                if not targetPlayerId then return end

                                local targetPed = GetPlayerPed(targetPlayerId)
                                if not DoesEntityExist(targetPed) then return end

                                local playerPed = PlayerPedId()
                                local myCoords = GetEntityCoords(playerPed)
                                local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 120.0, 0, 70)
                                if not closestVeh or closestVeh == 0 then return end

                                SetEntityAsMissionEntity(closestVeh, true, true)
                                reqCtrl(closestVeh)

                                SetPedIntoVehicle(playerPed, closestVeh, -1)
                                Wait(120)

                                SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)

                                local targetVeh = GetVehiclePedIsIn(targetPed, false)
                                if targetVeh ~= 0 and DoesEntityExist(targetVeh) then
                                    AttachEntityToEntityPhysically(
                                        closestVeh, targetVeh,
                                        0, 0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        1, false, false, 1, 2
                                    )
                                else
                                    AttachEntityToEntityPhysically(
                                        closestVeh, targetPed,
                                        0, 0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        1, false, false, 1, 2
                                    )
                                end
                            ]], targetServerId))
                    end
                end

if not attachedPlayers then attachedPlayers = {} end

CreateThread(function()
    while true do
        Wait(0)
        if attachedPlayers and next(attachedPlayers) then
            local me = PlayerPedId()
            if DoesEntityExist(me) then
                local coords = GetEntityCoords(me)
                local f = GetEntityForwardVector(me)
                for playerId, ped in pairs(attachedPlayers) do
                    if DoesEntityExist(ped) then
                        local success = pcall(function()
                            SetEntityCoordsNoOffset(ped, coords.x + f.x, coords.y + f.y, coords.z + f.z, true, true, true)
                            SetEntityHeading(ped, GetEntityHeading(me))
                        end)
                        if not success then
                            attachedPlayers[playerId] = nil
                        end
                    else
                        attachedPlayers[playerId] = nil
                    end
                end
            end
        end
    end
end)

                    function Menu.ActionTPToMe()
                        if not Menu.SelectedPlayer then return end

                        local targetServerId = Menu.SelectedPlayer

                        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                            Susano.InjectResource("any", string.format([[
                                local targetServerId = %d

                                local function reqCtrl(entity)
                                    if not entity or entity == 0 then return false end
                                    if not NetworkGetEntityIsNetworked(entity) then
                                        NetworkRegisterEntityAsNetworked(entity)
                                    end
                                    if NetworkGetEntityIsNetworked(entity) then
                                        NetworkRequestControlOfEntity(entity)
                                        local attempts = 0
                                        while not NetworkHasControlOfEntity(entity) and attempts < 50 do
                                            Wait(0)
                                            attempts = attempts + 1
                                            NetworkRequestControlOfEntity(entity)
                                        end
                                        return NetworkHasControlOfEntity(entity)
                                    end
                                    return false
                                end

                                local targetPlayerId = nil
                                for _, player in ipairs(GetActivePlayers()) do
                                    if GetPlayerServerId(player) == targetServerId then
                                        targetPlayerId = player
                                        break
                                    end
                                end
                                if not targetPlayerId then return end

                                local targetPed = GetPlayerPed(targetPlayerId)
                                if not DoesEntityExist(targetPed) then return end

                                local playerPed = PlayerPedId()
                                local myCoords = GetEntityCoords(playerPed)
                                local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 120.0, 0, 70)
                                if not closestVeh or closestVeh == 0 then return end

                                SetEntityAsMissionEntity(closestVeh, true, true)
                                reqCtrl(closestVeh)

                                SetPedIntoVehicle(playerPed, closestVeh, -1)
                                Wait(120)

                                SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)

                                local targetVeh = GetVehiclePedIsIn(targetPed, false)
                                if targetVeh ~= 0 and DoesEntityExist(targetVeh) then
                                    AttachEntityToEntityPhysically(
                                        closestVeh, targetVeh,
                                        0, 0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        1, false, false, 1, 2
                                    )
                                    Wait(200)
                                    DetachEntity(closestVeh, true, true)
                                    SetEntityCoordsNoOffset(closestVeh, myCoords.x, myCoords.y, myCoords.z + 1.0, false, false, false)
                                    Wait(100)
                                    AttachEntityToEntityPhysically(
                                        closestVeh, targetVeh,
                                        0, 0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        1, false, false, 1, 2
                                    )
                                else
                                    AttachEntityToEntityPhysically(
                                        closestVeh, targetPed,
                                        0, 0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        1, false, false, 1, 2
                                    )
                                    Wait(200)
                                    DetachEntity(closestVeh, true, true)
                                    SetEntityCoordsNoOffset(closestVeh, myCoords.x, myCoords.y, myCoords.z + 1.0, false, false, false)
                                    Wait(100)
                                    AttachEntityToEntityPhysically(
                                        closestVeh, targetPed,
                                        0, 0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        1, false, false, 1, 2
                                    )
                                end
                            ]], targetServerId))
                        end
                    end

Actions.attachPlayerItem = FindItem("Online", "Troll", "Attach Player")
if Actions.attachPlayerItem then
    Actions.attachPlayerItem.onClick = function(value)
        Menu.attachPlayerEnabled = value
        if not Menu.SelectedPlayer then
            Menu.attachPlayerEnabled = false
            return
        end

        local targetServerId = Menu.SelectedPlayer

        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
            Susano.InjectResource("any", string.format([[
                local targetServerId = %d
                local enabled = %s

                local targetPlayerId = nil
                for _, player in ipairs(GetActivePlayers()) do
                    if GetPlayerServerId(player) == targetServerId then
                        targetPlayerId = player
                        break
                    end
                end

                if not targetPlayerId then return end
                local targetPed = GetPlayerPed(targetPlayerId)
                if not DoesEntityExist(targetPed) then return end

                local playerPed = PlayerPedId()

                if enabled then
                    CreateThread(function()
                        rawset(_G, 'attach_loop_' .. targetServerId, true)

                        while rawget(_G, 'attach_loop_' .. targetServerId) do
                            Wait(0)

                            if not DoesEntityExist(targetPed) then break end

                            local myCoords = GetEntityCoords(playerPed)
                            local myForward = GetEntityForwardVector(playerPed)
                            local myHeading = GetEntityHeading(playerPed)

                            SetEntityCoordsNoOffset(targetPed, myCoords.x + myForward.x, myCoords.y + myForward.y, myCoords.z + myForward.z, true, true, true)
                            SetEntityHeading(targetPed, myHeading)
                        end
                    end)
                else
                    rawset(_G, 'attach_loop_' .. targetServerId, false)
                end
            ]], targetServerId, tostring(value)))
        end
                        end
                    end

Menu.BugVehicleMode = "V1"
Menu.KickVehicleMode = "V1"

function Menu.ActionBugVehicle()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    local bugVehicleMode = Menu.BugVehicleMode or "V1"
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local targetServerId = %d
            local bugVehicleMode = "%s"
            
            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == targetServerId then
                    targetPlayerId = player
                    break
                end
            end
            
            if not targetPlayerId then return end
            
            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) or not IsPedInAnyVehicle(targetPed, false) then
                return
            end
            
            local targetVehicle = GetVehiclePedIsIn(targetPed, false)
            if not DoesEntityExist(targetVehicle) then return end
            
            if bugVehicleMode == "V2" then
                CreateThread(function()
                    local function reqCtrl(entity)
                        if not entity or entity == 0 then return false end
                        if not NetworkGetEntityIsNetworked(entity) then
                            NetworkRegisterEntityAsNetworked(entity)
                        end
                        if NetworkGetEntityIsNetworked(entity) then
                            NetworkRequestControlOfEntity(entity)
                            local attempts = 0
                            while not NetworkHasControlOfEntity(entity) and attempts < 30 do
                                Wait(10)
                                attempts = attempts + 1
                                NetworkRequestControlOfEntity(entity)
                            end
                            return NetworkHasControlOfEntity(entity)
                        end
                        return false
                    end

                    local playerPed = PlayerPedId()
                    local myCoords = GetEntityCoords(playerPed)
                    local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 120.0, 0, 70)
                    if not closestVeh or closestVeh == 0 then return end

                    SetEntityAsMissionEntity(closestVeh, true, true)
                    if not reqCtrl(closestVeh) then return end

                    SetPedIntoVehicle(playerPed, closestVeh, -1)
                    Wait(120)

                    SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                    Wait(50)
                    
                    AttachEntityToEntityPhysically(
                        closestVeh, targetVehicle,
                        0, 0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        500.0, false, false, 1, 2
                    )
                    
                    Wait(100)
                    
                    AttachEntityToEntityPhysically(
                        closestVeh, targetVehicle,
                        0, 0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        500.0, false, false, 1, 2
                    )
                end)
            else
                CreateThread(function()
                    local playerPed = PlayerPedId()
                    local myCoords = GetEntityCoords(playerPed)
                    
                    local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 100.0, 0, 70)
                    if not closestVeh or closestVeh == 0 then return end
                    
                    SetPedIntoVehicle(playerPed, closestVeh, -1)
                    Wait(150)
                    
                    SetEntityAsMissionEntity(closestVeh, true, true)
                    if NetworkGetEntityIsNetworked(closestVeh) then
                        NetworkRequestControlOfEntity(closestVeh)
                    end
                    
                    SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
                    Wait(100)
                    
                    for i = 1, 30 do
                        DetachEntity(closestVeh, true, true)
                        Wait(5)
                        AttachEntityToEntityPhysically(closestVeh, targetVehicle, 0, 0, 0, 2000.0, 1460.0, 1000.0, 10.0, 88.0, 600.0, true, true, true, false, 0)
                        Wait(5)
                    end
                end)
            end
        ]], targetServerId, bugVehicleMode))
    end
end

function Menu.ActionKickVehicle()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    local kickMode = Menu.KickVehicleMode or "V1"
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local targetServerId = %d
            local kickMode = "%s"
            
            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == targetServerId then
                    targetPlayerId = player
                    break
                end
            end
            
            if not targetPlayerId then return end
            
            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) or not IsPedInAnyVehicle(targetPed, false) then
                return
            end
            
            local targetVehicle = GetVehiclePedIsIn(targetPed, false)
            if not DoesEntityExist(targetVehicle) then return end
            
            CreateThread(function()
                local player = PlayerPedId()
                
                if DoesEntityExist(targetVehicle) then
                    local driver = GetPedInVehicleSeat(targetVehicle, -1)
                    if driver ~= 0 and DoesEntityExist(driver) then
                        SetPedIntoVehicle(player, targetVehicle, 0)
                        Wait(10)
                        NetworkRequestControlOfEntity(targetVehicle)
                        DeletePed(driver)
                        SetPedIntoVehicle(player, targetVehicle, -1)
                        Wait(25)
                        TaskLeaveVehicle(player, targetVehicle, 16)
                        Wait(450)
                    end
                end
            end)
        ]], targetServerId, kickMode))
    end
end

function Menu.ActionRemoveAllTires()
    if not Menu.SelectedPlayer then return end

    local targetServerId = Menu.SelectedPlayer

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local targetServerId = %d

            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == targetServerId then
                    targetPlayerId = player
                    break
                end
            end

            if not targetPlayerId then return end

            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) or not IsPedInAnyVehicle(targetPed, false) then
                return
            end

            local targetVehicle = GetVehiclePedIsIn(targetPed, false)
            if not DoesEntityExist(targetVehicle) then return end

            CreateThread(function()
                local player = PlayerPedId()
                local playerCoords = GetEntityCoords(player)
                local playerHeading = GetEntityHeading(player)

                if DoesEntityExist(targetVehicle) then
                    local driver = GetPedInVehicleSeat(targetVehicle, -1)
                    if driver ~= 0 and DoesEntityExist(driver) then
                        SetPedIntoVehicle(player, targetVehicle, 0)
                        Wait(10)
                        NetworkRequestControlOfEntity(targetVehicle)
                        DeletePed(driver)
                        SetPedIntoVehicle(player, targetVehicle, -1)
                        Wait(25)
                        TaskLeaveVehicle(player, targetVehicle, 16)
                        Wait(450)
                    end

                    NetworkRequestControlOfEntity(targetVehicle)
                    local timeout = 0
                    while not NetworkHasControlOfEntity(targetVehicle) and timeout < 50 do
                        NetworkRequestControlOfEntity(targetVehicle)
                        Wait(10)
                        timeout = timeout + 1
                    end

                    if NetworkHasControlOfEntity(targetVehicle) then
                        for wheel = 0, 3 do
                            SetVehicleTyreBurst(targetVehicle, wheel, true, 1000.0)
                            SetVehicleWheelHealth(targetVehicle, wheel, -1000.0)
                            SetVehicleTyreBurst(targetVehicle, wheel, true, 1000.0)
                        end
                        SetVehicleWheelType(targetVehicle, 7)
                        Wait(50)
                        for wheel = 0, 3 do
                            SetVehicleTyreBurst(targetVehicle, wheel, true, 1000.0)
                            SetVehicleWheelHealth(targetVehicle, wheel, -1000.0)
                        end
                    end
                end

                SetEntityCoordsNoOffset(player, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false)
                SetEntityHeading(player, playerHeading)
                Wait(50)
                SetEntityCoordsNoOffset(player, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false)
                SetEntityHeading(player, playerHeading)
            end)
        ]], targetServerId))
    end
end

function Menu.ActionGiveVehicle()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
CreateThread(function()
    local targetServerId = %d
    
    local targetPlayerId = nil
    for _, player in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(player) == targetServerId then
            targetPlayerId = player
            break
        end
    end
    
    if not targetPlayerId then
        return
    end
    
    local targetPed = GetPlayerPed(targetPlayerId)
    if not DoesEntityExist(targetPed) then
        return
    end
    
    local playerPed = PlayerPedId()
    local myCoords = GetEntityCoords(playerPed)
    local myHeading = GetEntityHeading(playerPed)
    
    local giveCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    SetCamCoord(giveCam, camCoords.x, camCoords.y, camCoords.z)
    SetCamRot(giveCam, camRot.x, camRot.y, camRot.z, 2)
    SetCamFov(giveCam, GetGameplayCamFov())
    SetCamActive(giveCam, true)
    RenderScriptCams(true, false, 0, true, true)
    
    local playerModel = GetEntityModel(playerPed)
    RequestModel(playerModel)
    local timeout = 0
    while not HasModelLoaded(playerModel) and timeout < 50 do
        Wait(50)
        timeout = timeout + 1
    end
    
    local groundZ = myCoords.z
    local rayHandle = StartShapeTestRay(myCoords.x, myCoords.y, myCoords.z + 2.0, myCoords.x, myCoords.y, myCoords.z - 100.0, 1, 0, 0)
    local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)
    if hit then
        groundZ = hitCoords.z
    end
    
    local clonePed = CreatePed(4, playerModel, myCoords.x, myCoords.y, groundZ, myHeading, false, false)
    SetEntityCollision(clonePed, false, false)
    FreezeEntityPosition(clonePed, true)
    SetEntityInvincible(clonePed, true)
    SetBlockingOfNonTemporaryEvents(clonePed, true)
    SetPedCanRagdoll(clonePed, false)
    ClonePedToTarget(playerPed, clonePed)
    
    SetEntityVisible(playerPed, false, false)
    SetEntityLocallyInvisible(playerPed)
    
    local closestVeh = GetClosestVehicle(myCoords.x, myCoords.y, myCoords.z, 100.0, 0, 70)
    
    if not closestVeh or closestVeh == 0 then
        SetEntityVisible(playerPed, true, false)
        SetCamActive(giveCam, false)
        if not rawget(_G, 'isSpectating') then
            RenderScriptCams(false, false, 0, true, true)
        end
        DestroyCam(giveCam, true)
        if DoesEntityExist(clonePed) then
            DeleteEntity(clonePed)
        end
        SetModelAsNoLongerNeeded(playerModel)
        return
    end
    
    SetPedIntoVehicle(playerPed, closestVeh, -1)
    Wait(150)
    SetEntityAsMissionEntity(closestVeh, true, true)
    if NetworkGetEntityIsNetworked(closestVeh) then
        NetworkRequestControlOfEntity(closestVeh)
        local timeout = 0
        while not NetworkHasControlOfEntity(closestVeh) and timeout < 50 do
            NetworkRequestControlOfEntity(closestVeh)
            Wait(10)
            timeout = timeout + 1
        end
    end
    
    SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
    SetEntityHeading(playerPed, myHeading)
    Wait(100)
    
    if not DoesEntityExist(targetPed) or not DoesEntityExist(closestVeh) then
        SetEntityVisible(playerPed, true, false)
        SetCamActive(giveCam, false)
        if not rawget(_G, 'isSpectating') then
            RenderScriptCams(false, false, 0, true, true)
        end
        DestroyCam(giveCam, true)
        if DoesEntityExist(clonePed) then
            DeleteEntity(clonePed)
        end
        SetModelAsNoLongerNeeded(playerModel)
        return
    end
    
    local targetCoords = GetEntityCoords(targetPed)
    local targetHeading = GetEntityHeading(targetPed)
    local offsetCoords = GetOffsetFromEntityInWorldCoords(targetPed, 3.0, 0.0, 0.0)
    
    SetEntityCoordsNoOffset(closestVeh, offsetCoords.x, offsetCoords.y, offsetCoords.z, false, false, false)
    SetEntityHeading(closestVeh, targetHeading)
    SetVehicleOnGroundProperly(closestVeh)
    
    Wait(500)
    SetEntityVisible(playerPed, true, false)
    SetCamActive(giveCam, false)
    if not rawget(_G, 'isSpectating') then
        RenderScriptCams(false, false, 0, true, true)
    end
    DestroyCam(giveCam, true)
    if DoesEntityExist(clonePed) then
        DeleteEntity(clonePed)
    end
    SetModelAsNoLongerNeeded(playerModel)
end)
        ]], targetServerId)
        
        Susano.InjectResource("any", WrapWithVehicleHooks(code))
    end
end

function Menu.ActionGiveRamp()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
local targetServerId = %d
local targetPlayerId = nil
for _, player in ipairs(GetActivePlayers()) do
    if GetPlayerServerId(player) == targetServerId then
        targetPlayerId = player
        break
    end
end

if not targetPlayerId then
    return
end

local targetPed = GetPlayerPed(targetPlayerId)
if not DoesEntityExist(targetPed) then
    return
end

if not IsPedInAnyVehicle(targetPed, false) then
    return
end

local targetVehicle = GetVehiclePedIsIn(targetPed, false)
if not DoesEntityExist(targetVehicle) then
    return
end

CreateThread(function()
    local playerPed = PlayerPedId()
    local myCoords = GetEntityCoords(playerPed)
    local myHeading = GetEntityHeading(playerPed)
    
    local rampCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    SetCamCoord(rampCam, camCoords.x, camCoords.y, camCoords.z)
    SetCamRot(rampCam, camRot.x, camRot.y, camRot.z, 2)
    SetCamFov(rampCam, GetGameplayCamFov())
    SetCamActive(rampCam, true)
    RenderScriptCams(true, false, 0, true, true)
    
    local playerModel = GetEntityModel(playerPed)
    RequestModel(playerModel)
    local timeout = 0
    while not HasModelLoaded(playerModel) and timeout < 50 do
        Wait(50)
        timeout = timeout + 1
    end

    local groundZ = myCoords.z
    local rayHandle = StartShapeTestRay(myCoords.x, myCoords.y, myCoords.z + 2.0, myCoords.x, myCoords.y, myCoords.z - 100.0, 1, 0, 0)
    local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)
    if hit then
        groundZ = hitCoords.z
    end
    
    local clonePed = CreatePed(4, playerModel, myCoords.x, myCoords.y, groundZ, myHeading, false, false)
    SetEntityCollision(clonePed, false, false)
    FreezeEntityPosition(clonePed, true)
    SetEntityInvincible(clonePed, true)
    SetBlockingOfNonTemporaryEvents(clonePed, true)
    SetPedCanRagdoll(clonePed, false)
    ClonePedToTarget(playerPed, clonePed)
    
    SetEntityVisible(playerPed, false, false)
    
    local targetCoords = GetEntityCoords(targetVehicle)
    local vehicles = {}
    local searchRadius = 100.0
    local vehHandle, veh = FindFirstVehicle()
    local success
    
    repeat
        local vehCoords = GetEntityCoords(veh)
        local distance = #(targetCoords - vehCoords)
        local vehClass = GetVehicleClass(veh)
        if distance <= searchRadius and veh ~= targetVehicle and vehClass ~= 8 and vehClass ~= 13 then
            table.insert(vehicles, {handle = veh, distance = distance})
        end
        success, veh = FindNextVehicle(vehHandle)
    until not success
    EndFindVehicle(vehHandle)
    
    if #vehicles < 3 then
        SetEntityVisible(playerPed, true, false)
        SetCamActive(rampCam, false)
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(rampCam, true)
        if DoesEntityExist(clonePed) then
            DeleteEntity(clonePed)
        end
        SetModelAsNoLongerNeeded(playerModel)
        return
    end
    
    table.sort(vehicles, function(a, b) return a.distance < b.distance end)
    local selectedVehicles = {vehicles[1].handle, vehicles[2].handle, vehicles[3].handle}
    
    local function takeControl(veh)
        SetPedIntoVehicle(playerPed, veh, -1)
        Wait(150)
        SetEntityAsMissionEntity(veh, true, true)
        if NetworkGetEntityIsNetworked(veh) then
            NetworkRequestControlOfEntity(veh)
            local timeout = 0
            while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                NetworkRequestControlOfEntity(veh)
                Wait(10)
                timeout = timeout + 1
            end
        end
        SetEntityCoordsNoOffset(playerPed, myCoords.x, myCoords.y, myCoords.z, false, false, false)
        SetEntityHeading(playerPed, myHeading)
        Wait(100)
    end
    
    for i = 1, 3 do
        if DoesEntityExist(selectedVehicles[i]) then
            takeControl(selectedVehicles[i])
        end
    end
    
    local rampPositions = {
        {offsetX = -2.0, offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
        {offsetX = 0.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
        {offsetX = 2.0,  offsetY = 2.5, offsetZ = 0.2, rotX = 160.0, rotY = 0.0, rotZ = 0.0},
    }
    
    for i = 1, 3 do
        if DoesEntityExist(selectedVehicles[i]) and DoesEntityExist(targetVehicle) then
            local pos = rampPositions[i]
            AttachEntityToEntity(selectedVehicles[i], targetVehicle, 0, pos.offsetX, pos.offsetY, pos.offsetZ, pos.rotX, pos.rotY, pos.rotZ, false, false, true, false, 2, true)
        end
    end
    
    Wait(500)
    SetEntityVisible(playerPed, true, false)
    SetCamActive(rampCam, false)
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(rampCam, true)
    if DoesEntityExist(clonePed) then
        DeleteEntity(clonePed)
    end
    SetModelAsNoLongerNeeded(playerModel)
end)
        ]], targetServerId)
        
        Susano.InjectResource("any", WrapWithVehicleHooks(code))
    end
end

                    Menu.GiveMode = "Vehicle"

                    function Menu.ActionGive()
                        local giveMode = Menu.GiveMode or "Vehicle"
                        if giveMode == "Vehicle" then
                            Menu.ActionGiveVehicle()
                        elseif giveMode == "Ramp" then
                            Menu.ActionGiveRamp()
                        end
                    end

Menu.TPLocation = "ocean"

function Menu.ActionTPTo()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    local tpLocation = Menu.TPLocation or "ocean"
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
local targetServerId = %d
local tpLocation = "%s"

local targetPlayerId = nil
for _, player in ipairs(GetActivePlayers()) do
    if GetPlayerServerId(player) == targetServerId then
        targetPlayerId = player
        break
    end
end

if not targetPlayerId then
    return
end

local targetPed = GetPlayerPed(targetPlayerId)
if not DoesEntityExist(targetPed) then
    return
end

if not IsPedInAnyVehicle(targetPed, false) then
    return
end

local targetVehicle = GetVehiclePedIsIn(targetPed, false)
if not DoesEntityExist(targetVehicle) then
    return
end

local locations = {
    ocean = {coords = vector3(-3000.0, -3000.0, 0.0), name = "Ocean"},
    mazebank = {coords = vector3(-75.0, -818.0, 326.0), name = "Maze Bank"},
    sandyshores = {coords = vector3(1960.0, 3740.0, 32.0), name = "Sandy Shores"}
}

local destCoords = locations[tpLocation].coords
local destName = locations[tpLocation].name

local playerPed = PlayerPedId()
local savedCoords = GetEntityCoords(playerPed)
local savedHeading = GetEntityHeading(playerPed)

local function RequestControl(entity, timeoutMs)
    if not entity or not DoesEntityExist(entity) then return false end
    local start = GetGameTimer()
    NetworkRequestControlOfEntity(entity)
    while not NetworkHasControlOfEntity(entity) do
        Wait(0)
        if GetGameTimer() - start > (timeoutMs or 500) then
            return false
        end
        NetworkRequestControlOfEntity(entity)
    end
    return true
end

local function tryEnterSeat(seatIndex)
    SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
    Wait(0)
    return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
end

local function getFirstFreeSeat(v)
    local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
    if not numSeats or numSeats <= 0 then return -1 end
    for seat = 0, (numSeats - 2) do
        if IsVehicleSeatFree(v, seat) then return seat end
    end
    return -1
end

ClearPedTasksImmediately(playerPed)
SetVehicleDoorsLocked(targetVehicle, 1)
SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
    TaskLeaveVehicle(playerPed, targetVehicle, 0)
    Wait(500)
    
    SetEntityCoordsNoOffset(targetVehicle, destCoords.x, destCoords.y, destCoords.z, false, false, false)
    
    Wait(100)
    SetEntityCoordsNoOffset(playerPed, savedCoords.x, savedCoords.y, savedCoords.z, false, false, false)
    SetEntityHeading(playerPed, savedHeading)
    
    return
end

if GetPedInVehicleSeat(targetVehicle, -1) == playerPed then
    TaskLeaveVehicle(playerPed, targetVehicle, 0)
    Wait(500)
    
    SetEntityCoordsNoOffset(targetVehicle, destCoords.x, destCoords.y, destCoords.z, false, false, false)
    
    Wait(100)
    SetEntityCoordsNoOffset(playerPed, savedCoords.x, savedCoords.y, savedCoords.z, false, false, false)
    SetEntityHeading(playerPed, savedHeading)
    
    return
end

local fallbackSeat = getFirstFreeSeat(targetVehicle)
if fallbackSeat ~= -1 and tryEnterSeat(fallbackSeat) then
    local drv = GetPedInVehicleSeat(targetVehicle, -1)
    if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
        RequestControl(drv, 750)
        ClearPedTasksImmediately(drv)
        SetEntityAsMissionEntity(drv, true, true)
        SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
        Wait(50)
        DeleteEntity(drv)
        
        for i=1,80 do
            local occ = GetPedInVehicleSeat(targetVehicle, -1)
            if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
            Wait(0)
        end
    end
    
    for attempt = 1, 30 do
        if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
            TaskLeaveVehicle(playerPed, targetVehicle, 0)
            Wait(500)
            
            SetEntityCoordsNoOffset(targetVehicle, destCoords.x, destCoords.y, destCoords.z, false, false, false)
            
            Wait(100)
            SetEntityCoordsNoOffset(playerPed, savedCoords.x, savedCoords.y, savedCoords.z, false, false, false)
            SetEntityHeading(playerPed, savedHeading)
            
            return
        end
        Wait(0)
    end
end
        ]], targetServerId, tpLocation)
        
        Susano.InjectResource("any", WrapWithVehicleHooks(code))
    end
end

function Menu.ActionWarpVehicle()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
local targetServerId = %d

local targetPlayerId = nil
for _, player in ipairs(GetActivePlayers()) do
    if GetPlayerServerId(player) == targetServerId then
        targetPlayerId = player
        break
    end
end

if not targetPlayerId then
    return
end

local targetPed = GetPlayerPed(targetPlayerId)
if not DoesEntityExist(targetPed) then
    return
end

if not IsPedInAnyVehicle(targetPed, false) then
    return
end

local targetVehicle = GetVehiclePedIsIn(targetPed, false)
if not DoesEntityExist(targetVehicle) then
    return
end

local playerPed = PlayerPedId()

local function RequestControl(entity, timeoutMs)
    if not entity or not DoesEntityExist(entity) then return false end
    local start = GetGameTimer()
    NetworkRequestControlOfEntity(entity)
    while not NetworkHasControlOfEntity(entity) do
        Wait(0)
        if GetGameTimer() - start > (timeoutMs or 500) then
            return false
        end
        NetworkRequestControlOfEntity(entity)
    end
    return true
end

local function tryEnterSeat(seatIndex)
    SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
    Wait(0)
    return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
end

local function getFirstFreeSeat(v)
    local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
    if not numSeats or numSeats <= 0 then return -1 end
    for seat = 0, (numSeats - 2) do
        if IsVehicleSeatFree(v, seat) then return seat end
    end
    return -1
end

ClearPedTasksImmediately(playerPed)
SetVehicleDoorsLocked(targetVehicle, 1)
SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
    return
end

if GetPedInVehicleSeat(targetVehicle, -1) == playerPed then
    return
end

local fallbackSeat = getFirstFreeSeat(targetVehicle)
if fallbackSeat ~= -1 and tryEnterSeat(fallbackSeat) then
    local drv = GetPedInVehicleSeat(targetVehicle, -1)
    if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
        RequestControl(drv, 750)
        ClearPedTasksImmediately(drv)
        SetEntityAsMissionEntity(drv, true, true)
        SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
        Wait(50)
        DeleteEntity(drv)
        
        for i=1,80 do
            local occ = GetPedInVehicleSeat(targetVehicle, -1)
            if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
            Wait(0)
        end
    end
    
    for attempt = 1, 30 do
        if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
            return
        end
        Wait(0)
    end
end
        ]], targetServerId)
        
        Susano.InjectResource("any", WrapWithVehicleHooks(code))
    end
end

function Menu.ActionWarpBoost()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
CreateThread(function()
    if rawget(_G, 'warp_boost_player_busy') then return end
    rawset(_G, 'warp_boost_player_busy', true)
    
    local targetServerId = %d
    
    local targetPlayerId = nil
    for _, player in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(player) == targetServerId then
            targetPlayerId = player
            break
        end
    end
    
    if not targetPlayerId then
        rawset(_G, 'warp_boost_player_busy', false)
        return
    end
    
    local targetPed = GetPlayerPed(targetPlayerId)
    if not DoesEntityExist(targetPed) then
        rawset(_G, 'warp_boost_player_busy', false)
        return
    end
    
    if not IsPedInAnyVehicle(targetPed, false) then
        rawset(_G, 'warp_boost_player_busy', false)
        return
    end
    
    local targetVehicle = GetVehiclePedIsIn(targetPed, false)
    if not DoesEntityExist(targetVehicle) then
        rawset(_G, 'warp_boost_player_busy', false)
        return
    end
    
    local playerPed = PlayerPedId()
    local initialCoords = GetEntityCoords(playerPed)
    local initialHeading = GetEntityHeading(playerPed)
    
    local warpBoostCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    SetCamCoord(warpBoostCam, camCoords.x, camCoords.y, camCoords.z)
    SetCamRot(warpBoostCam, camRot.x, camRot.y, camRot.z, 2)
    SetCamFov(warpBoostCam, GetGameplayCamFov())
    SetCamActive(warpBoostCam, true)
    RenderScriptCams(true, false, 0, true, true)
    
    local playerModel = GetEntityModel(playerPed)
    RequestModel(playerModel)
    local timeout = 0
    while not HasModelLoaded(playerModel) and timeout < 50 do
        Wait(50)
        timeout = timeout + 1
    end
    
    local groundZ = initialCoords.z
    local rayHandle = StartShapeTestRay(initialCoords.x, initialCoords.y, initialCoords.z + 2.0, initialCoords.x, initialCoords.y, initialCoords.z - 100.0, 1, 0, 0)
    local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)
    if hit then
        groundZ = hitCoords.z
    end
    
    local clonePed = CreatePed(4, playerModel, initialCoords.x, initialCoords.y, groundZ, initialHeading, false, false)
    SetEntityCollision(clonePed, false, false)
    FreezeEntityPosition(clonePed, true)
    SetEntityInvincible(clonePed, true)
    SetBlockingOfNonTemporaryEvents(clonePed, true)
    SetPedCanRagdoll(clonePed, false)
    ClonePedToTarget(playerPed, clonePed)
    
    SetEntityVisible(playerPed, false, false)
    SetEntityLocallyInvisible(playerPed)
    
    local function RequestControl(entity, timeoutMs)
        if not entity or not DoesEntityExist(entity) then return false end
        local start = GetGameTimer()
        NetworkRequestControlOfEntity(entity)
        while not NetworkHasControlOfEntity(entity) do
            Wait(0)
            if GetGameTimer() - start > (timeoutMs or 500) then
                return false
            end
            NetworkRequestControlOfEntity(entity)
        end
        return true
    end
    
    RequestControl(targetVehicle, 800)
    SetVehicleDoorsLocked(targetVehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)
    
    local function tryEnterSeat(seatIndex)
        SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
        Wait(0)
        return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
    end
    
    local function getFirstFreeSeat(v)
        local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
        if not numSeats or numSeats <= 0 then return -1 end
        for seat = 0, (numSeats - 2) do
            if IsVehicleSeatFree(v, seat) then return seat end
        end
        return -1
    end
    
    ClearPedTasksImmediately(playerPed)
    SetVehicleDoorsLocked(targetVehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)
    
    local takeoverSuccess = false
    local tStart = GetGameTimer()
    
    while (GetGameTimer() - tStart) < 1000 do
        RequestControl(targetVehicle, 400)
        
        if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
            takeoverSuccess = true
            break
        end
        
        if not IsPedInVehicle(playerPed, targetVehicle, false) then
            local fs = getFirstFreeSeat(targetVehicle)
            if fs ~= -1 then
                tryEnterSeat(fs)
            end
        end
        
        local drv = GetPedInVehicleSeat(targetVehicle, -1)
        if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
            RequestControl(drv, 400)
            ClearPedTasksImmediately(drv)
            SetEntityAsMissionEntity(drv, true, true)
            SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
            Wait(20)
            DeleteEntity(drv)
        end
        
        local t0 = GetGameTimer()
        while (GetGameTimer() - t0) < 400 do
            local occ = GetPedInVehicleSeat(targetVehicle, -1)
            if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
            Wait(0)
        end
        
        local t1 = GetGameTimer()
        while (GetGameTimer() - t1) < 500 do
            if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                takeoverSuccess = true
                break
            end
            Wait(0)
        end
        if takeoverSuccess then break end
        Wait(0)
    end
    
    if takeoverSuccess then
        if DoesEntityExist(targetVehicle) then
            FreezeEntityPosition(targetVehicle, true)
            SetVehicleEngineOn(targetVehicle, true, true, false)
            
            local targetSpeed = 140.0
            for i = 1, 4 do
                SetVehicleForwardSpeed(targetVehicle, targetSpeed)
                Wait(0)
            end
        end
        TaskLeaveVehicle(playerPed, targetVehicle, 0)
        for i = 1, 10 do
            if not IsPedInVehicle(playerPed, targetVehicle, false) then break end
            ClearPedTasksImmediately(playerPed)
            Wait(0)
        end
        
        SetEntityCoordsNoOffset(playerPed, initialCoords.x, initialCoords.y, initialCoords.z, false, false, false)
        SetEntityHeading(playerPed, initialHeading)
        Wait(50)
        
        if DoesEntityExist(targetVehicle) then
            FreezeEntityPosition(targetVehicle, false)
            NetworkRequestControlOfEntity(targetVehicle)
            
            CreateThread(function()
                local targetSpeed = 140.0
                for i = 1, 12 do
                    SetVehicleForwardSpeed(targetVehicle, targetSpeed)
                    Wait(0)
                end
            end)
        end
    end
    
    Wait(500)
    SetEntityVisible(playerPed, true, false)
    SetCamActive(warpBoostCam, false)
    if not rawget(_G, 'isSpectating') then
        RenderScriptCams(false, false, 0, true, true)
    end
    DestroyCam(warpBoostCam, true)
    if DoesEntityExist(clonePed) then
        DeleteEntity(clonePed)
    end
    SetModelAsNoLongerNeeded(playerModel)
    
    rawset(_G, 'warp_boost_player_busy', false)
end)
        ]], targetServerId)
        
        Susano.InjectResource("any", WrapWithVehicleHooks(code))
    end
end

                    Menu.WarpMode = "Classic"

                    function Menu.ActionWarp()
                        local warpMode = Menu.WarpMode or "Classic"
                        if warpMode == "Classic" then
                            Menu.ActionWarpVehicle()
                        elseif warpMode == "Boost" then
                            Menu.ActionWarpBoost()
                        end
                    end

-- Teleport Into : warp dans le véhicule de la cible comme passager
function Menu.ActionTeleportInto()
    if not Menu.SelectedPlayer then return end
    local targetServerId = Menu.SelectedPlayer

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local targetServerId = %d

            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == targetServerId then
                    targetPlayerId = player
                    break
                end
            end
            if not targetPlayerId then return end

            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) then return end

            local targetVeh = GetVehiclePedIsIn(targetPed, false)
            if not targetVeh or targetVeh == 0 then
                -- Pas en véhicule : TP directement à côté
                local tc = GetEntityCoords(targetPed)
                SetEntityCoordsNoOffset(PlayerPedId(), tc.x + 1.0, tc.y, tc.z, false, false, false)
                return
            end

            local playerPed = PlayerPedId()

            -- Chercher un siège libre (-1=driver, 0=passager avant, 1-2=arrière)
            local seatFound = nil
            for seat = 0, GetVehicleMaxNumberOfPassengers(targetVeh) - 1 do
                if IsVehicleSeatFree(targetVeh, seat) then
                    seatFound = seat
                    break
                end
            end

            if not seatFound then
                -- Aucun siège libre : éjecter le passager du siège 0
                local passengerPed = GetPedInVehicleSeat(targetVeh, 0)
                if passengerPed and passengerPed ~= 0 and DoesEntityExist(passengerPed) then
                    TaskLeaveVehicle(passengerPed, targetVeh, 16)
                    Wait(500)
                end
                seatFound = 0
            end

            -- TP au véhicule puis warp dans le siège
            local vc = GetEntityCoords(targetVeh)
            SetEntityCoordsNoOffset(playerPed, vc.x, vc.y, vc.z, false, false, false)
            Wait(100)
            SetPedIntoVehicle(playerPed, targetVeh, seatFound)
        ]], targetServerId))
    end
end

function Menu.ActionRemoteVehicle()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([=[
CreateThread(function()
    local targetServerId = %d

    local stopFn = rawget(_G, 'remote_vehicle_stop')
    if stopFn and type(stopFn) == 'function' then
        stopFn()
        return
    end

    rawset(_G, 'remote_vehicle_active', true)

    local targetPlayerId = nil
    for _, player in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(player) == targetServerId then
            targetPlayerId = player
            break
        end
    end
    if not targetPlayerId then
        rawset(_G, 'remote_vehicle_active', false)
        return
    end

    local targetPed = GetPlayerPed(targetPlayerId)
    if not DoesEntityExist(targetPed) or not IsPedInAnyVehicle(targetPed, false) then
        rawset(_G, 'remote_vehicle_active', false)
        return
    end

    local targetVehicle = GetVehiclePedIsIn(targetPed, false)
    if not DoesEntityExist(targetVehicle) then
        rawset(_G, 'remote_vehicle_active', false)
        return
    end

    local playerPed = PlayerPedId()
    local initialCoords = GetEntityCoords(playerPed)
    local initialHeading = GetEntityHeading(playerPed)

    local function RequestControl(entity, timeoutMs)
        if not entity or not DoesEntityExist(entity) then return false end
        local start = GetGameTimer()
        NetworkRequestControlOfEntity(entity)
        while not NetworkHasControlOfEntity(entity) do
            Wait(0)
            if GetGameTimer() - start > (timeoutMs or 800) then
                return false
            end
            NetworkRequestControlOfEntity(entity)
        end
        return true
    end

    local function tryEnterSeat(seatIndex)
        SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
        Wait(0)
        return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
    end

    local function getFirstFreeSeat(v)
        local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
        if not numSeats or numSeats <= 0 then return -1 end
        for seat = 0, (numSeats - 2) do
            if IsVehicleSeatFree(v, seat) then return seat end
        end
        return -1
    end

    RequestControl(targetVehicle, 1200)
    SetVehicleDoorsLocked(targetVehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)
    ClearPedTasksImmediately(playerPed)

    local takeoverSuccess = false
    local tStart = GetGameTimer()
    while (GetGameTimer() - tStart) < 1200 do
        RequestControl(targetVehicle, 400)

        if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
            takeoverSuccess = true
            break
        end

        if not IsPedInVehicle(playerPed, targetVehicle, false) then
            local fs = getFirstFreeSeat(targetVehicle)
            if fs ~= -1 then
                tryEnterSeat(fs)
            end
        end

        local drv = GetPedInVehicleSeat(targetVehicle, -1)
        if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
            RequestControl(drv, 400)
            ClearPedTasksImmediately(drv)
            SetEntityAsMissionEntity(drv, true, true)
            SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
            Wait(20)
            DeleteEntity(drv)
        end

        local t0 = GetGameTimer()
        while (GetGameTimer() - t0) < 400 do
            local occ = GetPedInVehicleSeat(targetVehicle, -1)
            if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
            Wait(0)
        end

        if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
            takeoverSuccess = true
            break
        end
        Wait(0)
    end

    if not takeoverSuccess then
        rawset(_G, 'remote_vehicle_active', false)
        return
    end

    TaskLeaveVehicle(playerPed, targetVehicle, 16)
    local leaveT = GetGameTimer()
    while IsPedInVehicle(playerPed, targetVehicle, false) and (GetGameTimer() - leaveT) < 2000 do
        ClearPedTasksImmediately(playerPed)
        Wait(0)
    end

    SetEntityCoordsNoOffset(playerPed, initialCoords.x, initialCoords.y, initialCoords.z, false, false, false)
    SetEntityHeading(playerPed, initialHeading)

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, GetGameplayCamFov())
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    local running = true
    rawset(_G, 'remote_vehicle_stop', function()
        running = false
    end)

    local throttle = 0.0
    local steerState = 0.0
    local maxSpeed = 22.0

    local yaw = GetEntityHeading(targetVehicle) %% 360.0
    local pitch = 10.0
    local dist = 8.0
    local height = 2.8
    
    local smoothCamX = 0.0
    local smoothCamY = 0.0
    local smoothCamZ = 0.0

    local function clamp(v, mn, mx)
        if v < mn then return mn end
        if v > mx then return mx end
        return v
    end

    while running do
        Wait(0)

        if not DoesEntityExist(targetVehicle) then
            break
        end

        RequestControl(targetVehicle, 0)
        SetVehicleEngineOn(targetVehicle, true, true, false)

        if IsControlJustPressed(0, 73) then
            break
        end

        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)

        local lookLR = GetControlNormal(0, 1)
        local lookUD = GetControlNormal(0, 2)
        if lookLR ~= 0.0 or lookUD ~= 0.0 then
            yaw = (yaw + (lookLR * 4.5)) %% 360.0
            pitch = clamp(pitch + (lookUD * 3.5), -70.0, 70.0)
        end

        local vehCoords = GetEntityCoords(targetVehicle)
        local yawRad = math.rad(yaw)
        local pitchRad = math.rad(pitch)
        local dirX = math.sin(yawRad)
        local dirY = math.cos(yawRad)
        local cosP = math.cos(pitchRad)
        local sinP = math.sin(pitchRad)

        local targetCamX = vehCoords.x - (dirX * dist * cosP)
        local targetCamY = vehCoords.y - (dirY * dist * cosP)
        local targetCamZ = vehCoords.z + height + (dist * sinP)

        smoothCamX = smoothCamX + (targetCamX - smoothCamX) * 0.15
        smoothCamY = smoothCamY + (targetCamY - smoothCamY) * 0.15
        smoothCamZ = smoothCamZ + (targetCamZ - smoothCamZ) * 0.15

        SetCamCoord(cam, smoothCamX, smoothCamY, smoothCamZ)
        PointCamAtEntity(cam, targetVehicle, 0.0, 0.0, 0.0, true)

        local throttleIn = 0.0
        if IsControlPressed(0, 32) then throttleIn = 1.0 end
        if IsControlPressed(0, 33) then throttleIn = -1.0 end
        throttle = throttle + (throttleIn - throttle) * 0.12

        local trim = 0.0
        if IsControlPressed(0, 34) then trim = trim + 1.0 end
        if IsControlPressed(0, 35) then trim = trim - 1.0 end

        local desiredHeading = yaw
        local vehHeading = GetEntityHeading(targetVehicle)
        local diff = desiredHeading - vehHeading
        while diff > 180.0 do diff = diff - 360.0 end
        while diff < -180.0 do diff = diff + 360.0 end

        local steerIn = (diff / 55.0) + (trim * 0.35)
        if steerIn > 1.0 then steerIn = 1.0 end
        if steerIn < -1.0 then steerIn = -1.0 end
        steerState = steerState + (steerIn - steerState) * 0.16

        SetVehicleSteeringAngle(targetVehicle, steerState * 25.0)

        local speed = GetEntitySpeed(targetVehicle)
        local vel = GetEntityVelocity(targetVehicle)

        local forceMul = 6.0
        local brakeMul = 9.0
        local dragMul = 0.18

        if speed > maxSpeed then
            ApplyForceToEntity(targetVehicle, 1, -vel.x * 0.45, -vel.y * 0.45, 0.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
        end

        if throttle > 0.05 then
            if speed < maxSpeed then
                ApplyForceToEntity(targetVehicle, 1, dirX * (forceMul * throttle), dirY * (forceMul * throttle), 0.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
            end
        elseif throttle < -0.05 then
            ApplyForceToEntity(targetVehicle, 1, -dirX * (brakeMul * -throttle), -dirY * (brakeMul * -throttle), 0.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
        end

        ApplyForceToEntity(targetVehicle, 1, -vel.x * dragMul, -vel.y * dragMul, 0.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
    end

    rawset(_G, 'remote_vehicle_stop', nil)
    rawset(_G, 'remote_vehicle_active', false)

    SetCamActive(cam, false)
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, true)
end)
]=], targetServerId)
        
        Susano.InjectResource("any", WrapWithVehicleHooks(code))
    end
end

function Menu.ActionStealVehicle()
    if not Menu.SelectedPlayer then return end
    
    local targetServerId = Menu.SelectedPlayer
    
    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
CreateThread(function()
    if rawget(_G, 'warp_boost_busy') then return end
    rawset(_G, 'warp_boost_busy', true)
    
    local targetServerId = %d
    
    local targetPlayerId = nil
    for _, player in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(player) == targetServerId then
            targetPlayerId = player
            break
        end
    end
    
    if not targetPlayerId then
        rawset(_G, 'warp_boost_busy', false)
        return
    end
    
    local targetPed = GetPlayerPed(targetPlayerId)
    if not DoesEntityExist(targetPed) then
        rawset(_G, 'warp_boost_busy', false)
        return
    end
    
    if not IsPedInAnyVehicle(targetPed, false) then
        rawset(_G, 'warp_boost_busy', false)
        return
    end
    
    local targetVehicle = GetVehiclePedIsIn(targetPed, false)
    if not DoesEntityExist(targetVehicle) then
        rawset(_G, 'warp_boost_busy', false)
        return
    end
    
    local playerPed = PlayerPedId()
    local initialCoords = GetEntityCoords(playerPed)
    local initialHeading = GetEntityHeading(playerPed)
    
    local function RequestControl(entity, timeoutMs)
        if not entity or not DoesEntityExist(entity) then return false end
        local start = GetGameTimer()
        NetworkRequestControlOfEntity(entity)
        while not NetworkHasControlOfEntity(entity) do
            Wait(0)
            if GetGameTimer() - start > (timeoutMs or 500) then
                return false
            end
            NetworkRequestControlOfEntity(entity)
        end
        return true
    end
    
    RequestControl(targetVehicle, 800)
    SetVehicleDoorsLocked(targetVehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)
    
    local function tryEnterSeat(seatIndex)
        SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
        Wait(0)
        return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
    end
    
    local function getFirstFreeSeat(v)
        local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
        if not numSeats or numSeats <= 0 then return -1 end
        for seat = 0, (numSeats - 2) do
            if IsVehicleSeatFree(v, seat) then return seat end
        end
        return -1
    end
    
    ClearPedTasksImmediately(playerPed)
    SetVehicleDoorsLocked(targetVehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)
    
    local takeoverSuccess = false
    local tStart = GetGameTimer()
    
    while (GetGameTimer() - tStart) < 1000 do
        RequestControl(targetVehicle, 400)
        
        if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
            takeoverSuccess = true
            break
        end
        
        if not IsPedInVehicle(playerPed, targetVehicle, false) then
            local fs = getFirstFreeSeat(targetVehicle)
            if fs ~= -1 then
                tryEnterSeat(fs)
            end
        end
        
        local drv = GetPedInVehicleSeat(targetVehicle, -1)
        if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
            RequestControl(drv, 400)
            ClearPedTasksImmediately(drv)
            SetEntityAsMissionEntity(drv, true, true)
            SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
            Wait(20)
            DeleteEntity(drv)
        end
        
        local t0 = GetGameTimer()
        while (GetGameTimer() - t0) < 400 do
            local occ = GetPedInVehicleSeat(targetVehicle, -1)
            if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
            Wait(0)
        end
        
        local t1 = GetGameTimer()
        while (GetGameTimer() - t1) < 500 do
            if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                takeoverSuccess = true
                break
            end
            Wait(0)
        end
        if takeoverSuccess then break end
        Wait(0)
    end
    
    if takeoverSuccess then
        if DoesEntityExist(targetVehicle) and IsPedInVehicle(playerPed, targetVehicle, false) then
            RequestControl(targetVehicle, 1000)
            if NetworkHasControlOfEntity(targetVehicle) then
                FreezeEntityPosition(targetVehicle, true)
                SetVehicleEngineOn(targetVehicle, true, true, false)
                SetEntityCoordsNoOffset(targetVehicle, initialCoords.x, initialCoords.y, initialCoords.z + 1.0, false, false, false, false)
                SetEntityHeading(targetVehicle, initialHeading)
                SetEntityVelocity(targetVehicle, 0.0, 0.0, 0.0)
                Wait(100)
                FreezeEntityPosition(targetVehicle, false)
                SetVehicleOnGroundProperly(targetVehicle)
            end
        end
    end
    
    rawset(_G, 'warp_boost_busy', false)
end)
        ]], targetServerId)
        
        Susano.InjectResource("any", WrapWithVehicleHooks(code))
    end
end

function Menu.ActionDeleteVehicle()
    if not Menu.SelectedPlayer then return end

    local targetServerId = Menu.SelectedPlayer

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        local code = string.format([[
CreateThread(function()
    if rawget(_G, 'warp_boost_busy') then return end
    rawset(_G, 'warp_boost_busy', true)

    local targetServerId = %d

    local targetPlayerId = nil
    for _, player in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(player) == targetServerId then
            targetPlayerId = player
            break
    end
end

    if not targetPlayerId then
        rawset(_G, 'warp_boost_busy', false)
        return
    end

    local targetPed = GetPlayerPed(targetPlayerId)
    if not DoesEntityExist(targetPed) then
        rawset(_G, 'warp_boost_busy', false)
        return
    end

    if not IsPedInAnyVehicle(targetPed, false) then
        rawset(_G, 'warp_boost_busy', false)
        return
    end

    local targetVehicle = GetVehiclePedIsIn(targetPed, false)
    if not DoesEntityExist(targetVehicle) then
        rawset(_G, 'warp_boost_busy', false)
        return
    end

    local playerPed = PlayerPedId()
    local initialCoords = GetEntityCoords(playerPed)
    local initialHeading = GetEntityHeading(playerPed)

    local function RequestControl(entity, timeoutMs)
        if not entity or not DoesEntityExist(entity) then return false end
        local start = GetGameTimer()
        NetworkRequestControlOfEntity(entity)
        while not NetworkHasControlOfEntity(entity) do
            Wait(0)
            if GetGameTimer() - start > (timeoutMs or 500) then
                return false
            end
            NetworkRequestControlOfEntity(entity)
        end
        return true
    end

    RequestControl(targetVehicle, 800)
    SetVehicleDoorsLocked(targetVehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

    local function tryEnterSeat(seatIndex)
        SetPedIntoVehicle(playerPed, targetVehicle, seatIndex)
        Wait(0)
        return IsPedInVehicle(playerPed, targetVehicle, false) and GetPedInVehicleSeat(targetVehicle, seatIndex) == playerPed
    end

    local function getFirstFreeSeat(v)
        local numSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v))
        if not numSeats or numSeats <= 0 then return -1 end
        for seat = 0, (numSeats - 2) do
            if IsVehicleSeatFree(v, seat) then return seat end
        end
        return -1
    end

    ClearPedTasksImmediately(playerPed)
    SetVehicleDoorsLocked(targetVehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)

    local takeoverSuccess = false
    local tStart = GetGameTimer()

    while (GetGameTimer() - tStart) < 1000 do
        RequestControl(targetVehicle, 400)

        if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
            takeoverSuccess = true
            break
        end

        if not IsPedInVehicle(playerPed, targetVehicle, false) then
            local fs = getFirstFreeSeat(targetVehicle)
            if fs ~= -1 then
                tryEnterSeat(fs)
            end
        end

        local drv = GetPedInVehicleSeat(targetVehicle, -1)
        if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
            RequestControl(drv, 400)
            ClearPedTasksImmediately(drv)
            SetEntityAsMissionEntity(drv, true, true)
            SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
            Wait(20)
            DeleteEntity(drv)
        end

        local t0 = GetGameTimer()
        while (GetGameTimer() - t0) < 400 do
            local occ = GetPedInVehicleSeat(targetVehicle, -1)
            if occ == 0 or (occ ~= 0 and not DoesEntityExist(occ)) then break end
            Wait(0)
        end

        local t1 = GetGameTimer()
        while (GetGameTimer() - t1) < 500 do
            if IsVehicleSeatFree(targetVehicle, -1) and tryEnterSeat(-1) then
                takeoverSuccess = true
                break
            end
            Wait(0)
        end
        if takeoverSuccess then break end
        Wait(0)
    end

    if takeoverSuccess then
        if DoesEntityExist(targetVehicle) then
            RequestControl(targetVehicle, 1000)
            SetEntityAsMissionEntity(targetVehicle, true, true)
            DeleteEntity(targetVehicle)

            SetEntityCoordsNoOffset(playerPed, initialCoords.x, initialCoords.y, initialCoords.z, false, false, false, false)
            SetEntityHeading(playerPed, initialHeading)
        end
    end

    local dist = #(GetEntityCoords(playerPed) - initialCoords)
    if dist > 10.0 then
        SetEntityCoordsNoOffset(playerPed, initialCoords.x, initialCoords.y, initialCoords.z, false, false, false, false)
    end

    rawset(_G, 'warp_boost_busy', false)
end)
        ]], targetServerId)

        Susano.InjectResource("any", WrapWithVehicleHooks(code))
    end
end

do
    Actions.bugPlayerItem = FindItem("Online", "Troll", "Bug Player")
    if Actions.bugPlayerItem then
        Actions.bugPlayerItem.onClick = function(index, option)
            Menu.BugPlayerMode = option
            Menu.ActionBugPlayer()
    end
end

    Actions.ramPlayerItem = FindItem("Online", "Troll", "Ram Player")
    if Actions.ramPlayerItem then
        Actions.ramPlayerItem.onClick = function()
            Menu.ActionRamPlayer()
        end
    end

    Actions.crushItem = FindItem("Online", "Troll", "Crush")
    if Actions.crushItem then
        Actions.crushItem.onClick = function(index, option)
                            Menu.CrushMode = option
            Menu.ActionCrush()
    end
end

-- ============================================
-- PED FLOOD
-- ============================================

local pedFloodModel = "player_one"

function Menu.ActionPedFlood()
    if not Menu.SelectedPlayer then
        print("[PedFlood] ERROR: No player selected")
        return
    end

    local targetServerId = Menu.SelectedPlayer
    print("[PedFlood] Starting - target server ID: " .. tostring(targetServerId))

    if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
        print("[PedFlood] ERROR: Susano.InjectResource not available")
        return
    end

    print("[PedFlood] Injecting into resource...")

    Susano.InjectResource("any", string.format([[
        print("[PedFlood:Inject] Code injected, starting...")

        local susano = rawget(_G, "Susano")
        print("[PedFlood:Inject] Susano ref: " .. tostring(susano))
        if susano then
            print("[PedFlood:Inject] CreateSpoofedPed: " .. tostring(susano.CreateSpoofedPed))
        end

        local targetServerId = %d
        local spawnModel = "%s"

        -- Resolve target
        local targetPlayerId = nil
        for _, player in ipairs(GetActivePlayers()) do
            if GetPlayerServerId(player) == targetServerId then
                targetPlayerId = player
                break
            end
        end
        if not targetPlayerId then
            print("[PedFlood:Inject] ERROR: Target player not found")
            return
        end

        local targetPed = GetPlayerPed(targetPlayerId)
        if not DoesEntityExist(targetPed) then
            print("[PedFlood:Inject] ERROR: Target ped doesn't exist")
            return
        end
        print("[PedFlood:Inject] Target resolved: player=" .. tostring(targetPlayerId) .. " ped=" .. tostring(targetPed))

        -- Load model
        local modelHash = GetHashKey(spawnModel)
        print("[PedFlood:Inject] Model hash: " .. tostring(modelHash))
        RequestModel(modelHash)
        local t = 50
        while not HasModelLoaded(modelHash) and t > 0 do Wait(10); t = t - 1 end

        if not HasModelLoaded(modelHash) then
            print("[PedFlood:Inject] ERROR: Model failed to load after 500ms")
            return
        end
        print("[PedFlood:Inject] Model loaded OK")

        -- Kill previous flood
        if _G._pedFloodActive then
            print("[PedFlood:Inject] Killing previous flood...")
            _G._pedFloodActive = false
            Wait(300)
        end

        -- Init state
        _G._pedFloodStore = {}
        _G._pedFloodActive = true
        SetPedPopulationBudget(3)

        local PED_CAP = 2000
        local totalSpawned = 0
        local totalFailed = 0

        -- =============================================
        -- PHASE 1 : RETASK AMBIENT PEDS
        -- =============================================
        CreateThread(function()
            local pool = GetGamePool("CPed")
            local myPed = PlayerPedId()
            local retasked = 0
            for i, ped in ipairs(pool) do
                if DoesEntityExist(ped) and ped ~= myPed and ped ~= targetPed
                   and not IsPedAPlayer(ped) and not IsPedDeadOrDying(ped, true) then
                    ClearPedTasks(ped)
                    SetPedKeepTask(ped, true)
                    SetBlockingOfNonTemporaryEvents(ped, true)
                    SetPedCombatAttributes(ped, 46, true)
                    TaskCombatPed(ped, targetPed, 0, 16)
                    retasked = retasked + 1
                    if retasked %% 10 == 0 then Wait(0) end
                end
            end
            print("[PedFlood:Phase1] Retasked " .. retasked .. " ambient peds")
        end)

        -- =============================================
        -- PHASE 2 : SPAWN LOOP
        -- =============================================
        print("[PedFlood:Phase2] Starting 4 spawn threads...")

        for threadIdx = 1, 4 do
            CreateThread(function()
                Wait(threadIdx * 50)
                print("[PedFlood:Thread" .. threadIdx .. "] Started")

                while _G._pedFloodActive do
                    local store = _G._pedFloodStore
                    if store and #store >= PED_CAP then
                        Wait(1000)
                        -- Purge dead handles
                        local newStore = {}
                        for i, p in ipairs(store) do
                            if p and DoesEntityExist(p) then
                                newStore[#newStore + 1] = p
                            end
                            if i %% 50 == 0 then Wait(0) end
                        end
                        _G._pedFloodStore = newStore
                        print("[PedFlood:Thread" .. threadIdx .. "] Purged, now " .. #newStore .. " alive")
                    else
                        local tPed = GetPlayerPed(targetPlayerId)
                        if not DoesEntityExist(tPed) then
                            print("[PedFlood:Thread" .. threadIdx .. "] Target gone, stopping")
                            break
                        end
                        local tc = GetEntityCoords(tPed)

                        for b = 1, 3 do
                            local angle = math.random() * math.pi * 2
                            local radius = 1.0 + math.random() * 7.0
                            local x = tc.x + math.cos(angle) * radius
                            local y = tc.y + math.sin(angle) * radius

                            -- Ground Z check : évite spawn sous la map
                            local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, tc.z + 5.0, false)
                            local z = foundGround and groundZ or tc.z

                            local heading = math.random(0, 360) + 0.0

                            -- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
                            -- SPAWN : arg7 = isNetwork = false (local only)
                            -- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
                            local ped = 0
                            if susano and type(susano.CreateSpoofedPed) == "function" then
                                ped = susano.CreateSpoofedPed(4, modelHash, x, y, z, heading, true, false)
                            else
                                ped = CreatePed(4, modelHash, x, y, z, heading, true, false)
                            end

                            if ped and ped ~= 0 and DoesEntityExist(ped) then
                                SetEntityAsMissionEntity(ped, true, true)
                                _G._pedFloodStore[#_G._pedFloodStore + 1] = ped

                                -- Config ped : visible, combat, anti-GC
                                SetBlockingOfNonTemporaryEvents(ped, true)
                                SetPedKeepTask(ped, true)
                                SetPedCombatAttributes(ped, 46, true)
                                SetPedCombatAttributes(ped, 5, true)
                                SetPedFleeAttributes(ped, 0, false)
                                SetPedSuffersCriticalHits(ped, false)
                                SetEntityMaxHealth(ped, 500)
                                SetEntityHealth(ped, 500)
                                DisablePedPainAudio(ped, true)

                                TaskCombatPed(ped, tPed, 0, 16)
                                totalSpawned = totalSpawned + 1
                            else
                                totalFailed = totalFailed + 1
                            end

                            -- Yield après chaque ped (anti script-hang)
                            Wait(10)
                        end

                        Wait(50)
                    end
                end

                print("[PedFlood:Thread" .. threadIdx .. "] Stopped. Spawned=" .. totalSpawned .. " Failed=" .. totalFailed)
            end)
        end

        -- Auto-stop 120s
        CreateThread(function()
            Wait(120000)
            _G._pedFloodActive = false
            print("[PedFlood] Auto-stop triggered. Total in store: " .. tostring(_G._pedFloodStore and #_G._pedFloodStore or 0))
        end)

        -- =============================================
        -- PHASE 3 : CLEANUP AUTO
        -- =============================================
        CreateThread(function()
            while _G._pedFloodActive do Wait(1000) end
            print("[PedFlood:Cleanup] Waiting 10s grace period...")
            Wait(10000)

            local store = _G._pedFloodStore
            local deleted = 0
            if store then
                for idx = 1, #store do
                    local ped = store[idx]
                    if ped and DoesEntityExist(ped) then
                        SetEntityAsMissionEntity(ped, true, true)
                        DeleteEntity(ped)
                        deleted = deleted + 1
                    end
                    if idx %% 15 == 0 then Wait(0) end
                end
            end
            _G._pedFloodStore = {}
            SetPedPopulationBudget(2)
            SetModelAsNoLongerNeeded(modelHash)
            print("[PedFlood:Cleanup] Done. Deleted " .. deleted .. " entities")
        end)

        print("[PedFlood:Inject] All threads launched")
    ]], targetServerId, pedFloodModel))

    print("[PedFlood] InjectResource call completed")
end

Actions.pedFloodItem = FindItem("Online", "Troll", "Crash Method")
if Actions.pedFloodItem then
    Actions.pedFloodItem.onClick = function()
        _Stealth.blockAC = true
        Menu.ActionPedFlood()
        Citizen.SetTimeout(140000, function()
            if _Stealth._acUsers <= 0 then _Stealth.blockAC = false end
        end)
    end
end

-- Ped Armed : spawn un ped armé d'un fusil à pompe sur la cible
-- Ragdoll : force le ragdoll sur la cible via Susano.RequestRagdoll
function Menu.ActionRagdoll()
    if not Menu.SelectedPlayer then return end
    local targetServerId = Menu.SelectedPlayer

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local targetServerId = %d

            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == targetServerId then
                    targetPlayerId = player
                    break
                end
            end
            if not targetPlayerId then return end

            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) then return end

            local guid = GetEntityGuid(targetPed)
            if guid and guid ~= 0 then
                Susano.RequestRagdoll(guid)
            end
        ]], targetServerId))
    end
end

function Menu.ActionPedArmed()
    if not Menu.SelectedPlayer then return end

    local targetServerId = Menu.SelectedPlayer

    if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
        Susano.InjectResource("any", string.format([[
            local targetServerId = %d

            local targetPlayerId = nil
            for _, player in ipairs(GetActivePlayers()) do
                if GetPlayerServerId(player) == targetServerId then
                    targetPlayerId = player
                    break
                end
            end
            if not targetPlayerId then return end

            local targetPed = GetPlayerPed(targetPlayerId)
            if not DoesEntityExist(targetPed) then return end
            local tc = GetEntityCoords(targetPed)

            -- Spoof en clown côté serveur
            local clownHash = 0x3C438FD2 -- s_m_y_clown_01
            RequestModel(clownHash)
            local tw = 50
            while not HasModelLoaded(clownHash) and tw > 0 do Wait(10); tw = tw - 1 end
            Susano.SpoofPed(clownHash, true)

            -- Modèle réel : civil basique (discret)
            local modelHash = GetHashKey("a_m_m_hillbilly_01")
            RequestModel(modelHash)
            local t = 50
            while not HasModelLoaded(modelHash) and t > 0 do Wait(10); t = t - 1 end
            if not HasModelLoaded(modelHash) then Susano.SpoofPed(0, false) return end

            -- Spawn juste derrière la cible (1.5m)
            local heading = GetEntityHeading(targetPed)
            local rad = math.rad(heading)
            local x = tc.x - math.sin(rad) * 1.5
            local y = tc.y + math.cos(rad) * 1.5

            local ped = CreatePed(4, modelHash, x, y, tc.z, heading + 180.0, true, false)
            if ped and ped ~= 0 then
                SetEntityAsMissionEntity(ped, true, true)
                SetEntityMaxHealth(ped, 5000)
                SetEntityHealth(ped, 5000)
                SetPedSuffersCriticalHits(ped, false)
                SetPedCombatAttributes(ped, 46, true)
                SetPedCombatAttributes(ped, 5, true)
                SetPedFleeAttributes(ped, 0, false)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetPedKeepTask(ped, true)
                -- Fusil à pompe
                GiveWeaponToPed(ped, 0x1D073A89, 250, false, true) -- WEAPON_PUMPSHOTGUN
                -- Tir immédiat sur la cible
                TaskCombatPed(ped, targetPed, 0, 16)
            end

            -- Désactiver le spoof après spawn
            Wait(500)
            Susano.SpoofPed(0, false)

            SetModelAsNoLongerNeeded(modelHash)
            SetModelAsNoLongerNeeded(clownHash)
        ]], targetServerId))
    end
end

Actions.ragdollItem = FindItem("Online", "Troll", "Ragdoll")
if Actions.ragdollItem then
    Actions.ragdollItem.onClick = function()
        Menu.ActionRagdoll()
    end
end

-- [REMOVED] Actions.pedArmedItem handler (menu item deleted)
Actions.airstrikeItem = FindItem("Online", "Troll", "Airstrike")
if Actions.airstrikeItem then
    Actions.airstrikeItem.onClick = function(index, option)
        _Stealth.blockAC = true
        Menu.ActionAirstrike()
        Citizen.SetTimeout(10000, function()
            if _Stealth._acUsers <= 0 then _Stealth.blockAC = false end
        end)
    end
end

    Actions.bugVehicleItem = FindItem("Online", "Vehicle", "Bug Vehicle")
    if Actions.bugVehicleItem then
        Actions.bugVehicleItem.onClick = function(index, option)
        if option then
            Menu.BugVehicleMode = option
        end
            Menu.ActionBugVehicle()
    end
end

    Actions.warpItem = FindItem("Online", "Vehicle", "Warp")
    if Actions.warpItem then
        Actions.warpItem.onClick = function(index, option)
                            Menu.WarpMode = option
            Menu.ActionWarp()
    end
end

Actions.teleportIntoItem2 = FindItem("Online", "Vehicle", "Teleport Into")
if Actions.teleportIntoItem2 then
    Actions.teleportIntoItem2.onClick = function()
        Menu.ActionTeleportInto()
    end
end

    Actions.remoteVehicleItem = FindItem("Online", "Vehicle", "Remote Vehicle")
    if Actions.remoteVehicleItem then
        Actions.remoteVehicleItem.onClick = function()
            Menu.ActionRemoteVehicle()
    end
end

    Actions.stealVehicleItem = FindItem("Online", "Vehicle", "Steal Vehicle")
    if Actions.stealVehicleItem then
        Actions.stealVehicleItem.onClick = function()
            Menu.ActionStealVehicle()
    end
end

    Actions.npcDriveItem = FindItem("Online", "Vehicle", "NPC Drive")
    if Actions.npcDriveItem then
        Actions.npcDriveItem.onClick = function()
            Menu.ActionNPCDrive()
        end
    end

    Actions.deleteVehicleItem = FindItem("Online", "Vehicle", "Delete Vehicle")
    if Actions.deleteVehicleItem then
        Actions.deleteVehicleItem.onClick = function()
            Menu.ActionDeleteVehicle()
        end
    end

    Actions.kickVehicleItem = FindItem("Online", "Vehicle", "Kick Vehicle")
    if Actions.kickVehicleItem then
        Actions.kickVehicleItem.onClick = function(index, option)
        if option then
            Menu.KickVehicleMode = option
        end
            Menu.ActionKickVehicle()
    end
end

    Actions.removeAllTiresItem = FindItem("Online", "Vehicle", "remove all tires")
    if Actions.removeAllTiresItem then
        Actions.removeAllTiresItem.onClick = function()
            Menu.ActionRemoveAllTires()
        end
    end

    Actions.giveItem = FindItem("Online", "Vehicle", "Give")
    if Actions.giveItem then
        Actions.giveItem.onClick = function(index, option)
                            Menu.GiveMode = option
            Menu.ActionGive()
    end
end

    Actions.tpToItem = FindItem("Online", "Vehicle", "TP to")
    if Actions.tpToItem then
        Actions.tpToItem.onClick = function(index, option)
        if option then
            Menu.TPLocation = option
        end
            Menu.ActionTPTo()
        end
    end
end


CreateThread(function()
    while not Menu or not Menu.Categories do
        Wait(100)
    end
    
    local found = false
    local attempts = 0
    while not found and attempts < 50 do
        for _, cat in ipairs(Menu.Categories) do
            if cat.name == "Exploit" then
                found = true
                break
            end
        end
        if not found then
            Wait(100)
            attempts = attempts + 1
        end
    end
    
    if not found then
        return
    end
    
    Wait(500)
    
    for _, cat in ipairs(Menu.Categories) do
        if cat.name == "Exploit" and cat.tabs then
            for _, tab in ipairs(cat.tabs) do
                if tab.name == "Bypasses" and tab.items then
                    for _, item in ipairs(tab.items) do
                        if item.name == "Bypass Putin" then
                            break
                        end
                    end
                end
            end
        end
    end
    
    Actions.testItem = FindItem("Exploit", "Bypass", "Bypass Putin")
    if Actions.testItem then
        Actions.testItem.onClick = function()
            local targetResource = "Putin"
            
            if type(Susano) ~= "table" or type(Susano.InjectResource) ~= "function" then
                return
            end
            
            if not targetResource or GetResourceState(targetResource) ~= "started" then
                return
            end
            
            Susano.InjectResource(targetResource, [[
                local p = print
                local w = warn
                local e = error
                p = function() end
                w = function() end
                e = function() end
                
                if Citizen then
                    local t = Citizen.Trace
                    Citizen.Trace = function(m)
                        if m and type(m) == "string" then
                            local l = string.lower(m)
                            if string.find(l, "debug") or string.find(l, "detect") or 
                               string.find(l, "violation") or string.find(l, "cheat") or
                               string.find(l, "inject") or string.find(l, "hook") or
                               string.find(l, "susano") or string.find(l, "bypass") or
                               string.find(l, "ac:") or string.find(l, "anticheat") or
                               string.find(l, "ban") or string.find(l, "kick") or
                               string.find(l, "log") or string.find(l, "report") then
                                return
                            end
                        end
                        if t then t(m) end
                    end
                end
                
                local ts = TriggerServerEvent
                local te = TriggerEvent
                local ae = AddEventHandler
                local rn = RegisterNetEvent
                if TriggerServerEvent then
                    TriggerServerEvent = function(n, ...)
                        if n and type(n) == "string" then
                            local l = string.lower(n)
                            if string.find(l, "detect") or string.find(l, "violation") or
                               string.find(l, "cheat") or string.find(l, "ban") or
                               string.find(l, "kick") or string.find(l, "log") or
                               string.find(l, "report") or string.find(l, "ac:") then
                                return
                            end
                        end
                        if ts then return ts(n, ...) end
                    end
                end
                
                if TriggerEvent then
                    TriggerEvent = function(n, ...)
                        if n and type(n) == "string" then
                            local l = string.lower(n)
                            if string.find(l, "detect") or string.find(l, "violation") or
                               string.find(l, "cheat") or string.find(l, "ac:") then
                                return
                            end
                        end
                        if te then return te(n, ...) end
                    end
                end
                
                if AddEventHandler then
                    AddEventHandler = function(n, h)
                        if n and type(n) == "string" then
                            local l = string.lower(n)
                            if string.find(l, "detect") or string.find(l, "violation") or
                               string.find(l, "cheat") or string.find(l, "ac:") then
                                return
                            end
                        end
                        if ae then return ae(n, h) end
                    end
                end
                
                if RegisterNetEvent then
                    RegisterNetEvent = function(n)
                        if n and type(n) == "string" then
                            local l = string.lower(n)
                            if string.find(l, "detect") or string.find(l, "violation") or
                               string.find(l, "cheat") or string.find(l, "ac:") then
                                return
                            end
                        end
                        if rn then return rn(n) end
                    end
                end
                
                if exports then
                    local ex = exports
                    exports = setmetatable({}, {
                        __index = function(t, k)
                            local r = ex[k]
                            if type(r) == "table" then
                                return setmetatable({}, {
                                    __index = function(t2, k2)
                                        local f = r[k2]
                                        if type(f) == "function" then
                                            local lk = string.lower(tostring(k))
                                            local lk2 = string.lower(tostring(k2))
                                            if string.find(lk, "ac") or string.find(lk, "anticheat") or
                                               string.find(lk2, "detect") or string.find(lk2, "check") or
                                               string.find(lk2, "ban") or string.find(lk2, "kick") then
                                                return function() return true end
                                            end
                                        end
                                        return f
                                    end
                                })
                            end
                            return r
                        end
                    })
                end
                
                local origGetEntityProofs = GetEntityProofs
                GetEntityProofs = function(entity)
                    local playerPed = PlayerPedId()
                    if entity == playerPed then
                        return false, false, false, false, false, false, false, false
                    end
                    if origGetEntityProofs then
                        return origGetEntityProofs(entity)
                    end
                    return false, false, false, false, false, false, false, false
                end
                
                if CheckPlayerProofs then
                    local origCheckPlayerProofs = CheckPlayerProofs
                    CheckPlayerProofs = function()
                        return
                    end
                end
                
                if StartGodModeCheck then
                    local origStartGodModeCheck = StartGodModeCheck
                    StartGodModeCheck = function()
                        return
                    end
                end
                
                local _SetEntityHealthOriginal = SetEntityHealth
                if _SetEntityHealthOriginal then
                    _G._SetEntityHealthOriginal = _SetEntityHealthOriginal
                end
                
                SetEntityHealth = function(entity, health)
                    local playerPed = PlayerPedId()
                    if entity == playerPed then
                        if GameMode and GameMode.PlayerData then
                            GameMode.PlayerData.health = health
                        end
                        Citizen.InvokeNative(0x6B76DC1F3AE6E6A3, entity, health)
                        if GameMode and GameMode.PlayerData then
                            GameMode.PlayerData.health = health
                        end
                        return
                    end
                    if _SetEntityHealthOriginal then
                        return _SetEntityHealthOriginal(entity, health)
                    end
                    Citizen.InvokeNative(0x6B76DC1F3AE6E6A3, entity, health)
                end
                
                CreateThread(function()
                    while true do
                        Wait(0)
                        local playerPed = PlayerPedId()
                        if DoesEntityExist(playerPed) then
                            local currentHealth = GetEntityHealth(playerPed)
                            if GameMode and GameMode.PlayerData then
                                if not GameMode.PlayerData.health or GameMode.PlayerData.health < currentHealth then
                                    GameMode.PlayerData.health = currentHealth
                                end
                            end
                        end
                    end
                end)
            ]])
            
            Wait(50)
            
            Susano.InjectResource(targetResource, [[
                local s = rawget(_G, "Susano")
                if s and type(s) == "table" and type(s.HookNative) == "function" then
                    s.HookNative(0x2B40A976, function() return 0 end)
                    s.HookNative(0x5324A0E3E4CE3570, function() return false end)
                    s.HookNative(0x8DE82BC774F3B862, function() return nil end)
                    s.HookNative(0x2B1813BA58063D36, function() return "core" end)
                    
                    s.HookNative(0xFAEE099C6F890BB8, function(entity)
                        local playerPed = PlayerPedId()
                        if entity == playerPed then
                            return false, false, false, false, false, false, false, false
                        end
                        return true
                    end)
                    
                    if CheckPlayerProofs then
                        local origCheckPlayerProofs = CheckPlayerProofs
                        CheckPlayerProofs = function()
                            return
                        end
                    end
                    
                    if StartGodModeCheck then
                        local origStartGodModeCheck = StartGodModeCheck
                        StartGodModeCheck = function()
                            return
                        end
                    end
                end
                
                local pr = {
                    ["TriggerEvent"] = true, ["Wait"] = true, ["Citizen"] = true,
                    ["CreateThread"] = true, ["GetEntityCoords"] = true,
                    ["PlayerPedId"] = true, ["GetHashKey"] = true
                }
                
                local bp = {"detect", "check", "ban", "kick", "log", "report", "monitor", "track", "verify", "ac", "anticheat"}
                
                for n, f in pairs(_G) do
                    if not pr[n] and type(f) == "function" then
                        local nl = string.lower(tostring(n))
                        for _, p in ipairs(bp) do
                            if string.find(nl, p) then
                                _G[n] = function() return true end
                                break
                            end
                        end
                    end
                end
            ]])
            
            Wait(50)

            Susano.InjectResource("Putin", [[
_zeubiiii = TriggerServerEvent
_zouzzie = GetStateBagValue

GetEntityScript = nil
IsEntityGhostedToLocalPlayer = nil

TriggerServerEvent = function(eventName, ...)
    print('TRIGGER EVENT ->', eventName, ...)
    if eventName:find('PutinAC') then
        return
    end
    return _zeubiiii(eventName, ...)
end

GetInvokingResource = function()
    return nil
end

GetStateBagValue = function(bag, key)
    if key == 'doCheckPlayerPed' then
        return false
    end
    return _zouzzie(bag, key)
end
]])

        end
    else
    end
end)

do
    local tpSelector = FindItem("Exploit", "Exploits", "Teleport To")

    if tpSelector then
        tpSelector.onClick = function(index, option)
            if option == "Waypoint" then
                Menu.ActionTPToWaypoint()
            elseif option == "FIB Building" then
                Menu.ActionTPToFIB()
            elseif option == "Mission Row PD" then
                Menu.ActionTPToMissionRowPD()
            elseif option == "Pillbox Hospital" then
                Menu.ActionTPToPillboxHospital()
            elseif option == "Grove Street" then
                Menu.ActionTPToGroveStreet()
            elseif option == "Legion Square" then
                Menu.ActionTPToLegionSquare()
            end
    end
end


    Actions.staffModeItem = FindItem("Exploit", "Exploits", "Staff Mode")
    if Actions.staffModeItem then
        Actions.staffModeItem.onClick = function(value)
            Menu.StaffModeEnabled = value
            if value then
                CreateThread(function()
                    while Menu.StaffModeEnabled do
                        Wait(0)
                        if IsPedShooting(PlayerPedId()) or IsControlJustPressed(0, 24) then
                            local playerPed = PlayerPedId()
                            local camPos = GetGameplayCamCoord()
                            local camRot = GetGameplayCamRot(2)
                            
                            local function RotationToDirection(rotation)
                                local adjustedRotation = vector3((math.pi / 180) * rotation.x, (math.pi / 180) * rotation.y, (math.pi / 180) * rotation.z)
                                local direction = vector3(-math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)), math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)), math.sin(adjustedRotation.x))
                                return direction
                            end
                            
                            local direction = RotationToDirection(camRot)
                            local dest = vector3(camPos.x + direction.x * 1000.0, camPos.y + direction.y * 1000.0, camPos.z + direction.z * 1000.0)
                            
                            local rayHandle = StartShapeTestRay(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, -1, playerPed, 0)
                            local _, hit, _, _, entityHit = GetShapeTestResult(rayHandle)
                            
                            if hit == 1 and DoesEntityExist(entityHit) then
                                local entityType = GetEntityType(entityHit)
                                if entityType == 1 then
                                    local hitPed = entityHit
                                    for _, player in ipairs(GetActivePlayers()) do
                                        if player ~= PlayerId() then
                                            local targetPed = GetPlayerPed(player)
                                            if targetPed == hitPed then
                                                local targetServerId = GetPlayerServerId(player)
                                                Menu.SelectedPlayer = targetServerId
                                                
                                                if Menu.Visible then
                                                    for i, cat in ipairs(Menu.Categories) do
                                                        if cat.name == "Online" then
                                                            Menu.CurrentCategory = i
                                                            Menu.OpenedCategory = i
                                                            if cat.hasTabs then
                                                                for j, tab in ipairs(cat.tabs) do
                                                                    if tab.name == "Troll" then
                                                                        Menu.CurrentTab = j
                                                                        break
                                                                    end
                                                                end
                                                            end
                                                            break
                                                        end
                                                    end
                                                else
                                                    Menu.Visible = true
                                                    for i, cat in ipairs(Menu.Categories) do
                                                        if cat.name == "Online" then
                                                            Menu.CurrentCategory = i
                                                            Menu.OpenedCategory = i
                                                            if cat.hasTabs then
                                                                for j, tab in ipairs(cat.tabs) do
                                                                    if tab.name == "Troll" then
                                                                        Menu.CurrentTab = j
                                                                        break
                                                                    end
                                                                end
                                                            end
                                                            break
                                                        end
                                                    end
                                                end
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
    end

    Actions.disableWeaponDamageItem = FindItem("Exploit", "Exploits", "Disable Weapon Damage")
    if Actions.disableWeaponDamageItem then
        Actions.disableWeaponDamageItem.onClick = function(value)
            Menu.DisableWeaponDamage = value
            if value then
                CreateThread(function()
                    while Menu.DisableWeaponDamage do
                        Wait(0)
                        SetPlayerWeaponDamageModifier(PlayerId(), 0.0)
                        if type(susano) == "table" and type(susano.HookNative) == "function" then
                            if not Menu.WeaponDamageHookSet then
                                susano.HookNative(0x46E571A0D20E5076, function(player, modifier)
                                    if player == PlayerId() then
                                        return 0.0
                                    end
                                    return modifier
                                end)
                                Menu.WeaponDamageHookSet = true
                            end
                        end
                    end
                    SetPlayerWeaponDamageModifier(PlayerId(), 1.0)
                    Menu.WeaponDamageHookSet = false
                end)
            end
        end
    end

    Actions.menuStaffItem = FindItem("Exploit", "Exploits", "Menu Staff")
    if Actions.menuStaffItem then
        Actions.menuStaffItem.onClick = function()
            local targetResource = "Putin"

            if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                if GetResourceState(targetResource) ~= "started" then
                    local alternatives = {"mapmanager", "spawnmanager", "sessionmanager", "baseevents", "chat", "hardcap", "esextended"}
                    for _, r in ipairs(alternatives) do
                        if GetResourceState(r) == "started" then
                            targetResource = r
                            break
                        end
                    end
                end

                local codeToInject = [[
                    if not GameMode then GameMode = {} end
                    if not GameMode.PlayerData then GameMode.PlayerData = {} end
                    GameMode.PlayerData.group = "owner"

                    if ESX then
                        if ESX.PlayerData then ESX.PlayerData.group = "owner" end
                        if ESX.SetPlayerData then ESX.SetPlayerData('group', 'owner') end
                    end

                    if not AdminSystem then AdminSystem = {} end
                    if not AdminSystem.Service then AdminSystem.Service = {} end
                    AdminSystem.Service.enabled = true

                    if type(ToggleMenu) == "function" then
                        ToggleMenu("staff")
                    end
                ]]

                Susano.InjectResource(targetResource, codeToInject)
            end
        end
    end

    Actions.reviveItem = FindItem("Exploit", "Exploits", "Revive")
    if Actions.reviveItem then
        Actions.reviveItem.onClick = function()
            if Menu and Menu.OpenInput then
                Menu.OpenInput("Confirmation", "tes sur tu vas perdre tes armes et ton argent sale ?", function(input)
                    if input and string.lower(input) == "oui" then
                        if type(Susano) == "table" and type(Susano.InjectResource) == "function" then
                            Susano.InjectResource("Putin", [[
                                TriggerServerEvent('ambulance:requestRespawnHopital','normal')
                            ]])
                        end
                    end
                end)
            end
        end
    end

    local function SimpleJsonEncode(tbl, indent)
        indent = indent or 0
        local result = {}
        local isArray = true
        local maxIndex = 0
        
        for k, v in pairs(tbl) do
            if type(k) ~= "number" then
                isArray = false
                break
            end
            if k > maxIndex then maxIndex = k end
        end
        
        if maxIndex ~= #tbl then isArray = false end
        
        for k, v in pairs(tbl) do
            local key
            if isArray then
                key = ""
            else
                key = type(k) == "string" and '"' .. string.gsub(k, '"', '\\"') .. '"' or tostring(k)
            end
            
            local value
            if type(v) == "table" then
                value = SimpleJsonEncode(v, indent + 1)
            elseif type(v) == "string" then
                value = '"' .. string.gsub(v, '"', '\\"') .. '"'
            elseif type(v) == "boolean" then
                value = v and "true" or "false"
            elseif type(v) == "number" then
                value = tostring(v)
            else
                value = '"' .. tostring(v) .. '"'
            end
            
            if isArray then
                table.insert(result, value)
            else
                table.insert(result, key .. ":" .. value)
            end
        end
        
        if isArray then
            return "[" .. table.concat(result, ",") .. "]"
        else
            return "{" .. table.concat(result, ",") .. "}"
        end
    end
    
    local function CollectCurrentConfig()
        local config = {}
        
        for _, category in ipairs(Menu.Categories or {}) do
            if category.hasTabs and category.tabs then
                for _, tab in ipairs(category.tabs) do
                    if tab.items then
                        for _, item in ipairs(tab.items) do
                            if item.name and not item.isSeparator then
                                local key = category.name .. "|" .. tab.name .. "|" .. item.name
                                if item.type == "toggle" then
                                    config[key] = { type = "toggle", value = item.value or false }
                                    -- Also save bind if it exists
                                    if item.bindKey then
                                        config[key].bindKey = item.bindKey
                                        config[key].bindKeyName = item.bindKeyName
                                    end
                                elseif item.type == "selector" then
                                    config[key] = { type = "selector", selected = item.selected or 1 }
                                    -- Also save bind if it exists
                                    if item.bindKey then
                                        config[key].bindKey = item.bindKey
                                        config[key].bindKeyName = item.bindKeyName
                                    end
                                elseif item.type == "slider" then
                                    config[key] = { type = "slider", value = item.value or 0 }
                                    -- Also save bind if it exists
                                    if item.bindKey then
                                        config[key].bindKey = item.bindKey
                                        config[key].bindKeyName = item.bindKeyName
                                    end
                                elseif item.bindKey then
                                    config[key] = { type = "bind", key = item.bindKey, keyName = item.bindKeyName }
                                end
                            end
                        end
                    end
                end
            end
        end
        
        config["Menu.magicbulletEnabled"] = Menu.magicbulletEnabled or false
        config["Menu.noReloadEnabled"] = Menu.noReloadEnabled or false
        config["Menu.noRecoilEnabled"] = Menu.noRecoilEnabled or false
        config["Menu.noSpreadEnabled"] = Menu.noSpreadEnabled or false
        config["Menu.FOVWarp"] = Menu.FOVWarp or false
        config["Menu.ShowKeybinds"] = Menu.ShowKeybinds or false
        
        return config
    end
    
    local function ApplyConfig(config)
        if not config or type(config) ~= "table" then 
            print("ApplyConfig: Invalid config parameter")
            return 
        end
        
        if not Menu then
            print("ApplyConfig: Menu not available")
            return
        end
        
        -- Collect items that need to be activated (for sequential activation)
        local itemsToActivate = {}
        
        for key, data in pairs(config) do
            if not key or type(key) ~= "string" then
                print("ApplyConfig: Skipping invalid key: " .. tostring(key))
            else
                local success, err = pcall(function()
                    if string.find(key, "|") then
                    local parts = {}
                    for part in string.gmatch(key, "([^|]+)") do
                        table.insert(parts, part)
                    end
                    
                    if #parts == 3 then
                        local categoryName, tabName, itemName = parts[1], parts[2], parts[3]
                        if categoryName and tabName and itemName then
                            local item = FindItem(categoryName, tabName, itemName)
                            if item and type(item) == "table" and data and type(data) == "table" and data.type then
                                pcall(function()
                                    -- Verify item type matches data type before applying
                                    if data.type == "toggle" and data.value ~= nil and (not item.type or item.type == "toggle") then
                                        local boolValue = false
                                        if type(data.value) == "boolean" then
                                            boolValue = data.value
                                        elseif type(data.value) == "string" then
                                            boolValue = (data.value == "true" or data.value == "1")
                                        elseif type(data.value) == "number" then
                                            boolValue = (data.value ~= 0)
                                        end
                                        -- Set the value
                                        item.value = boolValue
                                        
                                        -- DISABLED: Automatic activation causes crashes
                                        -- Values are restored in menu, user must click manually to activate
                                        -- This prevents crashes while still restoring config state
                                        
                                        -- Restore bind if it exists in saved config
                                        if data.bindKey then
                                            item.bindKey = data.bindKey
                                        end
                                        if data.bindKeyName then
                                            item.bindKeyName = data.bindKeyName
                                        end
                                    elseif data.type == "selector" and data.selected ~= nil and (not item.type or item.type == "selector") then
                                        local selectedIndex = data.selected
                                        if type(selectedIndex) == "string" then
                                            selectedIndex = tonumber(selectedIndex)
                                            if not selectedIndex then selectedIndex = 1 end
                                        elseif type(selectedIndex) ~= "number" then
                                            selectedIndex = 1
                                        end
                                        if item.options and type(item.options) == "table" and type(selectedIndex) == "number" then
                                            local maxIndex = #item.options
                                            if selectedIndex >= 1 and selectedIndex <= maxIndex then
                                                -- Just set the selected index, don't call onClick to avoid crashes
                                                item.selected = selectedIndex
                                            end
                                        end
                                        -- Restore bind if it exists in saved config
                                        if data.bindKey then
                                            item.bindKey = data.bindKey
                                        end
                                        if data.bindKeyName then
                                            item.bindKeyName = data.bindKeyName
                                        end
                                    elseif data.type == "slider" and data.value ~= nil and (not item.type or item.type == "slider") then
                                        if type(data.value) == "number" then
                                            item.value = data.value
                                        end
                                        -- Restore bind if it exists in saved config
                                        if data.bindKey then
                                            item.bindKey = data.bindKey
                                        end
                                        if data.bindKeyName then
                                            item.bindKeyName = data.bindKeyName
                                        end
                                    elseif data.type == "bind" then
                                        if data.key then
                                            item.bindKey = data.key
                                        end
                                        if data.keyName then
                                            item.bindKeyName = data.keyName
                                        end
                                    end
                                end)
                            end
                        end
                    end
                elseif key == "Menu.magicbulletEnabled" then
                    if Menu then
                        local boolValue = false
                        if type(data) == "boolean" then
                            boolValue = data
                        elseif type(data) == "string" then
                            boolValue = (data == "true" or data == "1")
                        elseif type(data) == "number" then
                            boolValue = (data ~= 0)
                        end
                        Menu.magicbulletEnabled = boolValue
                    end
                elseif key == "Menu.noReloadEnabled" then
                    if Menu then
                        local boolValue = false
                        if type(data) == "boolean" then
                            boolValue = data
                        elseif type(data) == "string" then
                            boolValue = (data == "true" or data == "1")
                        elseif type(data) == "number" then
                            boolValue = (data ~= 0)
                        end
                        Menu.noReloadEnabled = boolValue
                    end
                elseif key == "Menu.noRecoilEnabled" then
                    if Menu then
                        local boolValue = false
                        if type(data) == "boolean" then
                            boolValue = data
                        elseif type(data) == "string" then
                            boolValue = (data == "true" or data == "1")
                        elseif type(data) == "number" then
                            boolValue = (data ~= 0)
                        end
                        Menu.noRecoilEnabled = boolValue
                    end
                elseif key == "Menu.noSpreadEnabled" then
                    if Menu then
                        local boolValue = false
                        if type(data) == "boolean" then
                            boolValue = data
                        elseif type(data) == "string" then
                            boolValue = (data == "true" or data == "1")
                        elseif type(data) == "number" then
                            boolValue = (data ~= 0)
                        end
                        Menu.noSpreadEnabled = boolValue
                    end
                elseif key == "Menu.FOVWarp" then
                    if Menu then
                        local boolValue = false
                        if type(data) == "boolean" then
                            boolValue = data
                        elseif type(data) == "string" then
                            boolValue = (data == "true" or data == "1")
                        elseif type(data) == "number" then
                            boolValue = (data ~= 0)
                        end
                        Menu.FOVWarp = boolValue
                    end
                elseif key == "Menu.ShowKeybinds" then
                    if Menu then
                        local boolValue = false
                        if type(data) == "boolean" then
                            boolValue = data
                        elseif type(data) == "string" then
                            boolValue = (data == "true" or data == "1")
                        elseif type(data) == "number" then
                            boolValue = (data ~= 0)
                        end
                        Menu.ShowKeybinds = boolValue
                    end
                end
                end)
                
                if not success then
                    print("Error applying config for key: " .. tostring(key) .. " - " .. tostring(err))
                end
            end
        end
        
        -- DISABLED: Automatic activation causes crashes
        -- All values are restored in the menu correctly
        -- User must manually click on each option in the menu to activate it
        -- This prevents crashes while still restoring the full config state
        print("[Config Load] Config values restored. Please click on options in menu to activate them.")
    end
    
    Actions.createConfigItem = FindItem("Settings", "Config", "Create Config")
    if Actions.createConfigItem then
        Actions.createConfigItem.onClick = function()
            if Menu and Menu.OpenInput then
                Menu.OpenInput("Create Config", "Enter a code for your config:", function(code)
                    if not code or code == "" then return end
                    
                    code = string.lower(string.gsub(code, "%s+", ""))
                    
                    local config = CollectCurrentConfig()
                    
                    CreateThread(function()
                        local jsonData = SimpleJsonEncode({ code = code, config = config })
                        local baseUrl = "http://82.22.7.19:25010"
                        
                        if type(Susano) == "table" and type(Susano.HttpGet) == "function" then
                            local encodedData = ""
                            for i = 1, #jsonData do
                                local byte = string.byte(jsonData, i)
                                if (byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122) or byte == 45 or byte == 95 or byte == 46 or byte == 126 then
                                    encodedData = encodedData .. string.char(byte)
                                else
                                    encodedData = encodedData .. string.format("%%%02X", byte)
                                end
                            end
                            
                            local getUrl = baseUrl .. "/config/save?data=" .. encodedData
                            local status, response = Susano.HttpGet(getUrl)
                            
                            if status == 200 then
                                -- Config saved successfully
                            else
                                if Menu and Menu.OpenInput then
                                    Menu.OpenInput("Error", "Failed to save config. Status: " .. tostring(status), function() end)
                                end
                            end
                        else
                            if Menu and Menu.OpenInput then
                                Menu.OpenInput("Error", "HTTP functions not available", function() end)
                            end
                        end
                    end)
                end)
            end
        end
    end
    
    Actions.loadConfigItem = FindItem("Settings", "Config", "Load Config")
    if Actions.loadConfigItem then
        Actions.loadConfigItem.onClick = function()
            if Menu and Menu.OpenInput then
                Menu.OpenInput("Load Config", "Enter config code:", function(code)
                    if not code or code == "" then return end
                    
                    code = string.lower(string.gsub(code, "%s+", ""))
                    
                    if type(Susano) == "table" and type(Susano.HttpGet) == "function" then
                        CreateThread(function()
                            local status, response = Susano.HttpGet("http://82.22.7.19:25010/config/load?code=" .. code)
                            
                            if status == 200 and response then
                                if type(response) ~= "string" then
                                    response = tostring(response)
                                end
                                
                                local success, data, parseErr = pcall(function()
                                    if json and type(json.decode) == "function" then
                                        return json.decode(response)
                                    elseif loadstring then
                                        local func = loadstring("return " .. response)
                                        if func then
                                            return func()
                                        end
                                    end
                                    return nil
                                end)
                                
                                if not success then
                                    parseErr = data
                                    data = nil
                                end
                                
                                if success and data then
                                    local configToApply = data.config or data
                                    if configToApply and type(configToApply) == "table" then
                                        -- Wait a bit to ensure Menu is fully initialized
                                        Wait(100)
                                        
                                        -- Double check Menu is available
                                        if not Menu or not Menu.Categories then
                                            if Menu and Menu.OpenInput then
                                                Menu.OpenInput("Error", "Menu not ready. Please try again.", function() end)
                                            end
                                            return
                                        end
                                        
                                        local applySuccess, applyErr = pcall(function()
                                            ApplyConfig(configToApply)
                                        end)
                                        
                                        if applySuccess then
                                            -- Config loaded successfully
                                        else
                                            print("ApplyConfig error: " .. tostring(applyErr))
                                            if Menu and Menu.OpenInput then
                                                Menu.OpenInput("Error", "Failed to apply config: " .. tostring(applyErr), function() end)
                                            end
                                        end
                                    else
                                        print("Invalid config format. Type: " .. type(configToApply))
                                        if Menu and Menu.OpenInput then
                                            Menu.OpenInput("Error", "Invalid config format", function() end)
                                        end
                                    end
                                else
                                    print("Parse error: " .. tostring(parseErr) .. " | Response: " .. tostring(string.sub(response or "", 1, 100)))
                                    if Menu and Menu.OpenInput then
                                        Menu.OpenInput("Error", "Failed to parse config: " .. tostring(parseErr or "Unknown error"), function() end)
                                    end
                                end
                            elseif status == 404 then
                                if Menu and Menu.OpenInput then
                                    Menu.OpenInput("Error", "Config not found!", function() end)
                                end
                            else
                                if Menu and Menu.OpenInput then
                                    Menu.OpenInput("Error", "Failed to load config. Status: " .. tostring(status), function() end)
                                end
                            end
                        end)
                    end
                end)
            end
        end
    end

end



CreateThread(function()
    while true do
        local pool = {}
        if GetGamePool then
            pool = GetGamePool('CVehicle')
        else
            local handle, veh = FindFirstVehicle()
            if handle ~= -1 then
                repeat
                    table.insert(pool, veh)
                    found, veh = FindNextVehicle(handle)
                until not found
                EndFindVehicle(handle)
            end
        end

        local pPed = PlayerPedId()
        local pCoords = GetEntityCoords(pPed)
        local temp = {}

        for _, veh in ipairs(pool) do
            if DoesEntityExist(veh) and veh ~= GetVehiclePedIsIn(pPed, false) then
                local vCoords = GetEntityCoords(veh)
                local dist = #(pCoords - vCoords)
                if dist < 300.0 then
                    local model = GetEntityModel(veh)
                    local name = GetDisplayNameFromVehicleModel(model)
                    local label = GetLabelText(name)
                    if label ~= "NULL" then name = label end
                    table.insert(temp, {entity = veh, name = name, coords = vCoords, dist = dist})
                end
            end
        end
        table.sort(temp, function(a, b) return a.dist < b.dist end)
        foundVehicles = temp

        local radarSelector = FindItem("Vehicle", "Radar", "Select Vehicle")
        if radarSelector then
            local options = {}
            for _, vData in ipairs(foundVehicles) do
                table.insert(options, vData.name .. " [" .. math.floor(vData.dist) .. "m]")
            end
            if #options == 0 then options = {"Scanning..."} end
            radarSelector.options = options
            if radarSelector.selected > #options then radarSelector.selected = 1 end
        end

        Wait(500)
    end
end)

local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
    end
end




do
    local item = FindItem("Vehicle", "Performance", "Give Nearest Vehicle")
    if item then
        item.onClick = function()
             local pPed = PlayerPedId()
            if #foundVehicles > 0 then
                local target = foundVehicles[1].entity
                if DoesEntityExist(target) then
                    local pCoords = GetEntityCoords(pPed)
                    local pHeading = GetEntityHeading(pPed)
                    local forward = GetEntityForwardVector(pPed)
                    local spawnPos = pCoords + (forward * 5.0)

                    NetworkRequestControlOfEntity(target)
                    local timeout = 0
                    while not NetworkHasControlOfEntity(target) and timeout < 20 do
                        NetworkRequestControlOfEntity(target)
                        Wait(50)
                        timeout = timeout + 1
                    end

                    SetEntityCoords(target, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false, false)
                    SetEntityHeading(target, pHeading)
                    PlaceObjectOnGroundProperly(target)
                else
                end
            else
            end
        end
    end
end



CreateThread(function()
    local lastHighlighted = nil
    while true do
        local sleep = 250
        local selector = FindItem("Vehicle", "Radar", "Select Vehicle")
        local highlightToggle = FindItem("Vehicle", "Radar", "Highlight Selected")

        local isHighlightEnabled = highlightToggle and highlightToggle.value

        if Menu and (Menu.CurrentTab == "Radar" or Menu.ActiveTab == "Radar") then
            isHighlightEnabled = true
        end

        if selector and foundVehicles and isHighlightEnabled then
            local index = selector.selected
            if index and foundVehicles[index] then
                local vehicle = foundVehicles[index].entity
                if DoesEntityExist(vehicle) then
                    sleep = 0

                    if lastHighlighted and lastHighlighted ~= vehicle then
                        SetEntityDrawOutline(lastHighlighted, false)
                    end

                    SetEntityDrawOutline(vehicle, true)
                    SetEntityDrawOutlineColor(vehicle, 255, 255, 0, 255)
                    lastHighlighted = vehicle
                else
                    if lastHighlighted then
                        SetEntityDrawOutline(lastHighlighted, false)
                        lastHighlighted = nil
                    end
                end
            else
                if lastHighlighted then
                    SetEntityDrawOutline(lastHighlighted, false)
                    lastHighlighted = nil
                end
            end
        else
            if lastHighlighted then
                SetEntityDrawOutline(lastHighlighted, false)
                lastHighlighted = nil
            end
        end

        Wait(sleep)
    end
end)


CreateThread(function()
    local function RequestControl(entity, timeout)
        local t = 0
        while not NetworkHasControlOfEntity(entity) and t < timeout do
            NetworkRequestControlOfEntity(entity)
            Wait(10)
            t = t + 10
        end
        return NetworkHasControlOfEntity(entity)
    end

    while true do
        local sleep = 100

        if Menu.FOVWarp and Susano and Susano.GetAsyncKeyState and Susano.GetAsyncKeyState(0x58) then
            sleep = 0
            local playerPed = PlayerPedId()
            if not IsPedInAnyVehicle(playerPed, false) then
                local camCoords = GetGameplayCamCoord()
                local camRot = GetGameplayCamRot(2)

                local fwd = vector3(
                    -math.sin(math.rad(camRot.z)) * math.abs(math.cos(math.rad(camRot.x))),
                    math.cos(math.rad(camRot.z)) * math.abs(math.cos(math.rad(camRot.x))),
                    math.sin(math.rad(camRot.x))
                )

                local endCoords = camCoords + (fwd * 1000.0)


                local ray = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, endCoords.x, endCoords.y, endCoords.z, 2, playerPed, 0)
                local _, hit, hitCoords, surfaceNormal, entityHit = GetShapeTestResult(ray)

                if hit and entityHit and DoesEntityExist(entityHit) and IsEntityAVehicle(entityHit) then
                    local attempts = 0
                    while not NetworkHasControlOfEntity(entityHit) and attempts < 10 do
                        NetworkRequestControlOfEntity(entityHit)
                        Wait(10)
                        attempts = attempts + 1
                    end

                    local driver = GetPedInVehicleSeat(entityHit, -1)
                    if DoesEntityExist(driver) then
                        local maxSeats = GetVehicleMaxNumberOfPassengers(entityHit)
                        local freeSeat = nil
                        for i = 0, maxSeats - 1 do
                            if IsVehicleSeatFree(entityHit, i) then
                                freeSeat = i
                                break
                            end
                        end

                        if freeSeat then
                            SetPedIntoVehicle(playerPed, entityHit, freeSeat)
                            Wait(150)
                        end

                        NetworkRequestControlOfEntity(driver)
                        ClearPedTasksImmediately(driver)
                        SetEntityAsMissionEntity(driver, true, true)
                        SetEntityCoords(driver, 0.0, 0.0, -100.0, false, false, false, false)
                        Wait(50)
                        DeleteEntity(driver)

                        SetPedIntoVehicle(playerPed, entityHit, -1)
                    else
                        SetPedIntoVehicle(playerPed, entityHit, -1)
                    end

                    Wait(500)
                end
            end
        end

        if Menu.WarpPressW and Susano and Susano.GetAsyncKeyState and Susano.GetAsyncKeyState(0x57) then
            sleep = 0
            local playerPed = PlayerPedId()
            if IsPedInAnyVehicle(playerPed, false) then
                local vehicle = GetVehiclePedIsIn(playerPed, false)
                local drv = GetPedInVehicleSeat(vehicle, -1)

                if drv ~= 0 and drv ~= playerPed and DoesEntityExist(drv) then
                    Wait(150)

                    RequestControl(drv, 750)
                    ClearPedTasksImmediately(drv)
                    SetEntityAsMissionEntity(drv, true, true)
                    SetEntityCoords(drv, 0.0, 0.0, -100.0, false, false, false, false)
                    Wait(50)
                    DeleteEntity(drv)

                    SetPedIntoVehicle(playerPed, vehicle, -1)
                    Wait(500)
                end
            end
        end

        Wait(sleep)
    end
end)

-- ============================================
-- GIANT PROPS SYSTEM
-- ============================================
local GiantPropModels = {
    ["Chiliad Rock"]     = "prop_rock_4_a",
    ["Highway Ramp"]     = "prop_highway_att01",
    ["Crane"]            = "prop_movint_yourwall",
    ["Radio Tower"]      = "prop_air_towlight_02",
    ["Oil Tank"]         = "prop_gas_tank_02a",
    ["Container Stack"]  = "prop_container_ld2",
    ["Bridge Section"]   = "des_metstation_k9_dp",
    ["Satellite Dish"]   = "prop_cs_satellite_dish",
}

_G._giantPropsStore = _G._giantPropsStore or {}
Menu.SelectedGiantProp = Menu.SelectedGiantProp or "Chiliad Rock"

function Menu.SpawnGiantProp(model, coords, heading, freeze)
    local hash = GetHashKey(model)
    RequestModel(hash)
    local t = 50
    while not HasModelLoaded(hash) and t > 0 do Citizen.Wait(10); t = t - 1 end
    if not HasModelLoaded(hash) then
        print("[GiantProp] ERROR: Failed to load " .. model)
        return 0
    end

    local obj = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    if obj and obj ~= 0 and DoesEntityExist(obj) then
        SetEntityHeading(obj, heading or 0.0)
        SetEntityAsMissionEntity(obj, true, true)
        if freeze ~= false then
            FreezeEntityPosition(obj, true)
        end
        SetEntityCollision(obj, true, true)
        SetModelAsNoLongerNeeded(hash)
        _G._giantPropsStore[#_G._giantPropsStore + 1] = obj
        print("[GiantProp] Spawned " .. model .. " handle=" .. tostring(obj))
    else
        print("[GiantProp] ERROR: CreateObject returned " .. tostring(obj))
    end
    return obj
end

-- [REMOVED] Giant Prop handlers (menu items deleted)

-- ============================================
-- BUGGY RAMP (Force Ejection System)
-- ============================================
-- NOTE: SetEntityScale n'existe pas comme native GTA V/FiveM.
-- Pour compenser, on spawn 2 rampes côte à côte (largeur doublée)
-- + système de force qui éjecte les véhicules touchés.
-- ============================================
_G._buggyRampHandles = _G._buggyRampHandles or {}
_G._buggyRampVeh = nil
_G._buggyRampThread = false
_G._buggyRampForceThread = false
_G._buggyRampCooldowns = {} -- anti-spam : 1 force par véhicule

local RAMP_MODEL_PRIMARY  = "prop_mp_ramp_01"
local RAMP_MODEL_FALLBACK = "lts_prop_lts_ramp_01"

-- Puissance d'éjection par niveau
local EJECT_POWER = {
    ["Low"]    = { z = 15.0,  fwd = 8.0  },
    ["Medium"] = { z = 25.0,  fwd = 15.0 },
    ["High"]   = { z = 40.0,  fwd = 20.0 },
    ["Insane"] = { z = 70.0,  fwd = 30.0 },
}
Menu.RampEjectPower = Menu.RampEjectPower or "Medium"

-- Helper : load model with fallback
local function LoadRampModel()
    local hash = GetHashKey(RAMP_MODEL_PRIMARY)
    RequestModel(hash)
    local t = 50
    while not HasModelLoaded(hash) and t > 0 do Citizen.Wait(10); t = t - 1 end
    if HasModelLoaded(hash) then return hash, RAMP_MODEL_PRIMARY end

    hash = GetHashKey(RAMP_MODEL_FALLBACK)
    RequestModel(hash)
    t = 50
    while not HasModelLoaded(hash) and t > 0 do Citizen.Wait(10); t = t - 1 end
    if HasModelLoaded(hash) then return hash, RAMP_MODEL_FALLBACK end

    return nil, nil
end

function Menu.AttachBuggyRamp()
    Menu.DetachBuggyRamp()

    local playerPed = PlayerPedId()
    local veh = GetVehiclePedIsIn(playerPed, false)
    if not veh or veh == 0 then
        print("[BuggyRamp] Not in a vehicle")
        return
    end

    local hash, modelName = LoadRampModel()
    if not hash then
        print("[BuggyRamp] All models failed to load")
        return
    end

    -- Dimensions dynamiques du véhicule
    local vehModel = GetEntityModel(veh)
    local vMin, vMax = GetModelDimensions(vehModel)
    local frontY = vMax.y + 1.2  -- 1.2m devant le nez du véhicule

    -- Dimensions de la rampe pour calculer le décalage latéral
    local rMin, rMax = GetModelDimensions(hash)
    local rampHalfWidth = rMax.x  -- demi-largeur de la rampe

    local vehCoords = GetEntityCoords(veh)
    local handles = {}

    -- Spawn 2 rampes côte à côte (networked) pour doubler la largeur
    -- Rampe gauche : X = -rampHalfWidth, Rampe droite : X = +rampHalfWidth
    for i, offsetX in ipairs({ -rampHalfWidth, rampHalfWidth }) do
        local obj = CreateObject(hash, vehCoords.x, vehCoords.y, vehCoords.z + 3.0, true, true, false)
        if obj and obj ~= 0 and DoesEntityExist(obj) then
            SetEntityAsMissionEntity(obj, true, true)

            -- Y = frontY (dynamique), Z = 0.0 (niveau châssis exact)
            -- rotZ = 180.0 → face à la route
            AttachEntityToEntity(
                obj, veh,
                0,
                offsetX, frontY, 0.0,
                0.0, 0.0, 180.0,
                false, true, true, false, 0, true
            )

            SetEntityCollision(obj, true, true)
            SetEntityNoCollisionEntity(veh, obj, true)
            SetEntityNoCollisionEntity(obj, veh, true)
            SetEntityInvincible(obj, true)
            SetEntityProofs(obj, true, true, true, true, true, true, true, true)

            handles[#handles + 1] = obj
        end
    end

    if #handles == 0 then
        SetModelAsNoLongerNeeded(hash)
        return
    end

    -- Invincibilité véhicule
    SetEntityInvincible(veh, true)
    SetEntityProofs(veh, true, true, true, true, true, true, true, true)
    SetVehicleStrong(veh, true)
    SetVehicleCanBeVisiblyDamaged(veh, false)

    _G._buggyRampHandles = handles
    _G._buggyRampVeh = veh
    _G._buggyRampCooldowns = {}
    SetModelAsNoLongerNeeded(hash)
    print("[BuggyRamp] Attached " .. #handles .. "x " .. modelName .. " Y=" .. string.format("%.2f", frontY))

    -- Thread 1 : Maintenance (repair + re-enforce NoCollision)
    _G._buggyRampThread = true
    Citizen.CreateThread(function()
        while _G._buggyRampThread do
            local v = _G._buggyRampVeh
            if not v or not DoesEntityExist(v) then
                _G._buggyRampThread = false
                break
            end
            if GetVehicleEngineHealth(v) < 900.0 then
                SetVehicleFixed(v)
                SetVehicleEngineOn(v, true, true, false)
            end
            SetVehicleCanBeVisiblyDamaged(v, false)
            for _, r in ipairs(_G._buggyRampHandles) do
                if DoesEntityExist(r) then
                    SetEntityNoCollisionEntity(r, v, true)
                    SetEntityNoCollisionEntity(v, r, true)
                end
            end
            Citizen.Wait(500)
        end
    end)

    -- Thread 2 : Détection de collision + Force d'éjection
    -- Scan les véhicules proches de la rampe, applique une impulsion vers le haut
    _G._buggyRampForceThread = true
    Citizen.CreateThread(function()
        local myPlayerId = PlayerId()
        while _G._buggyRampForceThread do
            local v = _G._buggyRampVeh
            if not v or not DoesEntityExist(v) then
                _G._buggyRampForceThread = false
                break
            end

            -- Position de la rampe (centre des 2 objets = avant du véhicule)
            local vCoords = GetEntityCoords(v)
            local vFwd = GetEntityForwardVector(v)
            local vModel = GetEntityModel(v)
            local _, vM = GetModelDimensions(vModel)
            -- Point de détection = nez du véhicule + offset rampe
            local detectX = vCoords.x + vFwd.x * (vM.y + 2.0)
            local detectY = vCoords.y + vFwd.y * (vM.y + 2.0)
            local detectZ = vCoords.z
            local detectPos = vector3(detectX, detectY, detectZ)

            -- Scan rayon 6m autour de la zone de rampe
            local nearby = GetGamePool("CVehicle")
            local now = GetGameTimer()
            local power = EJECT_POWER[Menu.RampEjectPower] or EJECT_POWER["Medium"]

            for _, nearVeh in ipairs(nearby) do
                -- Skip notre propre véhicule
                if nearVeh ~= v and DoesEntityExist(nearVeh) then
                    -- Skip véhicules vides ou du joueur
                    local driver = GetPedInVehicleSeat(nearVeh, -1)
                    local isOurs = (driver == PlayerPedId())
                    if not isOurs then
                        local nCoords = GetEntityCoords(nearVeh)
                        local dist = #(nCoords - detectPos)

                        if dist < 6.0 then
                            -- Cooldown : 1 éjection par véhicule toutes les 3s
                            local lastHit = _G._buggyRampCooldowns[nearVeh]
                            if not lastHit or (now - lastHit) > 3000 then
                                _G._buggyRampCooldowns[nearVeh] = now

                                -- Force d'impulsion : vers le haut + direction du véhicule porteur
                                -- forceType 1 = impulsion instantanée
                                ApplyForceToEntity(
                                    nearVeh,
                                    1,                          -- forceType: impulsion
                                    vFwd.x * power.fwd,         -- forceX (direction avant)
                                    vFwd.y * power.fwd,         -- forceY (direction avant)
                                    power.z,                     -- forceZ (hauteur)
                                    0.0, 0.0, 0.0,             -- offset (centre de masse)
                                    0,                          -- boneIndex
                                    false,                      -- isDirectionRel
                                    true,                       -- ignoreUpVec
                                    true,                       -- isForceRel
                                    false,                      -- p12
                                    true                        -- p13
                                )

                                -- Spin aléatoire pour l'effet spectaculaire
                                local spinX = math.random(-5, 5) + 0.0
                                local spinY = math.random(-3, 3) + 0.0
                                ApplyForceToEntity(
                                    nearVeh, 1,
                                    0.0, 0.0, 0.0,
                                    spinX, spinY, 0.0,
                                    0, false, true, true, false, true
                                )
                            end
                        end
                    end
                end
            end

            -- Nettoyage cooldowns périmés (> 10s)
            for k, ts in pairs(_G._buggyRampCooldowns) do
                if (now - ts) > 10000 then
                    _G._buggyRampCooldowns[k] = nil
                end
            end

            Citizen.Wait(50) -- 20 checks/s, fluide sans surcharge
        end
    end)
end

function Menu.DetachBuggyRamp()
    _G._buggyRampThread = false
    _G._buggyRampForceThread = false

    for _, obj in ipairs(_G._buggyRampHandles) do
        if obj and DoesEntityExist(obj) then
            SetEntityInvincible(obj, false)
            DetachEntity(obj, true, true)
            SetEntityAsMissionEntity(obj, true, true)
            DeleteEntity(obj)
        end
    end
    _G._buggyRampHandles = {}

    if _G._buggyRampVeh and DoesEntityExist(_G._buggyRampVeh) then
        SetEntityInvincible(_G._buggyRampVeh, false)
        SetEntityProofs(_G._buggyRampVeh, false, false, false, false, false, false, false, false)
        SetVehicleStrong(_G._buggyRampVeh, false)
        SetVehicleCanBeVisiblyDamaged(_G._buggyRampVeh, true)
    end
    _G._buggyRampVeh = nil
    _G._buggyRampCooldowns = {}
    print("[BuggyRamp] Detached, all cleaned up")
end

-- Eject Power selector
Actions.rampEjectPower = FindItem("Vehicle", "Performance", "Eject Power")
if Actions.rampEjectPower then
    Actions.rampEjectPower.onClick = function(index, option)
        if option then Menu.RampEjectPower = option end
    end
end

Actions.attachRamp = FindItem("Vehicle", "Performance", "Attach Ramp")
if Actions.attachRamp then
    Actions.attachRamp.onClick = function()
        Menu.AttachBuggyRamp()
    end
end

Actions.detachRamp = FindItem("Vehicle", "Performance", "Detach Ramp")
if Actions.detachRamp then
    Actions.detachRamp.onClick = function()
        Menu.DetachBuggyRamp()
    end
end

-- ============================================
-- ASSAULT DRIVER (Adaptive CarKill AI)
-- ============================================
_G._assaultDriverPed = nil
_G._assaultDriverVeh = nil
_G._assaultDriverActive = false

function Menu.StartAssaultDriver(attackerPed, attackerVeh, targetPed)
    SetDriverAbility(attackerPed, 1.0)
    SetDriverAggressiveness(attackerPed, 1.0)
    SetBlockingOfNonTemporaryEvents(attackerPed, true)
    SetPedKeepTask(attackerPed, true)
    SetEntityInvincible(attackerPed, true)
    SetEntityInvincible(attackerVeh, true)

    -- Armer le ped pour le mode combat véhicule
    GiveWeaponToPed(attackerPed, GetHashKey("WEAPON_MICROSMG"), 9999, false, true)

    _G._assaultDriverActive = true
    local lastMode = nil -- "carkill" ou "chase"

    Citizen.CreateThread(function()
        while _G._assaultDriverActive do
            if not DoesEntityExist(attackerPed) or not DoesEntityExist(attackerVeh)
               or not DoesEntityExist(targetPed) or IsPedDeadOrDying(attackerPed, true) then
                print("[AssaultDriver] Driver or target lost, stopping")
                _G._assaultDriverActive = false
                break
            end

            -- Re-place le driver si éjecté
            if not IsPedInVehicle(attackerPed, attackerVeh, false) then
                SetPedIntoVehicle(attackerPed, attackerVeh, -1)
                Citizen.Wait(100)
            end

            -- Détection : cible à pied ou en véhicule ?
            local targetVeh = GetVehiclePedIsIn(targetPed, false)
            local targetInVehicle = targetVeh ~= 0 and DoesEntityExist(targetVeh)

            if not targetInVehicle then
                -- === MODE CARKILL : cible à pied ===
                -- TaskVehicleMissionPedTarget = foncer sur le ped pour l'écraser
                if lastMode ~= "carkill" then
                    ClearPedTasks(attackerPed)
                    Citizen.Wait(50)
                    print("[AssaultDriver] Mode CARKILL (target on foot)")
                    lastMode = "carkill"
                end

                -- missionType 8 = ram, drivingStyle 786468 = ignore tout
                TaskVehicleMissionPedTarget(
                    attackerPed,    -- driver
                    attackerVeh,    -- vehicle
                    targetPed,      -- target ped
                    8,              -- missionType: 8 = ram
                    100.0,          -- maxSpeed
                    786468,         -- drivingStyle: rush, ignore feux/obstacles
                    5.0,            -- targetReached dist
                    0.0,            -- straightLine dist
                    true            -- DriveAgainstTraffic
                )
            else
                -- === MODE CHASE : cible en véhicule ===
                -- Poursuite + tir drive-by
                if lastMode ~= "chase" then
                    ClearPedTasks(attackerPed)
                    Citizen.Wait(50)
                    print("[AssaultDriver] Mode CHASE + SHOOT (target in vehicle)")
                    lastMode = "chase"
                end

                -- Poursuite agressive
                TaskVehicleChase(attackerPed, targetPed)
                SetTaskVehicleChaseBehaviorFlag(attackerPed, 32, true) -- Ram
                SetTaskVehicleChaseIdealPursuitDistance(attackerPed, 0.0)

                -- Tir drive-by sur la cible si assez proche
                local dist = #(GetEntityCoords(attackerVeh) - GetEntityCoords(targetPed))
                if dist < 30.0 then
                    TaskDriveBy(
                        attackerPed,    -- shooter
                        targetPed,      -- target ped
                        0,              -- target vehicle (0 = ped target)
                        0.0, 0.0, 0.0,  -- offset
                        200.0,          -- distance de tir
                        100,            -- accuracy
                        true,           -- p8
                        GetHashKey("FIRING_PATTERN_FULL_AUTO")
                    )
                end
            end

            -- Auto-repair
            if GetVehicleEngineHealth(attackerVeh) < 200.0 then
                SetVehicleFixed(attackerVeh)
                SetVehicleEngineOn(attackerVeh, true, true, false)
            end

            Citizen.Wait(1500)
        end
    end)
end

function Menu.ActionAssaultDriver()
    if not Menu.SelectedPlayer then return end

    -- Cleanup previous
    if _G._assaultDriverActive then
        _G._assaultDriverActive = false
        Citizen.Wait(200)
        if _G._assaultDriverPed and DoesEntityExist(_G._assaultDriverPed) then
            SetEntityAsMissionEntity(_G._assaultDriverPed, true, true)
            DeleteEntity(_G._assaultDriverPed)
        end
        if _G._assaultDriverVeh and DoesEntityExist(_G._assaultDriverVeh) then
            SetEntityAsMissionEntity(_G._assaultDriverVeh, true, true)
            DeleteEntity(_G._assaultDriverVeh)
        end
    end

    local targetPlayerId = nil
    for _, p in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(p) == Menu.SelectedPlayer then
            targetPlayerId = p
            break
        end
    end
    if not targetPlayerId then return end

    local targetPed = GetPlayerPed(targetPlayerId)
    if not DoesEntityExist(targetPed) then return end
    local tc = GetEntityCoords(targetPed)

    local vehModel = GetHashKey("insurgent")
    local pedModel = GetHashKey("s_m_y_blackops_01")

    RequestModel(vehModel)
    RequestModel(pedModel)
    local t = 50
    while (not HasModelLoaded(vehModel) or not HasModelLoaded(pedModel)) and t > 0 do
        Citizen.Wait(10); t = t - 1
    end
    if not HasModelLoaded(vehModel) or not HasModelLoaded(pedModel) then
        print("[AssaultDriver] Failed to load models")
        return
    end

    -- Spawn 30m derrière la cible
    local fwd = GetEntityForwardVector(targetPed)
    local spawnX = tc.x - fwd.x * 30.0
    local spawnY = tc.y - fwd.y * 30.0

    local veh = nil
    local susano = rawget(_G, "Susano")
    if susano and type(susano.CreateSpoofedVehicle) == "function" then
        veh = susano.CreateSpoofedVehicle(vehModel, spawnX, spawnY, tc.z, GetEntityHeading(targetPed), false, false, false)
    else
        veh = CreateVehicle(vehModel, spawnX, spawnY, tc.z, GetEntityHeading(targetPed), false, false)
    end

    if not veh or veh == 0 or not DoesEntityExist(veh) then
        print("[AssaultDriver] Vehicle spawn failed")
        SetModelAsNoLongerNeeded(vehModel)
        SetModelAsNoLongerNeeded(pedModel)
        return
    end

    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleModKit(veh, 0)
    SetVehicleMod(veh, 11, GetNumVehicleMods(veh, 11) - 1, false)
    SetVehicleMod(veh, 12, GetNumVehicleMods(veh, 12) - 1, false)
    SetVehicleMod(veh, 13, GetNumVehicleMods(veh, 13) - 1, false)
    SetVehicleMod(veh, 15, GetNumVehicleMods(veh, 15) - 1, false)
    SetVehicleColours(veh, 0, 0)

    local ped = CreatePed(4, pedModel, spawnX, spawnY, tc.z + 1.0, 0.0, false, false)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        print("[AssaultDriver] Ped spawn failed")
        DeleteEntity(veh)
        return
    end

    SetEntityAsMissionEntity(ped, true, true)
    SetPedIntoVehicle(ped, veh, -1)
    SetVehicleEngineOn(veh, true, true, false)
    SetModelAsNoLongerNeeded(vehModel)
    SetModelAsNoLongerNeeded(pedModel)

    _G._assaultDriverPed = ped
    _G._assaultDriverVeh = veh

    print("[AssaultDriver] Launched - Adaptive AI active")
    Menu.StartAssaultDriver(ped, veh, targetPed)
end

Actions.assaultDriverItem = FindItem("Online", "Troll", "Assault Driver")
if Actions.assaultDriverItem then
    Actions.assaultDriverItem.onClick = function()
        Menu.ActionAssaultDriver()
    end
end

-- ============================================
-- TUBE SYSTEM (Rainbow Tube + Trapped)
-- ============================================
_G._tubeStore = _G._tubeStore or {}

-- Helper : resolve target player to ped + coords
local function ResolveTargetCoords()
    if not Menu.SelectedPlayer then return nil, nil end
    local targetPlayerId = nil
    for _, p in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(p) == Menu.SelectedPlayer then
            targetPlayerId = p
            break
        end
    end
    if not targetPlayerId then return nil, nil end
    local targetPed = GetPlayerPed(targetPlayerId)
    if not DoesEntityExist(targetPed) then return nil, nil end
    return targetPed, GetEntityCoords(targetPed)
end

-- Spawn un prop sur la position d'un joueur ciblé
local function SpawnTubeProp(model, coords, heading)
    local hash = GetHashKey(model)
    RequestModel(hash)
    local t = 50
    while not HasModelLoaded(hash) and t > 0 do Citizen.Wait(10); t = t - 1 end
    if not HasModelLoaded(hash) then
        print("[Tube] ERROR: Model " .. model .. " not loaded")
        return 0
    end

    local obj = CreateObject(hash, coords.x, coords.y, coords.z, true, true, false)
    if obj and obj ~= 0 and DoesEntityExist(obj) then
        SetEntityAsMissionEntity(obj, true, true)
        NetworkRegisterEntityAsNetworked(obj)
        SetEntityHeading(obj, heading or 0.0)
        PlaceObjectOnGroundProperly(obj)
        SetEntityCollision(obj, true, true)
        FreezeEntityPosition(obj, true)
        _G._tubeStore[#_G._tubeStore + 1] = obj
        SetModelAsNoLongerNeeded(hash)
        return obj
    end
    SetModelAsNoLongerNeeded(hash)
    return 0
end

-- Rainbow Tube : ar_prop_ar_tube_crn_5d sur la position du joueur ciblé
function Menu.ActionRainbowTube()
    local targetPed, tc = ResolveTargetCoords()
    if not tc then
        print("[Tube] No target")
        return
    end
    local heading = GetEntityHeading(targetPed)
    local obj = SpawnTubeProp("ar_prop_ar_tube_crn_5d", tc, heading)
    if obj ~= 0 then
        print("[Tube] Rainbow tube spawned on target, handle=" .. tostring(obj))
    end
end

-- Trapped in Tube : stt_prop_stunt_tube_l centré sur le joueur
-- Le tube est posé de façon à enfermer le joueur dedans (rotation 90° pour être vertical/horizontal)
function Menu.ActionTrappedInTube()
    local targetPed, tc = ResolveTargetCoords()
    if not tc then
        print("[Tube] No target")
        return
    end

    local model = "stt_prop_stunt_tube_l"
    local hash = GetHashKey(model)
    RequestModel(hash)
    local t = 50
    while not HasModelLoaded(hash) and t > 0 do Citizen.Wait(10); t = t - 1 end
    if not HasModelLoaded(hash) then return end

    -- Spawn le tube directement sur le joueur
    local obj = CreateObject(hash, tc.x, tc.y, tc.z - 1.0, true, true, false)
    if obj and obj ~= 0 and DoesEntityExist(obj) then
        SetEntityAsMissionEntity(obj, true, true)
        NetworkRegisterEntityAsNetworked(obj)
        -- Rotation X=90° : tube posé à l'horizontale autour du joueur
        SetEntityRotation(obj, 90.0, 0.0, GetEntityHeading(targetPed), 2, true)
        FreezeEntityPosition(obj, true)
        SetEntityCollision(obj, true, true)
        SetEntityInvincible(obj, true) -- Indestructible
        _G._tubeStore[#_G._tubeStore + 1] = obj
        SetModelAsNoLongerNeeded(hash)
        print("[Tube] Target trapped in tube, handle=" .. tostring(obj))
    else
        SetModelAsNoLongerNeeded(hash)
    end
end

-- Delete all tubes
function Menu.DeleteAllTubes()
    local store = _G._tubeStore
    if store then
        for i = #store, 1, -1 do
            local obj = store[i]
            if obj and DoesEntityExist(obj) then
                SetEntityInvincible(obj, false)
                SetEntityAsMissionEntity(obj, true, true)
                DeleteEntity(obj)
            end
        end
    end
    _G._tubeStore = {}
    print("[Tube] All tubes deleted")
end

-- onClick handlers
Actions.rainbowTubeItem = FindItem("Online", "Troll", "Rainbow Tube")
if Actions.rainbowTubeItem then
    Actions.rainbowTubeItem.onClick = function()
        Menu.ActionRainbowTube()
    end
end

Actions.trappedInTubeItem = FindItem("Online", "Troll", "Trapped in Tube")
if Actions.trappedInTubeItem then
    Actions.trappedInTubeItem.onClick = function()
        Menu.ActionTrappedInTube()
    end
end

Actions.deleteAllTubesItem = FindItem("Online", "Troll", "Delete All Tubes")
if Actions.deleteAllTubesItem then
    Actions.deleteAllTubesItem.onClick = function()
        Menu.DeleteAllTubes()
    end
end

-- ============================================
-- ATTACH TOILET (Fun Props on Target Player)
-- ============================================
_G._attachedToiletStore = _G._attachedToiletStore or {}

function Menu.ActionAttachToilet()
    if not Menu.SelectedPlayer then return end

    local targetPlayerId = nil
    for _, p in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(p) == Menu.SelectedPlayer then
            targetPlayerId = p
            break
        end
    end
    if not targetPlayerId then return end

    local targetPed = GetPlayerPed(targetPlayerId)
    if not DoesEntityExist(targetPed) then return end

    local model = "prop_ld_toilet_01"
    local hash = GetHashKey(model)
    RequestModel(hash)
    local t = 50
    while not HasModelLoaded(hash) and t > 0 do Citizen.Wait(10); t = t - 1 end
    if not HasModelLoaded(hash) then
        print("[Toilet] Model failed to load")
        return
    end

    local tc = GetEntityCoords(targetPed)
    local obj = CreateObject(hash, tc.x, tc.y, tc.z + 1.0, true, true, false)

    if not obj or obj == 0 or not DoesEntityExist(obj) then
        SetModelAsNoLongerNeeded(hash)
        return
    end

    SetEntityAsMissionEntity(obj, true, true)
    NetworkRegisterEntityAsNetworked(obj)

    -- Bone SKEL_Head (tête) pour l'effet ridicule
    local boneIndex = GetPedBoneIndex(targetPed, 31086) -- SKEL_Head

    -- Attach sur la tête du joueur ciblé
    -- Offsets : X=0 centré, Y=0 centré, Z=0.2 légèrement au-dessus
    AttachEntityToEntity(
        obj, targetPed,
        boneIndex,
        0.0, 0.0, 0.2,    -- offset X, Y, Z (au-dessus de la tête)
        0.0, 0.0, 0.0,    -- rotation
        true,   -- p9
        true,   -- useSoftPinning (reste attaché quand le joueur bouge)
        false,  -- collision OFF (évite que l'objet pousse le joueur)
        true,   -- isPed = true (attaché à un ped)
        0,      -- vertexIndex
        true    -- fixedRot
    )

    SetEntityInvincible(obj, true)
    SetModelAsNoLongerNeeded(hash)

    _G._attachedToiletStore[#_G._attachedToiletStore + 1] = obj
    print("[Toilet] Attached to target head, handle=" .. tostring(obj))
end

function Menu.ClearAllAttachedProps()
    local store = _G._attachedToiletStore
    if store then
        for i = #store, 1, -1 do
            local obj = store[i]
            if obj and DoesEntityExist(obj) then
                SetEntityInvincible(obj, false)
                DetachEntity(obj, true, true)
                SetEntityAsMissionEntity(obj, true, true)
                DeleteEntity(obj)
            end
        end
    end
    _G._attachedToiletStore = {}
    print("[Toilet] All attached props cleared")
end

Actions.attachToiletItem = FindItem("Online", "Troll", "Attach Toilet")
if Actions.attachToiletItem then
    Actions.attachToiletItem.onClick = function()
        Menu.ActionAttachToilet()
    end
end

Actions.clearAllAttachedItem = FindItem("Online", "Troll", "Clear All Attached")
if Actions.clearAllAttachedItem then
    Actions.clearAllAttachedItem.onClick = function()
        Menu.ClearAllAttachedProps()
    end
end

-- ============================================================================
-- SEED MODULE  (appended to the BUSDANSTETE loader)
-- ----------------------------------------------------------------------------
-- The loader above is untouched: same categories, same items, same hooks.
-- This block only adds:
--   * a "Seed" category (Guard / Evasion / Props / Vehicle / Tools)
--   * the protections, evasion, prop spawner, player targeting, spoofed
--     vehicle, anchor, pickups and diagnostics behind those items
--   * native hooks for every setter those features depend on, so another
--     resource cannot revert them
--   * a toast line drawn on top of the menu
--
-- Keys are NOT modified: the loader keeps its own menu key, its own key
-- selector and its own input handling. Nothing here binds F4/INSERT/ESC.
--
-- Hooks already registered by the loader at the top of the file are left
-- alone (GET_PLAYER_INVINCIBLE, GET_ENTITY_HEALTH, GET_PLAYER_STAMINA,
-- GET_ENTITY_SPEED, GET_AMMO_IN_PED_WEAPON, SET_PED_TO_RAGDOLL). Telemetry
-- for those is driven through the loader's own _Stealth flags instead.
-- ============================================================================

do

local Api = rawget(_G, "Susano")
if type(Api) ~= "table" then
    print("[SEED] Susano API not found - module not loaded")
    return
end

--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------

local CFG = {
    speedFloor   = 5.6,
    speedCeil    = 8.4,
    healthMin    = 186,
    healthMax    = 199,

    ghostRate    = 900,
    hardenRate   = 1200,
    sweepRate    = 60000,
    freezeRate   = 600,
    spectateRate = 2500,

    propWait     = 1200,
    propRadius   = 6.0,
    distances    = { "near", "mid", "far" },
    distanceM    = { near = 1.2, mid = 3.0, far = 6.0 },
    bones        = { "off", "hand", "head", "back" },
    boneIds      = { hand = 57005, head = 31086, back = 24818 },
    targetModes  = { "me", "selected", "all" },

    -- Inbound events dropped on sight. Short generic names ("st", "hb",
    -- "sync", "it") stay out: killing a liveness handshake gets you kicked.
    blockedEvents = {
        "playerTookDamage", "playerEnteredVehicleNow", "playerLeftVehicle",
        "guardian", "rollback", "revert", "checkpoint",
    },

    blockPatterns = {
        "screenshot", "screen_shot", "screencap", "printscreen",
        "spectate", "ac_flag", "ac_report", "anticheat", "violation",
        "cheat_detect", "flag_player",
    },

    protectedPrefixes = { "ach_", "acr_", "axa_", "axb_" },
}

local C = {
    accent = { 255, 20, 147, 255 },
    white  = { 245, 245, 245, 255 },
    grey   = { 148, 148, 156, 255 },
    green  = { 110, 220, 140, 255 },
    red    = { 240, 100, 105, 255 },
    blue   = { 120, 175, 255, 255 },
}

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local S = {
    antiTeleport = true,
    antiKill     = true,
    antiDelete   = true,
    antiAttach   = true,
    antiVehicle  = true,
    eventShield  = true,
    outbound     = true,
    logSpoof     = true,

    telemetry    = true,
    ghost        = false,
    acFilter     = false,

    harden       = false,
    vehicleArmor = false,
    proofFire    = true,
    proofExplo   = true,
    proofSteam   = true,
    proofDrown   = true,
    proofCollide = false,
    proofBullet  = false,
    armour       = 100,

    propStatebag = true,
    propBone     = 1,
    propDistance = 2,

    targetMode   = 1,
    attachTarget = true,

    antiFreeze   = false,
    antiSpectate = false,
    acShim       = false,
    antiStrip    = true,
    pickupCollect = false,

    vehicleModel = 1,
    vehicleWarp  = true,
}

local PROP_LIST = {
    { label = "Tube corner (XL)",  model = "ar_prop_ar_tube_crn_5d",   extra = 3.5 },
    { label = "Container (XL)",    model = "prop_container_01a",       extra = 4.0 },
    { label = "Container 2 (XL)",  model = "prop_container_05a",       extra = 4.0 },
    { label = "Wood box (xm3)",    model = "xm3_prop_xm3_box_wood03a", extra = 0.0 },
    { label = "Barrel",            model = "prop_barrel_02a",          extra = 0.0 },
    { label = "Bench",             model = "prop_bench_01a",           extra = 0.0 },
    { label = "Road cone",         model = "prop_roadcone02a",         extra = 0.0 },
}

local Spawned = {}

--------------------------------------------------------------------------------
-- UTILITIES
--------------------------------------------------------------------------------

local function Log(level, fmt, ...)
    local message = fmt
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, fmt, ...)
        message = ok and formatted or tostring(fmt)
    end
    print(("[SEED][%s] %s"):format(level, message))
end

local Toasts = {}

local function Notify(message, colour)
    Toasts[#Toasts + 1] = {
        text = tostring(message),
        at = GetGameTimer(),
        colour = colour or C.white,
    }
    if #Toasts > 6 then table.remove(Toasts, 1) end
    Log("INFO", "%s", message)
end

local function IsProtectedChannel(name)
    local lowered = string.lower(tostring(name))
    local head = lowered:sub(1, 4)
    for i = 1, #CFG.protectedPrefixes do
        if head == CFG.protectedPrefixes[i] then return true end
    end
    return false
end

--------------------------------------------------------------------------------
-- SHARED CONTEXT
--------------------------------------------------------------------------------

local Ctx = { ped = 0, player = 0, vehicle = 0, health = 200, maxHealth = 200 }

Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        Ctx.ped = ped
        Ctx.player = PlayerId()
        Ctx.vehicle = GetVehiclePedIsIn(ped, false) or 0
        Ctx.health = GetEntityHealth(ped)
        Ctx.maxHealth = GetEntityMaxHealth(ped)
        Citizen.Wait(250)
    end
end)

--------------------------------------------------------------------------------
-- WRITE GUARD
--------------------------------------------------------------------------------

local mutationGuard = false

local function MutationsBlocked()
    return mutationGuard or _G.SeedBypass == true
end

local function IsLocalPed(entity)
    return type(entity) == "number" and entity ~= 0 and entity == Ctx.ped
end

--------------------------------------------------------------------------------
-- NATIVE HOOKS
--------------------------------------------------------------------------------

local HookStats = { installed = 0, failed = 0 }

local function InstallNativeHooks()
    if type(Api.HookNative) ~= "function" then
        Log("WARN", "HookNative unavailable - Lua fallbacks only")
        return
    end

    local hooks = {
        -- teleport
        {
            name = "SET_ENTITY_COORDS", hash = 0x06843DA7060A026B,
            fn = function(entity)
                if not S.antiTeleport or MutationsBlocked() or not IsLocalPed(entity) then
                    return true
                end
                return false
            end,
        },
        {
            name = "SET_ENTITY_COORDS_NO_OFFSET", hash = 0x239A3351AC1DA385,
            fn = function(entity)
                if not S.antiTeleport or MutationsBlocked() or not IsLocalPed(entity) then
                    return true
                end
                return false
            end,
        },
        {
            name = "SET_PED_COORDS_KEEP_VEHICLE", hash = 0x9AFEFF481A85AB2E,
            fn = function(ped)
                if not S.antiTeleport or MutationsBlocked() or not IsLocalPed(ped) then
                    return true
                end
                return false
            end,
        },

        -- health
        {
            name = "SET_ENTITY_HEALTH", hash = 0x6B76DC1F3AE6E6A3,
            fn = function(entity, health)
                if not S.antiKill or MutationsBlocked() or not IsLocalPed(entity) then
                    return true
                end
                if type(health) ~= "number" then return true end
                if health <= 0 or health < 100 then return false end
                if health < Ctx.health - 50 then return false end
                return true
            end,
        },
        {
            name = "SET_ENTITY_MAX_HEALTH", hash = 0x166E7CF68597D8B5,
            fn = function(entity, maxHealth)
                if not S.antiKill or MutationsBlocked() or not IsLocalPed(entity) then
                    return true
                end
                if type(maxHealth) == "number" and maxHealth < 100 then return false end
                return true
            end,
        },

        -- entity
        {
            name = "DELETE_ENTITY", hash = 0xAE3CBE5BF394C9C9,
            fn = function(entity)
                if not S.antiDelete or MutationsBlocked() or not IsLocalPed(entity) then
                    return true
                end
                return false
            end,
        },
        {
            name = "ATTACH_ENTITY_TO_ENTITY", hash = 0x6B9BBD38AB0796DF,
            fn = function(entity, attachTo)
                if not S.antiAttach or MutationsBlocked() then return true end
                if IsLocalPed(entity) or IsLocalPed(attachTo) then return false end
                return true
            end,
        },

        -- vehicle damage
        {
            name = "SMASH_VEHICLE_WINDOW", hash = 0x9E5B5E4D2CCD2259,
            fn = function(vehicle)
                if not S.antiVehicle or vehicle ~= Ctx.vehicle then return true end
                return false
            end,
        },
        {
            name = "SET_VEHICLE_DOOR_BROKEN", hash = 0xD4D4F6A4AB575A33,
            fn = function(vehicle, _door, deleteDoor)
                if not S.antiVehicle or vehicle ~= Ctx.vehicle then return true end
                if deleteDoor == true then return false end
                return true
            end,
        },

        -- anti-freeze / anti-spectate / shim
        {
            name = "FREEZE_ENTITY_POSITION", hash = 0x428CA6DBD1094446,
            fn = function(entity, toggle)
                if not S.antiFreeze or not IsLocalPed(entity) then return true end
                if toggle == true then return false end
                return true
            end,
        },
        {
            name = "NETWORK_SET_IN_SPECTATOR_MODE", hash = 0x423DE3854BB50894,
            fn = function(toggle, player)
                if not S.antiSpectate or player ~= Ctx.player then return true end
                if toggle == true then return false end
                return true
            end,
        },
        {
            name = "IS_ENTITY_VISIBLE", hash = 0x47D6F43D77935C75,
            fn = function(entity)
                if not S.acShim or not IsLocalPed(entity) then return true end
                return false, true
            end,
        },
        {
            name = "GET_ENTITY_ALPHA", hash = 0x5A47B3B5E63E94C6,
            fn = function(entity)
                if not S.acShim or not IsLocalPed(entity) then return true end
                return false, 255
            end,
        },
        {
            name = "IS_ENTITY_IN_AIR", hash = 0x886E37EC497200B6,
            fn = function(entity)
                if not S.acShim or not IsLocalPed(entity) then return true end
                return false, false
            end,
        },

        -- guardian: ped flags another resource can flip to make you an easy kill
        {
            name = "SET_PED_CONFIG_FLAG", hash = 0x1913FE4CBF41C463,
            fn = function(ped, flagId, value)
                if value ~= true or not IsLocalPed(ped) then return true end
                if flagId == 32 or flagId == 227 or flagId == 243 or flagId == 342 then
                    return false
                end
                return true
            end,
        },
        {
            name = "SET_PED_CAN_RAGDOLL", hash = 0xB128377056A54E2A,
            fn = function(ped, toggle)
                if IsLocalPed(ped) and toggle == false then return false end
                return true
            end,
        },

        -- hardening
        {
            name = "SET_ENTITY_INVINCIBLE", hash = 0x3882114BDE571AD4,
            fn = function(entity, toggle)
                if not S.harden or not IsLocalPed(entity) then return true end
                if toggle == false then return false end
                return true
            end,
        },
        {
            name = "SET_PLAYER_INVINCIBLE", hash = 0x239528EACDC3E7DE,
            fn = function(player, toggle)
                if not S.harden or player ~= Ctx.player then return true end
                if toggle == false then return false end
                return true
            end,
        },
        {
            name = "SET_PED_ARMOUR", hash = 0xCEA04D83135264CC,
            fn = function(ped, armour)
                if not S.harden or not IsLocalPed(ped) then return true end
                if type(armour) == "number" and armour < S.armour then return false end
                return true
            end,
        },
        {
            name = "SET_PLAYER_MAX_ARMOUR", hash = 0x77DFCCF5948B8C71,
            fn = function(player, maximum)
                if not S.harden or player ~= Ctx.player then return true end
                if type(maximum) == "number" and maximum < S.armour then return false end
                return true
            end,
        },
        {
            name = "SET_ENTITY_PROOFS", hash = 0xFAEE099C6F890BB8,
            fn = function(entity, bullet, fire, explosion, collision,
                          melee, steam, p7, drowning)
                if not S.harden or not IsLocalPed(entity) then return true end
                local any = bullet or fire or explosion or collision
                    or melee or steam or p7 or drowning
                if not any then return false end
                return true
            end,
        },
        {
            name = "SET_PED_SUFFERS_CRITICAL_HITS", hash = 0xEBD76F2359F190AC,
            fn = function(ped, toggle)
                if not S.harden or not IsLocalPed(ped) then return true end
                if toggle == true then return false end
                return true
            end,
        },
        {
            name = "SET_PED_DIES_WHEN_INJURED", hash = 0x5BA7919BED300023,
            fn = function(ped, toggle)
                if not S.harden or not IsLocalPed(ped) then return true end
                if toggle == true then return false end
                return true
            end,
        },
        {
            name = "SET_PED_CAN_BE_DRAGGED_OUT", hash = 0xC1670E958EEE24E5,
            fn = function(ped, toggle)
                if not S.harden or not IsLocalPed(ped) then return true end
                if toggle == true then return false end
                return true
            end,
        },
        {
            name = "SET_PED_CAN_RAGDOLL_FROM_PLAYER_IMPACT", hash = 0xDF993EE5E90ABA25,
            fn = function(ped, toggle)
                if not S.harden or not IsLocalPed(ped) then return true end
                if toggle == true then return false end
                return true
            end,
        },

        -- vehicle hold
        {
            name = "SET_VEHICLE_UNDRIVEABLE", hash = 0x8ABA6AF54B942B95,
            fn = function(vehicle, toggle)
                if not S.antiVehicle or vehicle ~= Ctx.vehicle then return true end
                if toggle == true then return false end
                return true
            end,
        },
        {
            name = "SET_VEHICLE_DOORS_LOCKED", hash = 0xB664292EAECF7FA6,
            fn = function(vehicle, status)
                if not S.antiVehicle or vehicle ~= Ctx.vehicle then return true end
                if type(status) == "number" and status > 1 then return false end
                return true
            end,
        },
        {
            name = "SET_VEHICLE_DOORS_LOCKED_FOR_ALL_PLAYERS", hash = 0xA2F80B8D040727CC,
            fn = function(vehicle, toggle)
                if not S.antiVehicle or vehicle ~= Ctx.vehicle then return true end
                if toggle == true then return false end
                return true
            end,
        },
        {
            name = "SET_VEHICLE_ENGINE_HEALTH", hash = 0x45F6D8EEF34ABEF1,
            fn = function(vehicle, health)
                if not S.antiVehicle or vehicle ~= Ctx.vehicle then return true end
                if type(health) == "number" and health < 900.0 then return false end
                return true
            end,
        },
        {
            name = "SET_VEHICLE_BODY_HEALTH", hash = 0xB77D05AC8C78AADB,
            fn = function(vehicle, health)
                if not S.antiVehicle or vehicle ~= Ctx.vehicle then return true end
                if type(health) == "number" and health < 900.0 then return false end
                return true
            end,
        },

        -- anti-freeze setters
        {
            name = "SET_ENTITY_DYNAMIC", hash = 0x1718DE8E3F2823CA,
            fn = function(entity, toggle)
                if not S.antiFreeze or not IsLocalPed(entity) then return true end
                if toggle == false then return false end
                return true
            end,
        },
        {
            name = "NETWORK_IS_IN_SPECTATOR_MODE", hash = 0x048746E388762E11,
            fn = function()
                if S.antiSpectate then return false, false end
                return true
            end,
        },

        -- anti-strip
        {
            name = "SET_PED_COMPONENT_VARIATION", hash = 0x262B14F48D29DE80,
            fn = function(ped, componentId, drawableId, textureId)
                if not S.antiStrip or not IsLocalPed(ped) then return true end
                if type(componentId) == "number" and componentId >= 3
                    and drawableId == 0 and textureId == 0 then
                    return false
                end
                return true
            end,
        },
        {
            name = "SET_PED_PROP_INDEX", hash = 0x93376B65A266EB5F,
            fn = function(ped, _propId, drawableId)
                if not S.antiStrip or not IsLocalPed(ped) then return true end
                if drawableId == -1 then return false end
                return true
            end,
        },
        {
            name = "SET_PED_DEFAULT_COMPONENT_VARIATION", hash = 0x45EEE61580806D63,
            fn = function(ped)
                if S.antiStrip and IsLocalPed(ped) then return false end
                return true
            end,
        },
        {
            name = "SET_PED_RANDOM_COMPONENT_VARIATION", hash = 0xC8A9481A01E63C28,
            fn = function(ped)
                if S.antiStrip and IsLocalPed(ped) then return false end
                return true
            end,
        },
    }

    for i = 1, #hooks do
        local hook = hooks[i]
        local ok = pcall(Api.HookNative, hook.hash, hook.fn)
        if ok then
            HookStats.installed = HookStats.installed + 1
        else
            HookStats.failed = HookStats.failed + 1
            Log("WARN", "hook failed: %s", hook.name)
        end
    end

    Log("INFO", "%d native hooks installed, %d failed", HookStats.installed, HookStats.failed)
end

-- If the engine hook is unavailable, wrap the Lua globals so the same flags
-- still apply inside this VM.
local function InstallLuaFallbacks()
    if HookStats.installed > 0 then return end

    local originalCoords = SetEntityCoords
    _G.SetEntityCoords = function(entity, ...)
        if S.antiTeleport and not MutationsBlocked() and IsLocalPed(entity) then return end
        return originalCoords(entity, ...)
    end

    local originalHealth = SetEntityHealth
    _G.SetEntityHealth = function(entity, health, ...)
        if S.antiKill and not MutationsBlocked() and IsLocalPed(entity)
            and type(health) == "number" and health < 100 then
            return
        end
        return originalHealth(entity, health, ...)
    end

    local originalDelete = DeleteEntity
    _G.DeleteEntity = function(entity, ...)
        if S.antiDelete and not MutationsBlocked() and IsLocalPed(entity) then return end
        return originalDelete(entity, ...)
    end

    local originalAttach = AttachEntityToEntity
    _G.AttachEntityToEntity = function(entity, attachTo, ...)
        if S.antiAttach and not MutationsBlocked()
            and (IsLocalPed(entity) or IsLocalPed(attachTo)) then return end
        return originalAttach(entity, attachTo, ...)
    end

    Log("INFO", "Lua fallback guards installed")
end

--------------------------------------------------------------------------------
-- EVENT SHIELD
--------------------------------------------------------------------------------

local blockedEvents = {}

local function BlockEvent(name)
    if type(name) ~= "string" or name == "" or blockedEvents[name] then return false end
    if IsProtectedChannel(name) then return false end
    if pcall(Api.BlockServerEvent, true, name) then
        blockedEvents[name] = true
        return true
    end
    return false
end

local function SweepEvents(verbose)
    if not S.eventShield then return 0 end

    local ok, events = pcall(Api.GetAllEvent)
    if not ok or type(events) ~= "table" then return 0 end

    local added = 0
    for i = 1, #events do
        local entry = events[i]
        local name = type(entry) == "table" and entry.event or entry
        if type(name) == "string" and not blockedEvents[name] and not IsProtectedChannel(name) then
            local lowered = string.lower(name)
            for p = 1, #CFG.blockPatterns do
                if string.find(lowered, CFG.blockPatterns[p], 1, true) then
                    if BlockEvent(name) then added = added + 1 end
                    break
                end
            end
        end
    end

    if verbose then
        Notify(("Event sweep: %d blocked"):format(added), C.blue)
    end
    return added
end

local function ApplyEventShield(state)
    if state then
        for i = 1, #CFG.blockedEvents do BlockEvent(CFG.blockedEvents[i]) end
        SweepEvents(false)
    else
        for name in pairs(blockedEvents) do
            pcall(Api.BlockServerEvent, false, name)
        end
        blockedEvents = {}
    end
end

local function IsBlockedName(name)
    local lowered = string.lower(tostring(name))
    for i = 1, #CFG.blockedEvents do
        local rule = string.lower(CFG.blockedEvents[i])
        if #rule <= 5 then
            if lowered == rule or lowered:sub(1, #rule + 1) == rule .. ":" then
                return true
            end
        elseif string.find(lowered, rule, 1, true) then
            return true
        end
    end
    return false
end

local logChannels = {
    "log", "report", "anticheat", "ac_", "_ac", "flag", "violation",
    "audit", "monitor", "screenshot", "screen", "detect", "evidence",
    "sanction", "strike", "punish",
}

local spoofRanges = {
    speed = { 5.0, 8.4 },
    velocity = { 5.0, 8.4 },
    health = { 188, 199 },
    hp = { 188, 199 },
    armour = { 0, 0 },
    armor = { 0, 0 },
    wanted = { 0, 0 },
    damage = { 0, 0 },
    god = { 0, 0 },
    distance = { 0.5, 3.0 },
}

local spoofFlags = {
    godmode = false, god = false, invincible = false, noclip = false,
    ghost = false, teleport = false, speedhack = false, cheat = false,
    hacked = false, injected = false, bypass = false, exploit = false,
    detected = false, flagged = false,
}

local function IsLogChannel(name)
    local lowered = string.lower(tostring(name))
    for i = 1, #logChannels do
        if string.find(lowered, logChannels[i], 1, true) then return true end
    end
    return false
end

local function SanitizeValue(value, depth, key)
    if depth > 4 then return value end

    local kind = type(value)
    local lowered = type(key) == "string" and string.lower(key) or ""

    if kind == "number" then
        local range = spoofRanges[lowered]
        if range then
            return range[1] + math.random() * (range[2] - range[1])
        end
        return value
    end

    if kind == "boolean" then
        if spoofFlags[lowered] ~= nil then return spoofFlags[lowered] end
        return value
    end

    if kind == "table" then
        local copy = {}
        for k, v in pairs(value) do
            copy[k] = SanitizeValue(v, depth + 1, k)
        end
        return copy
    end

    return value
end

local unpackArgs = table.unpack or unpack

-- Everything that leaves this VM as a log/report leaves with plausible values.
local originalTriggerServerEvent = TriggerServerEvent
_G.TriggerServerEvent = function(eventName, ...)
    if eventName == nil then
        return originalTriggerServerEvent(eventName, ...)
    end

    if S.outbound and not IsProtectedChannel(eventName) and IsBlockedName(eventName) then
        Log("DEBUG", "outbound blocked: %s", tostring(eventName))
        return
    end

    if S.logSpoof and IsLogChannel(eventName) then
        local count = select("#", ...)
        local args = { n = count, ... }

        for i = 1, count do
            args[i] = SanitizeValue(args[i], 0, nil)
        end

        return originalTriggerServerEvent(eventName, unpackArgs(args, 1, count))
    end

    return originalTriggerServerEvent(eventName, ...)
end

--------------------------------------------------------------------------------
-- TELEMETRY
--------------------------------------------------------------------------------

-- The five main telemetry natives are already hooked by the loader at the top
-- of the file. We only drive its flags, plus a few extra reads of our own.
local function ApplyTelemetry(state)
    S.telemetry = state and true or false

    if type(_Stealth) == "table" then
        _Stealth.health = S.telemetry
        _Stealth.speed = S.telemetry
        _Stealth.invincible = S.telemetry
        _Stealth.stamina = S.telemetry
        _Stealth.ammo = S.telemetry
    end
end

local TelemetryStats = { installed = 0, failed = 0 }

local function InstallTelemetryHooks()
    if type(Api.HookNative) ~= "function" then return end

    local hooks = {
        {
            name = "GET_ENTITY_HEIGHT_ABOVE_GROUND", hash = 0x1DD55701034110E5,
            fn = function(entity)
                if not S.telemetry or entity ~= Ctx.ped then return true end
                return false, 0.0
            end,
        },
        {
            name = "GET_PLAYER_WANTED_LEVEL", hash = 0xE28E54788CE8F12D,
            fn = function(player)
                if not S.telemetry or player ~= Ctx.player then return true end
                return false, 0
            end,
        },
        {
            name = "GET_PED_ARMOUR", hash = 0x9483AF821605B1D8,
            fn = function(entity)
                if not S.telemetry or entity ~= Ctx.ped then return true end
                return false, 0
            end,
        },
        {
            name = "GET_ENTITY_MAX_HEALTH", hash = 0x15D757606D170C3C,
            fn = function(entity)
                if not S.telemetry or entity ~= Ctx.ped then return true end
                return false, 200
            end,
        },
        {
            name = "GET_VEHICLE_ENGINE_HEALTH", hash = 0xC45D23BAF168AAB8,
            fn = function(vehicle)
                if not S.telemetry or Ctx.vehicle == 0 or vehicle ~= Ctx.vehicle then return true end
                return false, 1000.0
            end,
        },
        {
            name = "GET_VEHICLE_BODY_HEALTH", hash = 0xF271147EB7B40F12,
            fn = function(vehicle)
                if not S.telemetry or Ctx.vehicle == 0 or vehicle ~= Ctx.vehicle then return true end
                return false, 1000.0
            end,
        },
        {
            name = "IS_PLAYER_WANTED_LEVEL_GREATER", hash = 0x238DB2A2C23EE9EF,
            fn = function(player)
                if not S.telemetry or player ~= Ctx.player then return true end
                return false, false
            end,
        },
    }

    for i = 1, #hooks do
        local ok = pcall(Api.HookNative, hooks[i].hash, hooks[i].fn)
        if ok then
            TelemetryStats.installed = TelemetryStats.installed + 1
        else
            TelemetryStats.failed = TelemetryStats.failed + 1
            Log("WARN", "telemetry hook failed: %s", hooks[i].name)
        end
    end

    Log("INFO", "%d extra telemetry hooks installed, %d failed",
        TelemetryStats.installed, TelemetryStats.failed)
end

--------------------------------------------------------------------------------
-- GHOST
--------------------------------------------------------------------------------

local function ApplyGhost()
    local ped = Ctx.ped
    if ped == 0 then return end

    pcall(SetLocalPlayerAsGhost, true)
    pcall(SetGhostAlpha, 0)

    if Ctx.vehicle ~= 0 then
        pcall(SetNetworkVehicleAsGhost, Ctx.vehicle, true)
    end
end

local function ClearGhost()
    pcall(SetLocalPlayerAsGhost, false)
    pcall(ResetGhostAlpha)

    local ped = PlayerPedId()
    pcall(SetEntityLocallyVisible, ped)

    local veh = GetVehiclePedIsIn(ped, false)
    if veh and veh ~= 0 then
        pcall(SetNetworkVehicleAsGhost, veh, false)
    end
end

--------------------------------------------------------------------------------
-- HARDENING
--------------------------------------------------------------------------------

local function ApplyHarden()
    local ped = Ctx.ped
    if ped == 0 then return end

    pcall(SetEntityProofs, ped,
        S.proofBullet, S.proofFire, S.proofExplo, S.proofCollide,
        false, S.proofSteam, false, S.proofDrown)

    pcall(SetPedSuffersCriticalHits, ped, false)
    pcall(SetPedDiesWhenInjured, ped, false)
    pcall(SetPedCanRagdollFromPlayerImpact, ped, false)
    pcall(SetPedCanBeDraggedOut, ped, false)
    pcall(SetPedArmour, ped, S.armour)
    pcall(SetPlayerMaxArmour, Ctx.player, S.armour)

    if S.vehicleArmor and Ctx.vehicle ~= 0 then
        local veh = Ctx.vehicle
        pcall(SetVehicleTyresCanBurst, veh, false)
        pcall(SetVehicleStrong, veh, true)
        pcall(SetVehicleEngineCanDegrade, veh, false)
        pcall(SetVehicleCanBeVisiblyDamaged, veh, false)
        pcall(SetVehicleHasStrongAxles, veh, true)
        pcall(SetVehicleCanBeTargetted, veh, false)
        pcall(SetVehicleUndriveable, veh, false)

        pcall(function()
            if not NetworkHasControlOfEntity(veh) then
                NetworkRequestControlOfEntity(veh)
            end
            SetEntityAsMissionEntity(veh, true, true)
            SetVehicleDoorsLocked(veh, 1)
            SetVehicleDoorsLockedForAllPlayers(veh, false)
        end)
    end
end

local function ClearHarden()
    local ped = PlayerPedId()
    pcall(SetEntityProofs, ped, false, false, false, false, false, false, false, false)
    pcall(SetPedSuffersCriticalHits, ped, true)
    pcall(SetPedDiesWhenInjured, ped, true)
    pcall(SetPedCanRagdollFromPlayerImpact, ped, true)
    pcall(SetPedCanBeDraggedOut, ped, true)

    local veh = GetVehiclePedIsIn(ped, false)
    if veh and veh ~= 0 then
        pcall(SetVehicleTyresCanBurst, veh, true)
        pcall(SetVehicleStrong, veh, false)
        pcall(SetVehicleEngineCanDegrade, veh, true)
        pcall(SetVehicleCanBeVisiblyDamaged, veh, true)
        pcall(SetVehicleHasStrongAxles, veh, false)
        pcall(SetVehicleCanBeTargetted, veh, true)
    end
end

--------------------------------------------------------------------------------
-- ANTI-FREEZE / ANTI-SPECTATE
--------------------------------------------------------------------------------

local function ApplyAntiFreeze()
    local ped = Ctx.ped
    if ped == 0 then return end

    pcall(FreezeEntityPosition, ped, false)
    pcall(SetEntityDynamic, ped, true)

    local ok, attachedTo = pcall(GetEntityAttachedTo, ped)
    if ok and attachedTo and attachedTo ~= 0 then
        pcall(DetachEntity, ped, true, true)
        Notify("Foreign attachment removed", C.red)
    end

    if Ctx.vehicle ~= 0 then
        pcall(FreezeEntityPosition, Ctx.vehicle, false)
        pcall(SetVehicleUndriveable, Ctx.vehicle, false)
    end
end

local function ApplyAntiSpectate()
    local ok, spectating = pcall(NetworkIsInSpectatorMode)
    if ok and spectating then
        pcall(NetworkSetInSpectatorMode, false, Ctx.ped)
        Notify("Forced spectator mode broken", C.red)
    end
end

--------------------------------------------------------------------------------
-- MODELS
--------------------------------------------------------------------------------

local function LoadModel(hash, model)
    RequestModel(hash)

    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then
            SetModelAsNoLongerNeeded(hash)
            return false, ("%s never streamed"):format(model)
        end
        Citizen.Wait(10)
    end

    return true
end

--------------------------------------------------------------------------------
-- SPOOFED VEHICLE (Susano.CreateSpoofedVehicle)
--------------------------------------------------------------------------------

local VEHICLES = {
    { label = "Adder",             model = "adder" },
    { label = "Zentorno",          model = "zentorno" },
    { label = "Kuruma (armoured)", model = "kuruma2" },
    { label = "Insurgent",         model = "insurgent2" },
    { label = "Oppressor Mk II",   model = "oppressor2" },
    { label = "Deluxo",            model = "deluxo" },
    { label = "Sultan RS",         model = "sultanrs" },
    { label = "Bati 801",          model = "bati" },
}

local vehicleLabels = {}

for i = 1, #VEHICLES do
    vehicleLabels[i] = VEHICLES[i].label
end

local LastVehicle = 0
local vehicleItem = nil

local function DeleteLastVehicle()
    if LastVehicle == 0 or not DoesEntityExist(LastVehicle) then
        Notify("No spawned vehicle", C.red)
        return
    end

    pcall(NetworkRequestControlOfEntity, LastVehicle)
    pcall(SetEntityAsMissionEntity, LastVehicle, true, true)
    pcall(DeleteVehicle, LastVehicle)
    LastVehicle = 0
    Notify("Vehicle deleted", C.blue)
end

local function SpawnSpoofedVehicle()
    local index = vehicleItem and vehicleItem.selected or S.vehicleModel
    local entry = VEHICLES[index] or VEHICLES[1]
    S.vehicleModel = index

    Citizen.CreateThread(function()
        local hash = GetHashKey(entry.model)
        local loaded, reason = LoadModel(hash, entry.model)
        if not loaded then
            Notify(reason, C.red)
            return
        end

        local ped = PlayerPedId()
        local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 4.0, 0.0)
        local heading = GetEntityHeading(ped)

        -- Spoofed creation semantics: the entity does not carry the usual
        -- script-created footprint on the server side.
        local spoofed = false
        local vehicle = 0

        if type(Api.CreateSpoofedVehicle) == "function" then
            local ok, result = pcall(Api.CreateSpoofedVehicle, hash,
                coords.x, coords.y, coords.z, heading, true, true, false)
            if ok and type(result) == "number" and result ~= 0 then
                vehicle = result
                spoofed = true
            end
        end

        if vehicle == 0 then
            local ok, result = pcall(CreateVehicle, hash,
                coords.x, coords.y, coords.z, heading, true, true)
            if ok and type(result) == "number" and result ~= 0 then
                vehicle = result
            end
        end

        if vehicle == 0 then
            Notify(("%s spawn failed"):format(entry.label), C.red)
            SetModelAsNoLongerNeeded(hash)
            return
        end

        pcall(SetVehicleOnGroundProperly, vehicle)
        pcall(SetEntityAsMissionEntity, vehicle, true, true)
        pcall(SetVehicleHasBeenOwnedByPlayer, vehicle, true)

        if S.vehicleWarp then
            pcall(SetPedIntoVehicle, ped, vehicle, -1)
        end

        LastVehicle = vehicle
        Notify(("%s spawned (%s)"):format(entry.label,
            spoofed and "spoofed" or "native"), spoofed and C.green or C.blue)

        SetModelAsNoLongerNeeded(hash)
    end)
end

local function RepairVehicle()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if not veh or veh == 0 then
        Notify("Not in a vehicle", C.red)
        return
    end

    pcall(SetVehicleFixed, veh)
    pcall(SetVehicleDeformationFixed, veh)
    pcall(SetVehicleEngineHealth, veh, 1000.0)
    pcall(SetVehicleBodyHealth, veh, 1000.0)
    pcall(SetVehiclePetrolTankHealth, veh, 1000.0)
    Notify("Vehicle repaired", C.green)
end

--------------------------------------------------------------------------------
-- PICKUP COLLECTION
--------------------------------------------------------------------------------

local PICKUP_TYPES = {
    "PICKUP_WEAPON_ASSAULTRIFLE",
    "PICKUP_WEAPON_CARBINERIFLE",
    "PICKUP_HEALTH_STANDARD",
    "PICKUP_ARMOUR_STANDARD",
    "PICKUP_MONEY_VARIABLE",
}

local function ApplyPickupCollection(state)
    local player = PlayerId()
    local enabled = state and true or false

    pcall(function()
        if type(SetLocalPlayerCanCollectPortablePickups) == "function" then
            SetLocalPlayerCanCollectPortablePickups(enabled)
        end
    end)

    for i = 1, #PICKUP_TYPES do
        local hash = GetHashKey(PICKUP_TYPES[i])
        pcall(function()
            if type(SetPlayerPermittedToCollectPickupsOfType) == "function" then
                SetPlayerPermittedToCollectPickupsOfType(player, hash, enabled)
            end
        end)
    end
end

local function SpawnPickup(entry)
    Citizen.CreateThread(function()
        local hash = GetHashKey(entry.model)
        RequestModel(hash)

        local deadline = GetGameTimer() + 3000
        while not HasModelLoaded(hash) and GetGameTimer() < deadline do
            Citizen.Wait(10)
        end

        local ped = PlayerPedId()
        local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.5, 0.0)

        local previous = _G.SeedBypass
        _G.SeedBypass = true
        local ok, pickup = pcall(CreatePickupRotate, hash,
            coords.x, coords.y, coords.z + 0.2,
            0.0, 0.0, 0.0, 8, entry.amount or 100, 0, true, hash)
        _G.SeedBypass = previous

        SetModelAsNoLongerNeeded(hash)

        if ok and pickup and pickup ~= 0 then
            Notify(("%s spawned"):format(entry.label), C.green)
        else
            Notify(("%s blocked by the server"):format(entry.label), C.red)
        end
    end)
end

--------------------------------------------------------------------------------
-- PROP SPAWNER
--------------------------------------------------------------------------------

local function AttachToBone(obj, boneName, entity)
    local boneIndex = CFG.boneIds[string.lower(tostring(boneName or ""))]
    if not boneIndex then return false end

    local target = entity or PlayerPedId()
    local previous = _G.SeedBypass
    _G.SeedBypass = true
    local ok = pcall(AttachEntityToEntity, obj, target, boneIndex,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        false, false, false, true, 2, true)
    _G.SeedBypass = previous

    if not ok then return false end

    -- A remote ped cannot be verified with GetEntityAttachedTo, the link is
    -- owned by the other client. Local ped: verify the real link.
    if target ~= PlayerPedId() then return true end

    Citizen.Wait(0)
    return GetEntityAttachedTo(obj) == target
end

-- Local CreateObject only exists for this client. Registering the entity on
-- the network gives it a network ID, which is what makes other players see it.
local function EnsureNetworked(obj)
    if not obj or obj == 0 or not DoesEntityExist(obj) then return 0 end

    local function published(netId)
        if type(netId) ~= "number" or netId == 0 then return 0 end
        pcall(SetNetworkIdExistsOnAllMachines, netId, true)
        pcall(SetNetworkIdCanMigrate, netId, true)
        return netId
    end

    local ok, netId = pcall(NetworkGetNetworkIdFromEntity, obj)
    if ok and type(netId) == "number" and netId ~= 0 then return published(netId) end

    pcall(NetworkRegisterEntityAsNetworked, obj)

    for _ = 1, 10 do
        Citizen.Wait(50)
        ok, netId = pcall(NetworkGetNetworkIdFromEntity, obj)
        if ok and type(netId) == "number" and netId ~= 0 then return published(netId) end
    end

    return 0
end

local function SpawnProp(model, extra, targetPed, targetName, attachToTarget)
    Citizen.CreateThread(function()
        local hash = GetHashKey(model)
        local loaded, reason = LoadModel(hash, model)
        if not loaded then
            Notify(reason, C.red)
            return
        end

        local localPed = PlayerPedId()
        local remote = targetPed ~= nil and targetPed ~= 0 and targetPed ~= localPed
        local ped = remote and targetPed or localPed
        local who = remote and (targetName or "player") or nil

        if not DoesEntityExist(ped) then
            Notify("Target ped is gone", C.red)
            SetModelAsNoLongerNeeded(hash)
            return
        end

        local heading = GetEntityHeading(ped)
        local pitch = GetEntityPitch(ped)
        local roll = GetEntityRoll(ped)

        local target
        local forward = 0.0

        if remote then
            local coords = GetEntityCoords(ped)
            target = vector3(coords.x, coords.y, coords.z)
        else
            local distance = CFG.distanceM[CFG.distances[S.propDistance]] or 3.0
            forward = distance + (extra or 0.0)
            target = GetOffsetFromEntityInWorldCoords(ped, 0.0, forward, 0.0)
        end

        local consumerObj = 0

        -- The server statebag only knows about the local player; a remote
        -- target goes straight to the networked native path.
        if S.propStatebag and not remote then
            local state = LocalPlayer.state
            local payload = {
                {
                    model = model,
                    coords = target,
                    rot = vector3(pitch, roll, heading),
                    collision = false,
                },
            }

            local wrote = pcall(function()
                state:set("lib:progressProps", payload, true)
            end)

            if wrote then
                Citizen.Wait(CFG.propWait)
                local radius = math.max(CFG.propRadius, forward + 2.0)
                consumerObj = GetClosestObjectOfType(target.x, target.y, target.z,
                    radius, hash, false, false, false) or 0
            end

            if consumerObj == 0 then
                pcall(function() state:set("lib:progressProps", {}, true) end)
            end
        end

        if consumerObj ~= 0 then
            local netId = EnsureNetworked(consumerObj)
            Spawned[#Spawned + 1] = consumerObj

            if netId > 0 then
                Notify(("Server prop: %s (net %d)"):format(model, netId), C.green)
            else
                Notify(("Server prop: %s (local only)"):format(model), C.red)
            end

            SetModelAsNoLongerNeeded(hash)
            return
        end

        -- isNetwork = true, netMissionEntity = true: the object is replicated
        -- to every player in scope, not just this client.
        local obj = CreateObject(hash, target.x, target.y, target.z, true, true, false)
        if not obj or obj == 0 then
            Notify(("CreateObject failed: %s"):format(model), C.red)
            SetModelAsNoLongerNeeded(hash)
            return
        end

        SetEntityRotation(obj, pitch, roll, heading, 2, true)
        SetEntityAsMissionEntity(obj, true, true)
        FreezeEntityPosition(obj, true)

        local bone = CFG.bones[S.propBone]
        local attached = false
        local wantsAttach = bone and bone ~= "off" and (not remote or attachToTarget)

        if wantsAttach then
            attached = AttachToBone(obj, bone, ped)
        end

        if not attached and not remote then
            PlaceObjectOnGroundProperly(obj)
        end

        local netId = EnsureNetworked(obj)
        Spawned[#Spawned + 1] = obj

        local suffix
        if remote then
            suffix = attached and (" on " .. who) or (" at " .. who)
        elseif attached then
            suffix = " on " .. bone
        else
            suffix = ""
        end

        if netId > 0 then
            Notify(("Spawned %s%s (net %d)"):format(model, suffix, netId), C.green)
        else
            Notify(("Spawned %s%s (local only)"):format(model, suffix), C.red)
        end

        SetModelAsNoLongerNeeded(hash)
    end)
end

local function ClearProps()
    local removed = 0
    for i = #Spawned, 1, -1 do
        local obj = Spawned[i]
        if obj and obj ~= 0 and DoesEntityExist(obj) then
            pcall(NetworkRequestControlOfEntity, obj)
            pcall(SetEntityAsMissionEntity, obj, true, true)
            if pcall(DeleteObject, obj) then removed = removed + 1 end
        end
        Spawned[i] = nil
    end

    pcall(function() LocalPlayer.state:set("lib:progressProps", {}, true) end)
    Notify(("%d prop(s) cleared"):format(removed), C.blue)
end

--------------------------------------------------------------------------------
-- PLAYERS
--------------------------------------------------------------------------------

local Players = { list = {}, index = 1 }

local function RefreshPlayers()
    local list = {}

    if type(GetActivePlayers) == "function" then
        local ok, active = pcall(GetActivePlayers)
        if ok and type(active) == "table" then
            local localPlayer = PlayerId()

            for i = 1, #active do
                local player = active[i]
                if player ~= localPlayer then
                    local okPed, ped = pcall(GetPlayerPed, player)
                    if okPed and ped and ped ~= 0 and DoesEntityExist(ped) then
                        local okName, name = pcall(GetPlayerName, player)
                        local okId, serverId = pcall(GetPlayerServerId, player)

                        list[#list + 1] = {
                            player = player,
                            ped = ped,
                            name = okName and tostring(name) or ("player " .. tostring(player)),
                            serverId = okId and serverId or 0,
                        }
                    end
                end
            end
        end
    end

    Players.list = list
    if #list == 0 or Players.index > #list then Players.index = 1 end
    return #list
end

local function SelectedEntry()
    local entry = Players.list[Players.index]
    if not entry then return nil end

    local okPed, ped = pcall(GetPlayerPed, entry.player)
    if okPed and ped and ped ~= 0 and DoesEntityExist(ped) then
        entry.ped = ped
        return entry
    end

    return nil
end

local function CurrentTargetLabel()
    local mode = CFG.targetModes[S.targetMode] or "me"

    if mode == "me" then return "me" end
    if mode == "all" then return ("all players (%d)"):format(#Players.list) end

    local entry = Players.list[Players.index]
    if not entry then return "none" end
    return ("%s [%s]"):format(entry.name, tostring(entry.serverId))
end

local function CyclePlayer()
    local count = RefreshPlayers()
    if count == 0 then
        Notify("No other player nearby", C.red)
        return
    end

    Players.index = (Players.index % count) + 1
    local entry = Players.list[Players.index]
    Notify(("Target: %s [%s]"):format(entry.name, tostring(entry.serverId)), C.blue)
end

-- Spawns on all players in three modes: me, the selected player, or everyone
-- in the player list (capped so the network does not get flooded).
local function SpawnOnTargets(model, extra)
    local mode = CFG.targetModes[S.targetMode] or "me"

    if mode == "me" then
        SpawnProp(model, extra)
        return
    end

    if mode == "selected" then
        RefreshPlayers()
        local entry = SelectedEntry()
        if not entry then
            Notify("No player selected", C.red)
            return
        end
        SpawnProp(model, extra, entry.ped, entry.name, S.attachTarget)
        return
    end

    local count = RefreshPlayers()
    if count == 0 then
        SpawnProp(model, extra)
        return
    end

    local limit = math.min(count, 6)
    for i = 1, limit do
        local entry = Players.list[i]
        local okPed, ped = pcall(GetPlayerPed, entry.player)
        if okPed and ped and ped ~= 0 and DoesEntityExist(ped) then
            SpawnProp(model, extra, ped, entry.name, S.attachTarget)
        end
    end
end

--------------------------------------------------------------------------------
-- ANCHOR / DIAGNOSTICS
--------------------------------------------------------------------------------

local Anchor = { coords = nil, heading = 0.0 }

local function SaveAnchor()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    Anchor.coords = vector3(coords.x, coords.y, coords.z)
    Anchor.heading = GetEntityHeading(ped)

    Notify(("Anchor saved: %.1f, %.1f, %.1f"):format(coords.x, coords.y, coords.z), C.blue)
end

local function ReturnAnchor()
    if not Anchor.coords then
        Notify("No anchor saved", C.red)
        return
    end

    local previous = _G.SeedBypass
    _G.SeedBypass = true

    local ped = PlayerPedId()
    pcall(SetEntityCoords, ped, Anchor.coords.x, Anchor.coords.y, Anchor.coords.z,
        false, false, false, true)
    pcall(SetEntityHeading, ped, Anchor.heading)

    _G.SeedBypass = previous
    Notify("Back to anchor", C.green)
end

local function GuardSelfTest()
    Citizen.CreateThread(function()
        local previous = S.telemetry
        S.telemetry = false

        local ok, message = pcall(function()
            local ped = PlayerPedId()
            local before = GetEntityCoords(ped)
            local results = {}

            pcall(SetEntityCoords, ped, before.x + 2.0, before.y + 2.0, before.z,
                false, false, false, true)
            Citizen.Wait(250)

            local after = GetEntityCoords(ped)
            local moved = math.abs(after.x - before.x) + math.abs(after.y - before.y) > 1.0
            results[#results + 1] = ("teleport=%s"):format(moved and "FAIL" or "blocked")

            local beforeHealth = GetEntityHealth(ped)
            pcall(SetEntityHealth, ped, 50)
            Citizen.Wait(250)

            local afterHealth = GetEntityHealth(ped)
            local damaged = afterHealth < math.min(beforeHealth, 150)
            results[#results + 1] = ("health=%s"):format(damaged and "FAIL" or "blocked")

            return table.concat(results, " ")
        end)

        S.telemetry = previous

        if ok then
            Log("DIAG", "guard self-test: %s", tostring(message))
            Notify("Guard self-test: " .. tostring(message), C.blue)
        else
            Log("DIAG", "guard self-test error: %s", tostring(message))
            Notify("Guard self-test unavailable", C.red)
        end
    end)
end

local function ApiReport()
    local names = {}

    for key, value in pairs(Api) do
        names[#names + 1] = ("%s:%s"):format(tostring(key), type(value))
    end

    table.sort(names)
    Log("DIAG", "Susano API (%d entries):", #names)

    for i = 1, #names do
        Log("DIAG", "  %s", names[i])
    end

    Notify(("%d Susano entries - see F8"):format(#names), C.blue)
end

local function DiagSummary()
    Log("DIAG", "---- summary ----")
    Log("DIAG", "native hooks: %d installed / %d failed", HookStats.installed, HookStats.failed)
    Log("DIAG", "extra telemetry hooks: %d installed / %d failed",
        TelemetryStats.installed, TelemetryStats.failed)
    Log("DIAG", "spoof: telemetry=%s logPayloads=%s outboundFilter=%s",
        tostring(S.telemetry), tostring(S.logSpoof), tostring(S.outbound))

    local count = 0
    for _ in pairs(blockedEvents) do count = count + 1 end
    Log("DIAG", "inbound blocked: %d", count)

    Log("DIAG", "prop statebag=%s bone=%s distance=%s",
        tostring(S.propStatebag), CFG.bones[S.propBone], CFG.distances[S.propDistance])

    local ped = PlayerPedId()
    Log("DIAG", "speed=%.2f height=%.2f health=%d armour=%d wanted=%d",
        GetEntitySpeed(ped), GetEntityHeightAboveGround(ped), GetEntityHealth(ped),
        GetPedArmour(ped), GetPlayerWantedLevel(PlayerId()))

    Notify("Diagnostics in F8", C.blue)
end

local function DiagProp(model)
    model = model or "ar_prop_ar_tube_crn_5d"

    Citizen.CreateThread(function()
        Log("DIAG", "---- prop test: %s ----", model)
        local hash = GetHashKey(model)
        Log("DIAG", "valid=%s cdimage=%s",
            tostring(IsModelValid(hash)), tostring(IsModelInCdimage(hash)))

        local loaded, reason = LoadModel(hash, model)
        if not loaded then
            Log("DIAG", "FAIL: %s", tostring(reason))
            Notify("Prop test: model unavailable", C.red)
            return
        end

        local ped = PlayerPedId()
        local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 3.0, 0.0)
        local heading = GetEntityHeading(ped)

        local payload = {
            { model = model, coords = coords, rot = vector3(0.0, 0.0, heading), collision = false },
        }
        local wrote = pcall(function()
            LocalPlayer.state:set("lib:progressProps", payload, true)
        end)
        Log("DIAG", "statebag write=%s", tostring(wrote))

        Citizen.Wait(1500)
        local consumer = GetClosestObjectOfType(coords.x, coords.y, coords.z, 6.0, hash, false, false, false)
        Log("DIAG", "consumer probe=%s", tostring(consumer))
        pcall(function() LocalPlayer.state:set("lib:progressProps", {}, true) end)

        local obj = CreateObject(hash, coords.x, coords.y, coords.z + 0.6, true, true, false)
        local exists = obj ~= 0 and DoesEntityExist(obj)
        Log("DIAG", "CreateObject=%s exists=%s", tostring(obj), tostring(exists))

        if exists then
            local netId = EnsureNetworked(obj)
            Log("DIAG", "netId=%s (non-zero = visible to other players)", tostring(netId))

            local previous = _G.SeedBypass
            _G.SeedBypass = true
            pcall(AttachEntityToEntity, obj, ped, 57005,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, true, 2, true)
            _G.SeedBypass = previous
            Citizen.Wait(300)

            local attached = GetEntityAttachedTo(obj)
            Log("DIAG", "attach test: attachedTo=%s (ped=%s)", tostring(attached), tostring(ped))
            Log("DIAG", "verdict: %s",
                attached == ped and "attach path OK" or "attach blocked - prop drops on the ground")

            pcall(DeleteObject, obj)
        end

        if consumer ~= 0 then
            pcall(DeleteObject, consumer)
        end

        SetModelAsNoLongerNeeded(hash)
        Notify("Prop test done - see F8", C.blue)
    end)
end

local function DiagInput()
    local function state(code)
        if type(Api.GetAsyncKeyState) == "function" then
            local ok, down, pressed = pcall(Api.GetAsyncKeyState, code)
            if ok then return tostring(down), tostring(pressed) end
            return "err", "err"
        end
        return "n/a", "n/a"
    end

    Log("DIAG", "GetAsyncKeyState=%s IsRawKeyPressed=%s",
        type(Api.GetAsyncKeyState), type(IsRawKeyPressed))

    local menuKey = Menu.SelectedKey or 0x31
    Log("DIAG", "hold the menu key (0x%02X), UP, DOWN, A, E, ENTER within the next 6 seconds", menuKey)

    Citizen.CreateThread(function()
        local deadline = GetGameTimer() + 6000
        while GetGameTimer() < deadline do
            Log("DIAG", "menu=0x%02X %s | UP=%s DOWN=%s A=%s E=%s ENTER=%s",
                menuKey, state(menuKey), state(0x26), state(0x28), state(0x41), state(0x45), state(0x0D))
            Citizen.Wait(350)
        end
        Log("DIAG", "input probe done")
    end)
end

--------------------------------------------------------------------------------
-- TOASTS (drawn on top of the loader frame through Menu.OnRender)
--------------------------------------------------------------------------------

local function DrawToasts()
    if #Toasts == 0 then return end
    if type(Api.DrawRectFilled) ~= "function" or type(Api.DrawText) ~= "function" then return end

    local now = GetGameTimer()

    for i = #Toasts, 1, -1 do
        if now - (Toasts[i].at or now) > 6000 then table.remove(Toasts, i) end
    end

    local x = 24
    local y = 150
    local width = 340
    local height = 24
    local gap = 4

    for i = 1, #Toasts do
        local toast = Toasts[i]
        local age = now - (toast.at or now)
        local alpha = math.min(1.0, math.max(0.0, (6000 - age) / 900))
        local colour = toast.colour or C.white

        local top = y + (i - 1) * (height + gap)

        pcall(Api.DrawRectFilled, x, top, width, height, 0.04, 0.04, 0.05, 0.82 * alpha, 4)
        pcall(Api.DrawRectFilled, x, top, 3, height,
            colour[1] / 255, colour[2] / 255, colour[3] / 255, alpha, 2)
        pcall(Api.DrawText, x + 12, top + 4, tostring(toast.text), 15,
            0.96, 0.96, 0.96, alpha)
    end
end

local previousOnRender = Menu.OnRender

Menu.OnRender = function()
    if previousOnRender then
        local ok, err = pcall(previousOnRender)
        if not ok then Log("DEBUG", "loader OnRender: %s", tostring(err)) end
    end

    local ok, err = pcall(DrawToasts)
    if not ok then Log("DEBUG", "toast draw: %s", tostring(err)) end
end

--------------------------------------------------------------------------------
-- MENU ITEMS
--------------------------------------------------------------------------------

local function Sep(text)
    return { name = "", isSeparator = true, separatorText = text }
end

local function Toggle(name, initial, handler)
    return { name = name, type = "toggle", value = initial, onClick = handler }
end

local function Action(name, handler)
    return { name = name, type = "action", onClick = handler }
end

local function Selector(name, options, selected, handler)
    return { name = name, type = "selector", options = options, selected = selected, onClick = handler }
end

local targetModeItem = Selector("Target", CFG.targetModes, S.targetMode, function(index)
    S.targetMode = index
    Notify("Target mode: " .. tostring(CFG.targetModes[index]), C.blue)
end)

local playerItem = Selector("Player", { "none" }, 1, function(index)
    Players.index = index
    Notify("Target: " .. tostring(playerItem.options[index]), C.blue)
end)

local boneItem = Selector("Attach bone", CFG.bones, S.propBone, function(index)
    S.propBone = index
end)

local distanceItem = Selector("Distance", CFG.distances, S.propDistance, function(index)
    S.propDistance = index
end)

vehicleItem = Selector("Model", vehicleLabels, S.vehicleModel, function(index)
    S.vehicleModel = index
end)

local function SyncSelectors()
    -- LEFT / RIGHT do not fire onClick; read the live index on use.
    S.targetMode = math.max(1, math.min(#CFG.targetModes, targetModeItem.selected or 1))
    S.propBone = math.max(1, math.min(#CFG.bones, boneItem.selected or 1))
    S.propDistance = math.max(1, math.min(#CFG.distances, distanceItem.selected or 1))

    if vehicleItem and vehicleItem.selected then
        S.vehicleModel = math.max(1, math.min(#VEHICLES, vehicleItem.selected))
    end
end

local function PlayerItemSync()
    if playerItem and playerItem.selected then
        local count = math.max(1, #(playerItem.options or {}))
        Players.index = math.max(1, math.min(count, playerItem.selected))
    end
end

local function RefreshPlayerItem()
    local count = RefreshPlayers()
    local labels = {}

    for i = 1, count do
        local entry = Players.list[i]
        local shortName = tostring(entry.name)
        if #shortName > 14 then shortName = shortName:sub(1, 14) end
        labels[i] = ("%s [%s]"):format(shortName, tostring(entry.serverId))
    end

    if #labels == 0 then labels[1] = "none" end
    playerItem.options = labels

    if (playerItem.selected or 1) > #labels then playerItem.selected = 1 end
    PlayerItemSync()
end

local function SpawnPropOnTargets(model, extra)
    SyncSelectors()
    PlayerItemSync()
    SpawnOnTargets(model, extra)
end

-- Prop entries -------------------------------------------------------------

local propActions = {}

for i = 1, #PROP_LIST do
    local entry = PROP_LIST[i]
    propActions[#propActions + 1] = Action(entry.label, function()
        SpawnPropOnTargets(entry.model, entry.extra)
    end)
end

-- Tab contents -------------------------------------------------------------

local guardItems = {
    Sep("Protections"),
    Toggle("Anti teleport", S.antiTeleport, function(v) S.antiTeleport = v end),
    Toggle("Anti health write", S.antiKill, function(v) S.antiKill = v end),
    Toggle("Anti ped delete", S.antiDelete, function(v) S.antiDelete = v end),
    Toggle("Anti attach", S.antiAttach, function(v) S.antiAttach = v end),
    Toggle("Anti vehicle damage", S.antiVehicle, function(v) S.antiVehicle = v end),
    Toggle("Anti strip", S.antiStrip, function(v) S.antiStrip = v end),
    Toggle("Anti freeze", S.antiFreeze, function(v)
        S.antiFreeze = v
        if v then ApplyAntiFreeze() end
    end),
    Toggle("Anti spectate", S.antiSpectate, function(v)
        S.antiSpectate = v
        if v then ApplyAntiSpectate() end
    end),
    Toggle("AC shim (visibility)", S.acShim, function(v) S.acShim = v end),

    Sep("Combat"),
    Toggle("Harden (master)", S.harden, function(v)
        S.harden = v
        if v then ApplyHarden() else ClearHarden() end
    end),
    Toggle("Vehicle hardening", S.vehicleArmor, function(v) S.vehicleArmor = v end),

    Sep("Events"),
    Toggle("Inbound event shield", S.eventShield, function(v)
        S.eventShield = v
        ApplyEventShield(v)
    end),
    Toggle("Outbound report filter", S.outbound, function(v) S.outbound = v end),
    Toggle("Log payload spoof", S.logSpoof, function(v) S.logSpoof = v end),
    Action("Sweep events now", function() SweepEvents(true) end),
}

local evasionItems = {
    Toggle("Telemetry spoof", S.telemetry, function(v) ApplyTelemetry(v) end),
    Toggle("AC event filter", S.acFilter, function(v)
        S.acFilter = v
        if type(_Stealth) == "table" then _Stealth.blockAC = v end
    end),
    Toggle("Ghost mode", S.ghost, function(v)
        S.ghost = v
        if v then ApplyGhost() else ClearGhost() end
    end),

    Sep("Proofs (applied by harden)"),
    Toggle("Proof: bullets", S.proofBullet, function(v) S.proofBullet = v end),
    Toggle("Proof: fire", S.proofFire, function(v) S.proofFire = v end),
    Toggle("Proof: explosion", S.proofExplo, function(v) S.proofExplo = v end),
    Toggle("Proof: collision", S.proofCollide, function(v) S.proofCollide = v end),
    Toggle("Proof: steam", S.proofSteam, function(v) S.proofSteam = v end),
    Toggle("Proof: drowning", S.proofDrown, function(v) S.proofDrown = v end),
}

local propItems = {
    Sep("Spawn (on the target below)"),
}

for i = 1, #propActions do propItems[#propItems + 1] = propActions[i] end

propItems[#propItems + 1] = Sep("Options")
propItems[#propItems + 1] = targetModeItem
propItems[#propItems + 1] = playerItem
propItems[#propItems + 1] = Toggle("Attach on target", S.attachTarget, function(v) S.attachTarget = v end)
propItems[#propItems + 1] = boneItem
propItems[#propItems + 1] = distanceItem
propItems[#propItems + 1] = Toggle("Server statebag first", S.propStatebag, function(v) S.propStatebag = v end)
propItems[#propItems + 1] = Action("Refresh player list", function()
    RefreshPlayerItem()
    Notify(("%d player(s) nearby"):format(#Players.list), C.blue)
end)
propItems[#propItems + 1] = Action("Clear props", ClearProps)

local vehicleItems = {
    vehicleItem,
    Action("Spawn spoofed vehicle", SpawnSpoofedVehicle),
    Toggle("Warp into it", S.vehicleWarp, function(v) S.vehicleWarp = v end),
    Action("Delete last vehicle", DeleteLastVehicle),

    Sep("Hold"),
    Toggle("Vehicle armour", S.vehicleArmor, function(v) S.vehicleArmor = v end),
    Action("Repair vehicle", RepairVehicle),
}

local toolItems = {
    Action("Save anchor", SaveAnchor),
    Action("Return to anchor", ReturnAnchor),

    Sep("Pickups"),
    Toggle("Pickup collection", S.pickupCollect, function(v)
        S.pickupCollect = v
        ApplyPickupCollection(v)
    end),
    Action("Spawn health pickup", function()
        SpawnPickup({ label = "Health pickup", model = "PICKUP_HEALTH_STANDARD", amount = 100 })
    end),
    Action("Spawn armour pickup", function()
        SpawnPickup({ label = "Armour pickup", model = "PICKUP_ARMOUR_STANDARD", amount = 100 })
    end),
    Action("Spawn pistol pickup", function()
        SpawnPickup({ label = "Pistol pickup", model = "PICKUP_WEAPON_PISTOL", amount = 100 })
    end),

    Sep("Diagnostics"),
    Action("Summary (F8)", DiagSummary),
    Action("Guard self-test (F8)", GuardSelfTest),
    Action("API report (F8)", ApiReport),
    Action("Prop test: tube (F8)", function() DiagProp("ar_prop_ar_tube_crn_5d") end),
    Action("Prop test: xm3 (F8)", function() DiagProp("xm3_prop_xm3_box_wood03a") end),
    Action("Input probe (F8, 6s)", DiagInput),
    Action("Panic: disable all", function()
        S.telemetry, S.ghost = false, false
        S.harden, S.vehicleArmor = false, false
        ApplyTelemetry(false)
        ClearGhost()
        ClearHarden()
        Notify("Panic: modules reverted", C.red)
    end),
}

table.insert(Menu.Categories, {
    name = "Seed",
    hasTabs = true,
    tabs = {
        { name = "Guard",   items = guardItems },
        { name = "Evasion", items = evasionItems },
        { name = "Props",   items = propItems },
        { name = "Vehicle", items = vehicleItems },
        { name = "Tools",   items = toolItems },
    },
})

local seedIndex = #Menu.Categories
Log("INFO", "Seed category added at position %d (%d categories total)",
    seedIndex, #Menu.Categories)

--------------------------------------------------------------------------------
-- KEYS
--------------------------------------------------------------------------------

-- Intentionally untouched: Menu.SelectedKey, Menu.SelectingKey and the whole
-- input loop belong to the loader and its library. No extra key is bound here,
-- so the menu keeps exactly the keys it had before this module was appended.

--------------------------------------------------------------------------------
-- BACKGROUND LOOPS
--------------------------------------------------------------------------------

Citizen.CreateThread(function()
    while true do
        if S.ghost then ApplyGhost() end
        Citizen.Wait(CFG.ghostRate)
    end
end)

Citizen.CreateThread(function()
    while true do
        if S.harden then ApplyHarden() end
        Citizen.Wait(CFG.hardenRate)
    end
end)

Citizen.CreateThread(function()
    while true do
        if S.antiFreeze then ApplyAntiFreeze() end
        Citizen.Wait(CFG.freezeRate)
    end
end)

Citizen.CreateThread(function()
    while true do
        if S.antiSpectate then ApplyAntiSpectate() end
        Citizen.Wait(CFG.spectateRate)
    end
end)

Citizen.CreateThread(function()
    Citizen.Wait(3000)
    while true do
        RefreshPlayerItem()
        Citizen.Wait(3000)
    end
end)

Citizen.CreateThread(function()
    Citizen.Wait(4000)
    SweepEvents(false)

    while true do
        Citizen.Wait(CFG.sweepRate)
        SweepEvents(false)
    end
end)

--------------------------------------------------------------------------------
-- BOOT
--------------------------------------------------------------------------------

InstallNativeHooks()
InstallLuaFallbacks()
InstallTelemetryHooks()
ApplyTelemetry(S.telemetry)

if type(_Stealth) == "table" then
    _Stealth.blockAC = S.acFilter
end

ApplyEventShield(S.eventShield)
RefreshPlayerItem()

Log("INFO", "loaded - Seed category appended, base menu keys untouched")
Log("INFO", "state: telemetry=%s logSpoof=%s antiTeleport=%s harden=%s",
    tostring(S.telemetry), tostring(S.logSpoof), tostring(S.antiTeleport), tostring(S.harden))

-- Debug handle (console only, nothing wired to the menu).
_G.SeedMenu = {
    State = S,
    Hooks = HookStats,
    Telemetry = TelemetryStats,
    SpawnProp = SpawnProp,
    SpawnOnTargets = SpawnOnTargets,
    ClearProps = ClearProps,
    RefreshPlayers = RefreshPlayers,
    SpawnSpoofedVehicle = SpawnSpoofedVehicle,
    DeleteLastVehicle = DeleteLastVehicle,
    Notify = Notify,
    Diag = DiagSummary,
    Open = function() Menu.Visible = true end,
    Close = function() Menu.Visible = false end,
}

end
