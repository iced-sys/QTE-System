--!strict
local HttpService = game:GetService("HttpService")

local Types = require('./Types')
type QTEActionConfig = Types.QTEActionConfig

local QTEActionClass = {}
QTEActionClass.__index = QTEActionClass

type Data = {
	Config: QTEActionConfig,
	Id: string,
	StartTime: number,
	EndTime: number,
	IsCompleted: boolean,
	IsSuccessful: boolean,
	Progress: number,
	TimingScore: number,
	PressCount: number,
	HoldStartTime: number?,
}

export type Object = typeof(setmetatable({} :: Data, QTEActionClass))

function QTEActionClass.new(config: QTEActionConfig): Object
	local self = setmetatable({}, QTEActionClass) :: Object
	
	self.Config = config
	self.Id = HttpService:GenerateGUID(false)
	self.StartTime = 0
	self.EndTime = 0
	self.IsCompleted = false
	self.IsSuccessful = false
	self.Progress = 0
	self.TimingScore = 0
	self.PressCount = 0
	self.HoldStartTime = nil
	
	return self
end

function QTEActionClass.Start(self: Object)
	self.StartTime = tick()
	self.EndTime = self.StartTime + self.Config.Duration
	self.IsCompleted = false
	self.IsSuccessful = false
	self.Progress = 0
	self.TimingScore = 0
	
	if self.Config.OnStart then
		self.Config.OnStart(self)
	end
end

function QTEActionClass.Update(self: Object, deltaTime: number)
	if self.IsCompleted then
		return
	end
	
	local currentTime = tick()
	local elapsed = currentTime - self.StartTime
	self.Progress = math.min(elapsed / self.Config.Duration, 1)
	
	if self.Config.OnProgress then
		self.Config.OnProgress(self, self.Progress)
	end
	
	if currentTime >= self.EndTime then
		self:_OnTimeout()
	end
end

function QTEActionClass.HandleInput(self: Object, inputObject: InputObject): boolean
	if self.IsCompleted then
		return false
	end
	
	local success = false
	local actionType = self.Config.Type
	
	if actionType == "KeyPress" then
		success = self:HandleKeyPress(inputObject)
	elseif actionType == "KeyHold" then
		success = self:HandleKeyHold(inputObject)
	elseif actionType == "MouseClick" then
		success = self:HandleMouseClick(inputObject)
	elseif actionType == "MouseHold" then
		success = self:HandleMouseHold(inputObject)
	elseif actionType == "Mash" then
		success = self:HandleMash(inputObject)
	end
	
	if success then
		self:_OnSuccess()
	end
	
	return success
end

function QTEActionClass.HandleKeyPress(self: Object, inputObject: InputObject): boolean
	if inputObject.UserInputType ~= Enum.UserInputType.Keyboard then
		return false
	end
	
	if inputObject.UserInputState ~= Enum.UserInputState.Begin then
		return false
	end
	
	return inputObject.KeyCode == self.Config.Input
end

function QTEActionClass.HandleKeyHold(self: Object, inputObject: InputObject): boolean
	if inputObject.UserInputType ~= Enum.UserInputType.Keyboard then
		return false
	end
	
	if inputObject.KeyCode ~= self.Config.Input then
		return false
	end
	
	if inputObject.UserInputState == Enum.UserInputState.Begin then
		self.HoldStartTime = tick()
		return false -- Don't complete yet
	elseif inputObject.UserInputState == Enum.UserInputState.End then
		if self.HoldStartTime then
			local holdDuration = tick() - self.HoldStartTime
			local requiredDuration = self.Config.Duration * 0.8 -- 80% of duration required
			return holdDuration >= requiredDuration
		end
	end
	
	return false
end

function QTEActionClass.HandleMouseClick(self: Object, inputObject: InputObject): boolean
	if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return false
	end
	
	return inputObject.UserInputState == Enum.UserInputState.Begin
end

function QTEActionClass.HandleMouseHold(self: Object, inputObject: InputObject): boolean
	if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return false
	end
	
	if inputObject.UserInputState == Enum.UserInputState.Begin then
		self.HoldStartTime = tick()
		return false -- Don't complete yet
	elseif inputObject.UserInputState == Enum.UserInputState.End then
		if self.HoldStartTime then
			local holdDuration = tick() - self.HoldStartTime
			local requiredDuration = self.Config.Duration * 0.8
			return holdDuration >= requiredDuration
		end
	end
	
	return false
end

function QTEActionClass.HandleMash(self: Object, inputObject: InputObject): boolean
	if inputObject.UserInputType ~= Enum.UserInputType.Keyboard then
		return false
	end
	
	if inputObject.KeyCode ~= self.Config.Input then
		return false
	end
	
	if inputObject.UserInputState == Enum.UserInputState.Begin then
		self.PressCount = self.PressCount + 1
		local requiredPresses = self.Config.RequiredPresses or 10
		return self.PressCount >= requiredPresses
	end
	
	return false
end

function QTEActionClass._OnSuccess(self: Object)
	if self.IsCompleted then
		return
	end
	
	self.IsCompleted = true
	self.IsSuccessful = true
	self.TimingScore = self:GetTimingScore()
	
	if self.Config.OnSuccess then
		self.Config.OnSuccess(self, self.TimingScore)
	end
end

function QTEActionClass._OnTimeout(self: Object)
	if self.IsCompleted then
		return
	end
	
	self.IsCompleted = true
	self.IsSuccessful = false
	self.TimingScore = 0
	
	if self.Config.OnFailure then
		self.Config.OnFailure(self, "Timeout")
	end
end

function QTEActionClass.Cancel(self: Object, reason: string?)
	if self.IsCompleted then
		return
	end
	
	self.IsCompleted = true
	self.IsSuccessful = false
	self.TimingScore = 0
	
	if self.Config.OnFailure then
		self.Config.OnFailure(self, reason or "Cancelled")
	end
end

local OUTER_RING_START_SCALE = 2.5
local OUTER_RING_END_SCALE = 0.3
local TARGET_ZONE_SCALE = 0.7

function QTEActionClass.GetTimingScore(self: Object): number
	if not self.IsSuccessful then
		return 0
	end
	
	local elapsed = tick() - self.StartTime
	local progress = elapsed / self.Config.Duration
	
	-- Calculate when outer ring scale matches target zone scale
	local targetProgress = (OUTER_RING_START_SCALE - TARGET_ZONE_SCALE) / (OUTER_RING_START_SCALE - OUTER_RING_END_SCALE)
	
	local tolerance = self.Config.Tolerance or 0.15 -- 15% tolerance by default for perfect timing
	
	local timingError = math.abs(progress - targetProgress)
	local score = math.max(0, 1 - (timingError / tolerance))
	
	return score
end

return QTEActionClass
