import { DocumentClient } from "aws-sdk/clients/dynamodb";
import dayjs from "dayjs";
import process from "process";
import fs from "fs";
import utc from "dayjs/plugin/utc";
import { dynamodbClient, s3Client } from "./aws-client";

dayjs.extend(utc);

const IndexName = "status_index";

const yesterday = dayjs().add(-(process.env.TARGET_OFFSET_DAYS || 0), "day");
const start = yesterday.startOf("day");
const end = yesterday.endOf("day");

const queryWithPagination = async (
  params: DocumentClient.QueryInput,
  callback: (items: DocumentClient.ItemList) => Promise<void>
): Promise<void> => {
  const result = await dynamodbClient.query(params).promise();
  if (result.Items?.length) {
    await callback(result.Items);
  }
  if (!result.LastEvaluatedKey) {
    console.log("Got all chunks successfully!");
    return; // finish!
  }
  console.log("processing next chunk...");
  await queryWithPagination(
    {
      ...params,
      ExclusiveStartKey: result.LastEvaluatedKey,
    },
    callback
  );
};

async function main() {
  const fileName = `completed-tasks-${start.format("YYYY-MM-DD")}.csv`;
  const fullPath = `${process.env.TEMP_DIR || "."}/${fileName}`;
  const stream = fs.createWriteStream(fullPath, {
    flags: "w",
    encoding: "utf-8",
  });
  stream.on("error", (e) => {
    console.log("write-error", e);
    process.exit(1);
  });

  stream.write("taskId,userName,completedTime,title\n");
  const chunkWriter = async (items: DocumentClient.ItemList) => {
    items.forEach((item) => {
      console.log(`writing ${item.task_id}:${item.title} ...`);
      const endTime = dayjs.unix(item.updated_at).format("HH:mm");
      stream.write(
        `${item.task_id},${item.user_name},${endTime},"${item.title}"\n`
      );
    });
  };

  try {
    await queryWithPagination(
      {
        TableName: process.env.TASK_TABLE_NAME || "tasks",
        IndexName,
        KeyConditionExpression:
          "#status = :undone AND updated_at BETWEEN :start AND :end",
        ExpressionAttributeNames: {
          "#status": "status",
        },
        ExpressionAttributeValues: {
          ":start": start.unix(),
          ":end": end.unix(),
          ":undone": "DONE",
        },
        Limit: 10,
      },
      chunkWriter
    );
  } catch (e) {
    stream.close();
    throw e;
  }
  stream.end(() => console.log("stream end"));

  await s3Client
    .upload({
      Bucket: process.env.REPORT_BUCKET || "mz-reporting-test-bucket",
      Key: fileName,
      Body: fs.createReadStream(fullPath),
    })
    .promise();
  console.log(`uploaded file ${fileName}`);

  fs.unlinkSync(fullPath);
}

main()
  .then(() => {
    console.log("completed!!");
    process.exit(0);
  })
  .catch((e) => {
    console.log(e);
    process.exit(1);
  });
