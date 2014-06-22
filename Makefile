default:
	@echo "Copy the following line, then press enter, and paste it in the file that gets opened:"
	@echo
	@echo "*/30 * * * * cd ~/dots && ./test_update"
	@echo
	@read
	@crontab -e

install:
	- ./bin/install.rb || echo "Make sure a current version of Ruby is installed (https://www.ruby-lang.org/en)."

