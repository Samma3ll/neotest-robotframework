local adapter = {
	name = "robotframework",
	-- Required methods
	is_test_file = function(file_path)
		-- Return true if file_path is a test file
		return vim.endswith(file_path, ".robot")
	end,

	find_positions = function(file_path)
		-- Return test positions tree
	end,

	build_spec = function(args)
		-- Return test run spec
	end,

	results = function(spec, result, tree)
		-- Parse test results
	end,

	root = function(dir)
		-- Return project root directory
		-- Look for robot.conf or similar
		return dir
	end,
}

local create_adapter = function(opts)
	return adapter
end

return create_adapter
