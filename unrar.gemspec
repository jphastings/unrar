spec = Gem::Specification.new do |s| 
  s.name = "unrar"
  s.version = "0.2.1"
  s.author = "JP Hastings-Spital"
  s.email = "unrar@projects.kedakai.co.uk"
  s.homepage = "http://projects.kedakai.co.uk/unrar/"
  s.platform = Gem::Platform::RUBY
  s.description = "Pure ruby implementation of RarLabs' Unrar software. Doesn't yet support encryption or compression. Written to allow streaming of data from archives."
  s.summary = "Pure ruby implementation of RarLabs' Unrar software. Doesn't yet support encryption or compression. Written to allow streaming of data from archives."
  s.files = ["unrar.rb"]
  s.require_paths = ["."]
  s.has_rdoc = true
end
