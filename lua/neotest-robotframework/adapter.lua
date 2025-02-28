local lib = require("neotest.lib")
local logger = require("neotest.logging")

---@type neotest.Adapter
local adapter = { name = "robotframework" }

function adapter.root(dir)
	-- Find the project root by looking for robot files or robot.yaml
	return lib.files.match_root_pattern("*.robot", "robot.yaml")(dir)
end

function adapter.is_test_file(file_path)
	-- Check if the file is a Robot Framework test file
	return vim.endswith(file_path, ".robot")
end

function adapter.filter_dir(name, rel_path, root)
	-- Optionally filter out directories when searching for test files
	-- Return false for directories you want to skip
	return name ~= "node_modules" and name ~= ".git"
end

function adapter.discover_positions(path)
	-- Parse the test file to find test positions
	local query = [[
        ; Robot Framework test cases
        (section_header
            name: (_) @section.name
            (#match? @section.name "^Test Cases$")
        ) @section.definition

        (test_case
            name: (_) @test.name
        ) @test.definition
    ]]

	local positions = lib.treesitter.parse_positions(path, query)
	if not positions then
		logger.warn("No positions found in " .. path)
		return {}
	end
	return positions
end

function adapter.build_spec(args)
	-- Build the command to run tests
	local position = args.tree:data()
	local results_path = vim.fn.tempname()

	-- Basic command to run robot framework tests
	local command = {
		"robot",
		"--outputdir=" .. vim.fn.fnamemodify(results_path, ":h"),
		position.path,
	}

	-- If running a specific test, add the test name
	if position.type == "test" then
		table.insert(command, "--test")
		table.insert(command, position.name)
	end

	return {
		command = command,
		context = {
			results_path = results_path,
		},
	}
end

function adapter.results(spec, result, tree)
	-- Parse the results from the test run
	local results = {}
	local output_file = spec.context.results_path .. "/output.xml"

	-- Here you would parse the Robot Framework output.xml file
	-- and convert it to neotest results format
	-- This is a basic example that just uses the exit code
	for _, pos in tree:iter() do
		if pos.type == "test" then
			results[pos.id] = {
				status = result.code == 0 and "passed" or "failed",
			}
		end
	end

	return results
end

---@param opts table
local function create_adapter(opts)
	opts = opts or {}
	-- Add any adapter-specific configuration here
	return adapter
end

return create_adapter
