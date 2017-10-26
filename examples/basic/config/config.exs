use Mix.Config

config :otter,
  zipkin_collector_uri:    'http://127.0.0.1:9411/api/v1/spans',
  zipkin_tag_host_service: "TraceBasic",
  http_client:             :ibrowse
