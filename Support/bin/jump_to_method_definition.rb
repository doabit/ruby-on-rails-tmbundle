#!/usr/bin/env ruby

require 'rails_bundle_tools'
require 'fileutils'
require 'rubygems'
require "#{ENV['TM_SUPPORT_PATH']}/lib/tm/htmloutput"

@original_term = ENV['TM_SELECTED_TEXT'] || ENV['TM_CURRENT_WORD']
@term = Regexp.escape(@original_term)
@found = []
@root = RailsPath.new.rails_root

def find_in_file_or_directory(file_or_directory, match_string)
  match_string.gsub!("'","'\"'\"'")
  found = `grep -RnPH '#{match_string}' #{file_or_directory} 2>/dev/null`
  return if found.empty?
  found.split(/\n/).each do |line|
    filename, line_number = line.split(':')
    next if filename.split('/').any?{|directory| directory.match(/^\./)} # Ignore hidden directories like .svn, .rsync, etc.
    @found << {:file => filename, :line => line_number.to_i}
  end
end

# First, if this is a route, we know this is in routes.rb
if path = @term.match(/(new_|edit_)?(.*?)_(path|url)/)
  path = path[2].split('_').first
  filename = File.join(@root,"config","routes.rb")
  find_in_file_or_directory(filename, "[^\.].resource[s]? (:|')#{path}(s|es)?[']?")
end

# Second, search the local project for any potentially matching method.
find_in_file_or_directory(@root, "^\s*def #{@term}([\(]{1}[^\)]*[\)]{1}\s*$|\s*$)") 
find_in_file_or_directory(@root, "^\s*(belongs_to|has_many|has_one|has_and_belongs_to_many|scope|named_scope) :#{@term}[\,]?")

# Third, search the Gems directory, pulling only the most recent gems, but only if we haven't yet found a match.
if @found.empty?
  Gem.latest_load_paths.each do |directory|
    find_in_file_or_directory(directory, "^\s*def #{@term}([\(]{1}[^\)]*[\)]{1}\s*$|\s*$)")
  end
end

# Render results sensibly.
if @found.empty?
  TextMate.exit_show_tool_tip("Could not find definition for '#{@term}'")
elsif @found.size == 1  
  TextMate.open(File.join(@found[0][:file]), @found[0][:line] - 1)
  TextMate.exit_show_tool_tip("Found definition for '#{@original_term}' in #{@found[0][:file]}")
else
  TextMate::HTMLOutput.show(
    :title      => "#{@found.size} Method Definitions Found"
  ) do |io|
    io << "<div class='executor'><table border='0' cellspacing='4' cellpading'0'><tbody>"
    @found.each do |location|
      io << "<tr><td><a class='near' href='txmt://open?url=file://#{location[:file]}&line=#{location[:line]}'>#{location[:file]}</a></td><td>line #{location[:line]}</td></tr>"
    end
    io << "</tbody></table></div>"
  end
  TextMate.exit_show_html
end