# frozen_string_literal: true

# This file is part of the Alexandria build system.
#
# See the file README.md for authorship and licensing information.

load "tasks/setup.rb"

require "rake/packagetask"

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "util/rake"))
require "fileinstall"
require "gettextgenerate"
require "omfgenerate"

require_relative "lib/alexandria/version"

stage_dir = ENV["DESTDIR"] || "tmp"
prefix_dir = ENV["PREFIX"] || "/usr"

PROJECT = "alexandria"
PREFIX = prefix_dir
share_dir = ENV["SHARE"] || "#{PREFIX}/share"
SHARE = share_dir

GettextGenerateTask.new(PROJECT) do |g|
  g.generate_po_files("po", "po/*.po", "share/locale")
  g.generate_desktop("alexandria.desktop.in", "alexandria.desktop")
end

OmfGenerateTask.new(PROJECT) do |o|
  o.gnome_helpfiles_dir = "#{SHARE}/gnome/help"
  o.generate_omf("data/omf/alexandria", "share/omf/alexandria/*.in")
end

SHARE_FILE_GLOBS = ["data/alexandria/**/*", "data/gnome/**/*.*",
                    "data/locale/**/*.mo", "data/omf/**/*.omf",
                    "data/sounds/**/*.ogg"].freeze # , 'data/menu/*']

ICON_FILE_GLOBS = ["data/app-icon/**/*.png",
                   "data/app-icon/scalable/*.svg"].freeze

PIXMAP_GLOBS = "data/app-icon/32x32/*.xpm"

def install_common(install_task)
  install_task.install_exe("bin", "bin/*", "#{PREFIX}/bin")
  install_task.install("lib", "lib/**/*.rb", install_task.rubylib)

  install_task.install("data", SHARE_FILE_GLOBS, SHARE)
  install_task.install_icons(ICON_FILE_GLOBS, "#{SHARE}/icons")
  install_task.install("data/app-icon/32x32", PIXMAP_GLOBS, "#{SHARE}/pixmaps")

  install_task.install("", "schemas/alexandria.schemas", "#{SHARE}/gconf")
  install_task.install("", "alexandria.desktop", "#{SHARE}/applications")
  install_task.install("doc", "doc/alexandria.1", "#{SHARE}/man/man1")
end

FileInstallTask.new(:package_staging, stage_dir, true) do |i|
  install_common(i)
end

task debian_install: :install_package_staging

FileInstallTask.new(:package) do |j|
  install_common(j)

  docs = %w(README.rdoc CHANGELOG.md INSTALL.md COPYING TODO.md)
  devel_docs = ["doc/AUTHORS", "doc/BUGS", "doc/FAQ",
                "doc/cuecat_support.rdoc"]
  j.install("", docs, "#{SHARE}/doc/#{PROJECT}")
  j.install("doc", devel_docs, "#{SHARE}/doc/#{PROJECT}")

  j.uninstall_empty_dirs(["#{SHARE}/**/#{PROJECT}/",
                          "#{j.rubylib}/#{PROJECT}/"])
end

task :clobberp do
  puts CLOBBER
end

## autogenerated files

def autogen_comment
  lines = [
    "This file is automatically generated by the #{PROJECT} installer.",
    "Do not edit it directly."
  ]
  result = lines.map { |line| "# #{line}" }
  result.join("\n") + "\n\n"
end

def generate(filename)
  File.open(filename, "w") do |file|
    puts "Generating #{filename}"
    file.print autogen_comment
    file_contents = yield
    file.print file_contents.to_s
  end
end

# generate default_preferences.rb
def convert_with_type(value, type)
  case type
  when "int"
    value.to_i
  when "float"
    value.to_f
  when "bool"
    value == "true"
  when "string"
    value.to_s.strip
  else
    raise NotImplementedError, "Unknown type #{type}"
  end
end

SCHEMA_PATH = "schemas/alexandria.schemas"

