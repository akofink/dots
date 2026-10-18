#!/usr/bin/env ruby
# Run this small capped regression before any broader geometry tests.
require_relative "support/isolated-tmux"
require_relative "../templates/tmuxinator/ai-quota-layout"

IsolatedTmux.new("reentry").with_server do |server|
  window = server.window
  command = server.method(:command)
  4.times do
    command.call("split-window", "-d", "-v", "-t", window, "sleep 120")
    command.call("select-layout", "-t", window, "even-vertical")
  end
  command.call("resize-window", "-t", window, "-x", "160", "-y", "67")
  panes = command.call("list-panes", "-t", window, "-F", '#{pane_id}').lines.map(&:strip)
  desired = AiQuotaLayout.layout(160, 67, panes)
  AiQuotaLayout.run(window, install: true, socket: server.socket)
  server.wait_for do
    command.call("show-options", "-w", "-v", "-t", window, "@ai-quota-busy") == "0" &&
      AiQuotaLayout.matches?(command.call("display-message", "-p", "-t", window, '#{window_layout}'), desired)
  end

  # Prove select-layout cannot enqueue our hooks even when idempotence is
  # deliberately defeated. A sentinel would survive any too-early flag reset.
  command.call("set-option", "-w", "-t", window, "@test-recursed", "0")
  AiQuotaLayout::EVENTS.each do |event|
    command.call("set-hook", "-w", "-t", window, "#{event}[90]",
                 "set-option -w -t #{window} @test-recursed 1")
  end
  singleton = AiQuotaLayout.singleton_class
  singleton.alias_method(:original_matches?, :matches?)
  singleton.define_method(:matches?) { |_current, _desired| false }
  begin
    AiQuotaLayout.apply(window)
  ensure
    singleton.alias_method(:matches?, :original_matches?)
    singleton.remove_method(:original_matches?)
  end
  sleep 0.1
  raise "self-generated event enqueued a hook" unless command.call("show-options", "-w", "-v", "-t", window, "@test-recursed") == "0"

  # External triggers must coalesce before launching background processes.
  12.times { command.call("select-layout", "-t", window, "tiled") }
  server.wait_for do
    command.call("show-options", "-w", "-v", "-t", window, "@ai-quota-busy") == "0" &&
      AiQuotaLayout.matches?(command.call("display-message", "-p", "-t", window, '#{window_layout}'), desired)
  end
  sleep 0.5
  raise "helper did not release gate" unless command.call("show-options", "-w", "-v", "-t", window, "@ai-quota-busy") == "0"
  puts "tmuxinator-ai-reentrancy-test: source suppression and async coalescing: ok"
end
