--!strict
local QTEManagerClass = require('@self/Manager')
local QTESequenceClass = require('@self/Sequence')
local QTEActionClass = require('@self/Action')
local Types = require('@self/Types')

local QTE = {
	Manager = QTEManagerClass,
	Sequence = QTESequenceClass,
	Action = QTEActionClass,
	Types = Types,
}

export type QTEActionType = Types.QTEActionType
export type QTEInputType = Types.QTEInputType
export type QTEActionConfig = Types.QTEActionConfig
export type QTESequenceConfig = Types.QTESequenceConfig
export type QTEAction = Types.QTEAction
export type QTESequence = Types.QTESequence
export type QTEManager = Types.QTEManager
export type QTENetworkData = Types.QTENetworkData
export type QTEResult = Types.QTEResult

function QTE.CreateSimpleKeyPress(key: Enum.KeyCode, duration: number): Types.QTEActionConfig
	return {
		Type = "KeyPress",
		Input = key,
		Duration = duration,
	}
end

function QTE.CreateMash(key: Enum.KeyCode, duration: number, requiredPresses: number): Types.QTEActionConfig
	return {
		Type = "Mash",
		Input = key,
		Duration = duration,
		RequiredPresses = requiredPresses,
	}
end

function QTE.CreateComboSequence(keys: {Enum.KeyCode}, actionDuration: number?): Types.QTESequenceConfig
	local actions = {}
	local duration = actionDuration or 1.5
	
	for _, key in ipairs(keys) do
		table.insert(actions, QTE.CreateSimpleKeyPress(key, duration))
	end
	
	return {
		Actions = actions,
		AllowEarlyCancel = true,
		CancelInput = Enum.KeyCode.Escape,
		FailOnFirstMiss = false,
	}
end

function QTE.CreateReactionTest(duration: number?): Types.QTESequenceConfig
	local testDuration = duration or 2.0
	
	return {
		Actions = {
			QTE.CreateSimpleKeyPress(Enum.KeyCode.Space, testDuration),
		},
		AllowEarlyCancel = false,
		FailOnFirstMiss = true,
	}
end

return QTE