# This generates default_preferences.rb by copying over values from
# providers_priority key in alexandria.schemas (necessary?)

file "lib/alexandria/default_preferences.rb" => ["Rakefile", SCHEMA_PATH] do |f|
  require "rexml/document"
  generated_lines = []

  doc = REXML::Document.new(IO.read(SCHEMA_PATH))
  doc.elements.each("gconfschemafile/schemalist/schema") do |element|
    default = element.elements["default"].text

    varname = File.basename(element.elements["key"].text)
    type = element.elements["type"].text

    if (type == "list") || (type == "pair")
      ary = default[1..-2].split(",")
      next if ary.empty?

      case type
      when "list"
        list_type = element.elements["list_type"].text
        ary.map! { |x| convert_with_type(x, list_type) }
      when "pair"
        next if ary.length != 2

        ary[0] = convert_with_type(ary[0],
                                   element.elements["car_type"].text)
        ary[1] = convert_with_type(ary[1],
                                   element.elements["cdr_type"].text)
      end
      default = ary.inspect
    else
      default = convert_with_type(default, type).inspect.to_s
    end

    generated_lines << varname.inspect + " => " + default
  end

  generate(f.name) do
    <<~EOS
      module Alexandria
        class Preferences
          DEFAULT_VALUES = {
            #{generated_lines.join(",\n      ")}
          }
        end
      end
    EOS
  end
end

autogenerated_files = ["lib/alexandria/default_preferences.rb"]

desc "Generate ruby files needed for the installation"
task autogen: autogenerated_files

task :autogen_clobber do |_t|
  autogenerated_files.each do |file|
    FileUtils.rm_f(file)
  end
end
task clobber: [:autogen_clobber]

## # # # default task # # # ##

task build: [:autogen, :gettext, :omf]

task default: [:build]

# pre-release tasks

ULTRA_CLOBBER = [].freeze
task ultra_clobber: :clobber do
  ULTRA_CLOBBER.each do |file|
    FileUtils::Verbose.rm_f(file)
  end
end

## # # # package task # # # ##

Rake::PackageTask.new(PROJECT, Alexandria::DISPLAY_VERSION) do |p|
  p.need_tar_gz = true
  p.package_files.include("README.md", "COPYING", "CHANGELOG.md", "INSTALL.md",
                          "Rakefile", "util/**/*",
                          "TODO.md", "alexandria.desktop",
                          "alexandria.desktop.in",
                          "bin/**/*", "data/**/*", "misc/**/*",
                          "doc/**/*", "lib/**/*", "po/**/*",
                          "schemas/**/*", "spec/**/*")
end

task tgz: [:build] do
  `rake package`
end

## # # # system installation # # # ##

task pre_install: [:build]
task :scrollkeeper do
  unless system("which scrollkeeper-update")
    raise "scrollkeeper-update cannot be found, is Scrollkeeper correctly installed?"
  end

  system("scrollkeeper-update -q") || raise("Scrollkeeper update failed")
end

task :gconf do
  return if ENV["GCONF_DISABLE_MAKEFILE_SCHEMA_INSTALL"]

  unless system("which gconftool-2")
    raise "gconftool-2 cannot be found, is GConf2 correctly installed?"
  end

  ENV["GCONF_CONFIG_SOURCE"] = `gconftool-2 --get-default-source`.chomp
  Dir["schemas/*.schemas"].each do |schema|
    system("gconftool-2 --makefile-install-rule '#{schema}'")
  end
  # system("killall -HUP gconfd-2")
end

task :update_icon_cache do
  system("gtk-update-icon-cache -f -t /usr/share/icons/hicolor") # HACK
end

task post_install: [:scrollkeeper, :gconf, :update_icon_cache]

desc "Install Alexandria"
task install: [:pre_install, :install_package, :post_install]

desc "Uninstall Alexandria"
task uninstall: [:uninstall_package] # TODO: gconf etc...

task default: [:spec]
