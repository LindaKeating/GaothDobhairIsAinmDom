require 'oauth'
require 'json'
require 'typhoeus'
require 'oauth/request_proxy/typhoeus_request'

# The code below sets the consumer key and secret from your environment variables
# To set environment variables on Mac OS X, run the export command below from the terminal:
# export CONSUMER_KEY='YOUR-KEY', CONSUMER_SECRET='YOUR-SECRET'
consumer_key = ENV["CONSUMER_KEY"]
puts "----- ****** #{consumer_key} : CONSUMER_KEY"
consumer_secret = ENV["CONSUMER_SECRET"]
bearer = ENV["BEARER_TOKEN"]
client_id = ENV["CLIENT_ID"]
client_secret = ENV["CLIENT_SECRET"]
redirect_uri = 'http://127.0.0.1:8000'

create_tweet_url = "https://api.twitter.com/2/tweets"

@json_payload = {"text": "Hello world!"}


create_tweet_url = "https://api.twitter.com/2/tweets"

# Be sure to add replace the text of the with the text you wish to Tweet.
# You can also add parameters to post polls, quote Tweets, Tweet with reply settings, and Tweet to Super Followers in addition to other features.
@json_payload = {"text": "Hello world!"}
@callback_url = "http://127.0.0.1:8000"

consumer = OAuth::Consumer.new(consumer_key, consumer_secret,
	:site => 'https://api.twitter.com',
	:authorize_path => '/oauth/authenticate',)

  def get_request_token(consumer)

    request_token = consumer.get_request_token()
    puts "request_token: #{request_token}"
  
    return request_token
  end

  def get_user_authorization(request_token)
    puts "Follow this URL to have a user authorize your app: #{request_token.authorize_url()}"
    puts "Enter PIN: "
    pin = gets.strip
  
    return pin
  end

  def obtain_access_token(consumer, request_token, pin)
    token = request_token.token
    token_secret = request_token.secret
    hash = { :oauth_token => token, :oauth_token_secret => token_secret }
    request_token  = OAuth::RequestToken.from_hash(consumer, hash)
  
    # Get access token
    access_token = request_token.get_access_token({:oauth_verifier => pin})
  
    return access_token
  end

  def create_tweet(url, oauth_params)
    options = {
        :method => :post,
        headers: {
           "User-Agent": "v2CreateTweetRuby",
          "content-type": "application/json"
        },
        body: JSON.dump(@json_payload)
    }
    request = Typhoeus::Request.new(url, options)
    oauth_helper = OAuth::Client::Helper.new(request, oauth_params.merge(:request_uri => url))
    request.options[:headers].merge!({"Authorization" => oauth_helper.header}) # Signs the request
    response = request.run
  
    return response
  end

request_token = get_request_token(consumer)

pin = get_user_authorization(request_token)

access_token = obtain_access_token(consumer, request_token, pin)

oauth_params = {:consumer => consumer, :token => access_token}

response = create_tweet(create_tweet_url, oauth_params)

puts response.code, JSON.pretty_generate(JSON.parse(response.body))

@bearer_token = ENV["BEARER_TOKEN"]

@stream_url = "https://api.twitter.com/2/tweets/search/stream"
@rules_url = "https://api.twitter.com/2/tweets/search/stream/rules"

@sample_rules = [
  { "value" => "love island -is:retweet -is:reply"}
]


# Add or remove values from the optional parameters below. Full list of parameters can be found in the docs:
# https://developer.twitter.com/en/docs/twitter-api/tweets/filtered-stream/api-reference/get-tweets-search-stream
params = {
  "expansions": "attachments.poll_ids,attachments.media_keys,author_id,entities.mentions.username,geo.place_id,in_reply_to_user_id,referenced_tweets.id,referenced_tweets.id.author_id",
  "tweet.fields": "attachments,author_id,conversation_id,created_at,entities,geo,id,in_reply_to_user_id,lang",
  # "user.fields": "description",
  # "media.fields": "url", 
  # "place.fields": "country_code",
  # "poll.fields": "options"
}

def get_all_rules
  @options = {
    headers: {
      "User-Agent": 'v2FilteredStreamRuby',
      "Authorization": "Bearer #{@bearer_token}"
    }
  }

  @response = Typhoeus.get(@rules_url, @options)

  raise "An error occurred while retrieving active rules from your stream #{@response.body}" unless @response.success?

  @body = JSON.parse(@response.body)
end

def set_rules(rules)
  return if rules.nil?

  @payload = {
    add: rules
  }

  puts JSON.dump(@payload)

  @options  = {
    headers: {
      "User-Agent": "v2FilteredStremRuby",
      "Authorization": "Bearer #{@bearer_token}",
      "Content-type": "application/json"
    },
    body: JSON.dump(@payload)
  }

  @response = Typhoeus.post(@rules_url, @options)
  raise "An error occurred while adding rules: #{@response.status_message}" unless @response.success?
end

# Post request with a delete body to remove rules from your stream
def delete_all_rules(rules)
  return if rules.nil?
  puts "Rules #{rules.inspect}"

  @ids = rules['data'].map { |rule| rule["id"] }
  @payload = {
    delete: {
      ids: @ids
    }
  }

  @options = {
    headers: {
      "User-Agent": "v2FilteredStreamRuby",
      "Authorization": "Bearer #{@bearer_token}",
      "Content-type": "application/json"
    },
    body: JSON.dump(@payload)
  }

  @response = Typhoeus.post(@rules_url, @options)

  raise "An error occurred while deleting your rules: #{@response.status_message}" unless @response.success?
end

def setup_rules
  # Gets the complete list of rules currently applied to the stream
  @rules = get_all_rules
  puts "Found existing rules on the stream:\n #{@rules}\n"

  puts "Do you want to delete existing rules and replace with new rules? [y/n]"
  answer = gets.chomp
  if answer == "y"
    # Delete all rules
    delete_all_rules(@rules)
  else
    puts "Keeping existing rules and adding new ones."
  end
  
  # Add rules to the stream
  set_rules(@sample_rules)
end

# Connects to the stream and returns data (Tweet payloads) in chunks
def stream_connect(params)
  @options = {
    timeout: 20,
    method: 'get',
    headers: {
      "User-Agent": "v2FilteredStreamRuby",
      "Authorization": "Bearer #{@bearer_token}"
    },
    params: params
  }

  @request = Typhoeus::Request.new(@stream_url, @options)
  @request.on_body do |chunk|
    puts chunk
    puts "***** THIS IS WHERE I COULD CALL MAKING RETWEET *****"
  end
  @request.run
end

# Comment this line if you already setup rules and want to keep them
setup_rules

# Listen to the stream.
# This reconnection logic will attempt to reconnect when a disconnection is detected.
# To avoid rate limites, this logic implements exponential backoff, so the wait time
# will increase if the client cannot reconnect to the stream.
timeout = 0
while true
  stream_connect(params)
  sleep 2 ** timeout
  timeout += 1
end
