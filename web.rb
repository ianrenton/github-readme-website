require 'rubygems'
require 'sinatra'
require 'redcarpet'
require 'find'
require 'open-uri'
require 'json'
require 'nokogiri'
require 'uri'

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
    @pages.sort! { |a,b| a[:name].downcase <=> b[:name].downcase }
    @pages.each { |page|
      page[:slug] = slugify(page[:name])
    }
		@content = {}
		renderer = Redcarpet::Render::HTML.new()
		@markdown = Redcarpet::Markdown.new(renderer, {:no_intra_emphasis=>true, :fenced_code_blocks=>true, :autolink=>true, :tables=>true, :with_toc_data=>true})
	end

  # Get a list of all local and remote markdowns
	def get_file_list
	    # Add files on disk
	    Dir['markdown/**/*.md'].each {|fileName|
			name = create_name_from(fileName)
			@content[slugify(name)] = {'name' => name, 'shortname' => shorten(name), 'slug' => slugify(name), 'file' => fileName, 'remote' => false}
		}
		# Then add the requested remote files
		@pages.each { |page|
			@content[slugify(page[:name])] = {'name' => page[:name], 'shortname' => shorten(page[:name]), 'slug' => slugify(page[:name]), 'file' => page[:url], 'remote' => true}
		}
		@content
	end

    # Add the render of a markdown file to @content
	def get_markdown(slug)
	
    if @content[slug]['remote']
      file = open(@content[slug]['file'])
	    content = file.read
	    content = append_github_link(@content[slug]['file'], content)
	    html_content = @markdown.render(content)
	    html_content = rel_to_abs_urls(@content[slug]['file'], html_content)
	  else
	    file = File.open(@content[slug]['file'])
	    html_content = @markdown.render(file.read)
	  end
    
    @content[slug] = @content[slug].merge({'html' => html_content})
	
		@content
	end

	private

    # Create a "pretty" name from a local Markdown filename
	def create_name_from(name)
		File.basename(name, '.md').gsub(/[-_]/, ' ').capitalize
	end
	
	# Create a "slug" (alphabet characters and dashes only) to name the tabs and
	# the valid URLs that automatically select each tab.
	def slugify(name)
	    name.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
	end
	
	# Create a shortened form of a name, truncating to the width of the menu div.
	def shorten(name)
	    if name.length < 25
	      return name
	    else
	      return name[0,21] + '...'
	    end
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
	
	# Convert relative to absolute URLs. Supply the URL that the markdown was
	# retrieved from and the *HTML* content - not the Markdown. Only useful for
	# remotely retrieved pages.
	def rel_to_abs_urls(url, html_content)
	    # Get the directory the fetched markdown was in
	    baseURI = "#{File.dirname(url)}/"
	    
	    # If Github, get the presentable location for this file not the raw one
	    match = /raw.github.com\/([\w\d\/\.\-_]*)\/(.*\/).*\.md/.match(url)
		unless match.nil?
		    baseURI = "https://github.com/#{match[1]}/blob/#{match[2]}"
		end
	    
	    # Mangle the HTML to find relative links and make them absolute.
	    doc = Nokogiri::HTML(html_content)
	    tags = {
          'img'    => 'src',
          'a'      => 'href'
        }
        doc.search(tags.keys.join(',')).each do |node|
          url_param = tags[node.name]
          src = node[url_param]
          unless (src.empty?)
            uri = URI.parse(src)
            # No uri.host means this is a relative link
            unless uri.host
              node[url_param] = "#{baseURI}#{src}"
            end
          end
        end
    doc.to_html
	end
end

# Respond to the HTTP request, with optional slug to select a page.
get '/?:slug?' do

  # Request index file unless told otherwise
  if params[:slug]
    slug = params[:slug]
  else
    slug = 'index'
  end
  
  # Get requested Markdown file, and links to all the others
  renderer = MarkdownRenderer.new
  content = renderer.get_file_list
  
  if content[slug]
    # If the slug matches something in the page index, fetch the markdown
    # for it.
    content = renderer.get_markdown(slug)
  else
    # If page not found, set status 404. Render the page anyway, because
    # the template deals with 404 error display.
    status 404
  end
	
	# Generate output
	erb :index, :locals => { :content => content, :slug => slug}
end
