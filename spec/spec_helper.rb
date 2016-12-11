
RSpec.configure do |config|
  # Only accept expect syntax do not allow old should syntax
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

SUPPORT_PATH = File.expand_path(File.join(File.dirname(__FILE__), '..', 'support'))

def wait(time, increment = 5, elapsed_time = 0, &block)
  yield
rescue Exception => e
  if elapsed_time >= time
    raise e
  else
    sleep increment
    wait(time, increment, elapsed_time + increment, &block)
  end
end
