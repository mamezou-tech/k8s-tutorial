import { DocumentClient } from "aws-sdk/clients/dynamodb";
import S3 from "aws-sdk/clients/s3";
import { ServiceConfigurationOptions } from "aws-sdk/lib/service";

const options: ServiceConfigurationOptions = {
  endpoint: process.env.AWS_ENDPOINT || "http://localhost:4566",
  region: process.env.AWS_DEFAULT_REGION || "ap-northeast-1",
  httpOptions: {
    connectTimeout: 1000,
  },
  maxRetries: 3,
};

const dynamodbClient = new DocumentClient(options);
const s3Client = new S3({
  ...options,
  s3ForcePathStyle: process.env.STAGE === "localstack",
});

export { dynamodbClient, s3Client };
