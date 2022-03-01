# AWS CloudFront Authorizer Terraform module

The resulting lambda should be configured as `viewer-request` and `viewer-response` association for the distribution.

The authorizer supports JWK keys verification with `RS256` keys. Tokens are stored in cookies. Token refresh flow is supported.

## Example

*Note: Lambda@Edge should be in `us-east-1` region.*

```hcl

module "onelogin_secrets" {
  source                = "git::ssh://git@bitbucket.dpgmm.nl:7999/tfmod/secrets_management.git?ref=0.1.1"
  enable_secretsmanager = true
  secret_id             = "onelogin_secrets"
  tags                  = var.tags
  secret = {
    client-id     = "<added via console>"
    client-secret = "<added via console>"
  }
  manage_secret_manually = true
}

data "aws_secretsmanager_secret" "onelogin" {
  arn = module.onelogin_secrets.secretsmanager_arn
}

data "aws_secretsmanager_secret_version" "onelogin" {
  secret_id = data.aws_secretsmanager_secret.onelogin.id
}

module "cloudfront_authorizer" {
  providers = {
    aws = aws.us-east-1
  }

  source  = "git::ssh://git@bitbucket.dpgmm.nl:7999/news/tfmod_cloudfront_oidc_authorizer.git?ref=<TAG>"

  function_name = "cloudfront-authorizer"

  issuer        = "https://persgroep.onelogin.com/oidc/2"
  client_id     = jsondecode(data.aws_secretsmanager_secret_version.onelogin.secret_string)["client-id"]
  client_secret = jsondecode(data.aws_secretsmanager_secret_version.onelogin.secret_string)["client-secret"]
  redirect_uri  = format("https://%s/auth/provider/callback", var.domain_name)
}

resource "aws_cloudfront_distribution" "dist" {
  ...
  aliases = [var.domain_name]

  default_cache_behavior {

    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = module.cloudfront_authorizer.lambda.qualified_arn
      include_body = false
    }

    lambda_function_association {
      event_type   = "viewer-response"
      lambda_arn   = module.cloudfront_authorizer.lambda.qualified_arn
      include_body = false
    }

    ...
  }
}
```
