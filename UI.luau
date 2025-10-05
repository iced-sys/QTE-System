--!strict
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local UI_SIZE = UDim2.fromOffset(200, 200)
local CLOSING_CIRCLE_STROKE_THICKNESS = 2
local KEY_CIRCLE_STROKE_THICKNESS = 3
local CLICKING_ZONE_STROKE_THICKNESS = 3

local CLOSING_CIRCLE_START_SCALE = 1
local KEY_CIRCLE_SCALE = 0.25
local CLICKING_ZONE_SCALE = 0.45

local WHITE_COLOR = Color3.fromRGB(255, 255, 255)
local BLACK_COLOR = Color3.fromRGB(0, 0, 0)
local RED_COLOR = Color3.fromRGB(255, 0, 0)
local GREEN_COLOR = Color3.fromRGB(0, 255, 0)
local YELLOW_COLOR = Color3.fromRGB(255, 255, 0)
local ORANGE_COLOR = Color3.fromRGB(255, 165, 0)

local QTEUIManagerClass = {}
QTEUIManagerClass.__index = QTEUIManagerClass

type Data = {
	ActivePrompts: {[string]: any},
	ScreenGui: ScreenGui,
	_connections: {[string]: RBXScriptConnection},
}

export type Object = typeof(setmetatable({} :: Data, QTEUIManagerClass))

