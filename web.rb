require 'rubygems'
require 'sinatra'
require 'redcarpet'
require 'find'
require 'open-uri'
require 'redis'
require 'json'
require 'github/markdown'

class MarkdownRenderer

    # Set up initial content, including the list of remote markdown docs to get
	def initialize ()
	    @pages = 
        [
            {:name => 'GitHub Readme Website', 
             :url => 'https://raw.github.com/ianrenton/github-readme-website/master/README.md'},
            {:name => 'Markdown Website Renderer', 
             :url => 'https://raw.github.com/ciwchris/markdown-website-renderer/master/README.md'}
        ]
		@content = {}
		@markdown = GitHub::Markdown.new()
	end

    # Get all markdown docs, local and remote
	def get_markdowns
	    # Add files on disk
	    Dir['markdown/**/*.md'].each {|fileName|
			name = create_tab_name_from(fileName)
			file = File.open(fileName)
			@content[slugify(name)] = {'name' => name, 'html' => @markdown.render_gfm(file.read)}
		}
		# Then add the requested remote files
		@pages.each { |page|
		    file = open(page[:url])
		    content = file.read
		    content = append_github_link(page[:url], content)
			@content[slugify(page[:name])] = {'name' => page[:name], 'html' => @markdown.render(content)}
		}
		@content
	end

	private

    # Create a "pretty" name from a local Markdown filename
	def create_tab_name_from(name)
		File.basename(name, '.md').gsub(/[-_]/, ' ').capitalize
	end
	
	# Create a "slug" (alphabet characters and dashes only) to name the tabs and
	# the valid URLs that automatically select each tab.
	def slugify(name)
	    name.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
	end

    # Check if a given URL is to a Markdown file in a Github repo, and if so,
    # append information to that effect to the Markdown.
	def append_github_link(url, content)
		match = /raw.github.com\/([\w\d\/\.\-_]*)\/.*\/.*\.md/.match(url)
		unless match.nil?
		    content << "\n\n> This description is from the GitHub project [#{match[1]}](https://github.com/#{match[1]}). Full source code is available there.\n"
		end
		return content
	end
end

# Respond to the HTTP request, with optional slug to select a tab by default.
get '/?:slug?' do

    # Check if we have data cached from a previous call.
    uri = URI.parse(ENV["REDISTOGO_URL"])
    redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
    if redis[:cached_data]
        # Cached data present, so use it
        content = JSON.parse(redis[:cached_data])
    else
        # No cached data, so grab new data and cache it as well as using it now
        content = MarkdownRenderer.new.get_markdowns
        redis[:cached_data] = content.to_json
        redis.expire(:cached_data, 60*60*24)
    end
	
	# Generate output
	erb :index, :locals => { :content => content, :slug => params[:slug] }
end
