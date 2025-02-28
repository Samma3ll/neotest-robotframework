local lib = require("neotest.lib")
local logger = require("neotest.logging")

---@class RobotframeworkNeotestAdapter
local RobotframeworkNeotestAdapter = { name = "robotframework" }

function RobotframeworkNeotestAdapter.discover_positions(path)
	logger.info("RobotFramework adapter: discovering positions in " .. path)

	local query = [[
    ;; Test Cases section
    (section
      name: (section_header) @section.name
      (#match? @section.name "^Test Cases$")
    ) @section.definition

    ;; Individual test cases
    (test_case
      name: (test_name) @test.name
    ) @test.definition

    ;; Test suites (files)
    (file) @file.definition
    ]]

	local positions = lib.treesitter.parse_positions(path, query, { nested_tests = true })
	logger.info("RobotFramework adapter: found positions", positions)
	return positions
end

return RobotframeworkNeotestAdapter
