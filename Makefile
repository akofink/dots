default:
	@echo "Copy the following line, then press enter, and paste it in the file that gets opened:"
	@echo
	@echo "*/30 * * * * cd ~/dots && ./test_update"
	@echo
	@read
	@crontab -e

