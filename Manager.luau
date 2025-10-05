--!strict
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Types = require('./Types')
local QTESequenceClass = require('./Sequence')
local UIManager = require('./UI')

type QTESequenceConfig = Types.QTESequenceConfig
type QTESequenceObject = QTESequenceClass.Object

local QTEManagerClass = {}
QTEManagerClass.__index = QTEManagerClass

type Data = {
	ActiveSequences: {[string]: any},
	UIManager: any?,
	_connections: {[string]: RBXScriptConnection},
}

export type Object = typeof(setmetatable({} :: Data, QTEManagerClass))

function QTEManagerClass.new(): Object
	local self = setmetatable({}, QTEManagerClass) :: Object
	
	self.ActiveSequences = {}
	self.UIManager = UIManager.new()
	self._connections = {}
	
	self._connections.InputBegan = UserInputService.InputBegan:Connect(function(inputObject, gameProcessed)
		if gameProcessed then return end
		self:HandleInput(inputObject)
	end)
	
	self._connections.InputEnded = UserInputService.InputEnded:Connect(function(inputObject, gameProcessed)
		if gameProcessed then return end
		self:HandleInput(inputObject)
	end)
	
	self._connections.Heartbeat = RunService.Heartbeat:Connect(function(deltaTime)
		self:UpdateSequences(deltaTime)
	end)
	
	return self
end

function QTEManagerClass.CreateSequence(self: Object, config: QTESequenceConfig): QTESequenceObject
	local sequence = QTESequenceClass.new(config)
	
	if self.UIManager then
		self:_ConnectSequenceToUI(sequence)
	end
	
	return sequence
end

function QTEManagerClass.StartSequence(self: Object, sequence: any)
	if self.ActiveSequences[sequence.Id] then
		warn("QTE Sequence with ID " .. sequence.Id .. " is already active")
		return
	end
	
	self.ActiveSequences[sequence.Id] = sequence
	sequence:Start()
end

function QTEManagerClass._ConnectSequenceToUI(self: Object, sequence: any)
	if not self.UIManager then return end
	
	for i, action in ipairs(sequence.Actions) do
		action.Id = sequence.Id .. "_action_" .. tostring(i)
		
		local onStart = action.Config.OnStart
		action.Config.OnStart = function(actionSelf)
			self.UIManager:ShowActionPrompt(actionSelf.Id, actionSelf.Config)
			if onStart then
				onStart(actionSelf)
			end
		end
		
		local onProgress = action.Config.OnProgress
		action.Config.OnProgress = function(actionSelf, progress)
			self.UIManager:UpdateActionProgress(actionSelf.Id, progress)
			if onProgress then
				onProgress(actionSelf, progress)
			end
		end
		
		local onSuccess = action.Config.OnSuccess
		action.Config.OnSuccess = function(actionSelf, score)
			self.UIManager:ShowTimingFeedback(actionSelf.Id, score)
			
			task.wait(0.2)
			self.UIManager:HideActionPrompt(actionSelf.Id, true)
			
			if onSuccess then
				onSuccess(actionSelf, score)
			end
		end
		
		local onFailure = action.Config.OnFailure
		action.Config.OnFailure = function(actionSelf, reason)
			self.UIManager:HideActionPrompt(actionSelf.Id, false)
			if onFailure then
				onFailure(actionSelf, reason)
			end
		end
	end
	
	local onComplete = sequence.Config.OnSequenceComplete
	sequence.Config.OnSequenceComplete = function(seq: any, score: any)
		for _, action in ipairs(seq.Actions) do
			if action.Id then
				self.UIManager:HideActionPrompt(action.Id)
			end
		end
		if onComplete then
			onComplete(seq, score)
		end
	end
	
	local onFail = sequence.Config.OnSequenceFail
	sequence.Config.OnSequenceFail = function(seq: any)
		for _, action in ipairs(seq.Actions) do
			if action.Id then
				self.UIManager:HideActionPrompt(action.Id)
			end
		end
		if onFail then
			onFail(seq)
		end
	end
	
	local onCancel = sequence.Config.OnSequenceCancel
	sequence.Config.OnSequenceCancel = function(seq: any)
		for _, action in ipairs(seq.Actions) do
			if action.Id then
				self.UIManager:HideActionPrompt(action.Id)
			end
		end
		if onCancel then
			onCancel(seq)
		end
	end
end

function QTEManagerClass.UpdateSequences(self: Object, deltaTime: number)
	local toRemove = {}
	
	for sequenceId, sequence in pairs(self.ActiveSequences) do
		sequence:Update(deltaTime)
		
		if sequence.IsCompleted then
			table.insert(toRemove, sequenceId)
		end
	end
	
	for _, sequenceId in ipairs(toRemove) do
		self.ActiveSequences[sequenceId] = nil
	end
end

function QTEManagerClass.HandleInput(self: Object, inputObject: InputObject)
	for _, sequence in pairs(self.ActiveSequences) do
		if sequence:HandleInput(inputObject) then
			break
		end
	end
end

function QTEManagerClass.CancelSequence(self: Object, sequenceId: string, reason: string?)
	local sequence = self.ActiveSequences[sequenceId]
	if sequence then
		sequence:Cancel(reason)
		self.ActiveSequences[sequenceId] = nil
	end
end

function QTEManagerClass.CancelAllSequences(self: Object, reason: string?)
	for sequenceId, sequence in pairs(self.ActiveSequences) do
		sequence:Cancel(reason)
	end
	self.ActiveSequences = {}
end

function QTEManagerClass.GetActiveSequence(self: Object, sequenceId: string): QTESequenceObject?
	return self.ActiveSequences[sequenceId]
end

function QTEManagerClass.Destroy(self: Object)
	self:CancelAllSequences("Manager destroyed")
	
	for _, connection in pairs(self._connections) do
		connection:Disconnect()
	end
	self._connections = {}
end

return QTEManagerClass
