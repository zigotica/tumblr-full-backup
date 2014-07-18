tumblr-full-backup
==================

Export the post and images from your tumblr blog, or post and images from your [liked posts](https://www.tumblr.com/likes) in Tumblr. Heavily inspired by, mmmmm, ripped off from [tumblr-photo-export](https://github.com/javierarce/tumblr-photo-export/)

## Dependencies

* [httparty](https://github.com/jnunemaker/httparty) 

        [sudo] gem install httparty

* [reverse_markdown](https://github.com/xijo/reverse_markdown)

        [sudo] gem install reverse_markdown

## Setup

1. Clone the repo:  

        $ git clone git@github.com:zigotica/tumblr-full-backup.git

    If you do not use Git, you can simply download the project in [.zip format](https://github.com/zigotica/tumblr-full-backup/archive/master.zip)

2. (Optionally) modify defaults at export.rb file: `public_dir`, `liked_dir`, `image_subdir`, `download_num`, `limit`
 
3. Register a new app, this will allow you to fetch data from Tumblr programmatically:  [https://www.tumblr.com/oauth/register](https://www.tumblr.com/oauth/register)

4. Copy the `OAuth Consumer Key` of the app, you will need it later. 

5. (Optionally) Add two keys to your bash/zsh:

        export TUMBLR_USERNAME="MY_FANTASTIC_TUMBLR_USERNAME"  
        export TUMBLR_CONSUMER_KEY="MY_DAUNTING_OAUTH_CONSUMER_KEY"  

## Download posts, including images

1. Go to the app directory and run [optional if performed step 5]:  

        ruby export.rb posts [TUMBLR_USERNAME TUMBLR_CONSUMER_KEY]

2. Posts and images from your Tumblr blog will be downloaded to the `public_dir` folder. 


## Download likes, including images

1. Enable the option ["Share posts you like"](https://www.tumblr.com/settings/dashboard).

2. Go to the app directory and run [optional if performed step 5]:  

        ruby export.rb likes [TUMBLR_USERNAME TUMBLR_CONSUMER_KEY]

3. Posts and images from posts you liked will be downloaded to the `liked_dir` folder. 

## Todo

* [x] Refactor write to insert correct contents depending on post type
* [x] Manage photo sets
* [x] Add downloaded image info to post header
* [x] Create index page for posts/likes
* [ ] Build a static site from downloaded files