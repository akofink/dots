# Only uniquely named private servers. A detached watchdog survives parent exit,
# detects more than eight helpers, and verifies server AND helper cleanup.
require "open3"
require "securerandom"
require "timeout"

class IsolatedTmux
  attr_reader :window, :socket

  def initialize(label)
    @name = "dots-ai-#{label}-#{Process.pid}-#{SecureRandom.hex(4)}"
  end

  def bounded(*args)
    input, output, error, child = Open3.popen3(*args)
    input.close
    readers = [Thread.new { output.read }, Thread.new { error.read }]
    Timeout.timeout(2) { [readers[0].value, readers[1].value, child.value] }
  ensure
    if child&.alive?
      Process.kill("KILL", child.pid) rescue nil
      child.join(1)
    end
    readers&.each do |thread|
      thread.kill if thread.alive?
      thread.join(1)
    end
    [input, output, error].compact.each { |io| io.close unless io.closed? }
  end

  def raw(*args)
    bounded("tmux", "-L", @name, *args)
  end

  def command(*args)
    out, err, status = raw(*args)
    raise err unless status.success?
    out.strip
  end

  def processes
    out, _, status = bounded("ps", "-axo", "pid=,ppid=,command=")
    raise "cannot inspect isolated processes" unless status.success?
    out.lines.filter_map do |line|
      pid, ppid, command = line.strip.split(/\s+/, 3)
      [pid.to_i, ppid.to_i, command] if command
    end
  end

  def helper?(command)
    command.include?("ai-quota-layout.rb --socket ") && command.include?(@name)
  end

  def server?(ppid, command)
    ppid == 1 && command.match?(/\A(?:\S*\/)?tmux(?:\s|:)/) && command.include?(@name)
  end

  def cleanup
    raw("kill-server") rescue Timeout::Error
    # A stalled server may not service kill-server. Only signal a daemon
    # whose freshly verified command names this unique private socket.
    owned = processes.select { |_pid, ppid, cmd| server?(ppid, cmd) || helper?(cmd) }
    owned.each { |pid, _ppid, _cmd| Process.kill("TERM", pid) rescue nil }
    sleep 0.1 unless owned.empty?
    processes.each do |pid, ppid, cmd|
      next unless owned.any? { |old_pid, _, _| old_pid == pid }
      Process.kill("KILL", pid) if server?(ppid, cmd) || helper?(cmd)
    rescue Errno::ESRCH
      nil
    end
    _, _, present = raw("has-session")
    helpers = processes.count { |_pid, _ppid, cmd| helper?(cmd) }
    !present.success? && helpers.zero?
  end

  def wait_for
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
    until yield
      raise "layout did not settle" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.05
    end
  end

  def with_server(timeout: 20, watchdog_timeout: timeout + 5)
    _, _, exists = raw("has-session")
    raise "refusing existing isolated server" if exists.success?
    control_read, control_write = IO.pipe
    result_read, result_write = IO.pipe
    owner = Process.pid
    watchdog = fork do
      Process.setsid
      control_write.close
      result_read.close
      peak = 0
      reason = "normal"
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + watchdog_timeout
      begin
        loop do
          count = processes.count { |_pid, _ppid, cmd| helper?(cmd) }
          peak = [peak, count].max
          if count > 8 || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
            reason = count > 8 ? "helper cap exceeded: #{count}" : "watchdog timeout"
            Process.kill("TERM", owner) rescue nil
            break
          end
          break if IO.select([control_read], nil, nil, 0.03)
        end
      ensure
        absent = cleanup
        result_write.puts("#{reason}; peak=#{peak}; server-and-helpers-absent=#{absent}") rescue nil
        result_write.close
        control_read.close
      end
      exit! 0
    end
    control_read.close
    result_write.close
    previous_term = Signal.trap("TERM") { raise "isolated tmux watchdog stopped this test" }
    begin
      Timeout.timeout(timeout) do
        @window = command("-f", "/dev/null", "new-session", "-d", "-P", "-F", '#{window_id}',
                          "-s", "quota-test", "-x", "160", "-y", "68", "sleep 120")
        @socket = command("display-message", "-p", "-t", @window, '#{socket_path}')
        command("set-option", "-w", "-t", @window, "window-size", "manual")
        yield self
      end
    ensure
      absent = cleanup
      control_write.close
      outcome = Timeout.timeout(12) { result_read.read.strip }
      result_read.close
      Process.waitpid(watchdog)
      Signal.trap("TERM", previous_term)
      puts "isolated-tmux: #{outcome}"
      raise "isolated cleanup failed" unless absent && outcome.end_with?("server-and-helpers-absent=true")
      raise outcome unless outcome.start_with?("normal;")
    end
  end
end
