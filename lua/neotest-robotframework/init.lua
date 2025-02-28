local create_adapter = require("neotest-robotframework.adapter")

local RobotframeworkNeotestAdapter = create_adapter({})

setmetatable(RobotframeworkNeotestAdapter, {
	__call = function(_, opts)
		opts = opts or {}
		return create_adapter({ min_init = opts.min_init })
	end,
})

RobotframeworkNeotestAdapter.setup = function(opts)
	return RobotframeworkNeotestAdapter(opts)
end

return RobotframeworkNeotestAdapter
