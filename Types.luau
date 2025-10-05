--!strict

export type QTEActionType = 
	"KeyPress" | 
	"MouseClick" | 
	"Sequence" | 
	"Mash"

export type QTEInputType = 
	Enum.KeyCode | 
	Enum.UserInputType | 
	{Enum.KeyCode} -- For sequences

export type QTEActionConfig = {
	Type: QTEActionType,
	Input: QTEInputType?,
	Duration: number, -- Time allowed for this action
	Tolerance: number?, -- Timing tolerance (for rhythm games, etc.)
	RequiredPresses: number?, -- For mash events
	StartTimestamp: number?, -- Time offset in seconds from when step begins to when this action should start
	
	OnStart: ((any) -> ())?,
	OnProgress: ((any, number) -> ())?,
	OnSuccess: ((any, number) -> ())?,
	OnFailure: ((any, string) -> ())?,
}

export type QTESequenceConfig = {
	Actions: {QTEActionConfig},
	AllowEarlyCancel: boolean?,
	CancelInput: QTEInputType?,
	FailOnFirstMiss: boolean?,
	
	-- Callbacks
	OnSequenceStart: ((any) -> ())?,
	OnSequenceComplete: ((any, number) -> ())?,
	OnSequenceFail: ((any) -> ())?,
	OnSequenceCancel: ((any) -> ())?,
}

export type QTEAction = {
	Config: QTEActionConfig,
	Id: string,
	StartTime: number,
	EndTime: number,
	IsCompleted: boolean,
	IsSuccessful: boolean,
	Progress: number,
	TimingScore: number, -- 0-1, 1 being perfect timing
}

export type QTESequence = {
	Config: QTESequenceConfig,
	Id: string,
	Actions: {QTEAction},
	IsActive: boolean,
	IsCompleted: boolean,
	IsSuccessful: boolean,
	StartTime: number,
	OverallScore: number,
	CompletedActions: number,
}

export type QTEManager = {
	ActiveSequences: {[string]: QTESequence},
}

export type QTENetworkData = {
	SequenceId: string,
	Config: QTESequenceConfig,
}

export type QTEResult = {
	SequenceId: string,
	IsSuccessful: boolean,
}

return {}
