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
download_num = 45  # number of posts to download
limit        = 3   # number of posts requested each time

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
        $post = posts[$i]
        parse_post_common($post)
        send("parse_post_#{$type}".to_sym, $post)

        $i += 1
    end

  end

  def parse_post_common(post)
    # common post data:   
    $id           = post['id']
    $slug         = post['slug']
    if $slug == ""
      $slug       = $id
    end
    $type         = post['type']
    $date         = post['date']
    $timestamp    = post['timestamp']
    $format       = post['format']
    $source_url   = post['source_url']
    $source_title = post['source_title']
    $short_url    = post['short_url']
    $post_url     = post['post_url']
    $tags         = post['tags']
    $state        = post['state']
    # common md output content
    $headerstart  = "---\nlayout: post"
    $headerend    = "path: #$slug\ntype: #$type\ntags: #$tags\ncreated: #$date\n---\n\n"
  end

  def parse_post_text(post)
    puts "parse_post_text"
    $title        = post['title']
    $body         = post['body']
    $headercustom = "title: #$title"

    if $format == "html"
      $body       = get_md($body)
    end

    # write post to disk
    write_post("./#{@where}/", "#$slug.md", "\n#$headerstart\n#$headercustom\n#$headerend\n\n#$body")
  end

  def parse_post_quote(post)
    puts "parse_post_quote"
    $text         = post['text']
    $source       = post['source']
    $headercustom = "title: no title"

    if $format == "html"
      $text       = get_md($text)
      $source     = get_md($source)
    end

    # write post to disk
    write_post("./#{@where}/", "#$slug.md", "\n#$headerstart\n#$headercustom\n#$headerend\n\n#$text\n\n#$source")
  end

  def parse_post_link(post)
    puts "parse_post_link"
    $title        = post['title']
    $url          = post['url']
    $url          = "[#$title](#$url)"
    $description  = post['description']
    $headercustom = "title: #$title"

    if $format == "html"
      $description = get_md($description)
    end

    # write post to disk
    write_post("./#{@where}/", "#$slug.md", "\n#$headerstart\n#$headercustom\n#$headerend\n\n#$url\n#$description")
  end

  def parse_post_video(post)
    puts "parse_post_video"
    $caption      = $post['caption']
    $player       = $post['player']
    $headercustom = "title: no title"

    if $format == "html"
      $caption    = get_md($caption)
    end

    # write post to disk
    write_post("./#{@where}/", "#$slug.md", "\n#$headerstart\n#$headercustom\n#$headerend\n\n#$caption")
  end

  def parse_post_photo(post)
    puts "parse_post_photo"
    $caption      = post['caption']
    $image_url    = post['photos'][0]['original_size']['url']
    $extension    = $image_url.split('.').last
    $filename     = $slug+"."+$extension
    $headercustom = "title: no title"

    if $format == "html"
      $caption     = get_md($caption)
    end

    # write source image to disk
    write_file("./#{@where}/#{@image_subdir}/", $image_url, $filename)
    # write post to disk
    write_post("./#{@where}/", "#$slug.md", "\n#$headerstart\n#$headercustom\n#$headerend\n\n#$caption")
  end

  def parse_post_chat(post)
    puts "parse_post_chat"
    # same format as text
    parse_post_text(post)
  end

  def parse_post_audio(post)
    puts "parse_post_audio"
    $caption      = $post['caption']
    $url          = $post['audio_url']
    $url          = "[#$url](#$url)"
    $headercustom = "title: no title"

    if $format == "html"
      $caption    = get_md($caption)
    end

    # write post to disk
    write_post("./#{@where}/", "#$slug.md", "\n#$headerstart\n#$headercustom\n#$headerend\n\n#$url\n#$caption")
  end

  def parse_post_answer(post)
    # nothing to see here, old post type
  end

  def get_md(html)
    return ReverseMarkdown.convert html
  end

  def write_file(folder, fileuri, filename)
    filename = File.basename(filename)

    begin
      File.open(folder + filename, "wb") do |f| 
        f.write HTTParty.get(fileuri).parsed_response
      end
    rescue => e
      puts ":( #{e}"
    end
  end

  def write_post(folder, filename, content)
    begin
      File.open(folder + filename, "wb") do |f| 
        f.write content
      end
    rescue => e
      puts ":( #{e}"
    end
  end

  def start

    # uncomment next line to download all your posts
    # download_num = get_results_count

    parsed = 0
    rest = @download_num % @limit
    if rest > 1
      rest = 1
    end
    batchs = (@download_num / @limit) + rest
    puts "batchs download_num #{download_num} limit #{limit} batchs #{batchs}"

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