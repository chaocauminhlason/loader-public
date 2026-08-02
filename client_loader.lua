-- ====================================================================
-- E-CLIENT SECURE CLIENT LOADER
-- VERSION: 2.0 - BACKEND PAYLOAD DECRYPTION & ANTI-HOOKING
-- ====================================================================
local ggenv = (type(getgenv) == "function" and getgenv()) or _G
if ggenv.EClientSecureRunning then
    warn("⏳ E-Client đã được tải và đang hoạt động trong bộ nhớ!")
    return
end
ggenv.EClientSecureRunning = true

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RbxAnalyticsService = game:GetService("RbxAnalyticsService")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- --------------------------------------------------------------------
-- CONFIG LOADER SERVER URL
-- --------------------------------------------------------------------
-- Đổi URL dưới đây thành domain Server Vercel/Render/Local của bạn
local BACKEND_SERVER_URL = getgenv().EClientBackendUrl or "https://web-production-92e0f.up.railway.app/api/v1/load-script"
local KEY_FILE = "key_cache.txt"

-- --------------------------------------------------------------------
-- 1. HÀM TẠO HWID DUY NHẤT VÀ CHÍNH XÁC
-- --------------------------------------------------------------------
local rawHwid = gethwid
local function GetClientHWID()
    if type(rawHwid) == "function" then
        local ok, val = pcall(rawHwid)
        if ok and val and #tostring(val) > 0 then return tostring(val) end
    elseif type(rawHwid) == "string" and #rawHwid > 0 then
        return rawHwid
    end
    return tostring(player.UserId)
end

local function lDigest(input)
    local str = tostring(input)
    local hex = {}
    for i = 1, #str do
        table.insert(hex, string.format("%02x", string.byte(str, i)))
    end
    return table.concat(hex)
end

local function GetPlatoboostKeyLink()
    local hwid = GetClientHWID()
    local fRequest = request or http_request or (http and http.request) or (syn and syn.request) or (fluxus and fluxus.request)
    
    if fRequest then
        local hosts = {
            "https://api.platoboost.com",
            "https://api.platoboost.net",
            "https://corsproxy.io/?https://api.platoboost.com"
        }
        
        local bodyData = HttpService:JSONEncode({
            service = 27272,
            identifier = lDigest(hwid)
        })
        
        for _, host in ipairs(hosts) do
            local success, response = pcall(function()
                return fRequest({
                    Url = host .. "/public/start",
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = bodyData
                })
            end)
            
            if success and response and (response.StatusCode == 200 or response.StatusCode == 429) then
                local decodeOk, result = pcall(function() return HttpService:JSONDecode(response.Body) end)
                if decodeOk and result and result.success and result.data and result.data.url then
                    return result.data.url
                end
            end
        end
    end
    
    -- Fallback link khi Platoboost API gián đoạn
    return "https://loot-link.com/s?n1B65oYM"
end

-- --------------------------------------------------------------------
-- 2. HÀM CHỐNG HOOKING VÀ ANTI-HTTPSPY (ANTI-FETCH & ANTI-DUMP)
-- --------------------------------------------------------------------
local function DisableHttpSpy()
    -- Vô hiệu hóa hoặc phát hiện các công cụ HttpSpy / SimpleSpy phổ biến trong RAM
    pcall(function()
        if _G.HttpSpy or _G.SimpleSpy or _G.HydroSpy then
            player:Kick("❌ Phát hiện công cụ HttpSpy / Dump Code!")
        end
        if getgenv then
            getgenv().decompile = function() return "-- Decompile disabled by Anti-Fetch" end
            getgenv().saveinstance = function() return false end
        end
    end)
end

local function VerifyEnvironment()
    DisableHttpSpy()
    return true
end

