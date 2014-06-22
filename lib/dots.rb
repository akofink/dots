require './installer.rb'

class Dots
  def initialize
    @installer = Installer.new
  end

  def self.install
    @installer.install
  end
end
