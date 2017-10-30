# ExRay

<div align="center" style="margin-top:10px;">
  <img src="assets/xray.png"/>
</div>

[![Hex version](https://img.shields.io/hexpm/v/ex_ray.svg "Hex version")](https://hex.pm/packages/ex_ray)
[![Build Status](https://semaphoreci.com/api/v1/derailed/ex_ray/branches/master/shields_badge.svg)](https://semaphoreci.com/derailed/ex_ray)


## Motivation

ExRay defines an annotation construct that wraps regular functions and enable
them to be traced using a simple affordance **@trace** to interact with an
OpenTracing compliant collector.

[OpenTracing](http://opentracing.io/) defines the concept of spans that
track the call stack and record timing information and various call artifacts
that can be used for application runtime inspection.
This is a really cool piece of technology that compliments your monitoring
solution as you now have x-ray vision of your application at runtime once
a monitoring metric gets off the chart.

However in practice, your code gets quickly cluttered by your tracing efforts.
ExRay alleviates the clutter by injecting cross-cutting tracing concern into
your application code. By using @trace annotation, you can trap the essence of
the calls without introducing tracing code mixed-in with your business logic.

ExRay leverages [Otter](https://github.com/Bluehouse-Technology/otter) Erlang
OpenTracing lib from the fine folks of BlueHouse Technology.

## Documentation

[ExRay](https://hexdocs.pm/ex_ray)

## Installation

Tracing information needs to be collected by a tracing backend of your choice. You can run
ExRay using any trace collector that Otter supports. In the following example we will use
[Jaeger](https://uber.github.io/jaeger) from the self-driven folks at Uber!

1. Start Jaeger

    Providing you have docker running on you box, you can use the all-in-one Jaeger
    image to get you started. If you are a Kubernetes fan, you can use the
    [Jaeger chart](https://github.com/kubernetes/charts/tree/master/incubator/jaeger)

    ```shell
    docker run -d -e COLLECTOR_ZIPKIN_HTTP_PORT=9411 -p5775:5775/udp -p6831:6831/udp -p6832:6832/udp \
    -p5778:5778 -p16686:16686 -p14268:14268 -p9411:9411 jaegertracing/all-in-one:latest
    ```

    Alternatively, you could use the echo server [otter_srv](https://github.com/Bluehouse-Technology/otter_srv)
    for testing your installation but I find it more fun to have a cool UI to look at your tracing outcomes.

1. Setup Dependencies

    Add the following dependencies to your project (Elixir or Phoenix)

    > NOTE: You can use Httpc(default), Hackney or IBrowse for your http client.
    > We opt for Ibrowse here.

    ```elixir
    def deps do
      [
        ...
        {:ex_ray , "~> 0.1.2"},
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

1. Configure Your Application

    ExRay uses ETS to track the span chains. Each request will create a new chain that
    will grow and collapse with your function call stack. As such you will need to track a unique
    call ID either by generating a custom ID for each request. If you are using Phoenix, the
    framework does this for you by using the request_id in the response headers.
    The ETS table is used to locate the parent span for which to attach to when
    navigating the call stack.

    > NOTE: One cool aspect of OpenTracing is the tracing does not stop at the process boundaries
    as you can continue the chain to other processes and external services. Please see
    the examples directory for further info.

    In your application initialization, you need to make sure the ExRay ETS table is created by calling

    ```elixir
    # application.ex
    ...
    ExRay.Store.create()
    ...
    ```

1. Let's Trace!

    Here is a simples tracing example. Please take a look at the examples in the Repo and
    [ExRay Tracers](https://github.com/derailed/ex_ray_tracers) for Phoenix sample use cases.

    ```elixir
      defmodule TraceMe do
        use ExRay, pre: :before_fun, post: :after_fun

        alias ExRay.Span

        # Generates a request id
        @req_id :os.system_time(:milli_seconds) |> Integer.to_string |> IO.inspect

        @trace kind: :critical
        def fred(a, b), do: a+b

        defp before_fun(ctx) do
          ctx.target
          |> Span.open(@req_id)
          |> :otter.tag(:kind, ctx.meta[:kind])
          |> :otter.log(">>> #{ctx.target} with #{ctx.args |> inspect}")
        end

        defp after_fun(ctx, span, res) do
          span
          |> :otter.log("<<< #{ctx.target} returned #{res}")
          |> Span.close(@req_id)
        end
      end
    ```

1. See it!

    That's great, but how do you see the tracing information?

    ```shell
    open http://localhost:16686
    ```

    Under *Service* open up our *TraceMe* service, click **Find Traces** and you should
    now see your span in all its glory ie timing, tag and log info

---
### Thank you for playing!

---
<img src="assets/imhoteplogo.png" width="32" height="auto"/> © 2017 Imhotep Software LLC.
All materials licensed under [Apache v2.0](http://www.apache.org/licenses/LICENSE-2.0)
