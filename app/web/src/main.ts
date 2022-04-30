// OpenTelemetry Tracer Provider
import { WebTracerProvider } from "@opentelemetry/sdk-trace-web";
import { DocumentLoadInstrumentation } from "@opentelemetry/instrumentation-document-load";
import { ZoneContextManager } from "@opentelemetry/context-zone";
import { registerInstrumentations } from "@opentelemetry/instrumentation";
import { SemanticResourceAttributes } from "@opentelemetry/semantic-conventions";

import { SimpleSpanProcessor } from "@opentelemetry/sdk-trace-base";
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http";
import { XMLHttpRequestInstrumentation } from "@opentelemetry/instrumentation-xml-http-request";
import { Resource } from "@opentelemetry/resources";
import { AWSXRayIdGenerator } from "@opentelemetry/id-generator-aws-xray";

const provider = new WebTracerProvider({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: "task-web",
    [SemanticResourceAttributes.SERVICE_VERSION]: "1.0.0",
  }),
  idGenerator: new AWSXRayIdGenerator(),
});
const exporter = new OTLPTraceExporter({
  url: "https://otel.mamezou-tech.com/v1/traces",
  // url: "http://192.168.64.8/v1/traces",
});
//provider.addSpanProcessor(new SimpleSpanProcessor(new ConsoleSpanExporter()));
provider.addSpanProcessor(new SimpleSpanProcessor(exporter));

provider.register({
  contextManager: new ZoneContextManager(),
});

registerInstrumentations({
  instrumentations: [
    new DocumentLoadInstrumentation(),
    new XMLHttpRequestInstrumentation(),
  ],
});

import { createApp } from "vue";
import App from "./App.vue";
import router from "./router";

const app = createApp(App);
app.use(router);
app.mount("#app");
