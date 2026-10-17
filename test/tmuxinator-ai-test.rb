#!/usr/bin/env ruby

require "erb"
require "yaml"

repo_root = File.expand_path("..", __dir__)
template = File.join(repo_root, "templates/tmuxinator/ai.yml")
legacy_alias = File.join(repo_root, "templates/tmuxinator/agent.yml")

raise "agent.yml must remain an alias of ai.yml" unless File.symlink?(legacy_alias) && File.readlink(legacy_alias) == "ai.yml"

[
  [[], {}, "ai", "~/dev/"],
  [["dormancy"], {}, "ai-dormancy", "~/dev/"],
  [["BBCEEP-1234"], {}, "ai-BBCEEP-1234", "~/dev/"],
  [[" cleanup-old-flags "], {}, "ai-cleanup-old-flags", "~/dev/"],
  [["   "], {}, "ai", "~/dev/"],
  [["dormancy"], {"root" => "/example/project"}, "ai-dormancy", "/example/project"]
].each do |args, settings, expected_name, expected_root|
  context = Object.new
  context.instance_variable_set(:@args, args)
  context.instance_variable_set(:@settings, settings)
  render = lambda do |path|
    YAML.safe_load(ERB.new(File.read(path)).result(context.instance_eval { binding }))
  end
  config = render.call(template)
  raise "unexpected session name: #{config['name']}" unless config["name"] == expected_name
  raise "unexpected root: #{config['root']}" unless config["root"] == expected_root
  raise "legacy alias rendered differently" unless render.call(legacy_alias) == config

  puts "tmuxinator-ai-test: #{args.inspect}, #{settings.inspect} -> #{expected_name}, root #{expected_root}"
end

puts "tmuxinator-ai-test: ok"