local function keycodeToText(keycode: Enum.KeyCode): string
	local keycodeString = tostring(keycode)
	local parts = string.split(keycodeString, ".")
	local keyName = parts[#parts]
	return string.upper(keyName)
end

function QTEUIManagerClass.new(): Object
	local self = setmetatable({}, QTEUIManagerClass) :: Object
	
	self.ActivePrompts = {}
	self._connections = {}
	
	self.ScreenGui = Instance.new("ScreenGui")
	self.ScreenGui.Name = "QTEPrompts"
	self.ScreenGui.ResetOnSpawn = false
	self.ScreenGui.IgnoreGuiInset = true
	self.ScreenGui.Parent = PlayerGui
	
	return self
end

function QTEUIManagerClass.ShowActionPrompt(self: Object, actionId: string, actionData: any)
	if self.ActivePrompts[actionId] then
		return
	end
	
	local frame = self:_CreatePromptFrame()
	
	local clickingZone, clickingZoneStroke = self:_CreateClickingZone(frame)
	local keyCircle, keyCircleStroke, keyText = self:_CreateKeyCircle(frame, actionData)
	local closingCircle, closingCircleStroke = self:_CreateClosingCircle(frame)
	
	local promptData = {
		Frame = frame,
		ClickingZone = clickingZone,
		ClickingZoneStroke = clickingZoneStroke,
		KeyCircle = keyCircle,
		KeyCircleStroke = keyCircleStroke,
		KeyText = keyText,
		ClosingCircle = closingCircle,
		ClosingCircleStroke = closingCircleStroke,
		ActionData = actionData,
		StartTime = tick(),
		ProgressTween = nil,
	}
	
	self.ActivePrompts[actionId] = promptData
	
	self:_PositionPrompt(frame, actionId)
	self:_ShowEntranceAnimation(promptData)
	
	promptData.ProgressTween = self:_StartProgressTween(actionId, promptData.ActionData.Duration or 2.0, promptData.ClosingCircle)
end

function QTEUIManagerClass.UpdateActionProgress(self: Object, actionId: string, progress: number, customColor: Color3?)
	local promptData = self.ActivePrompts[actionId]
	if not promptData then return end
	
	promptData.LastProgressUpdate = tick()
	
	local scale = CLOSING_CIRCLE_START_SCALE - (progress * (CLOSING_CIRCLE_START_SCALE - KEY_CIRCLE_SCALE))
	local startOffset = (1 - CLOSING_CIRCLE_START_SCALE) / 2
	local endOffset = (1 - KEY_CIRCLE_SCALE) / 2
	local positionOffset = startOffset + (progress * (endOffset - startOffset))
	
	local scaleTween = TweenService:Create(
		promptData.ClosingCircle,
		TweenInfo.new(0.1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{
			Size = UDim2.fromScale(scale, scale),
			Position = UDim2.fromScale(positionOffset, positionOffset)
		}
	)
	scaleTween:Play()
	
	local targetProgress = (CLOSING_CIRCLE_START_SCALE - CLICKING_ZONE_SCALE) / (CLOSING_CIRCLE_START_SCALE - KEY_CIRCLE_SCALE)
	local distanceFromPerfect = math.abs(progress - targetProgress)
	
	local clickingZoneColor = RED_COLOR
	if not customColor then
		if distanceFromPerfect <= 0.05 then
			clickingZoneColor = YELLOW_COLOR
		else
			clickingZoneColor = RED_COLOR
		end
	else
		clickingZoneColor = customColor
	end
	
	if promptData.ClickingZoneStroke then
		promptData.ClickingZoneStroke.Color = clickingZoneColor
	end
	
	if promptData.ClickingZone then
		promptData.ClickingZone.BackgroundColor3 = clickingZoneColor
	end
	
	if progress > 0.8 then
		local pulse = math.sin(tick() * 15) * 0.05 + 1
		promptData.Frame.Size = UDim2.fromOffset(UI_SIZE.X.Offset * pulse, UI_SIZE.Y.Offset * pulse)
	end
end

function QTEUIManagerClass.HideActionPrompt(self: Object, actionId: string, success: boolean?)
	local promptData = self.ActivePrompts[actionId]
	if not promptData then 
		return 
	end
	
	self.ActivePrompts[actionId] = nil
	
	if success == true then
		self:_ShowSuccessFeedback(promptData)
	elseif success == false then
		self:_ShowFailureFeedback(promptData, "X")
	end
	
	self:_ShowExitAnimation(promptData, function()
		if promptData.Frame and promptData.Frame.Parent then
			promptData.Frame:Destroy()
		end
		if promptData.ProgressTween then
			promptData.ProgressTween:Cancel()
		end
		if self._connections[actionId] then
			self._connections[actionId]:Disconnect()
			self._connections[actionId] = nil
		end
	end)
end

function QTEUIManagerClass._GetKeyDisplayText(self: Object, input: any, actionType: string): string
	if actionType == "KeyPress" or actionType == "KeyHold" then
		return keycodeToText(input)
	elseif actionType == "MouseClick" or actionType == "MouseHold" then
		return "CLICK"
	elseif actionType == "Mash" then
		return "MASH " .. keycodeToText(input or Enum.KeyCode.Space)
	elseif actionType == "Sequence" then
		return "SEQUENCE"
	else
		return "?"
	end
end

function QTEUIManagerClass._StartProgressTween(self: Object, actionId: string, duration: number, targetElement: GuiObject)
	local startScale = CLOSING_CIRCLE_START_SCALE
	local endScale = KEY_CIRCLE_SCALE
	local startOffset = (1 - startScale) / 2
	local endOffset = (1 - endScale) / 2
	
	targetElement.Size = UDim2.fromScale(startScale, startScale)
	targetElement.Position = UDim2.fromScale(startOffset, startOffset)
	
	local tweenInfo = TweenInfo.new(
		duration,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.InOut,
		0,
		false,
		0
	)
	
	local tween = TweenService:Create(targetElement, tweenInfo, {
		Size = UDim2.fromScale(endScale, endScale),
		Position = UDim2.fromScale(endOffset, endOffset)
	})
	
	tween:Play()
	return tween
end

function QTEUIManagerClass._StartProgressAnimation(self: Object, actionId: string)
	local connection = RunService.Heartbeat:Connect(function()
		local promptData = self.ActivePrompts[actionId]
		if not promptData then
			if self._connections[actionId] then
				self._connections[actionId]:Disconnect()
				self._connections[actionId] = nil
			end
			return
		end
		
		local elapsed = tick() - promptData.StartTime
		local duration = promptData.ActionData.Duration or 2.0
		local progress = math.min(elapsed / duration, 1)
		
		local lastUpdate = promptData.LastProgressUpdate or 0
		local timeSinceLastUpdate = tick() - lastUpdate
		
		if timeSinceLastUpdate > 0.1 then
			self:UpdateActionProgress(actionId, progress)
		end
		
		if progress >= 1 then
			self:HideActionPrompt(actionId, false)
		end
	end)
	
	self._connections[actionId] = connection
end

function QTEUIManagerClass.UpdateMashProgress(self: Object, actionId: string, currentPresses: number, requiredPresses: number)
	local promptData = self.ActivePrompts[actionId]
	if not promptData then return end
	
	local progress = currentPresses / requiredPresses
	self:UpdateActionProgress(actionId, progress, YELLOW_COLOR)
	
	promptData.KeyText.Text = string.format("%d/%d", currentPresses, requiredPresses)
end

function QTEUIManagerClass.ShowTimingFeedback(self: Object, actionId: string, timingAccuracy: number)
	local promptData = self.ActivePrompts[actionId]
	if not promptData then return end
	
	local feedbackColor = RED_COLOR
	
	if timingAccuracy >= 0.95 then
		feedbackColor = GREEN_COLOR
	elseif timingAccuracy >= 0.8 then
		feedbackColor = YELLOW_COLOR
	elseif timingAccuracy >= 0.6 then
		feedbackColor = ORANGE_COLOR
	else
		feedbackColor = RED_COLOR
	end
	
	local originalClickingZoneColor = promptData.ClickingZoneStroke.Color
	local originalClickingZoneBgColor = promptData.ClickingZone.BackgroundColor3
	
	promptData.ClickingZoneStroke.Color = feedbackColor
	promptData.ClickingZone.BackgroundColor3 = feedbackColor
	
	local clickingZoneColorTween = TweenService:Create(
		promptData.ClickingZoneStroke,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad),
		{Color = originalClickingZoneColor}
	)
	clickingZoneColorTween:Play()
	
	local clickingZoneBgColorTween = TweenService:Create(
		promptData.ClickingZone,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad),
		{BackgroundColor3 = originalClickingZoneBgColor}
	)
	clickingZoneBgColorTween:Play()
