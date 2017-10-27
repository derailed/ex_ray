# ExRay Nested

Demonstrates a simple OpenTracing use case by decorating nested functions.


## Up And Running

1. Start Jaeger

    ```shell
    docker run -d -e COLLECTOR_ZIPKIN_HTTP_PORT=9411 -p5775:5775/udp -p6831:6831/udp -p6832:6832/udp \
    -p5778:5778 -p16686:16686 -p14268:14268 -p9411:9411 jaegertracing/all-in-one:latest
    ```

1. Run Basic

    ```shell
    iex -S mix
    > Nested.fred(10,20)
    ```

1. See the trace

    ```shell
    open http://localhost:16686
    ```

---
<img src="../../assets/imhoteplogo.png" width="32" height="auto"/> © 2017 Imhotep Software LLC.
All materials licensed under [Apache v2.0](http://www.apache.org/licenses/LICENSE-2.0)
