--!strict

local HttpService = game:GetService("HttpService")

local Types = require('./Types')
local QTEActionClass = require('./Action')

type QTESequenceConfig = Types.QTESequenceConfig
type QTEActionConfig = Types.QTEActionConfig
type QTEActionObject = QTEActionClass.Object

local QTESequenceClass = {}
QTESequenceClass.__index = QTESequenceClass

type Data = {
	Config: QTESequenceConfig,
	Id: string,
	Actions: {QTEActionObject},
	ActiveActions: {[string]: QTEActionObject}, -- Track actions by ID for concurrent execution
	ScheduledActions: {[string]: QTEActionObject}, -- Track actions waiting to start based on timestamp
	IsActive: boolean,
	IsCompleted: boolean,
	IsSuccessful: boolean,
	StartTime: number,
	OverallScore: number,
	CompletedActions: number,
}

export type Object = typeof(setmetatable({} :: Data, QTESequenceClass))

function QTESequenceClass.new(config: QTESequenceConfig): Object
	local self = setmetatable({}, QTESequenceClass) :: Object
	
	self.Config = config
	self.Id = HttpService:GenerateGUID(false)
	self.Actions = {}
	self.ActiveActions = {}
	self.ScheduledActions = {}
	self.IsActive = false
	self.IsCompleted = false
	self.IsSuccessful = false
	self.StartTime = 0
	self.OverallScore = 0
	self.CompletedActions = 0
	
	for _, actionConfig in ipairs(config.Actions) do
		local action = QTEActionClass.new(actionConfig)
		table.insert(self.Actions, action)
	end
	
	return self
end

function QTESequenceClass.Start(self: Object)
	if self.IsActive then
		return
	end
	
	self.IsActive = true
	self.StartTime = tick()
	self.IsCompleted = false
	self.IsSuccessful = false
	self.OverallScore = 0
	self.CompletedActions = 0
	self.ActiveActions = {}
	self.ScheduledActions = {}
	
	for _, action in ipairs(self.Actions) do
		local startTimestamp = action.Config.StartTimestamp or 0
		if startTimestamp <= 0 then
			action:Start()
			self.ActiveActions[action.Id] = action
		else
			self.ScheduledActions[action.Id] = action
			task.spawn(function()
				task.wait(startTimestamp)
				if self.IsActive and self.ScheduledActions[action.Id] then
					self.ScheduledActions[action.Id] = nil
					action:Start()
					self.ActiveActions[action.Id] = action
				end
			end)
		end
	end
	
	if self.Config.OnSequenceStart then
		self.Config.OnSequenceStart(self)
	end
end

function QTESequenceClass.Update(self: Object, deltaTime: number)
	if not self.IsActive or self.IsCompleted then
		return
	end
	
	for actionId, action in pairs(self.ActiveActions) do
		action:Update(deltaTime)
		
		if action.IsCompleted then
			self:_OnActionCompleted(action)
		end
	end
end

function QTESequenceClass.HandleInput(self: Object, inputObject: InputObject): boolean
	if not self.IsActive or self.IsCompleted then
		return false
	end
	
	if self.Config.AllowEarlyCancel and self.Config.CancelInput then
		if self:_IsCancelInput(inputObject) then
			self:Cancel()
			return true
		end
	end
	
	local inputHandled = false
	for _, action in pairs(self.ActiveActions) do
		if action:HandleInput(inputObject) then
			inputHandled = true
		end
	end
	
	return inputHandled
end

function QTESequenceClass._IsCancelInput(self: Object, inputObject: InputObject): boolean
	local cancelInput = self.Config.CancelInput
	if not cancelInput then
		return false
	end
	
	if typeof(cancelInput) == "EnumItem" then
		if cancelInput.EnumType == Enum.KeyCode then
			return inputObject.UserInputType == Enum.UserInputType.Keyboard and inputObject.KeyCode == (cancelInput :: Enum.KeyCode)
		elseif cancelInput.EnumType == Enum.UserInputType then
			return inputObject.UserInputType == (cancelInput :: Enum.UserInputType)
		end
	end
	
	return false
end

function QTESequenceClass._OnActionCompleted(self: Object, action: QTEActionObject)
	if not self.ActiveActions[action.Id] then
		return
	end
	
	self.ActiveActions[action.Id] = nil
	
	if action.IsSuccessful then
		self.CompletedActions = self.CompletedActions + 1
		self.OverallScore = self.OverallScore + action.TimingScore
	else
		if self.Config.FailOnFirstMiss then
			self:_OnSequenceFail()
			return
		end
	end
	
	local hasActiveActions = false
	for _ in pairs(self.ActiveActions) do
		hasActiveActions = true
		break
	end
	
	local hasScheduledActions = false
	for _ in pairs(self.ScheduledActions) do
		hasScheduledActions = true
		break
	end
	
	if not hasActiveActions and not hasScheduledActions then
		self:_OnSequenceComplete()
	end
end

function QTESequenceClass._OnSequenceComplete(self: Object)
	self.IsCompleted = true
	self.IsActive = false
	
	local successRate = self.CompletedActions / #self.Actions
	self.IsSuccessful = successRate >= 0.6
	
	if self.CompletedActions > 0 then
		self.OverallScore = self.OverallScore / self.CompletedActions
	else
		self.OverallScore = 0
	end
	
	if self.Config.OnSequenceComplete then
		self.Config.OnSequenceComplete(self, self.OverallScore)
	end
end

function QTESequenceClass._OnSequenceFail(self: Object)
	self.IsCompleted = true
	self.IsActive = false
	self.IsSuccessful = false
	self.OverallScore = 0
	
	for actionId, action in pairs(self.ActiveActions) do
		if not action.IsCompleted then
			action:Cancel()
		end
	end
	self.ActiveActions = {}
	
	self.ScheduledActions = {}
	
	if self.Config.OnSequenceComplete then
		self.Config.OnSequenceComplete(self, 0)
	end
end

function QTESequenceClass.Cancel(self: Object)
	if self.IsCompleted then
		return
	end
	
	self.IsCompleted = true
	self.IsActive = false
	self.IsSuccessful = false
	
	for _, action in ipairs(self.Actions) do
		if not action.IsCompleted then
			action:Cancel()
		end
	end
	
	self.ScheduledActions = {}
	
	if self.Config.OnSequenceCancel then
		self.Config.OnSequenceCancel(self)
	end
end

function QTESequenceClass.GetCurrentAction(self: Object): QTEActionObject?
	for _, action in pairs(self.ActiveActions) do
		return action
	end
	return nil
end

function QTESequenceClass.GetProgress(self: Object): number
	if #self.Actions == 0 then
		return 1
	end
	
	local completedCount = 0
	for _, action in ipairs(self.Actions) do
		if action.IsCompleted then
			completedCount = completedCount + 1
		end
	end
	
	local currentAction = self:GetCurrentAction()
	if currentAction and not currentAction.IsCompleted then
		completedCount = completedCount + currentAction.Progress
	end
	
	return completedCount / #self.Actions
end

return QTESequenceClass
