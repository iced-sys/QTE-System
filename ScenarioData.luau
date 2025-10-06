--!strict
local ScenarioData = {}

ScenarioData.ShopRobbery = {
	Name = "Shop Robbery",
	Description = "Blabla",
	FoV = 40,
	
	Steps = {
		{
			StepId = "1",
			CharacterAnimations = {"rbxassetid://125106246479367", "rbxassetid://114678187660900"},

			OnSuccess = { NextStep = "2" },
		},

		{
			StepId = "2",
			CharacterAnimations = {"rbxassetid://98570472521396", "rbxassetid://99168504267378"},
			
			QTE = {
				Actions = {
					{
						Type = "KeyPress",
						Input = Enum.KeyCode.H,
						Duration = 1.5,
						StartTimestamp = 1.0,
					},
					{
						Type = "KeyPress", 
						Input = Enum.KeyCode.J,
						Duration = 1.5,
						StartTimestamp = 2.5,
					},
					{
						Type = "KeyPress",
						Input = Enum.KeyCode.K, 
						Duration = 1.5,
						StartTimestamp = 4.0,
					},
					{
						Type = "KeyPress",
						Input = Enum.KeyCode.L,
						Duration = 1.5,
						StartTimestamp = 5.5
					}
				},
				RequireExactOrder = true,
				FailOnFirstMiss = false,
				AllowEarlyCancel = false,
			},

			OnSuccess = {
				NextStep = "finish1",
				Callback = function(sequence)

				end
			},
			
			OnFailure = {
				NextStep = "3",
				Callback = function(sequence)

				end
			}
		},

		{
			StepId = "3",
			CharacterAnimations = {"rbxassetid://86988045505031", "rbxassetid://99683565113808"},
			TransitionDuration = 0.4,

			OnSuccess = {
				NextStep = "4",
				Callback = function(sequence)

				end
			}
		},

		{
			StepId = "4",
			CharacterAnimations = {"rbxassetid://82707252458843", "rbxassetid://91395070643644"},
			TransitionDuration = 0.4,
			
			QTE = {
				Actions = {
					{
						Type = "KeyPress",
						Input = Enum.KeyCode.H,
						Duration = 1.5,
						StartTimestamp = 1.0,
					},
					{
						Type = "KeyPress", 
						Input = Enum.KeyCode.J,
						Duration = 1.5,
						StartTimestamp = 2.5,
					},
					{
						Type = "KeyPress",
						Input = Enum.KeyCode.K, 
						Duration = 1.5,
						StartTimestamp = 4.0,
					},
					{
						Type = "KeyPress",
						Input = Enum.KeyCode.L,
						Duration = 1.5,
						StartTimestamp = 5.5,
					}
				},
				RequireExactOrder = true,
				FailOnFirstMiss = false,
				AllowEarlyCancel = false,
			},

			OnSuccess = {
				NextStep = "4s",
				Callback = function(sequence)

				end
			},
			
			OnFailure = {
				NextStep = "4f",
				Callback = function(sequence)

				end
			}
		},

		{
			StepId = "4s",
			CharacterAnimations = {"rbxassetid://85802827084103", "rbxassetid://107972563833960"},
			TransitionDuration = 0.4,

			OnSuccess = {
				NextStep = "",
				Callback = function(sequence)

				end
			}
		},


		{
			StepId = "4f",
			CharacterAnimations = {"rbxassetid://107631591586362", "rbxassetid://136072763220824"},
			TransitionDuration = 0.4,

			OnSuccess = {
				NextStep = "",
				Callback = function(sequence)

				end
			}
		},

		

		{
			StepId = "finish1",
			CharacterAnimations = {"rbxassetid://123037162693972", "rbxassetid://131440551742322"},
			TransitionDuration = 0.4,

			OnSuccess = { NextStep = "" },
		},
	},
	
	OnStart = function(sequence)

	end,
	
	OnComplete = function(sequence, success)
		if success then

		else

		end
	end,
}

return ScenarioData
