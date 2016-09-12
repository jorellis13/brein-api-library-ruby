require 'net/https'
require 'json'
require 'base64'
require 'logger'
require 'rubygems/request'

require File.join(File.dirname(__FILE__), "/Breinify/version.rb")

module Breinify

  # logger
  @@logger = Logger.new(STDOUT)
  @@logger.sev_threshold = Logger::DEBUG
  # @@logger = Logger.new('breinify.log', 'daily')

  ## default values

  ##
  #  default endpoint of activity
  @@defaultActivityEndpoint = '/activity'

  ##
  # default endpoint of lookup
  @@defaultLookupEndpoint = '/lookup'

  ##
  # default breinify url
  @@defaultUrl = 'https://api.breinify.com'

  ##
  # default secret value
  @@defaultSecret = nil

  ##
  # default timeout
  @@defaultTimeout = 6000

  ## module values

  ##
  # contains the url
  @@url

  ##
  # contains the api key
  @@apiKey

  ##
  # contains the secret
  @@secret

  ##
  # contains the timeout (in ms)
  @@timeout

  ##
  # == Description
  #
  # sets the Breinify Configuration of the library for the properties supplied.
  #
  # - possible parameters are:
  #    apiKey: The API-key to be used (mandatory).
  #    url: The url of the API
  #    activityEndpoint: The end-point of the API to send activities.
  #    lookupEndpoint: The end-point of the API to retrieve lookup results.
  #    secret: The secret attached to the API-key
  #    timeout: The maximum amount of time in milliseconds an API-call should take.
  #             If the API does not response after this amount of time, the call is cancelled.
  #
  # If no parameters are set the default parameters will be used.
  #
  def self.setConfig(options = {})

    if options == nil
      @@logger.debug 'BreinifyConfig: values are nil'
      return
    end

    begin
      @@apiKey = options.fetch('apiKey', '')
      @@logger.debug ('apiKey: ' + @@apiKey)

      @@url = options.fetch('url', @@defaultUrl)
      @@logger.debug ('url: ' + @@url)

      @@activityEndpoint = options.fetch('activityEndpoint', @@defaultActivityEndpoint)
      @@logger.debug ('ActivityEndpoint: ' + @@activityEndpoint)

      @@lookupEndpoint = options.fetch('lookupEndpoint', @@defaultLookupEndpoint)
      @@logger.debug ('LookupEndpoint: ' + @@lookupEndpoint)

      @@secret = options.fetch('secret', @@defaultSecret)
      @@logger.debug ('Secret: ' + @@secret)

      @@timeout = options.fetch(:'timeout', @@defaultTimeout)
      @@logger.debug ('Timeout: ' + @@timeout.to_s)

    rescue Exception => e
      @@logger.debug 'Exception caught: ' + e.message
      @@logger.debug '  Backtrace is: ' + e.backtrace.inspect
      return
    end

  end

  ##
  # == Description
  #
  # Sends an activity to the engine utilizing the API.
  # The call is done asynchronously as a POST request.
  # It is important that a valid API-key is configured prior
  # to using this function.
  #
  # Possible parameters are:
  #
  # Example:
  #
  #
  def self.activity(options = {})

    if options == nil
      @@logger.debug 'Breinify activity: values are nil'
      return
    end

    begin

      # unix timestamp
      unixTimestamp = Time.now.getutc.to_i
      @@logger.debug 'Unix timestamp is: ' + unixTimestamp.to_s

      @@logger.debug 'activity values are: ' + options.to_s

      ## the following fields have to be added
      # apiKey
      # unixTimestamp
      # secret (if set)

      data = options
      data['apiKey'] = @@apiKey
      data['unixTimestamp'] = unixTimestamp

      signature = handleSignature(options, unixTimestamp)
      if signature != nil
        data['signature'] = signature
      end

      ## add the userAgent
      userAgent = retrieveUserAgentInformation

      # fetch previous values - if they exists
      begin
        additionalValues = options.fetch('user', {}).fetch('additional', {})
        if additionalValues.empty?

          userAgentHash = Hash.new
          userAgentHash['userAgent'] = userAgent

          userData = options.fetch('user', {})
          userData['additional'] = userAgentHash
        else
          additionalValues['userAgent'] = userAgent
        end
      rescue
        @@logger.debug 'Could not handle userAgent information'
      end

      # url to use with actvity endpoint
      fullUrl = @@url + @@activityEndpoint

      # retrieve all the options
      uri = URI(fullUrl)

      # Create the HTTP objects
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      request = Net::HTTP::Post.new(uri.request_uri, {'accept': 'application/json'})
      request.body = data.to_json
      @@logger.debug 'JSON data request is: ' + data.to_json.to_s

      # Send the request
      response = http.request(request)
      @@logger.debug 'response from call is: ' + response.to_s

    rescue Exception => e
      @@logger.debug 'Exception caught: ' + e.message
      @@logger.debug '  Backtrace is: ' + e.backtrace.inspect
      return
    end

  end

  ##
  # == Description
  #
  def self.retrieveUserAgentInformation
    begin
      userAgent = request.user_agent
      @@logger.debug 'userAgent is: ' + userAgent
    rescue
      @@logger.debug 'Sorry, no userAgent can be detected'
      userAgent = nil
    end
    userAgent
  end

  ##
  # == Description
  #
  # Handles the signature...
  #
  def self.handleSignature(options, unixTimestamp)
    signature = nil
    if @@secret != nil

      activityData = options.fetch('activity', nil)
      activityType = activityData.fetch('type', nil)
      message = activityType + unixTimestamp.to_s + '1'
      hash = OpenSSL::HMAC.digest('sha256', @@secret, message)
      signature = Base64.encode64(hash).strip

      # @@logger.debug 'Secret value is: ' + signature
    end
    signature
  end


end

