# USE AT YOUR VERY OWN RISK
# Heavily inspired by, mmmmm, ripped from https://github.com/javierarce/tumblr-photo-export/

require 'rubygems'
require 'httparty'
require 'reverse_markdown'

# Configuration
what         = ARGV[0] #posts, likes
username     = ARGV[1] || ENV["TUMBLR_USERNAME"]
api_key      = ARGV[2] || ENV["TUMBLR_CONSUMER_KEY"]
public_dir   = "public"
liked_dir    = "liked"
where        = public_dir
image_subdir = "images"
download_num = 300  # number of posts to download
limit        = 10   # number of posts requested each time

class TumblrPhotoExport

  attr_accessor :username, :api_key, :what, :where, :public_dir, :liked_dir, :image_subdir, :limit, :download_num, :url

  def initialize(username, api_key, what, where, public_dir, liked_dir, image_subdir, limit, download_num)

    @username     = username
    @api_key      = api_key
    @what         = what
    
    if @what == "likes"
      @where = liked_dir
    else
      @where = public_dir
    end

    @public_dir   = public_dir
    @liked_dir    = liked_dir
    @image_subdir = image_subdir
    @limit        = limit
    @download_num = download_num

    # URL to get Posts
    @url          = "http://api.tumblr.com/v2/blog/#{@username}.tumblr.com/#{@what}?api_key=#{@api_key}"

    create_dirs

  end

  def create_dirs

    Dir.mkdir("./#{@where}") unless File.directory?("./#{@where}")
    Dir.mkdir("./#{@where}/#{@image_subdir}") unless File.directory?("./#{@where}/#{@image_subdir}")

  end

  def get_results_count

    response        = HTTParty.get(@url + "&limit=1&offset=0")
    parsed_response = JSON.parse(response.body)

    return parsed_response['response']['posts']

  end

  def get_results(limit = 0, offset = 0)

    response        = HTTParty.get(@url + "&limit=#{limit}&offset=#{offset}")
    parsed_response = JSON.parse(response.body)

    # Status of the request
    status_code = parsed_response['meta']['status']
    status_msg  = parsed_response['meta']['msg']

    if status_code != 200
      puts "\033[91m#{status_msg}\033[0m" 
      return
    end

    if @what == "posts"
      parse_posts(parsed_response['response']['posts'])
    else
      parse_posts(parsed_response['response']['liked_posts'])
    end

    return true

  end

  def parse_posts(posts)
    # for each item in posts
    $i = 0
    $LEN = posts.length
    until $i == $LEN
        # common post data:
        $post         = posts[$i]
        $id           = $post['id']
        $slug         = $post['slug']
        if $slug == ""
          $slug       = $id
        end
        $type         = $post['type']
        $date         = $post['date']
        $timestamp    = $post['timestamp']
        $format       = $post['format']
        $source_url   = $post['source_url']
        $source_title = $post['source_title']
        $short_url    = $post['short_url']
        $post_url     = $post['post_url']
        $tags         = $post['tags']
        $state        = $post['state']

        # type = text:
        $title        = $post['title']
        $body         = $post['body']

        # type = quote:
        $text         = $post['text']
        $source       = $post['source']

        # type = link:
        $title        = $post['title']
        $url          = $post['url']
        $description  = $post['description']

        # type = video:
        $caption      = $post['caption']
        $player       = $post['player']

        # type = photo (just 1 photo, no photosets so far)
        $caption      = $post['caption']
        $image_url    = $post['photos'][0]['original_size']['url']

        # basic format translators: markdown, …
        if $format == "html"
          $body       = ReverseMarkdown.convert $body
          $caption    = ReverseMarkdown.convert $caption
        end

        # if type = photo, write image to disk
        if $type == "photo"
          begin
            $file = File.basename($image_url)
            File.open("./#{@where}/#{@image_subdir}/" + $file, "wb") do |f| 
              puts "downloading image #{$image_url}"
              f.write HTTParty.get($image_url).parsed_response
            end
          rescue => e
            puts ":( #{e}"
          end
        end

        # finally, write post to disk
        begin
          $file = "#$slug.md"
          File.open("./#{@where}/" + $file, "wb") do |f| 
            puts "writing post #$slug"
            f.write "\n---\nlayout: post\ntitle: #$title \npath: #$slug\ntype: #$type\ntags: #$tags\ncreated: #$date\n---\n\n#$body\n#$caption"
          end
        rescue => e
          puts ":( #{e}"
        end

        $i += 1
    end

  end

  def write_file(folder, filename, content)
    #
  end

  def start

    # uncomment next line to download all your posts
    # download_num = get_results_count

    parsed = 0
    batchs = (@download_num / @limit) + (@download_num % @limit)
    puts "batchs #{batchs}"

    if (@download_num < @limit)
      batchs = 1
      @limit  = @download_num
    end

    puts ":::::::::::::::::::::::::: Downloading \033[32m#{@download_num}\033[0m posts"

    batchs.times do |i|
      offset = i*@limit
      if parsed + @limit > @download_num
        @limit = @download_num - parsed
      end
      puts "::::::::::::: step #{i} parsed #{parsed} limit #{@limit} offset #{offset}"
      result = get_results(@limit, offset)
      parsed += @limit
      break if !result
    end

    puts "\033[32m#{"Aaaaand we're done, parsed #{parsed} "}\033[0m"

  end

end

tumblr = TumblrPhotoExport.new(username, api_key, what, where, public_dir, liked_dir, image_subdir, limit, download_num)
tumblr.start