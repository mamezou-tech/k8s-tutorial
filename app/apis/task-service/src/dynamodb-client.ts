import { DocumentClient } from "aws-sdk/clients/dynamodb";

const client = new DocumentClient({
  endpoint: process.env.AWS_ENDPOINT,
  region: process.env.AWS_DEFAULT_REGION || "ap-northeast-1",
});
export default client;
