# Aerospike client for Erlang

## License

BSD two-clause license.

## Examples

### Start Aerospike client as linked process:

```erlang
Host = "10.0.0.1",
Port = 3000,
{ok, Socket} = aerospike_socket:start_link(Host, Port, []),
...
```

The example code snippet above will crash on connection error. There is a
special option for aerospike_socket:start_link/3 function which make the
process to behave more stable in case of network failures:

```erlang
{ok, Socket} = aerospike_socket:start_link("10.0.0.1", 3000, [reconnect]),
...
```

In this case the process will not terminate until aerospike_socket:close/1
will be called and will try to continuously reconnect to the node if
first connection attempt was failed or when already established connection
closed for some reason.

### Write some data

Set value for binary bin "myb", increment integer counter "myi" with 2 and
increment float counter "myf" with 3.2:

```erlang
case aerospike_socket:msg(Socket,
                          _Fields = [{namespace, <<"myn">>}, {set, <<"mys">>}, {key, <<"myk">>}],
                          _Ops = [{write, blob, <<"myb">>, <<"myv">>},
                                  {incr, integer, <<"myi">>, 2},
                                  {incr, float, <<"myf">>, 3.2}],
                          _FlagsAndOptions = [write],
                          _Timeout = 5000) of
    {ok, _RespFlags, Generation, _RespFields, RespOps} ->
        ...;
    {error, Reason} ->
        ...
end,
```

### Read data from Aerospike

Fetch all bins from the record:

```erlang
case aerospike_socket:msg(Socket,
                          _Fields = [{namespace, <<"myn">>}, {set, <<"mys">>}, {key, <<"myk">>}],
                          _Ops = [],
                          _FlagsAndOptions = [read, get_all],
                          _Timeout = 5000) of
    {ok, _RespFlags, Generation, _RespFields, RespOps} ->
        Proplist =
            [{BinName, BinValue} ||
                {_Operation, _BinType, BinName, BinValue} <- RespOps],
        ...;
    {error, Reason} ->
        ...
end,
```

## Build dependencies

* GNU Make;
* Erlang OTP;
* erlang-dev, erlang-tools (only when they are not provided with the Erlang OTP, e.g. in Debian);
* erlang-edoc (optional, needed to generate HTML docs);
* erlang-dialyzer (optional, needed to run the Dialyzer).

## Runtime dependencies

* Erlang OTP.

## Build

```make compile```

## Generate an HTML documentation for the code

```make html```

## Dialyze the code

```make dialyze```
