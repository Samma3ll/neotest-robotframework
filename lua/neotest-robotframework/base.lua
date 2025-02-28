local lib = require("neotest.lib")

---@class RobotframeworkNeotestAdapter
local RobotframeworkNeotestAdapter = { name = "robotframework" }

function RobotframeworkNeotestAdapter.discover_positions(path)
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

	return lib.treesitter.parse_positions(path, query, { nested_tests = true })
end

return RobotframeworkNeotestAdapter
