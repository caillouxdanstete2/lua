local Menu = {}
Menu.Visible = false
Menu.CurrentCategory = 2
Menu.CurrentPage = 1
Menu.ItemsPerPage = 8
Menu.scrollbarY = nil
Menu.scrollbarHeight = nil
Menu.scrollbarContext = nil
Menu.OpenedCategory = nil
Menu.CurrentItem = 1
Menu.CurrentTab = 1
Menu.ItemScrollOffset = 0
Menu.CategoryScrollOffset = 0
Menu.EditorDragging = false
Menu.EditorDragOffsetX = 0
Menu.EditorDragOffsetY = 0
Menu.EditorMode = false
Menu.ShowSnowflakes = false
Menu.SelectorY = 0
Menu.CategorySelectorY = 0
Menu.TabSelectorX = 0
Menu.TabSelectorWidth = 0
Menu.SmoothFactor = 0.2
Menu.GradientType = 1
Menu.ScrollbarPosition = 1

Menu.LoadingBarAlpha = 0.0
Menu.KeySelectorAlpha = 0.0
Menu.KeybindsInterfaceAlpha = 0.0

Menu.LoadingProgress = 0.0
Menu.IsLoading = true
Menu.LoadingComplete = false
Menu.LoadingStartTime = nil
Menu.LoadingDuration = 3000

Menu.SelectingKey = false
Menu.SelectedKey = nil
Menu.SelectedKeyName = nil

Menu.SelectingBind = false
Menu.BindingItem = nil
Menu.BindingKey = nil
Menu.BindingKeyName = nil

Menu.ShowKeybinds = false


Menu.CurrentTopTab = 1
function Menu.UpdateCategoriesFromTopTab()
    if not Menu.TopLevelTabs then return end
    local currentTop = Menu.TopLevelTabs[Menu.CurrentTopTab]
    if not currentTop then return end

    Menu.Categories = {}
    table.insert(Menu.Categories, { name = currentTop.name })
    for _, cat in ipairs(currentTop.categories) do
        table.insert(Menu.Categories, cat)
    end
    
    Menu.CurrentCategory = 2
    Menu.CategoryScrollOffset = 0
    Menu.OpenedCategory = nil
    
    if currentTop.autoOpen then
        Menu.OpenedCategory = 2
        Menu.CurrentTab = 1
        Menu.ItemScrollOffset = 0
        Menu.CurrentItem = 1
    end
end

Menu.Banner = {
    enabled = true,
    imageUrl = "https://i.imgur.com/3HLMxX5.png",
    height = 100
}

Menu.bannerTexture = nil
Menu.bannerWidth = 0
Menu.bannerHeight = 0

function Menu.LoadBannerTexture(url)
    if not url or url == "" then return end
    if not Susano or not Susano.HttpGet or not Susano.LoadTextureFromBuffer then return end

    if CreateThread then
        CreateThread(function()
            local success, result = pcall(function()
                local status, body = Susano.HttpGet(url)
                if status == 200 and body and #body > 0 then
                    local textureId, width, height = Susano.LoadTextureFromBuffer(body)
                    if textureId and textureId ~= 0 then
                        Menu.bannerTexture = textureId
                        Menu.bannerWidth = width
                        Menu.bannerHeight = height
                        return textureId
                    end
                end
                return nil
            end)
            if not success then
            end
        end)
    else
        local success, result = pcall(function()
            local status, body = Susano.HttpGet(url)
            if status == 200 and body and #body > 0 then
                local textureId, width, height = Susano.LoadTextureFromBuffer(body)
                if textureId and textureId ~= 0 then
                    Menu.bannerTexture = textureId
                    Menu.bannerWidth = width
                    Menu.bannerHeight = height
                    print("Banner texture loaded successfully")
                    return textureId
                end
            end
            return nil
        end)
        if not success then
        end
    end
end

Menu.Colors = {
    HeaderPink = { r = 104, g = 168, b = 203 },
    SelectedBg = { r = 104, g = 168, b = 203 },
    TextWhite = { r = 255, g = 255, b = 255 },
    BackgroundDark = { r = 0, g = 0, b = 0 },
    FooterBlack = { r = 0, g = 0, b = 0 }
}

function Menu.ApplyTheme(themeName)
    if themeName == "Blue" then
        Menu.Colors.HeaderPink = { r = 104, g = 168, b = 203 }
        Menu.Colors.SelectedBg = { r = 104, g = 168, b = 203 }
        Menu.Banner.imageUrl = "https://i.imgur.com/3HLMxX5.png"
    elseif themeName == "Green" then
        Menu.Colors.HeaderPink = { r = 76, g = 143, b = 88 }
        Menu.Colors.SelectedBg = { r = 76, g = 143, b = 88 }
        Menu.Banner.imageUrl = "https://i.imgur.com/3HLMxX5.png"
    elseif themeName == "Red" then
        Menu.Colors.HeaderPink = { r = 211, g = 64, b = 60 }
        Menu.Colors.SelectedBg = { r = 211, g = 64, b = 60 }
        Menu.Banner.imageUrl = "https://i.imgur.com/3HLMxX5.png"
    elseif themeName == "Purple" then
        Menu.Colors.HeaderPink = { r = 91, g = 55, b = 131 }
        Menu.Colors.SelectedBg = { r = 91, g = 55, b = 131 }
        Menu.Banner.imageUrl = "https://i.imgur.com/3HLMxX5.png"
    else
        Menu.Colors.HeaderPink = { r = 255, g = 20, b = 147 }
        Menu.Colors.SelectedBg = { r = 255, g = 20, b = 147 }
        Menu.Banner.imageUrl = "https://i.imgur.com/3HLMxX5.png"
    end

    if Menu.Banner.enabled and Menu.Banner.imageUrl then
        Menu.LoadBannerTexture(Menu.Banner.imageUrl)
    end
end

Menu.Position = {
    x = 50,
    y = 100,
    width = 360,
    itemHeight = 42,
    mainMenuHeight = 26,
    headerHeight = 100,
    footerHeight = 42,
    footerSpacing = 7,
    headerSpacing = 7,
    mainMenuSpacing = 5,
    footerRadius = 4,
    itemRadius = 4,
    scrollbarWidth = 12,
    scrollbarPadding = 5,
    headerRadius = 6
}
Menu.Scale = 1.0

function Menu.GetScaledPosition()
    local scale = Menu.Scale or 1.0
    return {
        x = Menu.Position.x,
        y = Menu.Position.y,
        width = Menu.Position.width * scale,
        itemHeight = Menu.Position.itemHeight * scale,
        mainMenuHeight = Menu.Position.mainMenuHeight * scale,
        headerHeight = Menu.Position.headerHeight * scale,
        footerHeight = Menu.Position.footerHeight * scale,
        footerSpacing = Menu.Position.footerSpacing * scale,
        headerSpacing = (Menu.Position.headerSpacing or 0) * scale,
        mainMenuSpacing = Menu.Position.mainMenuSpacing * scale,
        footerRadius = Menu.Position.footerRadius * scale,
        itemRadius = Menu.Position.itemRadius * scale,
        scrollbarWidth = Menu.Position.scrollbarWidth * scale,
        scrollbarPadding = Menu.Position.scrollbarPadding * scale,
        headerRadius = Menu.Position.headerRadius * scale
    }
end

function Menu.DrawRect(x, y, width, height, r, g, b, a)
    a = a or 1.0
    r = r or 1.0
    g = g or 1.0
    b = b or 1.0

    if r > 1.0 then r = r / 255.0 end
    if g > 1.0 then g = g / 255.0 end
    if b > 1.0 then b = b / 255.0 end
    if a > 1.0 then a = a / 255.0 end

    if Susano.DrawFilledRect then
        Susano.DrawFilledRect(x, y, width, height, r, g, b, a)
    elseif Susano.FillRect then
        Susano.FillRect(x, y, width, height, r, g, b, a)
    elseif Susano.DrawRect then
        for i = 0, height - 1 do
            Susano.DrawRect(x, y + i, width, 1, r, g, b, a)
        end
    end
end

function Menu.DrawText(x, y, text, size_px, r, g, b, a)
    local scale = Menu.Scale or 1.0
    size_px = (size_px or 16) * scale
    r = r or 1.0
    g = g or 1.0
    b = b or 1.0
    a = a or 1.0

    if r > 1.0 then r = r / 255.0 end
    if g > 1.0 then g = g / 255.0 end
    if b > 1.0 then b = b / 255.0 end
    if a > 1.0 then a = a / 255.0 end

    Susano.DrawText(x, y, text, size_px, r, g, b, a)
end

function Menu.DrawHeader()
    local scaledPos = Menu.GetScaledPosition()
    local scale = Menu.Scale or 1.0
    local x = scaledPos.x
    local y = scaledPos.y
    local width = scaledPos.width - 1
    local height = scaledPos.headerHeight
    local radius = scaledPos.headerRadius
    local bannerHeight = Menu.Banner.height * scale

    if Menu.Banner.enabled then
        if Menu.bannerTexture and Menu.bannerTexture > 0 and Susano and Susano.DrawImage then
            local bannerRadius = radius
            local framePad = 8
            if Susano and Susano.DrawRectFilled then
                Susano.DrawRectFilled(x, y, width, height, 0.216, 0.216, 0.216, 0.98, bannerRadius)
                Susano.DrawRectFilled(x + 1, y + 1, width - 2, height - 2, 0.059, 0.059, 0.059, 0.98, bannerRadius)
            else
                Menu.DrawTopRoundedRect(x, y, width, height, 55, 55, 55, 250, bannerRadius)
                Menu.DrawTopRoundedRect(x + 1, y + 1, width - 2, height - 2, 15, 15, 15, 250, bannerRadius)
            end
            local availW = width - (framePad * 2)
            local availH = height - (framePad * 2)
            local imgRounding = 6
            local imgW = Menu.bannerWidth or width
            local imgH = Menu.bannerHeight or bannerHeight
            local aspectRatio = imgW / imgH
            local drawW, drawH
            if (availW / availH) > aspectRatio then drawH = availH; drawW = availH * aspectRatio
            else drawW = availW; drawH = availW / aspectRatio end
            local drawX = x + framePad + (availW - drawW) / 2
            local drawY = y + framePad + (availH - drawH) / 2
            Susano.DrawImage(Menu.bannerTexture, drawX, drawY, drawW, drawH, 1, 1, 1, 1, imgRounding)
        else
            Menu.DrawRect(x, y, width, height, Menu.Colors.HeaderPink.r, Menu.Colors.HeaderPink.g, Menu.Colors.HeaderPink.b, 255)

            local logoX = x + width / 2 - 12
            local logoY = y + height / 2 - 20
            Menu.DrawText(logoX, logoY, "P", 44, 1.0, 1.0, 1.0, 1.0)
        end
    else
        Menu.DrawRect(x, y, width, height, Menu.Colors.HeaderPink.r, Menu.Colors.HeaderPink.g, Menu.Colors.HeaderPink.b, 255)

        local logoX = x + width / 2 - 12
        local logoY = y + height / 2 - 20
        Menu.DrawText(logoX, logoY, "P", 44, 1.0, 1.0, 1.0, 1.0)
    end
end

function Menu.DrawScrollbar(x, startY, visibleHeight, selectedIndex, totalItems, isMainMenu, menuWidth)
    if totalItems < 2 then return end

    local scaledPos = Menu.GetScaledPosition()
    local scale = Menu.Scale or 1.0
    local scrollbarWidth = scaledPos.scrollbarWidth
    local scrollbarPadding = scaledPos.scrollbarPadding
    local width = menuWidth or scaledPos.width
    local scrollbarX = x - scrollbarWidth - scrollbarPadding

    local barY = startY
    local barH = visibleHeight
    local arrowH = math.floor(16 * scale)
    local trackY = barY + arrowH + 1
    local trackH = barH - (arrowH * 2) - 2
    if trackH < 10 then return end

    local bgR = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.r) and (Menu.Colors.SelectedBg.r / 255.0) or 1.0
    local bgG = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.g) and (Menu.Colors.SelectedBg.g / 255.0) or 0.0
    local bgB = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.b) and (Menu.Colors.SelectedBg.b / 255.0) or 1.0
    local barRadius = scrollbarWidth / 2

    if Susano and Susano.DrawRectFilled then
        Susano.DrawRectFilled(scrollbarX, barY, scrollbarWidth, barH, 0.216, 0.216, 0.216, 0.85, barRadius)
        Susano.DrawRectFilled(scrollbarX + 1, barY + 1, scrollbarWidth - 2, barH - 2, 0.05, 0.05, 0.05, 0.92, barRadius)
    else
        Menu.DrawRoundedRect(scrollbarX, barY, scrollbarWidth, barH, 55, 55, 55, 217, barRadius)
        Menu.DrawRoundedRect(scrollbarX + 1, barY + 1, scrollbarWidth - 2, barH - 2, 13, 13, 13, 235, barRadius)
    end

    if Susano and Susano.DrawImage then
        local iconSz = scrollbarWidth
        local iconX = scrollbarX
        local arrowUpTex = Menu.IconTextures and Menu.IconTextures["_arrowUp"]
        if arrowUpTex and arrowUpTex > 0 then
            Susano.DrawImage(arrowUpTex, iconX, barY + math.floor((arrowH - iconSz) / 2), iconSz, iconSz, 1, 1, 1, 0.75, 0)
        end
        local arrowDownTex = Menu.IconTextures and Menu.IconTextures["_arrowDown"]
        if arrowDownTex and arrowDownTex > 0 then
            Susano.DrawImage(arrowDownTex, iconX, barY + barH - arrowH + math.floor((arrowH - iconSz) / 2), iconSz, iconSz, 1, 1, 1, 0.75, 0)
        end
    end

    local adjustedIndex = selectedIndex
    if isMainMenu then adjustedIndex = selectedIndex - 1 end
    local progress = math.max(0, math.min(1, (adjustedIndex - 1) / math.max(1, totalItems - 1)))

    local thumbHeight = math.max(trackH * 0.15, math.min(trackH * 0.25, math.floor(20 * scale)))
    local thumbY = math.max(trackY, math.min(trackY + trackH - thumbHeight, trackY + progress * (trackH - thumbHeight)))

    local ctx = isMainMenu and "cat" or ("items_" .. tostring(Menu.CurrentTab or 0))
    if Menu.scrollbarContext ~= ctx then
        Menu.scrollbarY = nil
        Menu.scrollbarHeight = nil
        Menu.scrollbarContext = ctx
    end
    if not Menu.scrollbarY then Menu.scrollbarY = thumbY end
    if not Menu.scrollbarHeight then Menu.scrollbarHeight = thumbHeight end

    Menu.scrollbarY = Menu.scrollbarY + (thumbY - Menu.scrollbarY) * 0.18
    Menu.scrollbarHeight = Menu.scrollbarHeight + (thumbHeight - Menu.scrollbarHeight) * 0.18

    local thumbPad = 2
    local thumbW = scrollbarWidth - (thumbPad * 2)
    local thumbRadius = thumbW / 2
    if Susano and Susano.DrawRectFilled then
        -- Bloom large visible
        Susano.DrawRectFilled(scrollbarX - 2, Menu.scrollbarY - 4,
            scrollbarWidth + 4, Menu.scrollbarHeight + 8,
            bgR * 0.5, bgG * 0.5, bgB * 0.5, 0.20,
            thumbRadius + 4)
        -- Glow moyen
        Susano.DrawRectFilled(scrollbarX + thumbPad - 2, Menu.scrollbarY - 2,
            thumbW + 4, Menu.scrollbarHeight + 4,
            bgR * 0.6, bgG * 0.6, bgB * 0.6, 0.35,
            thumbRadius + 2)
        -- Thumb
        Susano.DrawRectFilled(scrollbarX + thumbPad, Menu.scrollbarY,
            thumbW, Menu.scrollbarHeight,
            bgR, bgG, bgB, 1.0, thumbRadius)
    else
        Menu.DrawRoundedRect(scrollbarX + thumbPad, Menu.scrollbarY,
            thumbW, Menu.scrollbarHeight,
            math.floor(bgR * 255), math.floor(bgG * 255), math.floor(bgB * 255), 255, thumbRadius)
    end