-- Hàm tạo SHA256 Signature Token tại phía Client bằng thuật toán Luau thuần
local function GenerateClientToken(hwid, key, timestamp)
    local rawSig = hwid .. ":" .. key .. ":" .. tostring(timestamp) .. ":ECLIENT_SECRET_SALT_2026"
    
    -- Nếu Executor hỗ trợ crypt.sha256
    if type(crypt) == "table" and type(crypt.sha256) == "function" then
        return crypt.sha256(rawSig)
    end
    
    -- Fallback SHA256 Luau implementation
    local K = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    }
    local function ror(x, n) return bit32.bor(bit32.rshift(x, n), bit32.lshift(x, 32 - n)) end
    
    local msg = rawSig
    local len = #msg
    local bytes = {}
    for i = 1, len do table.insert(bytes, string.byte(msg, i)) end
    table.insert(bytes, 0x80)
    while (#bytes % 64) ~= 56 do table.insert(bytes, 0x00) end
    
    local bitLen = len * 8
    for i = 7, 0, -1 do
        table.insert(bytes, bit32.band(bit32.rshift(bitLen, i * 8), 0xFF))
    end
    
    local H = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 }
    
    for i = 1, #bytes, 64 do
        local W = {}
        for j = 0, 15 do
            W[j + 1] = bit32.bor(
                bit32.lshift(bytes[i + j*4], 24),
                bit32.lshift(bytes[i + j*4 + 1], 16),
                bit32.lshift(bytes[i + j*4 + 2], 8),
                bytes[i + j*4 + 3]
            )
        end
        for j = 16, 63 do
            local s0 = bit32.bxor(ror(W[j - 15 + 1], 7), ror(W[j - 15 + 1], 18), bit32.rshift(W[j - 15 + 1], 3))
            local s1 = bit32.bxor(ror(W[j - 2 + 1], 17), ror(W[j - 2 + 1], 19), bit32.rshift(W[j - 2 + 1], 10))
            W[j + 1] = bit32.band(W[j - 16 + 1] + s0 + W[j - 7 + 1] + s1, 0xFFFFFFFF)
        end
        local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
        for j = 0, 63 do
            local S1 = bit32.bxor(ror(e, 6), ror(e, 11), ror(e, 25))
            local ch = bit32.bxor(bit32.band(e, f), bit32.band(bit32.bnot(e), g))
            local temp1 = bit32.band(h + S1 + ch + K[j + 1] + W[j + 1], 0xFFFFFFFF)
            local S0 = bit32.bxor(ror(a, 2), ror(a, 13), ror(a, 22))
            local maj = bit32.bxor(bit32.band(a, b), bit32.band(a, c), bit32.band(b, c))
            local temp2 = bit32.band(S0 + maj, 0xFFFFFFFF)
            h, g, f, e = g, f, e, bit32.band(d + temp1, 0xFFFFFFFF)
            d, c, b, a = c, b, a, bit32.band(temp1 + temp2, 0xFFFFFFFF)
        end
        H[1] = bit32.band(H[1] + a, 0xFFFFFFFF)
        H[2] = bit32.band(H[2] + b, 0xFFFFFFFF)
        H[3] = bit32.band(H[3] + c, 0xFFFFFFFF)
        H[4] = bit32.band(H[4] + d, 0xFFFFFFFF)
        H[5] = bit32.band(H[5] + e, 0xFFFFFFFF)
        H[6] = bit32.band(H[6] + f, 0xFFFFFFFF)
        H[7] = bit32.band(H[7] + g, 0xFFFFFFFF)
        H[8] = bit32.band(H[8] + h, 0xFFFFFFFF)
    end
    
    local hex = {}
    for i = 1, 8 do table.insert(hex, string.format("%08x", H[i])) end
    return table.concat(hex)
end

-- --------------------------------------------------------------------
-- 3. HÀM TẢI PAYLOAD MÃ HÓA TỪ BACKEND SERVER
-- --------------------------------------------------------------------
local function ExecuteSecurePayload(userKey)
    if not VerifyEnvironment() then
        player:Kick("❌ Phát hiện can thiệp môi trường (Hooking/HttpSpy Detected)!")
        return false, "Environment Hooked"
    end

    local hwid = GetClientHWID()
    local fRequest = request or http_request or (http and http.request) or (syn and syn.request) or (fluxus and fluxus.request)
    
    if not fRequest then
        warn("❌ Executor của bạn không hỗ trợ HTTP Request!")
        return false, "Executor unsupported"
    end

    local timestamp = os.time()
    local token = GenerateClientToken(hwid, userKey, timestamp)

    local requestBody = HttpService:JSONEncode({
        key = userKey,
        hwid = hwid,
        place_id = game.PlaceId,
        job_id = game.JobId,
        timestamp = timestamp,
        token = token
    })

    local response = fRequest({
        Url = BACKEND_SERVER_URL,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = requestBody
    })

    if response and response.StatusCode == 200 then
        local decodeOk, result = pcall(function() return HttpService:JSONDecode(response.Body) end)
        if decodeOk and result and result.success and result.payload then
            print("🔒 Đã nhận Payload mã hóa thành công từ Server. Đang khởi chạy...")
            local execFunc, execErr = loadstring(result.payload)
            if execFunc then
                execFunc()
                return true
            else
                warn("❌ Lỗi cú pháp trong Payload mã hóa:", execErr)
                return false, execErr
            end
        end
    else
        local errMsg = "Server Error (" .. tostring(response and response.StatusCode) .. ")"
        pcall(function()
            local decoded = HttpService:JSONDecode(response.Body)
            if decoded and (decoded.detail or decoded.message) then
                errMsg = tostring(decoded.detail or decoded.message)
            end
        end)
        warn("❌ Secure Loader Error:", errMsg)
        return false, errMsg
    end
end

