module AccessChecker
  module Checkers
    class CostelloChecker < BaseChecker
      register "cost", "Costello Test Checker"
      def verify
        case
        when session.has_content?("You are connecting from")
          "IP access"
        when session.has_content?("Inloggning till bibliotekets databaser")
          "No access"
        end
      end
    end
  end
end
