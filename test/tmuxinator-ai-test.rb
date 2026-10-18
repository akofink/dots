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
  [[], {}, "personal", "ai", "~/dev/"],
  [[], {}, "work", "ai", "~/dev/"],
  [["work-check"], {"root" => "/example/project"}, "work", "ai-work-check", "/example/project"]
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
      "layout" => "even-vertical",
      "panes" => [{"quota" => [
        'ruby ~/.config/tmuxinator/ai-quota-layout.rb --install "$TMUX_PANE"',
        "npx -y quota-axi --tui --provider claude,codex,grok,copilot"
      ]}, *expected_panes]
    }
  end

  puts "tmuxinator-ai-test: #{args.inspect}, #{settings.inspect}, MACHINE_CLASS=#{machine_class || 'unset'} -> #{expected_name}, root #{expected_root}"
end

require_relative "../templates/tmuxinator/ai-quota-layout"

panes = %w[%10 %11 %12 %13 %14]
(31..120).each do |height|
  layout = AiQuotaLayout.layout(160, height, panes)
  checksum, body = layout.split(",", 2)
  sum = 0
  body.each_byte do |byte|
    sum = ((sum >> 1) + ((sum & 1) << 15) + byte) & 0xffff
  end
  raise "invalid layout checksum" unless checksum.to_i(16) == sum
  raise "legacy layout comparison failed" unless AiQuotaLayout.matches?(layout, layout)
  cells = body.scan(/160x(\d+),0,(\d+),(1[0-4])/).map { |cell| cell.map(&:to_i) }
  json = {"V" => 2, "L" => {"t" => "v", "c" => cells.map do |rows, top, id|
    {"t" => "p", "w" => 160, "h" => rows, "x" => 0, "y" => top, "I" => "%#{id}", "a" => true}
  end}}.to_json
  raise "JSON layout comparison failed" unless AiQuotaLayout.matches?(json, layout)
  raise "wrong pane order" unless cells.map(&:last) == (10..14).to_a
  raise "quota too short" unless cells.first[0] >= 23
  raise "unequal shells" unless cells.drop(1).map(&:first).uniq.length == 1
  y = 0
  cells.each do |rows, top, _id|
    raise "not stacked" unless top == y
    y += rows + 1
  end
  raise "wrong total height" unless y - 1 == height
end
raise "undersized window should be left alone" if AiQuotaLayout.layout(160, 30, panes)
raise "changed pane count should be left alone" if AiQuotaLayout.layout(160, 60, panes.take(4))
%w[top bottom].each do |status|
  raise "border-status minimum wrong" if AiQuotaLayout.layout(160, 31, panes, status)
  layout = AiQuotaLayout.layout(160, 32, panes, status)
  quota_height = status == "top" ? 24 : 23
  raise "border-status quota too short" unless layout.include?("[160x#{quota_height},0,0,10,")
end
puts "tmuxinator-ai-test: ok"
