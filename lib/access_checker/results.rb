#!/usr/bin/env ruby
module AccessChecker

  # Module containing result classes for access checking
  #
  # Using a class hierarchy rather than plain strings should give client
  # applications a good way to respond differently to different kind of results,
  # much like they can chose to handle errors of different kind differently in
  # regular Ruby code.
  #
  module Results

    # Base class for all results that defines the interface
    #
    # Each result has a #name based on the class name, and an accessor
    # #message, that is set on initialization.
    #
    # This class is not intended to instantiated, only subclassed
    Result = Struct.new(:message) do
      def name
        self.class.name.split("::").last.gsub(/(\w+)Result$/, '\1')
      end

      def message
        String(@message)
      end

      def to_s
        "#<#{ [name, message].compact.join(": ") }>"
      end
    end

    ### Success responses ###

    # Parent class for all result classes indicating a successful result
    SuccessResult            = Class.new(Result)

    # Used when full access could be verified
    FullAccessResult         = Class.new(SuccessResult)

    # Used when full access is probable but could not be fully verified.
    #
    # An example usage is when there isn't a known positive indicator on the
    # page, but only a set of known negative indicators. If no negative
    # indicator matches, it probably means full access, but there is still the
    # possibility that an unknown negative indicator was present.
    #
    # It is recommended to use the message to explain the reason of the
    # uncertainty
    ProbableFullAccessResult = Class.new(SuccessResult)


    ### Failure responses ###

    # Parent class for all failure results, either a negative result or a
    # failure to complete the check.
    FailureResult            = Class.new(Result)

    ## Errors ##

    # Indicates that an error occured that prevented the actual access status
    # from being retreived.
    #
    # This class can be used by itself or subclassed to give more information on
    # the kind of error
    ErrorResult              = Class.new(FailureResult)

    # Default result when no match - neither positive or negative - was found
    NoRuleMatchedResult      = Class.new(ErrorResult)

    # The URL was a DOI that failed to resolve
    DOIErrorResult           = Class.new(ErrorResult)

    # Page could not be found
    PageNotFoundResult       = Class.new(ErrorResult)

    ## No access ##

    # Used when verification indicated that full access was not available
    NoAccessResult           = Class.new(FailureResult)

    # Don't know what this is for - it replaces the string result "Restricted
    # access" that was used in some places instead of "No access" ...
    RestrictedAccessResult   = Class.new(NoAccessResult)

  end

end
