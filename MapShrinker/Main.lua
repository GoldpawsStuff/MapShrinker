--[[

	The MIT License (MIT)

	Copyright (c) 2024 Lars Norberg

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
-- Retrive addon folder name, and our local, private namespace.
local Addon, Private = ...

-- Localization system.
-----------------------------------------------------------
-- Do not modify the function,
-- just the locales in the table below!
local L = (function(tbl,defaultLocale)
	local gameLocale = GetLocale() -- The locale currently used by the game client.
	local L = tbl[gameLocale] or tbl[defaultLocale] -- Get the localization for the current locale, or use your default.
	-- Replace the boolean 'true' with the key,
	-- to simplify locale creation and reduce space needed.
	for i in pairs(L) do
		if (L[i] == true) then
			L[i] = i
		end
	end
	-- If the game client is in another locale than your default,
	-- fill in any missing localization in the client's locale
	-- with entries from your default locale.
	if (gameLocale ~= defaultLocale) then
		for i,msg in pairs(tbl[defaultLocale]) do
			if (not L[i]) then
				-- Replace the boolean 'true' with the key,
				-- to simplify locale creation and reduce space needed.
				L[i] = (msg == true) and i or msg
			end
		end
	end
	return L
end)({
	-- ENTER YOUR LOCALIZATION HERE!
	-----------------------------------------------------------
	-- * Note that you MUST include a full table for your primary/default locale!
	-- * Entries where the value (to the right) is the boolean 'true',
	--   will use the key (to the left) as the value instead!
	["enUS"] = {
		-- We're using WoW globals that are localized by the game itself,
		-- so not translations should generally be needed here.
		["Player"] = PLAYER,
		["Mouse"] = MOUSE_LABEL,
		["N/A"] = NOT_APPLICABLE
	},
	["deDE"] = {},
	["esES"] = {},
	["esMX"] = {},
	["frFR"] = {},
	["itIT"] = {},
	["koKR"] = {},
	["ptPT"] = {},
	["ruRU"] = {},
	["zhCN"] = {},
	["zhTW"] = {}

-- The primary/default locale of your addon.
-- * You should change this code to your default locale.
-- * Note that you MUST include a full table for your primary/default locale!
}, "enUS")

-- Lua API
-----------------------------------------------------------
local ipairs = ipairs
local pairs = pairs
local select = select
local string_format = string.format
local string_gsub = string.gsub

-- WoW API
-----------------------------------------------------------
local CreateFrame = CreateFrame
local GetBestMapForUnit = C_Map and C_Map.GetBestMapForUnit
local GetFallbackWorldMapID = C_Map and C_Map.GetFallbackWorldMapID
local GetMapInfo = C_Map and C_Map.GetMapInfo
local GetPlayerMapPosition = C_Map and C_Map.GetPlayerMapPosition
local hooksecurefunc = hooksecurefunc
local InCombatLockdown = InCombatLockdown
local IsAddOnLoaded = IsAddOnLoaded or C_AddOns.IsAddOnLoaded
local UIParent = UIParent

-- Utility Functions
-----------------------------------------------------------
local StripCache = {}
local Strip = function(object)
	local cache = StripCache[object]
	if (not cache) then
		cache = {}
		StripCache[object] = cache
	end
	for i = 1, object:GetNumRegions() do
		local region = select(i, object:GetRegions())
		if (region) and (region:GetObjectType() == "Texture") then
			-- Store this only once.
			if (not cache[region]) then
				cache[region] = region:GetTexture()
			end
			region:SetTexture(nil)
		end
	end
end
local Unstrip = function(object)
	local cache = StripCache[object]
	if (not cache) then
		return
	end
	for i = 1, object:GetNumRegions() do
		local region = select(i, object:GetRegions())
		if (region) and (region:GetObjectType() == "Texture") then
			if (cache[region]) then
				region:SetTexture(cache[region])
			end
		end
	end
end

local GetFormattedCoordinates = function(x, y)
	return 	string_gsub(string_format("|cfff0f0f0%.2f|r", x*100), "%.(.+)", "|cffa0a0a0.%1|r"),
			string_gsub(string_format("|cfff0f0f0%.2f|r", y*100), "%.(.+)", "|cffa0a0a0.%1|r")
end

local CalculateScale = function()
	local min, max = 0.65, 0.95 -- our own scale limits
	local uiMin, uiMax = 0.65, 1.15 -- blizzard uiScale slider limits
	local uiScale = UIParent:GetEffectiveScale() -- current blizzard uiScale
	-- Calculate and return a relative scale
	-- that is user adjustable through graphics settings,
	-- but still keeps itself within our intended limits.
	if (uiScale < uiMin) then
		return min
	elseif (uiScale > uiMax) then
		return max
	else
		return ((uiScale - uiMin) / (uiMax - uiMin)) * (max - min) + min
	end
end


-- Callbacks
-----------------------------------------------------------
local Coords_OnUpdate = function(self, elapsed)
	self.elapsed = self.elapsed + elapsed
	if (self.elapsed < .02) then
		return
	end
	local pX, pY, cX, cY
	local mapID = GetBestMapForUnit("player")
	if (mapID) then
		local mapPosObject = GetPlayerMapPosition(mapID, "player")
		if (mapPosObject) then
			pX, pY = mapPosObject:GetXY()
		end
	end
	if (WorldMapFrame.ScrollContainer:IsMouseOver()) then
		cX, cY = WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()
	end
	if ((pX) and (pY) and (pX > 0) and (pY > 0)) then
		self.Player:SetFormattedText("%s:|r   %s, %s", L["Player"], GetFormattedCoordinates(pX, pY))
	else
		self.Player:SetText(" ")
	end
	if ((cX) and (cY) and (cX > 0) and (cY > 0) and (cX < 100) and (cY < 100)) then
		self.Cursor:SetFormattedText("%s:|r   %s, %s", L["Mouse"], GetFormattedCoordinates(cX, cY))
	else
		self.Cursor:SetText(" ")
	end
	self.elapsed = 0
end

local WorldMapFrame_Maximize = function()
	local WorldMapFrame = WorldMapFrame
	WorldMapFrame:SetParent(UIParent)
	WorldMapFrame:SetScale(1)

	if (WorldMapFrame:GetAttribute("UIPanelLayout-area") ~= "center") then
		SetUIPanelAttribute(WorldMapFrame, "area", "center")
	end

	if (WorldMapFrame:GetAttribute("UIPanelLayout-allowOtherPanels") ~= true) then
		SetUIPanelAttribute(WorldMapFrame, "allowOtherPanels", true)
	end

	WorldMapFrame:OnFrameSizeChanged()

	WorldMapFrame.NavBar:Hide()
	WorldMapFrame.BorderFrame:SetAlpha(0)
	WorldMapFrameBg:Hide()

	WorldMapFrameCloseButton:ClearAllPoints()
	WorldMapFrameCloseButton:SetPoint("TOPLEFT", 4, -70)

	WorldMapFrame.MapShrinkerBackdrop:Show()
	WorldMapFrame.MapShrinkerBorder:Show()
	WorldMapFrame.MapShrinkerCoords:Show()
end

local WorldMapFrame_Minimize = function()
	local WorldMapFrame = WorldMapFrame
	if (not WorldMapFrame:IsMaximized()) then
		WorldMapFrame:ClearAllPoints()
		WorldMapFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -94)

		WorldMapFrame.NavBar:Show()
		WorldMapFrame.BorderFrame:SetAlpha(1)
		WorldMapFrameBg:Show()

		WorldMapFrameCloseButton:ClearAllPoints()
		WorldMapFrameCloseButton:SetPoint("TOPRIGHT", 5, 5)

		--WorldMapFrame_UnstripOverlays()

		WorldMapFrame.MapShrinkerBackdrop:Hide()
		WorldMapFrame.MapShrinkerBorder:Hide()
		WorldMapFrame.MapShrinkerCoords:Hide()
	end
end

local WorldMapFrame_SyncState = function()
	local WorldMapFrame = WorldMapFrame
	if (WorldMapFrame:IsMaximized()) then
		WorldMapFrame:ClearAllPoints()
		WorldMapFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
	end
end

local WorldMapFrame_UpdateMaximizedSize = function()
	local WorldMapFrame = WorldMapFrame
	local width, height = WorldMapFrame:GetSize()
	local scale = CalculateScale()
	local magicNumber = (1 - scale) * 100
	WorldMapFrame:SetSize((width * scale) - (magicNumber + 2), (height * scale) - 2)

	-- This fails in Dragonflight at startup,
	-- uncertain what events or methods to safely call it after.
	if (Private.ClientMajor < 10) then
		WorldMapFrame:OnCanvasSizeChanged()
	end
end


-- Addon API
-----------------------------------------------------------
-- Custom check to see if we can run this addon at all.
Private.IsIncompatible = function(self)
	if (not self.IsRetail) then
		return true
	end
	for _,addon in ipairs({ "ElvUI", "KkthnxUI", "SpartanUI", "TukUI" }) do
		if (self:IsAddOnEnabled(addon)) then
			return true
		end
	end
end

Private.CreateCoordinates = function(self)
	local WorldMapFrame = WorldMapFrame
	if (not WorldMapFrame) then
		return
	end

	local coords = CreateFrame("Frame", nil, WorldMapFrame)
	coords:SetFrameStrata(WorldMapFrame.BorderFrame:GetFrameStrata())
	coords:SetFrameLevel(WorldMapFrame.BorderFrame:GetFrameLevel() + 10)
	coords.elapsed = 0
	WorldMapFrame.MapShrinkerCoords = coords

	local player = coords:CreateFontString()
	player:SetFontObject(NumberFont_Shadow_Med)
	player:SetFont(player:GetFont(), 14, "THINOUTLINE")
	player:SetShadowColor(0,0,0,0)
	player:SetTextColor(255/255, 234/255, 137/255)
	player:SetAlpha(.85)
	player:SetDrawLayer("OVERLAY")
	player:SetJustifyH("LEFT")
	player:SetJustifyV("BOTTOM")
	player:SetPoint("BOTTOMLEFT", WorldMapFrame.MapShrinkerBorder, "TOPLEFT", 32, -16)

	local cursor = coords:CreateFontString()
	cursor:SetFontObject(NumberFont_Shadow_Med)
	cursor:SetFont(cursor:GetFont(), 14, "THINOUTLINE")
	cursor:SetShadowColor(0,0,0,0)
	cursor:SetTextColor(255/255, 234/255, 137/255)
	cursor:SetAlpha(.85)
	cursor:SetDrawLayer("OVERLAY")
	cursor:SetJustifyH("RIGHT")
	cursor:SetJustifyV("BOTTOM")
	cursor:SetPoint("BOTTOMRIGHT", WorldMapFrame.MapShrinkerBorder, "TOPRIGHT", -32, -16)

	coords.Player = player
	coords.Cursor = cursor
	coords:SetScript("OnUpdate", Coords_OnUpdate)
end

Private.StyleWorldMap = function(self)

	local backdrop = CreateFrame("Frame", nil, WorldMapFrame, BackdropTemplateMixin and "BackdropTemplate")
	backdrop:Hide()
	backdrop:SetFrameLevel(WorldMapFrame:GetFrameLevel())
	backdrop:SetPoint("TOP", 0, 25-66)
	backdrop:SetPoint("LEFT", -25, 0)
	backdrop:SetPoint("BOTTOM", 0, -25)
	backdrop:SetPoint("RIGHT", 25, 0)
	backdrop:SetBackdrop({ bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], insets = { left = 25, right = 25, top = 25, bottom = 25 }})
	backdrop:SetBackdropColor(0, 0, 0, .95)

	local border = CreateFrame("Frame", nil, WorldMapFrame, BackdropTemplateMixin and "BackdropTemplate")
	border:Hide()
	border:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 10)
	border:SetAllPoints(backdrop)
	border:SetBackdrop({ edgeSize = 32, edgeFile = self:GetMedia("better-blizzard-border-small-alternate") })
	border:SetBackdropBorderColor(.35, .35, .35, 1)

	WorldMapFrame.MapShrinkerBackdrop = backdrop
	WorldMapFrame.MapShrinkerBorder = border

	WorldMapFrame:EnableMouse(false)

	WorldMapFrame.BlackoutFrame.Blackout:SetTexture(nil)
	WorldMapFrame.BlackoutFrame:EnableMouse(false)
	WorldMapFrame.BorderFrame.MaximizeMinimizeFrame.MinimizeButton:SetParent(Private.UIHider)

	for index,button in pairs(WorldMapFrame.overlayFrames) do
		if (type(button) == "table") then
			if (button.Icon) then
				local texture = button.Icon:GetTexture()
				if (texture) then
					button.Border:SetAlpha(0)
					button.Background:SetAlpha(0)
				else
					for i = 1, button:GetNumRegions() do
						local region = select(i, button:GetRegions())
						if (region and region:GetObjectType() == "Texture") then
							region:SetTexture(nil)
						end
					end
					if (button.Button) then
						button.Button:Hide()
					end
					if (button.Text) then
						button.Text:Hide()
					end
				end
			end
		end
	end

