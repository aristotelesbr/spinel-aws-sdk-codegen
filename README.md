# spinel-aws-sdk-codegen

Writes the Spinel packages' service clients (first `Aws::STS`, inside
aws-sdk-core) as plain, explicit Ruby, from the same `api-2.json` model the
aws-sdk-ruby gem is generated from. One method per operation serializes the
request and parses the response field by field, so nothing walks a model at
run time and Spinel compiles every line.

Runs under CRuby only. It is a build tool, not a spin package.

## Usage

```sh
bin/generate API_JSON MODULE PREFIX OUT_DIR [--check-against-gem]

# STS, into the aws-sdk-core package
bin/generate ../spinel-aws-notes/upstream/aws-sdk-ruby-apis/sts/2011-06-15/api-2.json \
  STS aws-sdk-sts ../spinel-aws-sdk-core --check-against-gem
```

It writes `PREFIX.rb` and `PREFIX/{types,errors,serializers,parsers,stubs,client}.rb`
under `OUT_DIR`. The output is deterministic: the same model gives the same
files.

`--check-against-gem` first loads the real aws-sdk-core gem and stops unless
every structure's member names match the gem's `ClientApi`, so the generated
names are the gem's. It needs the gem installed in the Ruby that runs the
generator.

## Scope

Only the `query` protocol (STS). The model is read from aws-sdk-ruby at
`1113d9b05fdf26bbf147e4c4936a9e446ae27ad5`, the commit aws-sdk-core 3.257.0
ships from.

## Provenance

`lib/codegen/underscore.rb` is ported from aws-sdk-ruby (Apache-2.0),
`build_tools/aws-sdk-code-generator`, so model names become the gem's Ruby
names.

## License

Apache-2.0, as aws-sdk-ruby. See `LICENSE` and `NOTICE`.
