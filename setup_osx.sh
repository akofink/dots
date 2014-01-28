#!/bin/bash

declare -a files=('.env' '.gemrc' '.gitconfig' '.gitignore' 'NERDTreeBookmarks' '.tmux.conf' '.tmuxinator' '.vim' '.vimrc' '.zshrc')
platform="osx"

if [[ $1 = "--dry-run" || $1 = "-d" ]]; then
	echo "This is a dry run."
	dry=1
fi

for i in "${files[@]}"
do
	if [[ -e "${HOME}/${i}" && ! -L "${HOME}/${i}" ]]; then
		echo "Moving ${HOME}/${i} to ${HOME}/${i}.old"
		if [ ! $dry ]; then
			mv "${HOME}/${i}" "${HOME}/${i}.old"
		fi
	elif [ -L "${HOME}/${i}" ]; then
		echo "${i} is already set up!"
		continue
	fi

	echo "Creating symlink from ${HOME}/dots/${i}_${platform} to ${HOME}/${i}"
	if [ ! $dry ]; then
		ln -s "${HOME}/dots/${i}_${platform}" "${HOME}/${i}"
	fi
done
