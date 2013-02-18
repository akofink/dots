#!/bin/bash

declare -a files=('.gitconfig' '.zshrc')

if [[ $1 = "--dry-run" || $1 = "-d" ]]; then
	echo "This is a dry run."
	dry=1
fi

for i in "${files[@]}"
do
	if [ -e "${HOME}/${i}" ]; then
	echo "Moving ${HOME}/${i} to ${i}.old"
		if [ ! $dry ]; then
			mv "${HOME}/${i}" "${i}.old"
		fi
	fi

	if [ ! -L "${HOME}/${i}" ]; then
		echo "Creating symlink from ${HOME}/dots/${i}_ubuntu to ${HOME}/${i}"
		if [ ! $dry ]; then
			ln -s "${HOME}/dots/${i}_ubuntu" "${HOME}/${i}"
		fi
	fi
done