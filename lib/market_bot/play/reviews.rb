module MarketBot
  module Play
    class Reviews

      attr_reader :result

      def self.parse(input, opts={})
        results = []

        # Get rid of junk at the front
        input.gsub!(/\A.+?" /m, '')
        # Get rid of junk at the end
        input.gsub!(/",0.+/m, '')
        html = ActiveSupport::JSON.decode("[\"#{input}\"]").first

        doc = Nokogiri::HTML(html)
        reviews = doc.css('.single-review')
        reviews.each do |review|
          result = {}
          result[:author] = review.at_css('.author-name').text.strip
          result[:date] = Date.parse(review.at_css('.review-date').text.strip)
          result[:review] = review.at_css('.review-body').text.strip.gsub(/\s+Full Review/,'')
          review.at_css('.star-rating-non-editable-container')['aria-label'].match(/(\d)/)
          result[:rating] = $1
          result[:uid] = review.at_css('.review-header')['data-reviewid']
          results.push(result)
        end
        results
      end

      def initialize(app, opts = {})
        @package = app.package
      end

      def update(user_opts = {})
        options = {method: :post,
          params: {id: @package,
            reviewSortOrder: 0,
            reviewType: 0,
            pageNum: 0,
            xhr: 1}
        }
        req = Typhoeus::Request.new('https://play.google.com/store/getreviews?authuser=0',
          options.merge(user_opts)
        )
        req.run
        response_handler(req.response)

        self
      end

      private

      def response_handler(response)
        if response.success?
          @result = self.class.parse(response.body)
        else
          codes = "code=#{response.code}, return_code=#{response.return_code}"
          case response.code
          when 404
            raise MarketBot::NotFoundError.new("Unable to find reviews in store: #{codes}")
          when 403
            raise MarketBot::UnavailableError.new("Unavailable reviews (country restriction?): #{codes}")
          else
            raise MarketBot::ResponseError.new("Unhandled response: #{codes}")
          end
        end
      end


    end
  end
end
