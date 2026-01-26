local root = vim.fs.find({ "sudow.nvim" }, { upward = true })[1]
return {
	{
		"pynappo/sudow.nvim",
		dir = root,
	},
}
