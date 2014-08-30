require 'celerity'
require 'csv'
require 'highline/import'
require 'open-uri'

require 'access_checker'

module AccessChecker
  class CLI
    include AccessChecker::Checkers
    def self.run

      checker_classes = { "apb"    => ApabiEbooks,
                          "asp"    => AlexanderStreetPress,
                          "duphw"  => DukeUniversityPress,
                          "ebr"    => Ebrary,
                          "ebs"    => EbscoHostEbookCollection,
                          "end"    => Endeca,
                          "fmgfod" => FMGFilmsOnDemand,
                          "nccorv" => NCCO,
                          "sabov"  => SabinAmerica,
                          "scid"   => ScienceDirectEbooks,
                          "skno"   => SAGEKnowledge,
                          "spr"    => SpringerLink,
                          "srmo"   => SAGEResearchMethodsOnline,
                          "ss"     => SerialsSolutions,
                          "upso"   => UniversityPressScholarshipOnline,
                          "wol"    => WileyOnlineLibrary,
                        }

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

      checker_class = checker_classes[package]

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

      case package
      when "fmgfod"
        sleeptime = 10
      when "spr"
        b.css = false
        b.javascript_enabled = false
      end

      csv_data.each do |r|
        row_array = r.to_csv.parse_csv
        url = row_array.pop
        rest_of_data = row_array

        access = checker_class.new(b, url).result

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
