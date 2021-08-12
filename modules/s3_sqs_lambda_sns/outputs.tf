output "resource_name" {
  value = local.resource_name
}

output "queue_arn" {
  value = aws_sqs_queue.s3_event_queue.arn
}
