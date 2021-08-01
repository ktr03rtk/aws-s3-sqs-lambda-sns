package main

import (
	"context"
	"encoding/json"
	"log"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sns"
	"github.com/pkg/errors"
)

var (
	topicArn string
	region   string
)

func getEnvVal() error {
	t, ok := os.LookupEnv("TOPIC_ARN")
	if !ok {
		return errors.New("env TOPIC_ARN is not found")
	}

	topicArn = t

	r, ok := os.LookupEnv("REGION")
	if !ok {
		return errors.New("env REGION is not found")
	}

	region = r

	return nil
}

func handler(ctx context.Context, sqsEvent events.SQSEvent) error {
	if err := getEnvVal(); err != nil {
		log.Fatal(err)
	}

	cfg, err := config.LoadDefaultConfig(context.TODO(), config.WithRegion(region))
	if err != nil {
		return errors.Wrap(err, "failed to initialize client")
	}

	client := sns.NewFromConfig(cfg)

	m, err := json.Marshal(sqsEvent)
	if err != nil {
		return errors.Wrap(err, "failed to convert to JSON")
	}

	input := &sns.PublishInput{
		Message:  aws.String(string(m)),
		TopicArn: &topicArn,
	}

	_, err = client.Publish(context.TODO(), input)
	if err != nil {
		return errors.Wrapf(err, "failed to publish message. message: %+v", input)
	}

	return nil
}

func main() {
	lambda.Start(handler)
}