end
function Menu.DrawTabs(category, x, startY, width, tabHeight)
    local scale = Menu.Scale or 1.0
    if not category or not category.hasTabs or not category.tabs then
        return
    end

    local numTabs = #category.tabs
    local tabWidth = width / numTabs
    local currentX = x

    for i, tab in ipairs(category.tabs) do
        local tabX = currentX
        local currentTabWidth
        if i == numTabs then
            currentTabWidth = (x + width) - currentX
        else
            currentTabWidth = tabWidth + (0.5 * scale)
        end

        local isSelected = (i == Menu.CurrentTab)

        if isSelected then
            local targetWidth = currentTabWidth
            if i == numTabs then
                targetWidth = math.min(currentTabWidth, (x + width) - tabX - (1 * scale))
            end

            if Menu.TabSelectorX == 0 then
                Menu.TabSelectorX = tabX
                Menu.TabSelectorWidth = targetWidth
            end

            local smoothSpeed = Menu.SmoothFactor
            Menu.TabSelectorX = Menu.TabSelectorX + (tabX - Menu.TabSelectorX) * smoothSpeed
            Menu.TabSelectorWidth = Menu.TabSelectorWidth + (targetWidth - Menu.TabSelectorWidth) * smoothSpeed

            if math.abs(Menu.TabSelectorX - tabX) < (0.5 * scale) then Menu.TabSelectorX = tabX end
            if math.abs(Menu.TabSelectorWidth - targetWidth) < (0.5 * scale) then Menu.TabSelectorWidth = targetWidth end

            local drawX = Menu.TabSelectorX
            local drawWidth = Menu.TabSelectorWidth

            local baseR = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.r) and (Menu.Colors.SelectedBg.r / 255.0) or 1.0
            local baseG = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.g) and (Menu.Colors.SelectedBg.g / 255.0) or 0.0
            local baseB = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.b) and (Menu.Colors.SelectedBg.b / 255.0) or 1.0
            local darkenAmount = 0.4

            local gradientSteps = 20
            local stepHeight = tabHeight / gradientSteps
            local selectorWidth = drawWidth
            local selectorX = drawX

            for step = 0, gradientSteps - 1 do
                local stepY = startY + (step * stepHeight)
                local actualStepHeight = stepHeight
                local maxY = startY + tabHeight
                if stepY + actualStepHeight > maxY then
                    actualStepHeight = maxY - stepY
                end
                if actualStepHeight > 0 and stepY < maxY then
                    local stepGradientFactor = step / (gradientSteps - 1)
                    local stepDarken = (1 - stepGradientFactor) * darkenAmount

                    local stepR = math.max(0, baseR - stepDarken)
                    local stepG = math.max(0, baseG - stepDarken)
                    local stepB = math.max(0, baseB - stepDarken)

                    if Susano and Susano.DrawRectFilled then
                        Susano.DrawRectFilled(selectorX, stepY, selectorWidth, actualStepHeight, stepR, stepG, stepB, 0.9, 0.0)
                    else
                        Menu.DrawRect(selectorX, stepY, selectorWidth, actualStepHeight, stepR * 255, stepG * 255, stepB * 255, 220)
                    end
                end
            end

            Menu.DrawRect(selectorX, startY, (3 * scale), tabHeight, Menu.Colors.SelectedBg.r, Menu.Colors.SelectedBg.g, Menu.Colors.SelectedBg.b, 255)
        end

        Menu.DrawRect(tabX, startY, currentTabWidth, tabHeight, Menu.Colors.BackgroundDark.r, Menu.Colors.BackgroundDark.g, Menu.Colors.BackgroundDark.b, isSelected and 0 or 50)

        local textSize = 17
        local scaledTextSize = textSize * scale
        local textY = startY + tabHeight / 2 - (scaledTextSize / 2) + (1 * scale)
        local textWidth = 0
        if Susano and Susano.GetTextWidth then
            textWidth = Susano.GetTextWidth(tab.name, scaledTextSize)
        else
            textWidth = string.len(tab.name) * 9 * scale
        end
        local textX = tabX + (currentTabWidth / 2) - (textWidth / 2)
        Menu.DrawText(textX, textY, tab.name, textSize, Menu.Colors.TextWhite.r / 255.0, Menu.Colors.TextWhite.g / 255.0, Menu.Colors.TextWhite.b / 255.0, 1.0)

        currentX = currentX + tabWidth
    end
end

local function findNextNonSeparator(items, startIndex, direction)
    local index = startIndex
    local attempts = 0
    local maxAttempts = #items

    while attempts < maxAttempts do
        index = index + direction
        if index < 1 then
            index = #items
        elseif index > #items then
            index = 1
        end

        if items[index] and not items[index].isSeparator then
            return index
        end

        attempts = attempts + 1
    end

    return startIndex
end

