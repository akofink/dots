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
    raise "missing tmux socket" if @socket.to_s.empty?
    output, error, status = Open3.capture3("tmux", "-S", @socket, *args)
    raise error unless status.success?
    output.strip
  end

  EVENTS = %w[window-resized window-layout-changed].freeze

  def hook(window)
    command = ["ruby", File.realpath(__FILE__), "--socket", @socket, window].shelljoin
    # The gate is acquired in tmux's command queue BEFORE run-shell -b can
    # launch a process. Events during a run coalesce into one pending bit.
    pending = ["set-option", "-w", "-t", window, "@ai-quota-pending", "1"].shelljoin
    launch = ["set-option", "-w", "-t", window, "@ai-quota-busy", "1"].shelljoin +
             " ; " + ["run-shell", "-b", command].shelljoin
    ["if-shell", "-F", "-t", window, '#{==:#{@ai-quota-busy},1}', pending, launch].shelljoin
  end

  def hook_commands(window, value)
    EVENTS.flat_map do |event|
      ["set-hook", "-w", "-t", window, "#{event}[90]", value, ";"]
    end
  end

  def apply(window)
    state = tmux("display-message", "-p", "-t", window,
                 "\#{window_width} \#{window_height} \#{window_zoomed_flag} \#{pane-border-status}").split
    return if state[2] == "1"

    panes = tmux("list-panes", "-t", window, "-F", "\#{pane_id}").lines.map(&:strip)
    desired = layout(state[0].to_i, state[1].to_i, panes, state[3])
    return unless desired
    return if matches?(tmux("display-message", "-p", "-t", window, "\#{window_layout}"), desired)

    # Suppress our hooks AT THE EVENT SOURCE, not with a flag reset before
    # an async hook executes. tmux resolves hooks synchronously when the
    # event fires. This single command group cannot enqueue our own hook
    # for select-layout (or the resize events it may cause).
    commands = hook_commands(window, "") + ["select-layout", "-t", window, desired, ";"] +
               hook_commands(window, hook(window))
    tmux(*commands.take(commands.length - 1))
  end

  def run(target, install: false, socket: nil)
    @socket = socket || ENV.fetch("TMUX", "").split(",").first
    # Resolve once from the invoking quota pane, never from client focus.
    window = tmux("display-message", "-p", "-t", target, "\#{window_id}")
    raise "cannot resolve quota window" unless window.match?(/\A@\d+\z/)
    if install
      commands = hook_commands(window, hook(window))
      tmux(*commands.take(commands.length - 1))
      tmux(*Shellwords.split(hook(window)))
      return
    end

    begin
      loop do
        tmux("set-option", "-w", "-t", window, "@ai-quota-pending", "0")
        apply(window)
        # Check pending and release the gate atomically in tmux. A resize
        # cannot be lost between reading the bit and releasing ownership.
        again = ["set-option", "-w", "-t", window, "@ai-quota-pending", "0"].shelljoin +
                " ; display-message -p again"
        done = ["set-option", "-w", "-t", window, "@ai-quota-busy", "0"].shelljoin +
               " ; display-message -p done"
        result = tmux("if-shell", "-F", "-t", window, '#{==:#{@ai-quota-pending},1}', again, done)
        break if result == "done"
      end
    rescue StandardError
      # Fail closed: errors must not leave an active hook retrying forever.
      commands = hook_commands(window, "") + ["set-option", "-w", "-t", window, "@ai-quota-busy", "0"]
      tmux(*commands) rescue nil
      raise
    end
  end
end

if $PROGRAM_NAME == __FILE__
  install = ARGV.delete("--install")
  socket = ARGV.shift(2).last if ARGV.first == "--socket"
  abort "usage: #{$PROGRAM_NAME} [--install] [--socket path] pane-or-window-id" unless ARGV.length == 1 && ARGV[0].match?(/\A[%@]\d+\z/)
  AiQuotaLayout.run(ARGV[0], install: install, socket: socket)
end
