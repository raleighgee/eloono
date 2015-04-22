require File.expand_path '../app.rb', __FILE__

log = File.new("log/app.log", "a+")
#$stdout.reopen(log)
$stderr.reopen(log)

run Sinatra::Application