-- --------------------------------------------------------------------
-- 4. GIAO DIỆN RAYFIELD KEY SYSTEM UI
-- --------------------------------------------------------------------
local function ShowKeySystemUI(errorMessage)
    local Rayfield = loadstring(game:HttpGet('https://sirius.menu/gen2'))()
    
    local KeyWindow = Rayfield:CreateWindow({
        Name = "E-Client Pro | Key System",
        LoadingTitle = "Checking Authorization...",
        LoadingSubtitle = "by Antigravity & Son",
        ConfigurationSaving = { Enabled = false },
        KeySystem = false
    })

    local KeyTab = KeyWindow:CreateTab({
        Name = "Key Verification",
        Icon = "rbxassetid://10723346959"
    })

    local function NotifyUser(title, content, duration)
        pcall(function()
            if Rayfield and type(Rayfield.Notify) == "function" then
                Rayfield:Notify({ Title = title, Content = content, Duration = duration or 4 })
            else
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = title,
                    Text = content,
                    Duration = duration or 4
                })
            end
        end)
    end

    KeyTab:CreateSection({ Name = "🔑 XÁC THỰC KEY SYSTEM" })

    if errorMessage then
        KeyTab:CreateParagraph({
            Title = "⚠️ Thông báo lỗi",
            Content = errorMessage
        })
    end

    local enteredKey = ""
    
    -- Tự động lấy Key từ khay nhớ tạm nếu có
    pcall(function()
        if getclipboard then
            local clip = getclipboard()
            if clip and type(clip) == "string" and (clip:find("KEY_") or clip:find("VIP_")) then
                enteredKey = string.gsub(clip, "^%s*(.-)%s*$", "%1")
            end
        end
    end)

    local keyInputObj = KeyTab:CreateInput({
        Name = "Dán Key của bạn vào đây",
        PlaceholderText = "Nhập hoặc dán Key tại đây...",
        CurrentValue = enteredKey,
        RemoveTextOnFocus = false,
        Callback = function(text)
            enteredKey = string.gsub(text, "^%s*(.-)%s*$", "%1")
        end
    })

    KeyTab:CreateButton({
        Name = "🚀 Xác Thực Key (Verify Key)",
        Callback = function()
            local targetKey = enteredKey
            if (not targetKey or #targetKey == 0) and keyInputObj then
                if type(keyInputObj.CurrentValue) == "string" and #keyInputObj.CurrentValue > 0 then
                    targetKey = keyInputObj.CurrentValue
                end
            end

            if not targetKey or #targetKey == 0 then
                NotifyUser("Lỗi Xác Thực", "Vui lòng nhập Key trước khi nhấn Xác thực!", 4)
                return
            end

            targetKey = string.gsub(targetKey, "^%s*(.-)%s*$", "%1")

            NotifyUser("Đang kiểm tra Key...", "Đang kết nối tới Backend Server...", 3)

            local success, err = ExecuteSecurePayload(targetKey)
            if success then
                if writefile then
                    pcall(function() writefile(KEY_FILE, targetKey) end)
                end
                NotifyUser("✅ Thành Công!", "Key hợp lệ! Đang khởi chạy E-Client...", 3)
                task.wait(1)
                pcall(function() KeyWindow:Destroy() end)
            else
                NotifyUser("❌ Thất Bại", "Key hoặc HWID không hợp lệ: " .. tostring(err), 5)
            end
        end
    })

    KeyTab:CreateSection({ Name = "🌐 LẤY KEY VÀ HỖ TRỢ" })

    KeyTab:CreateButton({
        Name = "🔑 Lấy Link Key Platoboost (Copy Link)",
        Callback = function()
            NotifyUser("⏳ Đang tạo Link Key...", "Đang kết nối tới Platoboost...", 2)
            task.spawn(function()
                local keyLink = GetPlatoboostKeyLink()
                if setclipboard then
                    setclipboard(keyLink)
                    NotifyUser("📋 Đã Copy Link Key!", "Link Platoboost đã được copy vào khay nhớ tạm. Hãy dán vào trình duyệt!", 5)
                else
                    NotifyUser("Link Lấy Key", keyLink, 8)
                end
            end)
        end
    })

    KeyTab:CreateButton({
        Name = "💬 Tham Gia Discord Hỗ Trợ",
        Callback = function()
            local discordLink = "https://discord.gg/PqBwSpQhz"
            if setclipboard then
                setclipboard(discordLink)
                NotifyUser("📋 Đã Copy Discord!", "Link Discord đã copy vào khay nhớ tạm!", 5)
            end
        end
    })
end

-- Tự động kiểm tra Key trong cache hoặc hiển thị UI Nhập Key
task.spawn(function()
    local hasValidCache = false
    if isfile and isfile(KEY_FILE) then
        local cachedKey = readfile(KEY_FILE)
        if cachedKey and #cachedKey > 0 then
            cachedKey = string.gsub(cachedKey, "^%s*(.-)%s*$", "%1")
            local success = ExecuteSecurePayload(cachedKey)
            if success then
                hasValidCache = true
            end
        end
    end

    if not hasValidCache then
        ShowKeySystemUI()
    end
end)

_G.ExecuteSecurePayload = ExecuteSecurePayload
return ExecuteSecurePayload
