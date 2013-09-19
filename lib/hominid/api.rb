module Hominid
  class API
    # Blank Slate
    instance_methods.each do |m|
      undef_method m unless m.to_s =~ /^__|object_id|method_missing|respond_to?|to_s|inspect|kind_of?|nil?|should|should_not/
    end
    
    include Hominid::Campaign
    include Hominid::List
    include Hominid::Security
    
    # MailChimp API Documentation: http://apidocs.mailchimp.com/api/1.3/
    MAILCHIMP_API_VERSION = "1.3"

    # Initialize with an API key and config options
    def initialize(api_key, config = {})
      raise ArgumentError.new('Your Mailchimp API key appears to be malformed.') unless api_key.include?('-')
      dc = api_key.split('-').last
      defaults = {
        :api_version        => MAILCHIMP_API_VERSION,
        :domain             => 'api.mailchimp.com',
        :secure             => false,
        :timeout            => nil
      }
      @config = defaults.merge(config).freeze
      protocol = @config[:secure] ? 'https' : 'http'
      @api_key = api_key
      @chimpApi = XMLRPC::Client.new2("#{protocol}://#{dc}.#{@config[:domain]}/#{@config[:api_version]}/", nil, @config[:timeout])
      @chimpApi.http_header_extra = { 'accept-encoding' => 'identity' }
    end

    def method_missing(api_method, *args) # :nodoc:
      @chimpApi.call(camelize_api_method_name(api_method.to_s), @api_key, *args)
    rescue XMLRPC::FaultException => error
      super if error.faultCode == -32601
      raise APIError.new(error)
    end
    
    def respond_to?(api_method) # :nodoc:
      @chimpApi.call(api_method, @api_key)
    rescue XMLRPC::FaultException => error
      error.faultCode == -32601 ? false : true 
    end
    
    private

    def camelize_api_method_name(str)
      str.to_s[0].chr.downcase + str.gsub(/(?:^|_)(.)/) { $1.upcase }[1..str.size]
    end
  end
  
  class APIError < StandardError
    attr_accessor :fault_code
    def initialize(error)
      self.fault_code = error.faultCode
      super("<#{error.faultCode}> #{error.message}")
    end
  end

end
