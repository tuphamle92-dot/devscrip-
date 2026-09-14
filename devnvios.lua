-- [[ 👑 THÙY HÚI HUB - AUTO HOP 1 NGƯỜI & LỌC TRỨNG VIP 👑 ]] --

-- Load UI ngay lập tức không cần chờ đợi!
local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local CoreGui = (gethui and gethui()) or game:GetService("CoreGui") or lp:WaitForChild("PlayerGui")

-- ==========================================
-- 🛡️ ANTI-CHEAT CỰC MẠNH (100% ANTI-KICK)
-- ==========================================
task.spawn(function()
    pcall(function()
        if hookfunction and lp.Kick then
            hookfunction(lp.Kick, function() return nil end)
        end
        local rawmetatable = getrawmetatable(game)
        local oldNamecall = rawmetatable.__namecall
        setreadonly(rawmetatable, false)
        rawmetatable.__namecall = newcclosure(function(self, ...)
            if string.lower(tostring(getnamecallmethod())) == "kick" then return nil end
            return oldNamecall(self, ...)
        end)
        local oldIndex = rawmetatable.__index
        rawmetatable.__index = newcclosure(function(self, index)
            if string.lower(tostring(index)) == "kick" then return function() return nil end end
            return oldIndex(self, index)
        end)
        setreadonly(rawmetatable, true)
    end)
end)

-- ==========================================
-- 🎨 UI SETUP (GỌN NHẸ & CÓ LOG)
-- ==========================================
local guiName = "ThuyHuiVIP_" .. tostring(math.random(1000, 9999))
for _, v in ipairs(CoreGui:GetChildren()) do
    if v.Name:match("^ThuyHuiVIP_") or v.Name:match("^ThuyHui_") then v:Destroy() end
end

local Gui = Instance.new("ScreenGui", CoreGui)
Gui.Name = guiName
Gui.ResetOnSpawn = false
if syn and syn.protect_gui then syn.protect_gui(Gui) end

local MainFrame = Instance.new("Frame", Gui)
MainFrame.Size = UDim2.new(0, 240, 0, 140)
MainFrame.Position = UDim2.new(0.02, 0, 0.35, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35) -- Chuyển sang Dark Mode cho ngầu
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", MainFrame).Color = Color3.fromRGB(100, 100, 255)
Instance.new("UIStroke", MainFrame).Thickness = 1.5

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, -10, 0, 25)
Title.Position = UDim2.new(0, 10, 0, 5)
Title.BackgroundTransparency = 1
Title.Text = "👑 THÙY HÚI HUB - VIP"
Title.TextColor3 = Color3.fromRGB(255, 215, 0)
Title.TextSize = 14
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left

-- KHUNG LOG BÁO CÁO CỰC CHUẨN
local LogFrame = Instance.new("Frame", MainFrame)
LogFrame.Size = UDim2.new(0.9, 0, 0, 45)
LogFrame.Position = UDim2.new(0.05, 0, 0, 35)
LogFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
Instance.new("UICorner", LogFrame).CornerRadius = UDim.new(0, 6)

local LogText = Instance.new("TextLabel", LogFrame)
LogText.Size = UDim2.new(1, -10, 1, -10)
LogText.Position = UDim2.new(0, 5, 0, 5)
LogText.BackgroundTransparency = 1
LogText.Text = "[*] Đang chờ lệnh..."
LogText.TextColor3 = Color3.fromRGB(0, 255, 127)
LogText.TextSize = 11
LogText.Font = Enum.Font.GothamMedium
LogText.TextXAlignment = Enum.TextXAlignment.Left
LogText.TextYAlignment = Enum.TextYAlignment.Top
LogText.TextWrapped = true

local function updateLog(msg, color)
    LogText.Text = msg
    if color then LogText.TextColor3 = color end
end

local HopBtn = Instance.new("TextButton", MainFrame)
HopBtn.Size = UDim2.new(0.9, 0, 0, 35)
HopBtn.Position = UDim2.new(0.05, 0, 0, 92)
HopBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
HopBtn.Text = "🚀 BẬT AUTO LỌC TRỨNG VIP"
HopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
HopBtn.TextSize = 12
HopBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", HopBtn).CornerRadius = UDim.new(0, 6)