end

function QTEUIManagerClass._ShowSuccessFeedback(self: Object, promptData)
	local clickingZoneColorTween = TweenService:Create(
		promptData.ClickingZoneStroke,
		TweenInfo.new(0.1, Enum.EasingStyle.Quad),
		{Color = GREEN_COLOR}
	)
	clickingZoneColorTween:Play()
	
	local clickingZoneBgTween = TweenService:Create(
		promptData.ClickingZone,
		TweenInfo.new(0.1, Enum.EasingStyle.Quad),
		{BackgroundColor3 = GREEN_COLOR}
	)
	clickingZoneBgTween:Play()
	
	local successTween = TweenService:Create(
		promptData.Frame,
		TweenInfo.new(0.2, Enum.EasingStyle.Bounce),
		{
			Size = UDim2.fromOffset(UI_SIZE.X.Offset * 1.2, UI_SIZE.Y.Offset * 1.2),
		}
	)
	successTween:Play()
	
	successTween.Completed:Connect(function()
		local shrinkTween = TweenService:Create(
			promptData.Frame,
			TweenInfo.new(0.1, Enum.EasingStyle.Quad),
			{Size = UI_SIZE}
		)
		shrinkTween:Play()
	end)
end

function QTEUIManagerClass._ShowFailureFeedback(self: Object, promptData, message: string?)
	local keyCircleStrokeColorTween = TweenService:Create(
		promptData.KeyCircleStroke,
		TweenInfo.new(0.1, Enum.EasingStyle.Quad),
		{Color = RED_COLOR}
	)
	
	keyCircleStrokeColorTween:Play()
	
	local keyCircleColorTween = TweenService:Create(
		promptData.KeyCircle,
		TweenInfo.new(0.1, Enum.EasingStyle.Quad),
		{BackgroundColor3 = RED_COLOR}
	)

	keyCircleColorTween:Play()
	
	-- local originalPosition = promptData.Frame.Position
	-- for i = 1, 3 do
	-- 	task.wait(0.05)
	-- 	promptData.Frame.Position = originalPosition + UDim2.fromOffset(math.random(-5, 5), math.random(-5, 5))
	-- 	task.wait(0.05)
	-- 	promptData.Frame.Position = originalPosition
	-- end
	
	if message then
		promptData.KeyText.Text = message
	end
end

function QTEUIManagerClass._CreatePromptFrame(self: Object): Frame
	local frame = Instance.new("Frame")
	frame.Size = UI_SIZE
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = self.ScreenGui
	
	return frame
end

