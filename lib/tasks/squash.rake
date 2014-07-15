namespace :squash do
  desc "notify a release"
  task :notify, [:revision, :host] => :environment do |t, options|
    puts "Running in env #{Rails.env} and with options #{options}"
    Squash::Ruby.notify_deploy Rails.env, options[:revision], options[:host]
  end
end