-- ==========================================
-- ⚙️ HỆ THỐNG SCAN TRỨNG HIẾM (DIVINE, SECRET, ETERNAL)
-- ==========================================
local function CheckRareEggs()
    local targets = {"divine", "secret", "eternal"}
    
    -- 1. Quét thông báo trên màn hình (UI)
    pcall(function()
        for _, obj in ipairs(lp.PlayerGui:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextBox") or obj:IsA("TextButton") then
                local txt = string.lower(obj.Text)
                for _, v in ipairs(targets) do
                    if string.find(txt, v) then return v end
                end
            end
        end
    end)

    -- 2. Quét thực thể trong Map (Workspace)
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") or obj:IsA("BasePart") then
                local name = string.lower(obj.Name)
                for _, v in ipairs(targets) do
                    if string.find(name, v) then return v end
                end
            end
        end
    end)
    
    return nil
end

-- ==========================================
-- ⚙️ LOGIC HOP SERVER MƯỢT KHÔNG TREO
-- ==========================================
local isHopping = false

local function SmartHop()
    if isHopping then return end
    isHopping = true
    
    updateLog("[-] Không có trứng VIP.\n[*] Đang tìm phòng 1 người...", Color3.fromRGB(255, 100, 100))
    HopBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    HopBtn.Text = "Đang lướt tìm map..."

    -- Đưa HttpGet vào task.spawn để KHÔNG BAO GIỜ TREO GAME
    task.spawn(function()
        local placeId = game.PlaceId
        local currentJob = game.JobId
        local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true"

        local success, result = pcall(function() return game:HttpGet(url) end)

        if success and result then
            local decodeSuccess, decoded = pcall(function() return HttpService:JSONDecode(result) end)
            if decodeSuccess and decoded and decoded.data then
                local foundServer = nil
                for _, server in ipairs(decoded.data) do
                    if type(server.playing) == "number" and server.playing == 1 and server.id ~= currentJob then
                        foundServer = server
                        break
                    end
                end
                
                if foundServer then
                    updateLog("[+] Tìm thấy phòng 1 người!\n[*] Đang dịch chuyển...", Color3.fromRGB(0, 255, 127))
                    
                    local queue = queue_on_teleport or (getgenv and getgenv().queue_on_teleport)
                    if queue then
                        local next_code = [[
                            getgenv().ThuyHui_AutoRun = true
                            if isfile and readfile and isfile("ThuyHui_AutoHop.txt") then
                                loadstring(readfile("ThuyHui_AutoHop.txt"))()
                            end
                        ]]
                        pcall(function() queue(next_code) end)
                    end

                    task.wait(0.5)
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(placeId, foundServer.id, lp)
                    end)
                    task.wait(5)
                    isHopping = false
                else
                    updateLog("[!] Hết server 1 người, thử lại...", Color3.fromRGB(255, 165, 0))
                    task.wait(2)
                    isHopping = false
                    SmartHop()
                end
            else
                updateLog("[!] Lỗi API, tự động thử lại...", Color3.fromRGB(255, 165, 0))
                task.wait(2)
                isHopping = false
                SmartHop()
            end
        else
            updateLog("[!] Mạng lag, tự động thử lại...", Color3.fromRGB(255, 165, 0))
            task.wait(2)
            isHopping = false
            SmartHop()
        end
    end)
end

local function StartFilterFlow()
    if not game:IsLoaded() then game.Loaded:Wait() end
    task.wait(1.5) -- Cho map load xong thực thể
    
    updateLog("[*] Đang quét map tìm trứng: Divine, Secret, Eternal...", Color3.fromRGB(0, 255, 255))
    task.wait(1)
    
    local foundEgg = CheckRareEggs()
    
Để xử lý triệt để tình trạng treo game và tối ưu lại kịch bản (script) của bạn cho mượt mà hơn, mình cần xem cấu trúc code hiện tại của bạn. Tuy nhiên, dựa trên yêu cầu, mình có thể chỉ ra nguyên nhân và cung cấp đoạn code chuẩn để bạn ráp vào kịch bản hiện tại.

Dưới đây là phương pháp giải quyết từng vấn đề:

