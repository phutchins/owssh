Gem::Specification.new do |s|
  s.name    = 'owssh'
  s.version = '0.0.28'
  s.date    = '2014-06-12'
  s.summary = 'OWssh'
  s.description   = 'Wrapper for awscli for listing OpsWorks hosts and sshing to them'
  s.authors       = ["Philip Hutchins"]
  s.email         = 'flipture@gmail.com'
  s.files         = ["lib/owssh.rb"]
  s.executables  << 'owssh'
  s.add_runtime_dependency 'command_line_reporter', '~>3.0'
  s.homepage      =
    'http://phutchins.com/'
  s.license       = 'MIT'
end
