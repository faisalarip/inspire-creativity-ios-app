#!/usr/bin/env ruby
# Deterministically add source files to the InspireCreativityApp target.
#
# Adds each given file (paths relative to repo root) to the target's
# Sources build phase, creating navigator groups that mirror the folder
# structure. Idempotent: files already in the build phase are skipped.
# .swift and .metal both compile in the Sources phase.
#
# Usage:  ruby Tools/add_sources.rb <relpath> [<relpath> ...]

require 'xcodeproj'
require 'set'
require 'pathname'

ROOT = File.expand_path('..', __dir__)
PROJECT = File.join(ROOT, 'InspireCreativityApp.xcodeproj')
TARGET = 'InspireCreativityApp'

project = Xcodeproj::Project.open(PROJECT)
target = project.targets.find { |t| t.name == TARGET }
abort "target #{TARGET} not found" unless target
abort 'no files given' if ARGV.empty?

existing = target.source_build_phase.files.map { |bf| bf.file_ref&.real_path&.to_s }.compact.to_set

added = []
skipped = []
ARGV.each do |rel|
  abs = File.expand_path(rel, ROOT)
  unless File.exist?(abs)
    warn "MISSING (skipped): #{rel}"
    next
  end
  if existing.include?(abs)
    skipped << rel
    next
  end
  rel_from_root = Pathname.new(abs).relative_path_from(Pathname.new(ROOT)).to_s
  group_path = File.dirname(rel_from_root)
  group = project.main_group.find_subpath(group_path, true)
  group.set_source_tree('SOURCE_ROOT')
  file_ref = group.new_reference(abs)
  target.source_build_phase.add_file_reference(file_ref, true)
  existing << abs
  added << rel_from_root
end

project.save
puts "added #{added.size}: #{added.join(', ')}"
puts "already present #{skipped.size}" unless skipped.empty?