function Menu.DrawItem(x, itemY, width, itemHeight, item, isSelected)
    if item.isSeparator then
        if item.separatorText then
            local textY = itemY + itemHeight / 2 - 7
            local textSize = 14

            local textWidth = 0
            if Susano and Susano.GetTextWidth then
                textWidth = Susano.GetTextWidth(item.separatorText, textSize)
            else
                textWidth = string.len(item.separatorText) * 8
            end

            local textX = x + (width / 2) - (textWidth / 2)

            Menu.DrawText(textX, textY, item.separatorText, textSize, Menu.Colors.TextWhite.r / 255.0, Menu.Colors.TextWhite.g / 255.0, Menu.Colors.TextWhite.b / 255.0, 1.0)

            local barY = itemY + (itemHeight / 2)
            local barSpacing = 8
            local barMaxLength = 80
            local barHeight = 1
            local barRadius = 0.5

            local leftBarX = textX - barSpacing - barMaxLength
            local leftBarWidth = math.min(barMaxLength, textX - leftBarX - barSpacing)
            if leftBarWidth > 0 and leftBarX >= x + 15 then
                if Susano and Susano.DrawRectFilled then
                    Susano.DrawRectFilled(leftBarX, math.floor(barY), leftBarWidth, barHeight,
                        Menu.Colors.TextWhite.r / 255.0, Menu.Colors.TextWhite.g / 255.0, Menu.Colors.TextWhite.b / 255.0, 100 / 255.0,
                        barRadius)
                else
                    Menu.DrawRect(leftBarX, math.floor(barY), leftBarWidth, barHeight, Menu.Colors.TextWhite.r, Menu.Colors.TextWhite.g, Menu.Colors.TextWhite.b, 100)
                end
            end

            local rightBarX = textX + textWidth + barSpacing
            local rightBarWidth = math.min(barMaxLength, (x + width - 15) - rightBarX)
            if rightBarWidth > 0 and rightBarX + rightBarWidth <= x + width - 15 then
                if Susano and Susano.DrawRectFilled then
                    Susano.DrawRectFilled(rightBarX, math.floor(barY), rightBarWidth, barHeight,
                        Menu.Colors.TextWhite.r / 255.0, Menu.Colors.TextWhite.g / 255.0, Menu.Colors.TextWhite.b / 255.0, 100 / 255.0,
                        barRadius)
                else
                    Menu.DrawRect(rightBarX, math.floor(barY), rightBarWidth, barHeight, Menu.Colors.TextWhite.r, Menu.Colors.TextWhite.g, Menu.Colors.TextWhite.b, 100)
                end
            end
        end
        return
    end

    if isSelected then
        if Menu.SelectorY == 0 then
            Menu.SelectorY = itemY
        end

        local smoothSpeed = Menu.SmoothFactor
        Menu.SelectorY = Menu.SelectorY + (itemY - Menu.SelectorY) * smoothSpeed
        if math.abs(Menu.SelectorY - itemY) < 0.5 then
            Menu.SelectorY = itemY
        end
        
        local drawY = Menu.SelectorY

        local baseR = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.r) and (Menu.Colors.SelectedBg.r / 255.0) or 1.0
        local baseG = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.g) and (Menu.Colors.SelectedBg.g / 255.0) or 0.0
        local baseB = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.b) and (Menu.Colors.SelectedBg.b / 255.0) or 1.0

        -- Barre de selection Korium avec bloom lumineux
        local floatPad = 6
        local selX = x + floatPad
        local selW = width - (floatPad * 2)
        local selH = itemHeight - 15
        local selY = drawY + math.floor((itemHeight - selH) / 2)
        local selRadius = 4
        if Susano and Susano.DrawRectFilled then
            Susano.DrawRectFilled(selX - 10, selY - 6, selW + 20, selH + 12, baseR, baseG, baseB, 0.07, selRadius + 8)
            Susano.DrawRectFilled(selX - 5, selY - 3, selW + 10, selH + 6, baseR, baseG, baseB, 0.15, selRadius + 4)
            Susano.DrawRectFilled(selX - 2, selY - 2, selW + 4, selH + 4, baseR, baseG, baseB, 0.22, selRadius + 1)
            Susano.DrawRectFilled(selX, selY, selW, selH, 0.216, 0.216, 0.216, 0.98, selRadius)
            Susano.DrawRectFilled(selX + 1, selY + 1, selW - 2, selH - 2, baseR, baseG, baseB, 0.85, selRadius)
            Susano.DrawRectFilled(selX + 1, selY + 1, (selW - 2) * 0.5, selH - 2, baseR, baseG, baseB, 0.10, selRadius)
        else
            Menu.DrawRoundedRect(selX, selY, selW, selH, 55, 55, 55, 250, selRadius)
            Menu.DrawRoundedRect(selX + 1, selY + 1, selW - 2, selH - 2, math.floor(baseR * 255), math.floor(baseG * 255), math.floor(baseB * 255), 217, selRadius)
        end
    end

    local textX = x + 16
    local textY = itemY + itemHeight / 2 - 8
    Menu.DrawText(textX, textY, item.name, 19, Menu.Colors.TextWhite.r / 255.0, Menu.Colors.TextWhite.g / 255.0, Menu.Colors.TextWhite.b / 255.0, 1.0)

    if item.type == "toggle" then
        local toggleWidth = 36
        local toggleHeight = 16
        local toggleX = x + width - toggleWidth - 16
        local toggleY = itemY + (itemHeight / 2) - (toggleHeight / 2)
        local toggleRadius = toggleHeight / 2

        if item.value then
            local tR = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.r) and (Menu.Colors.SelectedBg.r / 255.0) or 1.0
            local tG = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.g) and (Menu.Colors.SelectedBg.g / 255.0) or 0.0
            local tB = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.b) and (Menu.Colors.SelectedBg.b / 255.0) or 1.0

            if Susano and Susano.DrawRectFilled then
                Susano.DrawRectFilled(toggleX, toggleY, toggleWidth, toggleHeight,
                    tR, tG, tB, 0.95,
                    toggleRadius)
            else
                Menu.DrawRoundedRect(toggleX, toggleY, toggleWidth, toggleHeight,
                    tR * 255, tG * 255, tB * 255, 242,
                    toggleRadius)
            end
        else
            if Susano and Susano.DrawRectFilled then
                Susano.DrawRectFilled(toggleX, toggleY, toggleWidth, toggleHeight,
                    0.2, 0.2, 0.2, 0.95,
                    toggleRadius)
            else
                Menu.DrawRoundedRect(toggleX, toggleY, toggleWidth, toggleHeight,
                    51, 51, 51, 242,
                    toggleRadius)
            end
        end

        local circleSize = toggleHeight - 4
        local circleY = toggleY + 2
        local circleX
        if item.value then
            circleX = toggleX + toggleWidth - circleSize - 2
        else
            circleX = toggleX + 2
        end

        if Susano and Susano.DrawRectFilled then
            Susano.DrawRectFilled(circleX, circleY, circleSize, circleSize,
                0.0, 0.0, 0.0, 1.0,
                circleSize / 2)
        else
            Menu.DrawRoundedRect(circleX, circleY, circleSize, circleSize,
                0, 0, 0, 255,
                circleSize / 2)
        end

        if item.hasSlider then
            local sliderWidth = 85
            local sliderHeight = 6
            local sliderX = x + width - sliderWidth - 95
            local sliderY = itemY + (itemHeight / 2) - (sliderHeight / 2)

            local currentValue = item.sliderValue or item.sliderMin or 0.0
            local minValue = item.sliderMin or 0.0
            local maxValue = item.sliderMax or 100.0

            local percent = (currentValue - minValue) / (maxValue - minValue)
            percent = math.max(0.0, math.min(1.0, percent))

            if Susano and Susano.DrawRectFilled then
                Susano.DrawRectFilled(sliderX, sliderY, sliderWidth, sliderHeight,
                    0.12, 0.12, 0.12, 0.7, 3.0)
            else
                Menu.DrawRoundedRect(sliderX, sliderY, sliderWidth, sliderHeight,
                    31, 31, 31, 180, 3.0)
            end

            if percent > 0 then
                if Susano and Susano.DrawRectFilled then
                    local accentR = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.r) and (Menu.Colors.SelectedBg.r / 255.0 * 1.3) or 1.0
                    local accentG = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.g) and (Menu.Colors.SelectedBg.g / 255.0 * 1.3) or 0.0
                    local accentB = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.b) and (Menu.Colors.SelectedBg.b / 255.0 * 1.3) or 1.0
                    accentR = math.min(1.0, accentR)
                    accentG = math.min(1.0, accentG)
                    accentB = math.min(1.0, accentB)
                    Susano.DrawRectFilled(sliderX, sliderY, sliderWidth * percent, sliderHeight,
                        accentR, accentG, accentB, 1.0, 3.0)
                else
                    local accentR = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.r) and math.min(255, Menu.Colors.SelectedBg.r * 1.3) or 255
                    local accentG = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.g) and math.min(255, Menu.Colors.SelectedBg.g * 1.3) or 0
                    local accentB = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.b) and math.min(255, Menu.Colors.SelectedBg.b * 1.3) or 255
                    Menu.DrawRoundedRect(sliderX, sliderY, sliderWidth * percent, sliderHeight,
                        accentR, accentG, accentB, 255, 3.0)
                end
            end

            local thumbSize = 10
            local thumbX = sliderX + (sliderWidth * percent) - (thumbSize / 2)
            local thumbY = itemY + (itemHeight / 2) - (thumbSize / 2)

            if Susano and Susano.DrawRectFilled then
                Susano.DrawRectFilled(thumbX, thumbY, thumbSize, thumbSize,
                    1.0, 1.0, 1.0, 1.0, 5.0)
            else
                Menu.DrawRoundedRect(thumbX, thumbY, thumbSize, thumbSize,
                    255, 255, 255, 255, 5.0)
            end

            local valueText
            if item.name == "Freecam" then
                valueText = string.format("%.1f", currentValue)
            else
                valueText = string.format("%.1f", currentValue)
            end
            local valuePadding = 10
            local valueX = sliderX + sliderWidth + valuePadding
            local valueY = sliderY + (sliderHeight / 2) - 6
            Menu.DrawText(valueX, valueY, valueText, 10, Menu.Colors.TextWhite.r / 255.0, Menu.Colors.TextWhite.g / 255.0, Menu.Colors.TextWhite.b / 255.0, 0.8)
        end
    elseif item.type == "toggle_selector" then
        local toggleWidth = 32
        local toggleHeight = 14
        local toggleX = x + width - toggleWidth - 15
        local toggleY = itemY + (itemHeight / 2) - (toggleHeight / 2)
        local toggleRadius = toggleHeight / 2

        if item.value then
            local tR = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.r) and (Menu.Colors.SelectedBg.r / 255.0) or 1.0
            local tG = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.g) and (Menu.Colors.SelectedBg.g / 255.0) or 0.0
            local tB = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.b) and (Menu.Colors.SelectedBg.b / 255.0) or 1.0

            if Susano and Susano.DrawRectFilled then
                Susano.DrawRectFilled(toggleX, toggleY, toggleWidth, toggleHeight, tR, tG, tB, 0.95, toggleRadius)
            else
                Menu.DrawRoundedRect(toggleX, toggleY, toggleWidth, toggleHeight, tR * 255, tG * 255, tB * 255, 242, toggleRadius)
            end
        else
            if Susano and Susano.DrawRectFilled then
                Susano.DrawRectFilled(toggleX, toggleY, toggleWidth, toggleHeight, 0.2, 0.2, 0.2, 0.95, toggleRadius)
            else
                Menu.DrawRoundedRect(toggleX, toggleY, toggleWidth, toggleHeight, 51, 51, 51, 242, toggleRadius)
            end
        end

        local circleSize = toggleHeight - 4
        local circleY = toggleY + 2
        local circleX
        if item.value then
            circleX = toggleX + toggleWidth - circleSize - 2
        else
            circleX = toggleX + 2
        end

        if Susano and Susano.DrawRectFilled then
            Susano.DrawRectFilled(circleX, circleY, circleSize, circleSize, 0.0, 0.0, 0.0, 1.0, circleSize / 2)
        else
            Menu.DrawRoundedRect(circleX, circleY, circleSize, circleSize, 0, 0, 0, 255, circleSize / 2)
        end

        if item.options then
            local selectedIndex = item.selected or 1
            local selectedOption = item.options[selectedIndex] or ""
            local selectorSize = 16
            local textY = itemY + itemHeight / 2 - 7

            local fullText = "< " .. selectedOption .. " >"
            local selectorWidth = 0
            if Susano and Susano.GetTextWidth then
                selectorWidth = Susano.GetTextWidth(fullText, selectorSize)
            else
                selectorWidth = string.len(fullText) * 9
            end

            local selectorX = toggleX - selectorWidth - 15

            Menu.DrawText(selectorX, textY, "<", selectorSize,
                Menu.Colors.TextWhite.r / 255.0 * 0.8, Menu.Colors.TextWhite.g / 255.0 * 0.8, Menu.Colors.TextWhite.b / 255.0 * 0.8, 0.8)

            local leftArrowWidth = 0
            if Susano and Susano.GetTextWidth then
                leftArrowWidth = Susano.GetTextWidth("< ", selectorSize)
            else
                leftArrowWidth = 18
            end
            Menu.DrawText(selectorX + leftArrowWidth, textY, selectedOption, selectorSize, 1.0, 1.0, 1.0, 1.0)

            local optionWidth = 0
            if Susano and Susano.GetTextWidth then
                optionWidth = Susano.GetTextWidth(selectedOption, selectorSize)
            else
                optionWidth = string.len(selectedOption) * 9
            end
            Menu.DrawText(selectorX + leftArrowWidth + optionWidth + 5, textY, ">", selectorSize,
                Menu.Colors.TextWhite.r / 255.0 * 0.8, Menu.Colors.TextWhite.g / 255.0 * 0.8, Menu.Colors.TextWhite.b / 255.0 * 0.8, 0.8)
        end
    elseif item.type == "slider" then
        local sliderWidth = 100
        local sliderHeight = 7
        local sliderX = x + width - sliderWidth - 60
        local sliderY = itemY + (itemHeight / 2) - (sliderHeight / 2)

        local currentValue = item.value or item.min or 0.0
        local minValue = item.min or 0.0
        local maxValue = item.max or 100.0

        local percent = (currentValue - minValue) / (maxValue - minValue)
        percent = math.max(0.0, math.min(1.0, percent))

        if Susano and Susano.DrawRectFilled then
            Susano.DrawRectFilled(sliderX, sliderY, sliderWidth, sliderHeight,
                0.12, 0.12, 0.12, 0.7, 3.0)
        else
            Menu.DrawRoundedRect(sliderX, sliderY, sliderWidth, sliderHeight,
                31, 31, 31, 180, 3.0)
        end

        if percent > 0 then
            if Susano and Susano.DrawRectFilled then
                local accentR = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.r) and (Menu.Colors.SelectedBg.r / 255.0 * 1.3) or 1.0
                local accentG = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.g) and (Menu.Colors.SelectedBg.g / 255.0 * 1.3) or 0.0
                local accentB = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.b) and (Menu.Colors.SelectedBg.b / 255.0 * 1.3) or 1.0
                accentR = math.min(1.0, accentR)
                accentG = math.min(1.0, accentG)
                accentB = math.min(1.0, accentB)
                Susano.DrawRectFilled(sliderX, sliderY, sliderWidth * percent, sliderHeight,
                    accentR, accentG, accentB, 1.0, 3.0)
            else
                local accentR = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.r) and math.min(255, Menu.Colors.SelectedBg.r * 1.3) or 255
                local accentG = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.g) and math.min(255, Menu.Colors.SelectedBg.g * 1.3) or 0
                local accentB = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.b) and math.min(255, Menu.Colors.SelectedBg.b * 1.3) or 255
                Menu.DrawRoundedRect(sliderX, sliderY, sliderWidth * percent, sliderHeight,
                    accentR, accentG, accentB, 255, 3.0)
            end
        end

        local thumbSize = 11
        local thumbX = sliderX + (sliderWidth * percent) - (thumbSize / 2)
        local thumbY = itemY + (itemHeight / 2) - (thumbSize / 2)

        if Susano and Susano.DrawRectFilled then
                Susano.DrawRectFilled(thumbX, thumbY, thumbSize, thumbSize,
                    1.0, 1.0, 1.0, 1.0, 5.0)
            else
                Menu.DrawRoundedRect(thumbX, thumbY, thumbSize, thumbSize,
                    255, 255, 255, 255, 5.0)
            end

        local valueText = string.format("%.0f", currentValue)
        local valuePadding = 10
        local valueX = sliderX + sliderWidth + valuePadding
        local valueY = sliderY + (sliderHeight / 2) - 6
        Menu.DrawText(valueX, valueY, valueText, 11, Menu.Colors.TextWhite.r / 255.0, Menu.Colors.TextWhite.g / 255.0, Menu.Colors.TextWhite.b / 255.0, 0.8)
    elseif item.type == "selector" and item.options then
        local selectedIndex = item.selected or 1
        local selectedOption = item.options[selectedIndex] or ""
        local selectorSize = 17

        local isWardrobeSelector = false
        local wardrobeItemNames = {"Hat", "Mask", "Glasses", "Torso", "Tshirt", "Pants", "Shoes"}
        for _, name in ipairs(wardrobeItemNames) do
            if item.name == name then
                isWardrobeSelector = true
                break
            end
        end

        if isWardrobeSelector then
            local displayValue = selectedIndex
            local selectorText = "- " .. tostring(displayValue) .. " -"
            local selectorWidth = 0
            if Susano and Susano.GetTextWidth then
                selectorWidth = Susano.GetTextWidth(selectorText, selectorSize)
            else
                selectorWidth = string.len(selectorText) * 9
            end
            local selectorX = x + width - selectorWidth - 16
            Menu.DrawText(selectorX, textY, selectorText, selectorSize,
                1.0, 1.0, 1.0, 1.0)
        else
            local fullText = "< " .. selectedOption .. " >"
            local selectorWidth = 0
            if Susano and Susano.GetTextWidth then
                selectorWidth = Susano.GetTextWidth(fullText, selectorSize)
            else
                selectorWidth = string.len(fullText) * 9
            end

            local selectorX = x + width - selectorWidth - 16

            Menu.DrawText(selectorX, textY, "<", selectorSize,
                Menu.Colors.TextWhite.r / 255.0 * 0.8, Menu.Colors.TextWhite.g / 255.0 * 0.8, Menu.Colors.TextWhite.b / 255.0 * 0.8, 0.8)

            local leftArrowWidth = 0
            if Susano and Susano.GetTextWidth then
                leftArrowWidth = Susano.GetTextWidth("< ", selectorSize)
            else
                leftArrowWidth = 18
            end
            Menu.DrawText(selectorX + leftArrowWidth, textY, selectedOption, selectorSize,
                1.0, 1.0, 1.0, 1.0)

            local optionWidth = 0
            if Susano and Susano.GetTextWidth then
                optionWidth = Susano.GetTextWidth(selectedOption, selectorSize)
            else
                optionWidth = string.len(selectedOption) * 9
            end
            Menu.DrawText(selectorX + leftArrowWidth + optionWidth + 5, textY, ">", selectorSize,
                Menu.Colors.TextWhite.r / 255.0 * 0.8, Menu.Colors.TextWhite.g / 255.0 * 0.8, Menu.Colors.TextWhite.b / 255.0 * 0.8, 0.8)
        end
    end
end

