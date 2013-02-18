#!/bin/bash

current_file='.gitconfig'
if [ -f "~/$current_file" ]; then
	mv "~/$current_file" "$current_file.old"
fi
if [ ! -L "~/$current_file" ]; then
	ln -s "~/dots/$current_file_ubuntu" "~/$current_file"
fi

current_file='.zshrc'
if [ -f "~/$current_file" ]; then
	mv "~/$current_file" "$current_file.old"
fi
if [ ! -L "~/$current_file" ]; then
	ln -s "~/dots/$current_file_ubuntu" "~/$current_file"
fi