local Path = require("plenary.path")
local lib = require("neotest.lib")

---@type neotest.Adapter
local RobotAdapter = { name = "neotest-robotframework" }

function RobotAdapter.root(dir)
  -- Look for robot.yaml, robot configuration files, or robot test files
  return lib.files.match_root_pattern("robot.yaml", "*.robot")(dir)
end

function RobotAdapter.filter_dir(name, rel_path, root)
  -- Skip common directories that are unlikely to contain test files
  return name ~= "node_modules" and name ~= ".git" and name ~= "venv" and name ~= "__pycache__"
end

function RobotAdapter.is_test_file(file_path)
  -- Robot Framework test files typically end with .robot extension
  return vim.endswith(file_path, ".robot")
end

function RobotAdapter.discover_positions(file_path)
  -- Parse the robot file to find test cases and test suites
  if not RobotAdapter.is_test_file(file_path) then
    return nil
  end
  
  local file_data = lib.files.read(file_path)
  if not file_data then
    return nil
  end
  
  local tree = lib.positions.new_tree()
  local file = {
    type = "file",
    path = file_path,
    name = vim.fn.fnamemodify(file_path, ":t"),
  }
  tree:add_position(file)
  
  local in_test_cases_section = false
  local in_settings_section = false
  local current_test = nil
  local lines = vim.split(file_data, "\n")
  
  -- Try to extract suite name from Settings/Documentation if available
  local suite_name = vim.fn.fnamemodify(file_path, ":t:r")
  local suite_doc = ""
  
  for i, line in ipairs(lines) do
    local trimmed_line = vim.trim(line)
    
    -- Check for section headers
    if vim.startswith(trimmed_line:lower(), "*** test cases ***") then
      in_test_cases_section = true
      in_settings_section = false
    elseif vim.startswith(trimmed_line:lower(), "*** settings ***") or 
           vim.startswith(trimmed_line:lower(), "*** setting ***") then
      in_settings_section = true
      in_test_cases_section = false
    elseif vim.startswith(trimmed_line, "***") then
      in_test_cases_section = false
      in_settings_section = false
    elseif in_settings_section and trimmed_line ~= "" and not vim.startswith(trimmed_line, "#") then
      -- Look for Documentation in settings
      local doc_match = trimmed_line:match("^Documentation%s+(.+)$")
      if doc_match then
        suite_doc = doc_match
        -- Update the file name/description with documentation if found
        file.name = suite_name .. " - " .. suite_doc
        tree:update_position(file)
      end
    elseif in_test_cases_section and trimmed_line ~= "" and not vim.startswith(trimmed_line, "#") then
      -- Lines that don't start with whitespace are test case names
      if not vim.startswith(trimmed_line, " ") and not vim.startswith(trimmed_line, "\t") then
        current_test = {
          type = "test",
          path = file_path,
          name = trimmed_line,
          range = {i - 1, 0, i - 1, #trimmed_line}
        }
        tree:add_position(current_test, file.id)
      end
    end
  end
  
  return tree
end

function RobotAdapter.build_spec(args)
  local position = args.tree:data()
  local command = {"robot"}
  
  if position.type == "test" then
    -- Run a specific test case
    local test_name = position.name
    -- Add output directory for results
    local output_dir = vim.fn.tempname()
    vim.fn.mkdir(output_dir, "p")
    
    return {
      command = command .. {"--test", vim.fn.shellescape(test_name), "--outputdir", output_dir, position.path},
      context = {
        file = position.path,
        test_name = test_name,
        output_dir = output_dir
      }
    }
  elseif position.type == "file" then
    -- Run all tests in a file
    local output_dir = vim.fn.tempname()
    vim.fn.mkdir(output_dir, "p")
    
    return {
      command = command .. {"--outputdir", output_dir, position.path},
      context = {
        file = position.path,
        output_dir = output_dir
      }
    }
  elseif position.type == "dir" then
    -- Run all tests in a directory
    local output_dir = vim.fn.tempname()
    vim.fn.mkdir(output_dir, "p")
    
    return {
      command = command .. {"--outputdir", output_dir, position.path},
      context = {
        dir = position.path,
        output_dir = output_dir
      }
    }
  end
end

function RobotAdapter.results(spec, result, tree)
  local results = {}
  
  -- Basic implementation: check if the robot command was successful
  local success = result.code == 0
  
  -- Try to parse output.xml file if available
  if spec.context.output_dir then
    local output_xml = Path:new(spec.context.output_dir, "output.xml")
    if output_xml:exists() then
      -- In a full implementation, we would parse the XML here
      -- For MVP, we'll just use the exit code
    end
  end
  
  if spec.context.test_name then
    -- A specific test was run
    local test_id = tree:find_by(function(node)
      return node.type == "test" and node.name == spec.context.test_name and node.path == spec.context.file
    end)
    
    if test_id then
      results[test_id] = {
        status = success and "passed" or "failed",
        output = result.output,
      }
    end
  else
    -- A file or directory was run
    -- For MVP, mark all tests as either passed or failed based on exit code
    for _, node in tree:iter_nodes() do
      if node.type == "test" and 
         ((spec.context.file and node.path == spec.context.file) or 
          (spec.context.dir and vim.startswith(node.path, spec.context.dir))) then
        results[node.id] = {
          status = success and "passed" or "failed",
          output = result.output,
        }
      end
    end
  end
  
  -- Clean up output directory
  if spec.context.output_dir and Path:new(spec.context.output_dir):exists() then
    vim.fn.delete(spec.context.output_dir, "rf")
  end
  
  return results
end

return RobotAdapter