function Menu.DrawCategories()
    if Menu.OpenedCategory then
        local category = Menu.Categories[Menu.OpenedCategory]
        if not category or not category.hasTabs or not category.tabs then
            Menu.OpenedCategory = nil
            return
        end

        local scaledPos = Menu.GetScaledPosition()
        local x = scaledPos.x
        local headerSp = scaledPos.headerSpacing or 0
        local startY = scaledPos.y + scaledPos.headerHeight + headerSp
        local width = scaledPos.width
        local itemHeight = scaledPos.itemHeight
        local mainMenuHeight = scaledPos.mainMenuHeight
        local mainMenuSpacing = scaledPos.mainMenuSpacing

        Menu.DrawTabs(category, x, startY, width, mainMenuHeight)

        local currentTab = category.tabs[Menu.CurrentTab]
        if currentTab and currentTab.items then
            local itemY = startY + mainMenuHeight + mainMenuSpacing
            local totalItems = #currentTab.items
            local maxVisible = Menu.ItemsPerPage

            local nonSeparatorCount = 0
            for _, item in ipairs(currentTab.items) do
                if not item.isSeparator then
                    nonSeparatorCount = nonSeparatorCount + 1
                end
            end

            if Menu.CurrentItem > Menu.ItemScrollOffset + maxVisible then
                Menu.ItemScrollOffset = Menu.CurrentItem - maxVisible
            elseif Menu.CurrentItem <= Menu.ItemScrollOffset then
                Menu.ItemScrollOffset = math.max(0, Menu.CurrentItem - 1)
            end

            local visibleHeight = math.min(maxVisible, totalItems) * itemHeight
            for i = 1, math.min(maxVisible, totalItems) do
                local itemIndex = i + Menu.ItemScrollOffset
                if itemIndex <= totalItems then
                    local item = currentTab.items[itemIndex]
                    local itemYPos = itemY + (i - 1) * itemHeight
                    local isSelected = (itemIndex == Menu.CurrentItem)
                    Menu.DrawItem(x, itemYPos, width, itemHeight, item, isSelected)
                end
            end

            if totalItems > 0 then
                Menu.DrawScrollbar(x, itemY, visibleHeight, Menu.CurrentItem, totalItems, false, width)
            end
        end
        return
    end

    local scaledPos = Menu.GetScaledPosition()
    local x = scaledPos.x
    local headerSp = scaledPos.headerSpacing or 0
    local startY = scaledPos.y + scaledPos.headerHeight + headerSp
    local width = scaledPos.width
    local itemHeight = scaledPos.itemHeight
    local mainMenuHeight = scaledPos.mainMenuHeight
    local mainMenuSpacing = scaledPos.mainMenuSpacing

    local totalCategories = #Menu.Categories - 1
    local maxVisible = Menu.ItemsPerPage

    if Menu.CurrentCategory > Menu.CategoryScrollOffset + maxVisible + 1 then
        Menu.CategoryScrollOffset = Menu.CurrentCategory - maxVisible - 1
    elseif Menu.CurrentCategory <= Menu.CategoryScrollOffset + 1 then
        Menu.CategoryScrollOffset = math.max(0, Menu.CurrentCategory - 2)
    end

    -- Bandeau Main Menu supprime - les categories commencent directement apres le header

    local visibleHeight = math.min(maxVisible, totalCategories) * itemHeight
    for displayIndex = 1, math.min(maxVisible, totalCategories) do
        local categoryIndex = displayIndex + Menu.CategoryScrollOffset + 1
        if categoryIndex <= #Menu.Categories then
            local category = Menu.Categories[categoryIndex]
            local isSelected = (categoryIndex == Menu.CurrentCategory)

            local itemY = startY + (displayIndex - 1) * itemHeight

            if isSelected then
                if Menu.CategorySelectorY == 0 then
                    Menu.CategorySelectorY = itemY
                end

                local smoothSpeed = Menu.SmoothFactor
                Menu.CategorySelectorY = Menu.CategorySelectorY + (itemY - Menu.CategorySelectorY) * smoothSpeed
                if math.abs(Menu.CategorySelectorY - itemY) < 0.5 then
                    Menu.CategorySelectorY = itemY
                end

                local drawY = Menu.CategorySelectorY

                local baseR = Menu.Colors.SelectedBg.r / 255.0
                local baseG = Menu.Colors.SelectedBg.g / 255.0
                local baseB = Menu.Colors.SelectedBg.b / 255.0

                -- Barre de selection Korium avec bloom lumineux
                local floatPad = 6
                local selX = x + floatPad
                local selW = width - (floatPad * 2)
                local selH = itemHeight - 15
                local selY = drawY + math.floor((itemHeight - selH) / 2)
                local selRadius = 4
                if Susano and Susano.DrawRectFilled then
                    Susano.DrawRectFilled(selX - 10, selY - 6, selW + 20, selH + 12, baseR, baseG, baseB, 0.07, selRadius + 8)
                    Susano.DrawRectFilled(selX - 5, selY - 3, selW + 10, selH + 6, baseR, baseG, baseB, 0.15, selRadius + 4)
                    Susano.DrawRectFilled(selX - 2, selY - 2, selW + 4, selH + 4, baseR, baseG, baseB, 0.22, selRadius + 1)
                    Susano.DrawRectFilled(selX, selY, selW, selH, 0.216, 0.216, 0.216, 0.98, selRadius)
                    Susano.DrawRectFilled(selX + 1, selY + 1, selW - 2, selH - 2, baseR, baseG, baseB, 0.85, selRadius)
                    Susano.DrawRectFilled(selX + 1, selY + 1, (selW - 2) * 0.5, selH - 2, baseR, baseG, baseB, 0.10, selRadius)
                else
                    Menu.DrawRoundedRect(selX, selY, selW, selH, 55, 55, 55, 250, selRadius)
                    Menu.DrawRoundedRect(selX + 1, selY + 1, selW - 2, selH - 2, math.floor(baseR * 255), math.floor(baseG * 255), math.floor(baseB * 255), 217, selRadius)
                end
            end

            local textX = x + 16
            local textY = itemY + itemHeight / 2 - 8
            Menu.DrawText(textX, textY, category.name, 19, Menu.Colors.TextWhite.r / 255.0, Menu.Colors.TextWhite.g / 255.0, Menu.Colors.TextWhite.b / 255.0, 1.0)

            local _chevSz = math.floor(20 * (Menu.Scale or 1.0))
            local _chevX = x + width - _chevSz - 16
            local _chevY = itemY + math.floor((itemHeight - _chevSz) / 2)
            local _chevTex = Menu.IconTextures and Menu.IconTextures["_chevron"]
            if _chevTex and _chevTex > 0 and Susano and Susano.DrawImage then
                local _cR = Menu.Colors.SelectedBg.r / 255.0
                local _cG = Menu.Colors.SelectedBg.g / 255.0
                local _cB = Menu.Colors.SelectedBg.b / 255.0
                Susano.DrawImage(_chevTex, _chevX - 3, _chevY - 3, _chevSz + 6, _chevSz + 6, _cR, _cG, _cB, 0.10, 0)
                Susano.DrawImage(_chevTex, _chevX, _chevY, _chevSz, _chevSz, 1, 1, 1, 0.55, 0)
            else
                Menu.DrawText(x + width - 30, textY, ">", 19, Menu.Colors.TextWhite.r / 255.0, Menu.Colors.TextWhite.g / 255.0, Menu.Colors.TextWhite.b / 255.0, 0.55)
            end
        end
    end

    if totalCategories > 0 then
        local scrollbarStartY = startY
        Menu.DrawScrollbar(x, scrollbarStartY, visibleHeight, Menu.CurrentCategory, totalCategories, true, width)
    end
end

function Menu.DrawTopRoundedRect(x, y, width, height, r, g, b, a, radius)
    Menu.DrawRect(x, y + radius, width, height - radius, r, g, b, a)
    Menu.DrawRect(x + radius, y, width - 2 * radius, radius, r, g, b, a)

    for i = 0, radius - 1 do
        local slice_width = math.ceil(math.sqrt(radius * radius - i * i))
        local y_pos = y + radius - 1 - i

        Menu.DrawRect(x + radius - slice_width, y_pos, slice_width, 1, r, g, b, a)

        Menu.DrawRect(x + width - radius, y_pos, slice_width, 1, r, g, b, a)
    end
end

function Menu.DrawRoundedRect(x, y, width, height, r, g, b, a, radius)
    radius = radius or 0
    if radius <= 0 then
        Menu.DrawRect(x, y, width, height, r, g, b, a)
        return
    end
    
    Menu.DrawRect(x + radius, y, width - 2 * radius, height, r, g, b, a)
    Menu.DrawRect(x, y + radius, radius, height - 2 * radius, r, g, b, a)
    Menu.DrawRect(x + width - radius, y + radius, radius, height - 2 * radius, r, g, b, a)
    
    for i = 0, radius - 1 do
        local slice_width = math.ceil(math.sqrt(radius * radius - i * i))
        
        local top_y = y + radius - 1 - i
        Menu.DrawRect(x + radius - slice_width, top_y, slice_width, 1, r, g, b, a)
        Menu.DrawRect(x + width - radius, top_y, slice_width, 1, r, g, b, a)
        
        local bottom_y = y + height - radius + i
        Menu.DrawRect(x + radius - slice_width, bottom_y, slice_width, 1, r, g, b, a)
        Menu.DrawRect(x + width - radius, bottom_y, slice_width, 1, r, g, b, a)
    end
end

function Menu.DrawLoadingBar(alpha)
    if alpha <= 0 then return end
    
    local screenWidth = 1920
    local screenHeight = 1080
    if Susano and Susano.GetScreenWidth and Susano.GetScreenHeight then
        screenWidth = Susano.GetScreenWidth()
        screenHeight = Susano.GetScreenHeight()
    end

    local centerX = screenWidth / 2
    local centerY = screenHeight - 150
    local radius = 40
    local thickness = 8

    local currentTime = GetGameTimer() or 0
    local elapsedTime = 0
    if Menu.LoadingStartTime then
        elapsedTime = currentTime - Menu.LoadingStartTime
    end

    local loadingText = ""
    if elapsedTime < 1000 then
        loadingText = "Injecting"
    elseif elapsedTime < 2000 then
        loadingText = "Have Fun !"
    else
        loadingText = "Have Fun !"
    end

    if loadingText ~= "" then
        local textSize = 18
        local textWidth = 0
        if Susano and Susano.GetTextWidth then
            textWidth = Susano.GetTextWidth(loadingText, textSize)
        else
            textWidth = string.len(loadingText) * 10
        end
        local textX = centerX - (textWidth / 2)
        local textY = centerY - radius - 40
        Menu.DrawText(textX, textY, loadingText, textSize, 1.0, 1.0, 1.0, 1.0 * alpha)
    end

    local segments = 90
    local step = 360 / segments
    local startAngle = -90

    for i = 0, segments do
        local angle = math.rad(startAngle + (i * step))
        local px = centerX + radius * math.cos(angle)
        local py = centerY + radius * math.sin(angle)
        local outlineSize = thickness + 4
        
        if Susano and Susano.DrawRectFilled then
            Susano.DrawRectFilled(px - outlineSize/2, py - outlineSize/2, outlineSize, outlineSize, 0.0, 0.0, 0.0, 1.0 * alpha, outlineSize/2)
        else
            Menu.DrawRect(px - outlineSize/2, py - outlineSize/2, outlineSize, outlineSize, 0, 0, 0, 255 * alpha)
        end
    end

    for i = 0, segments do
        local angle = math.rad(startAngle + (i * step))
        local px = centerX + radius * math.cos(angle)
        local py = centerY + radius * math.sin(angle)
        
        if Susano and Susano.DrawRectFilled then
            Susano.DrawRectFilled(px - thickness/2, py - thickness/2, thickness, thickness, 0.15, 0.15, 0.15, 1.0 * alpha, thickness/2)
        else
            Menu.DrawRect(px - thickness/2, py - thickness/2, thickness, thickness, 38, 38, 38, 255 * alpha)
        end
    end

    local progressSegments = math.floor(segments * (Menu.LoadingProgress / 100.0))
    local accentR = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.r) and (Menu.Colors.SelectedBg.r / 255.0) or 1.0
    local accentG = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.g) and (Menu.Colors.SelectedBg.g / 255.0) or 0.0
    local accentB = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.b) and (Menu.Colors.SelectedBg.b / 255.0) or 1.0

    for i = 0, progressSegments do
        local angle = math.rad(startAngle + (i * step))
        local px = centerX + radius * math.cos(angle)
        local py = centerY + radius * math.sin(angle)
        
        if Susano and Susano.DrawRectFilled then
            Susano.DrawRectFilled(px - thickness/2, py - thickness/2, thickness + 1, thickness + 1, accentR, accentG, accentB, 1.0 * alpha, (thickness + 1)/2)
        else
            Menu.DrawRect(px - thickness/2, py - thickness/2, thickness + 1, thickness + 1, accentR * 255, accentG * 255, accentB * 255, 255 * alpha)
        end
    end

    local percentText = string.format("%.0f%%", Menu.LoadingProgress)
    local percentTextSize = 16
    local percentTextWidth = 0
    if Susano and Susano.GetTextWidth then
        percentTextWidth = Susano.GetTextWidth(percentText, percentTextSize)
    else
        percentTextWidth = string.len(percentText) * 9
    end
    local percentTextX = centerX - (percentTextWidth / 2)
    local percentTextY = centerY - (percentTextSize / 2)
    Menu.DrawText(percentTextX, percentTextY, percentText, percentTextSize, 1.0, 1.0, 1.0, 1.0 * alpha)
end

