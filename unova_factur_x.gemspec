# frozen_string_literal: true

require_relative "lib/unova_factur_x/version"

Gem::Specification.new do |spec|
  spec.name = "unova_factur_x"
  spec.version = UnovaFacturX::VERSION
  spec.authors = ["Rodolphe Limousin"]
  spec.email = ["rodolphe.limousin@unova.fr"]

  spec.summary = "Generation of invoices/credit notes in Factur-X format"
  spec.description = "Takes a PDF and a data hash as input and returns a Factur-X-compliant PDF"
  spec.homepage = "https://github.com/unovafr/unova_factur_x"
  spec.license = "Apache 2.0"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/unovafr/unova_factur_x"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .gitlab-ci.yml .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "hexapdf", "~> 1.6"
  spec.add_dependency "nokogiri", "~> 1.18"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
