FROM golang:1.16 as builder
WORKDIR /src
COPY main.go /src
RUN CGO_ENABLED=0 GOOS=linux go build -o sample-app main.go

FROM scratch
COPY --from=builder /src/sample-app /sample-app
EXPOSE 8000
CMD ["/sample-app"]