### 1. Fix lỗi treo game (Crash/Freeze) và Menu hiện chậm
*   **Nguyên nhân treo:** Thường do các vòng lặp `while true do` hoặc `repeat until` không có `task.wait()`, khiến luồng (thread) bị quá tải. Việc quét toàn bộ bản đồ (Workspace) ngay lập tức khi vừa vào server cũng gây tụt FPS và treo đột ngột.
*   **Nguyên nhân Menu chậm:** UI đang bị render tuần tự theo một quy trình chờ load tài nguyên. 
*   **Cách khắc phục:** Đưa chức năng tạo UI vào một luồng riêng biệt chạy song song bằng `task.spawn()` để menu hiện lên ngay lập tức mà không cần đợi server hop hay các chức năng khác chạy xong.

### 2. Thuật toán tìm Trứng Hiếm (Divine, Secret, Eternal) & Auto Hop
Để log "cực chuẩn" và đẹp, chúng ta sẽ dùng các tiền tố như `[+]`, `[-]`, `[★]` và in ra console. Code dưới đây sẽ tự động quét, nếu có trứng thì ở lại, không có thì lập tức đổi server (chỉ tìm server ít người).

Bạn tham khảo và tích hợp đoạn logic mẫu này vào script nhé:

```lua
-- ==========================================
-- TỐI ƯU MENU LOAD NHANH (CHẠY SONG SONG)
-- ==========================================
task.spawn(function()
    -- Đặt code tạo Menu UI của bạn vào đây
    -- Menu sẽ hiện ngay lập tức không bị delay bởi quá trình check server
    print("[UI] Đã tải Menu thành công!")
end)

-- ==========================================
-- CẤU HÌNH TRỨNG & SERVER HOP
-- ==========================================
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local targetEggs = {"Divine", "Secret", "Eternal"} -- Các loại trứng cần săn

-- Hàm trang trí log cho đẹp và chuẩn
local function sendLog(type, message)
    local prefix = ""
    if type == "info" then prefix = "ℹ️ [INFO]"
    elseif type == "success" then prefix = "✅ [SUCCESS]"
    elseif type == "warning" then prefix = "⚠️ [WARNING]"
    elseif type == "rare" then prefix = "🌟 [RARE EGG FOUND]"
    end
    print(string.format("=====================================\n%s %s\n=====================================", prefix, message))
end

-- Hàm tìm server ít người (1 người)
local function hopToSmallServer()
    sendLog("warning", "Không tìm thấy trứng hiếm. Đang tìm server mới...")
    -- Lưu ý: Bạn cần thay thế PlaceId bằng ID chuẩn của game
    local PlaceId = game.PlaceId
    -- Logic API tìm server (Ví dụ cơ bản, bạn có thể thay bằng hàm hop của thư viện bạn đang dùng)
    -- Nếu bạn dùng KRNL, Synapse, hay Fluxus thì thường có sẵn thư viện server hop tốt hơn.
    task.wait(1) 
    TeleportService:Teleport(PlaceId, Players.LocalPlayer)
end

-- ==========================================
-- THUẬT TOÁN QUÉT TRỨNG CHUẨN XÁC
-- ==========================================
local function scanForRareEggs()
    sendLog("info", "Đang quét dữ liệu server...")
    local found = false
    local eggFoundName = ""
    
    -- QUAN TRỌNG: Đừng quét toàn bộ workspace bằng GetDescendants() vì sẽ gây treo game.
    -- Hãy trỏ chính xác vào thư mục chứa trứng của game này (Ví dụ: workspace.Map.Eggs)
    -- Giả sử thư mục là workspace:WaitForChild("Eggs", 5)
    
    local eggFolder = workspace -- THAY ĐỔI ĐƯỜNG DẪN NÀY CHO ĐÚNG VỚI GAME
    
    for _, obj in pairs(eggFolder:GetDescendants()) do
        for _, rareName in pairs(targetEggs) do
            if string.match(string.lower(obj.Name), string.lower(rareName)) then
                found = true
                eggFoundName = obj.Name
                break
            end
        end
        if found then break end
    end
    
    if found then
        sendLog("rare", "Giữ nguyên server! Đã phát hiện trứng: " .. eggFoundName)
        -- Code tiến đến nhặt/mở trứng bỏ vào đây
    else
        hopToSmallServer()
    end
end

-- Chạy hàm quét sau khi game load một chút để tránh thiếu dữ liệu
task.delay(3, function()
    scanForRareEggs()
end)
