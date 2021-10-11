FROM golang:1.17 AS builder

WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 go build -o server main.go

FROM alpine:3.12

WORKDIR /app
COPY --from=builder /app/server .
CMD ["./server"]