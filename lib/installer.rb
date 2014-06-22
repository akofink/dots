require './lib/dots_config.rb'

class Installer
  include DotsConfig

  def initialize(args)
    @args = args
  end

  def self.install(args)
    installer(args).install
  end

  def self.usage
    installer.usage
  end

  def install
    puts "#{black}This is a dry run!" if dry_run?
    install_dependencies
    copy_erb_files
    copy_verbatim_files
  end

  def usage
    puts <<-USAGE
      usage: ./bin/install.rb [options]
      options:
        -h\tDisplay this help text
        -d\tDry run: don't install anything
    USAGE
  end

  def dry_run?
    @args.include? "-d"
  end

  private

  def self.installer(args = {})
    Installer.new(args)
  end

  def install_dependencies
  end

  def copy_erb_files
    require 'erb'
    require 'fileutils'
    erb_file_pairs do |old, new|
      puts "#{black}Writing #{cyan}#{new}#{black} from #{cyan}#{old}#{black}"
      unless dry_run?
        FileUtils.rm_rf new
        File.open new, 'w' do |file|
          file.write(ERB.new(File.read old).result(binding))
        end
      end
    end
  end

  def copy_verbatim_files
    require 'fileutils'
    verbatim_file_pairs do |old, new|
      puts "#{black}Copying #{cyan}#{new}#{black} from #{cyan}#{old}#{black}"
      unless dry_run?
        FileUtils.rm_rf new
        FileUtils.cp_r old, new
      end
    end
  end

  private

  def osx?
    akmacpro? || akscimed?
  end

  def akmacpro?
    host[/akmacpro/]
  end

  def akkit?
    host[/akkit/]
  end

  def akscimed?
    host[/akscimed/]
  end

  def host
    `echo $HOST`
  end

  def erb_file_pairs
    config.erbs.map do |old, new|
      yield File.expand_path("config/#{old}.erb"), File.expand_path("#{new}/#{old}")
    end
  end

  def verbatim_file_pairs
    config.symlinks.map do |old, new|
      yield File.expand_path("config/#{old}"), File.expand_path("#{new}/#{old}")
    end
  end

  def cyan
    "\033[0;36m"
  end

  def black
    "\033[1;30m"
  end
end
