#!/usr/bin/env ruby
require_relative "support/isolated-tmux"

server = IsolatedTmux.new("failure")
begin
  server.with_server { raise "intentional test failure" }
  raise "test failure was swallowed"
rescue RuntimeError => error
  raise unless error.message == "intentional test failure"
end
_, _, present = server.raw("has-session")
raise "server survived test failure" if present.success?

server = IsolatedTmux.new("timeout")
begin
  server.with_server(timeout: 0.5) { sleep 3 }
  raise "timeout was swallowed"
rescue Timeout::Error
  _, _, present = server.raw("has-session")
  raise "server survived timeout" if present.success?
end
server = IsolatedTmux.new("watchdog")
begin
  server.with_server(timeout: 5, watchdog_timeout: 0.8) { sleep 3 }
  raise "watchdog deadline was swallowed"
rescue RuntimeError => error
  raise unless error.message.start_with?("watchdog timeout;")
end

server = IsolatedTmux.new("stalled")
begin
  server.with_server do |private_server|
    pid = private_server.command("display-message", "-p", "-t", private_server.window, '#{pid}').to_i
    raise "invalid isolated server pid" unless pid > 1
    Process.kill("STOP", pid)
    raise "intentional stalled-server failure"
  end
rescue RuntimeError => error
  raise unless error.message == "intentional stalled-server failure"
end

orphan = nil
server = IsolatedTmux.new("orphan")
begin
  server.with_server do |private_server|
    # A harmless sleeping child with the exact namespaced helper marker.
    orphan = Process.spawn("ruby", "-e", "sleep 30", "--", "ai-quota-layout.rb", "--socket", private_server.socket,
                           out: File::NULL, err: File::NULL)
    sleep 0.1
    raise "intentional orphan cleanup failure"
  end
rescue RuntimeError => error
  raise unless error.message == "intentional orphan cleanup failure"
ensure
  Timeout.timeout(2) { Process.waitpid(orphan) } if orphan
end
puts "tmuxinator-ai-cleanup-test: failure, timeout, watchdog, stalled server, orphan cleanup: ok"
