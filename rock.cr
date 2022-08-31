# Kjartan Rex (github.com/kjarex)

require "http/client"
require "uri"
require "yaml"
require "dynany/yaml"
require "colorize"

VERSION= "0.1"

class String
  def cap (l=20)
    size>l ? "#{self[0..(l-2)]}…" : self      
  end
end

class Shard
  YML= "shard.yml"
  @@yml= nil

  def self.yml
    @@yml||self.init
  end

  def self.init
    (`shards init`) unless File.file? Shard::YML
    begin
      @@yml= (YAML.parse File.read Shard::YML)
    rescue 
      puts "rock can't handle your #{Shard::YML} file. No action taken."
      exit 1
    end
  end
end

def dependencies
  Shard.yml[YAML::Any.new("dependencies")]||=YAML::Any.new(Hash(YAML::Any, YAML::Any).new)
end

def save
  File.write Shard::YML, Shard.yml.to_yaml 
  Shard.init
  nil
rescue File::AccessDeniedError
  puts "\nERROR! Couldn't write to #{Shard::YML}. No action taken.".colorize(:red)
  exit 1
end

def addDependency (name, **args)
  name= name.to_s
  (puts "\nHold on a second - you've got this shard already! No action taken."; exit 1) if dependencies[name]?
  #dependencies[name]= (p args.map{|k, v| [k.to_s, v]}.to_h)
  dependencies[YAML::Any.new(name)]= YAML::Any.new(Hash(YAML::Any, YAML::Any).new)
  args.each do |k, v|
    dependencies[[name, k.to_s]]= YAML::Any.new(v)
  end
  save
end

def searchProcedure (s)
  rr= shardboxSearch s  
  puts "and found #{rr.size.to_s.colorize(:yellow)} result#{"s" unless rr.size==1}#{rr.size.zero? ? '.' : ':'}"
  l= 20
  begin
    ld= (`stty size`.split(' ')[1]?||120).to_i-l-20
  rescue
    ld= 80
  end
  ld= 80 if ld<60
  rr.each{|r| puts "   #{r["name"].not_nil!.cap(l).ljust(l+8, ' ')}#{r["description"].try{|d| d.cap(ld)}}"}
end

def shardboxSearch (s)
  print "Searching at Shardbox for '#{s.colorize(:yellow)}'… "
  begin
    HTTP::Client.get("https://shardbox.org/search?q=#{URI.encode_path_segment s.not_nil!}").body.split("</main>")[0].split("shard-card")[1..-1].map{|card| card.gsub("\n", " ").match(/class="shard-name">\s+(?<name>.+?)\s*<.+?(class=\"description\">\s+(?<description>.+?)\s+<.+?){0,1}https:\/\/github.com\/(?<github>.+?)\".+/).try &.named_captures}.compact
  rescue
    puts "but couldn't access Shardbox. No action taken."
    exit 1
  end
end

def addProcedure (s)
  r= searchShard s
  puts "and found it. "
  print "Adding it to your #{Shard::YML} right now. Just a moment. "
  addDependency s, github: r
  puts "Done."
end

def searchShard (s)
  help unless s
  print "Searching at Shardbox for #{s.colorize(:green)}… "
  begin
    r= HTTP::Client.get("https://shardbox.org/shards/#{URI.encode_path_segment s.not_nil!}")
  rescue
    puts "but couldn't access Shardbox. No action taken."
    exit 1
  end
  (puts "but couldn't find #{s.colorize(:green)}. No action taken."; exit 1) unless r.success?
  r= r.body.match(/class=\"token key atrule\">github<\/span>: (.+?)\n/)
  (puts "but couldn't find the github target. No action taken."; exit 1) unless r
  r.captures[0]
end

def help (i=1)
  puts "rock - version #{VERSION}
  Usage:
    rock help                   to get this help text
    rock version                to see rock's version
    rock search #{"something".colorize(:yellow)}       to search for #{"something".colorize(:yellow)} on shardbox.org
    rock add #{"shard".colorize(:green)}              to add #{"shard".colorize(:green)} to your dependencies
    rock remove #{"shard".colorize(:green)}           not implemented yet - to remove #{"shard".colorize(:green)} from your dependencies"
#    rock install #{"shard".colorize(:green)}          to install #{"shard".colorize(:green)}
#    rock uninstall #{"shard".colorize(:green)}        to uninstall #{"shard".colorize(:green)}"
  exit i
end

def todo
  puts "This feature hasn't been implemented yet. Sorry."
  exit 1  
end

def remove (name)
  (puts "#{name.colorize(:green)} isn't in your #{Shard::YML} anyway. No action taken."; exit 1) unless dependencies[name]?
   dependencies.delete name.not_nil!
  save
end

case ARGV.shift?
when "add"
  addProcedure ARGV.shift? #TODO all of them if more than one given (but then the check should be adjust)
#when "install"
#  todo
when "remove"
  help if ARGV.empty?
  remove ARGV.shift? #TODO all of them if more than one given
#when "uninstall"
#  todo
when "search"
  help if ARGV.empty?
  searchProcedure ARGV.join " "
when "version"
  puts VERSION
when "help"
  help 0
else
  help    
end 