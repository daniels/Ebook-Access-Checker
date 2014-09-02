require 'celerity'
require 'csv'
require 'highline/import'
require 'open-uri'

require 'access_checker'

module AccessChecker
  class CLI
    def self.run

      checkers = Checkers.by_key
      max_key_length = checkers.keys.map { |key| key.length }.max

      puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
      puts "What platform/package are you access checking?"
      puts "Type one of the following:"

      checkers.keys.sort.each do |key|
        description = checkers[key].description
        puts sprintf("  %-#{max_key_length}s : %s", key, description)
      end

      puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="

      package = ask("Package?  ")

      checker_class = checkers.fetch(package).klass

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
