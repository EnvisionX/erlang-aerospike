%%% @doc
%%% Aerospike message decoder.

%%% @author Aleksey Morarash <aleksey.morarash@gmail.com>
%%% @since 02 May 2016
%%% @copyright 2016, Aleksey Morarash <aleksey.morarash@gmail.com>

-module(aerospike_decoder).

%% API exports
-export([decode/1]).

-include("aerospike.hrl").
-include("aerospike_defaults.hrl").
-include("aerospike_constants.hrl").

%% ----------------------------------------------------------------------
%% API functions
%% ----------------------------------------------------------------------

%% @doc Decode Aerospike message.
-spec decode(Encoded :: binary()) ->
                    {ok,
                     Flags :: [aerospike_socket:flag()],
                     CurrentGeneration :: integer(),
                     Fields :: list(), Ops :: list()} |
                    {error, Reason :: any()}.
decode(<<22:8/unsigned,
         Info1:8/unsigned, Info2:8/unsigned, Info3:8/unsigned,
         _Unused:8/unsigned, ?AS_PROTO_RESULT_OK:8/unsigned,
         CurrentGeneration:32/big-unsigned,
         _RecordTTL:32/big-signed,
         _TransactionTTL:32/big-unsigned,
         Nfields:16/big-unsigned, Nops:16/big-unsigned,
         Payload/binary>>) ->
    Flags = decode_flags(Info1, ?info1weights) ++
        decode_flags(Info2, ?info2weights) ++
        decode_flags(Info3, ?info3weights),
    ?trace("flags: ~9999p", [Flags]),
    case decode_response_fields(Nfields, Payload, []) of
        {ok, Fields, Tail} ->
            case decode_response_ops(Nops, Tail, []) of
                {ok, Ops, <<>>} ->
                    {ok, Flags, CurrentGeneration, Fields, Ops};
                {ok, Ops, _Tail2} ->
                    ?trace("decode_response(): extra data after response:"
                           " B64(GZ()) = ~s",
                           [base64:encode(zlib:gzip(_Tail2))]),
                    {ok, Flags, CurrentGeneration, Fields, Ops};
                {error, _Reason} = Error ->
                    Error
            end;
        {error, _Reason} = Error ->
            Error
    end;
decode(<<22:8/unsigned,
         _Infos:24/unsigned, _Unused:8/unsigned,
         ErrorCode:8/unsigned,
         _Generation:32/big-unsigned,
         _RecordTTL:32/big-unsigned,
         _TransactionTTL:32/big-unsigned,
         _Nfields:16/big-unsigned, _Nops:16/big-unsigned,
         _/binary>>) ->
    {error, [{code, ErrorCode}, {descr, ?describeError(ErrorCode)}]};
decode(Response) ->
    {error, {unknown_response_format, Response}}.

%% ----------------------------------------------------------------------
%% Internal functions
%% ----------------------------------------------------------------------

%% @doc
-spec decode_flags(Packed :: 0..16#ff, Spec :: list()) ->
                          [aerospike_socket:flag()].
decode_flags(Packed, Spec) ->
    lists:flatmap(
      fun({Flag, Weight}) ->
              if Packed band Weight > 0 ->
                      [Flag];
                 true ->
                      []
              end
      end, Spec).

%% @doc
-spec decode_response_fields(Count :: non_neg_integer(),
                             Payload :: binary(),
                             Accum :: list()) ->
                                    {ok, Fields :: list(), Tail :: binary()} |
                                    {error, Reason :: any()}.
decode_response_fields(0, Tail, Accum) ->
    {ok, lists:reverse(Accum), Tail};
decode_response_fields(Count, <<Size:32/big-unsigned, FieldType:8/unsigned, Tail/binary>>, Accum)
  when is_integer(Count), Count > 0, size(Tail) >= Size - 1 ->
    {FieldValue, Tail2} = split_binary(Tail, Size - 1),
    decode_response_fields(
      Count - 1, Tail2, [{?ft2a(FieldType), FieldValue} | Accum]);
decode_response_fields(_Count, Tail, _Accum) ->
    {error, {decode_fields, {bad_data, Tail}}}.

%% @doc
-spec decode_response_ops(Count :: non_neg_integer(),
                          Payload :: binary(),
                          Accum :: list()) ->
                                 {ok, Ops :: list(), Tail :: binary()} |
                                 {error, Reason :: any()}.
decode_response_ops(0, Tail, Accum) ->
    {ok, lists:reverse(Accum), Tail};
decode_response_ops(Count, <<Size:32/big-unsigned,
                             Operation:8/unsigned,
                             BinDataType:8/unsigned,
                             _BinVersion:8/unsigned,
                             BinNameLength:8/unsigned,
                             Tail/binary>>, Accum)
  when is_integer(Count), Count > 0, size(Tail) >= BinNameLength,
       Size > BinNameLength, size(Tail) >= Size - 4 ->
    {BinName, Tail2} = split_binary(Tail, BinNameLength),
    {EncodedBinData, Tail3} = split_binary(Tail2, Size - 4 - BinNameLength),
    case decode_bin_data(BinDataType, EncodedBinData) of
        {ok, BinData} ->
            decode_response_ops(
              Count - 1, Tail3,
              [{?op2a(Operation), ?bt2a(BinDataType), BinName, BinData} | Accum]);
        {error, Reason} ->
            {error, {decode_bin_data,
                     [{bin_name, BinName},
                      {bin_data_type, BinDataType},
                      {encoded_bin_data, EncodedBinData}],
                     Reason}}
    end;
decode_response_ops(_Count, Tail, _Accum) ->
    {error, {decode_ops, {bad_data, Tail}}}.

%% @doc
-spec decode_bin_data(BinDataType :: integer(), Encoded :: binary()) ->
                             {ok, BinData :: any()} |
                             {error, Reason :: any()}.
decode_bin_data(?AS_BIN_TYPE_INTEGER, <<I:64/big-unsigned>>) ->
    {ok, I};
decode_bin_data(?AS_BIN_TYPE_INTEGER, Encoded) ->
    {error, {bad_integer, Encoded}};
decode_bin_data(?AS_BIN_TYPE_FLOAT, <<Float/float>>) ->
    {ok, Float};
decode_bin_data(?AS_BIN_TYPE_FLOAT, Encoded) ->
    {error, {bad_float, Encoded}};
decode_bin_data(_BinDataType, Encoded) ->
    {ok, Encoded}.
