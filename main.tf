data "aws_sns_topic" "this" {
  count = "${1 - var.create_sns_topic}"

  name = "${var.sns_topic_name}"
}

resource "aws_sns_topic" "this" {
  count = "${var.create_sns_topic}"

  name = "${var.sns_topic_name}"
}

locals {
  sns_topic_arn = "${element(compact(concat(aws_sns_topic.this.*.arn, data.aws_sns_topic.this.*.arn)), 0)}"
  source_path   = "${path.module}/functions/notify_slack.py"
}

resource "aws_sns_topic_subscription" "sns_notify_slack" {
  topic_arn = "${local.sns_topic_arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.notify_slack.arn}"
}

resource "aws_lambda_permission" "sns_notify_slack" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.notify_slack.function_name}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${local.sns_topic_arn}"
}

resource "aws_s3_bucket_object" "notify_slack" {
  bucket         = "calderalabs-terraform"
  key            = "notify_slack"
  content_base64 = "${base64gzip(file(local.source_path))}"
  content_type   = "application/gzip"
}

resource "aws_lambda_function" "notify_slack" {
  s3_bucket        = "calderalabs-terraform"
  s3_key           = "notify_slack"
  function_name    = "${var.lambda_function_name}"
  role             = "${aws_iam_role.lambda.arn}"
  handler          = "notify_slack.lambda_handler"
  source_code_hash = "${sha256(base64gzip(file(local.source_path)))}"
  runtime          = "python3.6"
  timeout          = 30
  kms_key_arn      = "${var.kms_key_arn}"

  environment {
    variables = {
      SLACK_WEBHOOK_URL = "${var.slack_webhook_url}"
      SLACK_CHANNEL     = "${var.slack_channel}"
      SLACK_USERNAME    = "${var.slack_username}"
    }
  }
}