function QTEUIManagerClass._CreateClickingZone(self: Object, parent: GuiObject): (Frame, UIStroke)
	local clickingZone = Instance.new("Frame")
	clickingZone.AnchorPoint = Vector2.new(0.5, 0.5)
	clickingZone.Size = UDim2.fromScale(CLICKING_ZONE_SCALE, CLICKING_ZONE_SCALE)
	clickingZone.Position = UDim2.fromScale(0.5, 0.5)
	clickingZone.BackgroundColor3 = RED_COLOR
	clickingZone.BackgroundTransparency = 0.4
	clickingZone.BorderSizePixel = 0
	clickingZone.Parent = parent
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = clickingZone
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = RED_COLOR
	stroke.Thickness = CLICKING_ZONE_STROKE_THICKNESS
	stroke.Parent = clickingZone
	
	return clickingZone, stroke
end

function QTEUIManagerClass._CreateKeyCircle(self: Object, parent: GuiObject, actionData: any): (Frame, UIStroke, TextLabel)
	local keyCircle = Instance.new("Frame")
	keyCircle.AnchorPoint = Vector2.new(0.5, 0.5)
	keyCircle.Size = UDim2.fromScale(KEY_CIRCLE_SCALE, KEY_CIRCLE_SCALE)
	keyCircle.Position = UDim2.fromScale(0.5, 0.5)
	keyCircle.BackgroundColor3 = WHITE_COLOR
	keyCircle.BackgroundTransparency = 0
	keyCircle.BorderSizePixel = 0
	keyCircle.Parent = parent
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = keyCircle
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = WHITE_COLOR
	stroke.Thickness = KEY_CIRCLE_STROKE_THICKNESS
	stroke.Parent = keyCircle
	
	local keyText = Instance.new("TextLabel")
	keyText.Size = UDim2.fromScale(1, 1)
	keyText.BackgroundTransparency = 1
	keyText.Text = self:_GetKeyDisplayText(actionData.Input, actionData.Type)
	keyText.TextScaled = true
	keyText.Font = Enum.Font.GothamBold
	keyText.TextColor3 = WHITE_COLOR
	keyText.Parent = keyCircle
	
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = BLACK_COLOR
	textStroke.Thickness = 1
	textStroke.Parent = keyText
	
	return keyCircle, stroke, keyText
end

function QTEUIManagerClass._CreateClosingCircle(self: Object, parent: GuiObject): (Frame, UIStroke)
	local closingCircle = Instance.new("Frame")
	closingCircle.Size = UDim2.fromScale(CLOSING_CIRCLE_START_SCALE, CLOSING_CIRCLE_START_SCALE)
	local startOffset = (1 - CLOSING_CIRCLE_START_SCALE) / 2
	closingCircle.Position = UDim2.fromScale(startOffset, startOffset)
	closingCircle.BackgroundColor3 = WHITE_COLOR
	closingCircle.BackgroundTransparency = 0.7
	closingCircle.BorderSizePixel = 0
	closingCircle.Parent = parent
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = closingCircle
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = WHITE_COLOR
	stroke.Thickness = CLOSING_CIRCLE_STROKE_THICKNESS
	stroke.Parent = closingCircle
	
	return closingCircle, stroke
end

function QTEUIManagerClass._ShowExitAnimation(self: Object, promptData, onComplete: (() -> ())?)
	local exitTween = TweenService:Create(
		promptData.Frame,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
		}
	)
	
	exitTween:Play()
	
	if onComplete then
		exitTween.Completed:Connect(onComplete)
	end
end

function QTEUIManagerClass._ShowEntranceAnimation(self: Object, promptData)
	promptData.Frame.Size = UDim2.fromOffset(0, 0)
	
	local entranceTween = TweenService:Create(
		promptData.Frame,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Size = UI_SIZE}
	)
	entranceTween:Play()
end

function QTEUIManagerClass._PositionPrompt(self: Object, frame: GuiObject, actionId: string)
	local minPos = 0.15
	local maxPos = 0.85
	
	local randomX = minPos + math.random() * (maxPos - minPos)
	local randomY = minPos + math.random() * (maxPos - minPos)
	
	frame.Position = UDim2.new(randomX, -60, randomY, -60)
end

function QTEUIManagerClass.Destroy(self: Object)
	for actionId in pairs(self.ActivePrompts) do
		self:HideActionPrompt(actionId)
	end
	self.ActivePrompts = {}
	
	for _, connection in pairs(self._connections) do
		connection:Disconnect()
	end
	self._connections = {}
	
	if self.ScreenGui then
		self.ScreenGui:Destroy()
	end
end

return QTEUIManagerClass