function Menu.DrawFooter()
    local scaledPos = Menu.GetScaledPosition()
    local scale = Menu.Scale or 1.0
    local x = scaledPos.x
    local footerY
    local totalHeight

    if Menu.OpenedCategory then
        local category = Menu.Categories[Menu.OpenedCategory]
        if category and category.hasTabs and category.tabs then
            local currentTab = category.tabs[Menu.CurrentTab]
            if currentTab and currentTab.items then
                local maxVisible = Menu.ItemsPerPage
                local totalItems = #currentTab.items
                local visibleItems = math.min(maxVisible, totalItems)
                totalHeight = scaledPos.headerHeight + (scaledPos.headerSpacing or 0) + scaledPos.mainMenuHeight + scaledPos.mainMenuSpacing + (visibleItems * scaledPos.itemHeight)
            else
                totalHeight = scaledPos.headerHeight + scaledPos.mainMenuHeight + scaledPos.mainMenuSpacing
            end
        else
            totalHeight = scaledPos.headerHeight + (scaledPos.headerSpacing or 0) + scaledPos.mainMenuHeight + scaledPos.mainMenuSpacing
        end
    else
        -- Sans bandeau Main Menu: header + items directement
        local maxVisible = Menu.ItemsPerPage
        local totalCategories = #Menu.Categories - 1
        local visibleCategories = math.min(maxVisible, totalCategories)
        totalHeight = scaledPos.headerHeight + (scaledPos.headerSpacing or 0) + (visibleCategories * scaledPos.itemHeight)
    end

    footerY = scaledPos.y + totalHeight + scaledPos.footerSpacing
    local footerWidth = scaledPos.width - 1
    local footerHeight = scaledPos.footerHeight
    local footerRounding = scaledPos.footerRadius

    if Susano and Susano.DrawRectFilled then
        Susano.DrawRectFilled(x, footerY, footerWidth, footerHeight,
            0.0, 0.0, 0.0, 1.0,
            footerRounding)
    else
        Menu.DrawRoundedRect(x, footerY, footerWidth, footerHeight, 0, 0, 0, 255, footerRounding)
    end

    local footerPadding = 15 * scale
    local footerSize = 15
    local scaledFooterSize = footerSize * scale
    local footerTextY = footerY + math.floor((footerHeight - scaledFooterSize) / 2)

    local footerText = (Menu.FooterText and Menu.FooterText ~= "") and Menu.FooterText or "BUSDANSTETE"
    local currentX = x + footerPadding

    local textWidth = 0
    if Susano and Susano.GetTextWidth then
        textWidth = Susano.GetTextWidth(footerText, scaledFooterSize)
    else
        textWidth = string.len(footerText) * 8 * scale
    end

    -- Faux-bold: double rendu avec offset de 1px
    local tR = Menu.Colors.TextWhite.r / 255.0
    local tG = Menu.Colors.TextWhite.g / 255.0
    local tB = Menu.Colors.TextWhite.b / 255.0
    Menu.DrawText(currentX, footerTextY, footerText, footerSize, tR, tG, tB, 1.0)
    Menu.DrawText(currentX + 1, footerTextY, footerText, footerSize, tR, tG, tB, 1.0)

    if Menu.FooterLogoTex and Menu.FooterLogoTex > 0 and Susano and Susano.DrawImage then
        local _lSz = footerHeight * 0.7
        local _lX = x + (footerWidth / 2) - (_lSz / 2)
        local _lY = footerY + (footerHeight - _lSz) / 2
        Susano.DrawImage(Menu.FooterLogoTex, _lX, _lY, _lSz, _lSz, 1, 1, 1, 1, 0)
    end

    local displayIndex
    local totalItems

    if Menu.OpenedCategory then
        local category = Menu.Categories[Menu.OpenedCategory]
        if category and category.hasTabs and category.tabs then
            local currentTab = category.tabs[Menu.CurrentTab]
            if currentTab and currentTab.items then
                displayIndex = Menu.CurrentItem
                totalItems = #currentTab.items
            else
                displayIndex = 1
                totalItems = 1
            end
        else
            displayIndex = 1
            totalItems = 1
        end
    else
        displayIndex = Menu.CurrentCategory - 1
        if displayIndex < 1 then displayIndex = 1 end
        totalItems = #Menu.Categories - 1
    end

    local posText = string.format("%d/%d", displayIndex, totalItems)

    local posWidth = 0
    if Susano and Susano.GetTextWidth then
        posWidth = Susano.GetTextWidth(posText, scaledFooterSize)
    else
        posWidth = string.len(posText) * 8 * scale
    end

    local posX = x + footerWidth - posWidth - footerPadding
    -- Faux-bold pour la pagination aussi
    Menu.DrawText(posX, footerTextY, posText, footerSize, tR, tG, tB, 1.0)
    Menu.DrawText(posX + 1, footerTextY, posText, footerSize, tR, tG, tB, 1.0)
end

function Menu.DrawKeySelector(alpha)
    if alpha <= 0 then return end

    local screenWidth = 1920
    local screenHeight = 1080
    if Susano and Susano.GetScreenWidth and Susano.GetScreenHeight then
        screenWidth = Susano.GetScreenWidth()
        screenHeight = Susano.GetScreenHeight()
    end

    local padding = 15
    local cornerRadius = 8
    local barHeight = 4
    local lineHeight = 28
    local textSize = 14
    local headerHeight = 42

    local width = 400
    local startX = math.floor((screenWidth - width) / 2)
    local startY = math.floor(screenHeight - 160)

    local itemName = Menu.BindingItem and (Menu.BindingItem.name or "Option") or "Menu Toggle"
    local keyName = Menu.BindingItem and Menu.BindingKeyName or Menu.SelectedKeyName
    if not keyName then keyName = "..." end
    local status = "press a key"
    local rowText = itemName .. " [" .. keyName .. "] - " .. status

    local totalHeight = headerHeight + barHeight + padding + lineHeight + padding

    local menuR = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.r) and (Menu.Colors.SelectedBg.r / 255.0) or 0.4
    local menuG = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.g) and (Menu.Colors.SelectedBg.g / 255.0) or 0.2
    local menuB = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.b) and (Menu.Colors.SelectedBg.b / 255.0) or 0.8

    local bgAlpha = 0.65 * alpha
    if Susano and Susano.DrawRectFilled then
        Susano.DrawRectFilled(startX, startY, width, totalHeight, 0.0, 0.0, 0.0, bgAlpha, cornerRadius)
    else
        Menu.DrawRoundedRect(startX, startY, width, totalHeight, 0, 0, 0, math.floor(255 * bgAlpha), cornerRadius)
    end

    local title = "KEYBIND"
    local titleX = startX + padding
    local titleY = startY + padding - 2
    Menu.DrawText(titleX - 1, titleY - 1, title, textSize, 0.0, 0.0, 0.0, 1.0 * alpha)
    Menu.DrawText(titleX + 1, titleY - 1, title, textSize, 0.0, 0.0, 0.0, 1.0 * alpha)
    Menu.DrawText(titleX - 1, titleY + 1, title, textSize, 0.0, 0.0, 0.0, 1.0 * alpha)
    Menu.DrawText(titleX + 1, titleY + 1, title, textSize, 0.0, 0.0, 0.0, 1.0 * alpha)
    Menu.DrawText(titleX, titleY, title, textSize, 1.0, 1.0, 1.0, 1.0 * alpha)

    local barY = startY + headerHeight
    local barLabel = "Choose a key"
    local barLabelSize = 12
    local barLabelW = Susano and Susano.GetTextWidth and Susano.GetTextWidth(barLabel, barLabelSize) or (string.len(barLabel) * 7)
    local barLabelX = startX + (width / 2) - (barLabelW / 2)
    local barLabelY = barY - barLabelSize - 4
    Menu.DrawText(barLabelX, barLabelY, barLabel, barLabelSize, 0.9, 0.9, 0.9, 1.0 * alpha)

    if Susano and Susano.DrawRectFilled then
        Susano.DrawRectFilled(startX + padding, barY, width - 2 * padding, barHeight, menuR, menuG, menuB, 1.0 * alpha, 0)
    else
        Menu.DrawRect(startX + padding, barY, width - 2 * padding, barHeight, math.floor(menuR * 255), math.floor(menuG * 255), math.floor(menuB * 255), math.floor(255 * alpha))
    end

    local rowY = barY + barHeight + padding
    local textX = startX + padding
    local textY = rowY + (lineHeight / 2) - (textSize / 2)

    Menu.DrawText(textX, textY, rowText, textSize, 1.0, 1.0, 1.0, 1.0 * alpha)

    local boxSize = 34
    local boxX = startX + width - padding - boxSize
    local boxY = rowY + (lineHeight / 2) - (boxSize / 2)
    if Susano and Susano.DrawRectFilled then
        Susano.DrawRectFilled(boxX, boxY, boxSize, boxSize, 0.12, 0.12, 0.12, 1.0 * alpha, 6)
    else
        Menu.DrawRect(boxX, boxY, boxSize, boxSize, 30, 30, 30, 255 * alpha)
    end

    local keySize = 18
    local keyW = Susano and Susano.GetTextWidth and Susano.GetTextWidth(keyName, keySize) or (string.len(keyName) * 9)
    Menu.DrawText(math.floor(boxX + (boxSize / 2) - (keyW / 2)), math.floor(boxY + (boxSize / 2) - (keySize / 2)), keyName, keySize, 1.0, 1.0, 1.0, 1.0 * alpha)
end

function Menu.DrawKeybindsInterface(alpha)
    if alpha <= 0 then
        return
    end

    local screenWidth = 1920
    local screenHeight = 1080
    if Susano and Susano.GetScreenWidth and Susano.GetScreenHeight then
        screenWidth = Susano.GetScreenWidth()
        screenHeight = Susano.GetScreenHeight()
    end

    local activeBinds = {}
    for _, cat in ipairs(Menu.Categories) do
        if cat.hasTabs and cat.tabs then
            for _, tab in ipairs(cat.tabs) do
                if tab.items then
                    for _, item in ipairs(tab.items) do
                        if item.bindKey and item.bindKeyName and (item.type == "toggle" or item.type == "action") then
                            table.insert(activeBinds, {
                                name = item.name,
                                keyName = item.bindKeyName,
                                isActive = (item.type == "toggle" and (item.value or false)) or nil
                            })
                        end
                    end
                end
            end
        end
    end

    if #activeBinds == 0 then
        return
    end

    local padding = 15
    local cornerRadius = 8
    local barHeight = 2
    local lineHeight = 25
    local textSize = 14
    local headerHeight = 40
    
    local maxWidth = 0
    for _, bind in ipairs(activeBinds) do
        local status = bind.isActive and "on" or "off"
        local text = bind.name .. " (" .. bind.keyName .. ") [" .. status .. "]"
        local textWidth = 0
        if Susano and Susano.GetTextWidth then
            textWidth = Susano.GetTextWidth(text, textSize)
        else
            textWidth = string.len(text) * 8
        end
        if textWidth > maxWidth then
            maxWidth = textWidth
        end
    end
    
    local width = math.max(200, maxWidth + (padding * 2))
    local startX = screenWidth - width - 20
    local startY = 20

    local contentHeight = #activeBinds * lineHeight
    local totalHeight = headerHeight + barHeight + padding + contentHeight + padding

    local menuR = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.r) and (Menu.Colors.SelectedBg.r / 255.0) or 0.4
    local menuG = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.g) and (Menu.Colors.SelectedBg.g / 255.0) or 0.2
    local menuB = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.b) and (Menu.Colors.SelectedBg.b / 255.0) or 0.8

    local bgAlpha = 0.6 * alpha
    if Susano and Susano.DrawRectFilled then
        Susano.DrawRectFilled(startX, startY, width, totalHeight, 0.0, 0.0, 0.0, bgAlpha, cornerRadius)
    else
        Menu.DrawRoundedRect(startX, startY, width, totalHeight, 0, 0, 0, math.floor(255 * bgAlpha), cornerRadius)
    end

    local textX = startX + padding
    local textY = startY + padding
    Menu.DrawText(textX, textY, "keybind", textSize, 1.0, 1.0, 1.0, 1.0 * alpha)

    local barY = startY + headerHeight
    if Susano and Susano.DrawRectFilled then
        Susano.DrawRectFilled(startX + padding, barY, width - 2 * padding, barHeight, menuR, menuG, menuB, 1.0 * alpha, 0)
    else
        Menu.DrawRect(startX + padding, barY, width - 2 * padding, barHeight, math.floor(menuR * 255), math.floor(menuG * 255), math.floor(menuB * 255), math.floor(255 * alpha))
    end

    local currentY = barY + barHeight + padding
    for i, bind in ipairs(activeBinds) do
        local text
        if bind.isActive ~= nil then
            local status = bind.isActive and "on" or "off"
            text = bind.name .. " (" .. bind.keyName .. ") [" .. status .. "]"
        else
            text = bind.name .. " (" .. bind.keyName .. ")"
        end
        local bindTextX = startX + padding
        local bindTextY = currentY + (i - 1) * lineHeight

        Menu.DrawText(bindTextX - 1, bindTextY - 1, text, textSize, 0.0, 0.0, 0.0, 1.0 * alpha)
        Menu.DrawText(bindTextX + 1, bindTextY - 1, text, textSize, 0.0, 0.0, 0.0, 1.0 * alpha)
        Menu.DrawText(bindTextX - 1, bindTextY + 1, text, textSize, 0.0, 0.0, 0.0, 1.0 * alpha)
        Menu.DrawText(bindTextX + 1, bindTextY + 1, text, textSize, 0.0, 0.0, 0.0, 1.0 * alpha)
        Menu.DrawText(bindTextX, bindTextY, text, textSize, 1.0, 1.0, 1.0, 1.0 * alpha)
    end
end

Menu.Particles = {}
for i = 1, 15 do
    table.insert(Menu.Particles, {
        x = math.random(0, 100) / 100,
        y = math.random(0, 100) / 100,
        speedY = math.random(20, 100) / 10000,
        speedX = math.random(-20, 20) / 10000,
        size = math.random(1, 2),
        life = math.random(10, 50)
    })
end

function Menu.GetLayoutSegments()
    local segments = {}
    local scaledPos = Menu.GetScaledPosition()
    local x = scaledPos.x
    local startY = scaledPos.y
    local width = scaledPos.width
    
    local headerH = scaledPos.headerHeight
    local headerSp = scaledPos.headerSpacing or 0
    local menuBarH = scaledPos.mainMenuHeight
    local spacing = scaledPos.mainMenuSpacing
    local itemH = scaledPos.itemHeight
    local footerSpacing = scaledPos.footerSpacing
    local footerH = scaledPos.footerHeight
    
    local itemsY = 0
    local itemsH = 0
    
    if Menu.OpenedCategory then
        local menuBarY = startY + headerH + headerSp
        table.insert(segments, {y = menuBarY, h = menuBarH})
        
        itemsY = startY + headerH + headerSp + menuBarH + spacing
        
        local category = Menu.Categories[Menu.OpenedCategory]
        if category and category.hasTabs and category.tabs then
            local currentTab = category.tabs[Menu.CurrentTab]
            if currentTab and currentTab.items then
                local maxVisible = Menu.ItemsPerPage
                local totalItems = #currentTab.items
                local visibleItems = math.min(maxVisible, totalItems)
                itemsH = visibleItems * itemH
            end
        end
    else
        itemsY = startY + headerH + headerSp
        
        local maxVisible = Menu.ItemsPerPage
        local totalCategories = #Menu.Categories - 1
        local visibleCategories = math.min(maxVisible, totalCategories)
        itemsH = visibleCategories * itemH
    end
    
    if itemsH > 0 then
        table.insert(segments, {y = itemsY, h = itemsH})
    end
    
    local footerY = itemsY + itemsH + footerSpacing
    table.insert(segments, {y = footerY, h = footerH})
    
    local fullHeight = (itemsY + itemsH) - startY
    if fullHeight <= 0 then
        fullHeight = (footerY + footerH) - startY
    end
    
    return segments, fullHeight
end

