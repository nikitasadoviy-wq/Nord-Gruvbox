-- ============================================================================
-- Nord-Gruvbox Neovim Config (LazyVim + GenesisNvim inspired modules)
-- ============================================================================

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Загальні налаштування редактора
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.cursorline = true

require("lazy").setup({
  spec = {
    -- 1. Базовий фреймворк LazyVim
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },

    -- 2. Наша тема Gruvbox (як основна під палітру райсу)
    { 
      "ellisonleao/gruvbox.nvim",
      opts = {
        contrast = "hard",
        transparent_mode = true, -- Прозорість для гармонії з Alacritty та Picom
      },
    },
    {
      "LazyVim/LazyVim",
      opts = {
        colorscheme = "gruvbox",
      },
    },

    -- 3. GenesisNvim-inspired: Покращений UI та додаткові утиліти
    -- Дерево файлів (neo-tree або nvim-tree, у LazyVim за замовчуванням neo-tree)
    {
      "nvim-neo-tree/neo-tree.nvim",
      opts = {
        window = {
          position = "left",
          width = 30,
        },
      },
    },

    -- Іконки та статус-лайн (lualine) у стилі мінімалізму
    {
      "nvim-lualine/lualine.nvim",
      opts = {
        options = {
          theme = "gruvbox",
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
        },
      },
    },

    -- Швидкий пошук та навігація (telescope)
    {
      "nvim-telescope/telescope.nvim",
      opts = {
        defaults = {
          layout_strategy = "horizontal",
          layout_config = { prompt_position = "top" },
          sorting_strategy = "ascending",
        },
      },
    },

    -- Підсвічування синтаксису (Treesitter)
    {
      "nvim-treesitter/nvim-treesitter",
      opts = {
        ensure_installed = { "lua", "python", "rust", "c", "cpp", "bash", "json", "markdown" },
        highlight = { enable = true },
        indent = { enable = true },
      },
    },
  },
  defaults = {
    lazy = false,
    version = false,
  },
  checker = { enabled = false },
})
