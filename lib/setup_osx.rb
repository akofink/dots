#!/usr/bin/env ruby

require 'yaml'

platform="osx"
dry = false
home = ENV['HOME']
host = `printf $HOSTNAME`.gsub('.local', '')
env = YAML.load(File.read('environment.yml'))[host]
puts env.inspect

files = [
  '.env',
  '.gemrc',
  '.gitconfig',
  '.gitignore',
  '.NERDTreeBookmarks',
  '.tmux.conf',
  '.tmuxinator',
  '.vim',
  '.vimrc',
  '.zshrc'
]

if ARGV.include?("--dry-run") || ARGV.include?("-d")
  puts "This is a dry run."
  dry = true
end

files.each do |file|
  if File.exists?("#{home}/#{file}")
    puts "Moving #{home}/#{file} to #{home}/#{file}.old"
    unless dry
      mv "#{home}/#{file}" "#{home}/#{file}.old"
    end
  end

  puts "Creating symlink from #{home}/dots/#{file}_#{platform} to #{home}/#{file}"
  unless dry
    `ln -s '#{home}/dots/#{file}_#{platform}' '#{home}/#{file}'`
  end
end