function Menu.DrawBackground()
    local scaledPos = Menu.GetScaledPosition()
    local x = scaledPos.x
    local y = scaledPos.y
    local width = scaledPos.width - 1
    local segments, fullHeight = Menu.GetLayoutSegments()
    local startY = scaledPos.y
    local headerH = scaledPos.headerHeight
    local headerSp = scaledPos.headerSpacing or 0
    local menuBarH = scaledPos.mainMenuHeight
    local spacing = scaledPos.mainMenuSpacing
    local itemH = scaledPos.itemHeight
    local bgR, bgG, bgB = 0.059, 0.059, 0.059
    local bgAlpha = 0.98
    local menuRadius = 6
    local borderR, borderG, borderB = 0.216, 0.216, 0.216
    if Menu.OpenedCategory then
        local tabsY = startY + headerH + headerSp
        local itemsH = 0
        local category = Menu.Categories[Menu.OpenedCategory]
        if category and category.hasTabs and category.tabs then
            local currentTab = category.tabs[Menu.CurrentTab]
            if currentTab and currentTab.items then
                itemsH = math.min(Menu.ItemsPerPage, #currentTab.items) * itemH
            end
        end
        local totalH = menuBarH + spacing + itemsH
        if totalH > 0 then
            if Susano and Susano.DrawRectFilled then
                Susano.DrawRectFilled(x, tabsY, width, totalH, borderR, borderG, borderB, bgAlpha, menuRadius)
                Susano.DrawRectFilled(x + 1, tabsY + 1, width - 2, totalH - 2, bgR, bgG, bgB, bgAlpha, menuRadius)
                Susano.DrawRectFilled(x + 1, tabsY + 1, width - 2, menuBarH - 1, 0.0, 0.0, 0.0, 1.0, menuRadius)
            else
                Menu.DrawRect(x, tabsY, width, totalH, 15, 15, 15, math.floor(bgAlpha * 255))
                Menu.DrawRect(x, tabsY, width, menuBarH, 0, 0, 0, 255)
            end
        end
    else
        local itemsY = startY + headerH + headerSp
        local totalCat = #Menu.Categories - 1
        local itemsH = math.min(Menu.ItemsPerPage, totalCat) * itemH
        if itemsH > 0 then
            if Susano and Susano.DrawRectFilled then
                Susano.DrawRectFilled(x, itemsY, width, itemsH, borderR, borderG, borderB, bgAlpha, menuRadius)
                Susano.DrawRectFilled(x + 1, itemsY + 1, width - 2, itemsH - 2, bgR, bgG, bgB, bgAlpha, menuRadius)
            else
                Menu.DrawRect(x, itemsY, width, itemsH, 15, 15, 15, math.floor(bgAlpha * 255))
            end
        end
    end

    if Menu.ShowSnowflakes then
        for _, p in ipairs(Menu.Particles) do
            p.y = p.y + p.speedY
            p.x = p.x + p.speedX

            if p.y > 1.0 then
                p.y = 0
                p.x = math.random(0, 100) / 100
                p.speedY = math.random(20, 100) / 10000
                p.speedX = math.random(-20, 20) / 10000
            end

            local pX = x + (p.x * width)
            local pY = y + (p.y * fullHeight)
            
            local isVisible = false
            for i, seg in ipairs(segments) do
                if i == #segments then
                    break
                end
                if pY >= seg.y and pY <= seg.y + seg.h then
                    isVisible = true
                    break
                end
            end
            
            if isVisible then
                 local alpha = math.random(100, 200)
                 if Susano and Susano.DrawRectFilled then
                    Susano.DrawRectFilled(pX, pY, p.size, p.size, 1.0, 1.0, 1.0, alpha/255, 0)
                else
                    Menu.DrawRect(pX, pY, p.size, p.size, 255, 255, 255, alpha)
                end
            end
        end
    end
end


function Menu.Render()
    if Menu.TopLevelTabs and not Menu.Categories then
        Menu.UpdateCategoriesFromTopTab()
    end

    if not (Susano and Susano.BeginFrame) then
        return
    end

    local dt = 0.016
    if GetFrameTime then
        dt = GetFrameTime()
    end
    local animSpeed = 5.0 * dt

    if Menu.IsLoading then
        Menu.LoadingBarAlpha = math.min(1.0, Menu.LoadingBarAlpha + animSpeed)
    else
        Menu.LoadingBarAlpha = math.max(0.0, Menu.LoadingBarAlpha - animSpeed)
    end

    if Menu.SelectingKey or Menu.SelectingBind then
        Menu.KeySelectorAlpha = math.min(1.0, Menu.KeySelectorAlpha + animSpeed)
    else
        Menu.KeySelectorAlpha = math.max(0.0, Menu.KeySelectorAlpha - animSpeed)
    end

    if Menu.ShowKeybinds then
        Menu.KeybindsInterfaceAlpha = math.min(1.0, Menu.KeybindsInterfaceAlpha + animSpeed)
    else
        Menu.KeybindsInterfaceAlpha = math.max(0.0, Menu.KeybindsInterfaceAlpha - animSpeed)
    end

    Susano.BeginFrame()

    if Menu.KeybindsInterfaceAlpha > 0 then
        Menu.DrawKeybindsInterface(Menu.KeybindsInterfaceAlpha)
    end

    if Menu.Visible then
        if Menu.EditorMode and Susano and Susano.EnableOverlay then
            Susano.EnableOverlay(true)
        elseif not Menu.EditorMode and Susano and Susano.EnableOverlay then
            Susano.EnableOverlay(false)
        end
        
        Menu.DrawBackground()
        Menu.DrawHeader()
        Menu.DrawCategories()
        Menu.DrawFooter()
    end

    if Menu.InputOpen then
        Menu.DrawInputWindow()
    end

    if Menu.LoadingBarAlpha > 0 then
        Menu.DrawLoadingBar(Menu.LoadingBarAlpha)
    end

    if Menu.KeySelectorAlpha > 0 then
        Menu.DrawKeySelector(Menu.KeySelectorAlpha)
    end

    if Menu.OnRender then
        local success, err = pcall(Menu.OnRender)
        if not success then
        end
    end

    if Susano.SubmitFrame then
        Susano.SubmitFrame()
    end

    if not Menu.Visible and not Menu.ShowKeybinds and Menu.LoadingBarAlpha <= 0 and Menu.KeySelectorAlpha <= 0 then
        if Susano.ResetFrame then
            Susano.ResetFrame()
        end
    end
end

Menu.KeyStates = {}

function Menu.IsKeyJustPressed(keyCode)
    if not (Susano and Susano.GetAsyncKeyState) then
        return false
    end

    local down, pressed = Susano.GetAsyncKeyState(keyCode)
    local wasDown = Menu.KeyStates[keyCode] or false

    if down == true then
        Menu.KeyStates[keyCode] = true
    else
        Menu.KeyStates[keyCode] = false
    end

    if pressed == true then
        return true
    end

    if down == true and not wasDown then
        return true
    end

    return false
end


Menu.KeyNames = {
    [0x08] = "Backspace", [0x09] = "Tab", [0x0D] = "Enter", [0x10] = "Shift",
    [0x11] = "Ctrl", [0x12] = "Alt", [0x13] = "Pause", [0x14] = "Caps Lock",
    [0x1B] = "ESC", [0x20] = "Space", [0x21] = "Page Up", [0x22] = "Page Down",
    [0x23] = "End", [0x24] = "Home", [0x25] = "Left", [0x26] = "Up",
    [0x27] = "Right", [0x28] = "Down", [0x2D] = "Insert", [0x2E] = "Delete",
    [0x30] = "0", [0x31] = "1", [0x32] = "2", [0x33] = "3", [0x34] = "4",
    [0x35] = "5", [0x36] = "6", [0x37] = "7", [0x38] = "8", [0x39] = "9",
    [0x41] = "A", [0x42] = "B", [0x43] = "C", [0x44] = "D", [0x45] = "E",
    [0x46] = "F", [0x47] = "G", [0x48] = "H", [0x49] = "I", [0x4A] = "J",
    [0x4B] = "K", [0x4C] = "L", [0x4D] = "M", [0x4E] = "N", [0x4F] = "O",
    [0x50] = "P", [0x51] = "Q", [0x52] = "R", [0x53] = "S", [0x54] = "T",
    [0x55] = "U", [0x56] = "V", [0x57] = "W", [0x58] = "X", [0x59] = "Y",
    [0x5A] = "Z", [0x60] = "Numpad 0", [0x61] = "Numpad 1", [0x62] = "Numpad 2",
    [0x63] = "Numpad 3", [0x64] = "Numpad 4", [0x65] = "Numpad 5", [0x66] = "Numpad 6",
    [0x67] = "Numpad 7", [0x68] = "Numpad 8", [0x69] = "Numpad 9",
    [0x6A] = "Multiply", [0x6B] = "Add", [0x6D] = "Subtract", [0x6E] = "Decimal",
    [0x6F] = "Divide", [0x70] = "F1", [0x71] = "F2", [0x72] = "F3", [0x73] = "F4",
    [0x74] = "F5", [0x75] = "F6", [0x76] = "F7", [0x77] = "F8", [0x78] = "F9",
    [0x79] = "F10", [0x7A] = "F11", [0x7B] = "F12",
    [0x90] = "Num Lock", [0x91] = "Scroll Lock",
    [0xA0] = "Left Shift", [0xA1] = "Right Shift", [0xA2] = "Left Ctrl",
    [0xA3] = "Right Ctrl", [0xA4] = "Left Alt", [0xA5] = "Right Alt"
}

function Menu.GetKeyName(keyCode)
    return Menu.KeyNames[keyCode] or ("Key 0x" .. string.format("%02X", keyCode))
end

function Menu.HandleInput()
    if Menu.IsLoading or not Menu.LoadingComplete then
        return
    end

    if Menu.InputOpen then
        return
    end

    if Menu.SelectingBind then
        if not (Susano and Susano.GetAsyncKeyState) then
            return
        end

        if Menu.IsKeyJustPressed(0x0D) then
            if Menu.BindingKey and Menu.BindingItem then
                Menu.BindingItem.bindKey = Menu.BindingKey
                Menu.BindingItem.bindKeyName = Menu.BindingKeyName
                local itemName = Menu.BindingItem.name or "option"
                local savedKeyName = Menu.BindingKeyName
                Menu.SelectingBind = false
                Menu.BindingItem = nil
                Menu.BindingKey = nil
                Menu.BindingKeyName = nil
                print("Bind set for " .. itemName .. ": " .. tostring(savedKeyName))
            end
            return
        end

        local keysToCheck = {
            0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D,
            0x4E, 0x4F, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A,
            0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
            0x20, 0x1B, 0x08, 0x09, 0x10, 0x11, 0x12,
            0x25, 0x26, 0x27, 0x28,
            0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x7B
        }

        for _, keyCode in ipairs(keysToCheck) do
            if keyCode ~= 0x0D then
                local down, pressed = Susano.GetAsyncKeyState(keyCode)
                if down == true or pressed == true then
                    local wasDown = Menu.KeyStates[keyCode] or false
                    if (pressed == true) or (down == true and not wasDown) then
                        Menu.BindingKey = keyCode
                        Menu.BindingKeyName = Menu.GetKeyName(keyCode)
                        Menu.KeyStates[keyCode] = true
                        break
                    end
                    if down == true then
                        Menu.KeyStates[keyCode] = true
                    else
                        Menu.KeyStates[keyCode] = false
                    end
                end
            end
        end
        return
    end

    if Menu.SelectingKey then
        if not (Susano and Susano.GetAsyncKeyState) then
            return
        end

        if Menu.IsKeyJustPressed(0x0D) then
            if Menu.SelectedKey then
                Menu.SelectingKey = false
            end
            return
        end

        local keysToCheck = {
            0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D,
            0x4E, 0x4F, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A,
            0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
            0x20, 0x1B, 0x08, 0x09, 0x10, 0x11, 0x12,
            0x25, 0x26, 0x27, 0x28,
            0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x7B
        }

        for _, keyCode in ipairs(keysToCheck) do
            if keyCode ~= 0x0D then
                local down, pressed = Susano.GetAsyncKeyState(keyCode)
                if down == true or pressed == true then
                    local wasDown = Menu.KeyStates[keyCode] or false
                    if (pressed == true) or (down == true and not wasDown) then
                        Menu.SelectedKey = keyCode
                        Menu.SelectedKeyName = Menu.GetKeyName(keyCode)
                        Menu.KeyStates[keyCode] = true
                        break
                    end
                    if down == true then
                        Menu.KeyStates[keyCode] = true
                    else
                        Menu.KeyStates[keyCode] = false
                    end
                end
            end
        end
        return
    end

    if Susano and Susano.GetAsyncKeyState then
        if Menu.Categories then
            for _, category in ipairs(Menu.Categories) do
                if category and category.hasTabs and category.tabs then
                    for _, tab in ipairs(category.tabs) do
                        if tab and tab.items then
                            for _, item in ipairs(tab.items) do
                                if item and item.bindKey and (item.type == "toggle" or item.type == "action") then
                                    local down, pressed = Susano.GetAsyncKeyState(item.bindKey)
                                    local wasDown = Menu.KeyStates[item.bindKey] or false

                                    if down == true then
                                        Menu.KeyStates[item.bindKey] = true
                                    else
                                        Menu.KeyStates[item.bindKey] = false
                                    end

                                    if (pressed == true) or (down == true and not wasDown) then
                                        if item.type == "toggle" then
                                            item.value = not item.value
                                            if item.name == "Editor Mode" then
                                                Menu.EditorMode = item.value
                                            end
                                            if item.onClick then
                                                item.onClick(item.value)
                                            end
                                            print("Toggled " .. (item.name or "option") .. " to " .. tostring(item.value))
                                        elseif item.type == "action" then
                                            if item.onClick then
                                                item.onClick()
                                            end
                                            print("Executed action: " .. (item.name or "option"))
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local toggleKeyCode = Menu.SelectedKey or 0x31
    if Susano and Susano.GetAsyncKeyState then
        local down, pressed = Susano.GetAsyncKeyState(toggleKeyCode)

        local wasDown = Menu.KeyStates[toggleKeyCode] or false
        local keyPressed = false

        if pressed == true then
            keyPressed = true
        elseif down == true and not wasDown then
            keyPressed = true
        end

        if down == true then
            Menu.KeyStates[toggleKeyCode] = true
        else
            Menu.KeyStates[toggleKeyCode] = false
        end

        if keyPressed then
            local wasVisible = Menu.Visible
            Menu.Visible = not Menu.Visible

            if wasVisible and not Menu.Visible and not Menu.ShowKeybinds then
                if Susano and Susano.ResetFrame then
                    Susano.ResetFrame()
                end
            end
        end
    end

    if not Menu.Visible then
        return
    end

    if Menu.EditorMode then
        local moveSpeed = 8.0
        local screenW = 1920
        local screenH = 1080
        if Susano and Susano.GetScreenWidth and Susano.GetScreenHeight then
            screenW = Susano.GetScreenWidth()
            screenH = Susano.GetScreenHeight()
        end

        if Susano and Susano.GetCursorPos and Susano.GetAsyncKeyState then
            local cursorPos = Susano.GetCursorPos()
            local mouseX = 0
            local mouseY = 0
            
            if cursorPos then
                if type(cursorPos) == "table" then
                    mouseX = cursorPos[1] or cursorPos.x or 0
                    mouseY = cursorPos[2] or cursorPos.y or 0
                else
                    local xOk, x = pcall(function() return cursorPos.x end)
                    local yOk, y = pcall(function() return cursorPos.y end)
                    if xOk and x then mouseX = x end
                    if yOk and y then mouseY = y end
                end
            end
            
            local leftMouseDown = false
            if Susano.GetAsyncKeyState then
                local lmbDown, lmbPressed = Susano.GetAsyncKeyState(0x01)
                if lmbDown == true or lmbDown == 1 then
                    leftMouseDown = true
                end
            end
            
            if not leftMouseDown and (IsControlPressed or IsDisabledControlPressed) then
                if IsDisabledControlPressed and IsDisabledControlPressed(0, 24) then
                    leftMouseDown = true
                elseif IsControlPressed and IsControlPressed(0, 24) then
                    leftMouseDown = true
                end
            end
            
            local menuX = Menu.Position.x
            local menuY = Menu.Position.y
            local menuWidth = Menu.Position.width
            
            local totalHeight = Menu.Position.headerHeight + (Menu.Position.headerSpacing or 0)
            if Menu.OpenedCategory then
                local category = Menu.Categories[Menu.OpenedCategory]
                if category and category.hasTabs and category.tabs then
                    local currentTab = category.tabs[Menu.CurrentTab]
                    if currentTab and currentTab.items then
                        local maxVisible = Menu.ItemsPerPage
                        local totalItems = #currentTab.items
                        local visibleItems = math.min(maxVisible, totalItems)
                        totalHeight = totalHeight + Menu.Position.mainMenuHeight + Menu.Position.mainMenuSpacing + (visibleItems * Menu.Position.itemHeight)
                    else
                        totalHeight = totalHeight + Menu.Position.mainMenuHeight + Menu.Position.mainMenuSpacing
                    end
                else
                    totalHeight = totalHeight + Menu.Position.mainMenuHeight + Menu.Position.mainMenuSpacing
                end
            else
                local maxVisible = Menu.ItemsPerPage
                local totalCategories = #Menu.Categories - 1
                local visibleCategories = math.min(maxVisible, totalCategories)
                totalHeight = totalHeight + Menu.Position.mainMenuHeight + Menu.Position.mainMenuSpacing + (visibleCategories * Menu.Position.itemHeight)
            end
            totalHeight = totalHeight + Menu.Position.footerSpacing + Menu.Position.footerHeight
            
            local isOverMenu = (mouseX >= menuX and mouseX <= menuX + menuWidth and 
                               mouseY >= menuY and mouseY <= menuY + totalHeight)
            
            local wasMouseDown = Menu.KeyStates[0x01] or false
            
            if leftMouseDown then
                if not wasMouseDown and isOverMenu then
                    Menu.EditorDragging = true
                    Menu.EditorDragOffsetX = mouseX - menuX
                    Menu.EditorDragOffsetY = mouseY - menuY
                    print("Started dragging menu")
                end
                
                if Menu.EditorDragging then
                    local newX = mouseX - Menu.EditorDragOffsetX
                    local newY = mouseY - Menu.EditorDragOffsetY
                    
                    local maxX = math.max(0, screenW - menuWidth)
                    local maxY = math.max(0, screenH - totalHeight)
                    
                    Menu.Position.x = math.max(0, math.min(maxX, newX))
                    Menu.Position.y = math.max(0, math.min(maxY, newY))
                end
                
                Menu.KeyStates[0x01] = true
            else
                Menu.EditorDragging = false
                Menu.KeyStates[0x01] = false
            end
        end

        if Susano and Susano.GetAsyncKeyState then
            local upDown = Susano.GetAsyncKeyState(0x26)
            local downDown = Susano.GetAsyncKeyState(0x28)
            local leftDown = Susano.GetAsyncKeyState(0x25)
            local rightDown = Susano.GetAsyncKeyState(0x27)

            if upDown == true then
                Menu.Position.y = math.max(0, Menu.Position.y - moveSpeed)
            end
            if downDown == true then
                Menu.Position.y = math.min(screenH - 200, Menu.Position.y + moveSpeed)
            end
            if leftDown == true then
                Menu.Position.x = math.max(0, Menu.Position.x - moveSpeed)
            end
            if rightDown == true then
                Menu.Position.x = math.min(screenW - Menu.Position.width, Menu.Position.x + moveSpeed)
            end

            if Menu.IsKeyJustPressed(0x0D) then
                local currentTab = nil
                if Menu.OpenedCategory then
                    local category = Menu.Categories[Menu.OpenedCategory]
                    if category and category.hasTabs and category.tabs then
                        currentTab = category.tabs[Menu.CurrentTab]
                    end
                end
                if currentTab and currentTab.items then
                    for _, item in ipairs(currentTab.items) do
                        if item.name == "Editor Mode" and item.type == "toggle" then
                            item.value = not item.value
                            Menu.EditorMode = item.value
                            break
                        end
                    end
                end
            end
        end
        return
    end

    if Menu.OpenedCategory then
        local category = Menu.Categories[Menu.OpenedCategory]
        if not category or not category.hasTabs or not category.tabs then
            Menu.OpenedCategory = nil
            return
        end

        local currentTab = category.tabs[Menu.CurrentTab]
        if currentTab and currentTab.items then
            if Susano and Susano.GetAsyncKeyState then
                local upDown, upPressed = Susano.GetAsyncKeyState(0x26)
                local downDown, downPressed = Susano.GetAsyncKeyState(0x28)
                local aDown, aPressed = Susano.GetAsyncKeyState(0x41)
                local eDown, ePressed = Susano.GetAsyncKeyState(0x45)
                local backDown, backPressed = Susano.GetAsyncKeyState(0x08)
                local leftDown, leftPressed = Susano.GetAsyncKeyState(0x25)
                local rightDown, rightPressed = Susano.GetAsyncKeyState(0x27)
                local f9Down, f9Pressed = Susano.GetAsyncKeyState(0x78)

                local upWasDown = Menu.KeyStates[0x26] or false
                local downWasDown = Menu.KeyStates[0x28] or false
                local aWasDown = Menu.KeyStates[0x41] or false
                local eWasDown = Menu.KeyStates[0x45] or false
                local backWasDown = Menu.KeyStates[0x08] or false
                local leftWasDown = Menu.KeyStates[0x25] or false
                local rightWasDown = Menu.KeyStates[0x27] or false
                local f9WasDown = Menu.KeyStates[0x78] or false

                if upDown == true then Menu.KeyStates[0x26] = true else Menu.KeyStates[0x26] = false end
                if downDown == true then Menu.KeyStates[0x28] = true else Menu.KeyStates[0x28] = false end
                if aDown == true then Menu.KeyStates[0x41] = true else Menu.KeyStates[0x41] = false end
                if eDown == true then Menu.KeyStates[0x45] = true else Menu.KeyStates[0x45] = false end
                if backDown == true then Menu.KeyStates[0x08] = true else Menu.KeyStates[0x08] = false end
                if leftDown == true then Menu.KeyStates[0x25] = true else Menu.KeyStates[0x25] = false end
                if rightDown == true then Menu.KeyStates[0x27] = true else Menu.KeyStates[0x27] = false end
                if f9Down == true then Menu.KeyStates[0x78] = true else Menu.KeyStates[0x78] = false end

                if (f9Pressed == true) or (f9Down == true and not f9WasDown) then
                    if Menu.CurrentItem > 0 and Menu.CurrentItem <= #currentTab.items then
                        local selectedItem = currentTab.items[Menu.CurrentItem]
                        if selectedItem and not selectedItem.isSeparator then
                            Menu.SelectingBind = true
                            Menu.BindingItem = selectedItem
                            Menu.BindingKey = nil
                            Menu.BindingKeyName = nil
                            if not selectedItem.bindKey then
                                selectedItem.bindKey = nil
                                selectedItem.bindKeyName = nil
                            else
                                Menu.BindingKey = selectedItem.bindKey
                                Menu.BindingKeyName = selectedItem.bindKeyName
                            end
                        end
                    end
                end

                if (upPressed == true) or (upDown == true and not upWasDown) then
                    Menu.CurrentItem = findNextNonSeparator(currentTab.items, Menu.CurrentItem, -1)
                elseif (downPressed == true) or (downDown == true and not downWasDown) then
                    Menu.CurrentItem = findNextNonSeparator(currentTab.items, Menu.CurrentItem, 1)
                elseif (aPressed == true) or (aDown == true and not aWasDown) then
                    if Menu.CurrentTab > 1 then
                        Menu.CurrentTab = Menu.CurrentTab - 1
                        local newTab = category.tabs[Menu.CurrentTab]
                        if newTab and newTab.items then
                            Menu.CurrentItem = findNextNonSeparator(newTab.items, 0, 1)
                        else
                            Menu.CurrentItem = 1
                        end
                        Menu.ItemScrollOffset = 0
                    elseif Menu.TopLevelTabs then
                        Menu.CurrentTopTab = Menu.CurrentTopTab - 1
                        if Menu.CurrentTopTab < 1 then Menu.CurrentTopTab = #Menu.TopLevelTabs end
                        Menu.UpdateCategoriesFromTopTab()
                    end
                elseif (ePressed == true) or (eDown == true and not eWasDown) then
                    if Menu.CurrentTab < #category.tabs then
                        Menu.CurrentTab = Menu.CurrentTab + 1
                        local newTab = category.tabs[Menu.CurrentTab]
                        if newTab and newTab.items then
                            Menu.CurrentItem = findNextNonSeparator(newTab.items, 0, 1)
                        else
                            Menu.CurrentItem = 1
                        end
                        Menu.ItemScrollOffset = 0
                    elseif Menu.TopLevelTabs then
                         Menu.CurrentTopTab = Menu.CurrentTopTab + 1
                         if Menu.CurrentTopTab > #Menu.TopLevelTabs then Menu.CurrentTopTab = 1 end
                         Menu.UpdateCategoriesFromTopTab()
                    end
                elseif (backPressed == true) or (backDown == true and not backWasDown) then
                    if Menu.TopLevelTabs and Menu.TopLevelTabs[Menu.CurrentTopTab].autoOpen then
                         if Menu.CurrentTopTab > 1 then
                             Menu.CurrentTopTab = 1
                             Menu.UpdateCategoriesFromTopTab()
                         else
                             Menu.Visible = false
                         end
                    else
                        Menu.OpenedCategory = nil
                        Menu.CurrentItem = 1
                        Menu.CurrentTab = 1
                        Menu.ItemScrollOffset = 0
                    end
                elseif (leftPressed == true) or (leftDown == true and not leftWasDown) then
                    if Menu.CurrentItem > 0 and Menu.CurrentItem <= #currentTab.items then
                        local selectedItem = currentTab.items[Menu.CurrentItem]
                        if selectedItem then
                            if selectedItem.type == "slider" then
                                local step = 1.0
                                if selectedItem.step then
                                    step = selectedItem.step
                                end
                                selectedItem.value = math.max(selectedItem.min or 0.0, (selectedItem.value or selectedItem.min or 0.0) - step)
                                if selectedItem.name == "Smooth Menu" then
                                    Menu.SmoothFactor = selectedItem.value / 100.0
                                elseif selectedItem.name == "Menu Size" then
                                    Menu.Scale = selectedItem.value / 100.0
                                end
                                if selectedItem.onClick then selectedItem.onClick(selectedItem.value) end
                            elseif selectedItem.type == "toggle" and selectedItem.hasSlider then
                                local step = selectedItem.sliderStep or 0.1
                                selectedItem.sliderValue = math.max(selectedItem.sliderMin or 0.0, (selectedItem.sliderValue or selectedItem.sliderMin or 0.0) - step)
                            elseif selectedItem.type == "toggle_selector" then
                                local currentIndex = selectedItem.selected or 1
                                if selectedItem.options and #selectedItem.options > 0 then
                                    currentIndex = currentIndex - 1
                                    if currentIndex < 1 then
                                        currentIndex = #selectedItem.options
                                    end
                                end
                                selectedItem.selected = currentIndex
                            elseif selectedItem.type == "selector" then
                                local currentIndex = selectedItem.selected or 1

                                local isWardrobeSelector = false
                                local wardrobeItemNames = {"Hat", "Mask", "Glasses", "Torso", "Tshirt", "Pants", "Shoes"}
                                for _, name in ipairs(wardrobeItemNames) do
                                    if selectedItem.name == name then
                                        isWardrobeSelector = true
                                        break
                                    end
                                end

                                if isWardrobeSelector then
                                    currentIndex = math.max(1, currentIndex - 1)
                                else
                                    if selectedItem.options and #selectedItem.options > 0 then
                                        currentIndex = currentIndex - 1
                                        if currentIndex < 1 then
                                            currentIndex = #selectedItem.options
                                        end
                                    end
                                end
                                selectedItem.selected = currentIndex

                                if selectedItem.name == "Menu Theme" and selectedItem.options then
                                    local theme = selectedItem.options[currentIndex]
                                    Menu.ApplyTheme(theme)
                                elseif selectedItem.name == "Gradient" and selectedItem.options then
                                    local gradientVal = selectedItem.options[currentIndex]
                                    Menu.GradientType = tonumber(gradientVal) or 1
                                elseif selectedItem.name == "Scroll Bar Position" and selectedItem.options then
                                    local pos = selectedItem.options[currentIndex]
                                    if pos == "Left" then
                                        Menu.ScrollbarPosition = 1
                                    elseif pos == "Right" then
                                        Menu.ScrollbarPosition = 2
                                    end
                                end

                            end
                        end
                    end
                elseif (rightPressed == true) or (rightDown == true and not rightWasDown) then
                    if Menu.CurrentItem > 0 and Menu.CurrentItem <= #currentTab.items then
                        local selectedItem = currentTab.items[Menu.CurrentItem]
                        if selectedItem then
                            if selectedItem.type == "slider" then
                                local step = 1.0
                                if selectedItem.step then
                                    step = selectedItem.step
                                end
                                selectedItem.value = math.min(selectedItem.max or 100.0, (selectedItem.value or selectedItem.min or 0.0) + step)
                                if selectedItem.name == "Smooth Menu" then
                                    Menu.SmoothFactor = selectedItem.value / 100.0
                                elseif selectedItem.name == "Menu Size" then
                                    Menu.Scale = selectedItem.value / 100.0
                                end
                                if selectedItem.onClick then selectedItem.onClick(selectedItem.value) end
                            elseif selectedItem.type == "toggle" and selectedItem.hasSlider then
                                local step = selectedItem.sliderStep or 0.1
                                selectedItem.sliderValue = math.min(selectedItem.sliderMax or 100.0, (selectedItem.sliderValue or selectedItem.sliderMin or 0.0) + step)
                            elseif selectedItem.type == "toggle_selector" then
                                local currentIndex = selectedItem.selected or 1
                                if selectedItem.options and #selectedItem.options > 0 then
                                    currentIndex = currentIndex + 1
                                    if currentIndex > #selectedItem.options then
                                        currentIndex = 1
                                    end
                                end
                                selectedItem.selected = currentIndex
                            elseif selectedItem.type == "selector" then
                                local currentIndex = selectedItem.selected or 1

                                local isWardrobeSelector = false
                                local wardrobeItemNames = {"Hat", "Mask", "Glasses", "Torso", "Tshirt", "Pants", "Shoes"}
                                for _, name in ipairs(wardrobeItemNames) do
                                    if selectedItem.name == name then
                                        isWardrobeSelector = true
                                        break
                                    end
                                end

                                if isWardrobeSelector then
                                    currentIndex = currentIndex + 1
                                else
                                    if selectedItem.options and #selectedItem.options > 0 then
                                        currentIndex = currentIndex + 1
                                        if currentIndex > #selectedItem.options then
                                            currentIndex = 1
                                        end
                                    end
                                end
                                selectedItem.selected = currentIndex

                                if selectedItem.name == "Menu Theme" and selectedItem.options then
                                    local theme = selectedItem.options[currentIndex]
                                    Menu.ApplyTheme(theme)
                                elseif selectedItem.name == "Gradient" and selectedItem.options then
                                    local gradientVal = selectedItem.options[currentIndex]
                                    Menu.GradientType = tonumber(gradientVal) or 1
                                elseif selectedItem.name == "Scroll Bar Position" and selectedItem.options then
                                    local pos = selectedItem.options[currentIndex]
                                    if pos == "Left" then
                                        Menu.ScrollbarPosition = 1
                                    elseif pos == "Right" then
                                        Menu.ScrollbarPosition = 2
                                    end
                                end

                            end
                        end
                    end
                end
            end

            if Menu.IsKeyJustPressed(0x0D) then
                local item = currentTab.items[Menu.CurrentItem]
                if item and not item.isSeparator then
                    if item.type == "toggle" or item.type == "toggle_selector" then
                        item.value = not item.value
                        if item.name == "Show Menu Keybinds" then
                            Menu.ShowKeybinds = item.value
                        elseif item.name == "Editor Mode" then
                            Menu.EditorMode = item.value
                        elseif item.name == "Flocon" then
                            Menu.ShowSnowflakes = item.value
                        end
                        if item.onClick then item.onClick(item.value) end
                    elseif item.type == "action" then
                        if item.name == "Change Menu Keybind" then
                            Menu.SelectingKey = true
                            Menu.SelectedKey = Menu.SelectedKey
                            Menu.SelectedKeyName = Menu.SelectedKeyName
                            print("Changing menu keybind...")
                        end
                        if item.onClick then item.onClick() end
                    elseif item.type == "selector" then
                        if item.onClick then
                             local option = (item.options and item.options[item.selected]) or nil
                             item.onClick(item.selected, option)
                        end
                    end
                end
            end
        end
    else
        if Susano and Susano.GetAsyncKeyState then
            local upDown, upPressed = Susano.GetAsyncKeyState(0x26)
            local downDown, downPressed = Susano.GetAsyncKeyState(0x28)
            local aDown, aPressed = Susano.GetAsyncKeyState(0x41)
            local eDown, ePressed = Susano.GetAsyncKeyState(0x45)

            local upWasDown = Menu.KeyStates[0x26] or false
            local downWasDown = Menu.KeyStates[0x28] or false
            local aWasDown = Menu.KeyStates[0x41] or false
            local eWasDown = Menu.KeyStates[0x45] or false

            if upDown == true then Menu.KeyStates[0x26] = true else Menu.KeyStates[0x26] = false end
            if downDown == true then Menu.KeyStates[0x28] = true else Menu.KeyStates[0x28] = false end
            if aDown == true then Menu.KeyStates[0x41] = true else Menu.KeyStates[0x41] = false end
            if eDown == true then Menu.KeyStates[0x45] = true else Menu.KeyStates[0x45] = false end

            if (upPressed == true) or (upDown == true and not upWasDown) then
                Menu.CurrentCategory = Menu.CurrentCategory - 1
                if Menu.CurrentCategory < 2 then
                    Menu.CurrentCategory = #Menu.Categories
                end
            elseif (downPressed == true) or (downDown == true and not downWasDown) then
                Menu.CurrentCategory = Menu.CurrentCategory + 1
                if Menu.CurrentCategory > #Menu.Categories then
                    Menu.CurrentCategory = 2
                end
            elseif (aPressed == true) or (aDown == true and not aWasDown) then
                if Menu.TopLevelTabs then
                    Menu.CurrentTopTab = Menu.CurrentTopTab - 1
                    if Menu.CurrentTopTab < 1 then Menu.CurrentTopTab = #Menu.TopLevelTabs end
                    Menu.UpdateCategoriesFromTopTab()
                end
            elseif (ePressed == true) or (eDown == true and not eWasDown) then
                if Menu.TopLevelTabs then
                    Menu.CurrentTopTab = Menu.CurrentTopTab + 1
                    if Menu.CurrentTopTab > #Menu.TopLevelTabs then Menu.CurrentTopTab = 1 end
                    Menu.UpdateCategoriesFromTopTab()
                end
            end
        end

        if Menu.IsKeyJustPressed(0x0D) then
            local category = Menu.Categories[Menu.CurrentCategory]
            if category and category.hasTabs and category.tabs then
                Menu.OpenedCategory = Menu.CurrentCategory
                Menu.CurrentTab = 1
                if category.tabs[1] and category.tabs[1].items then
                    Menu.CurrentItem = findNextNonSeparator(category.tabs[1].items, 0, 1)
                else
                    Menu.CurrentItem = 1
                end
                Menu.ItemScrollOffset = 0
            end
        end
    end
end


CreateThread(function()
    Menu.LoadingStartTime = GetGameTimer() or 0

    while Menu.IsLoading do
        local currentTime = GetGameTimer() or Menu.LoadingStartTime
        local elapsedTime = currentTime - Menu.LoadingStartTime

        Menu.LoadingProgress = (elapsedTime / Menu.LoadingDuration) * 100.0

        if Menu.LoadingProgress >= 100.0 then
            Menu.LoadingProgress = 100.0
            Menu.IsLoading = false
            Menu.LoadingComplete = true
            Menu.SelectingKey = true
            break
        end

        Wait(0)
    end
end)

CreateThread(function()
    while true do
        Menu.Render()

        if Menu.LoadingComplete then
            Menu.HandleInput()
        end

        Wait(0)
    end
end)


function Menu.OpenInput(title, subtitle, callback)
    if type(subtitle) == "function" then
        callback = subtitle
        subtitle = "Enter text below"
    end
    Menu.InputTitle = title
    Menu.InputSubtitle = subtitle
    Menu.InputText = ""
    Menu.InputCallback = callback
    Menu.InputOpen = true
    Menu.SelectingKey = false
    Menu.SelectingBind = false
end

function Menu.DrawInputWindow()
    if not Menu.InputOpen then return end
    
    local screenWidth = 1920
    local screenHeight = 1080
    if Susano and Susano.GetScreenWidth and Susano.GetScreenHeight then
        screenWidth = Susano.GetScreenWidth()
        screenHeight = Susano.GetScreenHeight()
    end
    
    if Susano and Susano.DrawRectFilled then
        Susano.DrawRectFilled(0, 0, screenWidth, screenHeight, 0, 0, 0, 0.6, 0)
    else
        Menu.DrawRect(0, 0, screenWidth, screenHeight, 0, 0, 0, 150)
    end
    
    local width = 350
    local height = 130
    local x = (screenWidth / 2) - (width / 2)
    local y = (screenHeight / 2) - (height / 2)
    
    if Susano and Susano.DrawRectFilled then
        Susano.DrawRectFilled(x, y, width, height, 0.08, 0.08, 0.08, 1.0, 6)
    else
        Menu.DrawRect(x, y, width, height, 20, 20, 20, 255)
    end
    
    local r = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.r) and (Menu.Colors.SelectedBg.r / 255.0) or 1.0
    local g = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.g) and (Menu.Colors.SelectedBg.g / 255.0) or 0.0
    local b = (Menu.Colors.SelectedBg and Menu.Colors.SelectedBg.b) and (Menu.Colors.SelectedBg.b / 255.0) or 1.0
    
    if Susano and Susano.DrawRectFilled then
        Susano.DrawRectFilled(x, y, width, 2, r, g, b, 1.0, 0)
    else
        Menu.DrawRect(x, y, width, 2, math.floor(r*255), math.floor(g*255), math.floor(b*255), 255)
    end
    
    local titleText = Menu.InputTitle or "Input"
    local titleSize = 20
    local titleWidth = 0
    if Susano and Susano.GetTextWidth then
        titleWidth = Susano.GetTextWidth(titleText, titleSize)
    else
        titleWidth = string.len(titleText) * 10
    end
    local titleX = x + (width / 2) - (titleWidth / 2)
    Menu.DrawText(titleX, y + 15, titleText, titleSize, 1.0, 1.0, 1.0, 1.0)
    
    local subText = Menu.InputSubtitle or "Enter text below:"
    Menu.DrawText(x + 20, y + 45, subText, 14, 0.7, 0.7, 0.7, 1.0)
    
    local boxW = width - 40
    local boxH = 30
    local boxX = x + 20
    local boxY = y + 70
    
    if Susano and Susano.DrawRectFilled then
        Susano.DrawRectFilled(boxX - 1, boxY - 1, boxW + 2, boxH + 2, 1.0, 1.0, 1.0, 0.8, 4)
        Susano.DrawRectFilled(boxX, boxY, boxW, boxH, 0.15, 0.15, 0.15, 1.0, 4)
    else
        Menu.DrawRect(boxX, boxY, boxW, boxH, 40, 40, 40, 255)
    end
    
    local displayText = Menu.InputText or ""
    if math.floor(GetGameTimer() / 500) % 2 == 0 then
        displayText = displayText .. "|"
    end
    
    local maxDisplayChars = 30
    if string.len(displayText) > maxDisplayChars then
        displayText = "..." .. string.sub(displayText, -maxDisplayChars)
    end
    
    Menu.DrawText(boxX + 10, boxY + 5, displayText, 16, 1.0, 1.0, 1.0, 1.0)
    
    if Susano and Susano.GetAsyncKeyState then
         if Menu.IsKeyJustPressed(0x0D) then
             Menu.InputOpen = false
             if Menu.InputCallback then
                 Menu.InputCallback(Menu.InputText)
             end
         end
         
         if Menu.IsKeyJustPressed(0x08) then
             if string.len(Menu.InputText) > 0 then
                 Menu.InputText = string.sub(Menu.InputText, 1, -2)
             end
         end
         
         if Menu.IsKeyJustPressed(0x1B) then
             Menu.InputOpen = false
         end
         
         local shiftPressed = false
         if Susano.GetAsyncKeyState(0x10) or Susano.GetAsyncKeyState(0xA0) or Susano.GetAsyncKeyState(0xA1) then
             shiftPressed = true
         end
         
         for i = 0x41, 0x5A do
             if Menu.IsKeyJustPressed(i) then
                 local char = string.char(i)
                 if not shiftPressed then
                     char = string.lower(char)
                 end
                 Menu.InputText = Menu.InputText .. char
             end
         end
         for i = 0x30, 0x39 do
             if Menu.IsKeyJustPressed(i) then
                 Menu.InputText = Menu.InputText .. string.char(i)
             end
         end
         if Menu.IsKeyJustPressed(0x20) then
             Menu.InputText = Menu.InputText .. " "
         end
         if Menu.IsKeyJustPressed(0xBD) then
             if shiftPressed then Menu.InputText = Menu.InputText .. "_" else Menu.InputText = Menu.InputText .. "-" end
         end
    end
end

if Menu.Banner.enabled and Menu.Banner.imageUrl then
    Menu.LoadBannerTexture(Menu.Banner.imageUrl)
end


return Menu
