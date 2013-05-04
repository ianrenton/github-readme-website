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
		renderer = Redcarpet::Render::HTML.new(:no_links => true, :hard_wrap => true)
		@markdown = Redcarpet::Markdown.new(renderer)
	end

	def start_search
		@pages.each { |page|
		    file = open(page[:url])
			@content[page[:name]] = @markdown.render(file.read)
		}
		@content
	end

	private

	def create_tab_name_from(name)
		File.basename(name, '.md').gsub(/[-_]/, ' ').capitalize
	end
end

get '/' do
	content = MarkdownRenderer.new.start_search
	erb :index, :locals => { :content => content }
end
