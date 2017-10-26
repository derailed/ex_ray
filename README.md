# ExRay

<div align="center" style="margin-top:10px;">
  <img src="assets/xray.png"/>
</div>

ExRay defines a custom annotation that wraps regular functions and enable
them to be traced using a simple affordance aka @trace. At the base,
[OpenTracing](http://opentracing.io/) defines the concept of a span that
track the callstack and record timing information, tags and logs,... .
So instead of littering your code with span management, ExRay provides an
easy way to inject your tracing needs by simply using an annotation and
wrapping your function calls.


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ex_ray` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_ray, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ex_ray](https://hexdocs.pm/ex_ray).

## Running with ExRay

You can run ExRay using any trace collection that honors
[Open Zipkin](https://github.com/openzipkin). In the following example we will use
[Jaeger](https://uber.github.io/jaeger) from the self-driven Uber folks...

1. Start Jaeger

  Providing you have docker running on you box, you can use the all in one Jaeger
  image to get you started. If you are a Kubernetes fan, you can use the
  [Jaeger chart](https://github.com/kubernetes/charts/tree/master/incubator/jaeger)

  ```shell
  docker run -d -e COLLECTOR_ZIPKIN_HTTP_PORT=9411 -p5775:5775/udp -p6831:6831/udp -p6832:6832/udp \
  -p5778:5778 -p16686:16686 -p14268:14268 -p9411:9411 jaegertracing/all-in-one:latest
  ```

  Alternatively, you could use the test [otter_srv](https://github.com/Bluehouse-Technology/otter_srv)for testing your installation but I find it more fun to have a nice ui to look at the outcomes.

1. Add the following dependencies in your project (Elixir or Phoenix)

    ```elixir
    def deps do
      [
        ...
        {:ex_ray , "~> 0.1.0"},
        {:ibrowse, "~> 4.4.0"}
      ]
    end
    ```

1. Configure Otter

   In your config file, you need to tell Otter where to find your Zipkin collector.

   ```elixir
    config :otter,
      zipkin_collector_uri:    'http://127.0.0.1:9411/api/v1/spans',
      zipkin_tag_host_service: "TraceMe",
      http_client:             :ibrowse
    ```

    > Note: This thru me for a loop! The uri is indeed a char list and not a string!
    > Note: We are using ibrowse here for the http client, you can also use httpc or
    hackney

1. Configure Your Application

  ExRay uses an ETS table to track the span chains. Each request will create a new chain that
  will grow and collapse with your function callstack. As such you will need to track a unique
  call ID either by generating a custom ID for each request or using the request_id that Phoenix
  generates for you. The ETS table is used to locate the parent span for which to attach to when
  navigating the callstack.

  In your application initialization, you need to make sure the ExRay ETS table is created by calling

  ```elixir
  # in application.ex
  ExRay.Store.create()
  ```

1. Let's Trace!

  Here is a simples tracing example. Please take a look at the examples in the Repo for
  different use cases.

  ```elixir
  defmodule Traceme do
    use ExRay, pre: :before_fun, post: :after_fun

    alias ExRay.Span

    @trace kind: :critical
    def fred(a, b), do a+b

    defp before_fun(ctx)
      ctx.target
      |> ExRay.open("123")
    end

    defp after_fun(ctx, span, _res) do
      span |> ExRay.close("123")
    end
  end

  ---
<img src="assets/imhoteplogo.png" width="32" height="auto"/> © 2017 Imhotep Software LLC.
All materials licensed under [Apache v2.0](http://www.apache.org/licenses/LICENSE-2.0)