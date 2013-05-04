require 'rubygems'
require 'sinatra'
require 'redcarpet'
require 'find'
require 'open-uri/cached'

class MarkdownRenderer

	def initialize ()
	    @pages = 
        [
            {:name => 'GitHub Readme Website', 
             :url => 'https://raw.github.com/ianrenton/github-readme-website/master/README.md'},
            {:name => 'Markdown Website Renderer', 
             :url => 'https://raw.github.com/ciwchris/markdown-website-renderer/master/README.md'}
        ]
		@content = {}
		renderer = Redcarpet::Render::HTML.new(:hard_wrap => true)
		@markdown = Redcarpet::Markdown.new(renderer)
	end

	def start_search
	    # Add files on disk
	    Dir['markdown/**/*.md'].each {|fileName|
			name = create_tab_name_from(fileName)
			file = File.open(fileName)
			@content[name] = @markdown.render(file.read)
		}
		# Then add the requested remote files
		@pages.each { |page|
		    file = open(page[:url])
		    content = file.read
		    content = append_github_link(page[:url], content)
			@content[page[:name]] = @markdown.render(content)
		}
		@content
	end

	private

	def create_tab_name_from(name)
		File.basename(name, '.md').gsub(/[-_]/, ' ').capitalize
	end

	def append_github_link(url, content)
		match = /raw.github.com\/([\w\d\/\.\-_]*)\/.*\/.*\.md/.match(url)
		unless match.nil?
		    content << "\n\n> This description is from the GitHub project [#{match[1]}](https://github.com/#{match[1]}). Full source code is available there.\n"
		end
	end
end

get '/' do
	content = MarkdownRenderer.new.start_search
	erb :index, :locals => { :content => content }
end
