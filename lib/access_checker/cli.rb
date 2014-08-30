require 'celerity'
require 'csv'
require 'highline/import'
require 'open-uri'

require 'access_checker'

module AccessChecker
  class CLI
    include AccessChecker::Checkers
    def self.run

      puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
      puts "What platform/package are you access checking?"
      puts "Type one of the following:"
      puts "  apb    : Apabi ebooks"
      puts "  asp    : Alexander Street Press links"
      puts "  duphw  : Duke University Press (via HighWire)"
      puts "  ebr    : Ebrary links"
      puts "  ebs    : EBSCOhost ebook collection"
      puts "  end    : Endeca - Check for undeleted records"
      puts "  fmgfod : FMG Films on Demand"
      puts "  nccorv : NCCO - Check for related volumes"
      puts "  sabov  : Sabin Americana - Check for Other Volumes"
      puts "  scid   : ScienceDirect ebooks (Elsevier)"
      puts "  spr    : SpringerLink links"
      puts "  skno   : SAGE Knowledge links"
      puts "  srmo   : SAGE Research Methods Online links"
      puts "  ss     : SerialsSolutions links"
      puts "  upso   : University Press (inc. Oxford) Scholarship Online links"
      puts "  wol    : Wiley Online Library"
      puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="

      package = ask("Package?  ")

      puts "\nPreparing to check access...\n"

      input = ARGV[0]
      output = ARGV[1]

      csv_data = CSV.read(input, :headers => true)

      counter = 0
      total = csv_data.count

      headers = csv_data.headers
      headers << "access"

      CSV.open(output, "a") do |c|
        c << headers
      end

      b = Celerity::Browser.new(:browser => :firefox)
      #b = Celerity::Browser.new(:browser => :firefox, :log_level => :all)

      sleeptime = 1

      if package == "spr"
          b.css = false
          b.javascript_enabled = false
      end

      csv_data.each do |r|
        row_array = r.to_csv.parse_csv
        url = row_array.pop
        rest_of_data = row_array

        access = if package == "apb"
          ApabiEbooks.new(b, url).result
        elsif package == "asp"
          AlexanderStreetPress.new(b, url).result
        elsif package == "duphw"
          DukeUniversityPress.new(b, url).result
        elsif package == "ebr"
          Ebrary.new(b, url).result
        elsif package == "ebs"
          EbscoHostEbookCollection.new(b, url).result
        elsif package == "end"
          Endeca.new(b, url).result
        elsif package == "fmgfod"
          sleeptime = 10
          FMGFilmsOnDemand.new(b, url).result
        elsif package == "nccorv"
          NCCO.new(b, url).result
        elsif package == "sabov"
          SabinAmerica.new(b, url).result
        elsif package == "scid"
          ScienceDirectEbooks.new(b, url).result
        elsif package == "skno"
          SAGEKnowledge.new(b, url).result
        elsif package == "spr"
          SpringerLink.new(b, url).result
        elsif package == "srmo"
          SAGEResearchMethodsOnline.new(b, url).result
        elsif package == "ss"
          SerialsSolutions.new(b, url).result
        elsif package == "upso"
          UniversityPressScholarshipOnline.new(b, url).result
        elsif package == 'wol'
          WileyOnlineLibrary.new(b, url).result
        end

        CSV.open(output, "a") do |c|
          c << [rest_of_data, url, access].flatten
        end

        counter += 1
        puts "#{counter} of #{total}, access = #{access}"

        sleep sleeptime
      end
    end
  end
end
