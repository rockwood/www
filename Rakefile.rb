# coding: utf-8

desc "Publish via rsync"
task :deploy do
  user = "rockwood"
  server = "50.56.110.128"
  local_path = ENV.fetch("LOCAL_PATH", "_site")
  remote_path = "~/domains/rockwood.me/public"
  sh("rsync -e 'ssh -p 2222' --compress --recursive --checksum --delete #{local_path} #{user}@#{server}:#{remote_path}")
end
