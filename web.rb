require 'rubygems'
require 'sinatra'
require 'redcarpet'
require 'find'
require 'open-uri'

class MarkdownRenderer

	def initialize ()
	    @pages = 
        [
            {:name => 'SuccessWhale', 
             :url => 'https://raw.github.com/ianrenton/SuccessWhale/master/README.md'},
            {:name => 'SuccessWhale API', 
             :url => 'https://raw.github.com/ianrenton/successwhale-api/master/README.md'}
        ]
		@content = {}
		renderer = Redcarpet::Render::HTML.new(:hard_wrap => true)
		@markdown = Redcarpet::Markdown.new(renderer)
	end

	def start_search
		@pages.each { |page|
		    file = open(page[:url])
		    content = file.read
		    content = append_github_link(page[:url], content)
			@content[page[:name]] = @markdown.render(content)
		}
		@content
	end

	private

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
