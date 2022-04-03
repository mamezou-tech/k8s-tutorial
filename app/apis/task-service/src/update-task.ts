import { RequestHandler } from "express";
import client from "./dynamodb-client";
import { TaskUpdateRequest } from "./types";
import dayjs from "dayjs";
import logger from "./logger";

const updateTaskHandler: RequestHandler<{}, string, TaskUpdateRequest> = async (
  req,
  res
) => {
  const { body } = req;
  const getResponse = await client
    .get({
      TableName: process.env.TASK_TABLE_NAME || "tasks",
      Key: {
        task_id: body.taskId,
      },
    })
    .promise();

  if (!getResponse.Item) {
    res.status(404);
    return;
  }
  const putResponse = await client
    .put({
      TableName: process.env.TASK_TABLE_NAME || "tasks",
      Item: {
        task_id: body.taskId,
        user_name: body.userName,
        start_at: body.startAt,
        title: body.title,
        contents: body.contents,
        notified: body.notified,
        status: body.done ? "DONE" : "UNDONE",
        updated_at: dayjs().unix(),
      },
    })
    .promise();
  logger.info(`タスクを更新しました。タスクID => ${body.taskId},ユーザー => ${body.userName}`);
  res.send("ok");
};

export default updateTaskHandler;
