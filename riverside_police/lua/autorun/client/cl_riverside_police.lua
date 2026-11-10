-- Изолированная клиентская часть полиции.

if not CLIENT then return end

JobSelector = JobSelector or {}
JobSelector.PermissionCheckers = JobSelector.PermissionCheckers or {}
JobSelector.ExtraTabs = JobSelector.ExtraTabs or {}

local COLOR_TEXT = Color(255, 248, 220)
local COLOR_TEXT_DIM = Color(202, 184, 128)
local COLOR_ACCENT = Color(235, 177, 35, 255)
local COLOR_ACCENT_HOVER = Color(255, 211, 72, 255)
local COLOR_DANGER = Color(120, 55, 60, 255)
local COLOR_DANGER_HOVER = Color(165, 75, 70, 255)

surface.CreateFont("RiversidePolice_Title", { font = "Roboto", size = 26, weight = 700, extended = true })
surface.CreateFont("RiversidePolice_Text", { font = "Roboto", size = 16, weight = 400, extended = true })

local function HoverFrac(panel)
    panel._policeHover = Lerp(FrameTime() * 9, panel._policeHover or 0, panel:IsHovered() and 1 or 0)
    return panel._policeHover
end

local function LerpColor(frac, from, to)
    return Color(Lerp(frac, from.r, to.r), Lerp(frac, from.g, to.g), Lerp(frac, from.b, to.b), Lerp(frac, from.a, to.a))
end

JobSelector.PermissionCheckers.police = function()
    local ply = LocalPlayer()
    return IsValid(ply) and ply:GetNWBool("RiversidePolice_Allowed", false)
end

local whitelistRows = {}
local whitelistList

local function RequestWhitelist()
    net.Start("RiversidePolice_RequestWhitelist")
    net.SendToServer()
end

local function BuildWhitelistRows()
    if not IsValid(whitelistList) then return end
    whitelistList:Clear()

    if #whitelistRows == 0 then
        local empty = vgui.Create("DLabel", whitelistList)
        empty:Dock(TOP)
        empty:SetTall(30)
        empty:SetFont("RiversidePolice_Text")
        empty:SetTextColor(COLOR_TEXT_DIM)
        empty:SetText("Whitelist полиции пока пуст")
        return
    end

    for _, entry in ipairs(whitelistRows) do
        local row = vgui.Create("DPanel", whitelistList)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 8)
        row:SetTall(70)
        row.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(61, 47, 16, 255))
        end

        local label = vgui.Create("DLabel", row)
        label:Dock(FILL)
        label:DockMargin(14, 7, 130, 7)
        label:SetFont("RiversidePolice_Text")
        label:SetTextColor(COLOR_TEXT)
        label:SetWrap(true)
        label:SetText(entry.playerName .. "\nSteamID64: " .. entry.steamid64 .. "\nДобавил: " .. entry.addedBy)

        local remove = vgui.Create("DButton", row)
        remove:Dock(RIGHT)
        remove:DockMargin(8, 14, 8, 14)
        remove:SetWide(110)
        remove:SetText("")
        remove.Paint = function(self, w, h)
            draw.RoundedBox(7, 0, 0, w, h, self:IsHovered() and COLOR_DANGER_HOVER or COLOR_DANGER)
            draw.SimpleText("Удалить", "RiversidePolice_Text", w / 2, h / 2, COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        remove.DoClick = function()
            net.Start("RiversidePolice_RemoveWhitelist")
                net.WriteString(entry.steamid64)
            net.SendToServer()
        end
    end
end

net.Receive("RiversidePolice_Whitelist", function()
    whitelistRows = {}
    local count = net.ReadUInt(16)

    for i = 1, count do
        whitelistRows[#whitelistRows + 1] = {
            steamid64 = net.ReadString(),
            playerName = net.ReadString(),
            addedBy = net.ReadString(),
            addedAt = net.ReadUInt(32),
        }
    end

    BuildWhitelistRows()
end)

net.Receive("RiversidePolice_WhitelistMessage", function()
    local success = net.ReadBool()
    local message = net.ReadString()

    chat.AddText(COLOR_ACCENT, "[Полиция] ", success and Color(150, 255, 160) or Color(255, 130, 130), message)
    if success then RequestWhitelist() end
end)

table.insert(JobSelector.ExtraTabs, {
    id = "police_whitelist",
    label = "Список полиции",
    visible = function()
        local ply = LocalPlayer()
        return IsValid(ply) and ply:GetNWBool("RiversidePolice_CanManageWhitelist", false)
    end,
    build = function(panel)
        local title = vgui.Create("DLabel", panel)
        title:Dock(TOP)
        title:DockMargin(0, 0, 0, 14)
        title:SetTall(34)
        title:SetFont("RiversidePolice_Title")
        title:SetTextColor(COLOR_TEXT)
        title:SetText("Список полиции")

        local help = vgui.Create("DLabel", panel)
        help:Dock(TOP)
        help:DockMargin(0, 0, 0, 12)
        help:SetTall(34)
        help:SetFont("RiversidePolice_Text")
        help:SetTextColor(COLOR_TEXT_DIM)
        help:SetWrap(true)
        help:SetText("Добавляйте и удаляйте игроков по SteamID64. SuperAdmin получает доступ к полиции автоматически.")

        local input = vgui.Create("DTextEntry", panel)
        input:Dock(TOP)
        input:DockMargin(0, 0, 0, 10)
        input:SetTall(38)
        input:SetFont("RiversidePolice_Text")
        input:SetTextColor(COLOR_TEXT)
        input:SetPlaceholderText("SteamID64, например 76561198000000000")

        local add = vgui.Create("DButton", panel)
        add:Dock(TOP)
        add:DockMargin(0, 0, 0, 16)
        add:SetTall(42)
        add:SetText("")
        add.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, LerpColor(HoverFrac(self), COLOR_ACCENT, COLOR_ACCENT_HOVER))
            draw.SimpleText("Добавить в whitelist", "RiversidePolice_Text", w / 2, h / 2, COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        add.DoClick = function()
            local steamID64 = string.Trim(input:GetValue() or "")
            if steamID64 == "" then return end
            net.Start("RiversidePolice_AddWhitelist")
                net.WriteString(steamID64)
            net.SendToServer()
            input:SetText("")
        end

        whitelistList = vgui.Create("DScrollPanel", panel)
        whitelistList:Dock(FILL)
        if JobSelector.StyleScrollbar then JobSelector.StyleScrollbar(whitelistList) end

        RequestWhitelist()
        BuildWhitelistRows()
    end,
})
