# Native notebooks in Neovim

The editable source of a notebook is a percent-format Python file. Jupytext keeps the
matching `.ipynb` file interoperable with Jupyter, while Molten executes code and renders
outputs inside Neovim.

## Setup

Run `./install_deps.sh` once. It creates `~/.local/share/nvim/python3` with `uv`,
installs the isolated Neovim provider, Molten dependencies, and Jupytext, and registers
Molten when the plugin is already installed. On a fresh setup, lazy.nvim performs the
registration when it installs Molten on first launch.

## Start a notebook

1. Create and save a Python file, such as `analysis.py`.
2. Add cells with `# %%`; use `# %% [markdown]` for prose cells.
3. Run `:NotebookPair` once. This creates `analysis.ipynb` and records the
   `ipynb,py:percent` pairing. If an unpaired `analysis.ipynb` already exists, the command
   refuses to guess; inspect it and use `:NotebookPair!` only when pairing is intentional.
4. Initialize a kernel with `<leader>mi`.
5. Run the current cell with `<leader>mr`, or run it and move forward with `<leader>mj`.
6. Use `<leader>ms` to update the `.ipynb` from the Python source. If Molten is active,
   its outputs are exported after the code is synchronized.

The Python file is deliberately authoritative during `:NotebookSync`; a newer notebook
will not silently replace source code. Opening an `.ipynb` directly still works through
Jupytext and uses percent formatting, but the paired `.py` workflow is the durable path.
Do not edit both members of one pair in separate Neovim buffers at the same time; close
the `.py` buffer before directly editing its `.ipynb` partner.

## Commands and keys

| Action | Command | Key |
| --- | --- | --- |
| Pair Python and notebook files | `:NotebookPair` | — |
| Sync code and active outputs | `:NotebookSync` | `<leader>ms` |
| Initialize a kernel | `:MoltenInit` | `<leader>mi` |
| Run current code cell | `:NotebookRunCell` | `<leader>mr` |
| Run current cell and advance | `:NotebookRunCellAndAdvance` | `<leader>mj` |
| Run every code cell | `:NotebookRunAll` | `<leader>mA` |
| Move between cell markers | `:NotebookNextCell` / `:NotebookPrevCell` | `]m` / `[m` |
| Interrupt / restart kernel | `:MoltenInterrupt` / `:MoltenRestart` | `<leader>mk` / `<leader>mR` |
| Open / hide output | `:MoltenEnterOutput` / `:MoltenHideOutput` | `<leader>mo` / `<leader>mh` |
| Open rich HTML output in a browser | `:MoltenOpenInBrowser` | `<leader>mB` |

Markdown and raw cells are skipped by execution commands. Inline images and plots use
`image.nvim`; complex JavaScript widgets and comm-based HTML remain browser-rendered.
