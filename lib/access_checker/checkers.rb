module AccessChecker

  # Container for checker classes
  #
  # Keeps a registry of known checker classes.
  #
  # A checker class MUST have an initializer accepting a browser and an url,
  # and it must respond to #result.
  #
  # A checker class SHOULD be defined in the AccessChecker::Checkers namespace.
  # (This is currently not enforced, but may be in the future.)
  #
  # A checker class SHOULD be registered through AccessChecker::Checkers.register
  # to enable use through Access::Checker::CLI.
  module Checkers

    class DuplicateKeyError < ArgumentError; end

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
    #
    # A subclass of BaseChecker SHOULD implement #verify for the actual access
    # checking logic and MAY override #visit to perform any extra navigation steps needed.
    #
    # A subclass of BaseChecker MAY instead directly override #result and
    # provide it's own navigation and access checking logic.
    #
    class BaseChecker

      # Registers the class in AccessChecker::Checkers::by_key
      def self.register(key, description=nil)
        Checkers.register(self, key, description)
      end

      attr_reader :b, :url, :page

      # Accepts a celerity browser instance and a URL string
      def initialize(browser, url)
        @b = browser
        @url = url
      end

      # Implementation of the required method for checker classes.
      #
      # Normally this shouldn't be overridden. It is preferred to override
      # #setup and/or #verify instead.
      #
      def result
        setup
        verify || "No rule matched"
      end

      # Performs the needed navigation to set the browser up for verification of
      # access. By default only visits url and sets @page to the found html
      #
      # May be overrided by subclasses that needs extra navigation steps
      #
      def setup
        b.goto url
        @page = b.html
      end

      private

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
        if page.match(/type="onlineread"/)
          access = "Access probably ok"
        else
          access = "Check access manually"
        end
      end
    end

    class AlexanderStreetPress < BaseChecker

      register "asp", "Alexander Street Press links"

      private

      def verify
        if page.include?("Page Not Found")
          access = "Page not found"
        elsif page.include?("error")
          access = "Error returned"
        elsif page.include?("Browse")
            access = "Full access"
        else
          access = "Check access manually"
        end
      end

    end

    class DukeUniversityPress < BaseChecker

      register "duphw", "Duke University Press (via HighWire)"

      private

      def verify
        if page.include?("DOI Not Found")
          access = "DOI error"
        else
          require 'open-uri'
          # I could find nothing on the ebook landing page to differentiate those to which we have full text access from those to which we do not.
          # This requires an extra step of having the checker visit one of the content pages, and testing whether one gets the content, or a log-in page
          url_title_segment = page.match(/http:\/\/reader\.dukeupress\.edu\/([^\/]*)\/\d+/).captures[0]
          content_url = "http://reader.dukeupress.edu/#{url_title_segment}/25"

          # Celerity couldn't handle opening the fulltext content pages that actually work,
          #  so I switch here to using open-uri to grab the HTML

          thepage = ""
          open(content_url) {|f|
            f.each_line {|line| thepage << line}
            }

          if thepage.include?("Log in to the e-Duke Books Scholarly Collection site")
            access = "No access"
          elsif thepage.include?("t-page-nav-arrows")
            access = "Full access"
          else
            access = "Check access manually"
          end
        end
      end

    end

    class Ebrary < BaseChecker

      register "ebr", "Ebrary links"

      private

      def verify
        if page.include?("Document Unavailable\.")
          access = "No access"
        elsif page.include?("Date Published")
          access = "Full access"
        else
          access = "Check access manually"
        end
      end

    end

    class EbscoHostEbookCollection < BaseChecker

      register "ebs", "EBSCOhost ebook collection"

      private

      def verify
        if page.match(/class="std-warning-text">No results/)
          access = "No access"
        elsif page.include?("eBook Full Text")
          access = "Full access"
        else
          access = "check"
        end
      end

    end

    class Endeca < BaseChecker

      register "end", "Endeca - Check for undeleted records"

      private

      def verify
        if page.include?("Invalid record")
          access = "deleted OK"
        else
          access = "possible ghost record - check"
        end
      end

    end

    class FMGFilmsOnDemand < BaseChecker

      register "fmgfod", "FMG Films on Demand"

      private

      def verify
        if page.include?("The title you are looking for is no longer available")
          access = "No access"
        elsif page.match(/class="now-playing-div/)
          access = "Full access"
        else
          access = "Check access manually"
        end
      end

    end

    class NCCO < BaseChecker

      register "nccorv", "NCCO - Check for related volumes"

      private

      def verify
        if page.match(/<div id="relatedVolumes">/)
          access = "related volumes section present"
        else
          access = "no related volumes section"
        end
      end

    end

    class SabinAmerica < BaseChecker

      register "sabov", "Sabin Americana - Check for Other Volumes"

      private

      def verify
        if page.match(/<a name="otherVols">/)
          access = "other volumes section present"
        else
          access = "no other volumes section"
        end
      end

    end

    class ScienceDirectEbooks < BaseChecker

      register "scid", "ScienceDirect ebooks (Elsevier)"

      private

      def verify
        if page.match(/<td class=nonSerialEntitlementIcon><span class="sprite_nsubIcon_sci_dir"/)
          access = "Restricted access"
        elsif page.match(/title="You are entitled to access the full text of this document"/)
          access = "Full access"
        else
          access = "check"
        end
      end

    end

    class SAGEKnowledge < BaseChecker

      register "skno", "SAGE Knowledge links"

      private

      def verify
        if page.include?("Page Not Found")
          access = "No access - page not found"
        elsif page.include?("Users without subscription are not able to see the full content")
          access = "Restricted access"
        elsif page.match(/class="restrictedContent"/)
          access = "Restricted access"
        elsif page.match(/<p class="lockicon">/)
          access = "Restricted access"
        else
          access = "Probable full access"
        end
      end

    end

    class SpringerLink < BaseChecker

      register "spr", "SpringerLink links"

      private

      def verify
        if page.match(/viewType="Denial"/) != nil
          access = "Restricted access"
        elsif page.match(/viewType="Full text download"/) != nil
          access = "Full access"
        elsif page.match(/DOI Not Found/) != nil
          access = "DOI error"
        elsif page.include?("Bookshop, Wageningen")
          access = "wageningenacademic.com"
        else
          access = "Check access manually"
        end
      end

    end

    class SAGEResearchMethodsOnline < BaseChecker

      register "srmo", "SAGE Research Methods Online links"

      private

      def verify
        if page.include?("Page Not Found")
          access = "No access - page not found"
        elsif page.include?("Add to Methods List")
          access = "Probable full access"
        else
          access = "Check access manually"
        end
      end

    end

    class SerialsSolutions < BaseChecker

      register "ss", "SerialsSolutions links"

      private

      def verify
        if page.include? "SS_NoJournalFoundMsg"
          access = "No access indicated"
        elsif page.include? "SS_Holding"
          access = "Access indicated"
        else
          access = "Check access manually"
        end
      end

    end

    class UniversityPressScholarshipOnline < BaseChecker

      register "upso", "University Press (inc. Oxford) Scholarship Online links"

      private

      def verify
        if page.include?("<div class=\"contentRestrictedMessage\">")
          access = "Restricted access"
        elsif page.include?("<div class=\"contentItem\">")
          access = "Full access"
        elsif page.include? "DOI Not Found"
          access = "DOI Error"
        else
          access = "Check access manually"
        end
      end

    end

    class WileyOnlineLibrary < BaseChecker

      register "wol", "Wiley Online Library"

      private

      def verify
        if page.include?("You have full text access to this content")
          access = "Full access"
        elsif page.include?("You have free access to this content")
          access = "Full access (free)"
        elsif page.include?("DOI Not Found")
          access = "DOI error"
        else
          access = "Check access manually"
        end
      end

    end

  end
end
