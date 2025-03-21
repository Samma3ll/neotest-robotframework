-- ~/.config/nvim/lua/neotest-robotframework/init.lua

local lib = require("neotest.lib")
local logger = require("neotest.logging")

---@type neotest.Adapter
local adapter = { name = "robotframework" }

function adapter.root(dir)
	return dir
end

function adapter.is_test_file(file_path)
	if file_path == nil then
		return false
	end
	return vim.endswith(file_path, ".robot")
end

function adapter.discover_positions(path)
	logger.info("Discovering positions for Robot file: " .. path)

	-- Read file content
	local content = lib.files.read_sync(path)
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
		-- Process potential test cases
		elseif in_test_section then
			-- Test cases start with non-whitespace
			if line:match("^[^%s]") and not line:match("^%s*#") then
				local test_name = line:match("^([^%s]+)")
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
		table.insert(command, position.name)
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

function adapter.results(spec, result, tree)
	local status = result.code == 0 and "passed" or "failed"

	-- Create output file
	local output = "== Robot Framework Test Results ==\n\n"

	if result.stdout and result.stdout ~= "" then
		output = output .. "STDOUT:\n" .. result.stdout .. "\n\n"
	end

	if result.stderr and result.stderr ~= "" then
		output = output .. "STDERR:\n" .. result.stderr .. "\n\n"
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
