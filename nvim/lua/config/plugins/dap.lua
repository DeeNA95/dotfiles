return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      {
        "rcarriga/nvim-dap-ui",
        dependencies = { "nvim-neotest/nvim-nio" },
        config = function()
          local dap = require("dap")
          local dapui = require("dapui")
          dapui.setup()

          -- Automatically open/close DAP UI
          dap.listeners.after.event_initialized["dapui_config"] = function()
            dapui.open()
          end
          dap.listeners.before.event_terminated["dapui_config"] = function()
            dapui.close()
          end
          dap.listeners.before.event_exited["dapui_config"] = function()
            dapui.close()
          end
        end,
      },
      {
        "theHamsta/nvim-dap-virtual-text",
        opts = { commented = true }, -- Show virtual text as comments
      },
      {
        "mfussenegger/nvim-dap-python",
        config = function()
          require("dap-python").setup("/usr/bin/python3") -- Path to python
          require("dap-python").test_runner = "pytest"
        end,
      },
      {
        "leoluz/nvim-dap-go",
        config = true, -- Automatically calls setup()
      },
    },
    keys = {
      { "<F5>", function() require("dap").continue() end, desc = "Debug: Start/Continue" },
      { "<F10>", function() require("dap").step_over() end, desc = "Debug: Step Over" },
      { "<F11>", function() require("dap").step_into() end, desc = "Debug: Step Into" },
      { "<F12>", function() require("dap").step_out() end, desc = "Debug: Step Out" },
      { "<leader>b", function() require("dap").toggle_breakpoint() end, desc = "Debug: Toggle Breakpoint" },
      { "<leader>B", function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, desc = "Debug: Set Breakpoint Condition" },
      { "<leader>dr", function() require("dap").repl.open() end, desc = "Debug: Open REPL" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "Debug: Toggle UI" },
    },
    config = function()
      local dap = require("dap")

      -- C/C++/CUDA/Rust configuration (via codelldb)
      local mason_path = vim.fn.stdpath("data") .. "/mason"
      local codelldb_path = mason_path .. "/bin/codelldb"

      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = codelldb_path,
          args = { "--port", "${port}" },
        },
      }

      -- Shared launch config for C, C++, CUDA, and Rust
      local codelldb_config = {
        {
          name = "Launch executable",
          type = "codelldb",
          request = "launch",
          program = function()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
        },
        {
          name = "Attach to process",
          type = "codelldb",
          request = "attach",
          pid = require("dap.utils").pick_process,
          cwd = "${workspaceFolder}",
        },
      }

      dap.configurations.c = codelldb_config
      dap.configurations.cpp = codelldb_config
      dap.configurations.cuda = codelldb_config
      dap.configurations.rust = codelldb_config

      -- Bash configuration (via bash-debug-adapter)
      dap.adapters.bashdb = {
        type = "executable",
        command = mason_path .. "/bin/bash-debug-adapter",
        name = "bashdb",
      }

      dap.configurations.sh = {
        {
          name = "Launch Bash script",
          type = "bashdb",
          request = "launch",
          program = "${file}",
          cwd = "${workspaceFolder}",
          pathBashdb = mason_path .. "/packages/bash-debug-adapter/extension/bashdb_dir/bashdb",
          pathBashdbLib = mason_path .. "/packages/bash-debug-adapter/extension/bashdb_dir",
          pathBash = "bash",
          pathCat = "cat",
          pathMkfifo = "mkfifo",
          pathPkill = "pkill",
          env = {},
          args = {},
        },
      }
    end,
  },
}
