require_relative '../access_checker/results'
module AccessChecker

  # Container for checker classes
  #
  # Keeps a registry of known checker classes.
  #
  # A checker class MUST have an initializer accepting a Capybara session and an
  # URL, and it must respond to #result.
  #
  # A checker class SHOULD be defined in the AccessChecker::Checkers namespace.
  # (This is currently not enforced, but may be in the future.)
  #
  # A checker class SHOULD be registered through AccessChecker::Checkers.register
  # to enable use through Access::Checker::CLI.
  #
  module Checkers

    class DuplicateKeyError < ArgumentError; end

    # Value object class used for the Checkers registry
    CheckerEntry = Struct.new(:klass, :description)

    # Returns a hash with all known checker classes. Each hash value is an open
    # struct with the members +klass+ and +description+.
    def self.by_key
      @checkers_by_key ||= {}
    end

    # Registers a checker class as an open struct with members for +klass+ and
    # +description+ under the key +key+
    def self.register(klass, key, description=nil)
      key = String(key)
      if self.by_key[key].nil?
        description = description || klass.name
        self.by_key[key] = CheckerEntry.new(klass, description)
      else
        raise DuplicateKeyError, "%s is already registered for %s" % [
          key.inspect,
          self.by_key[key].klass.name,
        ]
      end
    end

    # Base class that defines the interface for checkers, and provides default
    # implementations for some of the methods
    #
    # A subclass of BaseChecker SHOULD implement #verify for the actual access
    # checking logic and MAY override #setup to perform any extra preparation
    # and/or navigation steps.
    #
    # A subclass of BaseChecker MAY instead directly override #result and
    # provide it's own navigation and access checking logic.
    #
    class BaseChecker

      include Results

      PRIVATE_INTERFACE = [:setup, :verify]

      # Tries to keep the internal interface methods private even in subclasses
      def self.method_added(method)
        private method if PRIVATE_INTERFACE.include? method
      end

      # Registers the class in AccessChecker::Checkers::by_key
      def self.register(key, description=nil)
        Checkers.register(self, key, description)
      end

      attr_reader :session, :url

      # Accepts a celerity browser instance and a URL string
      def initialize(session, url)
        @session = session
        @url = url
      end

      # Default implementation of the required method for checker classes.
      #
      # Normally this shouldn't be overridden. It is preferred to override
      # #setup and/or #verify instead.
      #
      def result
        setup
        verify || NoRuleMatchedResult.new("No rule matced (default fallback)")
      end

      private

      # Performs the needed navigation to set the browser up for verification of
      # access. By default only visits url and sets @page to the found html
      #
      # May be overrided by subclasses that needs extra navigation steps
      #
      def setup
        session.visit url
      end

      # Subclasses should implement this with the logic for verifying access
      #
      # The method should only be called internally and directly after setup and
      # should be able to rely on the state of the session from setup.
      #
      # (Keep implementations private or treat them as if they were!)
      #
      def verify
        raise NotImplementedError, "Subclasses of BaseChecker should define #verify"
      end

    end

    class ApabiEbooks < BaseChecker

      register "apb", "Apabi ebooks"

      private

      def verify
        case
        when session.html.match(/type="onlineread"/)
          ProbableFullAccessResult.new
        end
      end
    end

    class AlexanderStreetPress < BaseChecker

      register "asp", "Alexander Street Press links"

      private

      def verify
        case
        when session.html.include?("Page Not Found")
          PageNotFoundResult.new
        when session.html.include?("error")
          ErrorResult.new
        when session.html.include?("Browse")
          FullAccessResult.new
        end
      end

    end

    class Dawsonera < BaseChecker

      register "daw", "Dawsonera eBooks"

      # Makes sure Capybara Session timeout is set to at least 60 seconds during
      # the ordinary setup. (Dawsonera is javascript heavy and can easily
      # timeout with the default 30 seconds.)
      def setup
        old_timeout = session.driver.timeout
        session.driver.timeout = [old_timeout, 90].max
        super
        session.driver.timeout = old_timeout
      end

      def verify
        session.within ".result-features" do
          case
          when session.has_content?("Read online")
            FullAccessResult.new
          when session.has_content?("Preview")
            NoAccessResult.new
          end
        end
      rescue Capybara::ElementNotFound => e
        ErrorResult.new(e.inspect)
      end

    end

    class DukeUniversityPress < BaseChecker

      register "duphw", "Duke University Press (via HighWire)"

      private

      def verify
        case
        when session.html.include?("DOI Not Found")
          DOIErrorResult.new
        else
          require 'open-uri'
          # I could find nothing on the ebook landing page to differentiate those to which we have full text access from those to which we do not.
          # This requires an extra step of having the checker visit one of the content pages, and testing whether one gets the content, or a log-in page
          url_title_segment = session.html.match(/http:\/\/reader\.dukeupress\.edu\/([^\/]*)\/\d+/).captures[0]
          content_url = "http://reader.dukeupress.edu/#{url_title_segment}/25"

          # Celerity couldn't handle opening the fulltext content pages that actually work,
          #  so I switch here to using open-uri to grab the HTML

          thepage = open(content_url) {|f| f.read }

          if thepage.include?("Log in to the e-Duke Books Scholarly Collection site")
            NoAccessResult.new
          elsif thepage.include?("t-page-nav-arrows")
            FullAccessResult.new
          end
        end
      end

    end

    class Ebrary < BaseChecker
      register "ebr", "Ebrary links"

      private

      def verify
        case
        when session.html.include?("Document Unavailable\.")
          NoAccessResult.new
        when session.html.include?("Date Published")
          FullAccessResult.new
        end
      end

    end

    class EbscoHostEbookCollection < BaseChecker

      register "ebs", "EBSCOhost ebook collection"

      private

      def verify
        case
        when session.html.match(/class="std-warning-text">No results/)
          NoAccessResult.new
        when session.html.include?("eBook Full Text")
          FullAccessResult.new
        end
      end

    end

    class Endeca < BaseChecker

      register "end", "Endeca - Check for undeleted records"

      private

      def verify
        case
        when session.html.include?("Invalid record")
          SuccessResult.new "Deleted OK"
        else
          FailureResult.new "Possible ghost record"
        end
      end

    end

    class FMGFilmsOnDemand < BaseChecker

      register "fmgfod", "FMG Films on Demand"

      private

      def verify
        case
        when session.html.include?("The title you are looking for is no longer available")
          NoAccessResult.new
        when session.html.match(/class="now-playing-div/)
          FullAccessResult.new
        end
      end

    end

    class NCCO < BaseChecker

      register "nccorv", "NCCO - Check for related volumes"

      private

      def verify
        case
        when session.html.match(/<div id="relatedVolumes">/)
          SuccessResult.new "related volumes section present"
        else
          FailureResult.new "no related volumes section"
        end
      end

    end

    class SabinAmerica < BaseChecker

      register "sabov", "Sabin Americana - Check for Other Volumes"

      private

      def verify
        case
        when session.html.match(/<a name="otherVols">/)
          SuccessResult.new "other volumes section present"
        else
          FailureResult.new "no other volumes section"
        end
      end

    end

    class ScienceDirectEbooks < BaseChecker

      register "scid", "ScienceDirect ebooks (Elsevier)"

      private

      def setup
        super
        session.find("#sppart1 a").click if session.has_selector?("#sppart1 a")
      end

      def verify
        case
        when session.has_selector?('span[title="You are not entitled to access the full text and this document is not for purchase."]')
          RestrictedAccessResult.new
        when session.html.match(/<td class=nonSerialEntitlementIcon><span class="sprite_nsubIcon_sci_dir"/)
          RestrictedAccessResult.new
        when session.html.match(/title="You are entitled to access the full text of this document"/)
          FullAccessResult.new
        when session.has_selector?('span[title="Entitled to full text"]', :minimum => 6)
          FullAccessResult.new
        when session.has_selector?('span[title="Entitled to full text"]', :minimum => 3)
          ProbableFullAccessResult.new
        end
      end

    end

    class SAGEKnowledge < BaseChecker

      register "skno", "SAGE Knowledge links"

      private

      def verify
        case
        when session.html.include?("Page Not Found")
          PageNotFoundResult.new
        when session.html.include?("Users without subscription are not able to see the full content")
          RestrictedAccessResult.new
        when session.html.match(/class="restrictedContent"/)
          RestrictedAccessResult.new
        when session.html.match(/<p class="lockicon">/)
          RestrictedAccessResult.new
        else
          ProbableFullAccessResult.new
        end
      end

    end

    class SpringerLink < BaseChecker

      register "spr", "SpringerLink links"

      private

      def verify
        case
        when session.html.match(/viewType="Denial"/) != nil
          RestrictedAccessResult.new
        when session.html.match(/viewType="Full text download"/) != nil
          FullAccessResult.new
        when session.html.match(/DOI Not Found/) != nil
          DOIErrorResult.new
        when session.html.include?("Bookshop, Wageningen")
          NoAccessResult.new
          "wageningenacademic.com"
        end
      end

    end

    class SAGEResearchMethodsOnline < BaseChecker

      register "srmo", "SAGE Research Methods Online links"

      private

      def verify
        case
        when session.html.include?("Page Not Found")
          PageNotFoundResult.new
        when session.html.include?("Add to Methods List")
          ProbableFullAccessResult.new
        end
      end

    end

    class SerialsSolutions < BaseChecker

      register "ss", "SerialsSolutions links"

      private

      def verify
        case
        when session.html.include?("SS_NoJournalFoundMsg")
          NoAccessResult.new "No access indicated"
        when session.html.include?("SS_Holding")
          FullAccessResult.new "Access indicated"
        end
      end

    end

    class UniversityPressScholarshipOnline < BaseChecker

      register "upso", "University Press (inc. Oxford) Scholarship Online links"

      private

      def verify
        case
        when session.html.include?("<div class=\"contentRestrictedMessage\">")
          RestrictedAccessResult.new
        when session.html.include?("<div class=\"contentItem\">")
          FullAccessResult.new
        when session.html.include?("DOI Not Found")
          DOIErrorResult.new
        end
      end

    end

    class WileyOnlineLibrary < BaseChecker

      register "wol", "Wiley Online Library"

      private

      def verify
        case
        when session.html.include?("You have full text access to this content")
          FullAccessResult.new
        when session.html.include?("You have free access to this content")
          FullAccessResult.new "Free"
        when session.html.include?("DOI Not Found")
          DOIErrorResult.new
        end
      end

    end

  end
end
