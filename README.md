# spinel-aws-sdk-codegen

Writes the Spinel packages' service clients (`Aws::STS` inside
aws-sdk-core, and `Aws::SSM`) as plain, explicit Ruby, from the same `api-2.json` model the
aws-sdk-ruby gem is generated from. One method per operation serializes the
request and parses the response field by field, so nothing walks a model at
run time and Spinel compiles every line.

Runs under CRuby only. It is a build tool, not a spin package.

## Usage

```sh
bin/generate API_JSON MODULE PREFIX OUT_DIR [--operations A,B] [--check-against-gem]

# STS, into the aws-sdk-core package
bin/generate ../spinel-aws-notes/upstream/aws-sdk-ruby-apis/sts/2011-06-15/api-2.json \
  STS aws-sdk-sts ../spinel-aws-sdk-core --check-against-gem

# SSM, into the aws-sdk-ssm package
bin/generate ../spinel-aws-notes/upstream/aws-sdk-ruby-apis/ssm/2014-11-06/api-2.json \
  SSM aws-sdk-ssm ../spinel-aws-sdk-ssm --check-against-gem

# only some operations, the structures they reach and their errors
bin/generate ../spinel-aws-notes/upstream/aws-sdk-ruby-apis/ssm/2014-11-06/api-2.json \
  SSM aws-sdk-ssm OUT_DIR --operations GetParameter,PutParameter
```

It writes `PREFIX.rb` and `PREFIX/{types,errors,serializers,parsers,stubs,client}.rb`
under `OUT_DIR`. The output is deterministic: the same model gives the same
files. `--operations` keeps only those operations, the structures they reach
and their errors. A `paginators-1.json` next to the model clears the paging
tokens of the default stubs, as the gem does, and gives a paginated
operation's response `last_page?` and its next page (a paginator of one
top-level token; any other is refused).

`--check-against-gem` first loads the real gem (aws-sdk-core for STS,
aws-sdk-PREFIX otherwise) and stops unless
every structure's member names match the gem's `ClientApi`, so the generated
names are the gem's. It needs the gem installed in the Ruby that runs the
generator.

## Scope

The `query` protocol (STS) and the `json` protocol (SSM); the model's
protocol picks the generator. A union is generated as the gem's: its
members plus `unknown`, `member` and `value`, and a subclass per member
(`NodeType::Instance`) for what a response or a stub gives; unions are
generated for the `json` protocol only. For the `json` protocol an error's
`data` is parsed as the gem's `Json::ErrorHandler` does: the modeled error the
code names, when the operation lists it, with a reader per member on the
error class. Document shapes are not supported
yet. The models are read from aws-sdk-ruby at
`1113d9b05fdf26bbf147e4c4936a9e446ae27ad5`, the commit aws-sdk-core 3.257.0
and aws-sdk-ssm 1.223.0 ship from.

## Provenance

`lib/codegen/underscore.rb` is ported from aws-sdk-ruby (Apache-2.0),
`build_tools/aws-sdk-code-generator`, so model names become the gem's Ruby
names.

## License

Apache-2.0, as aws-sdk-ruby. See `LICENSE` and `NOTICE`.
