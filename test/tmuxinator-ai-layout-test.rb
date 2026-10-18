#!/usr/bin/env ruby
# Exercise the real hooks on a private tmux server, never the operator's server.
require "open3"
require_relative "../templates/tmuxinator/ai-quota-layout"

socket_name = "dots-ai-layout-test-#{Process.pid}"
original_tmux = ENV["TMUX"]
started = false
command = lambda do |*args|
  out, err, status = Open3.capture3("tmux", "-L", socket_name, *args)
  raise err unless status.success?
  out.strip
end
wait_for = lambda do |&check|
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 8
  until check.call
    raise "layout did not settle" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
    sleep 0.05
  end
end

begin
  _, _, exists = Open3.capture3("tmux", "-L", socket_name, "has-session")
  raise "refusing an existing test server" if exists.success?
  window = command.call("-f", "/dev/null", "new-session", "-d", "-P", "-F", '#{window_id}',
                        "-s", "quota-test", "-x", "160", "-y", "68", "sleep 120")
  started = true
  socket = command.call("display-message", "-p", "-t", window, '#{socket_path}')
  ENV["TMUX"] = "#{socket},0,0"
  command.call("set-option", "-w", "-t", window, "window-size", "manual")
  AiQuotaLayout.run(window, install: true)
  4.times do
    command.call("split-window", "-d", "-v", "-t", window, "sleep 120")
    command.call("select-layout", "-t", window, "even-vertical")
  end
  panes = command.call("list-panes", "-t", window, "-F", '#{pane_id}').lines.map(&:strip)
  active = panes[2]
  command.call("select-pane", "-t", active)
  verify = lambda do |width, height, border = "off"|
    command.call("resize-window", "-t", window, "-x", width.to_s, "-y", height.to_s)
    expected = AiQuotaLayout.layout(width, height, panes, border).split("[", 2).last.delete_suffix("]")
    rows = nil
    wait_for.call do
      geometry = command.call("list-panes", "-t", window, "-F",
                              '#{pane_id} #{pane_width} #{pane_height} #{pane_left} #{pane_top}')
      # Validate the same snapshot that matched, not a second read racing
      # an asynchronous layout hook from the preceding resize.
      rows = geometry.lines.map { |line| line.split.drop(1).map(&:to_i) }
      current = geometry.lines.each_with_index.map do |line, index|
        id, w, h, x, y = line.split
        top_status = border == "top" && index == 0 ? 1 : 0
        bottom_status = border == "bottom" && index == 4 ? 1 : 0
        "#{w}x#{h.to_i + top_status + bottom_status},#{x},#{y.to_i - top_status},#{id.delete_prefix('%')}"
      end.join(",")
      current == expected
    end
    raise "quota not full-width or too short" unless rows[0][0] == width && rows[0][1] >= 23
    raise "shells not full-width/equal" unless rows.drop(1).map { |row| row.take(3) }.uniq.length == 1
    raise "shells not full-width" unless rows.all? { |row| row[0] == width && row[2] == 0 }
    raise "active pane changed" unless command.call("display-message", "-p", "-t", window, '#{pane_id}') == active
    puts "tmuxinator-ai-layout-test: #{width}x#{height}, borders=#{border}: ok"
  end
  [[160, 67], [173, 70], [121, 46], [160, 31]].each { |size| verify.call(*size) }
  command.call("set-option", "-w", "-t", window, "pane-border-status", "top")
  verify.call(160, 44, "top")
  command.call("set-option", "-w", "-t", window, "pane-border-status", "bottom")
  verify.call(160, 44, "bottom")
  command.call("set-option", "-w", "-t", window, "pane-border-status", "off")
  verify.call(160, 67)
  # A later tmuxinator select-layout must not replace the custom stack.
  command.call("select-layout", "-t", window, "tiled")
  verify.call(160, 67)
  rejected = false
  begin
    AiQuotaLayout.run("@999999999", install: true)
  rescue RuntimeError
    rejected = true
  end
  raise "missing target must not fall back to current window" unless rejected
  # Scrollbars may reserve content columns, but must not cause a hook loop.
  _, _, scrollbars = Open3.capture3("tmux", "-L", socket_name, "show-options", "-w", "-t", window, "pane-scrollbars")
  if scrollbars.success?
    command.call("set-option", "-w", "-t", window, "pane-scrollbars", "on")
    command.call("resize-window", "-t", window, "-x", "161", "-y", "67")
    desired = AiQuotaLayout.layout(161, 67, panes)
    wait_for.call do
      AiQuotaLayout.matches?(command.call("display-message", "-p", "-t", window, '#{window_layout}'), desired)
    end
    AiQuotaLayout.run(window)
    AiQuotaLayout.run(window)
    puts "tmuxinator-ai-layout-test: reserved scrollbars: ok"
  end
  hooks = command.call("show-hooks", "-w", "-t", window)
  %w[window-resized window-layout-changed].each do |hook|
    raise "missing scoped hook #{hook}" unless hooks.include?("#{hook}[90]")
  end
ensure
  command.call("kill-server") if started
  original_tmux.nil? ? ENV.delete("TMUX") : ENV["TMUX"] = original_tmux
end
puts "tmuxinator-ai-layout-test: ok"
