# coding: utf-8

desc "Publish via rsync"
task :deploy do
  user = "rockwood"
  server = "50.56.110.128"
  remote_path = "~/domains/rockwood.me/public"
  sh("rsync -e 'ssh -p 2222' --compress --recursive --checksum --delete _site/ #{user}@#{server}:#{remote_path}")
end
