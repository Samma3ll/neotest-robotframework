-- ~/.config/nvim/lua/neotest-robotframework/init.lua
print("ATTEMPTING TO LOAD ROBOT FRAMEWORK ADAPTER")
local lib = require("neotest.lib")
local logger = require("neotest.logging")
logger.info("Loading Robot Framework adapter")

---@type neotest.Adapter
local adapter = { name = "robotframework" }

function adapter.filter_dir(name)
	return name ~= "node_modules"
end

function adapter.root(dir)
	return lib.files.match_root_pattern("*.robot")(dir)
end

function adapter.is_test_file(file_path)
	if file_path == nil then
		return false
	end
	return vim.endswith(file_path, ".robot")
end

function adapter.new()
	return adapter
end

function adapter.discover_positions(path)
	logger.info("Discovering positions for Robot file: " .. path)

	-- Read file content
	local content = lib.files.read(path)
	local lines = vim.split(content, "\n")

	-- Create position tree
	local positions = {
		{
			id = path,
			name = vim.fn.fnamemodify(path, ":t"),
			path = path,
			range = { 0, 0, #lines, 0 },
			type = "file",
		},
	}

	-- Find tests
	local in_test_section = false
	for i, line in ipairs(lines) do
		-- Check for Test Cases section
		if line:match("^%s*%*%*%*%s*[Tt][Ee][Ss][Tt]%s*[Cc][Aa][Ss][Ee][Ss]%s*%*%*%*") then
			in_test_section = true
			logger.info("Found test section at line " .. i)
		-- Check for any section header (marks end of test section)
		elseif line:match("^%s*%*%*%*") then
			in_test_section = false
			current_test_start = nil
		-- Process potential test cases
		elseif in_test_section then
			-- Test cases start with non-whitespace
			if line:match("^[^%s]") and not line:match("^%s*#") and line:match("%S") then
				local test_name = vim.trim(line)
				if test_name then
					logger.info("Found test: " .. test_name .. " at line " .. i)

					table.insert(positions, {
						id = path .. "::" .. test_name,
						name = test_name,
						path = path,
						range = { i - 1, 0, i - 1, #line },
						type = "test",
					})
				end
			end
		end
	end

	return lib.positions.parse(positions)
end

function adapter.build_spec(args)
	local position = args.tree:data()
	local command = { "robot" }

	-- Create output directory
	local output_dir = vim.fn.tempname()
	vim.fn.mkdir(output_dir, "p")

	-- Add test filter if running specific test
	if position.type == "test" then
		table.insert(command, "--test")
		table.insert(command, "*" .. position.name .. "*")
	end

	-- Add output options
	table.insert(command, "--consolecolors")
	table.insert(command, "off")
	table.insert(command, "--consolemarkers")
	table.insert(command, "off")
	table.insert(command, "--outputdir=" .. output_dir)
	table.insert(command, position.path)

	logger.info("Robot command: " .. table.concat(command, " "))

	return {
		command = command,
		context = {
			file = position.path,
			id = position.id,
			output_dir = output_dir,
		},
	}
end

function adapter.results(spec, result, _)
	local status = result.code == 0 and "passed" or "failed"

	-- Create output file
	local output = "== Robot Framework Test Results ==\n\n"

	local stdout = result.stdout and vim.trim(result.output) or ""
	local stderr = result.stderr and vim.trim(result.stderr) or ""

	if stdout ~= "" then
		output = output .. "STDOUT:\n" .. stdout .. "\n\n"
	end

	if stderr ~= "" then
		output = output .. "STDERR:\n" .. stderr .. "\n\n"
	end

	-- Check for Robot output files
	local log_file = spec.context.output_dir .. "/log.html"
	if vim.fn.filereadable(log_file) == 1 then
		output = output .. "Log file: " .. log_file .. "\n"
	end

	-- Write to temp file
	local output_file = vim.fn.tempname()
	local file = io.open(output_file, "w")
	if file then
		file:write(output)
		file:close()
	end

	-- Create results
	local results = {}
	results[spec.context.id] = {
		status = status,
		short = vim.fn.fnamemodify(spec.context.file, ":t") .. " (" .. status .. ")",
		output = output_file,
	}

	return results
end

return adapter
