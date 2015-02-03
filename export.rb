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
download_num = -1  # number of posts to download, use -1 for ALL
limit        = 3   # number of posts requested each time

class TumblrPhotoExport

  attr_accessor :username, :api_key, :what, :where, :public_dir, :liked_dir, :image_subdir, :limit, :download_num, :url

  def initialize(username, api_key, what, where, public_dir, liked_dir, image_subdir, limit, download_num)

    @username     = username
    @api_key      = api_key
    @what         = what

    if @what == "likes"
      @where    = liked_dir
      @whatkey  = "liked_posts"
      @whatcount= "liked_count"
    else
      @where    = public_dir
      @whatkey  = "posts"
      @whatcount= "total_posts"
    end

    # URL to get Posts
    @url          = "http://api.tumblr.com/v2/blog/#{@username}.tumblr.com/#{@what}?api_key=#{@api_key}"

    @public_dir   = public_dir
    @liked_dir    = liked_dir
    @image_subdir = image_subdir
    @limit        = limit
    @download_num = download_num
    if @download_num == -1
      @download_num = get_results_count
    end

    @index_arr    = []
    @indexstart   = "---\nARCHIVE: "
    @indexend     = "\n---"

    create_dirs

  end

  def create_dirs

    Dir.mkdir("./#{@where}") unless File.directory?("./#{@where}")
    Dir.mkdir("./#{@where}/#{@image_subdir}") unless File.directory?("./#{@where}/#{@image_subdir}")

  end

  def get_results_count

    response        = HTTParty.get(@url)
    parsed_response = JSON.parse(response.body)
    total_count     = parsed_response['response'][@whatcount].to_i

    puts "total count: #{total_count}"
    return total_count

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

    if parsed_response['response'][@whatkey].length > 0
      parse_posts(parsed_response['response'][@whatkey])
      return true
    else
      return
    end

  end

  def parse_posts(posts)
    # for each item in posts
    $i = 0
    $LEN = posts.length
    until $i == $LEN
        $post = posts[$i]
        parse_post_common($post)
        send("parse_post_#{$type}".to_sym, $post)
        # push basic data to index array so we can build the archive
        if $title == nil
          $title       = $slug
        end
        @index_arr.push Hash[
            "STATE"   => $state,
            "TYPE"    => $type,
            "DATE"    => $date,
            "SLUG"    => $slug,
            "TITLE"   => $title
        ]

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
    $blog_name    = post['blog_name'] # useful to keep track in liked posts
    $post_url     = post['post_url']
    $tags         = post['tags']
    $state        = post['state']
    # common md output content
    $headerstart  = "---\nlayout: post\ntype: #$type"
    $headerend    = "path: #$slug\npost_url: #$post_url\ntags: #$tags\ncreated: #$date\n---\n\n"
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
    $images_arr   = []
    $num_photos   = post['photos'].length
    $headercustom = "num_photos: #$num_photos\ntitle: no title"
    $folder       = "./#{@where}/"
    $subfolder    = "#{@image_subdir}/"

    # write all source images to disk
    $num_photos.times do |i|
      $image        = post['photos'][i]
      $image_url    = $image['original_size']['url']
      $image_cap    = $image['caption']
      $image_str    = ""
      $extension    = $image_url.split('.').last
      $filename     = "#$slug"+"_"+i.to_s+"."+$extension

      if $format == "html"
        $image_cap     = get_md($image_cap)
      end

      if $image_cap == ""
        $image_str  = "[#$slug](#$folder#$subfolder#$filename)"
      else
        $image_str  = "[#$image_cap](#$folder#$subfolder#$filename)"
      end

      $images_arr.push $image_str
      write_file("#$folder#$subfolder", $image_url, $filename)
    end

    if $format == "html"
      $caption     = get_md($caption)
    end

    # inject images array into $headercustom
    $headercustom += "\nimages: #$images_arr"

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

  def write_index(folder, content)
    begin
      File.open(folder + "______index.md", "wb") do |f|
        f.write content
      end
    rescue => e
      puts ":( #{e}"
    end

  end

  def start

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

    write_index("./#{@where}/", "\n#@indexstart #@index_arr #@indexend")
  end

end

tumblr = TumblrPhotoExport.new(username, api_key, what, where, public_dir, liked_dir, image_subdir, limit, download_num)
tumblr.start