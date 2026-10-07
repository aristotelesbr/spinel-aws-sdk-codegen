# frozen_string_literal: true

module Codegen
  # Error codes any AWS service may return without its model listing them.
  # The gem names the raised class after the code at run time (DynamicErrors
  # sets a constant the first time a code is seen); Spinel cannot create a
  # class at run time, so every service gets these classes generated, and
  # `rescue Aws::<Service>::Errors::AccessDenied` works as with the gem. A
  # code in neither the model nor this list raises the service's ServiceError
  # with that code.
  module CommonErrors
    # https://docs.aws.amazon.com/STS/latest/APIReference/CommonErrors.html
    # (2026-10-07)
    DOCUMENTED = %w[
      AccessDeniedException ExpiredTokenException IncompleteSignature
      InternalFailure InvalidParameterCombination InvalidParameterValue
      InvalidQueryParameter MalformedQueryString MissingAction
      MissingAuthenticationToken MissingParameter NotAuthorized OptInRequired
      RequestExpired ServiceUnavailable ThrottlingException
      UnrecognizedClientException ValidationError
    ].freeze

    # The codes aws-sdk-core 3.257.0 names in
    # lib/aws-sdk-core/plugins/retries/error_inspector.rb: EXPIRED_CREDS,
    # THROTTLING_ERRORS, CHECKSUM_ERRORS, NETWORKING_ERRORS and
    # CLOCK_SKEW_ERRORS.
    GEM_RETRY_LOGIC = %w[
      InvalidClientTokenId UnrecognizedClientException InvalidAccessKeyId
      AuthFailure InvalidIdentityToken ExpiredToken ExpiredTokenException
      Throttling ThrottlingException ThrottledException RequestThrottled
      RequestThrottledException ProvisionedThroughputExceededException
      TransactionInProgressException RequestLimitExceeded
      BandwidthLimitExceeded LimitExceededException TooManyRequestsException
      PriorRequestNotComplete SlowDown EC2ThrottledException
      CRC32CheckFailed BadDigest
      RequestTimeout InternalError RequestTimeoutException IDPCommunicationError
      RequestTimeTooSkewed RequestExpired InvalidSignatureException
      SignatureDoesNotMatch AuthFailure RequestInTheFuture
    ].freeze

    # Returned by query services such as STS and IAM when a policy denies the
    # call (an AssumeRole the role's trust policy does not allow, for one),
    # and in neither list above.
    OBSERVED = %w[AccessDenied].freeze

    ALL = (DOCUMENTED + GEM_RETRY_LOGIC + OBSERVED).uniq.sort.freeze
  end
end
