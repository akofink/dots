module Env
  def osx?
    `uname`[/darwin/i]
  end

  def scimed?
    `hostname`[/scimed/]
  end
end
