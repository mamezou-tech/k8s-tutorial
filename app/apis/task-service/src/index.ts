// OpenTelemetry Instrumentations
import { NodeTracerProvider } from "@opentelemetry/sdk-trace-node";
import { registerInstrumentations } from "@opentelemetry/instrumentation";
import { AwsInstrumentation } from "@opentelemetry/instrumentation-aws-sdk";
import { WinstonInstrumentation } from "@opentelemetry/instrumentation-winston";
import { SimpleSpanProcessor } from "@opentelemetry/sdk-trace-base";
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-grpc";
import { Resource } from "@opentelemetry/resources";
import { SemanticResourceAttributes } from "@opentelemetry/semantic-conventions";
import { HttpInstrumentation } from "@opentelemetry/instrumentation-http";
import { ExpressInstrumentation } from "@opentelemetry/instrumentation-express";

const provider = new NodeTracerProvider({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: "task-service",
    [SemanticResourceAttributes.SERVICE_VERSION]: "1.0.0",
  })
});

provider.register();
registerInstrumentations({
  instrumentations: [
    new HttpInstrumentation({
      ignoreIncomingPaths: ["/health/liveness", "/health/readiness"]
    }),
    new ExpressInstrumentation(),
    new AwsInstrumentation(),
    new WinstonInstrumentation() // ログにトレース識別子を注入
  ]
});
const exporter = new OTLPTraceExporter();
provider.addSpanProcessor(new SimpleSpanProcessor(exporter));
["SIGINT", "SIGTERM"].forEach(signal => {
  process.on(signal, () => provider.shutdown().catch(console.error));
});

import express, { ErrorRequestHandler } from "express";
import createTaskHandler from "./create-task";
import updateTaskHandler from "./update-task";
import listTasksHandler from "./list-tasks";
import Router from "express-promise-router";
import expressWinston from "express-winston";
import winston from "winston";
import apiMetrics from 'prometheus-api-metrics';
import logger from "./logger";

const app = express();
app.use(express.json());

app.use(apiMetrics());

app.use(expressWinston.logger({
  transports: [
    new winston.transports.Console()
  ],
  format: winston.format.combine(winston.format.timestamp(), winston.format.json())
}));

const router = Router();
app.use("/api", router);
router.post("/tasks", createTaskHandler);
router.put("/tasks", updateTaskHandler);
router.get("/tasks", listTasksHandler);

app.get("/health/liveness", (req, res) => {
  res.send("liveness OK");
});
app.get("/health/readiness", (req, res) => {
  res.send("readiness OK");
});
app.get("/health/startup", (req, res) => {
  res.send("startup OK");
});

app.use(expressWinston.errorLogger({
  transports: [
    new winston.transports.Console()
  ],
  format: winston.format.combine(winston.format.timestamp(), winston.format.json())
}))

const errorHandler: ErrorRequestHandler = (err, req, res, next) => {
  if (res.headersSent) {
    return next(err);
  }
  res.header("Content-Type", "text/plain");
  res.status(500).send("Something wrong...");
};
app.use(errorHandler);

const port = 3000;
const host = "0.0.0.0"
app.listen(port, host, () => {
  logger.info(`task-service listening at http://${host}:${port}`);
});
