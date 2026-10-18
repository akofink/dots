#!/usr/bin/env ruby

require "erb"
require "yaml"

repo_root = File.expand_path("..", __dir__)
template = File.join(repo_root, "templates/tmuxinator/ai.yml")
legacy_alias = File.join(repo_root, "templates/tmuxinator/agent.yml")

raise "agent.yml must remain an alias of ai.yml" unless File.symlink?(legacy_alias) && File.readlink(legacy_alias) == "ai.yml"

[
  [[], {}, nil, "ai", "~/dev/"],
  [["dormancy"], {}, nil, "ai-dormancy", "~/dev/"],
  [["BBCEEP-1234"], {}, nil, "ai-BBCEEP-1234", "~/dev/"],
  [[" cleanup-old-flags "], {}, nil, "ai-cleanup-old-flags", "~/dev/"],
  [["   "], {}, nil, "ai", "~/dev/"],
  [["dormancy"], {"root" => "/example/project"}, nil, "ai-dormancy", "/example/project"],
  [[], {}, "work", "ai", "~/dev/"]
].each do |args, settings, machine_class, expected_name, expected_root|
  context = Object.new
  context.instance_variable_set(:@args, args)
  context.instance_variable_set(:@settings, settings)
  render = lambda do |path|
    previous_machine_class = ENV["MACHINE_CLASS"]
    machine_class.nil? ? ENV.delete("MACHINE_CLASS") : ENV["MACHINE_CLASS"] = machine_class
    YAML.safe_load(ERB.new(File.read(path)).result(context.instance_eval { binding }))
  ensure
    previous_machine_class.nil? ? ENV.delete("MACHINE_CLASS") : ENV["MACHINE_CLASS"] = previous_machine_class
  end
  config = render.call(template)
  raise "unexpected session name: #{config['name']}" unless config["name"] == expected_name
  raise "unexpected root: #{config['root']}" unless config["root"] == expected_root
  raise "legacy alias rendered differently" unless render.call(legacy_alias) == config

  first_window = config.fetch("windows").first.fetch("zsh")
  expected_panes = [
    {"dev" => ["cd #{expected_root}"]},
    {"notes" => ["cd ~/dev/repos/notes"]},
    {"dots" => ["cd ~/dev/repos/dots"]},
    {"sandbox" => ["cd ~/dev/repos/sandbox"]}
  ]
  if machine_class == "work"
    raise "work window 1 changed" unless first_window == {"layout" => "even-vertical", "panes" => expected_panes}
  else
    raise "personal quota pane or layout missing" unless first_window == {
      "layout" => "main-horizontal",
      "panes" => ["npx -y quota-axi --tui --provider claude,codex,grok,copilot", *expected_panes]
    }
  end

  puts "tmuxinator-ai-test: #{args.inspect}, #{settings.inspect}, MACHINE_CLASS=#{machine_class || 'unset'} -> #{expected_name}, root #{expected_root}"
end

puts "tmuxinator-ai-test: ok"
