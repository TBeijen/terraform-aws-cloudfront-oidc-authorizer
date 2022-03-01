# Change Log

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [0.0.1] - 2022-03-01
### Added:
* Forked and adapter from https://github.com/spirius/terraform-aws-cloudfront-oidc-authorizer. Changes:

    * Added ability to configure scope, as required by OneLogin
    * Adding `depends_on` to timestamp based random id. A workaround to ensure the zip archive is present at apply time. Downside: Always proposes changes.