end

Private.SetUpMap = function(self)
	if (self.Styled) then
		return
	end

	self:StyleWorldMap()
	self:CreateCoordinates()

	SetCVar("miniWorldMap", 0)

	hooksecurefunc(WorldMapFrame, "Maximize", WorldMapFrame_Maximize)
	hooksecurefunc(WorldMapFrame, "Minimize", WorldMapFrame_Minimize)
	hooksecurefunc(WorldMapFrame, "SynchronizeDisplayState", WorldMapFrame_SyncState)
	hooksecurefunc(WorldMapFrame, "UpdateMaximizedSize", WorldMapFrame_UpdateMaximizedSize)

	-- Button removed in WoW Retail 11.0.0.
	if (WorldMapFrameButton) then
		WorldMapFrameButton:UnregisterAllEvents()
		WorldMapFrameButton:SetParent(Private.UIHider)
		WorldMapFrameButton:Hide()
	end

	if (WorldMapFrame:IsMaximized()) then
		WorldMapFrame_UpdateMaximizedSize()
		WorldMapFrame_Maximize()
	end

	self.Styled = true
end

-- Addon Core
-----------------------------------------------------------
-- Your event handler.
-- Any events you add should be handled here.
-- @input event <string> The name of the event that fired.
-- @input ... <misc> Any payloads passed by the event handlers.
Private.OnEvent = function(self, event, ...)
	if (event == "ADDON_LOADED") then
		local addon = ...
		if (addon == "Blizzard_WorldMap") then
			self:SetUpMap()
			self:UnregisterEvent("ADDON_LOADED")
		end
	elseif (event == "PLAYER_ENTERING_WORLD") then
		self.inWorld = true
	end
