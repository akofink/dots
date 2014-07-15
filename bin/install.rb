#!/usr/bin/env ruby

require './lib/installer.rb'

if ARGV[0] == "-h"
  Installer.usage
else
  Installer.install ARGV
end
