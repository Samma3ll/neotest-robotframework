local lib = require("neotest.lib")
local logger = require("neotest.logging")

---@type neotest.Adapter
local adapter = { name = "robotframework" }

function adapter.root(dir)
	return lib.files.match_root_pattern("*.robot", "robot.yaml")(dir)
end

function adapter.is_test_file(file_path)
	return vim.endswith(file_path, ".robot")
end

function adapter.filter_dir(name, rel_path, root)
	return name ~= "node_modules" and name ~= ".git"
end

function adapter.discover_positions(path)
	local query = [[
        ; Robot Framework test cases
        (section_header
            name: (_) @section.name
            (#match? @section.name "(?i)^Test Cases$")
        ) @section.definition

        (test_case_setting
            name: (_) @test.name
        ) @test.definition

        (test_case
            name: (_) @test.name
        ) @test.definition

        (keyword_setting
            name: (_) @test.name
            (#match? @test.name "^Test Setup$|^Test Teardown$")
        ) @test.definition
    ]]

	local tree = lib.treesitter.parse_positions(path, query, {
		position_id = function(position, namespaces)
			return position.id
		end,
	})

	if not tree then
		logger.warn("No positions found in " .. path)
		return {}
	end

	return tree
end

function adapter.build_spec(args)
	local position = args.tree:data()
	local results_path = vim.fn.tempname()

	local command = {
		"robot",
		"--outputdir=" .. vim.fn.fnamemodify(results_path, ":h"),
	}

	if position.type == "test" then
		table.insert(command, "--test")
		table.insert(command, '"' .. position.name .. '"')
	end

	table.insert(command, position.path)

	return {
		command = command,
		context = {
			results_path = results_path,
		},
	}
end

function adapter.results(spec, result, tree)
	local results = {}
	local output_file = spec.context.results_path .. "/output.xml"

	-- Basic results based on exit code
	for _, pos in tree:iter() do
		if pos.type == "test" or pos.type == "namespace" then
			results[pos.id] = {
				status = result.code == 0 and "passed" or "failed",
				short = pos.name,
				output = result.output,
			}
		end
	end

	return results
end

local function create_adapter(opts)
	opts = opts or {}
	return adapter
end

return create_adapter
