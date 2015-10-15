-----------------------------------------------------------------------------------------------
-- Client Lua Script for RandomMount
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- RandomMount Module Definition
-----------------------------------------------------------------------------------------------
local RandomMount = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
local kcrSelectedText = ApolloColor.new("UI_BtnTextHoloPressedFlyby")
local kcrNormalText = ApolloColor.new("UI_BtnTextHoloNormal")
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function RandomMount:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	o.tItems = {} -- keep track of all the list items
	o.wndSelectedListItem = nil -- keep track of which list item is currently selected

    return o
end

function RandomMount:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- RandomMount OnLoad
-----------------------------------------------------------------------------------------------
function RandomMount:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("RandomMount.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- RandomMount OnDocLoaded
-----------------------------------------------------------------------------------------------
function RandomMount:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "RandomMountForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
		-- item list
		self.wndItemList = self.wndMain:FindChild("ItemList")
	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("randommount", "OnRandomMountOn", self)
		Apollo.RegisterEventHandler("Mount", "OnMount", self)

		-- Do additional Addon initialization here
		--apply savedSettings to current settings

		self.settings = {
		    enabled = true,
			knownMounts = {}
		}
		
		self.settings = RandomMount:ShallowCopy(self.savedSettings)
		self.savedSettings = nil
	end
end

-----------------------------------------------------------------------------------------------
-- RandomMount Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here
function RandomMount:ShallowCopy(t)
  local t2 = {}
  for k,v in pairs(t) do
    t2[k] = v
  end
  return t2
end

-- on SlashCommand "/randommount"
function RandomMount:OnRandomMountOn()
	self.wndMain:Invoke() -- show the window
	--save previous known mount settings
	self.currentSettings = RandomMount:ShallowCopy(self.settings)
		
	self:SetupMainForm()	
end


-----------------------------------------------------------------------------------------------
-- RandomMountForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function RandomMount:SetupMainForm()

	local EnabledButton  = self.wndMain:FindChild("EnabledButton")
	
	if EnabledButton ~= nil then
		EnabledButton:SetCheck(self.settings.enabled)
	end
	
	-- populate the item list
	self:PopulateItemList()
end


function RandomMount:OnOK()
	self.currentSettings= nil
	self.wndMain:Close() -- hide the window
end

-- when the Cancel button is clicked
function RandomMount:OnCancel()
	self.wndMain:Close() -- hide the window
end

--if canceled, escaped, or closed, restore previous settings
function RandomMount:RestorePreviousSettings()
	self.settings = RandomMount:ShallowCopy(self.currentSettings)
	self.currentSettings = nil
	
end


function RandomMount:ToggleRandomization( wndHandler, wndControl, eMouseButton )
	self.settings.enabled = wndControl:IsChecked()
end

function RandomMount:OnWindowClosed( wndHandler, wndControl )
	self:DestroyItemList()
end

function RandomMount:SelectAllmountsToggle( wndHandler, wndControl, eMouseButton )
	
	local isChecked = wndControl:IsChecked()
	
	for k,v in pairs(self.settings.knownMounts) do
		self.settings.knownMounts[k].isSelected = isChecked 
	end
	
	for k,v in pairs(self.tItems) do
		
		test = getmetatable( self.tItems[k]:FindChild("SelectMountButton"))
		--self.tItems[k].FindChild("SelectMountButton").SetCheck(isChecked)
		
		for k,v in pairs(test) do
			Print(k,v)end
	end
	
end

-----------------------------------------------------------------------------------------------
-- ItemList Functions
-----------------------------------------------------------------------------------------------
-- populate item list
function RandomMount:PopulateItemList()
	-- make sure the item list is empty to start with
	self:DestroyItemList()
	
	--all mounts
	local arMountList = CollectiblesLib.GetMountList()
	table.sort(arMountList, function(a,b) return (a.bIsKnown and not b.bIsKnown) or (a.bIsKnown == b.bIsKnown and a.strName < b.strName) end)
	
	--Get mounts not already in list that are known
	for idx = 1, #arMountList do
		local tMountData = arMountList[idx]
				
		if tMountData.bIsKnown and not self.settings.knownMounts[tMountData.nSpellId] then
			self.settings.knownMounts[tMountData.nSpellId] = {
			strName = tMountData.strName, 
			nSpellId = tMountData.nSpellId, 
			icon = tMountData.splObject:GetIcon(),
			isSelected = true
			}
		end
	end
	
	--add window items
	idx = 1

	for k,v in pairs(self.settings.knownMounts) do
		self:AddItem(v,idx)
		idx = idx +1
	end
	
	-- now all the item are added, call ArrangeChildrenVert to list out the list items vertically
	self.wndItemList:ArrangeChildrenVert()
end

-- clear the item list
function RandomMount:DestroyItemList()
	-- destroy all the wnd inside the list
	for idx,wnd in ipairs(self.tItems) do
		wnd:Destroy()
	end

	-- clear the list item array
	self.tItems = {}
	self.wndSelectedListItem = nil
end

-- add an item into the item list
function RandomMount:AddItem(tMountData,idx)
	-- load the window item for the list item
	local wndMount = Apollo.LoadForm(self.xmlDoc, "ListItem", self.wndItemList, self)
	
	if wndMount ~= nil then
		self.tItems[idx] = wndMount 

		local SelectButton = wndMount:FindChild("SelectMountButton")
		local mountSpellId = tMountData.nSpellId
		local isSelected = tMountData.isSelected
		
		if SelectButton ~= nil then
			SelectButton:SetCheck(isSelected)
		end

		wndMount:FindChild("MountName"):SetText(tMountData.strName)		
		wndMount:FindChild("MountIcon"):SetSprite(tMountData.icon)
		
		wndMount:SetData(mountSpellId)

	end
end

-----------------------------------------------------------------------------------------------
-- Save/Load
-----------------------------------------------------------------------------------------------
function RandomMount:OnSave(eLevel)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then return nil end
	return self.settings
end

function RandomMount:OnRestore(eLevel,tSaveData)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then return end
	self.savedSettings = {}
	
	if tSaveData then
		for k,v in pairs(tSaveData) do
			self.savedSettings[k] = v
		end
	end					
end

-----------------------------------------------------------------------------------------------
-- Mount Events
-----------------------------------------------------------------------------------------------
function RandomMount:OnMount()

--If enabled, set random mount for next mount	
if self.settings.enabled == true then
	selectedMounts = {}
	count = 0
	
	for k,v in pairs(self.settings.knownMounts) do
		if v.isSelected then
			count = count + 1
			selectedMounts[count] = k
		end
	end
	
	if count ~= 0 then
		local randNumber = math.random(count)

		GameLib.SetShortcutMount(selectedMounts[randNumber])
	end
end
	

end


---------------------------------------------------------------------------------------------------
-- ListItem Functions
---------------------------------------------------------------------------------------------------
--Save as viable random mount
function RandomMount:OnMountSelected( wndHandler, wndControl, eMouseButton )
	adjustedMount = wndControl:GetParent():GetData()
	self.settings.knownMounts[adjustedMount].isSelected = wndControl:IsChecked()
end

-----------------------------------------------------------------------------------------------
-- RandomMount Instance
-----------------------------------------------------------------------------------------------
local RandomMountInst = RandomMount:new()
RandomMountInst:Init()
