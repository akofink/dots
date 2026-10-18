#!/usr/bin/env ruby
# A full-width quota pane over four equally sized, full-width shells.
require "open3"
require "shellwords"
require "json"

module AiQuotaLayout
  module_function

  def layout(width, height, panes, border_status = "off")
    return unless panes.length == 5

    # Four separators, at least 23 visible quota rows, and at least one
    # visible row per shell. Give the quota pane the integer-row remainder.
    status_rows = border_status == "off" ? 0 : 1
    shell_height = (height - 4 - 23 - status_rows) / 4
    return if shell_height < 1

    bottom_status = border_status == "bottom" ? 1 : 0
    heights = [height - 4 - 4 * shell_height - bottom_status, *Array.new(4, shell_height)]
    heights[-1] += bottom_status
    y = 0
    cells = panes.zip(heights).map do |pane, rows|
      cell = "#{width}x#{rows},0,#{y},#{pane.delete_prefix('%')}"
      y += rows + 1
      cell
    end
    body = "#{width}x#{height},0,0[#{cells.join(',')}]"
    checksum = body.bytes.reduce(0) do |sum, byte|
      (((sum >> 1) | ((sum & 1) << 15)) + byte) & 0xffff
    end
    "%04x,%s" % [checksum, body]
  end

  def matches?(current, desired)
    return current == desired unless current.start_with?("{")

    # tmux 3.8 reports JSON, including raw layout-cell dimensions. Comparing
    # cells avoids content offsets from border status and reserved scrollbars.
    root = JSON.parse(current).fetch("L")
    return false unless root["t"] == "v" && root["c"]&.length == 5
    return false unless root["c"].all? { |cell| cell["t"] == "p" }

    cells = root["c"].map do |cell|
      "#{cell['w']}x#{cell['h']},#{cell['x']},#{cell['y']},#{cell.fetch('I').delete_prefix('%')}"
    end.join(",")
    cells == desired.split("[", 2).last.delete_suffix("]")
  end

  def tmux(*args)
    output, error, status = Open3.capture3("tmux", *args)
    raise error unless status.success?
    output.strip
  end

  def run(target, install: false)
    # Resolve once from the invoking quota pane, never from client focus.
    window = tmux("display-message", "-p", "-t", target, "\#{window_id}")
    raise "cannot resolve quota window" unless window.match?(/\A@\d+\z/)
    if install
      command = ["ruby", File.realpath(__FILE__), window].shelljoin
      hook = "run-shell -b #{command.shellescape}"
      # The second hook also corrects tmuxinator's final select-layout if
      # the quota shell starts before tmuxinator finishes creating panes.
      %w[window-resized window-layout-changed].each do |event|
        tmux("set-hook", "-w", "-t", window, "#{event}[90]", hook)
      end
    end
    state = tmux("display-message", "-p", "-t", window,
                 "\#{window_width} \#{window_height} \#{window_zoomed_flag} \#{pane-border-status}").split
    return if state[2] == "1"

    panes = tmux("list-panes", "-t", window, "-F", "\#{pane_id}").lines.map(&:strip)
    desired = layout(state[0].to_i, state[1].to_i, panes, state[3])
    return unless desired
    # A no-op prevents recursive window-layout-changed hooks.
    return if matches?(tmux("display-message", "-p", "-t", window, "\#{window_layout}"), desired)

    tmux("select-layout", "-t", window, desired)
  end
end

if $PROGRAM_NAME == __FILE__
  install = ARGV.delete("--install")
  abort "usage: #{$PROGRAM_NAME} [--install] pane-or-window-id" unless ARGV.length == 1 && ARGV[0].match?(/\A[%@]\d+\z/)
  AiQuotaLayout.run(ARGV[0], install: install)
end
