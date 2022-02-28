locals {
  config = {
    cookieNamePrefix     = var.cookie_name_prefix
    cookieChunkMaxLength = var.cookie_chunk_max_length
    cookieMaxCount       = var.cookie_max_count

    tokenExchangeHeader = var.token_exchange_header
    tokenDeadlineScale  = var.token_deadline_scale

    clientId     = var.client_id
    clientSecret = var.client_secret
    redirectUri  = var.redirect_uri

    issuer                = var.issuer
    tokenEndpoint         = var.token_endpoint != null ? var.token_endpoint : local.well_known_config.token_endpoint
    authorizationEndpoint = var.authorization_endpoint != null ? var.authorization_endpoint : local.well_known_config.authorization_endpoint

    jwks = jsondecode(data.http.jwks.body)

    viewerRequestHandler  = var.viewer_request_handler != null
    viewerResponseHandler = var.viewer_response_handler != null
  }

  lambda_checksum = sha1(join("", [for f in fileset("lambda-src", "*"): filesha1(f)]))

  archive_file_name = (
    var.lambda_code_archive_file != null
    ? var.lambda_code_archive_file
    : "${path.root}/${var.function_name}-${local.lambda_checksum}-lambda.zip"
    # : "${path.root}/${var.function_name}-${random_id.id.dec}-lambda.zip"
    # : "${path.cwd}/${var.function_name}-${local.lambda_checksum}-lambda.zip"
    # : "${path.cwd}/${var.function_name}-${random_id.id.dec}-lambda.zip"
  )
}

# locals {
  # # Hard code a list of files in the dir
  # cfn_files = [
  #   "lambda-src/index.js",
  #   "lambda-src/index.js",
  # ]

  # # Get the MD5 of each file in the directory
  # cfn_md5sums = [for f in local.cfn_files : filemd5(f)]

  # # Join the MD5 sums together and take the MD5 of all of them
  # # Effectively checksumming the pieces of the dir you care about
  # cfn_dirchecksum = md5(join("-", local.cfn_md5sums))
  # lambda_checksum = sha1(join("", [for f in fileset("lambda-src", "*"): filesha1(f)]))
# }

resource "random_id" "id" {
  byte_length = 8

  keepers = {
    timestamp = "${timestamp()}" # force change on every execution
  }

  # lifecycle {
  #   ignore_changes = [
  #     "keepers",
  #   ]
  # }
}

# data "null_data_source" "hash" {
#   inputs {
#     hash = "${md5(file("${path.module}/src/process.py"))}"
#   }
# }

data "archive_file" "lambda_code" {
  depends_on  = ["random_id.id"]
  type        = "zip"
  output_path = local.archive_file_name

  source {
    filename = "index.js"
    content  = file("${path.module}/lambda-src/index.js")
  }

  source {
    filename = "jwk.js"
    content  = file("${path.module}/lambda-src/jwk.js")
  }

  source {
    filename = "config.json"
    content  = jsonencode(local.config)
  }

  dynamic "source" {
    for_each = merge(
      var.viewer_request_handler == null ? {} : {
        viewer-request-handler = var.viewer_request_handler
      },
      var.viewer_response_handler == null ? {} : {
        viewer-response-handler = var.viewer_response_handler
      },
    )

    content {
      filename = "${source.key}.js"
      content  = source.value
    }
  }
}

module "lambda_role" {
  source  = "spirius/iam-role/aws"
  version = "~> 1.0"

  name                 = var.role_name != null ? var.role_name : "${var.function_name}-lambda"
  assume_role_services = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
  managed_policy_arns  = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
}

resource "aws_lambda_function" "authorizer" {
  filename         = data.archive_file.lambda_code.output_path
  source_code_hash = data.archive_file.lambda_code.output_base64sha256

  function_name = var.function_name
  role          = module.lambda_role.role.arn
  handler       = "index.handler"

  runtime     = "nodejs12.x"
  timeout     = 5
  memory_size = 128
  publish     = true
}
