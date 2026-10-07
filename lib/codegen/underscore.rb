# frozen_string_literal: true

# Ported from aws-sdk-ruby (Apache-2.0),
# build_tools/aws-sdk-code-generator/lib/aws-sdk-code-generator/underscore.rb
# at 1113d9b05fdf26bbf147e4c4936a9e446ae27ad5: the rule that turns a model
# name into the Ruby name the gem uses, so generated names match the gem's.
module Codegen
  module Underscore
    IRREGULAR = {
      'ARNs' => 'arns',
      'CNAMEs' => 'cnames',
      'ETag' => 'etag',
      'Ec2' => 'ec2',
      'ElastiCache' => 'elasticache',
      'iSCSI' => 'iscsi',
      'ACLs' => 'acls',
      'Md5s' => 'md5s',
      'HIT' => 'hit',
      'URL' => 'url',
    }.freeze
    IRREGULAR_REGEX = Regexp.new(IRREGULAR.keys.join('|'))

    def self.underscore(string)
      new_string = string.dup
      new_string.gsub!(IRREGULAR_REGEX) { |word| "_#{IRREGULAR[word]}" }
      new_string.gsub!(/([A-Z0-9]+)([A-Z][a-z])/, '\1_\2')
      new_string = new_string.scan(/[a-z0-9]+|\d+|[A-Z0-9]+[a-z]*/).join('_')
      new_string.downcase!
      new_string
    end
  end
end
