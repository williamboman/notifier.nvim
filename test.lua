vim.notify("Hello world!")
vim.notify("I'm a plugin who've done something.", vim.log.levels.INFO, { title = "some-plugin" })
vim.notify(
	"This is an error, something went terribly terribly wrong and this is a very unhelpful error message informing you that something indeed went terribly wrong.",
	vim.log.levels.ERROR
)
vim.notify("You probably don't have to worry about this message.", vim.log.levels.WARN, { title = "test" })