end

-- Initialization.
-- This fires when the addon and its settings are loaded.
Private.OnInit = function(self)
	if (self:IsIncompatible()) then
		return
	end

	-- Tell the environment what subfolder to find our media in.
	self:SetMediaPath("Media")

	-- Create a frame to hide UI elements with.
	self.UIHider = CreateFrame("Frame", nil, UIParent)
	self.UIHider:SetAllPoints()
	self.UIHider:Hide()
end

-- Enabling.
-- This fires when most of the user interface has been loaded
-- and most data is available to the user.
Private.OnEnable = function(self)
	if (self:IsIncompatible()) then
		return
	end
	if (IsAddOnLoaded("Blizzard_WorldMap")) then
		self:SetUpMap()
	else
		self:RegisterEvent("ADDON_LOADED")
	end
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
end


-- Setup the environment
-----------------------------------------------------------
(function(self)
	-- Private Default API
	-- This mostly contains methods we always want available
	-----------------------------------------------------------
	local currentClientPatch, currentClientBuild = GetBuildInfo()
	currentClientBuild = tonumber(currentClientBuild)

	-- Let's create some constants for faster lookups
	local MAJOR,MINOR,PATCH = string.split(".", currentClientPatch)

	-- WoW 11.0.x
	local GetAddOnEnableState = GetAddOnEnableState or function(character, name) return C_AddOns.GetAddOnEnableState(name, character) end
	local GetAddOnInfo = GetAddOnInfo or C_AddOns.GetAddOnInfo
	local GetNumAddOns = GetNumAddOns or C_AddOns.GetNumAddOns

	-- These are defined in FrameXML/BNet.lua
	-- *Using blizzard constants if they exist,
	-- using string parsing as a fallback.
	Private.IsRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)

	-- Store major, minor and build.
	Private.ClientMajor = tonumber(MAJOR)
	Private.ClientMinor = tonumber(MINOR)
	Private.ClientBuild = currentClientBuild

	-- Set a relative subpath to look for media files in.
	local Path
	Private.SetMediaPath = function(self, path)
		Path = path
	end

	-- Simple API calls to retrieve a media file.
	-- Will honor the relativ subpath set above, if defined,
	-- and will default to the addon folder itself if not.
	-- Note that we cannot check for file or folder existence
	-- from within the WoW API, so you must make sure this is correct.
	Private.GetMedia = function(self, name, type)
		if (Path) then
			return ([[Interface\AddOns\%s\%s\%s.%s]]):format(Addon, Path, name, type or "tga")
		else
			return ([[Interface\AddOns\%s\%s.%s]]):format(Addon, name, type or "tga")
		end
	end

	-- Parse chat input arguments
	local parse = function(msg)
		msg = string.gsub(msg, "^%s+", "") -- Remove spaces at the start.
		msg = string.gsub(msg, "%s+$", "") -- Remove spaces at the end.
		msg = string.gsub(msg, "%s+", " ") -- Replace all space characters with single spaces.
		if (string.find(msg, "%s")) then
			return string.split(" ", msg) -- If multiple arguments exist, split them into separate return values.
		else
			return msg
		end
	end

	-- This methods lets you register a chat command, and a callback function or private method name.
	-- Your callback will be called as callback(Private, editBox, commandName, ...) where (...) are all the input parameters.
	Private.RegisterChatCommand = function(_, command, callback)
		command = string.gsub(command, "^\\", "") -- Remove any backslash at the start.
		command = string.lower(command) -- Make it lowercase, keep it case-insensitive.
		local name = string.upper(Addon.."_CHATCOMMAND_"..command) -- Create a unique uppercase name for the command.
		_G["SLASH_"..name.."1"] = "/"..command -- Register the chat command, keeping it lowercase.
		SlashCmdList[name] = function(msg, editBox)
			local func = Private[callback] or Private.OnChatCommand or callback
			if (func) then
				func(Private, editBox, command, parse(string.lower(msg)))
			end
		end
	end

	Private.GetAddOnInfo = function(self, index)
		local name, title, notes, loadable, reason, security, newVersion = GetAddOnInfo(index)
		local enabled = not(GetAddOnEnableState(UnitName("player"), index) == 0)
		return name, title, notes, enabled, loadable, reason, security
	end

	-- Check if an addon exists in the addon listing and loadable on demand
	Private.IsAddOnLoadable = function(self, target, ignoreLoD)
		local target = string.lower(target)
		for i = 1,GetNumAddOns() do
			local name, title, notes, enabled, loadable, reason, security = self:GetAddOnInfo(i)
			if string.lower(name) == target then
				if loadable or ignoreLoD then
					return true
				end
			end
		end
	end

	-- This method lets you check if an addon WILL be loaded regardless of whether or not it currently is.
	-- This is useful if you want to check if an addon interacting with yours is enabled.
	-- My philosophy is that it's best to avoid addon dependencies in the toc file,
	-- unless your addon is a plugin to another addon, that is.
	Private.IsAddOnEnabled = function(self, target)
		local target = string.lower(target)
		for i = 1,GetNumAddOns() do
			local name, title, notes, enabled, loadable, reason, security = self:GetAddOnInfo(i)
			if string.lower(name) == target then
				if enabled and loadable then
					return true
				end
			end
		end
	end

	-- Event API
	-----------------------------------------------------------
	-- Proxy event registering to the addon namespace.
	-- The 'self' within these should refer to our proxy frame,
	-- which has been passed to this environment method as the 'self'.
	Private.RegisterEvent = function(_, ...) self:RegisterEvent(...) end
	Private.RegisterUnitEvent = function(_, ...) self:RegisterUnitEvent(...) end
	Private.UnregisterEvent = function(_, ...) self:UnregisterEvent(...) end
	Private.UnregisterAllEvents = function(_, ...) self:UnregisterAllEvents(...) end
	Private.IsEventRegistered = function(_, ...) self:IsEventRegistered(...) end

	-- Event Dispatcher and Initialization Handler
	-----------------------------------------------------------
	-- Assign our event script handler,
	-- which runs our initialization methods,
	-- and dispatches event to the addon namespace.
	self:RegisterEvent("ADDON_LOADED")
	self:SetScript("OnEvent", function(self, event, ...)
		if (event == "ADDON_LOADED") then
			-- Nothing happens before this has fired for your addon.
			-- When it fires, we remove the event listener
			-- and call our initialization method.
			if ((...) == Addon) then
				-- Delete our initial registration of this event.
				-- Note that you are free to re-register it in any of the
				-- addon namespace methods.
				self:UnregisterEvent("ADDON_LOADED")
				-- Call the initialization method.
				if (Private.OnInit) then
					Private:OnInit()
				end
				-- If this was a load-on-demand addon,
				-- then we might be logged in already.
				-- If that is the case, directly run
				-- the enabling method.
				if (IsLoggedIn()) then
					if (Private.OnEnable) then
						Private:OnEnable()
					end
				else
					-- If this is a regular always-load addon,
					-- we're not yet logged in, and must listen for this.
					self:RegisterEvent("PLAYER_LOGIN")
				end
				-- Return. We do not wish to forward the loading event
				-- for our own addon to the namespace event handler.
				-- That is what the initialization method exists for.
				return
			end
		elseif (event == "PLAYER_LOGIN") then
			-- This event only ever fires once on a reload,
			-- and anything you wish done at this event,
			-- should be put in the namespace enable method.
			self:UnregisterEvent("PLAYER_LOGIN")
			-- Call the enabling method.
			if (Private.OnEnable) then
				Private:OnEnable()
			end
			-- Return. We do not wish to forward this
			-- to the namespace event handler.
			return
		end
		-- Forward other events than our two initialization events
		-- to the addon namespace's event handler.
		-- Note that you can always register more ADDON_LOADED
		-- if you wish to listen for other addons loading.
		if (Private.OnEvent) then
			Private:OnEvent(event, ...)
		end
	end)
end)((function() return CreateFrame("Frame", nil, WorldFrame) end)())
